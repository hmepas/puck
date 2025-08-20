import Foundation
import Carbon
import Logging

public class InputMethodManager {
    private let configManager: ConfigurationManager
    private lazy var keyboardMonitor: KeyboardMonitor = {
        return KeyboardMonitor { [weak self] keyString, modifiers in
            self?.handleKeyEvent(keyString: keyString, modifiers: modifiers)
        }
    }()
    private var isRunning = false
    
    public init(configPath: String) throws {
        self.configManager = ConfigurationManager()
        try self.configManager.loadConfiguration(from: configPath)
    }
    
    public func start() -> Bool {
        guard !isRunning else { return true }
        
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
    
    private func handleKeyEvent(keyString: String, modifiers: [String]) {
        let hotkey = ConfigHotkey.from(keyString: keyString, modifiers: modifiers)
        PuckLogger.shared.debug("Key event: key=\(keyString) modifiers=\(modifiers.joined(separator: "+"))")
        // Get the next action for this hotkey (handles both single actions and cycles)
        guard let action = configManager.nextActionInCycle(for: hotkey) else {
            PuckLogger.shared.debug("No action configured for this hotkey")
            return
        }
        
        switchToInputSource(withID: action.inputSourceID)
    }
    
    private func switchToInputSource(withID id: String) {
        guard let inputSource = TISInputSource.inputSource(withID: id) else {
            PuckLogger.shared.error("Input source with ID '\(id)' not found")
            return
        }
        
        let result = inputSource.select()
        if !result {
            PuckLogger.shared.error("Failed to switch to input source '\(id)'")
        } else {
            let name = SystemInputSource(inputSource).localizedName ?? "?"
            PuckLogger.shared.info("Switched to input source id=\(id) name=\(name)")
        }
    }
} 