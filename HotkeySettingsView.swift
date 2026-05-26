import Cocoa
import Carbon

class HotkeySettingsView: NSView {
    var cmdCheckbox: NSButton!
    var shiftCheckbox: NSButton!
    var optCheckbox: NSButton!
    var ctrlCheckbox: NSButton!
    var keyField: NSTextField!
    
    init(currentKeyCode: UInt32, currentModifiers: UInt32) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        
        // Create checkboxes for modifiers
        cmdCheckbox = NSButton(checkboxWithTitle: "⌘ Cmd", target: nil, action: nil)
        shiftCheckbox = NSButton(checkboxWithTitle: "⇧ Shift", target: nil, action: nil)
        optCheckbox = NSButton(checkboxWithTitle: "⌥ Opt", target: nil, action: nil)
        ctrlCheckbox = NSButton(checkboxWithTitle: "⌃ Ctrl", target: nil, action: nil)
        
        cmdCheckbox.state = (currentModifiers & UInt32(cmdKey) != 0) ? .on : .off
        shiftCheckbox.state = (currentModifiers & UInt32(shiftKey) != 0) ? .on : .off
        optCheckbox.state = (currentModifiers & UInt32(optionKey) != 0) ? .on : .off
        ctrlCheckbox.state = (currentModifiers & UInt32(controlKey) != 0) ? .on : .off
        
        let label = NSTextField(labelWithString: "Shortcut Key:")
        label.frame = NSRect(x: 10, y: 10, width: 90, height: 20)
        addSubview(label)
        
        keyField = NSTextField(frame: NSRect(x: 100, y: 8, width: 50, height: 22))
        keyField.placeholderString = "M"
        if let char = HotkeyManager.shared.keyCharFromCode(currentKeyCode) {
            keyField.stringValue = char.uppercased()
        }
        addSubview(keyField)
        
        // Layout elements
        cmdCheckbox.frame = NSRect(x: 10, y: 48, width: 65, height: 20)
        shiftCheckbox.frame = NSRect(x: 80, y: 48, width: 65, height: 20)
        optCheckbox.frame = NSRect(x: 150, y: 48, width: 65, height: 20)
        ctrlCheckbox.frame = NSRect(x: 220, y: 48, width: 65, height: 20)
        
        addSubview(cmdCheckbox)
        addSubview(shiftCheckbox)
        addSubview(optCheckbox)
        addSubview(ctrlCheckbox)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
