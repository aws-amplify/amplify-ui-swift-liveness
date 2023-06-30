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
        app?.launch()
      }
    
    func testBeginCheckUI() throws {
        XCTAssertEqual(app!.label, UIConstants.appName)
        XCTAssert(app!.buttons[UIConstants.primaryButton].exists)
        XCTAssert(app!.buttons[UIConstants.primaryButton].isEnabled)
        app!.buttons[UIConstants.primaryButton].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssert(app!.buttons[UIConstants.BeginCheck.primaryButton].exists)
        XCTAssertFalse(app!.buttons[UIConstants.primaryButton].exists)
        let scrollViewsQuery = app!.scrollViews
        let elementsQuery = scrollViewsQuery.otherElements
        XCTAssertEqual(elementsQuery.staticTexts.element(boundBy: 1).label, UIConstants.BeginCheck.description)
        XCTAssert(elementsQuery.buttons[UIConstants.BeginCheck.warning].exists)
        XCTAssert(elementsQuery.staticTexts[UIConstants.BeginCheck.instruction].exists)
    }
    
    func testStartLivenessIntegration() throws {
        XCTAssertEqual(app!.label, UIConstants.appName)
        XCTAssert(app!.buttons[UIConstants.primaryButton].exists)
        XCTAssert(app!.buttons[UIConstants.primaryButton].isEnabled)
        app?.buttons[UIConstants.primaryButton].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssert(app!.buttons[UIConstants.BeginCheck.primaryButton].exists)
        XCTAssertFalse(app!.buttons[UIConstants.primaryButton].exists)
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
