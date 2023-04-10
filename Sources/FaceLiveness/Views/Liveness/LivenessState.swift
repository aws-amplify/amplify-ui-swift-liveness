////
////  LivenessState.swift
////  HostApp
////
////  Created by Saultz, Ian on 4/9/23.
////
//
//import Foundation
//
//enum FaceLiveness {}
//
//extension FaceLiveness {
//    class StateMachine {
//        var state: State
//
//        init(initialState: State) {
//            self.state = initialState
//        }
//
//        func send(
//            _ action: Action,
//            completion: @escaping () -> Void
//        ) {
//            switch action {
//            case .multipleFacesDetected:
//                switch state.livenessStage {
//                case .pendingInitialFacePrepared:
//                    break // show prompt
//                case .countingDown:
//                    break
//                default: break
//                }
//            case .noFaceDetected:
//
//                break
//            case .singleFaceDetected:
//                break
//            case .displayOval:
//                break
//            case .openSocket:
//                break
//            case .startCountdown:
//                break
//            case .displayFreshness:
//                break
//            case .completedDisplayingFreshness:
//                break
//            case .faceMatchingInOval:
//                break
//            case .receivedEvent(let serviceEvent):
//                _ = serviceEvent
//                break
//            case .sentEvent(let clientEvent):
//                _ = clientEvent
//                break
//            case .disconnectEventReceived:
//                break
//            case .unrecoverableErrorEncountered(let unrecoverableError):
//                _ = unrecoverableError
//                break
//            }
//        }
//    }
//}
//
//
//
//extension FaceLiveness {
//    struct State {
//        var livenessStage: LivenessStage
//
//        enum LivenessStage: Equatable {
//            case initial
//            case pendingInitialFacePrepared(
//                InitialFaceNotPreparedReason
//            )
//            case countingDown
//            case failed
//            case complete
//        }
//
//        enum InitialFaceNotPreparedReason: String {
//            case pendingCheck
//            case noFace
//            case multipleFaces
//            case faceTooClose
//        }
//    }
//}
//
//
//
//extension FaceLiveness {
//    enum Action {
//        case multipleFacesDetected
//        case noFaceDetected
//        case singleFaceDetected
//        case displayOval
//        case openSocket
//        case startCountdown
//        case displayFreshness
//        case completedDisplayingFreshness
//        case faceMatchingInOval
//        case receivedEvent(ServiceEvent)
//        case sentEvent(ClientEvent)
//        case disconnectEventReceived
//        case unrecoverableErrorEncountered(FaceLivenessDetectionError)
//
//        struct ClientEvent {}
//        struct ServiceEvent {}
//    }
//}
