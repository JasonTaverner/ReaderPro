import Foundation
import Carbon.HIToolbox

/// Combinaciones de teclas disponibles para los comandos globales.
/// Lista cerrada (sin capturador de teclas): robusta y suficiente para configurar.
enum GlobalHotKeyCombo: String, CaseIterable, Identifiable {
    case ctrlOptR = "ctrl_opt_r"
    case ctrlOptL = "ctrl_opt_l"
    case ctrlOptP = "ctrl_opt_p"
    case ctrlOptSpace = "ctrl_opt_space"
    case ctrlOptCmdR = "ctrl_opt_cmd_r"
    case ctrlOptD = "ctrl_opt_d"   // ⚠️ macOS lo usa para ocultar el Dock
    case ctrlOptE = "ctrl_opt_e"
    case ctrlOptT = "ctrl_opt_t"
    case ctrlOptV = "ctrl_opt_v"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ctrlOptR: return "⌃⌥R"
        case .ctrlOptL: return "⌃⌥L"
        case .ctrlOptP: return "⌃⌥P"
        case .ctrlOptSpace: return "⌃⌥Space"
        case .ctrlOptCmdR: return "⌃⌥⌘R"
        case .ctrlOptD: return "⌃⌥D (puede chocar con el Dock)"
        case .ctrlOptE: return "⌃⌥E"
        case .ctrlOptT: return "⌃⌥T"
        case .ctrlOptV: return "⌃⌥V"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .ctrlOptR, .ctrlOptCmdR: return UInt32(kVK_ANSI_R)
        case .ctrlOptL: return UInt32(kVK_ANSI_L)
        case .ctrlOptP: return UInt32(kVK_ANSI_P)
        case .ctrlOptSpace: return UInt32(kVK_Space)
        case .ctrlOptD: return UInt32(kVK_ANSI_D)
        case .ctrlOptE: return UInt32(kVK_ANSI_E)
        case .ctrlOptT: return UInt32(kVK_ANSI_T)
        case .ctrlOptV: return UInt32(kVK_ANSI_V)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .ctrlOptR, .ctrlOptL, .ctrlOptP, .ctrlOptSpace, .ctrlOptD, .ctrlOptE, .ctrlOptT, .ctrlOptV:
            return UInt32(controlKey | optionKey)
        case .ctrlOptCmdR:
            return UInt32(controlKey | optionKey | cmdKey)
        }
    }
}

/// Registra atajos de teclado GLOBALES del sistema (funcionan con la app en
/// segundo plano) usando la API Carbon RegisterEventHotKey — no requiere
/// permisos de accesibilidad.
final class GlobalHotKeyManager {

    static let shared = GlobalHotKeyManager()

    private var handlerRef: EventHandlerRef?
    private var hotKeys: [UInt32: (ref: EventHotKeyRef, action: () -> Void)] = [:]
    private var nextId: UInt32 = 1

    private init() {
        installHandlerIfNeeded()
    }

    /// Registra un atajo global. Devuelve un id para des-registrarlo después.
    @discardableResult
    func register(combo: GlobalHotKeyCombo, action: @escaping () -> Void) -> UInt32 {
        let id = nextId
        nextId += 1

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5250524F) /* "RPRO" */, id: id)
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeys[id] = (ref, action)
            print("[GlobalHotKey] Registered \(combo.displayName) (id \(id))")
        } else {
            print("[GlobalHotKey] Failed to register \(combo.displayName): status \(status)")
        }
        return id
    }

    func unregister(id: UInt32) {
        if let entry = hotKeys.removeValue(forKey: id) {
            UnregisterEventHotKey(entry.ref)
        }
    }

    func unregisterAll() {
        for (_, entry) in hotKeys {
            UnregisterEventHotKey(entry.ref)
        }
        hotKeys.removeAll()
    }

    // MARK: - Carbon plumbing

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKey(id: hotKeyID.id)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    private func handleHotKey(id: UInt32) {
        guard let entry = hotKeys[id] else { return }
        DispatchQueue.main.async {
            entry.action()
        }
    }
}
