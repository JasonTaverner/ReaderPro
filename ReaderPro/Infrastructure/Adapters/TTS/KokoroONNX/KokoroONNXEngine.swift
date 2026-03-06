import Foundation
import OnnxRuntimeBindings

/// Protocol for ONNX inference engine
protocol KokoroONNXEngineProtocol {
    /// Load the ONNX model
    func loadModel() throws

    /// Run inference with the given inputs
    /// - Parameters:
    ///   - tokens: Padded token IDs [0, t1, t2, ..., 0] shape [1, N]
    ///   - style: Voice style vector, shape [1, 256]
    ///   - speed: Speech speed, shape [1]
    /// - Returns: Audio samples as Float32 array at 24kHz
    func infer(tokens: [Int64], style: [Float32], speed: Float32) throws -> [Float32]

    /// Whether the model is loaded
    var isLoaded: Bool { get }
}

/// ONNX Runtime engine for Kokoro TTS with CoreML Execution Provider
final class KokoroONNXEngine: KokoroONNXEngineProtocol {

    // MARK: - Errors

    enum EngineError: LocalizedError {
        case modelNotFound(String)
        case sessionCreationFailed(String)
        case inferenceFailed(String)
        case modelNotLoaded

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let path):
                return "ONNX model not found at: \(path)"
            case .sessionCreationFailed(let reason):
                return "Failed to create ONNX session: \(reason)"
            case .inferenceFailed(let reason):
                return "ONNX inference failed: \(reason)"
            case .modelNotLoaded:
                return "ONNX model not loaded. Call loadModel() first."
            }
        }
    }

    // MARK: - Properties

    private let modelPath: String
    private var environment: ORTEnv?
    private var session: ORTSession?
    private let useCoreML: Bool

    var isLoaded: Bool { session != nil }

    // MARK: - Init

    /// Create engine with explicit model path
    /// - Parameters:
    ///   - modelPath: Path to kokoro-v1.0.onnx file
    ///   - useCoreML: Whether to enable CoreML execution provider (default true)
    init(modelPath: String, useCoreML: Bool = true) {
        self.modelPath = modelPath
        self.useCoreML = useCoreML
    }

    /// Convenience init to find model in common locations
    convenience init(useCoreML: Bool = true) throws {
        guard let path = KokoroONNXEngine.findModel() else {
            throw EngineError.modelNotFound("Could not find kokoro ONNX model in any search path")
        }
        self.init(modelPath: path, useCoreML: useCoreML)
    }

    // MARK: - Model Discovery

    private static func findModel() -> String? {
        let searchPaths = [
            Bundle.main.path(forResource: "kokoro-v1.0", ofType: "onnx"),
            Bundle.main.path(forResource: "kokoro", ofType: "onnx"),
        ].compactMap { $0 }

        if let path = searchPaths.first {
            return path
        }

        let relativePaths = [
            "scripts/Resources/Models/kokoro/kokoro-v1.0.onnx",
            "kokoro.onnx",
        ]

        for path in relativePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try SOURCE_ROOT
        if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            let paths = [
                "\(sourceRoot)/scripts/Resources/Models/kokoro/kokoro-v1.0.onnx",
                "\(sourceRoot)/kokoro.onnx",
            ]
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
            }
        }

        return nil
    }

    // MARK: - KokoroONNXEngineProtocol

    func loadModel() throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw EngineError.modelNotFound(modelPath)
        }

        do {
            // Create environment
            let env = try ORTEnv(loggingLevel: .warning)
            self.environment = env

            // Create session options
            let sessionOptions = try ORTSessionOptions()
            try sessionOptions.setGraphOptimizationLevel(.all)

            // Try to enable CoreML EP
            if useCoreML {
                do {
                    let coreMLOptions = ORTCoreMLExecutionProviderOptions()
                    // Use all compute units (CPU + GPU + ANE)
                    coreMLOptions.useCPUOnly = false
                    try sessionOptions.appendCoreMLExecutionProvider(with: coreMLOptions)
                    print("[KokoroONNX] CoreML execution provider enabled")
                } catch {
                    print("[KokoroONNX] CoreML EP not available, using CPU: \(error.localizedDescription)")
                }
            }

            // Create session
            let sess = try ORTSession(env: env, modelPath: modelPath, sessionOptions: sessionOptions)
            self.session = sess

            print("[KokoroONNX] Model loaded successfully from: \(modelPath)")
        } catch {
            throw EngineError.sessionCreationFailed(error.localizedDescription)
        }
    }

    func infer(tokens: [Int64], style: [Float32], speed: Float32) throws -> [Float32] {
        guard let session = session else {
            throw EngineError.modelNotLoaded
        }

        do {
            // 1. Create input tensors

            // tokens: shape [1, N] int64
            let tokenCount = tokens.count
            let tokensData = NSMutableData(
                bytes: tokens,
                length: tokenCount * MemoryLayout<Int64>.size
            )
            let tokensValue = try ORTValue(
                tensorData: tokensData,
                elementType: .int64,
                shape: [1, NSNumber(value: tokenCount)]
            )

            // style: shape [1, 256] float32
            let styleData = NSMutableData(
                bytes: style,
                length: style.count * MemoryLayout<Float32>.size
            )
            let styleValue = try ORTValue(
                tensorData: styleData,
                elementType: .float,
                shape: [1, 256]
            )

            // speed: shape [1] float32
            var speedVal = speed
            let speedData = NSMutableData(
                bytes: &speedVal,
                length: MemoryLayout<Float32>.size
            )
            let speedValue = try ORTValue(
                tensorData: speedData,
                elementType: .float,
                shape: [1]
            )

            // 2. Run inference
            let inputs: [String: ORTValue] = [
                "tokens": tokensValue,
                "style": styleValue,
                "speed": speedValue,
            ]

            let outputNames: Set<String> = ["audio"]

            let outputs = try session.run(
                withInputs: inputs,
                outputNames: outputNames,
                runOptions: nil
            )

            // 3. Extract audio output
            guard let audioValue = outputs["audio"] else {
                throw EngineError.inferenceFailed("No 'audio' output from model")
            }

            let audioData = try audioValue.tensorData()

            // Convert NSMutableData to [Float32]
            let floatCount = audioData.length / MemoryLayout<Float32>.size
            let audioSamples: [Float32] = Array(unsafeUninitializedCapacity: floatCount) { buffer, initializedCount in
                let src = audioData.bytes.assumingMemoryBound(to: Float32.self)
                for i in 0..<floatCount {
                    buffer[i] = src[i]
                }
                initializedCount = floatCount
            }

            return audioSamples
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.inferenceFailed(error.localizedDescription)
        }
    }
}
