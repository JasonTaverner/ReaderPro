import Foundation

/// Protocol for tokenizing IPA phoneme strings into token IDs
protocol KokoroTokenizerProtocol {
    /// Convert an IPA phoneme string to token IDs
    /// - Parameter phonemes: IPA phoneme string from espeak-ng
    /// - Returns: Array of Int64 token IDs (without padding)
    func tokenize(_ phonemes: String) -> [Int64]
}

/// Character-level tokenizer for Kokoro TTS
/// Maps individual IPA characters to token IDs using the vocab from config.json
/// Unknown characters are silently ignored (same behavior as Python implementation)
final class KokoroTokenizer: KokoroTokenizerProtocol {

    // MARK: - Constants

    /// Maximum phoneme length before truncation (from config.py)
    static let maxPhonemeLength = 510

    // MARK: - Vocab

    /// Hardcoded vocab from kokoro-onnx config.json (114 entries, n_token=178)
    /// Maps IPA character → token ID
    static let vocab: [Character: Int64] = [
        ";": 1,
        ":": 2,
        ",": 3,
        ".": 4,
        "!": 5,
        "?": 6,
        "\u{2014}": 9,    // —  (em dash)
        "\u{2026}": 10,   // …  (ellipsis)
        "\"": 11,
        "(": 12,
        ")": 13,
        "\u{201C}": 14,   // "  (left double quote)
        "\u{201D}": 15,   // "  (right double quote)
        " ": 16,
        "\u{0303}": 17,   // ̃   (combining tilde)
        "\u{02A3}": 18,   // ʣ
        "\u{02A5}": 19,   // ʥ
        "\u{02A6}": 20,   // ʦ
        "\u{02A8}": 21,   // ʨ
        "\u{1D5D}": 22,   // ᵝ
        "\u{AB67}": 23,   // ꭧ
        "A": 24,
        "I": 25,
        "O": 31,
        "Q": 33,
        "S": 35,
        "T": 36,
        "W": 39,
        "Y": 41,
        "\u{1D4A}": 42,   // ᵊ
        "a": 43,
        "b": 44,
        "c": 45,
        "d": 46,
        "e": 47,
        "f": 48,
        "h": 50,
        "i": 51,
        "j": 52,
        "k": 53,
        "l": 54,
        "m": 55,
        "n": 56,
        "o": 57,
        "p": 58,
        "q": 59,
        "r": 60,
        "s": 61,
        "t": 62,
        "u": 63,
        "v": 64,
        "w": 65,
        "x": 66,
        "y": 67,
        "z": 68,
        "\u{0251}": 69,   // ɑ
        "\u{0250}": 70,   // ɐ
        "\u{0252}": 71,   // ɒ
        "\u{00E6}": 72,   // æ
        "\u{03B2}": 75,   // β
        "\u{0254}": 76,   // ɔ
        "\u{0255}": 77,   // ɕ
        "\u{00E7}": 78,   // ç
        "\u{0256}": 80,   // ɖ
        "\u{00F0}": 81,   // ð
        "\u{02A4}": 82,   // ʤ
        "\u{0259}": 83,   // ə
        "\u{025A}": 85,   // ɚ
        "\u{025B}": 86,   // ɛ
        "\u{025C}": 87,   // ɜ
        "\u{025F}": 90,   // ɟ
        "\u{0261}": 92,   // ɡ
        "\u{0265}": 99,   // ɥ
        "\u{0268}": 101,  // ɨ
        "\u{026A}": 102,  // ɪ
        "\u{029D}": 103,  // ʝ
        "\u{026F}": 110,  // ɯ
        "\u{0270}": 111,  // ɰ
        "\u{014B}": 112,  // ŋ
        "\u{0273}": 113,  // ɳ
        "\u{0272}": 114,  // ɲ
        "\u{0274}": 115,  // ɴ
        "\u{00F8}": 116,  // ø
        "\u{0278}": 118,  // ɸ
        "\u{03B8}": 119,  // θ
        "\u{0153}": 120,  // œ
        "\u{0279}": 123,  // ɹ
        "\u{027E}": 125,  // ɾ
        "\u{027B}": 126,  // ɻ
        "\u{0281}": 128,  // ʁ
        "\u{027D}": 129,  // ɽ
        "\u{0282}": 130,  // ʂ
        "\u{0283}": 131,  // ʃ
        "\u{0288}": 132,  // ʈ
        "\u{02A7}": 133,  // ʧ
        "\u{028A}": 135,  // ʊ
        "\u{028B}": 136,  // ʋ
        "\u{028C}": 138,  // ʌ
        "\u{0263}": 139,  // ɣ
        "\u{0264}": 140,  // ɤ
        "\u{03C7}": 142,  // χ
        "\u{028E}": 143,  // ʎ
        "\u{0292}": 147,  // ʒ
        "\u{0294}": 148,  // ʔ
        "\u{02C8}": 156,  // ˈ  (primary stress)
        "\u{02CC}": 157,  // ˌ  (secondary stress)
        "\u{02D0}": 158,  // ː  (long)
        "\u{02B0}": 162,  // ʰ  (aspiration)
        "\u{02B2}": 164,  // ʲ  (palatalization)
        "\u{2193}": 169,  // ↓
        "\u{2192}": 171,  // →
        "\u{2197}": 172,  // ↗
        "\u{2198}": 173,  // ↘
        "\u{1D7B}": 177,  // ᵻ
    ]

    // MARK: - Tokenization

    func tokenize(_ phonemes: String) -> [Int64] {
        // Truncate to max length (same as Python)
        let truncated = String(phonemes.prefix(KokoroTokenizer.maxPhonemeLength))

        // Character-level tokenization: map each char to its token ID
        // Unknown chars are silently dropped (same behavior as Python)
        return truncated.compactMap { KokoroTokenizer.vocab[$0] }
    }

    /// Wrap token IDs with padding token 0 for model input
    /// - Parameter tokens: Raw token IDs from tokenize()
    /// - Returns: [0] + tokens + [0] as required by the ONNX model
    static func addPadding(_ tokens: [Int64]) -> [Int64] {
        [0] + tokens + [0]
    }
}
