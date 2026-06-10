import Foundation
import Combine

/// Gestiona el ciclo de vida del servidor Kokoro TTS (proceso Python local)
///
/// Verifica si el servidor responde en localhost:8880, lo lanza automáticamente
/// si no responde, y monitoriza su estado con health checks periódicos.
@MainActor
final class KokoroServerManager: ObservableObject {

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
    /// Pipe conectado al stdin del servidor: si esta app muere (incluso con
    /// force-quit o crash), el kernel lo cierra y el servidor se apaga solo
    /// (--exit-with-parent). Debe retenerse mientras el proceso viva.
    private var serverStdinPipe: Pipe?
    private var healthTimer: Timer?

    // MARK: - Initialization

    init(
        urlSession: URLSessionProtocol = URLSession.shared,
        processFactory: ProcessFactoryProtocol = ProcessFactory(),
        baseURL: URL = URL(string: "http://127.0.0.1:8880")!,
        pythonPaths: [String]? = nil,
        scriptSearchPaths: [String]? = nil,
        healthCheckInterval: TimeInterval = 120.0,
        startupPollingInterval: TimeInterval = 2.0,
        startupTimeout: TimeInterval = 20.0
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

        // Reservar el estado ANTES de cualquier await: dos llamadas concurrentes
        // pasaban ambas los guards y lanzaban el proceso dos veces
        status = .starting

        // 1. Check if already running
        let healthy = await isHealthy()
        if healthy {
            status = .connected
            startHealthTimer()
            print("[KokoroServer] Already running")
            return
        }

        // 2. Try to launch
        let portArg = "\(baseURL.port ?? 8880)"
        print("[KokoroServer] Server not responding, attempting to launch...")

        // Try 1: Bundled standalone executable (PyInstaller build)
        if let execPath = findBundledExecutable() {
            print("[KokoroServer] Found bundled executable at: \(execPath)")
            let launched = await launchProcess(
                executablePath: execPath,
                arguments: ["--port", portArg, "--exit-with-parent"]
            )
            if launched { return }
            print("[KokoroServer] Bundled executable failed, trying Python fallback...")
        }

        // Try 2: Python script (development / manual setup)
        guard let pythonPath = findPython3() else {
            status = .error("Kokoro server not found. Reinstall the app or install Python 3.")
            print("[KokoroServer] Error: no bundled executable and python3 not found")
            return
        }

        guard let scriptPath = findServerScript() else {
            status = .error("kokoro_server.py script not found.")
            print("[KokoroServer] Error: kokoro_server.py not found")
            return
        }

        let launched = await launchProcess(
            executablePath: pythonPath,
            arguments: [scriptPath, "--exit-with-parent"]
        )
        if !launched {
            status = .error("Server failed to start within \(Int(startupTimeout))s")
            print("[KokoroServer] Startup timeout after \(Int(startupTimeout))s")
        }
    }

    /// Para el servidor y limpia recursos.
    /// Kills the process we launched (if any), then falls back to killing
    /// whatever is listening on the port — covers externally-started servers.
    func stopServer() {
        healthTimer?.invalidate()
        healthTimer = nil

        // Cerrar stdin del hijo: con --exit-with-parent esto ya provoca su salida
        try? serverStdinPipe?.fileHandleForWriting.close()
        serverStdinPipe = nil

        var killedOwnProcess = false

        // 1. Kill our own process if we have one
        if let process = serverProcess {
            let pid = process.processIdentifier
            if process.isRunning {
                kill(-pid, SIGTERM)  // Process group first
                process.interrupt()
                // Give it a moment, then force-kill
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    if process.isRunning {
                        kill(-pid, SIGKILL)
                        kill(pid, SIGKILL)
                        print("[KokoroServer] Force-killed process (pid: \(pid))")
                    }
                }
                killedOwnProcess = true
                print("[KokoroServer] Sent SIGTERM to process group (pid: \(pid))")
            }
            serverProcess = nil
        }

        // 2. Kill by port — catches externally-started servers or orphaned children
        let port = baseURL.port ?? 8880
        Self.killProcessesOnPort(port, label: "KokoroServer", forceIfNeeded: !killedOwnProcess)

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

    /// Permite inyectar un proceso para testing
    func setProcessForTesting(_ process: ProcessProtocol) {
        serverProcess = process
    }

    // MARK: - Private

