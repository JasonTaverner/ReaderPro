import SwiftUI

/// Vista de lectura sincronizada (estilo karaoke/teleprompter): muestra la frase
/// en reproducción con la palabra actual resaltada, más la frase anterior y la
/// siguiente atenuadas. No necesita scroll: las frases avanzan solas.
struct KaraokeTextView: View {

    let text: String
    let timings: [WordTiming]
    let currentTime: Double

    /// Frases como rangos de índices sobre `timings`
    private var sentences: [Range<Int>] {
        var result: [Range<Int>] = []
        var start = 0
        for (i, timing) in timings.enumerated() {
            if timing.word.hasSuffix(".") || timing.word.hasSuffix("!") || timing.word.hasSuffix("?")
                || timing.word.hasSuffix("…") || timing.word.hasSuffix(":") {
                result.append(start..<(i + 1))
                start = i + 1
            }
        }
        if start < timings.count {
            result.append(start..<timings.count)
        }
        return result
    }

    private var currentWordIndex: Int? {
        // Última palabra cuyo inicio ya pasó (binaria sería mejor; N es pequeño por frase)
        var candidate: Int? = nil
        for (i, t) in timings.enumerated() {
            if t.start <= currentTime { candidate = i } else { break }
        }
        return candidate
    }

    var body: some View {
        let sentenceRanges = sentences
        let wordIdx = currentWordIndex ?? 0
        let activeIdx = sentenceRanges.firstIndex(where: { $0.contains(wordIdx) }) ?? 0

        VStack(alignment: .leading, spacing: 6) {
            if activeIdx > 0 {
                sentenceText(range: sentenceRanges[activeIdx - 1], highlight: nil)
                    .font(.callout)
                    .foregroundColor(.appTextMuted)
                    .lineLimit(2)
            }

            sentenceText(range: sentenceRanges[activeIdx], highlight: wordIdx)
                .font(.title3)
                .foregroundColor(.appTextPrimary)

            if activeIdx + 1 < sentenceRanges.count {
                sentenceText(range: sentenceRanges[activeIdx + 1], highlight: nil)
                    .font(.callout)
                    .foregroundColor(.appTextMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appSecondary.opacity(0.6))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.15), value: wordIdx)
    }

    private func sentenceText(range: Range<Int>, highlight: Int?) -> Text {
        var result = Text("")
        for i in range {
            var word = Text(timings[i].word)
            if let highlight, i == highlight {
                word = word
                    .foregroundColor(.white)
                    .bold()
                    .underline(true, color: Color.accentColor)
            }
            result = result + word
            if i < range.upperBound - 1 {
                result = result + Text(" ")
            }
        }
        return result
    }
}
