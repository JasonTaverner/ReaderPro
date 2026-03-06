import Foundation
@testable import ReaderPro

/// Utilidades para crear objetos de test
/// Facilita la creación de objetos de dominio en tests
enum TestFixtures {

    // MARK: - Value Objects

    static func makeText(_ value: String = "Este es un texto de prueba") -> TextContent {
        try! TextContent(value)
    }

    static func makeProjectName(_ value: String = "Proyecto de Prueba") -> ProjectName {
        try! ProjectName(value)
    }

    static func makeVoiceConfiguration(
        voiceId: String = "voice-1",
        speed: Double = 1.0
    ) -> VoiceConfiguration {
        VoiceConfiguration(
            voiceId: voiceId,
            speed: try! VoiceConfiguration.Speed(speed)
        )
    }

    static func makeTimeRange(start: TimeInterval = 0.0, end: TimeInterval = 10.0) -> TimeRange {
        try! TimeRange(start: start, end: end)
    }

    static func makeAudioData(size: Int = 1024, duration: TimeInterval = 10.0) -> AudioData {
        let data = Data(repeating: 0, count: size)
        return try! AudioData(data: data, duration: duration)
    }

    // MARK: - Entities

    static func makeVoice(
        id: String = "voice-1",
        name: String = "Test Voice",
        language: String = "es-ES",
        provider: Voice.TTSProvider = .native,
        isDefault: Bool = true
    ) -> Voice {
        Voice(
            id: id,
            name: name,
            language: language,
            provider: provider,
            isDefault: isDefault
        )
    }

    static func makeAudioEntry(
        text: TextContent? = nil,
        audioPath: String? = nil,
        imagePath: String? = nil
    ) -> AudioEntry {
        AudioEntry(
            text: text ?? makeText(),
            audioPath: audioPath,
            imagePath: imagePath
        )
    }

    static func makeAudioSegment(
        text: TextContent? = nil,
        timeRange: TimeRange? = nil,
        audioPath: String? = nil
    ) -> AudioSegment {
        AudioSegment(
            text: text ?? makeText(),
            timeRange: timeRange ?? makeTimeRange(),
            audioPath: audioPath
        )
    }

    // MARK: - Aggregate Root

    static func makeProject(
        name: ProjectName? = nil,
        text: TextContent? = nil,
        voiceConfiguration: VoiceConfiguration? = nil,
        voice: Voice? = nil
    ) -> Project {
        let projectName = name ?? makeProjectName()
        let project = Project(
            name: projectName,
            text: text ?? makeText(),
            voiceConfiguration: voiceConfiguration ?? makeVoiceConfiguration(),
            voice: voice ?? makeVoice()
        )
        // Simulate project having been saved (folderName is set by repository on first save)
        project.updateFolderName(projectName.value)
        return project
    }

    static func makeProjectWithAudio(
        name: ProjectName? = nil,
        text: TextContent? = nil,
        audioPath: String = "/audio/test.wav"
    ) -> Project {
        var project = makeProject(name: name, text: text)
        project.markAudioGenerated(path: audioPath)
        return project
    }
}
