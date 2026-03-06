import XCTest
@testable import ReaderPro

@MainActor
final class KokoroServerManagerTests: XCTestCase {

    var sut: KokoroServerManager!
    var mockURLSession: MockURLSession!
    var mockProcess: MockProcess!
    var mockProcessFactory: MockProcessFactory!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        mockProcess = MockProcess()
        mockProcessFactory = MockProcessFactory(mockProcess: mockProcess)
        sut = KokoroServerManager(
            urlSession: mockURLSession,
            processFactory: mockProcessFactory,
            healthCheckInterval: 60 // Large interval so timer doesn't fire during tests
        )
    }

    override func tearDown() {
        sut.stopServer()
        sut = nil
        mockURLSession = nil
        mockProcess = nil
        mockProcessFactory = nil
        super.tearDown()
    }

    // MARK: - Init Tests

    func test_init_shouldHaveUnknownStatus() {
        XCTAssertEqual(sut.status, .unknown)
    }

    // MARK: - checkHealth Tests

    func test_checkHealth_whenHealthy_shouldSetConnected() async {
        // Arrange
        mockURLSession.dataToReturn = Data()
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/health")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        await sut.checkHealth()

        // Assert
        XCTAssertEqual(sut.status, .connected)
    }

    func test_checkHealth_whenUnhealthy_shouldSetDisconnected() async {
        // Arrange
        mockURLSession.errorToThrow = URLError(.cannotConnectToHost)

        // Act
        await sut.checkHealth()

        // Assert
        XCTAssertEqual(sut.status, .disconnected)
    }

    func test_checkHealth_whenServerReturns500_shouldSetDisconnected() async {
        // Arrange
        mockURLSession.dataToReturn = Data()
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/health")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        await sut.checkHealth()

        // Assert
        XCTAssertEqual(sut.status, .disconnected)
    }

    // MARK: - startServer Tests

    func test_startServer_whenAlreadyHealthy_shouldSetConnected() async {
        // Arrange - server already responding
        mockURLSession.dataToReturn = Data()
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/health")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        await sut.startServer()

        // Assert
        XCTAssertEqual(sut.status, .connected)
    }

    func test_startServer_whenAlreadyHealthy_shouldNotLaunchProcess() async {
        // Arrange - server already responding
        mockURLSession.dataToReturn = Data()
        mockURLSession.responseToReturn = HTTPURLResponse(
            url: URL(string: "http://localhost:8880/health")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Act
        await sut.startServer()

        // Assert
        XCTAssertFalse(mockProcess.runCalled)
    }

    func test_startServer_shouldSetStatusToStarting() async {
        // Arrange - server not responding, and no python/script found
        mockURLSession.errorToThrow = URLError(.cannotConnectToHost)

        // We'll capture status changes
        var statusHistory: [TTSServerStatus] = []
        let cancellable = sut.$status.sink { status in
            statusHistory.append(status)
        }

        // Act
        await sut.startServer()

        // Assert - should have gone through .starting at some point
        XCTAssertTrue(statusHistory.contains(.starting))
        cancellable.cancel()
    }

    func test_startServer_whenPython3NotFound_shouldSetError() async {
        // Arrange - server not responding
        mockURLSession.errorToThrow = URLError(.cannotConnectToHost)

        // Create manager with no valid python paths
        sut = KokoroServerManager(
            urlSession: mockURLSession,
            processFactory: mockProcessFactory,
            pythonPaths: [], // No python paths
            scriptSearchPaths: ["/nonexistent"],
            healthCheckInterval: 60
        )

        // Act
        await sut.startServer()

        // Assert
        if case .error(let msg) = sut.status {
            XCTAssertTrue(msg.contains("python3"), "Error should mention python3, got: \(msg)")
        } else {
            XCTFail("Expected error status, got: \(sut.status)")
        }
    }

    func test_startServer_whenScriptNotFound_shouldSetError() async {
        // Arrange - server not responding
        mockURLSession.errorToThrow = URLError(.cannotConnectToHost)

        // Create manager with valid python but no script
        sut = KokoroServerManager(
            urlSession: mockURLSession,
            processFactory: mockProcessFactory,
            pythonPaths: ["/usr/bin/python3"], // This likely exists
            scriptSearchPaths: ["/nonexistent/path/to/scripts"],
            healthCheckInterval: 60
        )

        // Act
        await sut.startServer()

        // Assert
        if case .error(let msg) = sut.status {
            XCTAssertTrue(
                msg.contains("script") || msg.contains("python3"),
                "Error should mention script or python3, got: \(msg)"
            )
        } else {
            // If python3 doesn't exist either, error about python3 is also acceptable
            XCTAssertNotEqual(sut.status, .connected)
        }
    }

    // MARK: - stopServer Tests

    func test_stopServer_shouldTerminateProcess() async {
        // Arrange - simulate a running process
        mockURLSession.errorToThrow = URLError(.cannotConnectToHost)
        mockProcess.simulateIsRunning = true

        // Manually set process as if it was started
        sut.setProcessForTesting(mockProcess)

        // Act
        sut.stopServer()

        // Assert
        XCTAssertTrue(mockProcess.terminateCalled)
    }

    func test_stopServer_shouldSetDisconnected() async {
        // Arrange
        sut.setProcessForTesting(mockProcess)

        // Act
        sut.stopServer()

        // Assert
        XCTAssertEqual(sut.status, .disconnected)
    }

    // MARK: - startServer with process launch

    func test_startServer_whenNotRunning_shouldLaunchProcess() async {
        // Arrange
        // First call fails (not running), subsequent calls succeed (server started)
        var callCount = 0
        let session = MockURLSessionWithCallCount()
        session.onDataRequest = { _ in
            callCount += 1
            if callCount <= 1 {
                throw URLError(.cannotConnectToHost)
            }
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:8880/health")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        // Create temp script file so findServerScript succeeds
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("kokoro_server.py")
        try? "# test script".write(to: scriptPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptPath) }

        sut = KokoroServerManager(
            urlSession: session,
            processFactory: mockProcessFactory,
            pythonPaths: ["/usr/bin/python3"],
            scriptSearchPaths: [tempDir.path],
            healthCheckInterval: 60,
            startupPollingInterval: 0.1,
            startupTimeout: 2.0
        )

        // Act
        await sut.startServer()

        // Assert
        XCTAssertTrue(mockProcess.runCalled)
    }

    func test_startServer_whenServerBecomesHealthy_shouldSetConnected() async {
        // Arrange
        var callCount = 0
        let session = MockURLSessionWithCallCount()
        session.onDataRequest = { _ in
            callCount += 1
            if callCount <= 1 {
                throw URLError(.cannotConnectToHost)
            }
            let response = HTTPURLResponse(
                url: URL(string: "http://localhost:8880/health")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("kokoro_server.py")
        try? "# test script".write(to: scriptPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scriptPath) }

        sut = KokoroServerManager(
            urlSession: session,
            processFactory: mockProcessFactory,
            pythonPaths: ["/usr/bin/python3"],
            scriptSearchPaths: [tempDir.path],
            healthCheckInterval: 60,
            startupPollingInterval: 0.1,
            startupTimeout: 2.0
        )

        // Act
        await sut.startServer()

        // Assert
        XCTAssertEqual(sut.status, .connected)
    }
}

// MARK: - Helper Mock

/// Mock URLSession that uses a closure for flexible per-call behavior
final class MockURLSessionWithCallCount: URLSessionProtocol {
    var onDataRequest: ((URLRequest) async throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let handler = onDataRequest {
            return try await handler(request)
        }
        throw URLError(.cannotConnectToHost)
    }
}
