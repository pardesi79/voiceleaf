# Voiceleaf 1.0

Offline audiobook reader for people who listen instead of read. No sign-in, no Google Drive, no server.

## What it does
- Create audiobooks from PDF (choose pages, optional page numbers), photos, camera (add many photos), DOCX, PPTX, XLSX, TXT, web link, pasted text, or a Voiceleaf zip backup.
- Offline text recognition with Google ML Kit: Latin, Hindi (Devanagari), Chinese, Japanese, Korean. "Auto" picks the script itself.
- Reads aloud with ANY text-to-speech engine and voice installed on the phone. The voice language is detected from the text, or you can pick one.
- Player: Go to Page, word highlight, rewind/forward 10 seconds, repeat, previous/next page, swipe on the text for previous/next word, sentence or paragraph, vertical seek bar.
- Gear menu: navigation mode, language and voice, speed, pitch, font size, preferences.
- Tools menu: share, download (audio WAV, text, ePub, DOCX, zip backup), text notes, voice notes, bookmarks, search, track reading, translate (ML Kit, offline after one download), edit page, copy text, skip text.
- App display language: English by default. Menu > Change App Display Language translates every button and message on the phone with ML Kit, into any of ~59 languages.
- Menu > Languages and offline dictionaries: download translation languages one by one or all at once.

## Not included
Password-protected PDFs, PDF export, MP3 audio, text recognition for scripts ML Kit does not support (Arabic, Tamil, Telugu, Bengali ...), spelling mode, Premium and ads.

## Build
Use the GitHub workflow (build.yml) or `flutter create` + copy lib/, assets/, pubspec.yaml, then see build.yml "Patch Android settings" for the Android changes.
