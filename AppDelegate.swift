import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    // Custom event monitors to reliably handle closing the popover on clicks outside
    var clickMonitor: Any?
    var globalClickMonitor: Any?
    
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
        popover.behavior = .applicationDefined // Use custom event monitoring for robust click-outside dismissal
        popover.delegate = self
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
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
                // Explicitly make the WKWebView the first responder of the popover window to bypass textfield focus
                if let webVC = popover.contentViewController as? WebViewController {
                    window.makeFirstResponder(webVC.webView)
                }
            }
            
            // Start custom event monitors
            startMonitoring()
        }
    }
    
    func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        stopMonitoring()
    }
    
    // NSPopoverDelegate
    func popoverDidClose(_ notification: Notification) {
        stopMonitoring()
    }
    
    // Custom event monitoring for reliable click-outside dismissal
    private func startMonitoring() {
        stopMonitoring()
        
        // 1. Local click monitor: clicks inside our app but outside the popover window
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if self.popover.isShown {
                if let window = self.popover.contentViewController?.view.window {
                    if let eventWindow = event.window {
                        if eventWindow == window {
                            // Click is inside popover window — let it proceed normally
                            return event
                        }
                        if eventWindow == self.statusItem.button?.window {
                            // Click on status bar button — let togglePopover handle it
                            return event
                        }
                        // Skip if it's a menu or alert/panel window (to prevent closing popover while interacting with menus/settings dialogs)
                        let className = eventWindow.className
                        if className.contains("Menu") || className.contains("Alert") || className.contains("Panel") || className.contains("Carbon") {
                            return event
                        }
                    }
                }
                
                // Click is outside the popover window — dismiss the popover!
                DispatchQueue.main.async {
                    self.closePopover(nil)
                }
            }
            return event
        }
        
        // 2. Global click monitor: clicks outside our app (e.g. on other apps or desktop)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            // If there's an active modal window (like our custom hotkey settings dialog), don't dismiss popover from a background click
            if NSApp.modalWindow != nil {
                return
            }
            DispatchQueue.main.async {
                self.closePopover(nil)
            }
        }
    }
    
    private func stopMonitoring() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
