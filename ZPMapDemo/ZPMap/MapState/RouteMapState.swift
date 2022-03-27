//
//  RouteMapState.swift
//
//  Created by EddieHua.
//

import Foundation
import GoogleMaps

/// Route 路線規劃狀態
class RouteMapState: MapState {
    // 是否有設定 目的地
    var isSetTarget: Bool = false
    // 是否有設定 起始點
    var isSetStart: Bool = false
    // 是否有成功規劃出路徑
    var hasRouteResult = false
    
    // 初始 / 重回 狀態；重回時 會由外界呼叫 reset
    override func reset() {
        mapVC.mMode = .PanMode
        mapVC.mBtnSearchPlaces.isHidden = true
        mapVC.mRouteResultView?.closeNaviButton.isHidden = true
        mapVC.mRouteResultView?.goNaviButton.isHidden = false
        mapVC.mRouteResultView?.destinationImageView.isHidden = false
        // 必要條件：至少會設定一個 起點or終點
        mapVC.showRouteViews()
        mapVC.hidePOIinfo()
        mapVC.mMapView?.isMyLocationEnabled = true
        
        if let routePlan = mapVC.mRoutePlan {
            if (routePlan.bounds != nil) {
                let nPadding:CGFloat = 30
                let cameraUpdate = GMSCameraUpdate.fit(routePlan.bounds!, with: UIEdgeInsets(top: nPadding, left: nPadding, bottom: nPadding * 2.7, right: nPadding))
                mapVC.mMapView?.animate(with: cameraUpdate)
            }
        }
        
        //
        mapVC.updateResultViewDestination()
    }
    
    override func mapViewController(_ mapViewCtrl:MapViewController, didLongPressAt coordinate: CLLocationCoordinate2D) {
        // Nothing
    }
    
    override func mapViewController(_ mapViewCtrl:MapViewController, didTapAt coordinate: CLLocationCoordinate2D) {
        // TODO: 切換 Full Screen Mode
    }
    
    override func mapViewController(_ mapViewCtrl:MapViewController, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
//       / mapViewCtrl.updateDestinationFromTargetMarker()
    }
}
