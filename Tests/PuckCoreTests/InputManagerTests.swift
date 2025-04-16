import XCTest
import Carbon
@testable import PuckCore

struct TestInputSource: InputSourceType {
    let id: String
    let name: String
    let selectableValue: Bool
    
    var identifier: String? { id }
    var localizedName: String? { name }
    var isSelectable: Bool? { selectableValue }
}

class TISWrapperStub: TISWrapperProtocol {
    // Test data
    let allSources: [TestInputSource] = [
        // Selectable keyboard layouts (should be included)
        TestInputSource(id: "com.apple.keylayout.US", name: "U.S.", selectableValue: true),
        TestInputSource(id: "com.apple.keylayout.Russian", name: "Russian", selectableValue: true),
        
        // Non-selectable keyboard layouts (should be excluded)
        TestInputSource(id: "com.apple.keylayout.NonSelectable", name: "Non-Selectable Layout", selectableValue: false),
        
        // Selectable input method (should be included)
        TestInputSource(id: "com.apple.inputmethod.SCIM", name: "Pinyin", selectableValue: true),
        
        // Non-selectable input method (should be excluded)
        TestInputSource(id: "com.apple.inputmethod.NonSelectable", name: "Non-Selectable Input Method", selectableValue: false),
        
        // Non-keyboard/input method sources (should be excluded regardless of selectable)
        TestInputSource(id: "com.apple.CharacterPaletteIM", name: "Character Viewer", selectableValue: true),
        TestInputSource(id: "com.apple.PressAndHold", name: "Press and Hold", selectableValue: true),
        
        // Edge cases
        TestInputSource(id: "com.apple.keylayout.", name: "Empty Layout", selectableValue: true),  // Invalid layout ID
        TestInputSource(id: "com.apple.inputmethod.", name: "Empty Input Method", selectableValue: true),  // Invalid input method ID
        TestInputSource(id: "", name: "", selectableValue: true)  // Empty source
    ]
    
    var currentSource: TestInputSource
    var selectedSource: TestInputSource?
    
    init() {
        self.currentSource = allSources[0]
    }
    
    func createInputSourceList() -> [InputSourceType]? {
        return allSources
    }
    
    func copyCurrentKeyboardInputSource() -> InputSourceType? {
        return currentSource
    }
    
    func selectInputSource(_ inputSource: InputSourceType) -> OSStatus {
        guard let id = inputSource.identifier,
              let stub = allSources.first(where: { $0.id == id }) else {
            return -1
        }
        selectedSource = stub
        currentSource = stub
        return noErr
    }
}

final class InputManagerTests: XCTestCase {
    var inputManager: InputManager!
    var tisWrapper: TISWrapperStub!
    
    override func setUp() {
        super.setUp()
        tisWrapper = TISWrapperStub()
        inputManager = InputManager(tisWrapper: tisWrapper)
    }
    
    func testAvailableInputSourcesFiltering() {
        let sources = inputManager.availableInputSources()
        
        // Test 1: Only selectable keyboard layouts and input methods should be included
        XCTAssertEqual(sources.count, 3, "Should only include 3 sources (US, Russian, and Pinyin)")
        
        // Test 2: Verify selectable keyboard layouts are included
        XCTAssertTrue(sources.contains { $0.id == "com.apple.keylayout.US" }, "Selectable US layout should be included")
        XCTAssertTrue(sources.contains { $0.id == "com.apple.keylayout.Russian" }, "Selectable Russian layout should be included")
        
        // Test 3: Verify non-selectable keyboard layouts are excluded
        XCTAssertFalse(sources.contains { $0.id == "com.apple.keylayout.NonSelectable" }, "Non-selectable layout should be excluded")
        
        // Test 4: Verify selectable input methods are included
        XCTAssertTrue(sources.contains { $0.id == "com.apple.inputmethod.SCIM" }, "Selectable input method should be included")
        
        // Test 5: Verify non-selectable input methods are excluded
        XCTAssertFalse(sources.contains { $0.id == "com.apple.inputmethod.NonSelectable" }, "Non-selectable input method should be excluded")
        
        // Test 6: Verify non-keyboard/input method sources are excluded regardless of selectable status
        XCTAssertFalse(sources.contains { $0.id == "com.apple.CharacterPaletteIM" }, "Character Viewer should be excluded")
        XCTAssertFalse(sources.contains { $0.id == "com.apple.PressAndHold" }, "Press and Hold should be excluded")
        
        // Test 7: Verify edge cases are handled
        XCTAssertFalse(sources.contains { $0.id == "com.apple.keylayout." }, "Invalid layout ID should be excluded")
        XCTAssertFalse(sources.contains { $0.id == "com.apple.inputmethod." }, "Invalid input method ID should be excluded")
        XCTAssertFalse(sources.contains { $0.id == "" }, "Empty source should be excluded")
    }
    
