//
//  StartTapUITests.swift
//  GOTronomeUITests
//
//  Any tap on the settings screen that doesn't land on a control should start playback,
//  matching Android. Hit-testing around UIKit-backed controls is where this breaks.
//

import XCTest

final class StartTapUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func isStopped(_ app: XCUIApplication) -> Bool {
        app.staticTexts["Tap to start"].waitForExistence(timeout: 2)
    }

    /// Taps `point`, reports whether playback started, and stops it again.
    private func startsPlayback(_ app: XCUIApplication, at point: CGPoint) -> Bool {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        // A tap that opens a menu also hides the settings from the accessibility tree, so
        // require the settings to be gone with no menu showing.
        let settingsGone = !app.staticTexts["Mode"].waitForExistence(timeout: 1.5)
        let menuOpen = app.collectionViews.count > 0 || app.menus.count > 0
        let started = settingsGone && !menuOpen
        if settingsGone || menuOpen {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(isStopped(app), "could not get back to settings after tapping \(point)")
        }
        return started
    }

    @MainActor
    func testTapsOutsideControlsStartPlayback() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(isStopped(app), "settings screen never appeared")

        let width = app.windows.firstMatch.frame.width
        let style = app.staticTexts["Style"].firstMatch.frame
        let bpm = app.staticTexts["BPM"].firstMatch.frame
        let mode = app.staticTexts["Mode"].firstMatch.frame
        let timeSignature = app.staticTexts["Time"].firstMatch.frame

        let spots: [(String, CGPoint)] = [
            ("Style label", CGPoint(x: style.midX, y: style.midY)),
            ("Style row gap 35%", CGPoint(x: width * 0.35, y: style.midY)),
            ("Style row gap 50%", CGPoint(x: width * 0.5, y: style.midY)),
            ("BPM label", CGPoint(x: bpm.midX, y: bpm.midY)),
            ("between Mode and TS rows", CGPoint(x: mode.midX, y: (mode.maxY + timeSignature.minY) / 2)),
            ("bottom start area", CGPoint(x: width * 0.5, y: app.windows.firstMatch.frame.maxY - 120)),
        ]

        let failures = spots.filter { !startsPlayback(app, at: $0.1) }.map(\.0)
        XCTAssertTrue(failures.isEmpty, "taps that did not start playback: \(failures)")

        // Proves the check can tell a control apart: the picker opens its menu instead.
        XCTAssertFalse(startsPlayback(app, at: CGPoint(x: width * 0.85, y: style.midY)),
                       "tapping the style picker should not start playback")
    }
}
