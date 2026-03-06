import Foundation

/// Port for persisting and retrieving saved cloned voice profiles.
/// Each profile stores a reference audio file + transcript for voice cloning.
protocol ClonedVoiceRepositoryPort {
    func save(_ profile: ClonedVoiceProfile, audioData: Data) async throws
    func findAll() async throws -> [ClonedVoiceProfile]
    func findById(_ id: String) async throws -> ClonedVoiceProfile?
    func delete(_ id: String) async throws
    func audioURL(for profile: ClonedVoiceProfile) -> URL
    var baseDirectory: URL { get }
}
