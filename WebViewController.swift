import Cocoa
import WebKit
import Carbon

// Dark mode preference: 0 = light, 1 = dark, 2 = follow system
enum DarkModeOption: Int {
    case light = 0
    case dark = 1
    case followSystem = 2
}

class WebViewController: NSViewController, WKNavigationDelegate, NSMenuDelegate {
    var webView: WKWebView!
    var toolbar: NSVisualEffectView!

    var cleanModeButton: NSButton!
    
    let defaultURL = "https://www.maimemo.com/home/web_study" // Set Maimemo as default
    let urlKey = "SavedLastURL"
    let cleanModeKey = "IsCleanModeActive"
    let darkModeKey = "DarkModeOption"
    
    var isCleanModeActive = true
    var darkModeOption: DarkModeOption = .followSystem
    
    // System appearance observer
    private var appearanceObserver: NSKeyValueObservation?
    
    override func loadView() {
        // Load preferences
        isCleanModeActive = UserDefaults.standard.object(forKey: cleanModeKey) as? Bool ?? true
        darkModeOption = DarkModeOption(rawValue: UserDefaults.standard.integer(forKey: darkModeKey)) ?? .followSystem
        
        // Create container view
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 650))
        self.view = container
        
        // Apply initial appearance
        applyDarkMode()
        
        // 1. Create Toolbar (Top) with native vibrancy/blur
        toolbar = NSVisualEffectView(frame: NSRect(x: 0, y: 610, width: 400, height: 40))
        toolbar.material = .headerView
        toolbar.blendingMode = .withinWindow
        toolbar.state = .active
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
        
        // Add auto-agree user script for public beta notification page (using deep-query Shadow DOM traversal and physical DOM Event dispatching)
        let userContentController = WKUserContentController()
        let autoAgreeJS = """
        (function() {
            console.log("MomoBar AutoAgree: Injected.");
            
            // Recursive function to search for selector inside standard DOM and nested open Shadow Roots
            function querySelectorDeep(selector, root) {
                root = root || document;
                var element = root.querySelector(selector);
                if (element) return element;
                
                var all = root.querySelectorAll('*');
                for (var i = 0; i < all.length; i++) {
                    if (all[i].shadowRoot) {
                        var found = querySelectorDeep(selector, all[i].shadowRoot);
                        if (found) return found;
                    }
                }
                return null;
            }
            
            var checkInterval = setInterval(function() {
                try {
                    var checkbox = querySelectorDeep('.taroify-checkbox');
                    var button = querySelectorDeep('taro-button-core');
                    
                    if (checkbox && button && button.textContent.includes('开始学习')) {
                        console.log("MomoBar AutoAgree: Found targets inside DOM/ShadowDOM.");
                        
                        var isChecked = checkbox.classList.contains('taroify-checkbox--checked') || 
                                        checkbox.getAttribute('aria-checked') === 'true';
                        
                        if (!isChecked) {
                            console.log("MomoBar AutoAgree: Click-dispatching checkbox.");
                            var clickEvt = new MouseEvent('click', { bubbles: true, cancelable: true });
                            
                            // Dispatch click on the custom element container itself (holds framework listeners)
                            checkbox.dispatchEvent(clickEvt);
                            
                            // Also try dispatching click on the inner label to be absolutely safe
                            var label = querySelectorDeep('.taroify-checkbox__label', checkbox);
                            if (label) label.dispatchEvent(clickEvt);
                        }
                        
                        setTimeout(function() {
                            try {
                                console.log("MomoBar AutoAgree: Click-dispatching submit button.");
                                var submitEvt = new MouseEvent('click', { bubbles: true, cancelable: true });
                                button.dispatchEvent(submitEvt);
                            } catch (e) {
                                button.click();
                            }
                            clearInterval(checkInterval);
                        }, 250);
                    }
                } catch (err) {
                    console.error("MomoBar AutoAgree error:", err);
                }
            }, 450);
            
            // Safety timeout to clear interval after 15s (saves resources if page isn't the beta notification)
            setTimeout(function() {
                console.log("MomoBar AutoAgree: Timeout reached, stopping search.");
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

        cleanModeButton.autoresizingMask = [.none]
        settingsButton.autoresizingMask = [.minXMargin]
        
        // Load saved URL or default
        let savedURL = UserDefaults.standard.string(forKey: urlKey) ?? defaultURL
        loadURL(savedURL)
        
        // Observe system appearance changes for "follow system" dark mode
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            guard let self = self, self.darkModeOption == .followSystem else { return }
            DispatchQueue.main.async {
                self.applyDarkMode()
            }
        }
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
        }
    }
    
    @objc func refreshPage() {
        webView.reload()
    }
    
    @objc func goHome() {
        loadURL(defaultURL)
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
    
    // MARK: - Dark Mode (Native NSAppearance)
    
    /// Apply dark mode by setting the view's NSAppearance.
    /// WKWebView will natively communicate prefers-color-scheme to web content.
    func applyDarkMode() {
        switch darkModeOption {
        case .light:
            view.appearance = NSAppearance(named: .aqua)
        case .dark:
            view.appearance = NSAppearance(named: .darkAqua)
        case .followSystem:
            view.appearance = nil  // Inherit from system
        }
    }
    
    @objc func setDarkModeLight() { setDarkMode(.light) }
    @objc func setDarkModeDark() { setDarkMode(.dark) }
    @objc func setDarkModeSystem() { setDarkMode(.followSystem) }
    
    private func setDarkMode(_ option: DarkModeOption) {
        darkModeOption = option
        UserDefaults.standard.set(option.rawValue, forKey: darkModeKey)
        applyDarkMode()
    }
    
    // MARK: - Settings Menu
    
    // Dropdown Settings Menu Action
    @objc func showSettingsMenu(_ sender: NSButton) {
        let menu = NSMenu()
        
        let headerItem = NSMenuItem(title: "MomoBar 设置", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())
        
        // Dark mode submenu
        let darkModeItem = NSMenuItem(title: "深色模式", action: nil, keyEquivalent: "")
        let darkModeSubmenu = NSMenu()
        
        let lightItem = NSMenuItem(title: "浅色", action: #selector(setDarkModeLight), keyEquivalent: "")
        lightItem.target = self
        if darkModeOption == .light { lightItem.state = .on }
        darkModeSubmenu.addItem(lightItem)
        
        let darkItem = NSMenuItem(title: "深色", action: #selector(setDarkModeDark), keyEquivalent: "")
        darkItem.target = self
        if darkModeOption == .dark { darkItem.state = .on }
        darkModeSubmenu.addItem(darkItem)
        
        let systemItem = NSMenuItem(title: "跟随系统", action: #selector(setDarkModeSystem), keyEquivalent: "")
        systemItem.target = self
        if darkModeOption == .followSystem { systemItem.state = .on }
        darkModeSubmenu.addItem(systemItem)
        
        darkModeItem.submenu = darkModeSubmenu
        menu.addItem(darkModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Display Current Hotkey in Option Label
        let keyCode = UserDefaults.standard.object(forKey: "HotkeyKeyCode") as? UInt32 ?? 46
        let modifiers = UserDefaults.standard.object(forKey: "HotkeyModifiers") as? UInt32 ?? UInt32(cmdKey | shiftKey)
        let hotkeyStr = HotkeyManager.shared.formatHotkeyString(keyCode: keyCode, modifiers: modifiers)
        
        let hotkeyItem = NSMenuItem(title: "自定义全局快捷键... (当前: \(hotkeyStr))", action: #selector(changeHotkey), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)
        
        let homeItem = NSMenuItem(title: "返回背单词主页", action: #selector(goHome), keyEquivalent: "")
        homeItem.target = self
        menu.addItem(homeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 MomoBar", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Set delegate to handle menu close for popover dismissal fix
        menu.delegate = self
        
        // Popup menu relative to the button
        let p = NSPoint(x: 0, y: sender.frame.height + 4)
        menu.popUp(positioning: nil, at: p, in: sender)
    }
    
    // NSMenuDelegate: After menu closes, check if mouse is outside popover and dismiss
    func menuDidClose(_ menu: NSMenu) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let window = self.view.window else { return }
            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            if !windowFrame.contains(mouseLocation) {
                // Mouse is outside the popover — find and close the popover
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.popover.performClose(nil)
                }
            }
        }
    }
    
    @objc func changeHotkey() {
        let keyCode = UserDefaults.standard.object(forKey: "HotkeyKeyCode") as? UInt32 ?? 46
        let modifiers = UserDefaults.standard.object(forKey: "HotkeyModifiers") as? UInt32 ?? UInt32(cmdKey | shiftKey)
        
        let alert = NSAlert()
        alert.messageText = "设置全局快捷键"
        alert.informativeText = "请勾选您想要的修饰键，并在输入框中填入一个字母键以自定义全局呼出/隐藏 MomoBar 的快捷键组合。"
        alert.alertStyle = .informational
        
        let settingsView = HotkeySettingsView(currentKeyCode: keyCode, currentModifiers: modifiers)
        alert.accessoryView = settingsView
        
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            var newModifiers: UInt32 = 0
            if settingsView.cmdCheckbox.state == .on { newModifiers |= UInt32(cmdKey) }
            if settingsView.shiftCheckbox.state == .on { newModifiers |= UInt32(shiftKey) }
            if settingsView.optCheckbox.state == .on { newModifiers |= UInt32(optionKey) }
            if settingsView.ctrlCheckbox.state == .on { newModifiers |= UInt32(controlKey) }
            
            let charStr = settingsView.keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstChar = charStr.first, let newKeyCode = HotkeyManager.shared.keyCodeFromChar(String(firstChar)) {
                // Save new keys
                UserDefaults.standard.set(newKeyCode, forKey: "HotkeyKeyCode")
                UserDefaults.standard.set(newModifiers, forKey: "HotkeyModifiers")
                
                // Apply update in AppDelegate
                HotkeyManager.shared.registerHotkey(keyCode: newKeyCode, modifiers: newModifiers)
            } else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "无效的快捷键"
                errorAlert.informativeText = "请输入一个有效的键盘字母 (A-Z)。"
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "确定")
                errorAlert.runModal()
            }
        }
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }
    
    // WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyCleanMode()
        
        if let url = webView.url {
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
