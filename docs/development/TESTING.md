# Testing Guide

ReaderPro follows **Test-Driven Development (TDD)** with the Red-Green-Refactor cycle.

## Running Tests

### Xcode

**Cmd+U** runs the full test suite.

### Command Line

```bash
xcodebuild -scheme ReaderPro -configuration Debug test
```

## Test Structure

```
ReaderPro/Tests/
├── Domain/
│   ├── AudioGeneration/
│   │   ├── Entities/
│   │   │   └── VoiceTests.swift
│   │   └── ValueObjects/
│   │       ├── TextContentTests.swift
│   │       ├── AudioDataTests.swift
│   │       ├── VoiceConfigurationTests.swift
│   │       ├── SpeechEmotionTests.swift
│   │       └── VoiceAccentTests.swift
│   ├── ProjectManagement/
│   │   ├── Entities/
│   │   │   ├── ProjectTests.swift
│   │   │   └── AudioEntryTests.swift
│   │   ├── ValueObjects/
│   │   │   ├── ProjectNameTests.swift
│   │   │   └── ProjectStatusTests.swift
│   │   └── Events/
│   │       └── DomainEventTests.swift
│   ├── AudioEditing/
│   │   └── ValueObjects/
│   │       └── TimeRangeTests.swift
│   ├── DocumentProcessing/
│   │   └── ValueObjects/
│   │       └── RecognizedTextTests.swift
│   └── Shared/
│       ├── IdentifierTests.swift
│       └── DomainErrorTests.swift
├── Application/
│   ├── GenerateAudioUseCaseTests.swift
│   ├── CreateProjectUseCaseTests.swift
│   ├── GetProjectUseCaseTests.swift
│   ├── UpdateProjectUseCaseTests.swift
│   ├── DeleteProjectUseCaseTests.swift
│   ├── ListProjectsUseCaseTests.swift
│   ├── SaveAudioEntryUseCaseTests.swift
│   └── ...
├── Infrastructure/
│   ├── KokoroONNX/
│   │   ├── KokoroTokenizerTests.swift
│   │   ├── NpyParserTests.swift
│   │   └── WAVEncoderTests.swift
│   ├── FileSystemProjectRepositoryTests.swift
│   └── ProjectMapperTests.swift
├── UI/
│   └── EditorPresenterTests.swift
└── Mocks/
    ├── MockTTSPort.swift
    ├── MockProjectRepository.swift
    ├── MockAudioStorage.swift
    ├── MockAudioPlayer.swift
    └── ...
```

## Test Count

As of 2026-02-11: **879 tests**, all passing.

## Naming Convention

```swift
func test_[method]_[condition]_[expected result]()
```

Examples:
```swift
func test_createProject_withEmptyName_shouldThrow()
func test_updateText_whenProjectHasAudio_shouldInvalidateAudio()
func test_execute_withValidRequest_shouldReturnResponse()
```

## AAA Pattern

All tests follow **Arrange-Act-Assert**:

```swift
func test_wordCount_shouldCalculateCorrectly() throws {
    // Arrange
    let text = try TextContent("Uno dos tres cuatro cinco")

    // Act
    let count = text.wordCount

    // Assert
    XCTAssertEqual(count, 5)
}
```

## Domain Tests

Domain tests require **no mocks** because the domain has zero external dependencies:

```swift
func test_addEntry_shouldEmitEvent() throws {
    // Arrange
    let project = try makeProject()
    project.clearEvents()
    let entry = AudioEntry(text: try TextContent("Test entry"))

    // Act
    try project.addEntry(entry)

    // Assert
    XCTAssertEqual(project.entries.count, 1)
    XCTAssertTrue(project.domainEvents.contains { $0 is EntryAddedEvent })
}
```

## Use Case Tests

Use case tests use mock implementations of ports:

```swift
func test_execute_withValidProject_shouldGenerateAudio() async throws {
    // Arrange
    let project = try TestFixtures.makeProject()
    mockRepository.projectToReturn = project
    mockTTS.audioDataToReturn = try AudioData(data: wavData, duration: 10.0)
    mockStorage.pathToReturn = "/audio/test.wav"

    // Act
    let response = try await sut.execute(GenerateAudioRequest(projectId: project.id))

    // Assert
    XCTAssertEqual(response.duration, 10.0)
    XCTAssertTrue(mockTTS.synthesizeCalled)
    XCTAssertTrue(mockStorage.saveCalled)
}
```

## Mock Pattern

Mocks track method calls and return configurable values:

```swift
final class MockTTSPort: TTSPort {
    var synthesizeCalled = false
    var lastText: TextContent?
    var audioDataToReturn: AudioData?
    var errorToThrow: Error?

    func synthesize(text: TextContent, voiceConfiguration: VoiceConfiguration, voice: Voice) async throws -> AudioData {
        synthesizeCalled = true
        lastText = text
        if let error = errorToThrow { throw error }
        return audioDataToReturn ?? try AudioData(data: Data([0]), duration: 1.0)
    }
    // ...
}
```

## Infrastructure Tests

Infrastructure tests verify adapter behavior:

```swift
// KokoroTokenizerTests
func test_tokenize_validPhonemes_shouldReturnTokenIds() {
    let result = tokenizer.tokenize("hɛloʊ")
    XCTAssertFalse(result.isEmpty)
}

// NpyParserTests
func test_parse_validFloat32_shouldReturnArray() throws {
    let data = makeNpyData(shape: [2, 3], values: [1, 2, 3, 4, 5, 6])
    let result = try NpyParser.parse(data)
    XCTAssertEqual(result.shape, [2, 3])
    XCTAssertEqual(result.data.count, 6)
}
```

## Writing New Tests

1. **RED:** Write a failing test for the behavior you want
2. **GREEN:** Write the minimum code to make it pass
3. **REFACTOR:** Clean up while keeping tests green

See [Adding Features](ADDING_FEATURES.md) for the complete TDD workflow when adding new functionality.
