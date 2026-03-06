import Foundation

/// Protocol for converting text to IPA phonemes
protocol EspeakPhonemizerProtocol {
    /// Convert text to IPA phonemes using espeak-ng
    /// - Parameters:
    ///   - text: Input text to phonemize
    ///   - language: Language code (e.g. "en-us", "es", "fr")
    /// - Returns: IPA phoneme string
    func phonemize(text: String, language: String) throws -> String

    /// Whether espeak-ng is available
    var isAvailable: Bool { get }
}

/// Wrapper around espeak-ng via dlopen for text → IPA phoneme conversion
/// Thread-safe: uses a serial DispatchQueue since espeak-ng is not thread-safe
final class EspeakPhonemizer: EspeakPhonemizerProtocol {

    // MARK: - Errors

    enum EspeakError: LocalizedError {
        case libraryNotFound(String)
        case symbolNotFound(String)
        case initializationFailed(String)
        case phonemizationFailed(String)

        var errorDescription: String? {
            switch self {
            case .libraryNotFound(let path):
                return "espeak-ng library not found at: \(path)"
            case .symbolNotFound(let symbol):
                return "espeak-ng symbol not found: \(symbol)"
            case .initializationFailed(let reason):
                return "espeak-ng initialization failed: \(reason)"
            case .phonemizationFailed(let reason):
                return "Phonemization failed: \(reason)"
            }
        }
    }

    // MARK: - C Function Types

    // espeak_ng_InitializePath(const char *path) -> espeak_ng_STATUS
    private typealias InitializePathFunc = @convention(c) (UnsafePointer<CChar>?) -> Int32

    // espeak_SetVoiceByName(const char *name) -> espeak_ERROR
    private typealias SetVoiceByNameFunc = @convention(c) (UnsafePointer<CChar>?) -> Int32

    // espeak_TextToPhonemes(const void **textptr, int textmode, int phonememode) -> const char*
    private typealias TextToPhonemesFunc = @convention(c) (UnsafeMutablePointer<UnsafeRawPointer?>, Int32, Int32) -> UnsafePointer<CChar>?

    // espeak_ng_Terminate() -> espeak_ng_STATUS
    private typealias TerminateFunc = @convention(c) () -> Int32

    // espeak_Initialize(output, buflength, path, options) -> int
    private typealias InitializeFunc = @convention(c) (Int32, Int32, UnsafePointer<CChar>?, Int32) -> Int32

    // MARK: - Properties

    private let queue = DispatchQueue(label: "com.readerpro.espeak-phonemizer")
    private var handle: UnsafeMutableRawPointer?
    private var initialized = false

    // Function pointers
    private var initializePath: InitializePathFunc?
    private var setVoiceByName: SetVoiceByNameFunc?
    private var textToPhonemes: TextToPhonemesFunc?
    private var terminate: TerminateFunc?
    private var initialize: InitializeFunc?

    // Paths
    private let libraryPath: String
    private let dataPath: String

    // MARK: - Init

    /// Initialize with explicit paths to espeak-ng library and data
    init(libraryPath: String, dataPath: String) throws {
        self.libraryPath = libraryPath
        self.dataPath = dataPath
        try loadLibrary()
    }

    /// Initialize using bundle resources
    convenience init() throws {
        let searchPaths = EspeakPhonemizer.findResources()

        guard let (libPath, datPath) = searchPaths else {
            throw EspeakError.libraryNotFound("Could not find espeak-ng resources in bundle or project")
        }

        try self.init(libraryPath: libPath, dataPath: datPath)
    }

    deinit {
        if initialized {
            _ = terminate?()
        }
        if let handle = handle {
            dlclose(handle)
        }
    }

    // MARK: - Resource Discovery

    private static func findResources() -> (libraryPath: String, dataPath: String)? {
        // Search in bundle
        if let bundlePath = Bundle.main.resourcePath {
            let libPath = (bundlePath as NSString).appendingPathComponent("espeak-ng/libespeak-ng.dylib")
            let datPath = (bundlePath as NSString).appendingPathComponent("espeak-ng/espeak-ng-data")

            if FileManager.default.fileExists(atPath: libPath) &&
               FileManager.default.fileExists(atPath: datPath) {
                return (libPath, datPath)
            }
        }

        // Search in project Resources directory
        let projectPaths = [
            "ReaderPro/Resources/espeak-ng",
            "../ReaderPro/Resources/espeak-ng",
        ]

        for basePath in projectPaths {
            let libPath = (basePath as NSString).appendingPathComponent("libespeak-ng.dylib")
            let datPath = (basePath as NSString).appendingPathComponent("espeak-ng-data")

            if FileManager.default.fileExists(atPath: libPath) &&
               FileManager.default.fileExists(atPath: datPath) {
                return (libPath, datPath)
            }
        }

        // Search via SOURCE_ROOT environment variable
        if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            let libPath = (sourceRoot as NSString).appendingPathComponent("ReaderPro/Resources/espeak-ng/libespeak-ng.dylib")
            let datPath = (sourceRoot as NSString).appendingPathComponent("ReaderPro/Resources/espeak-ng/espeak-ng-data")

            if FileManager.default.fileExists(atPath: libPath) &&
               FileManager.default.fileExists(atPath: datPath) {
                return (libPath, datPath)
            }
        }

