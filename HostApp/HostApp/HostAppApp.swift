//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import FaceLiveness
import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin

@main
struct HostAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    func increaseBrightness() {
        UIScreen.main.brightness = 1.0
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

    init() {
        do {
            Amplify.Logging.logLevel = .verbose
            let auth = AWSCognitoAuthPlugin()
            let api = AWSAPIPlugin()
            try Amplify.add(plugin: auth)
            try Amplify.add(plugin: api)
            try Amplify.configure()
        } catch {
            print("Error configuring Amplify", error)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = SceneDelegate.self
        }
        return configuration
    }
}

class SceneDelegate: NSObject, ObservableObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if #available(iOS 15.0, *) {
            self.window = (scene as? UIWindowScene)?.keyWindow
        } else {
            self.window = (scene as? UIWindowScene)?.windows
                .first(where: \.isKeyWindow)
        }
    }
}

