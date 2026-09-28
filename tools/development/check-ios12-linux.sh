#!/bin/bash
# iOS 12 compile check on Linux (no Xcode, no Mac).
#
# Uses the official Swift Linux toolchain + an iPhoneOS SDK to compile every
# Xcode target's Swift sources to arm64-apple-ios12.0 objects (WMO, same as
# Release), so availability errors and SIL mandatory diagnostics match what
# Xcode reports in CI. No linking. Then runs the checks the compiler cannot:
#   - ObjC/C sources with -Wunguarded-availability(-new)
#   - Swift Concurrency runtime references in the objects (iOS 12 has no
#     libswift_Concurrency; any reference = dyld refuses to launch)
#   - every "reynard.*" image name resolves to an .imageset (no .symbolset)
#   - post-iOS-12 SDK APIs used by engine patch lines added since BASE_REF
#     (mach folds warnings in some dirs, so the Gecko log is not enough)
#
# Usage: tools/development/check-ios12-linux.sh [BASE_REF]
#   BASE_REF: last device-verified commit for the engine patch scan
#             (default: merge-base with upstream/main's previous merge, i.e.
#             pass it explicitly after an upstream merge, e.g. the old main).
# Env: CHECK_CACHE (default ~/.cache/reynard-ios12-check), SWIFT_VERSION,
#      SDK_VERSION. The SDK's swiftinterfaces pin the compiler version: read
#      "swift-compiler-version" in UIKit's .swiftinterface and match it.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_REF="${1:-}"
CACHE="${CHECK_CACHE:-$HOME/.cache/reynard-ios12-check}"
SWIFT_VERSION="${SWIFT_VERSION:-6.3.2}"
SDK_VERSION="${SDK_VERSION:-26.5}"
SWIFT_DIR="$CACHE/swift-$SWIFT_VERSION"
SDK_REPO="$CACHE/ios-sdks"
SDK="$SDK_REPO/iPhoneOS$SDK_VERSION.sdk"
RES="$CACHE/res-$SWIFT_VERSION"
GECKO="$CACHE/gecko"
OUT="$CACHE/build"
mkdir -p "$CACHE"

# --- toolchain -------------------------------------------------------------
if [ ! -x "$SWIFT_DIR/usr/bin/swiftc" ]; then
	. /etc/os-release
	DIST="${ID}${VERSION_ID}"; DIST_NODOT="${DIST//./}"
	URL="https://download.swift.org/swift-$SWIFT_VERSION-release/$DIST_NODOT/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-$DIST.tar.gz"
	echo "Downloading $URL"
	mkdir -p "$SWIFT_DIR"
	curl -fsSL "$URL" | tar -xz -C "$SWIFT_DIR" --strip-components=1 || exit 1
fi
SWIFTC="$SWIFT_DIR/usr/bin/swiftc"; CLANG="$SWIFT_DIR/usr/bin/clang"; NM="$SWIFT_DIR/usr/bin/llvm-nm"

# --- SDK (sparse checkout, ~350MB) -----------------------------------------
if [ ! -d "$SDK/System" ]; then
	rm -rf "$SDK_REPO"; git init -q "$SDK_REPO"
	git -C "$SDK_REPO" remote add origin https://github.com/xybp888/iOS-SDKs
	git -C "$SDK_REPO" fetch -q --depth 1 --filter=blob:none origin master || exit 1
	git -C "$SDK_REPO" sparse-checkout set --no-cone "/iPhoneOS$SDK_VERSION.sdk/"
	git -C "$SDK_REPO" checkout -q FETCH_HEAD || exit 1
fi

# Resource dir with only shims + clang builtins: the Linux toolchain's own
# lib/swift carries corelibs CoreFoundation modulemaps that clash with the SDK.
if [ ! -d "$RES" ]; then
	mkdir -p "$RES"
	ln -s "$SWIFT_DIR/usr/lib/swift/shims" "$RES/shims"
	ln -s "$SWIFT_DIR/usr/lib/swift/clang" "$RES/clang"
fi

# --- Gecko exported headers (patched) --------------------------------------
TAG="$(tr -d '\r\n ' < "$ROOT/engine/release.txt")"
if [ ! -f "$GECKO/.tag" ] || [ "$(cat "$GECKO/.tag")" != "$TAG" ]; then
	rm -rf "$GECKO"; git init -q "$GECKO"
	git -C "$GECKO" remote add origin https://github.com/mozilla-firefox/firefox
	git -C "$GECKO" fetch -q --depth 1 --filter=blob:none origin "refs/tags/$TAG" || exit 1
	git -C "$GECKO" sparse-checkout set --no-cone /widget/uikit/ /toolkit/xre/IOSBootstrap.h
	git -C "$GECKO" checkout -q FETCH_HEAD || exit 1
	echo "$TAG" > "$GECKO/.tag"
