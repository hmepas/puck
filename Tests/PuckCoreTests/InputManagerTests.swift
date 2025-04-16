import XCTest
@testable import PuckCore

final class InputManagerTests: XCTestCase {
    var manager: InputManager!
    
    override func setUp() {
        super.setUp()
        manager = InputManager.shared
        manager.clear() // Ensure clean state
    }
    
    override func tearDown() {
        manager.clear()
        super.tearDown()
    }
    
    func testAvailableInputSources() {
        let sources = manager.availableInputSources()
        XCTAssertFalse(sources.isEmpty, "System should have at least one input source")
    }
    
    func testCurrentInputSource() {
        let current = manager.currentInputSource()
        XCTAssertNotNil(current, "Current input source should not be nil")
    }
    
    func testSingleHotkeyMapping() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        let inputSourceId = "test.input.source"
        
        manager.add(hotkey: hotkey, inputSourceId: inputSourceId)
        
        // Since we're using a fake input source ID, this should return false
        XCTAssertFalse(manager.handleHotkey(hotkey))
    }
    
    func testCyclingBehavior() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        let sources = ["source1", "source2", "source3"]
        
        sources.forEach { manager.add(hotkey: hotkey, inputSourceId: $0) }
        
        // Test cycling through sources
        // Since we're using fake input source IDs, this should return false
        for _ in 0..<5 {
            XCTAssertFalse(manager.handleHotkey(hotkey))
        }
    }
    
    func testDuplicateSourcePrevention() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        let sourceId = "test.source"
        
        // Add the same source twice
        manager.add(hotkey: hotkey, inputSourceId: sourceId)
        manager.add(hotkey: hotkey, inputSourceId: sourceId)
        
        // Handle the hotkey to ensure no crashes with duplicate prevention
        XCTAssertFalse(manager.handleHotkey(hotkey))
    }
    
    func testRealInputSourceSwitch() {
        // Get actual input sources from the system
        let sources = manager.availableInputSources()
        guard sources.count >= 2 else {
            // Skip test if we don't have enough input sources
            return
        }
        
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        manager.add(hotkey: hotkey, inputSourceId: sources[0].id)
        
        // This should actually work since we're using a real input source ID
        XCTAssertTrue(manager.handleHotkey(hotkey))
    }
} 