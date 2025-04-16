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
    
    func run() throws {
        let manager = InputManager.shared
        let sources = manager.availableInputSources()
        
        print("Available input sources:")
        for source in sources {
            print("\(source.id) - \"\(source.localizedName)\"")
        }
    }
} 