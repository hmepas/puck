import Foundation
import PuckCore
import ArgumentParser
import Carbon

struct Puck: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "puck",
        abstract: "A swift input method switching daemon for macOS",
        version: "0.1.0"
    )
    
    @Flag(name: .shortAndLong, help: "List all available input sources")
    var list = false
    
    @Flag(name: .shortAndLong, help: "Observe keyboard events to help with configuration")
    var observe = false
    
    @Option(name: .shortAndLong, help: "Use a specific configuration file path")
    var config: String?
    
    @Flag(help: "Install the launchd service")
    var installService = false
    
    @Flag(help: "Uninstall the launchd service")
    var uninstallService = false
    
    @Flag(help: "Start the launchd service")
    var startService = false
    
    @Flag(help: "Stop the launchd service")
    var stopService = false
    
    @Flag(help: "Restart the launchd service")
    var restartService = false
    
    func run() throws {
        let manager = InputManager.shared
        
        if list {
            // List available input sources
            let sources = manager.availableInputSources()
            print("Available input sources:")
            for source in sources {
                print("\(source.id) - \"\(source.localizedName)\"")
            }
            return
        }
        
        if observe {
            print("Starting key observation mode...")
            print("Press keys to see their names and modifiers.")
            print("Press Ctrl+C to exit.")
            
            let monitor = KeyboardMonitor { key, modifiers in
                if !modifiers.isEmpty {
                    print("\(modifiers.joined(separator: " + ")) + \(key)")
                } else {
                    print(key)
                }
            }
            
            guard monitor.start() else {
                print("Error: Failed to start key monitoring. Make sure you have accessibility permissions enabled.")
                return
            }
            
            // Keep the program running
            RunLoop.current.run()
            return
        }
        
        // Service management commands
        let serviceManager = ServiceManager()
        
        if installService {
            print("Installing launchd service...")
            try serviceManager.install()
            try serviceManager.start()
            return
        }
        
        if uninstallService {
            print("Uninstalling launchd service...")
            try serviceManager.uninstall()
            return
        }
        
        if startService {
            print("Starting service...")
            try serviceManager.start()
            return
        }
        
        if stopService {
            print("Stopping service...")
            try serviceManager.stop()
            return
        }
        
        if restartService {
            print("Restarting service...")
            try serviceManager.restart()
            return
        }
        
        // Default behavior: start in foreground if not running as service
        let configPath = config ?? "\(NSHomeDirectory())/.config/puck/puckrc"
        
        // Check if config file exists
        if !FileManager.default.fileExists(atPath: configPath) {
            print("Error: Configuration file not found at \(configPath)")
            print("Please create a configuration file or specify a custom path with --config")
            return
        }
        
        do {
            let inputManager = try InputMethodManager(configPath: configPath)
            print("Starting Puck in foreground mode with configuration from \(configPath)")
            print("Use --install-service to run as a background service")
            
            guard inputManager.start() else {
                print("Error: Failed to start input method manager. Make sure you have accessibility permissions enabled.")
                return
            }
            
            // Keep the program running
            RunLoop.current.run()
        } catch {
            print("Error: Failed to initialize input method manager: \(error)")
        }
    }
}

Puck.main() 