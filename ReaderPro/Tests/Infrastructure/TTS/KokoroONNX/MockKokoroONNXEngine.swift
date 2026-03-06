import Foundation
@testable import ReaderPro

/// Mock ONNX engine for testing KokoroONNXAdapter
final class MockKokoroONNXEngine: KokoroONNXEngineProtocol {
    var _isLoaded = false
    var isLoaded: Bool { _isLoaded }

    var loadModelCalled = false
    var loadModelError: Error?

    var inferCalled = false
    var inferResult: [Float32] = []
    var inferError: Error?
    var lastTokens: [Int64]?
    var lastStyle: [Float32]?
    var lastSpeed: Float32?

    func loadModel() throws {
        loadModelCalled = true
        if let error = loadModelError {
            throw error
        }
        _isLoaded = true
    }

    func infer(tokens: [Int64], style: [Float32], speed: Float32) throws -> [Float32] {
        inferCalled = true
        lastTokens = tokens
        lastStyle = style
        lastSpeed = speed

        if let error = inferError {
            throw error
        }

        // If no explicit result, generate a short sine wave
        if inferResult.isEmpty {
            return (0..<2400).map { i in
                0.5 * sinf(2.0 * .pi * 440.0 * Float(i) / 24000.0)
            }
        }

        return inferResult
    }
}
