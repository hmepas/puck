import Foundation
import PuckCore
import ArgumentParser
import Carbon

@main
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
        
        if installService {
            print("Installing launchd service...")
            // TODO: Implement service installation
            return
        }
        
        if uninstallService {
            print("Uninstalling launchd service...")
            // TODO: Implement service uninstallation
            return
        }
        
        if startService {
            print("Starting service...")
            // TODO: Implement service start
            return
        }
        
        if stopService {
            print("Stopping service...")
            // TODO: Implement service stop
            return
        }
        
        if restartService {
            print("Restarting service...")
            // TODO: Implement service restart
            return
        }
        
        // Default behavior: start the daemon
        print("Starting Puck daemon...")
        // TODO: Implement daemon mode
    }
} 