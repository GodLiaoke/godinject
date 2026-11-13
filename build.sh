#!/usr/bin/env bash
# 构建 GOD注入器.ipa（arm64，ad-hoc 签名，带 App Group entitlement）
# 依赖：macOS + Xcode（iOS 26 SDK）
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"

MINIMUM_IOS_VERSION=26.0
APP_NAME=GODInject
BUNDLE_NAME=GODInject
FINAL_IPA=${GOD_FINAL_IPA:-GODInject.ipa}
[[ "$FINAL_IPA" != /* ]] && FINAL_IPA="$ROOT/$FINAL_IPA"

fail() { echo "build failed: $*" >&2; exit 1; }

OUT=$(mktemp -d "${TMPDIR:-/tmp}/GODInject-build.XXXXXX")
IPA_TMP=$(mktemp "${TMPDIR:-/tmp}/GODInject.ipa.XXXXXX")
rm -f -- "$IPA_TMP"
cleanup() { rm -rf -- "$OUT" "$IPA_TMP" 2>/dev/null || true; }
trap cleanup EXIT

APP="$OUT/Payload/$APP_NAME.app"
mkdir -p "$APP"

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
echo "SDK: $SDK"
xcrun --sdk iphoneos --show-sdk-version

# 只编译必要模块：沙盒访问 + LaunchServices + 我们的 UI
xcrun --sdk iphoneos clang -fobjc-arc -fmodules \
    -fmodules-cache-path="$OUT/ModuleCache" \
    -arch arm64 \
    -miphoneos-version-min="$MINIMUM_IOS_VERSION" \
    -isysroot "$SDK" \
    -Wall -Wextra -Wno-unused-parameter -O2 \
    -framework UIKit -framework Foundation -framework Security \
    WQCore.m WQAccess.m WQLaunchServices.m main.m \
    -o "$APP/$BUNDLE_NAME"

cp Info.plist "$APP/Info.plist"
plutil -convert binary1 "$APP/Info.plist"
codesign -f -s - --entitlements entitlements.plist "$APP"

codesign --verify --deep --strict "$APP"
echo "signed OK"

(cd "$OUT" && zip -qry "$IPA_TMP" Payload)
unzip -tqq "$IPA_TMP"
mv -f -- "$IPA_TMP" "$FINAL_IPA"
IPA_TMP=""
echo "wrote $FINAL_IPA"
ls -l "$FINAL_IPA"
