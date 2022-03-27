//
//  RouteBase.swift
//
//  Created by EddieHua.
//

import Foundation
import SwiftyJSON
import GoogleMaps

public class RouteBase : NSObject {
//    static let styles = [GMSStrokeStyle.solidColor(.cyan),
//                         GMSStrokeStyle.solidColor(Theme.accentColor)]
    //
    override init() {
    }
    
    class func parseEncodedPointsToPolyline(_ encodedPoints:String) -> GMSPolyline? {
        let path = GMSPath.init(fromEncodedPath: encodedPoints)
        let polyline = GMSPolyline.init(path: path)
        return polyline
    }
    // Parse 失敗會得到 nil
    class func parseLocationCoordinate2D(_ locationDict : [String : JSON]?) -> CLLocationCoordinate2D? {
        if locationDict != nil {
            let lat = locationDict!["lat"]
            let lng = locationDict!["lng"]
            if lat != nil && lng != nil {
                return CLLocationCoordinate2D(latitude: (lat!.double)!, longitude: (lng!.double)!)
            }
        }
        return nil
    }
}
