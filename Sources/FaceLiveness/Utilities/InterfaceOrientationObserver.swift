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

        // A rotation while the app is backgrounded produces no transition callback.
        sceneActivationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }

        // Secondary signal alongside `InterfaceOrientationReader`. Device orientation is not
        // ordered against the interface rotation, hence the second read on the next turn.
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

    /// Re-reads the host scene's interface orientation, publishing only on a change.
    func refresh() {
        let current = LivenessOrientation.currentInterfaceOrientation
        guard current != orientation else { return }
        orientation = current
    }
}

/// Zero-sized view that calls `onChange` on every interface rotation, via
/// `viewWillTransition(to:with:)`, which is tied to the interface rather than the device.
/// Fires at the start of the transition so the prompt covers the feed before the animation.
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
