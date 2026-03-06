import Foundation

/// Domain service for normalizing OCR-extracted text.
///
/// OCR from book pages produces artifacts like:
/// - Syllable-hyphenated words across lines ("acti-\ntud" → "actitud")
/// - Line breaks that mirror column layout instead of paragraph breaks
/// - Page numbers, headers/footers
/// - Typographic characters and invisible Unicode
///
/// This normalizer cleans the text so it reads as continuous prose,
/// which produces much better TTS output (fewer, longer segments).
struct TextNormalizer {

    /// Normalizes OCR-extracted text from books/documents.
    /// - Joins hyphenated words split across lines
    /// - Converts single line breaks to spaces (preserves paragraph breaks)
    /// - Removes page numbers, headers/footers
    /// - Cleans OCR-specific Unicode artifacts
    static func normalizeOCRText(_ text: String) -> String {
        var result = text

        // 1. Join words split by end-of-line hyphen
        // "acti-\ntud" → "actitud", "liber-\ntad" → "libertad"
        result = result.replacingOccurrences(
            of: #"(\w)-\s*\n\s*(\w)"#,
            with: "$1$2",
            options: .regularExpression
        )

        // 2. Remove standalone page numbers (e.g. "123" on its own line)
        result = result.replacingOccurrences(
            of: #"(?m)^\s*\d{1,4}\s*$"#,
            with: "",
            options: .regularExpression
        )

        // 3. Remove page headers/footers (e.g. "3 M.D)" or "CHAPTER IV")
        result = result.replacingOccurrences(
            of: #"(?m)^\s*\d+\s*[A-Z\.\)]+\s*$"#,
            with: "",
            options: .regularExpression
        )

        // 4. Convert single line breaks to spaces (keep paragraph breaks: double newline)
        result = result.replacingOccurrences(
            of: #"(?<!\n)\n(?!\n)"#,
            with: " ",
            options: .regularExpression
        )

        // 5. Collapse multiple spaces into one
        result = result.replacingOccurrences(
            of: #" {2,}"#,
            with: " ",
            options: .regularExpression
        )

        // 6. Normalize excessive paragraph breaks (3+ newlines → double newline)
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        // 7. Clean common OCR / typographic artifacts
        let replacements: [(String, String)] = [
            ("\u{00AD}", ""),   // Soft hyphen
            ("\u{200B}", ""),   // Zero-width space
            ("\u{FEFF}", ""),   // BOM
        ]
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
