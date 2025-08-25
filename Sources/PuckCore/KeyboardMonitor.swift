import Foundation
import Carbon
import Logging

public class KeyboardMonitor {
    public typealias KeyEventHandler = (String, [String]) -> Bool
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let eventHandler: KeyEventHandler
    private let consumeHandledEvents: Bool
    
    public init(consumeHandledEvents: Bool = false, eventHandler: @escaping KeyEventHandler) {
        self.consumeHandledEvents = consumeHandledEvents
        self.eventHandler = eventHandler
    }
    
    public func start() -> Bool {
        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
        )
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                
                // Handle tap disabled events by re-enabling immediately
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = monitor.eventTap {
                        PuckLogger.shared.notice("Event tap disabled (\(type.rawValue)); re-enabling…")
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                // Only process keyDown
                guard type == .keyDown else {
                    return Unmanaged.passRetained(event)
                }

                // Ignore auto-repeat keyDowns to avoid chattering
                let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
                if isAutoRepeat {
                    PuckLogger.shared.trace("Ignoring autorepeat keyDown")
                    return Unmanaged.passRetained(event)
                }

                let handled = monitor.handleKeyEvent(event)
                if handled && monitor.consumeHandledEvents {
                    // Swallow the event so it doesn't reach the focused app / system
                    return nil
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            PuckLogger.shared.error("Failed to create event tap. Accessibility permission?")
            return false
        }
        
        eventTap = tap
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        self.runLoopSource = runLoopSource
        PuckLogger.shared.debug("Event tap installed")
        return true
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        PuckLogger.shared.debug("Event tap stopped")
    }
    
    private func handleKeyEvent(_ event: CGEvent) -> Bool {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        var modifiers: [String] = []
        if flags.contains(.maskShift) { modifiers.append("shift") }
        if flags.contains(.maskControl) { modifiers.append("ctrl") }
        if flags.contains(.maskAlternate) { modifiers.append("alt") }
        if flags.contains(.maskCommand) { modifiers.append("cmd") }
        
        // Convert keycode to string representation
        let keyString = keycodeToString(keycode)
        
        PuckLogger.shared.trace("keyDown: keycode=\(keycode) key=\(keyString) flags=\(flags.rawValue)")
        return eventHandler(keyString, modifiers)
    }
    
    private func keycodeToString(_ keycode: Int64) -> String {
        // Common keycodes mapping
        let keycodeMap: [Int64: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "n", 46: "m", 47: ".", 50: "`",
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            // Special keys
            36: "return", 48: "tab", 49: "space", 51: "delete", 53: "escape",
            123: "left", 124: "right", 125: "down", 126: "up"
        ]
        
        return keycodeMap[keycode] ?? "unknown(\(keycode))"
    }
} 