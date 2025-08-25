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
        
        let switched = switchToInputSource(withID: action.inputSourceID)
        if switched {
            lastHandledAtByHotkey[hotkey] = now
        }
        return switched
    }
    
    private func switchToInputSource(withID id: String) -> Bool {
        guard let inputSource = TISInputSource.inputSource(withID: id) else {
            PuckLogger.shared.error("Input source with ID '\(id)' not found")
            return false
        }
        
        let result = inputSource.select()
        if !result {
            PuckLogger.shared.error("Failed to switch to input source '\(id)'")
            return false
        } else {
            let name = SystemInputSource(inputSource).localizedName ?? "?"
            PuckLogger.shared.info("Switched to input source id=\(id) name=\(name)")
            return true
        }
    }
} 