    /// Searches for a bundled standalone executable (PyInstaller build) inside the app bundle
    /// or beside the .app directory.
    private func findBundledExecutable() -> String? {
        let fileManager = FileManager.default
        let execName = "kokoro_server"

        // 1. Inside app bundle: .app/Contents/Resources/servers/kokoro_server/kokoro_server
        if let resourcePath = Bundle.main.resourcePath {
            let bundledPath = (resourcePath as NSString)
                .appendingPathComponent("servers/kokoro_server/\(execName)")
            if fileManager.isExecutableFile(atPath: bundledPath) {
                return bundledPath
            }
        }

        // 2. Beside .app: ../servers/kokoro_server/kokoro_server
        if let execURL = Bundle.main.executableURL {
            let besidePath = execURL
                .deletingLastPathComponent()  // MacOS/
                .deletingLastPathComponent()  // Contents/
                .deletingLastPathComponent()  // .app/
                .deletingLastPathComponent()  // containing dir
                .appendingPathComponent("servers/kokoro_server/\(execName)")
            if fileManager.isExecutableFile(atPath: besidePath.path) {
                return besidePath.path
            }
        }

        // 3. Development: _scripts/pyinstaller/dist/kokoro_server/kokoro_server
        for searchPath in scriptSearchPaths {
            let devPath = ((searchPath as NSString)
                .deletingLastPathComponent as NSString)
                .appendingPathComponent("_scripts/pyinstaller/dist/kokoro_server/\(execName)")
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

        // Termination handler
        process.terminationHandler = { [weak self] terminatedProcess in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.serverProcess === terminatedProcess {
                    let exitCode = terminatedProcess.terminationStatus
                    print("[KokoroServer] Process terminated with exit code: \(exitCode)")
                    self.serverProcess = nil
                    self.status = .disconnected
                }
            }
        }

        // stdin con pipe: el servidor (--exit-with-parent) se apaga al detectar
        // EOF, lo que ocurre automaticamente si esta app muere por cualquier via
        let stdinPipe = Pipe()
        process.standardInput = stdinPipe

        do {
            try process.run()
            serverProcess = process
            serverStdinPipe = stdinPipe
            print("[KokoroServer] Process launched (\(executablePath)), waiting for health...")
        } catch {
            print("[KokoroServer] Failed to launch \(executablePath): \(error)")
            return false
        }

        // Poll for health until timeout
        let deadline = Date().addingTimeInterval(startupTimeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: UInt64(startupPollingInterval * 1_000_000_000))

            if await isHealthy() {
                status = .connected
                startHealthTimer()
                print("[KokoroServer] Server is healthy")
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
                print("[KokoroServer] Found python3 at: \(path)")
                return path
            }
        }
        return nil
    }

    private func findServerScript() -> String? {
        let fileManager = FileManager.default
        let scriptName = "kokoro_server.py"

        // Check in search paths
        for searchPath in scriptSearchPaths {
            let scriptPath = (searchPath as NSString).appendingPathComponent(scriptName)
            if fileManager.fileExists(atPath: scriptPath) {
                print("[KokoroServer] Found script at: \(scriptPath)")
                return scriptPath
            }
        }

        // Check Bundle resources
        if let bundlePath = Bundle.main.path(forResource: "kokoro_server", ofType: "py") {
            print("[KokoroServer] Found script in bundle: \(bundlePath)")
            return bundlePath
        }

        // Check UserDefaults for custom path
        if let customPath = UserDefaults.standard.string(forKey: "KokoroServerScriptPath"),
           fileManager.fileExists(atPath: customPath) {
            print("[KokoroServer] Found script at custom path: \(customPath)")
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

        // pyenv (very common on macOS)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let pyenvShim = (homeDir as NSString).appendingPathComponent(".pyenv/shims/python3")
        paths.append(pyenvShim)

        // pyenv versions directory (actual binaries)
        let pyenvVersions = (homeDir as NSString).appendingPathComponent(".pyenv/versions")
        if let enumerator = FileManager.default.enumerator(atPath: pyenvVersions) {
            while let path = enumerator.nextObject() as? String {
                if path.hasSuffix("/bin/python3") {
                    paths.append((pyenvVersions as NSString).appendingPathComponent(path))
                    break // Use the first one found
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

    /// Finds all PIDs listening on the given TCP port via lsof and kills them.
    nonisolated static func killProcessesOnPort(_ port: Int, label: String, forceIfNeeded: Bool = true) {
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-ti", "tcp:\(port)"]
        let pipe = Pipe()
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice

        do {
            try lsof.run()
            lsof.waitUntilExit()
        } catch {
            print("[\(label)] lsof failed: \(error)")
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else {
            print("[\(label)] No process found on port \(port)")
            return
        }

        let pids = output.components(separatedBy: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        for pid in pids {
            kill(pid, SIGTERM)
            print("[\(label)] Sent SIGTERM to pid \(pid) on port \(port)")
        }

        if forceIfNeeded {
            // Wait briefly then SIGKILL any survivors
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                for pid in pids {
                    // Check if still alive (kill 0 tests existence)
                    if kill(pid, 0) == 0 {
                        kill(pid, SIGKILL)
                        print("[\(label)] Force-killed pid \(pid)")
                    }
                }
            }
        }
    }

    private static func defaultScriptSearchPaths() -> [String] {
        var paths: [String] = []

        // Bundle executable directory (most reliable for .app bundles)
        if let execURL = Bundle.main.executableURL {
            // Go up from .app/Contents/MacOS/ to find scripts/ beside the .app
            let appBundlePath = execURL
                .deletingLastPathComponent()  // MacOS/
                .deletingLastPathComponent()  // Contents/
                .deletingLastPathComponent()  // .app
                .deletingLastPathComponent()  // containing dir
            paths.append(appBundlePath.appendingPathComponent("_scripts").path)
        }

        // Source root from build (Xcode sets this)
        if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            paths.append((sourceRoot as NSString).appendingPathComponent("_scripts"))
        }

        // scripts/ relative to the project (development) - multiple common locations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        paths.append((homeDir as NSString).appendingPathComponent("repos2/ReaderPro/_scripts"))
        paths.append((homeDir as NSString).appendingPathComponent("repos/ReaderPro/_scripts"))
        paths.append((homeDir as NSString).appendingPathComponent("Developer/ReaderPro/_scripts"))

        // Current working directory
        let cwd = FileManager.default.currentDirectoryPath
        paths.append((cwd as NSString).appendingPathComponent("_scripts"))

        // Parent of current working directory (in case cwd is inside the project)
        let parentCwd = (cwd as NSString).deletingLastPathComponent
        paths.append((parentCwd as NSString).appendingPathComponent("_scripts"))

        return paths
    }
}
