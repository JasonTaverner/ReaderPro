import Foundation

/// Protocol para abstraer Foundation.Process y permitir testing
protocol ProcessProtocol: AnyObject {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var environment: [String: String]? { get set }
    var standardInput: Any? { get set }
    var terminationHandler: (@Sendable (any ProcessProtocol) -> Void)? { get set }
    var isRunning: Bool { get }
    var terminationStatus: Int32 { get }

    var processIdentifier: Int32 { get }

    func run() throws
    func terminate()
    func interrupt()
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

    var standardInput: Any? {
        get { process.standardInput }
        set { process.standardInput = newValue }
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

    var processIdentifier: Int32 {
        process.processIdentifier
    }

    func run() throws {
        // Create a new process group so we can kill all children with kill(-pgid)
        process.qualityOfService = .utility
        try process.run()
        // Set the process as its own process group leader
        setpgid(process.processIdentifier, process.processIdentifier)
    }

    func terminate() {
        process.terminate()
    }

    func interrupt() {
        process.interrupt()
    }
}
