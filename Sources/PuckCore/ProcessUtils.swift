import Foundation

public enum ProcessUtils {
    /// Execute a shell command and return its status and output
    public static func shell(_ args: String...) -> (status: Int32, output: String) {
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
    
    /// Check if a process matching the given criteria is running
    public static func isProcessRunning(name: String, arguments: [String] = [], excludePatterns: [String] = []) -> Bool {
        let result = shell("/bin/ps", "-ax", "-o", "command")
        let processes = result.output.split(separator: "\n")
            .filter { line in
                let command = String(line)
                
                // Check if command contains the process name
                guard command.contains(name) else { return false }
                
                // Check if command contains all required arguments
                guard arguments.allSatisfy({ command.contains($0) }) else { return false }
                
                // Check if command doesn't contain any exclude patterns
                guard !excludePatterns.contains(where: { command.contains($0) }) else { return false }
                
                return true
            }
            .map { String($0) }
        
        return !processes.isEmpty
    }
} 