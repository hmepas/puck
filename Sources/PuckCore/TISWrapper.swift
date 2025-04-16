import Carbon
import Foundation

public protocol InputSourceType {
    var identifier: String? { get }
    var localizedName: String? { get }
    var isSelectable: Bool? { get }
}

public class SystemInputSource: InputSourceType {
    private let tisInputSource: TISInputSource
    
    init(_ tisInputSource: TISInputSource) {
        self.tisInputSource = tisInputSource
    }
    
    public var identifier: String? {
        let ptr = TISGetInputSourceProperty(tisInputSource, kTISPropertyInputSourceID)
        return Unmanaged<CFString>.fromOpaque(ptr!).takeUnretainedValue() as String
    }
    
    public var localizedName: String? {
        let ptr = TISGetInputSourceProperty(tisInputSource, kTISPropertyLocalizedName)
        return Unmanaged<CFString>.fromOpaque(ptr!).takeUnretainedValue() as String
    }
    
    public var isSelectable: Bool? {
        guard let ptr = TISGetInputSourceProperty(tisInputSource, kTISPropertyInputSourceIsSelectCapable) else {
            return nil
        }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue())
    }
    
    var underlyingSource: TISInputSource {
        tisInputSource
    }
}

public protocol TISWrapperProtocol {
    func createInputSourceList() -> [InputSourceType]?
    func copyCurrentKeyboardInputSource() -> InputSourceType?
    func selectInputSource(_ inputSource: InputSourceType) -> OSStatus
}

public class TISWrapper: TISWrapperProtocol {
    public static let shared = TISWrapper()
    
    private init() {}
    
    public func createInputSourceList() -> [InputSourceType]? {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        return sources.map { SystemInputSource($0) }
    }
    
    public func copyCurrentKeyboardInputSource() -> InputSourceType? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return SystemInputSource(source)
    }
    
    public func selectInputSource(_ inputSource: InputSourceType) -> OSStatus {
        // Get all available input sources
        guard let sources = createInputSourceList() else {
            return -1
        }
        
        // Find matching source by ID
        guard let sourceId = inputSource.identifier,
              let matchingSource = sources.first(where: { $0.identifier == sourceId }) as? SystemInputSource else {
            return -1
        }
        
        return TISSelectInputSource(matchingSource.underlyingSource)
    }
} 