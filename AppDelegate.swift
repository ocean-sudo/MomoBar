import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory so it doesn't show in the Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Setup standard edit menu to enable copy, paste, select all, etc.
        setupEditMenu()
        
        // Create status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "MomoBar") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
                button.image = image.withSymbolConfiguration(config)
            } else {
                button.title = "📖"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create the popover window
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 650)
        popover.behavior = .transient // Closes automatically when clicking outside
        popover.contentViewController = WebViewController()
        
        // Configure Global Hotkey Listener
        HotkeyManager.shared.setupHotkeyHandler { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.togglePopover(self)
            }
        }
        HotkeyManager.shared.loadAndRegisterHotkey()
    }
    
    private func setupEditMenu() {
        let mainMenu = NSMenu()
        
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                if let window = popover.contentViewController?.view.window {
                    window.makeKey()
                    // Explicitly make the WKWebView the first responder of the popover window to bypass textfield focus
                    if let webVC = popover.contentViewController as? WebViewController {
                        window.makeFirstResponder(webVC.webView)
                    }
                }
            }
        }
    }
}
