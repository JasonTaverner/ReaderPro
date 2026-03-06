import XCTest
@testable import ReaderPro

/// Tests para VoiceAccent y VoiceGender Value Objects
final class VoiceAccentTests: XCTestCase {

    // MARK: - VoiceAccent allCases

    func test_allCases_shouldHave9Accents() {
        XCTAssertEqual(VoiceAccent.allCases.count, 9)
    }

    // MARK: - displayName

    func test_displayName_spanishSpain_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.spanishSpain.displayName, "Espa\u{00f1}ol (Espa\u{00f1}a)")
    }

    func test_displayName_spanishMexico_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.spanishMexico.displayName, "Espa\u{00f1}ol (M\u{00e9}xico)")
    }

    func test_displayName_spanishArgentina_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.spanishArgentina.displayName, "Espa\u{00f1}ol (Argentina)")
    }

    func test_displayName_french_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.french.displayName, "Fran\u{00e7}ais")
    }

    func test_displayName_german_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.german.displayName, "Deutsch")
    }

    func test_displayName_italian_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.italian.displayName, "Italiano")
    }

    func test_displayName_portugueseBrazil_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.portugueseBrazil.displayName, "Portugu\u{00ea}s (Brasil)")
    }

    func test_displayName_portuguesePortugal_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.portuguesePortugal.displayName, "Portugu\u{00ea}s (Portugal)")
    }

    func test_displayName_russian_shouldReturnLocalized() {
        XCTAssertEqual(VoiceAccent.russian.displayName, "\u{0420}\u{0443}\u{0441}\u{0441}\u{043a}\u{0438}\u{0439}")
    }

    // MARK: - flag

    func test_flag_eachAccent_shouldReturnNonEmpty() {
        for accent in VoiceAccent.allCases {
            XCTAssertFalse(accent.flag.isEmpty, "\(accent.rawValue) should have a flag")
        }
    }

    // MARK: - voiceDesignInstruct

    func test_voiceDesignInstruct_female_shouldContainFemaleVoice() {
        let instruct = VoiceAccent.spanishSpain.voiceDesignInstruct(gender: .female, style: nil)
        XCTAssertTrue(instruct.contains("female voice"), "Instruct: \(instruct)")
        XCTAssertTrue(instruct.contains("woman"), "Instruct should describe a woman")
    }

    func test_voiceDesignInstruct_male_shouldContainMaleVoice() {
        let instruct = VoiceAccent.french.voiceDesignInstruct(gender: .male, style: nil)
        XCTAssertTrue(instruct.contains("male voice"), "Instruct: \(instruct)")
        XCTAssertTrue(instruct.contains("man"), "Instruct should describe a man")
        XCTAssertFalse(instruct.contains("female"))
        XCTAssertFalse(instruct.contains("woman"))
    }

    func test_voiceDesignInstruct_spanishSpain_shouldContainCastilianAccent() {
        let instruct = VoiceAccent.spanishSpain.voiceDesignInstruct(gender: .female, style: nil)
        XCTAssertTrue(instruct.contains("Castilian Spanish"))
    }

    func test_voiceDesignInstruct_spanishMexico_shouldContainMexicanAccent() {
        let instruct = VoiceAccent.spanishMexico.voiceDesignInstruct(gender: .male, style: nil)
        XCTAssertTrue(instruct.contains("Mexican Spanish"))
    }

    func test_voiceDesignInstruct_withCustomStyle_shouldAppendStyle() {
        let instruct = VoiceAccent.german.voiceDesignInstruct(gender: .female, style: "cheerful")
        XCTAssertTrue(instruct.contains("cheerful"), "Instruct: \(instruct)")
    }

    func test_voiceDesignInstruct_withSpeakPrefix_shouldAppendCapitalized() {
        let instruct = VoiceAccent.italian.voiceDesignInstruct(gender: .male, style: "Speak with a happy tone")
        XCTAssertTrue(instruct.contains("Speak with a happy tone"), "Instruct: \(instruct)")
    }

    func test_voiceDesignInstruct_withoutStyle_shouldUseNaturalDefault() {
        let instruct = VoiceAccent.italian.voiceDesignInstruct(gender: .male, style: nil)
        XCTAssertTrue(instruct.contains("natural"), "Instruct: \(instruct)")
    }

    func test_voiceDesignInstruct_brazilianPortuguese_shouldContainBrazilianAccent() {
        let instruct = VoiceAccent.portugueseBrazil.voiceDesignInstruct(gender: .female, style: nil)
        XCTAssertTrue(instruct.contains("Brazilian Portuguese"))
    }

    func test_voiceDesignInstruct_female_shouldContainAge30() {
        let instruct = VoiceAccent.russian.voiceDesignInstruct(gender: .female, style: nil)
        XCTAssertTrue(instruct.contains("30"))
    }

    func test_voiceDesignInstruct_male_shouldContainAge35() {
        let instruct = VoiceAccent.russian.voiceDesignInstruct(gender: .male, style: nil)
        XCTAssertTrue(instruct.contains("35"))
    }

    // MARK: - languageCode

    func test_languageCode_spanishAccents_shouldReturnEs() {
        XCTAssertEqual(VoiceAccent.spanishSpain.languageCode, "es")
        XCTAssertEqual(VoiceAccent.spanishMexico.languageCode, "es")
        XCTAssertEqual(VoiceAccent.spanishArgentina.languageCode, "es")
    }

    func test_languageCode_french_shouldReturnFr() {
        XCTAssertEqual(VoiceAccent.french.languageCode, "fr")
    }

    func test_languageCode_german_shouldReturnDe() {
        XCTAssertEqual(VoiceAccent.german.languageCode, "de")
    }

    func test_languageCode_italian_shouldReturnIt() {
        XCTAssertEqual(VoiceAccent.italian.languageCode, "it")
    }

    func test_languageCode_portugueseAccents_shouldReturnPt() {
        XCTAssertEqual(VoiceAccent.portugueseBrazil.languageCode, "pt")
        XCTAssertEqual(VoiceAccent.portuguesePortugal.languageCode, "pt")
    }

    func test_languageCode_russian_shouldReturnRu() {
        XCTAssertEqual(VoiceAccent.russian.languageCode, "ru")
    }

    // MARK: - instruct format structure

    func test_voiceDesignInstruct_female_shouldStartWithDescribeWoman() {
        let instruct = VoiceAccent.french.voiceDesignInstruct(gender: .female, style: nil)
        XCTAssertTrue(instruct.hasPrefix("Describe a woman"), "Instruct: \(instruct)")
    }

    func test_voiceDesignInstruct_male_shouldStartWithDescribeMan() {
        let instruct = VoiceAccent.french.voiceDesignInstruct(gender: .male, style: nil)
        XCTAssertTrue(instruct.hasPrefix("Describe a man"), "Instruct: \(instruct)")
    }

    func test_voiceDesignInstruct_shouldContainNativeAccent() {
        let instruct = VoiceAccent.french.voiceDesignInstruct(gender: .male, style: nil)
        XCTAssertTrue(instruct.contains("native French accent"))
    }

    // MARK: - VoiceGender

    func test_voiceGender_allCases_shouldHave2() {
        XCTAssertEqual(VoiceGender.allCases.count, 2)
    }

    func test_voiceGender_displayName_male() {
        XCTAssertEqual(VoiceGender.male.displayName, "Male")
    }

    func test_voiceGender_displayName_female() {
        XCTAssertEqual(VoiceGender.female.displayName, "Female")
    }

    // MARK: - Equatable

    func test_voiceAccent_equality_sameValue_shouldBeEqual() {
        XCTAssertEqual(VoiceAccent.french, VoiceAccent.french)
    }

    func test_voiceAccent_equality_differentValue_shouldNotBeEqual() {
        XCTAssertNotEqual(VoiceAccent.french, VoiceAccent.german)
    }

    func test_voiceGender_equality_sameValue_shouldBeEqual() {
        XCTAssertEqual(VoiceGender.male, VoiceGender.male)
    }

    func test_voiceGender_equality_differentValue_shouldNotBeEqual() {
        XCTAssertNotEqual(VoiceGender.male, VoiceGender.female)
    }

    // MARK: - rawValue roundtrip

    func test_voiceAccent_rawValue_roundtrip() {
        for accent in VoiceAccent.allCases {
            let restored = VoiceAccent(rawValue: accent.rawValue)
            XCTAssertEqual(restored, accent)
        }
    }

    func test_voiceGender_rawValue_roundtrip() {
        for gender in VoiceGender.allCases {
            let restored = VoiceGender(rawValue: gender.rawValue)
            XCTAssertEqual(restored, gender)
        }
    }
}
