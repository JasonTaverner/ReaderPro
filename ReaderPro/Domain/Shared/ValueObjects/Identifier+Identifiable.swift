import Foundation

// MARK: - Identifiable Conformance

extension Identifier: Identifiable {
    public var id: UUID {
        value
    }
}
