//
//  MapViewController+Search.swift
//
//  Created by EddieHua.
//

import UIKit
import GoogleMaps


extension MapViewController : SearchPlacesViewDelegate {
    // 當有搜尋結果出現在 map 上面時，mBtnSearchPlaces 要做些改變
    func changeSearchBarStatus(title: String, hideClearButton:Bool) {
        mBtnClearSearch.isHidden = hideClearButton
        mBtnSearchPlaces.setTitle(title, for: .normal)
    }
    // 清除搜尋結果：起迄點所有的marker 都會一併清除
    @objc func clearSearchResult() {
        changeSearchBarStatus(title: "", hideClearButton: true)
        hidePOIinfo()
        unselectMarker()
        // 從地圖上清除
        for marker in mFoundPlaceMarkers {
            marker.map = nil
        }
    }
    // ---------- autocomplete : 單一結果 設為目的地 -------------
    func searchPlaces(viewController: SearchPlacesViewController, selectedPlace:AutoCompletePlace) {
        dPrint("selectedPlace > \(selectedPlace.mainText ?? "")")
        // 取得這個 place_id 的座標
        GoogleMapService.getPlaceDetail(selectedPlace.place_id) { [weak self] (place, errMsg) in
            if place != nil {
                self?.moveToAndShowPlace(place!)
            } else {
                dPrint("getPlaceDetail Parse 出錯")
            }
        }
        // 手機 : 關掉；平板如果沒有全螢幕顯示就不需要
        viewController.close()
    }
    // ------------- 快速搜尋結果，會有多個 - 標註在地圖上 ---------------
    func searchPlaces(viewController: SearchPlacesViewController, title: String, foundPlaces:[Place]) {
        clearSearchResult()
        // ----------
        // 因為我是用 目前地圖中心點為基準 搜尋
        var northEast = mCurrentCameraPosition.target   // 東北 最大值為 90, 180
        var southWest = mCurrentCameraPosition.target   // 西南 最小值 -90, -180
        for place in foundPlaces {
            let marker = newMarker(coordinate: place.coordinate, text: place.name)
            marker.userData = place.id
            mFoundPlaceMarkers.append(marker)
            // North East
            if northEast.latitude < place.coordinate.latitude {
                northEast.latitude = place.coordinate.latitude
            }
            if northEast.longitude < place.coordinate.longitude {
                northEast.longitude = place.coordinate.longitude
            }
            // South West
            if southWest.latitude > place.coordinate.latitude {
                southWest.latitude = place.coordinate.latitude
            }
            if southWest.longitude > place.coordinate.longitude {
                southWest.longitude = place.coordinate.longitude
            }
        }
        // 設定
        changeSearchBarStatus(title: String(format:LocalizedString("map.s-search-results.message"), title), hideClearButton: false)
        
        let nPadding:CGFloat = 0
        let bounds = GMSCoordinateBounds(coordinate: northEast, coordinate: southWest)
        let cameraUpdate = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: nPadding, left: nPadding, bottom: nPadding, right: nPadding))
        mMapView.animate(with: cameraUpdate)
        // 手機 : 關掉；平板如果沒有全螢幕顯示就不需要
        viewController.close()
    }
    func moveToAndShowPlace(_ place: Place) {
        mMode = .PanMode
        // 地圖移到該地並選取
        setDestinationMarker(placeId:place.id, title:place.name, coordinate: place.coordinate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showPOIinfo(title: place.name)
        }
        CATransaction.begin()
        mMapView.animate(toZoom: 18)
        mMapView.animate(toLocation: place.coordinate)
        CATransaction.commit()
        // Place 加入 history
        RecentlyUsedPlaces.shared.use(place: place)
    }
    // 從 Recently Places 中選擇
    func searchPlaces(viewController: SearchPlacesViewController, recentlyPlace:Place) {
        // 手機 : 關掉；平板如果沒有全螢幕顯示就不需要
        viewController.close()
        //
        clearSearchResult()
        moveToAndShowPlace(recentlyPlace)
    }
}
