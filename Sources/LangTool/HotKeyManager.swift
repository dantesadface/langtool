import AppKit
import Carbon.HIToolbox

/// Registers system-wide hotkeys via the Carbon Hot Key API and dispatches
/// them to the TextProcessor. Defaults:
///   ⌥⌘T  → translate
///   ⌥⌘G  → grammar fix
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    private let signature: OSType = {
        // FourCharCode for "LANG"
        let chars = Array("LANG".utf8)
        return (OSType(chars[0]) << 24) | (OSType(chars[1]) << 16)
             | (OSType(chars[2]) << 8) | OSType(chars[3])
    }()

    private enum Action: UInt32 {
        case translate = 1
        case grammar = 2
    }

    func register() {
        installHandler()

        let optionCommand = UInt32(optionKey | cmdKey)
        registerHotKey(id: Action.translate.rawValue,
                       keyCode: UInt32(kVK_ANSI_T),
                       modifiers: optionCommand)
        registerHotKey(id: Action.grammar.rawValue,
                       keyCode: UInt32(kVK_ANSI_G),
                       modifiers: optionCommand)
    }

    // MARK: - Carbon plumbing

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(eventRef,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard status == noErr else { return status }

            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handle(actionID: hotKeyID.id)
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)
    }

    private func registerHotKey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
        } else {
            NSLog("LangTool — failed to register hotkey id=%u status=%d", id, status)
        }
    }

    private func handle(actionID: UInt32) {
        switch Action(rawValue: actionID) {
        case .translate:
            TextProcessor.shared.run(mode: .translate)
        case .grammar:
            TextProcessor.shared.run(mode: .grammar)
        case .none:
            break
        }
    }
}
