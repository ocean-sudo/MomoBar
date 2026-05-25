import Cocoa
import WebKit

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
            // Set menu bar icon (using SF Symbols, fallback to emoji)
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
    }
    
    private func setupEditMenu() {
        let mainMenu = NSMenu()
        
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        // Standard editing menu items with Cmd equivalents
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
        
        // 5. URL Text Field (resized to fit the cleanModeButton)
        urlTextField = NSTextField(frame: NSRect(x: 105, y: 8, width: 285, height: 24))
        urlTextField.isEditable = true
        urlTextField.isSelectable = true
        urlTextField.bezelStyle = .roundedBezel
        urlTextField.font = NSFont.systemFont(ofSize: 11)
        urlTextField.target = self
        urlTextField.action = #selector(loadUserURL)
        urlTextField.placeholderString = "Enter URL or Search..."
        toolbar.addSubview(urlTextField)
        
        // 6. Quit Button
        let quitButton = NSButton(frame: NSRect(x: 366, y: 8, width: 24, height: 24))
        quitButton.bezelStyle = .texturedRounded
        if let quitImage = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit") {
            quitButton.image = quitImage
        } else {
            quitButton.title = "✕"
        }
        quitButton.target = self
        quitButton.action = #selector(quitApp)
        toolbar.addSubview(quitButton)
        
        // 7. Create WKWebView (Bottom)
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.preferences.setValue(true, forKey: "developerExtrasEnabled") // Enable right-click inspect element
        
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
        quitButton.autoresizingMask = [.minXMargin]
        
        // Load saved URL or default
        let savedURL = UserDefaults.standard.string(forKey: urlKey) ?? defaultURL
        loadURL(savedURL)
    }
    
    func loadURL(_ urlString: String) {
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.isEmpty { return }
        
        // Basic smart URL bar (if doesn't look like domain, search on Bing or assume https)
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
        // If clean mode is active, we are hiding distractions, show eye.slash icon
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
            // JavaScript to hide the header navbar and the footer, and expand the iframe to fill height
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
            // JavaScript to restore standard layout
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
    
    // WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Always apply current clean/focus mode settings when page finishes loading
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

// Start application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
