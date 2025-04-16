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
    
    var id: String? {
        guard let ptr = TISGetInputSourceProperty(self, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
    
    func select() -> Bool {
        return TISSelectInputSource(self) == noErr
    }
} 