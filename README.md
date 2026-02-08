# epub-audiobook

An iOS app that plays EPUB files as audiobooks using system text-to-speech.

## Overview

epub-audiobook converts any EPUB e-book into spoken audio using Apple's AVSpeechSynthesizer. Import an EPUB from the Files app, and the app parses it into chapters and sentences, then reads them aloud with full playback controls.

## Features (MVP)

- Import EPUB files from the Files app
- Automatic chapter detection and navigation
- Play/pause/stop with skip forward/back
- Adjustable playback speed
- Bookmarking
- Position memory (resume where you left off)
- Voice selection from system voices

## Requirements

- iOS 17+
- iPhone or iPad
- Xcode 15+

## Quickstart

```bash
git clone https://github.com/tigger04/epub-audiobook.git
cd epub-audiobook
make build    # Build the project
make test     # Run tests
```

Or open `epub-audiobook/epub-audiobook.xcodeproj` in Xcode and run on a simulator.

## Project Structure

| Path | Purpose |
|------|---------|
| `epub-audiobook/` | Xcode project and source code |
| `docs/vision.md` | Product vision and goals |
| `docs/architecture.md` | Technical architecture |
| `docs/testing.md` | Testing strategy |
| `docs/implementation_plan.md` | Phased implementation plan with milestones |
| `Makefile` | Build, test, clean, release, sync targets |
| `LICENSE` | MIT licence |

## Documentation

- [Vision](docs/vision.md) — what the app does and why
- [Architecture](docs/architecture.md) — four-layer design, data flow, key decisions
- [Testing](docs/testing.md) — TDD approach, test organisation, coverage targets
- [Implementation Plan](docs/implementation_plan.md) — milestones and GitHub issues

## Make Targets

| Target | Description |
|--------|-------------|
| `make build` | Build the project |
| `make test` | Run unit and integration tests |
| `make test-ui` | Run UI/E2E tests |
| `make test-all` | Run all tests |
| `make clean` | Clean build artefacts |
| `make release VERSION=x.y` | Tag and create a GitHub release |
| `make sync` | Stage, commit, pull, and push |

## Licence

MIT — Copyright (c) 2026 Taḋg Paul. See [LICENSE](LICENSE).
