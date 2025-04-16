import Foundation
import ServiceManagement

#if canImport(SwiftUI)
import SwiftUI
#endif

private extension Bundle {
    static var current: Bundle {
        #if canImport(SwiftUI)
        return Bundle.main
        #else
        return Bundle.module
        #endif
    }
}

public enum ServiceError: Error {
    case fileOperationFailed(String)
    case commandFailed(String)
    case invalidState(String)
    case systemError(String)
    case plistNotFound
    case installFailed
    case uninstallFailed
    case startFailed
    case stopFailed
    case restartFailed
}

public class ServiceManager {
    private let launchAgentName = "com.puck.daemon"
    private let launchAgentPath: String
    private let executablePath: String
    private let plistContent: String
    
    public init(plistContent: String, executablePath: String? = nil) {
        self.launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(launchAgentName).plist"
        self.executablePath = executablePath ?? ProcessInfo.processInfo.arguments[0]
        self.plistContent = plistContent
    }
    
    public func install() throws {
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            print("Warning: Accessibility permissions are not granted.")
            print("Please grant accessibility permissions in System Settings -> Privacy & Security -> Accessibility")
            print("After granting permissions, try installing the service again.")
            throw ServiceError.invalidState("Accessibility permissions required")
        }
        
        // Create LaunchAgents directory if it doesn't exist
        try FileManager.default.createDirectory(
            atPath: "\(NSHomeDirectory())/Library/LaunchAgents",
            withIntermediateDirectories: true
        )
        
        print("Debug: Using executable path: \(executablePath)")
        
        // Get working directory (parent directory of executable)
        let workingDirectory = (executablePath as NSString).deletingLastPathComponent
        print("Debug: Using working directory: \(workingDirectory)")
        
        // Update plist content with correct paths
        var plistDict = try PropertyListSerialization.propertyList(
            from: plistContent.data(using: .utf8)!,
            options: [],
            format: nil
        ) as! [String: Any]
        
        // Update paths
        if var programArgs = plistDict["ProgramArguments"] as? [String] {
            programArgs[0] = executablePath
            plistDict["ProgramArguments"] = programArgs
        }
        plistDict["WorkingDirectory"] = workingDirectory
        
        // Convert back to XML
        let updatedContent = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        
        // Write updated plist
        try updatedContent.write(to: URL(fileURLWithPath: launchAgentPath), options: .atomic)
        
        print("Service installed at \(launchAgentPath)")
    }
    
    public func uninstall() throws {
        try stop()
        
        if FileManager.default.fileExists(atPath: launchAgentPath) {
            try FileManager.default.removeItem(atPath: launchAgentPath)
        }
        
        print("Service uninstalled")
    }
    
    public func start() throws {
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            throw ServiceError.invalidState("Service not installed. Please install first.")
        }
        
        let result = ProcessUtils.shell("/bin/launchctl", "load", launchAgentPath)
        if result.status != 0 {
            throw ServiceError.commandFailed("Failed to start service: \(result.output)")
        }
        
        print("Service started")
    }
    
    public func stop() throws {
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            return
        }
        
        let result = ProcessUtils.shell("/bin/launchctl", "unload", launchAgentPath)
        if result.status != 0 {
            throw ServiceError.commandFailed("Failed to stop service: \(result.output)")
        }
        
        print("Service stopped")
    }
    
    public func restart() throws {
        try stop()
        try start()
        
        print("Service restarted")
    }
    
    public func isInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: launchAgentPath)
    }
    
    public func isProcessRunning() -> Bool {
        return ProcessUtils.isProcessRunning(
            name: "Puck",
            arguments: ["-f"],
            excludePatterns: ["grep"]
        )
    }
    
    public func isRunning() -> Bool {
        // If service is installed, check if it's actually running via launchctl
        if isInstalled() {
            let result = ProcessUtils.shell("/bin/launchctl", "list")
            
            // Parse launchctl output to find our service and its PID
            let serviceInfo = result.output.split(separator: "\n")
                .map { String($0) }
                .first { line in 
                    line.contains(launchAgentName) 
                }
            
            // If service found and has non-zero PID, it's running
            if let info = serviceInfo {
                let parts = info.split(separator: "\t")
                if parts.count >= 1, let pid = Int(parts[0]), pid > 0 {
                    return true
                }
            }
            return false
        }
        
        // Otherwise check for direct process
        return isProcessRunning()
    }
} 