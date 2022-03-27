//
//  MapState.swift
//
//  Created by EddieHua.
//

import Foundation
import GoogleMaps

/// 一般狀態
class MapState : NSObject {
    weak var mapVC:MapViewController! = nil
    init(_ mapViewCtrl:MapViewController) {
        super.init()
        mapVC = mapViewCtrl
        reset()
    }
    // 初始 / 重回 狀態
    func reset() {
        // 如果有導航路徑 - 清除
        mapVC.clearRouteResult()
        mapVC.hideRouteViews(skipResultView: false)
        mapVC.mMapView?.isMyLocationEnabled = true
        mapVC.mBtnSearchPlaces.isHidden = false
    }
    // clear
    func clear() {
        
    }
    
    // ============= Map ================
    func mapViewController(_ mapViewCtrl:MapViewController, didLongPressAt coordinate: CLLocationCoordinate2D) {
        // TODO: 是否要用 Google API 找出附近景點?
        let name = LocalizedString("map.destination")
        mapViewCtrl.setDestinationMarker(placeId:"", title:name, coordinate: coordinate)
        mapViewCtrl.showPOIinfo(title: name)
    }
    func mapViewController(_ mapViewCtrl:MapViewController, didTap marker: GMSMarker) -> Bool {
        if mapViewCtrl.mSelectedMarker != nil {
            // 復原
            mapViewCtrl.unselectMarker()
        } else {
            // 原本沒有選擇任何 marker
            mapViewCtrl.mMode = .PanMode
        }
        mapViewCtrl.selectMarker(marker)
        mapViewCtrl.showPOIinfo(title: marker.title!)
        return false    // 回傳 true 的話，map 本身就不會再顯示 popup message
    }
    func mapViewController(_ mapViewCtrl:MapViewController, didTapAt coordinate: CLLocationCoordinate2D) {
        mapViewCtrl.unselectMarker()
        mapViewCtrl.clearDestinationMarker()
        mapViewCtrl.hidePOIinfo()
    }
    
    func mapViewController(_ mapViewCtrl:MapViewController, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
        // 移除換行符號
        let title = name.replacingOccurrences(of: "\r\n|\n|\r", with: "", options: .regularExpression)
        mapViewCtrl.setDestinationMarker(placeId:placeID, title: title, coordinate: location)
        mapViewCtrl.showPOIinfo(title: title)
    }
}
