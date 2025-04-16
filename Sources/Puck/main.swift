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
    
    @Flag(name: .shortAndLong, help: "Run in foreground mode without detaching")
    var foreground = false
    
    @Flag(name: .shortAndLong, help: "Show service status")
    var status = false
    
    @Flag(name: .shortAndLong, help: "Uninstall the service")
    var uninstall = false
    
    private lazy var serviceManager: ServiceManager = {
        // Load plist content
        guard let plistURL = Bundle.module.url(forResource: "com.puck.daemon", withExtension: "plist") else {
            fatalError("Could not find plist file in bundle")
        }
        
        let plistContent: String
        do {
            plistContent = try String(contentsOf: plistURL, encoding: .utf8)
        } catch {
            fatalError("Could not read plist file: \(error)")
        }
        
        let executablePath = ProcessInfo.processInfo.arguments[0]
        return ServiceManager(plistContent: plistContent, executablePath: executablePath)
    }()
    
    mutating func run() throws {
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
        
        if status {
            let isInstalled = serviceManager.isInstalled()
            let isRunning = serviceManager.isRunning()
            
            print("Service status:")
            print("  Installed: \(isInstalled ? "Yes" : "No")")
            print("  Running: \(isRunning ? "Yes" : "No")")
            return
        }
        
        if uninstall {
            print("Uninstalling service...")
            try serviceManager.uninstall()
            return
        }
        
        // Default behavior: ensure service is installed and running
        let configPath = config ?? "\(NSHomeDirectory())/.config/puck/puckrc"
        
        // Check if config file exists
        if !FileManager.default.fileExists(atPath: configPath) {
            print("Error: Configuration file not found at \(configPath)")
            print("Please create a configuration file or specify a custom path with --config")
            return
        }
        
        // If --foreground flag is set, run in foreground
        if foreground {
            let inputManager = try InputMethodManager(configPath: configPath)
            print("Starting Puck in foreground mode with configuration from \(configPath)")
            
            guard inputManager.start() else {
                print("Error: Failed to start input method manager. Make sure you have accessibility permissions enabled.")
                return
            }
            
            // Keep the program running
            RunLoop.current.run()
            return
        }

        do {
            // Check if already running in foreground mode
            if serviceManager.isProcessRunning() {
                print("Puck is already running in foreground mode.")
                return
            }
            
            // If not installed, install and start the service
            if !serviceManager.isInstalled() {
                print("Installing service...")
                try serviceManager.install()
            }
            
            if !serviceManager.isRunning() {
                print("Starting service...")
                try serviceManager.start()
            } else {
                print("Service is already running.")
            }
        } catch {
            print("Error: \(error)")
        }
        Foundation.exit(0)
    }
}

Puck.main() 