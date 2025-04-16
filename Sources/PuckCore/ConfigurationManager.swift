import Foundation

public struct ConfigHotkey: Hashable {
    public let modifiers: Set<String>
    public let key: String
    
    public init(modifiers: Set<String>, key: String) {
        self.modifiers = modifiers
        self.key = key
    }
    
    public static func from(keyString: String, modifiers: [String]) -> ConfigHotkey {
        return ConfigHotkey(modifiers: Set(modifiers), key: keyString)
    }
}

public struct HotkeyAction {
    public let inputSourceID: String
    public let isPartOfCycle: Bool
    
    public init(inputSourceID: String, isPartOfCycle: Bool = false) {
        self.inputSourceID = inputSourceID
        self.isPartOfCycle = isPartOfCycle
    }
}

public class ConfigurationManager {
    private var hotkeyMap: [ConfigHotkey: [HotkeyAction]] = [:]
    private var cycleIndexMap: [Set<ConfigHotkey>: Int] = [:]
    
    public init() {}
    
    public func loadConfiguration(from path: String) throws {
        let fileContents = try String(contentsOfFile: path, encoding: .utf8)
        let lines = fileContents.components(separatedBy: .newlines)
        
        var currentCycleHotkeys: Set<ConfigHotkey> = []
        var currentCycleActions: [HotkeyAction] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Parse the line
            let components = trimmedLine.components(separatedBy: ":")
            guard components.count == 2 else {
                continue
            }
            
            let hotkeyStr = components[0].trimmingCharacters(in: .whitespaces)
            let inputSourceID = components[1].trimmingCharacters(in: .whitespaces)
            
            // Parse hotkey string (e.g., "cmd + shift - space")
            let hotkeyParts = hotkeyStr.components(separatedBy: "-")
            guard hotkeyParts.count == 2 else { continue }
            
            let modifiersStr = hotkeyParts[0].trimmingCharacters(in: .whitespaces)
            let key = hotkeyParts[1].trimmingCharacters(in: .whitespaces)
            
            let modifiers = modifiersStr
                .components(separatedBy: "+")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            let hotkey = ConfigHotkey(modifiers: Set(modifiers), key: key)
            let action = HotkeyAction(inputSourceID: inputSourceID)
            
            // Check if this hotkey is part of a cycle
            if let existingActions = hotkeyMap[hotkey] {
                // This hotkey already exists, so it's part of a cycle
                var updatedActions = existingActions
                updatedActions.append(HotkeyAction(inputSourceID: inputSourceID, isPartOfCycle: true))
                hotkeyMap[hotkey] = updatedActions
                
                // Update cycle tracking
                currentCycleHotkeys.insert(hotkey)
                currentCycleActions.append(action)
            } else {
                // New hotkey
                hotkeyMap[hotkey] = [action]
                
                // Reset cycle tracking
                if !currentCycleHotkeys.isEmpty {
                    cycleIndexMap[currentCycleHotkeys] = 0
                    currentCycleHotkeys = []
                    currentCycleActions = []
                }
            }
        }
        
        // Handle any remaining cycle
        if !currentCycleHotkeys.isEmpty {
            cycleIndexMap[currentCycleHotkeys] = 0
        }
    }
    
    public func getActions(for hotkey: ConfigHotkey) -> [HotkeyAction]? {
        return hotkeyMap[hotkey]
    }
    
    public func nextActionInCycle(for hotkey: ConfigHotkey) -> HotkeyAction? {
        guard let actions = hotkeyMap[hotkey], actions.count > 1 else {
            return hotkeyMap[hotkey]?.first
        }
        
        // Find the cycle this hotkey belongs to
        let cycle = cycleIndexMap.keys.first { $0.contains(hotkey) }
        guard let currentCycle = cycle else { return actions.first }
        
        // Get and increment the cycle index
        var currentIndex = cycleIndexMap[currentCycle] ?? 0
        currentIndex = (currentIndex + 1) % actions.count
        cycleIndexMap[currentCycle] = currentIndex
        
        return actions[currentIndex]
    }
} 