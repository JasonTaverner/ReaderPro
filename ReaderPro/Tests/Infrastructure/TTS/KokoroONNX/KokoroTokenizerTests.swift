import XCTest
@testable import ReaderPro

final class KokoroTokenizerTests: XCTestCase {

    var sut: KokoroTokenizer!

    override func setUp() {
        super.setUp()
        sut = KokoroTokenizer()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Basic Tokenization

    func test_tokenize_simpleASCII_shouldMapCorrectly() {
        // Arrange - "hello" → h=50, e=47, l=54, l=54, o=57
        let phonemes = "hello"

        // Act
        let tokens = sut.tokenize(phonemes)

        // Assert
        XCTAssertEqual(tokens, [50, 47, 54, 54, 57])
    }

    func test_tokenize_space_shouldMapTo16() {
        // Act
        let tokens = sut.tokenize("a b")

        // Assert - a=43, space=16, b=44
        XCTAssertEqual(tokens, [43, 16, 44])
    }

    func test_tokenize_punctuation_shouldMapCorrectly() {
        // Act
        let tokens = sut.tokenize(".,!?")

        // Assert
        XCTAssertEqual(tokens, [4, 3, 5, 6]) // .=4, ,=3, !=5, ?=6
    }

    // MARK: - IPA Characters

    func test_tokenize_ipaStressMarkers_shouldMapCorrectly() {
        // ˈ = 156 (primary stress), ˌ = 157 (secondary stress)
        let tokens = sut.tokenize("\u{02C8}a\u{02CC}b")

        XCTAssertEqual(tokens, [156, 43, 157, 44])
    }

    func test_tokenize_ipaSchwa_shouldMapTo83() {
        // ə = 83
        let tokens = sut.tokenize("\u{0259}")

        XCTAssertEqual(tokens, [83])
    }

    func test_tokenize_ipaLongMark_shouldMapTo158() {
        // ː = 158
        let tokens = sut.tokenize("a\u{02D0}")

        XCTAssertEqual(tokens, [43, 158])
    }

    func test_tokenize_engma_shouldMapTo112() {
        // ŋ = 112
        let tokens = sut.tokenize("\u{014B}")

        XCTAssertEqual(tokens, [112])
    }

    // MARK: - Unknown Characters

    func test_tokenize_unknownCharacters_shouldBeDropped() {
        // 'g' (ASCII g) is not in the vocab (ɡ IPA g is 92)
        // '0', '1' are also not in the vocab
        let tokens = sut.tokenize("a0g1b")

        // Only a=43 and b=44 should survive; 'g' is not in vocab
        XCTAssertEqual(tokens, [43, 44])
    }

    func test_tokenize_emptyString_shouldReturnEmpty() {
        let tokens = sut.tokenize("")

        XCTAssertEqual(tokens, [])
    }

    func test_tokenize_allUnknown_shouldReturnEmpty() {
        let tokens = sut.tokenize("012345")

        XCTAssertEqual(tokens, [])
    }

    // MARK: - Max Length

    func test_tokenize_exceedingMaxLength_shouldTruncate() {
        // Create a string longer than 510 chars
        let phonemes = String(repeating: "a", count: 600)

        // Act
        let tokens = sut.tokenize(phonemes)

        // Assert - should be exactly 510 tokens (all 'a' = 43)
        XCTAssertEqual(tokens.count, 510)
        XCTAssertTrue(tokens.allSatisfy { $0 == 43 })
    }

    func test_tokenize_exactlyMaxLength_shouldNotTruncate() {
        let phonemes = String(repeating: "a", count: 510)

        let tokens = sut.tokenize(phonemes)

        XCTAssertEqual(tokens.count, 510)
    }

    // MARK: - Padding

    func test_addPadding_shouldWrapWithZeros() {
        // Arrange
        let tokens: [Int64] = [43, 44, 45]

        // Act
        let padded = KokoroTokenizer.addPadding(tokens)

        // Assert
        XCTAssertEqual(padded, [0, 43, 44, 45, 0])
    }

    func test_addPadding_emptyTokens_shouldReturnTwoZeros() {
        let padded = KokoroTokenizer.addPadding([])

        XCTAssertEqual(padded, [0, 0])
    }

    // MARK: - Vocab Completeness

    func test_vocab_shouldHave114Entries() {
        // config.json has 114 entries (n_token=178 is the embedding table size, not vocab count)
        XCTAssertEqual(KokoroTokenizer.vocab.count, 114)
    }

    func test_vocab_allValuesUnique() {
        let values = Array(KokoroTokenizer.vocab.values)
        let uniqueValues = Set(values)
        XCTAssertEqual(values.count, uniqueValues.count, "Vocab contains duplicate token IDs")
    }

    func test_vocab_noZeroTokenID() {
        // 0 is reserved for padding
        XCTAssertFalse(KokoroTokenizer.vocab.values.contains(0))
    }

    // MARK: - Realistic Phoneme Strings

    func test_tokenize_spanishPhonemes_shouldWork() {
        // Typical espeak-ng output for Spanish "hola mundo"
        // This is an approximation of what espeak produces
        let phonemes = "\u{02C8}ola m\u{02C8}undo"

        let tokens = sut.tokenize(phonemes)

        // Should produce non-empty tokens
        XCTAssertFalse(tokens.isEmpty)
        // First token should be primary stress marker ˈ = 156
        XCTAssertEqual(tokens.first, 156)
    }

    func test_tokenize_englishPhonemes_shouldWork() {
        // Approximation of "hello world" in IPA
        let phonemes = "h\u{0259}l\u{02C8}o\u{028A} w\u{025C}\u{02D0}ld"

        let tokens = sut.tokenize(phonemes)

        XCTAssertFalse(tokens.isEmpty)
    }
}
