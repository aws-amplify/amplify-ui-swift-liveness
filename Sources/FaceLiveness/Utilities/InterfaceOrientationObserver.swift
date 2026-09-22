//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// Tracks the interface orientation of the scene hosting the detector view. Fed by
/// `InterfaceOrientationReader`; `UIScene.didActivateNotification` covers a rotation that
/// happened while the app was in the background.
final class InterfaceOrientationObserver: ObservableObject {
    @Published private(set) var orientation: UIInterfaceOrientation

    /// The detector's own scene, supplied by the reader once it is in a window. Until then the
    /// app's foreground scene stands in, which can be a sibling under Stage Manager.
    private(set) weak var hostScene: InterfaceOrientationProviding?
    private var sceneActivationObserver: NSObjectProtocol?

    init(orientation: UIInterfaceOrientation? = nil) {
        self.orientation = orientation ?? LivenessOrientation.currentInterfaceOrientation

        sceneActivationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let sceneActivationObserver {
            NotificationCenter.default.removeObserver(sceneActivationObserver)
        }
    }

    var decision: LivenessOrientation.Decision {
        LivenessOrientation.decision(for: orientation)
    }

    /// Publishes where a rotation is heading before the scene reports it, so the prompt covers
    /// the feed from the first frame. Only a blocking orientation is published early; a turn back
    /// to portrait waits for `settle(in:)`, so a misread transform can only hold the prompt.
    func beginTransition(with targetTransform: CGAffineTransform) {
        let next = LivenessOrientation.orientation(orientation, rotatedBy: targetTransform)
        guard next != orientation,
              LivenessOrientation.decision(for: next) == .blockUntilPortrait
        else { return }
        orientation = next
    }

    /// Records the scene the reader settled in and re-reads the orientation from it.
    func settle(in scene: InterfaceOrientationProviding?) {
        if let scene {
            hostScene = scene
        }
        refresh()
    }

    /// Re-reads the interface orientation, from the host scene when known, publishing only on
    /// a change.
    func refresh() {
        let current = hostScene?.interfaceOrientation ?? LivenessOrientation.currentInterfaceOrientation
        guard current != orientation else { return }
        orientation = current
    }
}

/// Zero-sized view reporting interface rotations through `viewWillTransition(to:with:)`.
/// `onTransition` fires at the start with the coordinator's `targetTransform`; `onSettled`
/// fires with the hosting scene when the rotation completes and on first appearance.
struct InterfaceOrientationReader: UIViewControllerRepresentable {
    let onTransition: (CGAffineTransform) -> Void
    let onSettled: (UIWindowScene?) -> Void

    func makeUIViewController(context: Context) -> ReaderViewController {
        ReaderViewController(onTransition: onTransition, onSettled: onSettled)
    }

    func updateUIViewController(_ uiViewController: ReaderViewController, context: Context) {
        uiViewController.onTransition = onTransition
        uiViewController.onSettled = onSettled
    }

    final class ReaderViewController: UIViewController {
        var onTransition: (CGAffineTransform) -> Void
        var onSettled: (UIWindowScene?) -> Void

        init(
            onTransition: @escaping (CGAffineTransform) -> Void,
            onSettled: @escaping (UIWindowScene?) -> Void
        ) {
            self.onTransition = onTransition
            self.onSettled = onSettled
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onSettled(view.window?.windowScene)
        }

        override func viewWillTransition(
            to size: CGSize,
            with coordinator: UIViewControllerTransitionCoordinator
        ) {
            super.viewWillTransition(to: size, with: coordinator)
            onTransition(coordinator.targetTransform)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                guard let self else { return }
                self.onSettled(self.view.window?.windowScene)
            }
        }
    }
}
