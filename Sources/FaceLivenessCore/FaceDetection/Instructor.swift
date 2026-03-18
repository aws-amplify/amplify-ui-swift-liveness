//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

class Instructor {
    init(
        previousInstruction: Instructor.Instruction? = nil,
        runningCount: Int = 0
    ) {
        self.previousInstruction = previousInstruction
        self.runningCount = runningCount
    }

    enum Instruction: Equatable {
        case `match`
        case tooFarLeft(
            text: String = "Move head right",
            nearnessPercentage: Double
        )
        case tooFarRight(
            text: String = "Move head left",
            nearnessPercentage: Double
        )
        case tooClose(
            text: String = "Move head farther.",
            nearnessPercentage: Double
        )
        case tooFar(
            text: String = "Move head closer.",
            nearnessPercentage: Double
        )
        case none

        static func == (lhs: Instruction, rhs: Instruction) -> Bool {
            switch (lhs, rhs) {
            case (.match, .match): return true
            case (.tooFarLeft, .tooFarLeft): return true
            case (.tooFarRight, .tooFarRight): return true
            case (.tooClose, .tooClose): return true
            case (.tooFar, .tooFar): return true
            default: return false
            }
        }
    }

    var previousInstruction: Instruction?
    var runningCount = 0

    func instruction(for update: Instruction) -> Instruction {
        if previousInstruction == update {
            runningCount += 1
            if runningCount >= 15 {
                return update
            }
            return .none
        } else {
            previousInstruction = update
            runningCount = 0
        }
        return .none
    }
}
