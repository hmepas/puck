import Foundation

public enum ResourceError: Error {
    case resourceNotFound(String)
}

public struct ResourceLoader {
    public static func loadPlistContent() throws -> String {
        // Try environment variable
        if let path = ProcessInfo.processInfo.environment["PUCK_RESOURCE_PATH"],
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            return content
        }
        
        throw ResourceError.resourceNotFound("Could not find plist file")
    }
} 