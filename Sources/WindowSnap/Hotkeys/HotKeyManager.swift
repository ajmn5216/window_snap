import Carbon.HIToolbox
import AppKit

/// Registers global hotkeys via Carbon's `RegisterEventHotKey` and dispatches
/// them to closures. A single application-level event handler routes all hotkey
/// presses by their numeric ID.
final class HotKeyManager {
    private struct Registration {
        let ref: EventHotKeyRef
        let handler: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    init() {
        installHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handle(id: hotKeyID.id)
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }

    private func handle(id: UInt32) {
        registrations[id]?.handler()
    }

    /// Register a hotkey. No-op if the combo can't be registered (e.g. already
    /// taken by another app).
    func register(_ combo: HotKeyCombo, handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x57534E50 /* "WSNP" */), id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            NSLog("WindowSnap: failed to register hotkey \(combo.displayString) (status \(status))")
            return
        }
        registrations[id] = Registration(ref: ref, handler: handler)
    }

    func unregisterAll() {
        for (_, reg) in registrations {
            UnregisterEventHotKey(reg.ref)
        }
        registrations.removeAll()
    }
}
