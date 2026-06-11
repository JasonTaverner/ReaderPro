import AppKit
import AVFoundation

/// Comandos globales de dictado por voz: pulsa el atajo para EMPEZAR a grabar
/// (sonido "Tink"), habla, y pulsa de nuevo para PARAR ("Pop"). El audio se
/// transcribe con el whisper local del servidor MLX y, según el comando:
/// - dictado → portapapeles: copia el texto transcrito ("Glass" al terminar)
/// - dictado → entrada: crea una entrada SIN audio en el proyecto destino
///   configurado (el mismo del comando "crear entrada desde el portapapeles")
@MainActor
final class VoiceDictationService: NSObject {

    enum Target {
        case clipboard
        case entry
    }

    // MARK: - Settings keys

    static let clipboardEnabledKey = "dictationClipboardEnabled"
    static let clipboardHotKeyKey = "dictationClipboardHotKey"
    static let entryEnabledKey = "dictationEntryEnabled"
    static let entryHotKeyKey = "dictationEntryHotKey"
    static let languageKey = "dictationLanguage"

    /// Límite de seguridad de la grabación
    private static let maxRecordingSeconds: TimeInterval = 300

    // MARK: - Dependencies

    private let coordinator: TTSServerCoordinator
    private let entryService: ClipboardEntryService
    private let serverBaseURL: URL

    private var recorder: AVAudioRecorder?
    private var recordingTarget: Target?
    private var recordingURL: URL?
    private var safetyTimer: Timer?
    private var clipboardHotKeyId: UInt32?
    private var entryHotKeyId: UInt32?

    init(
        coordinator: TTSServerCoordinator,
        entryService: ClipboardEntryService,
        serverBaseURL: URL = URL(string: "http://127.0.0.1:8890")!
    ) {
        self.coordinator = coordinator
        self.entryService = entryService
        self.serverBaseURL = serverBaseURL
        super.init()
    }

    // MARK: - Hotkey lifecycle

    func applySettings() {
        if let id = clipboardHotKeyId {
            GlobalHotKeyManager.shared.unregister(id: id)
            clipboardHotKeyId = nil
        }
        if let id = entryHotKeyId {
            GlobalHotKeyManager.shared.unregister(id: id)
            entryHotKeyId = nil
        }

        let defaults = UserDefaults.standard

        let clipboardEnabled = defaults.object(forKey: Self.clipboardEnabledKey) == nil
            ? true : defaults.bool(forKey: Self.clipboardEnabledKey)
        if clipboardEnabled {
            let raw = defaults.string(forKey: Self.clipboardHotKeyKey) ?? GlobalHotKeyCombo.ctrlOptT.rawValue
            let combo = GlobalHotKeyCombo(rawValue: raw) ?? .ctrlOptT
            clipboardHotKeyId = GlobalHotKeyManager.shared.register(combo: combo) { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.toggleDictation(target: .clipboard)
                }
            }
        }

