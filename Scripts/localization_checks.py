#!/usr/bin/env python3
"""Fail CI when EduT localization coverage drifts."""

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Grantly" / "Resources"
SOURCE = ROOT / "Grantly"

LOCALES = ["en", "ru", "vi", "ar", "zh-Hans", "fr", "es", "de"]
KEY_RE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$', re.MULTILINE)
FORMAT_TOKEN_RE = re.compile(r'%(?:\d+\$)?[@df]')

VISIBLE_PATTERNS = [
    re.compile(r'Text\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'Button\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'Label\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'Section\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\.alert\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'TextField\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'Picker\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'Toggle\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'ContentUnavailableView\(\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\.accessibilityLabel\(\s*(?:Text\()?\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\.accessibilityHint\(\s*(?:Text\()?\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'\.confirmationDialog\(\s*"((?:[^"\\]|\\.)*)"'),
]

L10N_CALL_RE = re.compile(
    r'L10n\.(?:string|format)\(\s*"((?:[^"\\]|\\.)*)"'
)

def parse_locale(locale: str):
    path = RESOURCES / f"{locale}.lproj" / "Localizable.strings"
    text = path.read_text(encoding="utf-8")
    entries = KEY_RE.findall(text)
    keys = [key for key, _ in entries]

    duplicates = sorted({key for key in keys if keys.count(key) > 1})
    if duplicates:
        print(f"{locale}: duplicate localization keys: {duplicates}")
        return None

    return {key: value for key, value in entries}

def main() -> int:
    catalogs = {}
    failed = False

    for locale in LOCALES:
        catalog = parse_locale(locale)
        if catalog is None:
            failed = True
        else:
            catalogs[locale] = catalog

    if failed:
        return 1

    english = set(catalogs["en"])

    for locale in LOCALES[1:]:
        keys = set(catalogs[locale])
        missing = sorted(english - keys)
        extra = sorted(keys - english)

        if missing:
            failed = True
            print(f"{locale}: missing {len(missing)} key(s)")
            for key in missing:
                print(f"  - {key}")

        if extra:
            failed = True
            print(f"{locale}: has {len(extra)} key(s) not present in English")
            for key in extra:
                print(f"  + {key}")

        for key in sorted(english & keys):
            english_value = catalogs["en"][key]
            localized_value = catalogs[locale][key]

            english_tokens = sorted(FORMAT_TOKEN_RE.findall(english_value))
            localized_tokens = sorted(FORMAT_TOKEN_RE.findall(localized_value))
            if english_tokens != localized_tokens:
                failed = True
                print(
                    f"{locale}: format placeholders differ for {key!r}: "
                    f"{english_tokens} != {localized_tokens}"
                )

            plain_words = re.sub(FORMAT_TOKEN_RE, "", english_value)

            if (
                localized_value == english_value
                and re.search(r"[A-Za-z]", plain_words)
                and len(plain_words.split()) >= 4
            ):
                failed = True
                print(
                    f"{locale}: likely untranslated multi-word string: "
                    f"{key!r}"
                )

    missing_source_keys = set()

    for path in SOURCE.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")

        for match in L10N_CALL_RE.finditer(text):
            value = match.group(1)
            if value not in english:
                missing_source_keys.add((str(path.relative_to(ROOT)), value))

        for pattern in VISIBLE_PATTERNS:
            for match in pattern.finditer(text):
                value = match.group(1)

                # Interpolated SwiftUI strings use generated localization keys.
                # They are reviewed separately and should use L10n.format when
                # the surrounding copy needs deterministic formatting.
                if "\\(" in value:
                    continue

                if not re.search(r"[A-Za-z]", value):
                    continue

                if value.startswith("http://") or value.startswith("https://"):
                    continue

                if value not in english:
                    missing_source_keys.add((str(path.relative_to(ROOT)), value))

    if missing_source_keys:
        failed = True
        print("Visible SwiftUI strings missing from English localization:")
        for path, value in sorted(missing_source_keys):
            print(f"  {path}: {value}")

    if failed:
        return 1

    print(
        f"Localization checks passed: {len(english)} keys across "
        f"{len(LOCALES)} languages."
    )
    return 0

if __name__ == "__main__":
    sys.exit(main())
