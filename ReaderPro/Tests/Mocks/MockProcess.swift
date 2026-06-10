import Foundation
@testable import ReaderPro

/// Mock de ProcessProtocol para testing
final class MockProcess: ProcessProtocol {
    var executableURL: URL?
    var arguments: [String]?
    var environment: [String: String]?
    var standardInput: Any?
    var terminationHandler: (@Sendable (any ProcessProtocol) -> Void)?

    var runCalled = false
    var terminateCalled = false
    var interruptCalled = false
    var errorToThrow: Error?
    var simulateIsRunning = false

    var isRunning: Bool {
        simulateIsRunning
    }

    var terminationStatus: Int32 = 0

    var processIdentifier: Int32 = 12345

    func run() throws {
        runCalled = true
        if let error = errorToThrow {
            throw error
        }
        simulateIsRunning = true
    }

    func terminate() {
        terminateCalled = true
        simulateIsRunning = false
    }

    func interrupt() {
        interruptCalled = true
        simulateIsRunning = false
    }
}

/// Mock factory que retorna un MockProcess configurado
final class MockProcessFactory: ProcessFactoryProtocol {
    var mockProcess: MockProcess

    init(mockProcess: MockProcess = MockProcess()) {
        self.mockProcess = mockProcess
    }

    func makeProcess() -> ProcessProtocol {
        mockProcess
    }
}
