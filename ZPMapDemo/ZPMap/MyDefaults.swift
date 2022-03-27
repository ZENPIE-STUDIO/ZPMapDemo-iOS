//
//  MyDefaults.swift
//
//  Created by EddieHua.
//

import Foundation
import CoreLocation

private let kLastLatitude = "lastLatitude"
private let kLastLongitude = "lastLongitude"

open class MyDefaults {
    static let shared = MyDefaults()
    
    // 最後的座標
    var lastCoordinate : CLLocationCoordinate2D? {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: kLastLatitude) != nil
                && defaults.object(forKey: kLastLongitude) != nil {
                return CLLocationCoordinate2D(latitude: defaults.double(forKey: kLastLatitude),
                                              longitude: defaults.double(forKey: kLastLongitude))
            }
            return nil
        }
        set {
            let defaults = UserDefaults.standard
            if newValue != nil {
                defaults.set(newValue!.latitude, forKey: kLastLatitude)
                defaults.set(newValue!.longitude, forKey: kLastLongitude)
            } else {
                defaults.removeObject(forKey: kLastLatitude)
                defaults.removeObject(forKey: kLastLongitude)
            }
            defaults.synchronize()
        }
    }
}
