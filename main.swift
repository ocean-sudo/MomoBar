import Cocoa
import WebKit
import Carbon

// Global notification for hotkey toggle
extension Notification.Name {
    static let togglePopover = Notification.Name("TogglePopoverNotification")
}

// Global hotkey reference
var hotKeyRef: EventHotKeyRef?

// C-compatible global event handler callback for Carbon Hotkeys
func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    NotificationCenter.default.post(name: .togglePopover, object: nil)
    return noErr
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    let keyCodeKey = "HotkeyKeyCode"
    let modifiersKey = "HotkeyModifiers"
    
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
        
        // Observe hotkey trigger notification
        NotificationCenter.default.addObserver(self, selector: #selector(handleHotkeyToggle), name: .togglePopover, object: nil)
        
        // Setup Carbon event handler for global keyboard shortcuts
        setupHotkeyHandler()
        
        // Load and register hotkey
        loadAndRegisterHotkey()
    }
    
    @objc func handleHotkeyToggle() {
        DispatchQueue.main.async {
            self.togglePopover(self)
        }
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
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    // Carbon Keyboard Event Handler
    private func setupHotkeyHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, event, userData) -> OSStatus in
            return hotKeyHandler(nextHandler: nextHandler, event: event, userData: userData)
        }, 1, &eventType, nil, nil)
        
        if status != noErr {
            print("Failed to install Carbon event handler: \(status)")
        }
    }
    
    func loadAndRegisterHotkey() {
        // Default shortcut is Cmd + Shift + M (M is 46, cmdKey | shiftKey is 256 | 512 = 768)
        let keyCode = UserDefaults.standard.object(forKey: keyCodeKey) as? UInt32 ?? 46
        let modifiers = UserDefaults.standard.object(forKey: modifiersKey) as? UInt32 ?? UInt32(cmdKey | shiftKey)
        
        registerHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        // Unregister existing if active
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        var gHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 1296975947, id: 1) // "MMHK" as FourCharCode literal to avoid deprecation warnings
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &gHotKeyRef)
        if status == noErr {
            hotKeyRef = gHotKeyRef
            print("Hotkey successfully registered!")
        } else {
            print("Failed to register hotkey, error status: \(status)")
        }
    }
}

