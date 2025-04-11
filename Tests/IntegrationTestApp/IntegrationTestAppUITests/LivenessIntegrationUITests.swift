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
        XCTAssert(app!.staticTexts[UIConstants.BeginCheck.warningTitle].exists)
        XCTAssert(app!.staticTexts[UIConstants.BeginCheck.warningDescription].exists)
        XCTAssert(app!.staticTexts[UIConstants.BeginCheck.instruction].exists)
    }
    
    func testStartLivenessIntegration() throws {
        XCTAssertEqual(app!.label, UIConstants.appName)
        XCTAssert(app!.buttons[UIConstants.primaryButton].exists)
        XCTAssert(app!.buttons[UIConstants.primaryButton].isEnabled)
        app?.buttons[UIConstants.primaryButton].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssert(app!.buttons[UIConstants.BeginCheck.primaryButton].exists)
        app!.buttons[UIConstants.BeginCheck.primaryButton].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssert(app!.buttons[UIConstants.LivenessCheck.closeButton].exists)
        XCTAssert(app!.staticTexts[UIConstants.LivenessCheck.moveInstruction].exists)
        Thread.sleep(forTimeInterval: 4)
        XCTAssert(app!.staticTexts[UIConstants.LivenessCheck.holdInstruction].exists)
        Thread.sleep(forTimeInterval: 8)
        XCTAssert(app!.buttons[UIConstants.LivenessResult.primaryButton].exists)
        XCTAssert(app!.staticTexts[UIConstants.LivenessResult.result].exists)
        XCTAssert(app!.staticTexts[UIConstants.LivenessResult.confidence].exists)
    }
}
