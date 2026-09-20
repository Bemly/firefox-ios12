#!/bin/sh

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
FIREFOX_DIR="$ROOT_DIR/engine/firefox"

TARGET="aarch64-apple-ios"
USE_SCCACHE=false
AUTO_CLOBBER=false
DISABLE_JEMALLOC=false

for arg in "$@"; do
	case "$arg" in
		--use-sccache)
			USE_SCCACHE=true
			;;
		--auto-clobber)
			AUTO_CLOBBER=true
			;;
		--disable-jemalloc)
			DISABLE_JEMALLOC=true
			;;
	esac
done

if [ "$USE_SCCACHE" = true ]; then
	SCCACHE_BIN="${SCCACHE_PATH:-$(command -v sccache)}"
fi

cd "$ROOT_DIR"

if [ ! -d "$FIREFOX_DIR" ]; then
	echo "Missing firefox source at $FIREFOX_DIR"
	echo "Add the submodule, then run tools/development/update-gecko.sh."
	exit 1
fi

# Apple clang cannot target wasm, which the RLBox sandboxed libraries need.
# Use the WASI SDK's self-consistent clang/linker/sysroot/builtins as the
# wasm toolchain, downloading it if not already present.
WASI_SDK_DIR="$SCRIPT_DIR/wasi-sdk"
WASI_SDK_ARCH="$(uname -m)"
WASI_SDK_URL="https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-33/wasi-sdk-33.0-${WASI_SDK_ARCH}-macos.tar.gz"

if [ ! -d "$WASI_SDK_DIR" ]; then
	echo "Downloading WASI SDK ($WASI_SDK_ARCH)..."
	TMP_DIR="$(mktemp -d)"
	curl -L "$WASI_SDK_URL" -o "$TMP_DIR/wasi-sdk.tar.gz"
	mkdir -p "$WASI_SDK_DIR"
	tar -xzf "$TMP_DIR/wasi-sdk.tar.gz" -C "$WASI_SDK_DIR" --strip-components=1
	rm -rf "$TMP_DIR"
fi

# mozbuild clang ships no iOS compiler-rt, but our iOS 12 compat code uses
# @available(iOS 13, *) which clang lowers to __isPlatformVersionAtLeast.
# Link Xcode's libclang_rt.ios.a explicitly (from the DEVELOPER_DIR toolchain).
DEV_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
CLANG_RT_IOS=""
for cand in "$DEV_DIR"/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/*/lib/darwin/libclang_rt.ios.a; do
	if [ -f "$cand" ]; then
		CLANG_RT_IOS="$cand"
		break
	fi
done
if [ -z "$CLANG_RT_IOS" ]; then
	echo "Warning: libclang_rt.ios.a not found under $DEV_DIR; XUL link may fail on __isPlatformVersionAtLeast" >&2
fi

if [ -f "$FIREFOX_DIR/.mozconfig" ]; then
	mv "$FIREFOX_DIR/.mozconfig" "$FIREFOX_DIR/.mozconfig.bak"
fi

{
	echo "ac_add_options --enable-application=mobile/ios"
	echo "ac_add_options --target=$TARGET"
	echo "ac_add_options --enable-ios-target=12.0"
	echo "ac_add_options --enable-webrtc"
	echo "ac_add_options --enable-optimize"
	echo "ac_add_options --enable-release"
	echo "ac_add_options --enable-rust-simd"
	echo "ac_add_options --enable-lto"
	echo "ac_add_options --disable-debug"
	echo "export WASM_CC=$WASI_SDK_DIR/bin/clang"
	echo "export WASM_CXX=$WASI_SDK_DIR/bin/clang++"
	echo "ac_add_options --with-wasi-sysroot=$WASI_SDK_DIR/share/wasi-sysroot"
	if [ -n "$CLANG_RT_IOS" ]; then
		echo "export LDFLAGS=\"\$LDFLAGS $CLANG_RT_IOS\""
	fi
	echo "ac_add_options --disable-tests"
	echo "ac_add_options --enable-bootstrap"
	if [ "$USE_SCCACHE" = true ]; then
		echo "mk_add_options 'export RUSTC_WRAPPER=$SCCACHE_BIN'"
		echo "ac_add_options --with-ccache=$SCCACHE_BIN"
	fi
	if [ "$DISABLE_JEMALLOC" = true ]; then
		echo "ac_add_options --disable-jemalloc"
	fi
	if [ "$AUTO_CLOBBER" = true ]; then
		echo "mk_add_options AUTOCLOBBER=1"
	fi
} > "$FIREFOX_DIR/.mozconfig"

if ! rustup target list | grep -q "^$TARGET (installed)"; then
	rustup target add "$TARGET"
fi

cd "$FIREFOX_DIR"
./mach build

# Keep the generated mozconfig on disk (do NOT restore a stale backup):
# a leftover .mozconfig with an old --enable-ios-target makes any direct
# `./mach build` reconfigure the tree at the wrong deployment target
# (2026-09-20: merge rebuild via bare mach produced XUL minos 12.4 this way).
rm -f "$FIREFOX_DIR/.mozconfig.bak"