class WebViewController: NSViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var toolbar: NSView!
    var urlTextField: NSTextField!
    var cleanModeButton: NSButton!
    
    let defaultURL = "https://www.maimemo.com/home/web_study" // Set Maimemo as default
    let urlKey = "SavedLastURL"
    let cleanModeKey = "IsCleanModeActive"
    
    var isCleanModeActive = true
    
    override func loadView() {
        // Load preferences
        isCleanModeActive = UserDefaults.standard.object(forKey: cleanModeKey) as? Bool ?? true
        
        // Create container view
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 650))
        self.view = container
        
        // 1. Create Toolbar (Top)
        toolbar = NSView(frame: NSRect(x: 0, y: 610, width: 400, height: 40))
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.addSubview(toolbar)
        
        // 2. Refresh Button
        let refreshButton = NSButton(frame: NSRect(x: 10, y: 8, width: 24, height: 24))
        refreshButton.bezelStyle = .texturedRounded
        if let refreshImage = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh") {
            refreshButton.image = refreshImage
        } else {
            refreshButton.title = "↻"
        }
        refreshButton.target = self
        refreshButton.action = #selector(refreshPage)
        toolbar.addSubview(refreshButton)
        
        // 3. Home Button
        let homeButton = NSButton(frame: NSRect(x: 40, y: 8, width: 24, height: 24))
        homeButton.bezelStyle = .texturedRounded
        if let homeImage = NSImage(systemSymbolName: "house", accessibilityDescription: "Home") {
            homeButton.image = homeImage
        } else {
            homeButton.title = "⌂"
        }
        homeButton.target = self
        homeButton.action = #selector(goHome)
        toolbar.addSubview(homeButton)
        
        // 4. Toggle Clean Mode Button
        cleanModeButton = NSButton(frame: NSRect(x: 70, y: 8, width: 24, height: 24))
        cleanModeButton.bezelStyle = .texturedRounded
        updateCleanModeButtonIcon()
        cleanModeButton.target = self
        cleanModeButton.action = #selector(toggleCleanMode)
        toolbar.addSubview(cleanModeButton)
        
        // 5. URL Text Field (fixed bounds to avoid overlapping with settings button)
        urlTextField = NSTextField(frame: NSRect(x: 105, y: 8, width: 250, height: 24))
        urlTextField.isEditable = true
        urlTextField.isSelectable = true
        urlTextField.bezelStyle = .roundedBezel
        urlTextField.font = NSFont.systemFont(ofSize: 11)
        urlTextField.target = self
        urlTextField.action = #selector(loadUserURL)
        urlTextField.placeholderString = "Enter URL or Search..."
        toolbar.addSubview(urlTextField)
        
        // 6. Settings Button (Gear dropdown menu)
        let settingsButton = NSButton(frame: NSRect(x: 366, y: 8, width: 24, height: 24))
        settingsButton.bezelStyle = .texturedRounded
        if let gearImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") {
            settingsButton.image = gearImage
        } else {
            settingsButton.title = "⚙"
        }
        settingsButton.target = self
        settingsButton.action = #selector(showSettingsMenu(_:))
        toolbar.addSubview(settingsButton)
        
        // 7. Create WKWebView (Bottom)
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.setValue(true, forKey: "developerExtrasEnabled") // Enable right-click inspect element
        
        // Add auto-agree user script for public beta notification page
        let userContentController = WKUserContentController()
        let autoAgreeJS = """
        (function() {
            var checkInterval = setInterval(function() {
                var checkbox = document.querySelector('.taroify-checkbox');
                var button = document.querySelector('taro-button-core');
                if (checkbox && button && button.textContent.includes('开始学习')) {
                    // Check if already checked to avoid double-clicking
                    var isChecked = checkbox.classList.contains('taroify-checkbox--checked') || 
                                    checkbox.innerHTML.includes('checked') || 
                                    checkbox.querySelector('[class*="checked"]') !== null;
                    if (!isChecked) {
                        checkbox.click();
                    }
                    setTimeout(function() {
                        button.click();
                    }, 150);
                    clearInterval(checkInterval);
                }
            }, 300);
            
            // Safety timeout to clear interval after 15s (saves resources if page isn't the beta notification)
            setTimeout(function() {
                clearInterval(checkInterval);
            }, 15000);
        })();
        """
        let userScript = WKUserScript(source: autoAgreeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(userScript)
        webConfiguration.userContentController = userContentController
        
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 400, height: 610), configuration: webConfiguration)
        webView.navigationDelegate = self
        
        // Standard iPhone browser user agent to force beautiful mobile layouts for Maimemo
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        container.addSubview(webView)
        
        // Auto resizing setup
        webView.autoresizingMask = [.width, .height]
        toolbar.autoresizingMask = [.width, .minYMargin]
        urlTextField.autoresizingMask = [.width]
        cleanModeButton.autoresizingMask = [.none]
        settingsButton.autoresizingMask = [.minXMargin]
        
        // Load saved URL or default
        let savedURL = UserDefaults.standard.string(forKey: urlKey) ?? defaultURL
        loadURL(savedURL)
    }
    
    func loadURL(_ urlString: String) {
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.isEmpty { return }
        
        if !cleanURL.contains(".") {
            let encodedQuery = cleanURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            cleanURL = "https://www.bing.com/search?q=\(encodedQuery)"
        } else if !cleanURL.lowercased().hasPrefix("http://") && !cleanURL.lowercased().hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        if let url = URL(string: cleanURL) {
            webView.load(URLRequest(url: url))
            urlTextField.stringValue = cleanURL
        }
    }
    
    @objc func refreshPage() {
        webView.reload()
    }
    
    @objc func goHome() {
        loadURL(defaultURL)
    }
    
    @objc func loadUserURL() {
        loadURL(urlTextField.stringValue)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    // Toggle clean/focus mode
    @objc func toggleCleanMode() {
        isCleanModeActive.toggle()
        UserDefaults.standard.set(isCleanModeActive, forKey: cleanModeKey)
        updateCleanModeButtonIcon()
        applyCleanMode()
    }
    
    func updateCleanModeButtonIcon() {
        let iconName = isCleanModeActive ? "eye.slash" : "eye"
        let tooltip = isCleanModeActive ? "Show Menu & Footer" : "Hide Menu & Footer"
        
        if let iconImage = NSImage(systemSymbolName: iconName, accessibilityDescription: tooltip) {
            cleanModeButton.image = iconImage
        } else {
            cleanModeButton.title = isCleanModeActive ? "👁" : "🕶"
        }
        cleanModeButton.toolTip = tooltip
    }
    
    func applyCleanMode() {
        let js: String
        if isCleanModeActive {
            js = """
            (function() {
                var nav = document.querySelector('.navbar-momo');
                var footer = document.querySelector('.footer-border');
                var iframe = document.querySelector('iframe');
                if (nav) nav.style.setProperty('display', 'none', 'important');
                if (footer) footer.style.setProperty('display', 'none', 'important');
                if (iframe) {
                    iframe.style.setProperty('height', '100vh', 'important');
                    iframe.style.setProperty('margin-top', '0px', 'important');
                }
                document.body.style.setProperty('overflow', 'hidden', 'important');
            })();
            """
        } else {
            js = """
            (function() {
                var nav = document.querySelector('.navbar-momo');
                var footer = document.querySelector('.footer-border');
                var iframe = document.querySelector('iframe');
                if (nav) nav.style.display = '';
                if (footer) footer.style.display = '';
                if (iframe) {
                    iframe.style.height = 'calc(100vh - 52px)';
                    iframe.style.marginTop = '';
                }
                document.body.style.overflow = '';
            })();
            """
        }
        
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    // Dropdown Settings Menu Action
    @objc func showSettingsMenu(_ sender: NSButton) {
        let menu = NSMenu()
        
        let headerItem = NSMenuItem(title: "MomoBar Settings", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        // Display Current Hotkey in Option Label
        let keyCode = UserDefaults.standard.object(forKey: "HotkeyKeyCode") as? UInt32 ?? 46
        let modifiers = UserDefaults.standard.object(forKey: "HotkeyModifiers") as? UInt32 ?? UInt32(cmdKey | shiftKey)
        let hotkeyStr = formatHotkeyString(keyCode: keyCode, modifiers: modifiers)
        
        let hotkeyItem = NSMenuItem(title: "Global Shortcut... (\(hotkeyStr))", action: #selector(changeHotkey), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)
        
        let homeItem = NSMenuItem(title: "Back to Home", action: #selector(goHome), keyEquivalent: "")
        homeItem.target = self
        menu.addItem(homeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit MomoBar", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Popup menu relative to the button
        let p = NSPoint(x: 0, y: sender.frame.height + 4)
        menu.popUp(positioning: nil, at: p, in: sender)
    }
    
    @objc func changeHotkey() {
        let keyCode = UserDefaults.standard.object(forKey: "HotkeyKeyCode") as? UInt32 ?? 46
        let modifiers = UserDefaults.standard.object(forKey: "HotkeyModifiers") as? UInt32 ?? UInt32(cmdKey | shiftKey)
        
        let alert = NSAlert()
        alert.messageText = "Set Global Shortcut"
        alert.informativeText = "Select your modifiers and enter a letter to update the global shortcut for launching MomoBar."
        alert.alertStyle = .informational
        
        let settingsView = HotkeySettingsView(currentKeyCode: keyCode, currentModifiers: modifiers)
        alert.accessoryView = settingsView
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            var newModifiers: UInt32 = 0
            if settingsView.cmdCheckbox.state == .on { newModifiers |= UInt32(cmdKey) }
            if settingsView.shiftCheckbox.state == .on { newModifiers |= UInt32(shiftKey) }
            if settingsView.optCheckbox.state == .on { newModifiers |= UInt32(optionKey) }
            if settingsView.ctrlCheckbox.state == .on { newModifiers |= UInt32(controlKey) }
            
            let charStr = settingsView.keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstChar = charStr.first, let newKeyCode = keyCodeFromChar(String(firstChar)) {
                // Save new keys
                UserDefaults.standard.set(newKeyCode, forKey: "HotkeyKeyCode")
                UserDefaults.standard.set(newModifiers, forKey: "HotkeyModifiers")
                
                // Apply update in AppDelegate
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.registerHotkey(keyCode: newKeyCode, modifiers: newModifiers)
                }
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Shortcut"
                errorAlert.informativeText = "Please enter a valid keyboard letter (A-Z)."
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }
    
    private func formatHotkeyString(keyCode: UInt32, modifiers: UInt32) -> String {
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
    
    private func keyCodeFromChar(_ char: String) -> UInt32? {
        let mapping: [String: UInt32] = [
            "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4, "I": 34,
            "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35, "Q": 12, "R": 15,
            "S": 1, "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6
        ]
        return mapping[char.uppercased()]
    }
    
    private func keyCharFromCode(_ code: UInt32) -> String? {
        let mapping: [UInt32: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I",
            38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R",
            1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z"
        ]
        return mapping[code]
    }
    
    // WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyCleanMode()
        
        if let url = webView.url {
            urlTextField.stringValue = url.absoluteString
            UserDefaults.standard.set(url.absoluteString, forKey: urlKey)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to load page"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// Custom View for Hotkey Selection in Settings Dialog
class HotkeySettingsView: NSView {
    var cmdCheckbox: NSButton!
    var shiftCheckbox: NSButton!
    var optCheckbox: NSButton!
    var ctrlCheckbox: NSButton!
    var keyField: NSTextField!
    
    init(currentKeyCode: UInt32, currentModifiers: UInt32) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
        
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
        if let char = keyCharFromCode(currentKeyCode) {
            keyField.stringValue = char.uppercased()
        }
        addSubview(keyField)
        
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
    
    private func keyCharFromCode(_ code: UInt32) -> String? {
        let mapping: [UInt32: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I",
            38: "J", 40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R",
            1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z"
        ]
        return mapping[code]
    }
}

// Start application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
