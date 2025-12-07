import Foundation
import Carbon
import ApplicationServices
import Logging

public class InputMethodManager {
    private let configManager: ConfigurationManager
    private let debounceInterval: TimeInterval = 0.25
    private var lastHandledAtByHotkey: [ConfigHotkey: Date] = [:]
    private lazy var keyboardMonitor: KeyboardMonitor = {
        return KeyboardMonitor(consumeHandledEvents: true) { [weak self] keyString, modifiers in
            return self?.handleKeyEvent(keyString: keyString, modifiers: modifiers) ?? false
        }
    }()
    private var isRunning = false
    
    public init(configPath: String) throws {
        self.configManager = ConfigurationManager()
        try self.configManager.loadConfiguration(from: configPath)
    }
    
    public func start() -> Bool {
        guard !isRunning else { return true }
        // Check Accessibility (AX) trust first
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            PuckLogger.shared.error("Accessibility (AX) not granted for Puck. Add this binary to System Settings → Privacy & Security → Accessibility and reload the service.")
            return false
        }
        
        let success = keyboardMonitor.start()
        if success {
            isRunning = true
            PuckLogger.shared.info("Keyboard monitor started")
        }
        return success
    }
    
    public func stop() {
        guard isRunning else { return }
        
        keyboardMonitor.stop()
        isRunning = false
    }
    
    private func handleKeyEvent(keyString: String, modifiers: [String]) -> Bool {
        let hotkey = ConfigHotkey.from(keyString: keyString, modifiers: modifiers)
        PuckLogger.shared.debug("Key event: key=\(keyString) modifiers=\(modifiers.joined(separator: "+"))")

        // Debounce per-hotkey
        let now = Date()
        if let last = lastHandledAtByHotkey[hotkey], now.timeIntervalSince(last) < debounceInterval {
            PuckLogger.shared.trace("Debounced hotkey \(hotkey)")
            return true // treat as handled to avoid propagation beeps
        }

        guard let action = configManager.nextActionInCycle(for: hotkey) else {
            PuckLogger.shared.debug("No action configured for this hotkey")
            return false
        }
        
        // Perform selection on main thread; TIS calls from CGEvent tap thread can be flaky for IMEs.
        lastHandledAtByHotkey[hotkey] = now
        DispatchQueue.main.async { [weak self] in
            _ = self?.switchToInputSource(withID: action.inputSourceID)
        }
        return true
    }
    
    private func switchToInputSource(withID id: String) -> Bool {
        guard let inputSource = TISInputSource.inputSource(withID: id) else {
            PuckLogger.shared.error("Input source with ID '\(id)' not found")
            return false
        }
        
        // Input methods can have multiple input modes (e.g., Pinyin vs ASCII).
        // Choose a non-ASCII input mode when available and clear overrides.
        if inputSource.isInputMethod {
            TISSetInputMethodKeyboardLayoutOverride(nil)
            
            let modes = TISInputSource.inputModes(forInputSourceID: id)
            // Prefer a mode that does not look like ASCII/ABC/Latin
            let preferredMode = modes.first { mode in
                guard let modeID = mode.inputModeID?.lowercased() else { return false }
                return !(modeID.contains("abc") || modeID.contains("latin") || modeID.contains("english"))
            } ?? modes.first
            
            if let modeSource = preferredMode {
                if !modeSource.select() {
                    PuckLogger.shared.warning("Failed to select input mode for '\(id)'")
                }
            }
        }
        
        guard inputSource.select() else {
            PuckLogger.shared.error("Failed to switch to input source '\(id)'")
            return false
        }
        
        let name = SystemInputSource(inputSource).localizedName ?? "?"
        PuckLogger.shared.info("Switched to input source id=\(id) name=\(name)")
        return true
    }
}
