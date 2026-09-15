#!/usr/bin/env python3
"""
Injects UNO Nearby's local-networking permissions into the AndroidManifest
that `flutter create` generates.

We can't just commit our own AndroidManifest.xml and copy it over the
generated one, because the generated file contains the real package name
and theme references for the project. So instead we patch the generated
file in place: add the xmlns:tools namespace and insert our permission
block immediately before <application>.

Safe to run repeatedly — it does nothing if the permissions are already
present.
"""
import re
import sys
from pathlib import Path

MANIFEST = Path("android/app/src/main/AndroidManifest.xml")

PERMISSIONS = """
    <!-- Local networking only. No traffic ever leaves the local subnet. -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- Android ties Wi-Fi discovery to location on API <= 32; API 33+
         uses NEARBY_WIFI_DEVICES instead, which needs no location. -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
        android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
        android:usesPermissionFlags="neverForLocation"
        tools:targetApi="33" />

"""


def main() -> int:
    if not MANIFEST.exists():
        print(f"ERROR: {MANIFEST} not found. Run `flutter create --platforms=android .` first.")
        return 1

    text = MANIFEST.read_text(encoding="utf-8")

    if "NEARBY_WIFI_DEVICES" in text:
        print("Permissions already present — nothing to do.")
        return 0

    # 1. Ensure the tools namespace exists, or tools:targetApi fails the build.
    if "xmlns:tools" not in text:
        text = text.replace(
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"",
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"\n"
            "    xmlns:tools=\"http://schemas.android.com/tools\"",
            1,
        )

    # 2. Insert the permission block just before the <application> tag.
    match = re.search(r"^(\s*)<application", text, re.M)
    if not match:
        print("ERROR: no <application> tag found in the manifest.")
        return 1

    text = text[: match.start()] + PERMISSIONS + text[match.start():]

    MANIFEST.write_text(text, encoding="utf-8")
    print("Permissions injected into AndroidManifest.xml")
    return 0


if __name__ == "__main__":
    sys.exit(main())
