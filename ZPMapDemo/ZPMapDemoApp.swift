//
//  ZPMapDemoApp.swift
//  ZPMapDemo
//
//  Created by EddieHua.
//

import SwiftUI
import GoogleMaps
import GooglePlaces
import AVFoundation


@main
struct ZPMapDemoApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 給個初始座標
        var initLocation = MyDefaults.shared.lastCoordinate
        if initLocation == nil {
            initLocation = CLLocationCoordinate2D(latitude: 24.1385403, longitude: 120.6575869)
            MyDefaults.shared.lastCoordinate = initLocation
            print("Init location = \(initLocation!)")
        } else {
            print("My Defaults location = \(initLocation!)")
        }
        // TRY: 為了在使用App時調整音量，能固定調整"音效"、而不會調到"鬧鈴"
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)

        GMSServices.provideAPIKey(GOOGLEMAP_API_KEY)
        GMSPlacesClient.provideAPIKey(GOOGLEMAP_API_KEY)
        return true
    }
}
