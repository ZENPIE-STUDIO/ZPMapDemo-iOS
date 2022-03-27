//
//  RoutePlan.swift
//
//  Created by EddieHua.
//

import Foundation
import GoogleMaps
import SwiftyJSON

// (從 Google 網站抄的說明)
// 包含指定起點與目的地的一個結果。此路線可以包含一或多段行程 (RouteLeg / DirectionsLeg 類型)，取決於是否指定任何途經地點。
// 除了路線資訊之外，此路線也包含必須對使用者顯示的著作權與警告資訊。
public class RoutePlan : RouteBase {
    // Bound
    public var bounds : GMSCoordinateBounds? = nil
    public var summary: String?
    
    public var warnings: [String] = [String]()
    public var legs:[RouteLeg] = [RouteLeg]();
    //public var waypointsOrder: [Int] = [Int]()        // 經由點
    public var copyrights: String?
    fileprivate var polyline: GMSPolyline? = nil        // 路線（越長的路徑會越簡化）
    
    // TODO: 想要畫出路線的高度曲線圖的話 - 利用 Google Maps Elevation API；多點傳入會比較省錢嗎?
    public var encodedPath: String?
    // https://developers.google.com/maps/documentation/elevation/intro?hl=zh-tw
    // 從 RouteStep 整理得來，去除每個 Step 交會的重覆點
    public var coordinates = [CLLocationCoordinate2D]()
    
    deinit {
        dPrint("deinit")
    }
    
    func clear() {
        if polyline != nil {
            polyline!.map = nil
            polyline = nil
        }
        warnings.removeAll()
        bounds = nil
        summary = nil
        legs.removeAll()
    }
    
    class func create(json: JSON) -> RoutePlan {
        let routePlan:RoutePlan = RoutePlan()
        // print route using Polyline
        let boundsDict = json["bounds"].dictionary
        let northeastDict = boundsDict?["northeast"]?.dictionary
        let neCoord = parseLocationCoordinate2D(northeastDict)
        let southwestDict = boundsDict?["southwest"]?.dictionary
        let swCoord = parseLocationCoordinate2D(southwestDict)
        if neCoord != nil && swCoord != nil {
            routePlan.bounds = GMSCoordinateBounds.init(coordinate: neCoord!, coordinate: swCoord!)
        }
        
        routePlan.summary = json["summary"].string
        routePlan.copyrights = json["copyrights"].string
        // Warnings
        let warningsArray = json["warnings"].array
        if (warningsArray != nil) {
            for w in warningsArray! {
                if (w.string != nil) {
                    routePlan.warnings.append(w.string!)
                }
            }
        }
        // Overview Polyline
        let routeOverviewPolyline = json["overview_polyline"].dictionaryValue
        let encodedPoints = routeOverviewPolyline["points"]?.string
        if encodedPoints != nil {
            routePlan.encodedPath = encodedPoints
            routePlan.polyline = parseEncodedPointsToPolyline(encodedPoints!)
        }
        // ==== Legs ====
        let legsArray = json["legs"].array
        if legsArray != nil {
            for legJson in legsArray! {
                let leg = RouteLeg.create(json: legJson)
                routePlan.legs.append(leg)
                // 整理 coordinates，要移掉交界點
                for step in leg.steps {
                    if routePlan.coordinates.count > 0 {
                        routePlan.coordinates.removeLast()
                    }
                    routePlan.coordinates.append(contentsOf: step.coordinates)
                }
            }
        } else {
            dPrint("沒有 Legs!")
        }
        return routePlan
    }
    // 重置一些導航過程中，所更新的變數 (只有模擬駕駛時 才會用到)
    func resetNavigationInfo() {
        for leg in legs {
            for step in leg.steps {
                step.alertUserLevel = .none
            }
            leg.alertUserLevel = .none
        }
    }
    
    func isPolylineInMapShown() -> Bool {
        return polyline?.map != nil
    }
    // 顯示規劃的路徑
    func showPolylineInMap(_ mapView:GMSMapView) {
        if polyline != nil {
            polyline!.strokeWidth = 6
            polyline!.strokeColor = ZPMapCommon.appearance.mainColor
            polyline!.map = mapView
        }
    }
    // 隱藏規劃的路徑
    func hidePolyline() {
        polyline?.map = nil
    }
    // ------------- 精細版 --------------
    public private(set) var isFinePolylineInMapShown = false
    // 顯示規劃的路徑-精細版
    func showFinePolylineInMap(mapView:GMSMapView) {
        guard !isFinePolylineInMapShown else {
            return
        }
        dPrint("showFinePolylineInMap")
        isFinePolylineInMapShown = true
        for leg in legs {
            for step in leg.steps {
                step.showPolylineInMap(mapView)
            }
        }
    }
    // 隱藏規劃的路徑-精細版
    func hideFinePolyline() {
        guard isFinePolylineInMapShown else {
            return
        }
        dPrint("hideFinePolyline")
        for leg in legs {
            for step in leg.steps {
                step.hidePolyline()
            }
        }
        isFinePolylineInMapShown = false
    }
    // overview_polyline > points ，處理成 GMSPath > GMSPolyline
}

