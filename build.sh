#!/usr/bin/env bash
# 构建 GODInject.ipa —— Swift UI + Objective-C 沙盒访问
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"

MIN_IOS=26.0
APP_NAME=GODInject
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
SDKVER=$(xcrun --sdk iphoneos --show-sdk-version)
echo "SDK: $SDK ($SDKVER)"

# ── 1) Objective-C 编译成 .o ──────────────────────────────
echo "== compiling Objective-C =="
OBJ_DIR="$OUT/obj"
mkdir -p "$OBJ_DIR"
for f in WQCore WQAccess WQLaunchServices; do
  echo "   $f.m"
  xcrun --sdk iphoneos clang -c -fobjc-arc -fmodules \
      -fmodules-cache-path="$OUT/ModuleCache" \
      -arch arm64 -miphoneos-version-min="$MIN_IOS" \
      -isysroot "$SDK" -O2 -Wno-unused-parameter \
      "$f.m" -o "$OBJ_DIR/$f.o"
done

# ── 2) Swift 编译 + 链接 ─────────────────────────────────
echo "== compiling Swift =="
SWIFT_SRC=$(ls Sources/*.swift)
xcrun --sdk iphoneos swiftc \
    -sdk "$SDK" \
    -target arm64-apple-ios"$MIN_IOS" \
    -import-objc-header Bridging.h \
    -O -whole-module-optimization \
    -parse-as-library \
    -module-name GODInject \
    $SWIFT_SRC \
    "$OBJ_DIR/WQCore.o" "$OBJ_DIR/WQAccess.o" "$OBJ_DIR/WQLaunchServices.o" \
    -framework UIKit -framework Foundation -framework Security \
    -o "$APP/$APP_NAME"

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
