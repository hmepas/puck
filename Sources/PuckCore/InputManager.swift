import Foundation
import Carbon
import Logging

fileprivate let logger = Logger(label: "com.puck.core")

/// Represents an input source in the system
public struct InputSource: Hashable {
    public let id: String
    public let localizedName: String
    public let category: String
    public let type: String
    public let isSelectable: Bool
    public let isSelected: Bool
    
    public init?(source: TISInputSource) {
        guard let id = source.id,
              let category = source.category,
              let type = source.type else { return nil }
        
        self.id = id
        self.category = category
        self.type = type
        self.localizedName = source.localizedName ?? id
        self.isSelectable = source.isSelectable
        self.isSelected = source.isSelected
    }
    
    /// Whether this is an active input source that should be shown to users
    public var isActiveInputSource: Bool {
        // Must be in the keyboard category
        guard category == kTISCategoryKeyboardInputSource as String else { return false }
        
        // Must be selectable
        guard isSelectable else { return false }
        
        // Must be either:
        // 1. A keyboard layout
        // 2. A keyboard input mode (for input methods like Pinyin)
        return type == kTISTypeKeyboardLayout as String ||
               type == kTISTypeKeyboardInputMode as String
    }
}

// Extension to make TISInputSource more Swift-friendly
extension TISInputSource {
    var id: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var localizedName: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyLocalizedName) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var category: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceCategory) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var type: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceType) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var isSelectable: Bool {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceIsSelectCapable) else { return false }
        return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
    }
    
    var isSelected: Bool {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceIsSelected) else { return false }
        return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
    }
}

/// Represents a keyboard shortcut
public struct Hotkey: Hashable {
    public let keyCode: Int
    public let modifiers: Int
    
    public init(keyCode: Int, modifiers: Int) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// Core functionality for managing input sources and hotkeys
public final class InputManager {
    /// Singleton instance
    public static let shared = InputManager()
    
    /// Maps hotkeys to arrays of input source IDs (for cycling)
    private var hotkeyMap: [Hotkey: [String]] = [:]
    /// Keeps track of current position in each cycle group
    private var cyclePositions: [Hotkey: Int] = [:]
    
    private init() {}
    
    /// Get all available input sources
    public func availableInputSources() -> [InputSource] {
        // Create a dictionary to filter out duplicates
        var sourceDict: [String: InputSource] = [:]
        
        // Get all input sources
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        
        // Filter and deduplicate sources
        for source in sources.compactMap(InputSource.init) {
            if source.isActiveInputSource {
                sourceDict[source.id] = source
            }
        }
        
        // Convert back to array and sort by name
        return Array(sourceDict.values).sorted { $0.localizedName < $1.localizedName }
    }
    
    /// Switch to specific input source
    @discardableResult
    public func switchTo(sourceId: String) -> Bool {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return false
        }
        
        guard let source = sources.first(where: { $0.id == sourceId }) else {
            return false
        }
        
        let result = TISSelectInputSource(source)
        return result == noErr
    }
    
    /// Get current input source
    public func currentInputSource() -> InputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return InputSource(source: source)
    }
    
    /// Add a hotkey mapping
    public func add(hotkey: Hotkey, inputSourceId: String) {
        if var existing = hotkeyMap[hotkey] {
            if !existing.contains(inputSourceId) {
                existing.append(inputSourceId)
                hotkeyMap[hotkey] = existing
            }
        } else {
            hotkeyMap[hotkey] = [inputSourceId]
        }
    }
    
    /// Handle hotkey press
    @discardableResult
    public func handleHotkey(_ hotkey: Hotkey) -> Bool {
        guard let sourceIds = hotkeyMap[hotkey] else { return false }
        
        if sourceIds.count == 1 {
            // Single input source - just switch to it
            return switchTo(sourceId: sourceIds[0])
        } else {
            // Multiple input sources - cycle through them
            let currentPos = cyclePositions[hotkey] ?? 0
            let nextPos = (currentPos + 1) % sourceIds.count
            cyclePositions[hotkey] = nextPos
            
            let success = switchTo(sourceId: sourceIds[nextPos])
            if success {
                logger.debug("Switched to input source: \(sourceIds[nextPos])")
            } else {
                logger.error("Failed to switch to input source: \(sourceIds[nextPos])")
            }
            return success
        }
    }
    
    /// Clear all hotkey mappings
    public func clear() {
        hotkeyMap.removeAll()
        cyclePositions.removeAll()
    }
    
    /// Get all input sources (for debugging)
    public func getAllInputSources() -> [InputSource] {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return sources.compactMap(InputSource.init)
    }
} 