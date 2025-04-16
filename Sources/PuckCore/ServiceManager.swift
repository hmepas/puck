import Foundation

public enum ServiceError: Error {
    case fileOperationFailed(String)
    case commandFailed(String)
    case invalidState(String)
}

public class ServiceManager {
    private let launchAgentName = "com.puck.daemon"
    private let launchAgentPath: String
    private let executablePath: String
    
    public init() {
        self.launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(launchAgentName).plist"
        // Get the path to the current executable
        self.executablePath = Bundle.main.executablePath ?? "/usr/local/bin/puck"
    }
    
    public func install() throws {
        // Create LaunchAgents directory if it doesn't exist
        try FileManager.default.createDirectory(
            atPath: "\(NSHomeDirectory())/Library/LaunchAgents",
            withIntermediateDirectories: true
        )
        
        // Copy plist file to LaunchAgents
        guard let plistSource = Bundle.main.path(forResource: "com.puck.daemon", ofType: "plist") else {
            throw ServiceError.fileOperationFailed("Could not find plist file in bundle")
        }
        
        // Update plist with correct executable path
        let plistContent = try String(contentsOfFile: plistSource, encoding: .utf8)
        let updatedContent = plistContent.replacingOccurrences(
            of: "/usr/local/bin/puck",
            with: executablePath
        )
        
        try updatedContent.write(
            toFile: launchAgentPath,
            atomically: true,
            encoding: .utf8
        )
        
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
        
        let result = shell("launchctl", "load", launchAgentPath)
        if result.status != 0 {
            throw ServiceError.commandFailed("Failed to start service: \(result.output)")
        }
        
        print("Service started")
    }
    
    public func stop() throws {
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            return
        }
        
        let result = shell("launchctl", "unload", launchAgentPath)
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
    
    private func shell(_ args: String...) -> (status: Int32, output: String) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = args
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        
        try? task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        
        return (task.terminationStatus, output)
    }
} 