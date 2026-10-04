#!/bin/bash
set -euo pipefail

echo "Running EduT release checks..."

if grep -R --line-number --exclude-dir=.git   "SUPABASE_SERVICE_ROLE_KEY" Grantly 2>/dev/null; then
  echo "Service-role credentials must never be shipped in the iOS app."
  exit 1
fi

python3 - <<'PY'
import plistlib
from pathlib import Path

info = plistlib.loads(Path("Grantly/Info.plist").read_bytes())
if info.get("CFBundleDisplayName") != "EduT":
    raise SystemExit("CFBundleDisplayName must be EduT.")
if info.get("CFBundleShortVersionString") != "1.0.0":
    raise SystemExit("Unexpected CFBundleShortVersionString.")
if info.get("CFBundleVersion") != "1":
    raise SystemExit("Unexpected CFBundleVersion.")

privacy = plistlib.loads(Path("Grantly/PrivacyInfo.xcprivacy").read_bytes())
if privacy.get("NSPrivacyTracking") is not False:
    raise SystemExit("EduT must not declare tracking unless ATT is implemented.")
collected = privacy.get("NSPrivacyCollectedDataTypes", [])
if not collected:
    raise SystemExit("Privacy manifest must declare EduT's collected data.")
for item in collected:
    required = {
        "NSPrivacyCollectedDataType",
        "NSPrivacyCollectedDataTypeLinked",
        "NSPrivacyCollectedDataTypeTracking",
        "NSPrivacyCollectedDataTypePurposes",
    }
    if not required.issubset(item):
        raise SystemExit("Privacy manifest has an incomplete collected-data entry.")
PY

if ! grep -q "MARKETING_VERSION: 1.0.0" project.yml; then
  echo "Marketing version is not configured in project.yml."
  exit 1
fi

if ! grep -q "CURRENT_PROJECT_VERSION: 1" project.yml; then
  echo "Build number is not configured in project.yml."
  exit 1
fi

if ! grep -q "PRODUCT_BUNDLE_IDENTIFIER: com.grantly.app" project.yml; then
  echo "Stable production bundle identifier is missing."
  exit 1
fi

if ! grep -q "APP_ENVIRONMENT: production" project.yml; then
  echo "Production app environment is not configured."
  exit 1
fi

if ! grep -q "CODE_SIGN_ENTITLEMENTS: Grantly/Grantly.entitlements" project.yml; then
  echo "Release entitlements are not configured."
  exit 1
fi

if ! grep -q "<key>aps-environment</key>" Grantly/Grantly.entitlements; then
  echo "Production push entitlement is missing."
  exit 1
fi

APP_ICON="Grantly/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if ! test -f "$APP_ICON"; then
  echo "Production App Icon is missing."
  exit 1
fi

ICON_WIDTH=$(sips -g pixelWidth "$APP_ICON" 2>/dev/null | awk '/pixelWidth/ {print $2}')
ICON_HEIGHT=$(sips -g pixelHeight "$APP_ICON" 2>/dev/null | awk '/pixelHeight/ {print $2}')
if [[ "$ICON_WIDTH" != "1024" || "$ICON_HEIGHT" != "1024" ]]; then
  echo "Production App Icon must be exactly 1024x1024."
  exit 1
fi

ICON_BYTES=$(stat -f%z "$APP_ICON")
if [[ "$ICON_BYTES" -lt 50000 ]]; then
  echo "Production App Icon is suspiciously small; replace the placeholder/broken asset."
  exit 1
fi

python3 Scripts/localization_checks.py

echo "Release checks passed."
