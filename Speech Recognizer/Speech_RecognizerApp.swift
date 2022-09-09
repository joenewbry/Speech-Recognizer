//
//  Speech_RecognizerApp.swift
//  Speech Recognizer
//
//  Created by Joe Newbry on 9/9/22.
//

import SwiftUI
import Mixpanel

@main
struct Speech_RecognizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Mixpanel.initialize(token: "b7ee8bd77217bdc0a67b7931ecdfc9f9")
                }
        }
    }
}
