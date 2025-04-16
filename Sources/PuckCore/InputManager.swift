import Carbon
import Foundation

public struct InputSource: Equatable {
    public let id: String
    public let localizedName: String
}

/// Manages input sources
public class InputManager {
    public static let shared = InputManager()
    
    private var hotkeyMap: [Hotkey: InputSource] = [:]
    private let tisWrapper: TISWrapperProtocol
    
    public init(tisWrapper: TISWrapperProtocol = TISWrapper.shared) {
        self.tisWrapper = tisWrapper
    }
    
    /// Returns all available keyboard input sources
    public func availableInputSources() -> [InputSource] {
        guard let inputSources = tisWrapper.createInputSourceList() else {
            return []
        }
        
        return inputSources.compactMap { source in
            // Get source properties
            let sourceID = source.identifier
            let sourceName = source.localizedName
            let isSelectable = source.isSelectable
            
            // Skip if missing required properties or not selectable
            guard let sourceID = sourceID,
                  let sourceName = sourceName,
                  isSelectable == true else {
                return nil
            }
            
            // Only include keyboard layouts and input methods
            let isKeyboardLayout = sourceID.contains("com.apple.keylayout")
            let isInputMethod = sourceID.contains("com.apple.inputmethod")
            
            guard isKeyboardLayout || isInputMethod else {
                return nil
            }
            
            // Validate input source ID format
            let hasValidID = (isKeyboardLayout && sourceID.hasPrefix("com.apple.keylayout.") && sourceID.count > "com.apple.keylayout.".count) ||
                           (isInputMethod && sourceID.hasPrefix("com.apple.inputmethod.") && sourceID.count > "com.apple.inputmethod.".count)
            
            guard hasValidID else {
                return nil
            }
            
            return InputSource(id: sourceID, localizedName: sourceName)
        }
    }
    
    /// Returns the current input source
    public func currentInputSource() -> InputSource? {
        guard let currentSource = tisWrapper.copyCurrentKeyboardInputSource(),
              let sourceID = currentSource.identifier,
              let sourceName = currentSource.localizedName else {
            return nil
        }
        return InputSource(id: sourceID, localizedName: sourceName)
    }
    
    /// Adds a hotkey mapping to an input source
    public func add(hotkey: Hotkey, for inputSource: InputSource) {
        hotkeyMap[hotkey] = inputSource
    }
    
    /// Handles a hotkey press by switching to the corresponding input source
    public func handleHotkey(_ hotkey: Hotkey) -> Bool {
        guard let inputSource = hotkeyMap[hotkey] else {
            return false
        }
        
        // Find the TISInputSource for the target input source
        guard let inputSourceList = tisWrapper.createInputSourceList(),
              let matchingSource = inputSourceList.first(where: { $0.identifier == inputSource.id }) else {
            return false
        }
        
        // Switch to the target input source
        let result = tisWrapper.selectInputSource(matchingSource)
        return result == noErr
    }
} 
