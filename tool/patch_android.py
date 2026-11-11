#!/usr/bin/env python3
"""Prepares the generated Android project for Voiceleaf.

Runs after `flutter create`, before `flutter build`. Safe to run twice.
"""

import os
import re
import sys

MANIFEST = "android/app/src/main/AndroidManifest.xml"
GRADLE_GROOVY = "android/app/build.gradle"
GRADLE_KTS = "android/app/build.gradle.kts"

PERMISSIONS = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE"/>
        </intent>
    </queries>
"""


def patch_manifest():
    if not os.path.exists(MANIFEST):
        print("ERROR: %s not found" % MANIFEST)
        return False
    with open(MANIFEST, encoding="utf-8") as f:
        xml = f.read()

    if "android.permission.CAMERA" not in xml:
        xml = xml.replace("<application", PERMISSIONS.strip() + "\n\n    <application", 1)

    # App name shown under the launcher icon.
    xml = re.sub(r'android:label="[^"]*"', 'android:label="Voiceleaf"', xml, count=1)

    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write(xml)
    print("manifest patched")
    return True


def patch_gradle():
    for path, pattern, repl in [
        (GRADLE_GROOVY, r"minSdk\s*=?\s*(flutter\.minSdkVersion|\d+)", "minSdk 21"),
        (GRADLE_GROOVY, r"minSdkVersion\s+(flutter\.minSdkVersion|\d+)", "minSdkVersion 21"),
        (GRADLE_KTS, r"minSdk\s*=\s*(flutter\.minSdkVersion|\d+)", "minSdk = 21"),
    ]:
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            text = f.read()
        new = re.sub(pattern, repl, text, count=1)
        if new != text:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new)
            print("%s patched" % path)
            return True
    print("WARNING: could not find minSdk in either gradle file")
    return False


if __name__ == "__main__":
    ok_manifest = patch_manifest()
    patch_gradle()
    sys.exit(0 if ok_manifest else 1)