        return nil
    }

    // MARK: - Library Loading

    private func loadLibrary() throws {
        // dlopen the library
        guard let h = dlopen(libraryPath, RTLD_LAZY) else {
            let error = String(cString: dlerror())
            throw EspeakError.libraryNotFound("\(libraryPath): \(error)")
        }
        self.handle = h

        // Load function pointers
        initializePath = try loadSymbol(h, name: "espeak_ng_InitializePath")
        setVoiceByName = try loadSymbol(h, name: "espeak_SetVoiceByName")
        textToPhonemes = try loadSymbol(h, name: "espeak_TextToPhonemes")
        terminate = try loadSymbol(h, name: "espeak_ng_Terminate")
        initialize = try loadSymbol(h, name: "espeak_Initialize")

        // Initialize espeak-ng with data path
        try initializeEspeak()
    }

    private func loadSymbol<T>(_ handle: UnsafeMutableRawPointer, name: String) throws -> T {
        guard let sym = dlsym(handle, name) else {
            throw EspeakError.symbolNotFound(name)
        }
        return unsafeBitCast(sym, to: T.self)
    }

    private func initializeEspeak() throws {
        // Use espeak_Initialize with the data path
        // output=0 (AUDIO_OUTPUT_PLAYBACK not needed, we just want phonemes)
        // buflength=0 (default)
        // options=1 (don't load phoneme data for audio, just text-to-phonemes)
        let result = dataPath.withCString { pathPtr -> Int32 in
            initialize!(0, 0, pathPtr, 1) // options=1: espeakINITIALIZE_DONT_EXIT
        }

        guard result > 0 else {
            throw EspeakError.initializationFailed("espeak_Initialize returned \(result)")
        }

        initialized = true
    }

    // MARK: - EspeakPhonemizerProtocol

    var isAvailable: Bool {
        initialized
    }

    func phonemize(text: String, language: String) throws -> String {
        guard initialized else {
            throw EspeakError.initializationFailed("espeak-ng not initialized")
        }

        return try queue.sync {
            try _phonemize(text: text, language: language)
        }
    }

    // MARK: - Private Phonemization

    private func _phonemize(text: String, language: String) throws -> String {
        // 1. Set voice/language
        let espeakLang = mapLanguage(language)
        let voiceResult = espeakLang.withCString { langPtr -> Int32 in
            setVoiceByName!(langPtr)
        }

        if voiceResult != 0 {
            // Try fallback to just the base language
            let baseLang = String(espeakLang.prefix(2))
            let fallbackResult = baseLang.withCString { langPtr -> Int32 in
                setVoiceByName!(langPtr)
            }
            if fallbackResult != 0 {
                throw EspeakError.phonemizationFailed("Could not set language: \(language)")
            }
        }

        // 2. Convert text to phonemes
        // phonememode = 2 (IPA) | 0x100 (separator = space between words)
        let phonemeMode: Int32 = 0x02 // IPA output
        let textMode: Int32 = 0 // UTF-8

        var result = ""

        text.withCString { textCStr in
            var textPtr: UnsafeRawPointer? = UnsafeRawPointer(textCStr)
            // espeak_TextToPhonemes processes one clause at a time
            // We need to call it in a loop until all text is consumed
            while textPtr != nil {
                let phonemesCStr = textToPhonemes!(&textPtr, textMode, phonemeMode)

                if let phonemesCStr = phonemesCStr {
                    let phonemes = String(cString: phonemesCStr)
                    if !phonemes.isEmpty {
                        if !result.isEmpty {
                            result += " "
                        }
                        result += phonemes
                    }
                }

                // If textPtr is now pointing to a null byte or past the string, stop
                if let ptr = textPtr {
                    let byte = ptr.load(as: UInt8.self)
                    if byte == 0 {
                        break
                    }
                } else {
                    break
                }
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Map BCP-47 language codes to espeak-ng language names
    private func mapLanguage(_ language: String) -> String {
        let lowered = language.lowercased()

        // Direct mappings
        let mappings: [String: String] = [
            "en-us": "en-us",
            "en-gb": "en-gb",
            "es-es": "es",
            "es": "es",
            "fr-fr": "fr-fr",
            "fr": "fr-fr",
            "it-it": "it",
            "it": "it",
            "pt-br": "pt-br",
            "pt": "pt-br",
            "ja-jp": "ja",
            "ja": "ja",
            "zh-cn": "cmn",
            "zh": "cmn",
            "ko-kr": "ko",
            "ko": "ko",
            "hi-in": "hi",
            "hi": "hi",
            "de-de": "de",
            "de": "de",
        ]

        if let mapped = mappings[lowered] {
            return mapped
        }

        // If it contains a dash, try the base language
        if lowered.contains("-") {
            let base = String(lowered.prefix(while: { $0 != "-" }))
            if let mapped = mappings[base] {
                return mapped
            }
            return base
        }

        return lowered
    }
}
