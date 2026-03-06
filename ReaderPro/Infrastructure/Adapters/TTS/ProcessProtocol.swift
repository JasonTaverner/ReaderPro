import Foundation

/// Protocol para abstraer Foundation.Process y permitir testing
protocol ProcessProtocol: AnyObject {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var environment: [String: String]? { get set }
    var terminationHandler: (@Sendable (any ProcessProtocol) -> Void)? { get set }
    var isRunning: Bool { get }
    var terminationStatus: Int32 { get }

    func run() throws
    func terminate()
}

/// Factory protocol para crear procesos (inyectable para testing)
protocol ProcessFactoryProtocol {
    func makeProcess() -> ProcessProtocol
}

/// Factory por defecto que crea Foundation.Process
final class ProcessFactory: ProcessFactoryProtocol {
    func makeProcess() -> ProcessProtocol {
        ProcessWrapper()
    }
}

/// Wrapper alrededor de Foundation.Process que conforma ProcessProtocol
/// Necesario porque Process.terminationHandler tiene tipo diferente al del protocolo
final class ProcessWrapper: ProcessProtocol {
    private let process = Process()

    var executableURL: URL? {
        get { process.executableURL }
        set { process.executableURL = newValue }
    }

    var arguments: [String]? {
        get { process.arguments }
        set { process.arguments = newValue }
    }

    var environment: [String: String]? {
        get { process.environment }
        set { process.environment = newValue }
    }

    var terminationHandler: (@Sendable (any ProcessProtocol) -> Void)? {
        didSet {
            if let handler = terminationHandler {
                process.terminationHandler = { [weak self] _ in
                    guard let self else { return }
                    handler(self)
                }
            } else {
                process.terminationHandler = nil
            }
        }
    }

    var isRunning: Bool {
        process.isRunning
    }

    var terminationStatus: Int32 {
        process.terminationStatus
    }

    func run() throws {
        try process.run()
    }

    func terminate() {
        process.terminate()
    }
}
