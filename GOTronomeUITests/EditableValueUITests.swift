//
//  EditableValueUITests.swift
//  GOTronomeUITests
//
//  Created by Paolo De Pascalis on 30.07.26.
//

import XCTest

/// Covers the tap-to-type value field. Focus and commit behaviour is the part that breaks
/// silently, so it is worth holding down with a test rather than eyeballing.
final class EditableValueUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// In Basic mode the BPM field is the only text field on screen.
    private func bpmField(_ app: XCUIApplication) -> XCUIElement {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "BPM field never appeared")
        return field
    }

    private func commit(_ app: XCUIApplication) {
        app.buttons["Done"].firstMatch.tap()
    }

    @MainActor
    func testTypedValueIsAcceptedAndClampedToRange() throws {
        let app = XCUIApplication()
        app.launch()
        let field = bpmField(app)

        field.tap()
        field.typeText("137")
        commit(app)
        XCTAssertEqual(field.value as? String, "137", "a precise value should be accepted")

        field.tap()
        field.typeText("999")
        commit(app)
        XCTAssertEqual(field.value as? String, "240", "above the range should clamp to the max")

        field.tap()
        field.typeText("5")
        commit(app)
        XCTAssertEqual(field.value as? String, "20", "below the range should clamp to the min")
    }

    @MainActor
    func testEmptyInputLeavesTheValueAlone() throws {
        let app = XCUIApplication()
        app.launch()
        let field = bpmField(app)

        field.tap()
        field.typeText("90")
        commit(app)
        XCTAssertEqual(field.value as? String, "90")

        // Focus clears the field; committing with nothing typed should revert, not zero it.
        field.tap()
        commit(app)
        XCTAssertEqual(field.value as? String, "90", "empty input should leave the value unchanged")
    }

    @MainActor
    func testFieldSurvivesFocusAndDoesNotStartTheMetronome() throws {
        let app = XCUIApplication()
        app.launch()
        let field = bpmField(app)

        field.tap()
        // The Android port had the field commit and close itself on the frame it opened. If that
        // happens here the keyboard's Done button will not be around to find.
        XCTAssertTrue(
            app.buttons["Done"].firstMatch.waitForExistence(timeout: 5),
            "field lost focus immediately after being tapped"
        )
        // Tapping the field must not fall through to the global tap-to-start handler, which would
        // swap the settings screen out for the playing view and take the field with it.
        XCTAssertTrue(field.exists, "tapping the value started the metronome")
        commit(app)
    }

    /// The keyboard toolbar is attached unconditionally because the `if isFocused` form needs
    /// iOS 16. This pins down that two fields on screen still yield a single Done button.
    @MainActor
    func testOnlyOneDoneButtonWithTwoFieldsOnScreen() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Silent Bars"].tap()
        XCTAssertEqual(app.textFields.count, 2, "expected BPM plus silent bars")

        app.textFields.element(boundBy: 0).tap()
        XCTAssertEqual(
            app.buttons.matching(identifier: "Done").count, 1,
            "each field contributes a keyboard toolbar; only the focused one should show"
        )
    }
}
