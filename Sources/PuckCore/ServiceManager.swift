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
    
    public init(plistContent: String, executablePath: String) {
        self.plistContent = plistContent
        self.executablePath = executablePath
        self.launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents"
    }
    
    public func install() throws {
        // Create LaunchAgents directory if it doesn't exist
        try FileManager.default.createDirectory(atPath: launchAgentPath, withIntermediateDirectories: true, attributes: nil)
        
        let plistPath = (launchAgentPath as NSString).appendingPathComponent("\(launchAgentName).plist")
        try PlistTemplate.generate(executablePath: executablePath).write(toFile: plistPath, atomically: true, encoding: .utf8)
        
        let result = ProcessUtils.shell("/bin/launchctl", "load", plistPath)
        if result.status != 0 {
            throw ServiceError.commandFailed("Failed to load service: \(result.output)")
        }
    }
    
    public func uninstall() throws {
        try stop()
        
        let plistPath = (launchAgentPath as NSString).appendingPathComponent("\(launchAgentName).plist")
        if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }
        
        print("Service uninstalled")
    }
    
    public func start() throws {
        let plistPath = (launchAgentPath as NSString).appendingPathComponent("\(launchAgentName).plist")
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw ServiceError.invalidState("Service not installed. Please install first.")
        }
        
        let result = ProcessUtils.shell("/bin/launchctl", "load", plistPath)
        if result.status != 0 {
            throw ServiceError.commandFailed("Failed to start service: \(result.output)")
        }
        
        print("Service started")
    }
    
    public func stop() throws {
        let plistPath = (launchAgentPath as NSString).appendingPathComponent("\(launchAgentName).plist")
        guard FileManager.default.fileExists(atPath: plistPath) else {
            return
        }
        
        let result = ProcessUtils.shell("/bin/launchctl", "unload", plistPath)
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
        let plistPath = (launchAgentPath as NSString).appendingPathComponent("\(launchAgentName).plist")
        return FileManager.default.fileExists(atPath: plistPath)
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