        let entryEnabled = defaults.object(forKey: Self.entryEnabledKey) == nil
            ? true : defaults.bool(forKey: Self.entryEnabledKey)
        if entryEnabled {
            let raw = defaults.string(forKey: Self.entryHotKeyKey) ?? GlobalHotKeyCombo.ctrlOptE.rawValue
            let combo = GlobalHotKeyCombo(rawValue: raw) ?? .ctrlOptE
            entryHotKeyId = GlobalHotKeyManager.shared.register(combo: combo) { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.toggleDictation(target: .entry)
                }
            }
        }
    }

    // MARK: - Action

    func toggleDictation(target: Target) async {
        if recorder != nil {
            // Ya grabando: el mismo atajo (o el otro) detiene y procesa
            await stopAndProcess()
            return
        }
        await startRecording(target: target)
    }

    private func startRecording(target: Target) async {
        // Permiso de micrófono (la primera vez macOS muestra el diálogo)
        let statusBefore = AVCaptureDevice.authorizationStatus(for: .audio)
        print("[Dictation] Mic permission status: \(statusBefore.rawValue) (0=notDetermined 1=restricted 2=denied 3=authorized)")
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else {
            print("[Dictation] Microphone permission DENIED — enable it in System Settings → Privacy → Microphone → ReaderPro")
            NSSound.beep()
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation_\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]

        do {
            var newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.prepareToRecord()
            guard newRecorder.record() else {
                print("[Dictation] Failed to start recording")
                NSSound.beep()
                return
            }

            // Los micros Bluetooth tardan 1-2 s en conmutar su perfil al activar la
            // entrada: el AudioQueue puede arrancar "en falso" y grabar silencio.
            // Verificar que el tiempo avanza; si no, reintentar una vez.
            try? await Task.sleep(nanoseconds: 700_000_000)
            if newRecorder.currentTime < 0.05 {
                print("[Dictation] Input not capturing yet (Bluetooth switching?), retrying…")
                newRecorder.stop()
                try? FileManager.default.removeItem(at: url)
                try? await Task.sleep(nanoseconds: 800_000_000)

                newRecorder = try AVAudioRecorder(url: url, settings: settings)
                newRecorder.prepareToRecord()
                guard newRecorder.record() else {
                    print("[Dictation] Retry failed to start recording")
                    NSSound.beep()
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard newRecorder.currentTime > 0.05 else {
                    print("[Dictation] Microphone is not capturing audio — check the input device in System Settings → Sound")
                    newRecorder.stop()
                    try? FileManager.default.removeItem(at: url)
                    NSSound.beep()
                    return
                }
            }

            recorder = newRecorder
            recordingTarget = target
            recordingURL = url
            // El Tink suena cuando la captura está VERIFICADA: ya puedes hablar
            NSSound(named: "Tink")?.play()
            print("[Dictation] Recording started and capturing (target: \(target))")

            // Tope de seguridad
            safetyTimer = Timer.scheduledTimer(withTimeInterval: Self.maxRecordingSeconds, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.stopAndProcess()
                }
            }

            // Aprovechar la grabación para arrancar el servidor si hace falta
            Task { await coordinator.ensureServerRunning(for: .qwen3) }
        } catch {
            print("[Dictation] Recorder error: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func stopAndProcess() async {
        safetyTimer?.invalidate()
        safetyTimer = nil

        guard let activeRecorder = recorder,
              let url = recordingURL,
              let target = recordingTarget else { return }

        activeRecorder.stop()
        recorder = nil
        recordingTarget = nil
        recordingURL = nil
        NSSound(named: "Pop")?.play()

        defer_cleanup: do {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            // Grabaciones de menos de medio segundo: pulsación accidental
            let duration = (try? AVAudioFile(forReading: url).length) ?? 0
            print("[Dictation] Recording stopped: \(fileSize ?? 0) bytes, \(duration) frames")
            if duration < 8_000 { // 0.5 s a 16 kHz
                print("[Dictation] Recording too short, ignored")
                break defer_cleanup
            }

            let language = UserDefaults.standard.string(forKey: Self.languageKey) ?? "es"
            guard let text = await transcribe(audioURL: url, language: language),
                  !text.isEmpty else {
                NSSound.beep()
                break defer_cleanup
            }

            print("[Dictation] Transcribed \(text.count) chars")

            switch target {
            case .clipboard:
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                NSSound(named: "Glass")?.play()
            case .entry:
                await entryService.createEntry(text: text, generateAudio: false)
            }
        }

        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Transcription

    private func transcribe(audioURL: URL, language: String) async -> String? {
        await coordinator.ensureServerRunning(for: .qwen3)

        guard let audioData = try? Data(contentsOf: audioURL) else { return nil }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"dictation.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append(language.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: serverBaseURL.appendingPathComponent("transcribe"))
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            print("[Dictation] Transcription request failed: no response (¿server MLX arrancado?)")
            return nil
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            print("[Dictation] Transcription HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1) — \(String(data: data, encoding: .utf8) ?? "")")
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            print("[Dictation] Transcription parse failed")
            return nil
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
