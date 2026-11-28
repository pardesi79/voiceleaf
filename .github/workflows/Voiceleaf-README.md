# Voiceleaf

An audiobook reader for people who listen instead of read. It turns a PDF,
a scan, a photo or a document into speech, on the phone, in the language it
was written in.

**Works offline. Online is optional.**

Everything Voiceleaf does — reading a PDF, recognising the text, speaking it —
happens on the phone with no internet. Two things use the network, and only
when you ask for them:

- **Sharper scans.** A photographed or scanned page can be sent for online
  recognition, which reads small and faint print better than the on-phone
  engine. It is off by default, needs a one-time sign-in, and the temporary
  copy is deleted straight after the text comes back.
- **Translation languages.** Downloading a language for translation is a
  one-time download; after that it works offline.

Nothing else leaves the phone. There is no server of ours, no account to
create, and no reading history is uploaded.

## What it does

- **Make an audiobook from** a PDF (pick pages, optional page numbers), photos,
  the camera, DOCX, PPTX, XLSX, TXT, a web link, pasted text, or a Voiceleaf
  backup file.
- **Text recognition on the phone** with ML Kit, for Latin, Hindi (Devanagari),
  Chinese, Japanese and Korean. "Auto" picks the script itself.
- **Legacy Hindi fonts** (Kruti Dev, DevLys, Walkman-Chanakya and similar) are
  turned back into real Devanagari, so older textbooks read properly instead
  of spelling out raw font codes.
- **Reads aloud with any speech engine** and voice already on the phone. The
  language is detected from the text, or you pick one.
- **Player:** go to page, word highlight, rewind and forward ten seconds,
  repeat, previous and next page, swipe for the previous or next word,
  sentence or paragraph, vertical seek bar.
- **Gear menu:** navigation mode, language and voice, speed, pitch, font size,
  preferences.
- **Tools menu:** share, download (WAV audio, text, ePub, DOCX, backup),
  text notes, voice notes, bookmarks, search, reading progress, translate,
  edit a page, copy text, skip text.
- **App display language:** English by default. Any of about 59 languages can
  be chosen, and the buttons and messages are translated on the phone.
- **Languages and offline dictionaries:** download translation languages one
  at a time or all at once.

## Not included

Password-protected PDFs, PDF export, MP3 audio, recognition for scripts ML Kit
does not cover (Arabic, Tamil, Telugu, Bengali and others), spelling mode,
premium tiers and ads.

## Build

Use the GitHub workflow, or run `flutter create`, copy `lib/`, `assets/` and
`pubspec.yaml`, then apply the Android changes from the workflow.

## Licence

See the repository for licence terms.
