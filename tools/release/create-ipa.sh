#!/bin/sh

set -eu

CLANG_PATH="$(xcrun --sdk iphoneos --find clang)"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
ARCHIVE_DIR="$ROOT_DIR/dist/Reynard.xcarchive"
APP_DIR="$ARCHIVE_DIR/Products/Applications"
WORK_DIR="$ROOT_DIR/dist/Reynard"

BUILD_TYPE="${1:-normal}"
case "$BUILD_TYPE" in
	--trollstore)
		OUTPUT_NAME="Reynard-TrollStore.tipa"
		PTRACE_JIT_NAME="ts_ptrace_jit"
		;;
	--jailbroken)
		OUTPUT_NAME="Reynard-Jailbroken.ipa"
		PTRACE_JIT_NAME="jb_ptrace_jit"
		;;
	*)
		BUILD_TYPE="normal"
		OUTPUT_NAME="Reynard.ipa"
		;;
esac

cd "$ROOT_DIR"

if [ ! -d "$APP_DIR" ]; then
	echo "Missing archive output at $APP_DIR"
	echo "Run tools/release/build-app.sh first."
	exit 1
fi

APP_PATH="$(find "$APP_DIR" -maxdepth 1 -type d -name '*.app' | head -n 1)"
if [ -z "$APP_PATH" ]; then
	echo "No .app found in $APP_DIR"
	exit 1
fi

# I absolutely hate Apple for this
# Why is my bundle identifier just become unavailable for no reason?
plutil -replace CFBundleIdentifier -string "moe.bemly.reynard" "$APP_PATH/Info.plist"
plutil -replace CFBundleIdentifier -string "moe.bemly.reynard.Helper" "$APP_PATH/PlugIns/Reynard Helper.appex/Info.plist"
plutil -replace CFBundleIdentifier -string "moe.bemly.reynard.OpenIn" "$APP_PATH/PlugIns/OpenIn.appex/Info.plist"

rm -rf "$WORK_DIR" "$ROOT_DIR/dist/$OUTPUT_NAME"
mkdir -p "$WORK_DIR/Payload"
cp -R "$APP_PATH" "$WORK_DIR/Payload/"

# Strip bitcode, because we bypass the signing stage & https://developer.apple.com/documentation/Xcode-Release-Notes/xcode-13_3_1-release-notes?changes=_1
# NOTE (iOS 12 port): the Concurrency runtime may be absent — @MainActor was
# removed tree-wide, so nothing links libswift_Concurrency. Guard for that.
SWIFT_CONCURRENCY_PATH="$WORK_DIR/Payload/Reynard.app/Frameworks/libswift_Concurrency.dylib"
if [ -f "$SWIFT_CONCURRENCY_PATH" ]; then
	xcrun bitcode_strip "$SWIFT_CONCURRENCY_PATH" -r -o "$SWIFT_CONCURRENCY_PATH"
	/usr/bin/codesign --force --sign - --verbose "$SWIFT_CONCURRENCY_PATH"
fi

cd "$WORK_DIR"

if [ "$BUILD_TYPE" != "normal" ]; then
	PTRACE_JIT_SRC="$ROOT_DIR/browser/Reynard/JIT/Unsandboxed/ptrace_jit.c"
	PTRACE_JIT_OUT="Payload/Reynard.app/$PTRACE_JIT_NAME"

	"$CLANG_PATH" \
		-arch arm64 \
		-isysroot "$SDK_PATH" \
		-miphoneos-version-min=12.0 \
		-Os \
		"$PTRACE_JIT_SRC" \
		-o "$PTRACE_JIT_OUT"

	chmod 0755 "$PTRACE_JIT_OUT"
	ldid -S"$ROOT_DIR/browser/Reynard/JIT/Unsandboxed/ptrace_jit.entitlements" "$PTRACE_JIT_OUT"
	ldid -S"$ROOT_DIR/browser/Reynard/Entitlements/Reynard.private.entitlements" "Payload/Reynard.app/Reynard"
	ldid -S"$ROOT_DIR/browser/Helper/Entitlements/Reynard-Helper.private.entitlements" "Payload/Reynard.app/PlugIns/Reynard Helper.appex/Reynard Helper"
fi

zip -r "../$OUTPUT_NAME" Payload -x "._*" -x ".DS_Store" -x "__MACOSX"
