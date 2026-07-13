import Cocoa
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    var hotKeyRef: EventHotKeyRef?
    let keyCodeKey = "HotkeyKeyCode"
    let modifiersKey = "HotkeyModifiers"
    
    private static var onHotkeyTriggered: (() -> Void)?
    
    // Setup Carbon event handler for system-wide hotkeys
    func setupHotkeyHandler(onTrigger: @escaping () -> Void) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        HotkeyManager.onHotkeyTriggered = onTrigger
        
        let status = InstallEventHandler(GetEventDispatcherTarget(), { (nextHandler, event, userData) -> OSStatus in
            HotkeyManager.onHotkeyTriggered?()
            return noErr
        }, 1, &eventType, nil, nil)
        
        if status != noErr {
            print("Failed to install Carbon event handler: \(status)")
        }
    }
    
    // Load preference and register
    func loadAndRegisterHotkey() {
        let keyCode = UserDefaults.standard.object(forKey: keyCodeKey) as? UInt32 ?? 46 // default 'M'
        let modifiers = UserDefaults.standard.object(forKey: modifiersKey) as? UInt32 ?? UInt32(cmdKey | shiftKey) // default Cmd+Shift
        
        registerHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    // Register global hotkey
    func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        // Unregister existing if registered
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        var gHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 1296975947, id: 1) // "MMHK"
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &gHotKeyRef)
        if status == noErr {
            hotKeyRef = gHotKeyRef
            print("Hotkey registered successfully! KeyCode: \(keyCode), Modifiers: \(modifiers)")
        } else {
            print("Failed to register global hotkey, error status: \(status)")
        }
    }
    
    // Utility: Format modifier keys into human readable string (e.g. ⌘⇧M)
    func formatHotkeyString(keyCode: UInt32, modifiers: UInt32) -> String {
        var str = ""
        if modifiers & UInt32(controlKey) != 0 { str += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { str += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { str += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { str += "⌘" }
        
        if let char = keyCharFromCode(keyCode) {
            str += char
        } else {
            str += "?"
        }
        return str
    }
    
    // Utility: Convert letter string to macOS virtual keycode
    func keyCodeFromChar(_ char: String) -> UInt32? {
        let mapping: [String: UInt32] = [
            "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4, "I": 34,
            "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35, "Q": 12, "R": 15,
            "S": 1, "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6
        ]
        return mapping[char.uppercased()]
    }
    
    // Utility: Convert virtual keycode to letter string
    func keyCharFromCode(_ code: UInt32) -> String? {
        let mapping: [UInt32: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I",
            38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R",
            1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z"
        ]
        return mapping[code]
    }
}
