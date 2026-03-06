import XCTest
@testable import ReaderPro

final class EspeakPhonemizerTests: XCTestCase {

    // MARK: - Integration Tests (require espeak-ng resources)

    private func makePhonemizer() throws -> EspeakPhonemizer {
        let libPath = "/Users/jesuscruz/repos2/ReaderPro/ReaderPro/Resources/espeak-ng/libespeak-ng.dylib"
        let dataPath = "/Users/jesuscruz/repos2/ReaderPro/ReaderPro/Resources/espeak-ng/espeak-ng-data"

        guard FileManager.default.fileExists(atPath: libPath) else {
            throw XCTSkip("espeak-ng library not found")
        }

        return try EspeakPhonemizer(libraryPath: libPath, dataPath: dataPath)
    }

    func test_isAvailable_whenInitialized_shouldBeTrue() throws {
        let sut = try makePhonemizer()

        XCTAssertTrue(sut.isAvailable)
    }

    func test_phonemize_englishHello_shouldReturnIPA() throws {
        let sut = try makePhonemizer()

        let phonemes = try sut.phonemize(text: "hello", language: "en-us")

        // Should produce some IPA output
        XCTAssertFalse(phonemes.isEmpty)
        // "hello" typically includes hɛloʊ or similar
        print("[EspeakTest] 'hello' → '\(phonemes)'")
    }

    func test_phonemize_spanishHola_shouldReturnIPA() throws {
        let sut = try makePhonemizer()

        let phonemes = try sut.phonemize(text: "hola mundo", language: "es")

        XCTAssertFalse(phonemes.isEmpty)
        print("[EspeakTest] 'hola mundo' → '\(phonemes)'")
    }

    func test_phonemize_frenchBonjour_shouldReturnIPA() throws {
        let sut = try makePhonemizer()

        let phonemes = try sut.phonemize(text: "bonjour", language: "fr-fr")

        XCTAssertFalse(phonemes.isEmpty)
        print("[EspeakTest] 'bonjour' → '\(phonemes)'")
    }

    func test_phonemize_longText_shouldWork() throws {
        let sut = try makePhonemizer()

        let text = "This is a longer sentence with multiple words to test phonemization."
        let phonemes = try sut.phonemize(text: text, language: "en-us")

        XCTAssertFalse(phonemes.isEmpty)
        // Should have spaces between words
        XCTAssertTrue(phonemes.contains(" ") || phonemes.count > 10)
    }

    func test_phonemize_emptyText_shouldReturnEmpty() throws {
        let sut = try makePhonemizer()

        let phonemes = try sut.phonemize(text: "", language: "en-us")

        XCTAssertTrue(phonemes.isEmpty)
    }

    // MARK: - Error Cases

    func test_init_invalidLibraryPath_shouldThrow() {
        XCTAssertThrowsError(
            try EspeakPhonemizer(
                libraryPath: "/nonexistent/libespeak-ng.dylib",
                dataPath: "/nonexistent/data"
            )
        ) { error in
            guard case EspeakPhonemizer.EspeakError.libraryNotFound = error else {
                XCTFail("Expected libraryNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Thread Safety

    func test_phonemize_concurrentCalls_shouldNotCrash() throws {
        let sut = try makePhonemizer()

        let expectation = expectation(description: "Concurrent phonemization")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<10 {
            queue.async {
                do {
                    let text = "Test sentence number \(i)"
                    let result = try sut.phonemize(text: text, language: "en-us")
                    XCTAssertFalse(result.isEmpty)
                } catch {
                    XCTFail("Phonemization failed: \(error)")
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 30)
    }
}

// MARK: - Mock for unit testing other components

final class MockEspeakPhonemizer: EspeakPhonemizerProtocol {
    var phonemizeResult: String = ""
    var phonemizeError: Error?
    var phonemizeCalled = false
    var lastText: String?
    var lastLanguage: String?
    var _isAvailable = true

    var isAvailable: Bool { _isAvailable }

    func phonemize(text: String, language: String) throws -> String {
        phonemizeCalled = true
        lastText = text
        lastLanguage = language

        if let error = phonemizeError {
            throw error
        }

        return phonemizeResult
    }
}
