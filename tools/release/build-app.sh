#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PROJECT_PATH="$ROOT_DIR/browser/Reynard.xcodeproj"
XCCONFIG_PATH="$ROOT_DIR/browser/Configuration/Reynard.xcconfig"
BUILD_XCCONFIG_PATH="$DIST_DIR/Reynard.xcconfig"

NO_SIGNING=false
NIGHTLY=false

for argument in "$@"; do
	case "$argument" in
		--no-signing)
			NO_SIGNING=true
			;;
		--nightly)
			NIGHTLY=true
			;;
		*) ;;
	esac
done

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

cp "$XCCONFIG_PATH" "$BUILD_XCCONFIG_PATH"

BUILD_SHA=$(git -C "$ROOT_DIR" rev-parse HEAD | cut -c1-7)
sed -i '' -E \
	-e "s|^CURRENT_BUILD = .*|CURRENT_BUILD = $BUILD_SHA|" \
	"$BUILD_XCCONFIG_PATH"

if [ "$NIGHTLY" = true ]; then
	sed -i '' -E \
	-e 's|^(CURRENT_VERSION = [0-9.]+)$|\1-dev|' \
	-e 's|^APP_DISPLAY_NAME = .*|APP_DISPLAY_NAME = Reynard (Nightly)|' \
	"$BUILD_XCCONFIG_PATH"
fi

run_xcodebuild() {
	xcodebuild archive \
		-scheme "Reynard" \
		-archivePath "$DIST_DIR/Reynard.xcarchive" \
		-project "$PROJECT_PATH" \
		-sdk iphoneos \
		-arch arm64 \
		-configuration Release \
		-xcconfig "$BUILD_XCCONFIG_PATH" \
		"$@"
}

if [ "$NO_SIGNING" = true ]; then
	run_xcodebuild \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE_SPECIFIER=""

	# Strip bitcode because the archive bypasses signing: https://developer.apple.com/documentation/Xcode-Release-Notes/xcode-13_3_1-release-notes?changes=_1
	# NOTE (iOS 12 port): the Concurrency runtime may be absent — @MainActor was
	# removed tree-wide, so nothing links libswift_Concurrency. Guard for that.
	SWIFT_CONCURRENCY_PATH="$DIST_DIR/Reynard.xcarchive/Products/Applications/Reynard.app/Frameworks/libswift_Concurrency.dylib"
	if [ -f "$SWIFT_CONCURRENCY_PATH" ]; then
		xcrun bitcode_strip "$SWIFT_CONCURRENCY_PATH" -r -o "$SWIFT_CONCURRENCY_PATH"
		/usr/bin/codesign --force --sign - --verbose "$SWIFT_CONCURRENCY_PATH"
	fi
else
	run_xcodebuild
fi
