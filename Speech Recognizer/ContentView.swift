//
//  ContentView.swift
//  Speech Recognizer
//
//  Created by Joe Newbry on 9/9/22.
//

import SwiftUI
import Speech
import StoreKit
import Mixpanel

import AVFAudio

// For second version of the app -- add in leave review button
// From here: https://developer.apple.com/documentation/storekit/requesting_app_store_reviews
/*
 
 @IBAction func requestReviewManually() {
     // Note: Replace the placeholder value below with the App Store ID for your app.
     //       You can find the App Store ID in your app's product URL.
     guard let writeReviewURL = URL(string: "https://apps.apple.com/app/id<#Your App Store ID#>?action=write-review")
         else { fatalError("Expected a valid URL") }
     UIApplication.shared.open(writeReviewURL, options: [:], completionHandler: nil)
 }
 
 
 */


// Speech recognition sample code
/*
 https://developer.apple.com/tutorials/app-dev-training/transcribing-speech-to-text#Integrate-speech-recognition
 */


// Steps for adding in purchasable subscription outside the app //
/*
1. Offer codes into a readable csv -- check against each code
 2. Class that keeps track of currentCode in userdefaults
 3. Change price to free (and then put through app sumo)
 4. Add in StoreKit for subscriptions + make sure it works w/ and w/o subscriptions.

 */

enum UserDefaultsKeys: String {
    case processCompletedCountKey = "com.digitalsurfacelabs.speech_recognizer.processCompletedCountKey"
    case lastVersionPromptedForReviewKey = "com.digitalsurfacelabs.speech_recognizer.lastVersionPromptedForReviewKey"
}

struct ContentView: View {
    @State private var titleText = "Add File To Transcribe"
    @State private var transcribedText: String?

    var body: some View {
        
        VStack {
            Text("\(titleText)")
            Button("Add file") {
                guard let url = showSavePanel() else {
                    print("No url returned")
                    return
                }
                
                trackAddFile()
                
                recognizeFile(url: url)
            }
            if transcribedText != nil {
//                Button("Copy Text") {
//                    print("Text is copied to clipboard.")
//                    
//                    NSPasteboard.general.setString(transcribedText!, forType: .string)
//                }
                ScrollView {
                    Text(transcribedText!)
                    // https://developer.apple.com/documentation/swiftui/view/textselection(_:)
                        .textSelection(.enabled)
                        .lineLimit(nil)
                }
            }

        }
        .padding()
        .frame(width: 400, height: 300)
        .overlay(alignment: .bottom) {
            Text("Questions or feedback email: joe@digitalsurfacelabs.com")
        }
        .onAppear {
            
            // If the app doesn't store the count, this returns 0.
            var count = UserDefaults.standard.integer(forKey: UserDefaultsKeys.processCompletedCountKey.rawValue)
            count += 1
            UserDefaults.standard.set(count, forKey: UserDefaultsKeys.processCompletedCountKey.rawValue)
            print("Process completed \(count) time(s).")

            // Keep track of the most recent app version that prompts the user for a review.
            let lastVersionPromptedForReview = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey.rawValue)

            // Get the current bundle version for the app.
            let infoDictionaryKey = kCFBundleVersionKey as String
            guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
                else { fatalError("Expected to find a bundle version in the info dictionary.") }
             // Verify the user completes the process several times and doesn’t receive a prompt for this app version.
             if count >= 4 && currentVersion != lastVersionPromptedForReview {
                 Task {
                     // Delay for two seconds to avoid interrupting the person using the app.
                     // Use the equation n * 10^9 to convert seconds to nanoseconds.
                     try? await Task.sleep(nanoseconds: UInt64(2e9))
                     StoreKit.SKStoreReviewController.requestReview()
//                         if let windowScene = self?.view.window?.windowScene,
//                            self?.navigationController?.topViewController is ProcessCompletedViewController {
//                             SKStoreReviewController.requestReview(in: windowScene)
                     UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.lastVersionPromptedForReviewKey.rawValue)
                }
            }
        }
            
    }
