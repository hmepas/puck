import Foundation
import PuckCore
import Logging
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
    
    @Option(name: [.customLong("log-level")], help: "Log level: trace, debug, info, notice, warning, error, critical")
    var logLevel: String?
    
    @Option(name: [.customLong("log-file")], help: "Log file path (default: ~/Library/Logs/Puck/puck.log)")
    var logFile: String?
    
    private lazy var serviceManager: ServiceManager = {
        // Load plist content
        let plistContent = ResourceLoader.loadPlistContent()
        let executablePath = ProcessInfo.processInfo.arguments[0]
        return ServiceManager(plistContent: plistContent, executablePath: executablePath)
    }()
    
    mutating func run() throws {
        // Configure logging
        let level = logLevel.flatMap { Logger.Level(rawValue: $0) } ?? .info
        let defaultLogPath = "~/Library/Logs/Puck/puck.log"
        let filePath = logFile ?? defaultLogPath
        PuckLogger.configure(level: level, toFile: filePath)
        var logger = PuckLogger.shared
        logger[metadataKey: "pid"] = "\(getpid())"
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
            logger.info("Starting key observation mode…")
            print("Press keys to see their names and modifiers.")
            print("Press Ctrl+C to exit.")
            
            let monitor = KeyboardMonitor(consumeHandledEvents: false) { key, modifiers in
                if !modifiers.isEmpty {
                    print("\(modifiers.joined(separator: " + ")) + \(key)")
                } else {
                    print(key)
                }
                return false // never consume in observe mode
            }
            
            guard monitor.start() else {
                logger.error("Failed to start key monitoring. Accessibility permissions missing?")
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
            logger.info("Uninstalling service…")
            try serviceManager.uninstall()
            return
        }
        
        // Default behavior: ensure service is installed and running
        let configPath = config ?? "\(NSHomeDirectory())/.config/puck/puckrc"
        
        // Check if config file exists
        if !FileManager.default.fileExists(atPath: configPath) {
            logger.error("Configuration file not found at \(configPath)")
            print("Please create a configuration file or specify a custom path with --config")
            return
        }
        
        // If --foreground flag is set, run in foreground
        if foreground {
            let inputManager = try InputMethodManager(configPath: configPath)
            logger.info("Starting Puck in foreground mode with configuration from \(configPath)")
            
            guard inputManager.start() else {
                logger.error("Failed to start input method manager. Accessibility permissions missing?")
                return
            }
            
            // Keep the program running
            RunLoop.current.run()
            return
        }

        do {
            // Check if already running in foreground mode
            if serviceManager.isProcessRunning() {
                logger.notice("Puck is already running in foreground mode.")
                return
            }
            
            // If not installed, install and start the service
            if !serviceManager.isInstalled() {
                logger.info("Installing service…")
                try serviceManager.install()
            }
            
            if !serviceManager.isRunning() {
                logger.info("Starting service…")
                try serviceManager.start()
            } else {
                logger.info("Service is already running.")
            }
        } catch {
            logger.error("\(String(describing: error))")
        }
        Foundation.exit(0)
    }
}

Puck.main() 