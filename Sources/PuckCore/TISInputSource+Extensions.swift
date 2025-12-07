import Foundation
import Carbon

// Extension to handle TISInputSource
extension TISInputSource {
    static func inputSource(withID id: String) -> TISInputSource? {
        let inputSourceNSArray = TISCreateInputSourceList(nil, false).takeRetainedValue() as NSArray
        let inputSources = inputSourceNSArray as! [TISInputSource]
        
        return inputSources.first { source in
            guard let sourceID = source.id else { return false }
            return sourceID == id
        }
    }
    
    static func inputModes(forInputSourceID id: String) -> [TISInputSource] {
        let filter = [
            kTISPropertyInputSourceID as String: id
        ] as CFDictionary
        
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        // Only return entries that actually expose an input mode ID
        return sources.filter { $0.inputModeID != nil }
    }
    
    var id: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var inputModeID: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputModeID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var type: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceType) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    var isInputMethod: Bool {
        guard let type = type else { return false }
        // TIS type strings are documented; we check substrings to avoid missing constants in certain SDKs.
        return type.contains("InputMethod") || type == (kTISTypeKeyboardInputMode as String)
    }
    
    func select() -> Bool {
        return TISSelectInputSource(self) == noErr
    }
}
