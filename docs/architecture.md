<!-- Version: 1.0 | Last updated: 2026-02-08 -->

# Architecture

## Overview

epub-audiobook is a four-layer iOS application that converts EPUB files into spoken audio using the system text-to-speech engine.

## Layer Diagram

```
┌─────────────────────────────────────┐
│              Views (SwiftUI)        │
├─────────────────────────────────────┤
│     Services / Coordinators         │
│  (PlaybackCoordinator, BookImport,  │
│   BookmarkService)                  │
├──────────────────┬──────────────────┤
│   EPUBParser     │   TTSEngine      │
│  (pure funcs,    │  (protocol +     │
│   value types)   │   AVSpeech impl) │
├──────────────────┴──────────────────┤
│        Models (SwiftData)           │
│  Book, Chapter, ReadingPosition,    │
│  Bookmark                           │
└─────────────────────────────────────┘
```

## Layers

### 1. Models (SwiftData)

Persistent data layer using SwiftData with `VersionedSchema` for safe migrations.

- **Book** — title, author, cover image data, file path, import date
- **Chapter** — title, content (extracted text), spine index, parent book
- **ReadingPosition** — chapter index, sentence index, parent book
- **Bookmark** — label, chapter index, sentence index, timestamp, parent book

Relationships use optional references to avoid SwiftData relationship crashes.

### 2. EPUBParser

Pure functions and value types — no SwiftData dependencies, fully testable.

- **ContainerParser** — parses `META-INF/container.xml` to find the OPF rootfile path
- **OPFParser** — parses the OPF package document for metadata (title, author, cover), manifest items, and spine reading order
- **TOCParser** — parses EPUB 2 NCX and EPUB 3 nav documents to build a chapter table of contents
- **XHTMLTextExtractor** — strips HTML using XMLParser, splits into sentences via NLTokenizer
- **EPUBParser** (coordinator) — orchestrates: ZIP extraction → container → OPF → TOC → text extraction

**External dependency:** ZIPFoundation (via SPM) for ZIP extraction. iOS has no built-in ZIP API.

### 3. TTSEngine

Protocol-based abstraction over text-to-speech, enabling testing and future engine swaps.

- **TTSEngineProtocol** — defines speak/pause/resume/stop, rate control, delegate callbacks
- **SystemTTSEngine** — wraps AVSpeechSynthesizer with iOS 17+ workarounds
- **TTSEngineDelegate** — callbacks for utterance start/finish, word range, errors
- **PlaybackState** — enum: idle, playing, paused, loading

iOS 17 AVSpeechSynthesizer workarounds:
- Target iOS 17.4+ to avoid early-release crashes
- Use sentence-level utterances (not paragraph-level) to avoid truncation
- Keep a long-lived synthesizer instance (recreating mid-session causes silence)

### 4. Services / Coordinators

Business logic that ties the layers together.

- **PlaybackCoordinator** — @Observable class managing TTS orchestration, chapter transitions, position persistence, playback state
- **BookImportService** — handles file picker interaction, copies EPUB to sandbox, triggers parsing, persists to SwiftData
- **BookmarkService** — CRUD for bookmarks, jump-to-bookmark

### 5. Views (SwiftUI)

Thin views that observe coordinators and services.

- **LibraryView** — book grid, import button, delete support
- **BookCardView** — cover image, title, author, progress
- **PlayerView** — now-playing screen with controls
- **PlaybackControlsView** — play/pause, skip forward/back
- **SpeedControlView** — rate adjustment
- **ChapterListView** — chapter navigation with current highlight
- **BookmarksListView / BookmarkRowView** — bookmark management
- **SettingsView** — voice picker, default speed

## Data Flow

1. User imports EPUB via Files app picker
2. BookImportService copies file to app sandbox
3. EPUBParser extracts and parses content
4. SwiftData persists Book + Chapters
5. User taps Play → PlaybackCoordinator feeds sentences to TTSEngine
6. TTSEngine speaks via AVSpeechSynthesizer
7. Position saved on pause/stop/chapter change

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Protocol for TTS engine | Enables MockTTSEngine for testing; future-proofs for third-party engines |
| Sentence-level utterances | Avoids AVSpeechSynthesizer truncation bugs on long text |
| VersionedSchema from day one | Prevents SwiftData migration pain later |
| Optional SwiftData relationships | Avoids known SwiftData relationship crashes |
| ZIPFoundation as sole dependency | iOS has no built-in ZIP API; this is mature, well-maintained |
| XMLParser over third-party HTML | Keeps dependencies minimal; regex fallback for malformed XHTML |
