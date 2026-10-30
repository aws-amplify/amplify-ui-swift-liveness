# Face Liveness diagnostics

`FaceLivenessDetectorView` logs one line per session event through Amplify's Logging category, `Liveness`. The lines help you find out why a check failed, or never started, on a particular device. For example:

```
Liveness SessionEnded(sessionId=…, framesAnalyzed=150, faceEverDetected=true, ovalEverMatched=true, ovalPositionChanges=5, challengeFrames=108, challengeFramesWithFace=107, challengeMinIou=0.59, challengeMeanIou=0.64, analyzeErrors=0, closeCode=NORMAL, framesDropped=0)
```

Every line except `FrameBeforeSessionReady` starts with the session ID, so you can match it with the result you fetch for that session. Event names and most field names are the same as in Amplify UI for Android; see [Comparing with Android](#comparing-with-android). The lines only report on the check; logging never changes or fails it.

## Turning the lines on

Amplify's log level defaults to `.error`, so only `AnalyzeFailed` is logged until you raise it:

```swift
Amplify.Logging.logLevel = .info   // warn and info lines: the session lifecycle, face count and first oval match
Amplify.Logging.logLevel = .debug  // also the face's position and distance
```

That level applies to all of Amplify. To raise only these lines with the default plugin, call this once at startup instead:

```swift
_ = Amplify.Logging.logger(forCategory: "Liveness", logLevel: .debug)
```

Don't set the global level to `.verbose`: these lines don't use it, and it turns on Amplify's own verbose logging, which writes an entry for every message sent to the service.

The default plugin writes to the unified log, with your app's bundle identifier as the subsystem and `Liveness` as the category:
- Xcode's console shows the lines in full.
- Without a debugger attached, Console.app and `log stream` show the message as `<private>`. Only `AnalyzeFailed` is kept: Amplify writes warn lines as info entries, and the unified log doesn't keep info or debug entries.
- To collect lines from devices in the field, add a `LoggingCategoryPlugin`, such as `AWSCloudWatchLoggingPlugin`, which can raise `Liveness` on its own through its per-category log level.

## Privacy

Only the default plugin hides the message. A plugin you add, such as CloudWatch, receives each line as plain text. A line can contain:
- the session ID and the challenge ID
- the device model, iOS version, library versions and region
- frame counts, timings and face detection scores, and the service's thresholds
- the face's distance, and its position and overlap against the oval
- error descriptions, including text from your own credentials provider

Cognito identity IDs in error text are masked. No images, face landmarks or face boxes are logged.

## Events

Every event except `FrameBeforeSessionReady` also carries `sessionId` first. `phase` is `PRE_CHECK` until `InitialFaceDetected`, then `OVAL_FIT`, then `COLOR_SEQUENCE` from `ColorSequenceStarted`.

| Event | Level | Fields | Logged when |
|---|---|---|---|
| `SessionStarting` | info | `attempt`, `device`, `livenessVersion`, `codec`, `preCheckEnabled`, `osVersion`, `amplifyVersion`, `region` | The stream starts. `attempt` is null when the session couldn't be started. |
| `SessionReady` | info | `challengeType`, `challengeId`, `faceDetectionThreshold`, `targetIouThreshold`, `ovalFitTimeout` | The service sends the session's settings |
| `CameraBound` | info | `facing` | The camera starts |
| `FirstFrame` | info | `frame`, `targetFrame`, `resolutionMatchesTarget`, `rowStride`, `expectedRowStride`, `rowStridePadded`, `format` | The first camera frame arrives |
| `InitialFaceDetected` | info | `elapsedSinceFirstFrameMs`, `elapsedSinceCheckStartMs` | A single face passes the distance check and the oval appears |
| `ColorSequenceStarted` | info | none | The first color shows |
| `ChallengeCompleted` | info | `framesAnalyzed`, `phase` | The challenge ends |
| `SessionEnded` | info | `framesAnalyzed`, `faceEverDetected`, `ovalEverMatched`, `ovalPositionChanges`, `challengeFrames`, `challengeFramesWithFace`, `challengeMinIou`, `challengeMeanIou`, `analyzeErrors`, `closeCode`, `framesDropped` | The check ends, or the detector is removed first |
| `SessionError` | warn | `type`, `message`, `closeCode`, `reason`, `cause` | The check fails or is cancelled, or the service reports an error, before `SessionEnded`. An error your completion handler receives after `SessionEnded` has no line. |
| `FaceDetectionWatchdog` | warn | `elapsedMs`, `framesAnalyzed`, `maxDetectionScore`, `faceDetectionThreshold`, `analyzeErrors`, `readyForOval`, `faceTargetChallenge`, `initialFaceDistanceCheckPassed`, `checkState`, `framesDelivered`, `captureRunning` | No face is found within 10 s of the check taking over the camera |
| `CameraPermissionDenied` | warn | `status` | Camera access is denied, restricted or declined |
| `AnalyzeFailed` | error | `stage`, `cause` | The first frame that can't be analyzed; later ones are counted |
| `FrameBeforeSessionReady` | debug | none | The first frame scored before the session's settings arrived |
| `FaceCountChanged` | info | `from`, `to`, `framesAnalyzed`, `topScore`, `phase` | The number of faces changes and holds for 3 frames. The values are those of the third frame, so a face that appears in range can log it after `InitialFaceDetected`, with `phase=OVAL_FIT`. |
| `FirstOvalMatch` | info | `framesAnalyzed`, `phase` | The face first matches the oval |
| `OvalPositionChanged` | debug | `from`, `to`, `phase` | The face's position against the oval changes and holds for 3 frames |
| `FaceDistanceChanged` | debug | `distance`, `faceDistanceThreshold`, `exceedsThreshold`, `phase` | The face's distance moves by at least 0.05 |

### Reading the session summary

- **`closeCode`:**
  - `NORMAL`: the check completed.
  - `DISPOSED`: the detector was removed before the check ended, for example while it waited on the camera permission screen. SwiftUI also counts pushing another screen over it as removal, and the detector stops its camera then.
  - Otherwise, the close code of the session's first error:
    - `CANCELED`: the user cancelled.
    - `TIMEOUT`: the face didn't fit the oval in time.
    - `VIEW_CLOSURE`: the app became inactive or the device left portrait.
    - `MISSING_VIDEO_PERMISSION`: the camera couldn't be opened because camera access isn't granted.
    - `RUNTIME_ERROR`: anything else, including a camera that can't be opened with access granted, and errors the service reports.
- **`faceEverDetected`:** true once any frame had a face, even one too brief to log `FaceCountChanged`. That frame also stops the watchdog.
- **`challengeFrames` and `challengeFramesWithFace`:** the frames analyzed from the first oval match, and how many of them had exactly one face.
- **`challengeMinIou` and `challengeMeanIou`:** how well the face overlapped the oval over those frames, compared with `targetIouThreshold` from `SessionReady`. Read them together with `challengeFramesWithFace`. A face that leaves the frame adds no samples, so it raises the mean rather than lowering it.
- **`SessionError`:**
  - `type` and `message` are the error your completion handler receives.
  - `reason` tells apart failures that reach you as the same error. For example, a credentials failure reaches you as `socketClosed`, with `reason=couldNotOpenStream`.
  - `cause` is the underlying error chain, outermost first.

### Reading the watchdog

`FaceDetectionWatchdog` is logged once, when no face has been found within 10 s. A single analyzed frame with a face stops it.

| Values | Likely cause |
|---|---|
| `framesDelivered=0` | No camera frame reached the check; with `captureRunning=false`, the camera isn't running either |
| `faceTargetChallenge=unknown` | No frame was scored, because the camera sent nothing or every frame failed analysis |
| `readyForOval=false` or `faceTargetChallenge=absent` | The session's settings hadn't arrived, so frames were scored against a fallback threshold, and `framesAnalyzed` stays 0 |
| `analyzeErrors` above 0 | The face detection model failed to run |
| Otherwise | `maxDetectionScore` against `faceDetectionThreshold` shows how close the model came to seeing a face |

## Comparing with Android

Event names and most field names are the same as Android's. These differ:

- `SessionStarting.osVersion` is the iOS version string, such as `17.4`. Android logs its integer API level as `api`.
- `FaceDistanceChanged` logs `faceDistanceThreshold` and `exceedsThreshold`. Android logs `faceDistanceThresholdMin` and `exceedsThresholdMin`, against a different measure.
- Each `cause` entry is capped at 200 characters, and Cognito identity IDs in it are masked. Android does neither.
- `SessionError.type` is the iOS error name. Android logs the exception class instead:

  | iOS `type` | Android `type` |
  |---|---|
  | `sessionNotFound` | `SessionNotFoundException` |
  | `accessDenied` | `AccessDeniedException` |
  | `userCancelled` | `UserCancelledException` |
  | `faceInOvalMatchExceededTimeLimitError` | `FaceInOvalMatchExceededTimeLimitException` |
  | `sessionInterrupted` | `SessionInterruptedException` |
  | anything else | `FaceLivenessDetectionException` |

  The two interrupted errors have different triggers. iOS logs `sessionInterrupted` when the app becomes inactive or the device leaves portrait during the check; Android logs `SessionInterruptedException` when the connection drops mid-check. Android logs nothing when camera access is missing, so `CameraPermissionDeniedException` never appears. iOS logs `CameraPermissionDenied` instead, and its `type=cameraPermissionDenied` also covers other client failures, which `reason` tells apart. Only Android logs `SessionTimedOutException`, `UnsupportedChallengeTypeException`, `VideoEncodingException` and `VideoMuxingException`.

- `checkState` names the iOS state. Android logs its check state class:

  | iOS `checkState` | Android `checkState` |
  |---|---|
  | `initial`, `pendingFacePreparedConfirmation.<reason>`, `waitForRecording`, `recording` | `Initial` |
  | `recording.ovalDisplayed`, `awaitingFaceInOvalMatch.<reason>`, `faceMatched`, `displayingFreshness` | `Running` |
  | `completedDisplayingFreshness`, `completedNoLightCheck`, `completed` | `Success` |
  | `encounteredUnrecoverableError.<reason>` | `Error` |

  The watchdog only fires before a face is found, so `checkState` is normally `initial` or `pendingFacePreparedConfirmation.<reason>`.

- `distance`, the overlap values and `topScore` are measured differently on each platform, so don't compare them across platforms.
