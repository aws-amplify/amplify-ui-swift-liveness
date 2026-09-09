//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

/// Tracks the interface orientation of the scene hosting the detector view.
final class InterfaceOrientationObserver: ObservableObject {
    @Published private(set) var orientation: UIInterfaceOrientation

    private var sceneActivationObserver: NSObjectProtocol?
    private var deviceOrientationObserver: NSObjectProtocol?

    init(orientation: UIInterfaceOrientation? = nil) {
        self.orientation = orientation ?? LivenessOrientation.currentInterfaceOrientation

        // Covers a rotation that happens while the app is in the background, which produces
        // no transition callback on the detector's own view controllers.
        sceneActivationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }

        // Redundant trigger alongside `InterfaceOrientationReader`, so the gate does not
        // depend on a single signal. This one reports the device rather than the interface and
        // carries no ordering guarantee against the interface rotation, hence the second read
        // on the next main queue turn. A host locked to portrait still reads portrait here, so
        // it is never gated. `begin`/`endGeneratingDeviceOrientationNotifications` are
        // reference counted by UIKit, so this does not disturb the host app's own use of them.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        deviceOrientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    deinit {
        if let sceneActivationObserver {
            NotificationCenter.default.removeObserver(sceneActivationObserver)
        }
        if let deviceOrientationObserver {
            NotificationCenter.default.removeObserver(deviceOrientationObserver)
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    var decision: LivenessOrientation.Decision {
        LivenessOrientation.decision(for: orientation)
    }

    /// Re-reads the interface orientation from the host scene. Publishes only on a change so
    /// a repeated read does not re-render the detector.
    func refresh() {
        let current = LivenessOrientation.currentInterfaceOrientation
        guard current != orientation else { return }
        orientation = current
    }
}

/// Zero-sized bridge that tells an `InterfaceOrientationObserver` when to re-read the
/// interface orientation.
///
/// UIKit calls `viewWillTransition(to:with:)` on the view controllers in the hierarchy for
/// every interface rotation, which is the signal available on iOS 15 that is actually tied
/// to the interface. `UIDevice.orientationDidChangeNotification` is not equivalent: it
/// reports the *device*, fires for hosts that are locked to portrait, and requires the app
/// to be generating device orientation notifications.
///
/// The observer is refreshed at the start of the transition, where the scene's
/// `interfaceOrientation` already reports the new value, so the rotate prompt covers the
/// camera feed before the rotation animation plays rather than after it. The refresh on
/// completion is a backstop in case that read is ever early.
struct InterfaceOrientationReader: UIViewControllerRepresentable {
    let onChange: () -> Void

    func makeUIViewController(context: Context) -> ReaderViewController {
        ReaderViewController(onChange: onChange)
    }

    func updateUIViewController(_ uiViewController: ReaderViewController, context: Context) {
        uiViewController.onChange = onChange
    }

    final class ReaderViewController: UIViewController {
        var onChange: () -> Void

        init(onChange: @escaping () -> Void) {
            self.onChange = onChange
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
            onChange()
        }

        override func viewWillTransition(
            to size: CGSize,
            with coordinator: UIViewControllerTransitionCoordinator
        ) {
            super.viewWillTransition(to: size, with: coordinator)
            onChange()
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.onChange()
            }
        }
    }
}
