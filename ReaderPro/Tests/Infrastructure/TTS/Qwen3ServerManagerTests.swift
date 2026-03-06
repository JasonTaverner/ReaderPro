import XCTest
@testable import ReaderPro

@MainActor
final class Qwen3ServerManagerTests: XCTestCase {

    var sut: Qwen3ServerManager!
    var mockSession: MockURLSession!
    var mockProcessFactory: MockProcessFactory!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockProcessFactory = MockProcessFactory()
        sut = Qwen3ServerManager(
            urlSession: mockSession,
            processFactory: mockProcessFactory,
            baseURL: URL(string: "http://localhost:8890")!,
            pythonPaths: ["/usr/bin/python3"],
            scriptSearchPaths: ["/tmp"],
            healthCheckInterval: 1.0,
            startupPollingInterval: 0.1,
            startupTimeout: 1.0
        )
    }

    override func tearDown() {
        sut = nil
        mockSession = nil
        mockProcessFactory = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialStatus_shouldBeUnknown() {
        XCTAssertEqual(sut.status, .unknown)
    }

    // MARK: - checkHealth

    func test_checkHealth_whenHealthy_shouldSetConnected() async {
        // Arrange
        mockSession.dataToReturn = #"{"status":"ok"}"#.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/health")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        await sut.checkHealth()

        // Assert
        XCTAssertEqual(sut.status, .connected)
    }

    func test_checkHealth_whenNotHealthy_shouldSetDisconnected() async {
        // Arrange
        mockSession.errorToThrow = URLError(.cannotConnectToHost)

        // Act
        await sut.checkHealth()

        // Assert
        XCTAssertEqual(sut.status, .disconnected)
    }

    func test_checkHealth_whenServerReturns503_shouldSetDisconnected() async {
        // Arrange
        mockSession.dataToReturn = Data()
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/health")!,
            statusCode: 503, httpVersion: nil, headerFields: nil
        )

        // Act
        await sut.checkHealth()

        // Assert
        XCTAssertEqual(sut.status, .disconnected)
    }

    // MARK: - stopServer

    func test_stopServer_shouldSetDisconnected() {
        // Act
        sut.stopServer()

        // Assert
        XCTAssertEqual(sut.status, .disconnected)
    }

    func test_stopServer_shouldTerminateProcess() {
        // Arrange
        let mockProcess = MockProcess()
        mockProcess.simulateIsRunning = true
        sut.setProcessForTesting(mockProcess)

        // Act
        sut.stopServer()

        // Assert
        XCTAssertTrue(mockProcess.terminateCalled)
    }

    func test_stopServer_whenNoProcess_shouldNotCrash() {
        // Act - should not throw
        sut.stopServer()

        // Assert
        XCTAssertEqual(sut.status, .disconnected)
    }

    // MARK: - startServer (already running)

    func test_startServer_whenAlreadyHealthy_shouldSetConnected() async {
        // Arrange - health check returns 200
        mockSession.dataToReturn = #"{"status":"ok"}"#.data(using: .utf8)!
        mockSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8890/health")!,
            statusCode: 200, httpVersion: nil, headerFields: nil
        )

        // Act
        await sut.startServer()

        // Assert
        XCTAssertEqual(sut.status, .connected)
    }
}
