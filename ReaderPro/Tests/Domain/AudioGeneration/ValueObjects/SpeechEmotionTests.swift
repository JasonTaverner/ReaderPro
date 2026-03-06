import XCTest
@testable import ReaderPro

final class SpeechEmotionTests: XCTestCase {

    // MARK: - CaseIterable

    func test_allCases_shouldContainEightEmotions() {
        XCTAssertEqual(SpeechEmotion.allCases.count, 8)
    }

    func test_allCases_shouldIncludeExpectedEmotions() {
        let rawValues = SpeechEmotion.allCases.map(\.rawValue)
        XCTAssertTrue(rawValues.contains("neutral"))
        XCTAssertTrue(rawValues.contains("happy"))
        XCTAssertTrue(rawValues.contains("sad"))
        XCTAssertTrue(rawValues.contains("angry"))
        XCTAssertTrue(rawValues.contains("whisper"))
        XCTAssertTrue(rawValues.contains("excited"))
        XCTAssertTrue(rawValues.contains("calm"))
        XCTAssertTrue(rawValues.contains("fearful"))
    }

    // MARK: - Display Names

    func test_displayName_neutral_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.neutral.displayName, "Neutral")
    }

    func test_displayName_happy_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.happy.displayName, "Happy")
    }

    func test_displayName_sad_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.sad.displayName, "Sad")
    }

    func test_displayName_angry_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.angry.displayName, "Angry")
    }

    func test_displayName_whisper_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.whisper.displayName, "Whisper")
    }

    func test_displayName_excited_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.excited.displayName, "Excited")
    }

    func test_displayName_calm_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.calm.displayName, "Calm")
    }

    func test_displayName_fearful_shouldReturnLocalizedName() {
        XCTAssertEqual(SpeechEmotion.fearful.displayName, "Fearful")
    }

    // MARK: - Instruct Text

    func test_instruct_neutral_shouldReturnNil() {
        XCTAssertNil(SpeechEmotion.neutral.instruct)
    }

    func test_instruct_happy_shouldReturnNonEmpty() {
        let instruct = SpeechEmotion.happy.instruct
        XCTAssertNotNil(instruct)
        XCTAssertFalse(instruct!.isEmpty)
    }

    func test_instruct_allNonNeutral_shouldReturnNonEmpty() {
        for emotion in SpeechEmotion.allCases where emotion != .neutral {
            XCTAssertNotNil(emotion.instruct, "\(emotion.rawValue) should have instruct text")
            XCTAssertFalse(emotion.instruct!.isEmpty, "\(emotion.rawValue) instruct should not be empty")
        }
    }

    // MARK: - Equatable

    func test_equatable_sameEmotion_shouldBeEqual() {
        XCTAssertEqual(SpeechEmotion.happy, SpeechEmotion.happy)
    }

    func test_equatable_differentEmotions_shouldNotBeEqual() {
        XCTAssertNotEqual(SpeechEmotion.happy, SpeechEmotion.sad)
    }

    // MARK: - Raw Value Round-Trip

    func test_rawValue_roundTrip_shouldReconstitute() {
        for emotion in SpeechEmotion.allCases {
            let reconstituted = SpeechEmotion(rawValue: emotion.rawValue)
            XCTAssertEqual(reconstituted, emotion)
        }
    }

    func test_rawValue_invalid_shouldReturnNil() {
        XCTAssertNil(SpeechEmotion(rawValue: "nonexistent"))
    }
}
