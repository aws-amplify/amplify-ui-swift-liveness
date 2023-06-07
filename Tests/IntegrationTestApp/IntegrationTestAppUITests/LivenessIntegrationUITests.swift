//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest

class CreateLivenessSessionUITests: XCTestCase {
    
    var app: XCUIApplication?
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app?.launchEnvironment.updateValue("YES", forKey: "UITesting")
        app?.launchEnvironment.updateValue("mock1", forKey: "LivenessMockFileName")
        app?.launchEnvironment.updateValue("mov", forKey: "UITesting")
        app?.launch()
      }
    
    func testCreateLivenessSessionUI() throws {
        XCTAssertEqual(app!.label, "Liveness")
        XCTAssert(app!.buttons["Create Liveness Session"].exists)
        XCTAssert(app!.buttons["Create Liveness Session"].isEnabled)
        app?.buttons["Create Liveness Session"].tap()
        Thread.sleep(forTimeInterval: 4)
        XCTAssert(app!.buttons["Begin Check"].exists)
        XCTAssertFalse(app!.buttons["Create Liveness Session"].exists)
    }
    
    func testBeginCheckUI() throws {
        XCTAssertEqual(app!.label, "Liveness")
        XCTAssert(app!.buttons["Create Liveness Session"].exists)
        XCTAssert(app!.buttons["Create Liveness Session"].isEnabled)
        app!.buttons["Create Liveness Session"].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssert(app!.buttons[UIConstants.BeginCheck.primaryButton].exists)
        XCTAssertFalse(app!.buttons["Create Liveness Session"].exists)
        let scrollViewsQuery = app!.scrollViews
        let elementsQuery = scrollViewsQuery.otherElements
        XCTAssert(elementsQuery.staticTexts[UIConstants.BeginCheck.description].exists)
        XCTAssert(elementsQuery.buttons[UIConstants.BeginCheck.warning].exists)
        XCTAssert(elementsQuery.staticTexts[UIConstants.BeginCheck.instruction].exists)
    }
    
    func testStartLivenessIntegration() throws {
        XCTAssertEqual(app!.label, "Liveness")
        XCTAssert(app!.buttons["Create Liveness Session"].exists)
        XCTAssert(app!.buttons["Create Liveness Session"].isEnabled)
        app?.buttons["Create Liveness Session"].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssert(app!.buttons[UIConstants.BeginCheck.primaryButton].exists)
        XCTAssertFalse(app!.buttons["Create Liveness Session"].exists)
        app!.buttons[UIConstants.BeginCheck.primaryButton].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssert(app!.staticTexts[UIConstants.LivenessCheck.countdownInstruction].exists)
        XCTAssert(app!.buttons[UIConstants.LivenessCheck.closeButton].exists)
        Thread.sleep(forTimeInterval: 3)
        XCTAssert(app!.staticTexts[UIConstants.LivenessCheck.moveInstruction].exists)
        Thread.sleep(forTimeInterval: 3)
        XCTAssert(app!.staticTexts[UIConstants.LivenessCheck.holdInstruction].exists)
        Thread.sleep(forTimeInterval: 8)
        XCTAssert(app!.buttons[UIConstants.LivenessResult.primaryButton].exists)
        XCTAssert(app!.staticTexts[UIConstants.LivenessResult.result].exists)
        XCTAssert(app!.staticTexts[UIConstants.LivenessResult.confidence].exists)
    }
}
