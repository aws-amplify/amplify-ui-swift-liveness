//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Amplify
@testable import FaceLiveness
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// Records every line logged, with its level.
final class MockLogger: Logger, @unchecked Sendable {
    struct Entry: Equatable {
        let level: LogLevel
        let message: String
    }

    private let lock = NSLock()
    private var storage: [Entry] = []
    private var levelWrites = 0
    private var errorOverloadCalls = 0

    var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var messages: [String] { entries.map(\.message) }

    /// How often `logLevel` was set, which the library must never do.
    var logLevelWriteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return levelWrites
    }

    /// How often `error(error:)` was called, which would lose the message.
    var errorOverloadCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return errorOverloadCalls
    }

    /// The lines for the event called `name`, such as `"SessionEnded"`.
    func lines(named name: String) -> [String] {
        messages.filter { $0 == "Liveness \(name)" || $0.hasPrefix("Liveness \(name)(") }
    }

    func clear() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }

    var logLevel: LogLevel {
        get { .verbose }
        set {
            lock.lock()
            levelWrites += 1
            lock.unlock()
        }
    }

    func error(_ message: @autoclosure () -> String) { append(.error, message()) }

    func error(error: Error) {
        lock.lock()
        errorOverloadCalls += 1
        lock.unlock()
        append(.error, "\(error)")
    }

    func warn(_ message: @autoclosure () -> String) { append(.warn, message()) }
    func info(_ message: @autoclosure () -> String) { append(.info, message()) }
    func debug(_ message: @autoclosure () -> String) { append(.debug, message()) }
    func verbose(_ message: @autoclosure () -> String) { append(.verbose, message()) }

    private func append(_ level: LogLevel, _ message: String) {
        lock.lock()
        storage.append(Entry(level: level, message: message))
        lock.unlock()
    }
}

/// Holds scheduled work until the test runs it, in place of a timer.
final class ManualScheduler: @unchecked Sendable {
    struct Item {
        let delay: TimeInterval
        let work: () -> Void
        var cancelled: Bool
    }

    private let lock = NSLock()
    private var storage: [Item] = []

    var items: [Item] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var scheduler: LivenessSessionDiagnostics.Scheduler {
        { [self] delay, work in
            lock.lock()
            storage.append(Item(delay: delay, work: work, cancelled: false))
            let index = storage.count - 1
            lock.unlock()
            return { [self] in
                lock.lock()
                storage[index].cancelled = true
                lock.unlock()
            }
        }
    }

    /// Runs the work that hasn't been cancelled, as a timer would.
    func runPending() {
        items.filter { !$0.cancelled }.forEach { $0.work() }
    }

    /// Runs all of it, including cancelled work, as when a timer fires just before its cancellation.
    func runAll() {
        items.forEach { $0.work() }
    }
}

/// A clock the test moves by hand, in milliseconds.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var milliseconds: Int

    init(now: Int = 1_000) {
        milliseconds = now
    }

    var now: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            return milliseconds
        }
        set {
            lock.lock()
            milliseconds = newValue
            lock.unlock()
        }
    }

    var clock: () -> Int { { [self] in now } }
}

extension LivenessDeviceInfo {
    static let test = LivenessDeviceInfo(
        model: "iPhone16,2",
        osVersion: "18.5",
        livenessVersion: "1.5.3",
        amplifyVersion: "2.63.0"
    )
}

enum LivenessDiagnosticsFixture {
    static let sessionID = "session-1"

    static func makeDiagnostics(
        logger: MockLogger,
        clock: TestClock = TestClock(),
        scheduler: ManualScheduler = ManualScheduler(),
        region: String? = "us-east-1"
    ) -> LivenessSessionDiagnostics {
        LivenessSessionDiagnostics(
            sessionID: sessionID,
            region: region,
            deviceInfo: .test,
            logger: { logger },
            clock: clock.clock,
            scheduler: scheduler.scheduler
        )
    }

    static func ovalMatchChallenge(
        faceDetectionThreshold: Double = 0.7,
        distanceThreshold: Double = 0.32,
        iouThreshold: Double = 0.6,
        ovalFitTimeout: Int = 30_000
    ) -> FaceLivenessSession.OvalMatchChallenge {
        FaceLivenessSession.OvalMatchChallenge(
            faceDetectionThreshold: faceDetectionThreshold,
            face: .init(
                distanceThreshold: distanceThreshold,
                distanceThresholdMax: 0,
                distanceThresholdMin: distanceThreshold,
                iouWidthThreshold: 0.15,
                iouHeightThreshold: 0.15
            ),
            oval: .init(
                boundingBox: .init(x: 108, y: 107, width: 264, height: 427),
                heightWidthRatio: 1.618,
                iouThreshold: iouThreshold,
                iouWidthThreshold: 0.1,
                iouHeightThreshold: 0.1,
                ovalFitTimeout: ovalFitTimeout
            )
        )
    }

    static func movementConfiguration(
        faceDetectionThreshold: Double = 0.7,
        distanceThreshold: Double = 0.32
    ) -> FaceLivenessSession.SessionConfiguration {
        .faceMovement(ovalMatchChallenge(
            faceDetectionThreshold: faceDetectionThreshold,
            distanceThreshold: distanceThreshold
        ))
    }

    static func movementAndLightConfiguration() -> FaceLivenessSession.SessionConfiguration {
        let colors = [
            FaceLivenessSession.DisplayColor(
                rgb: .init(red: 0, green: 0, blue: 0, _values: [0, 0, 0]),
                duration: 75,
                shouldScroll: false
            ),
            FaceLivenessSession.DisplayColor(
                rgb: .init(red: 1, green: 1, blue: 1, _values: [255, 255, 255]),
                duration: 475,
                shouldScroll: true
            )
        ]
        return .faceMovementAndLight(.init(colors: colors), ovalMatchChallenge())
    }
}

/// A logged line's values by key, for lines whose values contain no ", ".
func fields(of line: String) -> [String: String] {
    guard let open = line.firstIndex(of: "("), line.hasSuffix(")") else { return [:] }
    var fields: [String: String] = [:]
    for pair in line[line.index(after: open)..<line.index(before: line.endIndex)].components(separatedBy: ", ") {
        guard let equals = pair.firstIndex(of: "=") else { continue }
        fields[String(pair[..<equals])] = String(pair[pair.index(after: equals)...])
    }
    return fields
}

/// The SessionEnded line of a session that found no face.
func sessionEndedLine(framesAnalyzed: Int = 0, closeCode: String = "DISPOSED") -> String {
    "Liveness SessionEnded(sessionId=session-1, framesAnalyzed=\(framesAnalyzed), faceEverDetected=false, "
        + "ovalEverMatched=false, ovalPositionChanges=0, challengeFrames=0, challengeFramesWithFace=0, challengeMinIou=0.0, "
        + "challengeMeanIou=0.0, analyzeErrors=0, closeCode=\(closeCode), framesDropped=0)"
}