    func testCurrentInputSource() {
        let currentSource = inputManager.currentInputSource()
        XCTAssertNotNil(currentSource)
        XCTAssertEqual(currentSource?.id, "com.apple.keylayout.US")
        XCTAssertEqual(currentSource?.localizedName, "U.S.")
    }
    
    func testHotkeyMapping() {
        // Create test data
        let hotkey = Hotkey(keyCode: 0, modifiers: 256)
        let inputSource = InputSource(id: "com.apple.keylayout.Russian", localizedName: "Russian")
        
        // Add hotkey mapping
        inputManager.add(hotkey: hotkey, for: inputSource)
        
        // Test hotkey handling
        XCTAssertTrue(inputManager.handleHotkey(hotkey))
        XCTAssertEqual(tisWrapper.selectedSource?.id, "com.apple.keylayout.Russian")
        
        // Test non-existent hotkey
        let nonExistentHotkey = Hotkey(keyCode: 1, modifiers: 256)
        XCTAssertFalse(inputManager.handleHotkey(nonExistentHotkey))
    }
    
    func testHotkeyMappingWithNonExistentSource() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        let inputSource = InputSource(id: "non.existent.source", localizedName: "Non-existent")
        
        inputManager.add(hotkey: hotkey, for: inputSource)
        XCTAssertFalse(inputManager.handleHotkey(hotkey))
    }
    
    func testSingleHotkeyMapping() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        let inputSource = InputSource(id: "test.input.source", localizedName: "Test Source")
        
        inputManager.add(hotkey: hotkey, for: inputSource)
        
        // Since we're using a fake input source ID, this should return false
        XCTAssertFalse(inputManager.handleHotkey(hotkey))
    }
    
    func testCyclingBehavior() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        let sources = [
            InputSource(id: "source1", localizedName: "Source 1"),
            InputSource(id: "source2", localizedName: "Source 2"),
            InputSource(id: "source3", localizedName: "Source 3")
        ]
        
        sources.forEach { inputManager.add(hotkey: hotkey, for: $0) }
        
        // Test cycling through sources
        // Since we're using fake input source IDs, this should return false
        for _ in 0..<5 {
            XCTAssertFalse(inputManager.handleHotkey(hotkey))
        }
    }
    
    func testDuplicateSourcePrevention() {
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        let inputSource = InputSource(id: "test.source", localizedName: "Test Source")
        
        // Add the same source twice
        inputManager.add(hotkey: hotkey, for: inputSource)
        inputManager.add(hotkey: hotkey, for: inputSource)
        
        // Handle the hotkey to ensure no crashes with duplicate prevention
        XCTAssertFalse(inputManager.handleHotkey(hotkey))
    }
    
    func testRealInputSourceSwitch() {
        // Get actual input sources from the system
        let sources = inputManager.availableInputSources()
        guard sources.count >= 2 else {
            // Skip test if we don't have enough input sources
            return
        }
        
        let hotkey = Hotkey(keyCode: 0, modifiers: 0)
        inputManager.add(hotkey: hotkey, for: sources[0])
        
        // This should actually work since we're using a real input source ID
        XCTAssertTrue(inputManager.handleHotkey(hotkey))
    }
} 