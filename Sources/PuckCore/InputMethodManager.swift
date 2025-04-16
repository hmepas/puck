import Foundation
import Carbon

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
        
        // Get the next action for this hotkey (handles both single actions and cycles)
        guard let action = configManager.nextActionInCycle(for: hotkey) else {
            return
        }
        
        switchToInputSource(withID: action.inputSourceID)
    }
    
    private func switchToInputSource(withID id: String) {
        guard let inputSource = TISInputSource.inputSource(withID: id) else {
            print("Error: Input source with ID '\(id)' not found")
            return
        }
        
        let result = inputSource.select()
        if !result {
            print("Error: Failed to switch to input source '\(id)'")
        }
    }
} 