fi
git -C "$GECKO" checkout -q -- . && git -C "$GECKO" clean -qfd
for p in "$ROOT"/patches/widget/uikit/*.patch "$ROOT"/patches/toolkit/xre/IOSBootstrap.h.patch; do
	[ -f "$p" ] && git -C "$GECKO" apply --whitespace=nowarn "$p" 2>/dev/null
done
rm -rf "$CACHE/dist"; mkdir -p "$CACHE/dist/include/GeckoView"
cp "$GECKO/widget/uikit/GeckoViewSwiftSupport.h" "$GECKO/widget/uikit/GeckoViewRuntimeSupport.h" \
	"$GECKO/toolkit/xre/IOSBootstrap.h" "$CACHE/dist/include/GeckoView/"

# --- Swift targets ---------------------------------------------------------
B="$ROOT/browser"
rm -rf "$OUT"; mkdir -p "$OUT/mods"
HDRS=(); for d in $(find "$B" -name "*.h" -exec dirname {} \; | sort -u); do HDRS+=(-Xcc "-I$d"); done
COMMON=(-target arm64-apple-ios12.0 -sdk "$SDK" -resource-dir "$RES" -I "$RES/shims" -swift-version 5
	-Xcc "-I$CACHE/dist/include" -Xcc "-I$CACHE/dist/include/GeckoView" "${HDRS[@]}"
	-default-isolation nonisolated -Onone -wmo -j 8
	-Xfrontend -disable-legacy-type-info)   # iOS <13 layouts yaml is not in the Linux toolchain
BRIDGE="$B/Reynard/Bridging/Reynard-Bridging-Header.h"
rc=0
swift_target() { # name log args...
	local name="$1" log="$OUT/$1.log"; shift
	echo "== Swift: $name"
	"$SWIFTC" "${COMMON[@]}" "$@" 2>"$log" || rc=1
	grep -E "(error|warning): .*(only available|unavailable)|error:" "$log" | grep -v '^ *|' | sort -u
}
mapfile -t GV < <(find "$B/GeckoView" -name "*.swift" | sort)
swift_target GeckoView -module-name GeckoView -parse-as-library -application-extension \
	-import-objc-header "$BRIDGE" -emit-module -emit-module-path "$OUT/mods/GeckoView.swiftmodule" \
	-c -o "$OUT/GeckoView.o" "${GV[@]}"
mapfile -t RY < <(find "$B/Reynard" -name "*.swift" | sort)
swift_target Reynard -module-name Reynard -I "$OUT/mods" -enable-upcoming-feature MemberImportVisibility \
	-import-objc-header "$BRIDGE" -c -o "$OUT/Reynard.o" "${RY[@]}"
mapfile -t OI < <(find "$B/Extensions" -name "*.swift" | sort)
swift_target OpenIn -module-name OpenIn -parse-as-library -application-extension -c -o "$OUT/OpenIn.o" "${OI[@]}"
swift_target ReynardHelper -module-name Reynard_Helper -I "$OUT/mods" -parse-as-library -application-extension \
	-import-objc-header "$BRIDGE" -c -o "$OUT/Helper.o" "$B/Helper/Helper.swift"

# --- Concurrency runtime references ----------------------------------------
echo "== Swift Concurrency runtime references"
for o in "$OUT"/*.o; do
	refs="$("$NM" -u "$o" 2>/dev/null | grep -E 'swift_task|swift_continuation|swift_asyncLet|swift_job|\$sScM|\$sScT|\$sScC|\$sScG|swift_defaultActor' | sort -u)"
	[ -n "$refs" ] && { echo "$(basename "$o"):"; echo "$refs"; rc=1; }
done

# --- ObjC / C ----------------------------------------------------------------
echo "== ObjC/C availability"
INC=(); for d in $(find "$B" -name "*.h" -exec dirname {} \; | sort -u); do INC+=("-I$d"); done
while IFS= read -r f; do
	# GeckoRuntimeBridge.mm needs the Gecko objdir (mozilla-config.h); skipped.
	grep -q "mozilla-config.h" "$f" && { echo "skip (needs objdir): ${f#$ROOT/}"; continue; }
	"$CLANG" -fsyntax-only -target arm64-apple-ios12.0 -isysroot "$SDK" -fobjc-arc -fmodules \
		-fmodules-cache-path="$CACHE/clang-mc" -Wunguarded-availability -Wunguarded-availability-new \
		-Wno-nullability-completeness -I"$CACHE/dist/include" -I"$CACHE/dist/include/GeckoView" "${INC[@]}" \
		"$f" 2>&1 | grep -E "error:|unguarded-availability" && rc=1
done < <(find "$B" \( -name "*.m" -o -name "*.mm" -o -name "*.c" \) | sort)

# --- image assets ------------------------------------------------------------
echo "== image assets"
python3 - "$B" <<'EOF' || rc=1
import glob,os,re,sys
b=sys.argv[1]
names={os.path.basename(d).rsplit('.',1)[0] for d in glob.glob(b+'/Reynard/Resources/Assets.xcassets/**/*.*set',recursive=True)}
bad=[d for d in glob.glob(b+'/**/*.symbolset',recursive=True)]
for d in bad: print('symbolset (iOS 12 cannot load):',d)
miss={}
for f in glob.glob(b+'/**/*.swift',recursive=True):
    for m in re.finditer(r'"(reynard\.[a-z0-9.]+)"',open(f).read()):
        if m.group(1) not in names: miss.setdefault(m.group(1),set()).add(os.path.basename(f))
for k,v in sorted(miss.items()): print('missing asset',k,sorted(v))
sys.exit(1 if bad or miss else 0)
EOF

# --- engine patch lines vs post-12 SDK APIs --------------------------------
if [ -n "$BASE_REF" ]; then
	echo "== engine patches added since $BASE_REF: post-iOS-12 SDK APIs (check each for a guard)"
	[ -f "$CACHE/avail-$SDK_VERSION.json" ] || python3 "$ROOT/tools/development/ios12_availdb.py" "$SDK" "$CACHE/avail-$SDK_VERSION.json"
	git -C "$ROOT" diff "$BASE_REF" HEAD -U0 -- patches | python3 "$ROOT/tools/development/ios12_availdb.py" --scan "$CACHE/avail-$SDK_VERSION.json"
fi

echo "== result: $([ $rc = 0 ] && echo PASS || echo FAIL)"
exit $rc
