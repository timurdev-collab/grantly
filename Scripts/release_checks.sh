#!/bin/bash
set -euo pipefail

echo "Running Grantly release checks..."

if grep -R --line-number --exclude-dir=.git   "SUPABASE_SERVICE_ROLE_KEY" Grantly 2>/dev/null; then
  echo "Service-role credentials must never be shipped in the iOS app."
  exit 1
fi

if ! grep -q "<string>1.0.0</string>" Grantly/Info.plist; then
  echo "CFBundleShortVersionString is missing or unexpected."
  exit 1
fi

if ! test -f Grantly/PrivacyInfo.xcprivacy; then
  echo "PrivacyInfo.xcprivacy is required for release builds."
  exit 1
fi

if ! grep -q "MARKETING_VERSION: 1.0.0" project.yml; then
  echo "Marketing version is not configured in project.yml."
  exit 1
fi

if ! grep -q "APP_ENVIRONMENT: production" project.yml; then
  echo "Production app environment is not configured."
  exit 1
fi

python3 Scripts/localization_checks.py\n\necho "Release checks passed."
