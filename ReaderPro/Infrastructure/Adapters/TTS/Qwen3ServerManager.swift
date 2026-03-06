import Foundation
import Combine

/// Gestiona el ciclo de vida del servidor Qwen3-TTS MLX (proceso Python local)
///
/// Verifica si el servidor responde en localhost:8890, lo lanza automáticamente
/// si no responde, y monitoriza su estado con health checks periódicos.
@MainActor
final class Qwen3ServerManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var status: TTSServerStatus = .unknown

    // MARK: - Dependencies

    private let urlSession: URLSessionProtocol
    private let processFactory: ProcessFactoryProtocol
    private let baseURL: URL
    private let pythonPaths: [String]
    private let scriptSearchPaths: [String]
    private let healthCheckInterval: TimeInterval
    private let startupPollingInterval: TimeInterval
    private let startupTimeout: TimeInterval

    // MARK: - Internal State

    private var serverProcess: ProcessProtocol?
    private var healthTimer: Timer?

    // MARK: - Initialization

    init(
        urlSession: URLSessionProtocol = URLSession.shared,
        processFactory: ProcessFactoryProtocol = ProcessFactory(),
        baseURL: URL = URL(string: "http://127.0.0.1:8890")!,
        pythonPaths: [String]? = nil,
        scriptSearchPaths: [String]? = nil,
        healthCheckInterval: TimeInterval = 120.0,
        startupPollingInterval: TimeInterval = 3.0,
        startupTimeout: TimeInterval = 60.0
    ) {
        self.urlSession = urlSession
        self.processFactory = processFactory
        self.baseURL = baseURL
        self.pythonPaths = pythonPaths ?? Self.defaultPythonPaths()
        self.scriptSearchPaths = scriptSearchPaths ?? Self.defaultScriptSearchPaths()
        self.healthCheckInterval = healthCheckInterval
        self.startupPollingInterval = startupPollingInterval
        self.startupTimeout = startupTimeout
    }

    // MARK: - Public API

    /// Verifica si el servidor está corriendo; si no, lo lanza automáticamente.
    /// Tries bundled standalone executable first, then falls back to Python script.
    func startServer() async {
        // Skip if already connected or in the middle of starting
        if case .connected = status { return }
        if case .starting = status { return }

        // 1. Check if already running
        let healthy = await isHealthy()
        if healthy {
            status = .connected
            startHealthTimer()
            print("[Qwen3Server] Already running on \(baseURL.absoluteString)")
            return
        }

        // 2. Try to launch
        status = .starting
        let portArg = "\(baseURL.port ?? 8890)"
        print("[Qwen3Server] Server not responding, attempting to launch...")

        // Try 1: Bundled standalone executable (PyInstaller build)
        if let execPath = findBundledExecutable() {
            print("[Qwen3Server] Found bundled executable at: \(execPath)")
            let launched = await launchProcess(
                executablePath: execPath,
                arguments: ["--port", portArg]
            )
            if launched { return }
            print("[Qwen3Server] Bundled executable failed, trying Python fallback...")
        }

        // Try 2: Python script (development / manual setup)
        guard let pythonPath = findPython3() else {
            status = .error("Qwen3 server not found. Reinstall the app or install Python 3.")
            print("[Qwen3Server] Error: no bundled executable and python3 not found")
            return
        }

        guard let scriptPath = findServerScript() else {
            status = .error("qwen3_mlx_server.py script not found.")
            print("[Qwen3Server] Error: qwen3_mlx_server.py not found")
            return
        }

        let launched = await launchProcess(
            executablePath: pythonPath,
            arguments: [scriptPath, "--port", portArg]
        )
        if !launched {
            status = .error("Server failed to start within \(Int(startupTimeout))s. Model may still be loading.")
            print("[Qwen3Server] Startup timeout after \(Int(startupTimeout))s")
        }
    }

    /// Para el servidor y limpia recursos
    func stopServer() {
        healthTimer?.invalidate()
        healthTimer = nil

        if let process = serverProcess {
            if process.isRunning {
                process.terminate()
                print("[Qwen3Server] Process terminated")
            }
            serverProcess = nil
        }

        status = .disconnected
    }

    /// Ejecuta un health check puntual y actualiza el estado
    func checkHealth() async {
        let healthy = await isHealthy()
        if healthy {
            status = .connected
        } else {
            status = .disconnected
            // Stop polling when server goes down to avoid network noise
            healthTimer?.invalidate()
            healthTimer = nil
        }
    }

    /// Stops the periodic health timer without stopping the server process.
    /// Used when this provider is no longer active to reduce idle network noise.
    func stopHealthPolling() {
        healthTimer?.invalidate()
        healthTimer = nil
    }

    // MARK: - Testing Support

    func setProcessForTesting(_ process: ProcessProtocol) {
        serverProcess = process
    }

    // MARK: - Private

    /// Searches for a bundled standalone executable (PyInstaller build) inside the app bundle
    /// or beside the .app directory.
    private func findBundledExecutable() -> String? {
        let fileManager = FileManager.default
        let execName = "qwen3_server"

        // 1. Inside app bundle: .app/Contents/Resources/servers/qwen3_server/qwen3_server
        if let resourcePath = Bundle.main.resourcePath {
            let bundledPath = (resourcePath as NSString)
                .appendingPathComponent("servers/qwen3_server/\(execName)")
            if fileManager.isExecutableFile(atPath: bundledPath) {
                return bundledPath
            }
        }

        // 2. Beside .app: ../servers/qwen3_server/qwen3_server
        if let execURL = Bundle.main.executableURL {
            let besidePath = execURL
                .deletingLastPathComponent()  // MacOS/
                .deletingLastPathComponent()  // Contents/
                .deletingLastPathComponent()  // .app/
                .deletingLastPathComponent()  // containing dir
                .appendingPathComponent("servers/qwen3_server/\(execName)")
            if fileManager.isExecutableFile(atPath: besidePath.path) {
                return besidePath.path
            }
        }

        // 3. Development: scripts/pyinstaller/dist/qwen3_server/qwen3_server
        for searchPath in scriptSearchPaths {
            let devPath = ((searchPath as NSString)
                .deletingLastPathComponent as NSString)
                .appendingPathComponent("scripts/pyinstaller/dist/qwen3_server/\(execName)")
            if fileManager.isExecutableFile(atPath: devPath) {
                return devPath
            }
        }

        return nil
    }

    /// Launches a process with the given executable and arguments, then polls for health.
    /// Returns true if the server became healthy within the startup timeout.
    private func launchProcess(
        executablePath: String,
        arguments: [String]
    ) async -> Bool {
        let process = processFactory.makeProcess()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        // Ensure PATH includes common tool locations
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        let missingPaths = extraPaths.filter { !currentPath.contains($0) }
        if !missingPaths.isEmpty {
            env["PATH"] = (missingPaths + [currentPath]).joined(separator: ":")
        }
        process.environment = env

        // Termination handler
        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.serverProcess === terminatedProcess {
                    let exitCode = terminatedProcess.terminationStatus
                    print("[Qwen3Server] Process terminated with exit code: \(exitCode)")
                    self.serverProcess = nil
                    self.status = .disconnected
                }
            }
        }

        do {
            try process.run()
            serverProcess = process
            print("[Qwen3Server] Process launched (\(executablePath)), waiting for health...")
        } catch {
            print("[Qwen3Server] Failed to launch \(executablePath): \(error)")
            return false
        }

        // Poll for health until timeout
        let deadline = Date().addingTimeInterval(startupTimeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: UInt64(startupPollingInterval * 1_000_000_000))

            if await isHealthy() {
                status = .connected
                startHealthTimer()
                print("[Qwen3Server] Server is healthy")
                return true
            }
        }

        return false
    }

    private func isHealthy() async -> Bool {
        let healthURL = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    private func findPython3() -> String? {
        let fileManager = FileManager.default
        for path in pythonPaths {
            if fileManager.isExecutableFile(atPath: path) {
                print("[Qwen3Server] Found python3 at: \(path)")
                return path
            }
        }
        return nil
    }

    private func findServerScript() -> String? {
        let fileManager = FileManager.default
        let scriptName = "qwen3_mlx_server.py"

        // Check in search paths
        for searchPath in scriptSearchPaths {
            let scriptPath = (searchPath as NSString).appendingPathComponent(scriptName)
            if fileManager.fileExists(atPath: scriptPath) {
                print("[Qwen3Server] Found script at: \(scriptPath)")
                return scriptPath
            }
        }

        // Check Bundle resources
        if let bundlePath = Bundle.main.path(forResource: "qwen3_mlx_server", ofType: "py") {
            print("[Qwen3Server] Found script in bundle: \(bundlePath)")
            return bundlePath
        }

        // Check UserDefaults for custom path
        if let customPath = UserDefaults.standard.string(forKey: "Qwen3ServerScriptPath"),
           fileManager.fileExists(atPath: customPath) {
            print("[Qwen3Server] Found script at custom path: \(customPath)")
            return customPath
        }

        return nil
    }

    private func startHealthTimer() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(
            withTimeInterval: healthCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkHealth()
            }
        }
    }

    private static func defaultPythonPaths() -> [String] {
        var paths: [String] = []

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // pyenv shim
        let pyenvShim = (homeDir as NSString).appendingPathComponent(".pyenv/shims/python3")
        paths.append(pyenvShim)

        // pyenv versions directory (actual binaries)
        let pyenvVersions = (homeDir as NSString).appendingPathComponent(".pyenv/versions")
        if let enumerator = FileManager.default.enumerator(atPath: pyenvVersions) {
            while let path = enumerator.nextObject() as? String {
                if path.hasSuffix("/bin/python3") {
                    paths.append((pyenvVersions as NSString).appendingPathComponent(path))
                    break
                }
            }
        }

        // Standard system paths
        paths.append("/opt/homebrew/bin/python3")
        paths.append("/usr/local/bin/python3")
        paths.append("/usr/bin/python3")

        // conda
        let condaPath = (homeDir as NSString).appendingPathComponent("miniconda3/bin/python3")
        paths.append(condaPath)
        let anacondaPath = (homeDir as NSString).appendingPathComponent("anaconda3/bin/python3")
        paths.append(anacondaPath)

        return paths
    }

    private static func defaultScriptSearchPaths() -> [String] {
        var paths: [String] = []

        // Bundle executable directory
        if let execURL = Bundle.main.executableURL {
            let appBundlePath = execURL
                .deletingLastPathComponent()  // MacOS/
                .deletingLastPathComponent()  // Contents/
                .deletingLastPathComponent()  // .app
                .deletingLastPathComponent()  // containing dir
            paths.append(appBundlePath.appendingPathComponent("scripts").path)
        }

        // Source root from build (Xcode sets this)
        if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            paths.append((sourceRoot as NSString).appendingPathComponent("scripts"))
        }

        // scripts/ relative to the project (development)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        paths.append((homeDir as NSString).appendingPathComponent("repos2/ReaderPro/scripts"))
        paths.append((homeDir as NSString).appendingPathComponent("repos/ReaderPro/scripts"))
        paths.append((homeDir as NSString).appendingPathComponent("Developer/ReaderPro/scripts"))

        // Current working directory
        let cwd = FileManager.default.currentDirectoryPath
        paths.append((cwd as NSString).appendingPathComponent("scripts"))

        // Parent of current working directory
        let parentCwd = (cwd as NSString).deletingLastPathComponent
        paths.append((parentCwd as NSString).appendingPathComponent("scripts"))

        return paths
    }
}
