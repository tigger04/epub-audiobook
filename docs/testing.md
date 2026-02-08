<!-- Version: 1.0 | Last updated: 2026-02-08 -->

# Testing Strategy

## Overview

We practise TDD. Every feature starts with a failing test. All tests run via `make test`.

## Test Targets

| Target | Contents | Runner |
|--------|----------|--------|
| `epub-audiobook-tests` | Unit + integration tests | `xcodebuild test` |
| `epub-audiobook-uitests` | End-to-end UI tests | `xcodebuild test` (UI) |

## Test Boundaries

| Type | Scope | Speed | Location |
|------|-------|-------|----------|
| Unit | Single function/struct | < 100ms | `epub-audiobook-tests/` |
| Integration | Multiple components together | < 5s | `epub-audiobook-tests/` |
| End-to-end | Full app flow in simulator | Slow | `epub-audiobook-uitests/` |

## Test Organisation

```
epub-audiobook-tests/
├── EPUBParser/
│   ├── ContainerParserTests.swift
│   ├── OPFParserTests.swift
│   ├── TOCParserTests.swift
│   ├── XHTMLTextExtractorTests.swift
│   ├── EPUBParserIntegrationTests.swift
│   └── TestData/
│       ├── container.xml
│       ├── sample.opf
│       ├── toc.ncx
│       ├── nav.xhtml
│       ├── chapter1.xhtml
│       └── minimal.epub
├── TTSEngine/
│   ├── MockTTSEngine.swift
│   └── SystemTTSEngineTests.swift
├── Services/
│   ├── PlaybackCoordinatorTests.swift
│   └── BookImportServiceTests.swift
└── Models/
    ├── BookTests.swift
    └── SchemaTests.swift
```

## Test Naming Convention

```
test_<unit>_<scenario>_<expected_result>
```

Examples:
- `test_containerParser_validXML_returnsOPFPath`
- `test_opfParser_missingTitle_usesFilename`
- `test_playbackCoordinator_lastChapterEnds_stopsPlayback`

## Test Structure

Follow Arrange-Act-Assert (AAA):

```swift
func test_containerParser_validXML_returnsOPFPath() {
    // Arrange
    let xml = TestData.loadFixture("container.xml")

    // Act
    let result = ContainerParser.parse(xml)

    // Assert
    XCTAssertEqual(result.opfPath, "OEBPS/content.opf")
}
```

## Mocking Policy

Following project standards — mock external dependencies, not the code under test.

**MockTTSEngine** is acceptable: it implements TTSEngineProtocol to test PlaybackCoordinator without needing AVSpeechSynthesizer (which requires a real device).

**Not acceptable:** mocking SwiftData in model tests — use an in-memory ModelContainer instead.

## Test Data

- Fixture files in `TestData/` directories alongside tests
- Minimal valid EPUB for integration tests (hand-crafted, minimal)
- No production data in tests

## Coverage Targets

- EPUBParser: 90%+ (critical path, pure logic)
- Models: 80%+ (CRUD operations)
- Services: 80%+ (business logic)
- Views: tested via UI tests (not unit-testable in isolation)

## Running Tests

```bash
make test          # All unit + integration tests
make test-ui       # UI/E2E tests (requires simulator)
make test-all      # Everything
```
