import Foundation

public enum ResourceError: Error {
    case resourceNotFound(String)
}

public struct ResourceLoader {
    public static func loadPlistContent() -> String {
        let executablePath = ProcessInfo.processInfo.arguments[0]
        return PlistTemplate.generate(executablePath: executablePath)
    }
} 