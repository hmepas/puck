import Foundation
import ServiceManagement

public enum ServiceError: Error {
    case fileOperationFailed(String)
    case commandFailed(String)
    case invalidState(String)
    case systemError(String)
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
        
        let result = shell("/bin/launchctl", "load", launchAgentPath)
        if result.status != 0 {
            throw ServiceError.commandFailed("Failed to start service: \(result.output)")
        }
        
        print("Service started")
    }
    
    public func stop() throws {
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            return
        }
        
        let result = shell("/bin/launchctl", "unload", launchAgentPath)
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
    
    public func isRunning() -> Bool {
        // Check if running as a direct process first
        if isProcessRunning() {
            return true
        }
        
        // Then check if running as a service
        let result = shell("/bin/launchctl", "list", launchAgentName)
        return result.status == 0
    }
    
    private func isProcessRunning() -> Bool {
        let type = UInt32(PROC_ALL_PIDS)
        var pids = [Int32](repeating: 0, count: 2048)
        var found = false
        
        pids.withUnsafeMutableBufferPointer { buffer in
            let size = Int32(buffer.count * MemoryLayout<pid_t>.size)
            let count = proc_listpids(type, 0, buffer.baseAddress, size)
            guard count > 0 else {
                return
            }
            
            let currentPid = ProcessInfo.processInfo.processIdentifier
            
            for i in 0..<Int(count) {
                let pid = buffer[i]
                if pid <= 0 || pid == currentPid {
                    continue
                }
                
                var pathBuffer = [Int8](repeating: 0, count: Int(MAXPATHLEN))
                let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
                
                if pathLength > 0 {
                    let procPath = String(cString: pathBuffer)
                    if procPath.contains("Puck") {
                        found = true
                        return
                    }
                }
            }
        }
        
        return found
    }
    
    private func proc_name(_ pid: Int32, _ buffer: UnsafeMutablePointer<Int8>, _ bufferSize: UInt32) {
        var name = [Int32](repeating: 0, count: 4)
        name[0] = CTL_KERN
        name[1] = KERN_PROC
        name[2] = KERN_PROC_PID
        name[3] = pid
        
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        
        let result = sysctl(&name, 4, &info, &size, nil, 0)
        if result == 0 {
            withUnsafeBytes(of: info.kp_proc.p_comm) { ptr in
                let data = ptr.bindMemory(to: Int8.self)
                for i in 0..<min(Int(bufferSize) - 1, data.count) {
                    buffer[i] = data[i]
                }
            }
        }
    }
    
    private func shell(_ args: String...) -> (status: Int32, output: String) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = Array(args.dropFirst())
        task.executableURL = URL(fileURLWithPath: args[0])
        
        do {
            try task.run()
        } catch {
            return (1, error.localizedDescription)
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        task.waitUntilExit()
        
        return (task.terminationStatus, output)
    }
} 