//            .onAppear {
////                let urlString = "update.mov"
////                guard let url = URL(string: urlString) else {
////                    print("URL misformatted")
//////                    print("Error: \(error)")
////                    return
////                }
//                
//
//            }
//    }
                
    // from here :https://serialcoder.dev/text-tutorials/macos-tutorials/save-and-open-panels-in-swiftui-based-macos-apps/
    func showSavePanel() -> URL? {
//        let savePanel = NSSavePanel()
//        savePanel.allowedFileTypes = nil
//        savePanel.canCreateDirectories = true
//        savePanel.isExtensionHidden = false
//        savePanel.allowsOtherFileTypes = false
//        savePanel.title = "Select location for Video Journal to Save Screenshots"
//        savePanel.message = "Pick the location."
//        savePanel.nameFieldLabel = "File name:"
//
//        let response = savePanel.runModal()
//        return response == .OK ? savePanel.url : nil
        
        let openPanel = NSOpenPanel()
//        openPanel.allowedFileTypes = [.mov, .mp3, .mp4]
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.audio, .audiovisualContent]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
//        openPanel.title = "Pick where Screen Timelapse save your files"
        openPanel.message = "Pick file with audio to translate."
        let response = openPanel.runModal()
        return response == .OK ? openPanel.url : nil
    }

    // https://developer.apple.com/documentation/speech/sfspeechurlrecognitionrequest
    func recognizeFile(url:URL) {

        
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .notDetermined:
                self.titleText = "Not determined yet."
                print("Not determined yet")
            case .denied:
                self.titleText = "Go to settings > security & privacy > speech recognition"
                print("Denied")
            case .restricted:
                self.titleText = "Device preventing translation. Contact developer."
                print("Device prevents you from being able to translate.")
            case .authorized:
                print("Processing request...")
                self.titleText = "Transcribing audio."
                self.processRequest(url: url)
            @unknown default:
                print("Unhandled default case")
                #if DEBUG
                fatalError()
                #endif
            }
        }
        

    }
    
    func processRequest(url: URL) {
        guard let myRecognizer = SFSpeechRecognizer() else {
           // A recognizer is not supported for the current locale
            print("Recognizer not supported for current locale")
            self.titleText = "Recognizer not supported for current locale"
           return
        }
        
        if !myRecognizer.isAvailable {
           // The recognizer is not available right now
            print("Recognizer is not available right now")
            self.titleText = "Recognizer is not available right now"
           return
        }
                
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        let engine = AVAudioEngine()
        let count = engine.inputNode.inputFormat(forBus: 0).channelCount
        // from Stack overflow: https://stackoverflow.com/questions/63592450/sfspeechrecognizer-crashes-if-no-microphone-input-attached-in-mac-osx
        if count < 1 {
            print("Worried about crash")
            self.titleText = "Audio Session has no available inputs."
            return
        }
        
        myRecognizer.recognitionTask(with: request) { (result, error) in
            if error != nil {
                print("Oops: \(error)")

                return
            }
            
            self.titleText = "Transcribing text, estimated time 23 seconds per minute of audio."
           guard let result = result else {
              // Recognition failed, so check error for details and handle it
               self.titleText = "check error: \(error?.localizedDescription ?? "No description")"
               print("Oops: \(error)")
              return
           }

           // Print the speech that has been recognized so far
           if result.isFinal {
              print("Speech in the file is \(result.bestTranscription.formattedString)")
               transcribedText = result.bestTranscription.formattedString
               self.titleText = "Finished Transcription. Copy text below OR add another file."
               
               trackTranslateFile()
           }
        }
    }
    
    func trackAddFile() {
        Mixpanel.mainInstance().track(event: "Add File", properties: [:
//            "source": "Pat's affiliate site",
//            "Opted out of email": true
        ])
    }
    
    func trackTranslateFile() {
        Mixpanel.mainInstance().track(event: "Translate File", properties: [:
//            "source": "Pat's affiliate site",
//            "Opted out of email": true
        ])
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
    

}
