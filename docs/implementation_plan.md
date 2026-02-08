<!-- Version: 1.0 | Last updated: 2026-02-08 -->

# Implementation Plan

## Milestones

### Milestone 1: Foundation — Project Scaffolding + EPUB Parser

| Issue | Title | Description |
|-------|-------|-------------|
| #1 | Create Xcode project scaffolding | SwiftUI app lifecycle, .gitignore, Makefile, README, docs, add ZIPFoundation via SPM |
| #2 | Implement container.xml parser | Parse META-INF/container.xml to extract OPF rootfile path. Unit tests with fixture XML |
| #3 | Implement OPF parser | Parse OPF for metadata (title, author, cover), manifest items, spine reading order. Unit tests |
| #4 | Implement TOC parser (NCX + EPUB 3 nav) | Parse EPUB 2 NCX and EPUB 3 nav documents to build chapter TOC. Unit tests |
| #5 | Implement XHTML text extractor | XMLParser-based HTML stripping + NLTokenizer sentence splitting. Unit tests |
| #6 | Implement top-level EPUBParser coordinator | Wire ZIP extraction -> container -> OPF -> TOC -> text extraction. Integration test with minimal EPUB fixture |

### Milestone 2: Data Layer + Book Import

| Issue | Title | Description |
|-------|-------|-------------|
| #7 | Define SwiftData models with VersionedSchema | Book, Chapter, ReadingPosition, Bookmark @Models. SchemaV1 + MigrationPlan. CRUD tests |
| #8 | Implement book import from Files app | BookImportService: file picker (UTType.epub), copy to sandbox, parse, persist. Tests |

### Milestone 3: TTS Engine + Playback

| Issue | Title | Description |
|-------|-------|-------------|
| #9 | Define TTS engine protocol and delegate | TTSEngine protocol, TTSEngineDelegate, Utterance type, PlaybackState enum |
| #10 | Implement SystemTTSEngine with AVSpeechSynthesizer | AVSpeech wrapper with iOS 17 workarounds, rate mapping, audio session. Tests |
| #11 | Implement PlaybackCoordinator | @Observable coordinator: TTS orchestration, chapter transitions, position persistence. Tests with MockTTSEngine |
| #12 | Create player view with playback controls | PlayerView, PlaybackControlsView, SpeedControlView. Wire to coordinator |

### Milestone 4: Library UI + Navigation + Bookmarks

| Issue | Title | Description |
|-------|-------|-------------|
| #13 | Create library view with book grid | LibraryView + BookCardView. Import button, delete support |
| #14 | Implement chapter navigation | ChapterListView with current chapter highlight, tap-to-jump |
| #15 | Implement bookmark management | BookmarkService + BookmarksListView + BookmarkRowView. Create/delete/jump |
| #16 | Implement settings with voice selection | SettingsView: voice picker, default speed preference |
| #17 | Implement resume-on-launch | Check for existing ReadingPosition, offer to resume |
| #18 | Add UI tests for import-to-playback flow | E2E tests: import -> library -> playback -> bookmarks |

### Milestone 5: Stretch Goals (post-MVP)

| Issue | Title | Description |
|-------|-------|-------------|
| #19 | Add background audio support | UIBackgroundModes, audio session for background AVSpeech |
| #20 | Add lock screen and control centre controls | MPNowPlayingInfoCenter + MPRemoteCommandCenter |
| #21 | Add sleep timer | SleepTimerService + SleepTimerView (15/30/45/60 min + end of chapter) |
| #22 | Add synchronized text highlighting | Use willSpeakRangeOfSpeechString delegate to highlight current word |

## Verification After Each Milestone

1. `make test` — all unit and integration tests pass
2. `make build` — clean build with no warnings
3. Manual smoke test on iOS Simulator (iPhone 16, iOS 17.x)
4. For Milestone 3+: open a sample EPUB and verify audible playback

## Key Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| AVSpeechSynthesizer bugs on iOS 17 (crashes, truncation, silence) | HIGH | Target iOS 17.4+, sentence-level utterances, long-lived synthesizer instance, abstract behind protocol |
| SwiftData rough edges (relationship crashes, migration) | MEDIUM | Optional relationships, VersionedSchema from day one, thorough tests |
| Malformed XHTML in EPUBs | MEDIUM | XMLParser primary, regex fallback for broken files |
