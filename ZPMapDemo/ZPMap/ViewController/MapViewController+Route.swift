//
//  MapViewController+Route.swift
//
//  Created by EddieHua.
//

import UIKit
import CoreLocation

// MARK: Route
extension MapViewController {
    // RouteRequest View
    func initRouteRequestView() {
        mRouteRequestView = RouteRequestView()
        guard let superView = getSuperView() else {
            return
        }
        
        superView.addSubview(mRouteRequestView!)
        mRouteRequestView!.snp.remakeConstraints { (make) -> Void in
            make.width.equalTo(superView)
            make.height.equalTo(RouteRequestView.HEIGHT)
            make.left.equalTo(superView.snp.left)
            mRouteRequestViewConstraint = make.bottom.equalTo(superView.snp.top).constraint
        }
        mRouteRequestView!.isHidden = true
        mRouteRequestView!.closeButton.tag = MapUiTags.BUTTON_CLOSE_DIRECTION_REQUEST_VIEW
        mRouteRequestView!.closeButton.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
        mRouteRequestView!.originButton.tag = MapUiTags.BUTTON_SET_ORIGIN
        mRouteRequestView!.originButton.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
        mRouteRequestView!.destinationButton.tag = MapUiTags.BUTTON_SET_DESTINATION
        mRouteRequestView!.destinationButton.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
    }
    
    // 更新目的地
//    func updateDestinationFromTargetMarker() {
//        if mDestinationMarker != nil {
//            mRouteRequestView!.destinationButton.setTitle(mDestinationMarker!.title, for: .normal)
//            //routeIfConditionOk()
//        }
//    }
    
    // RouteResultView
    func initRouteResultView() {
        mRouteResultView = RouteResultView()
        view.addSubview(mRouteResultView!)
        mRouteResultView!.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(view)
            make.height.equalTo(RouteResultView.HEIGHT)
            make.left.equalTo(view.snp.left)
            mRouteResultViewConstraint = make.top.equalTo(view.snp.bottom).constraint
        }
        mRouteResultView!.isHidden = false
        mRouteResultView!.closeNaviButton.tag = MapUiTags.BUTTON_CLOSE_NAVI
        mRouteResultView!.closeNaviButton.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
        mRouteResultView!.goNaviButton.tag = MapUiTags.BUTTON_GONAVI
        mRouteResultView!.goNaviButton.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
        // 顯示規劃結果
        mRouteResultView!.addTarget(self, action: #selector(showRoutePlanList), for: .touchUpInside)
    }
    // 將 mTargetMarker 設定成 終點
    func showRouteViews() {
        // Request View
        mRouteRequestView!.originButton.setTitle(LocalizedString("map.current-location.button"), for: .normal)
        mRouteRequestView!.isHidden = false
        mRouteRequestViewConstraint?.update(offset: RouteRequestView.HEIGHT)
        // Result View - ** showBottomInfoView 裡面會執行 animate **
        showBottomInfoView(mRouteResultView!, constraint: mRouteResultViewConstraint!)
    }
    
    func hideRouteViews(skipResultView: Bool) {
        mRouteRequestViewConstraint?.update(offset: -RouteRequestView.HEIGHT) // Request View
        if !skipResultView {
            mRouteResultViewConstraint?.update(offset: RouteResultView.HEIGHT)  // Result View
        }
        // Start!
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) { (complete) in
            self.mRouteRequestView?.isHidden = true
            if !skipResultView {
                self.mRouteResultView?.isHidden = true
            }
        }
    }
    // 顯示路徑規劃的結果
    @objc func showRoutePlanList() {
        let routePlanVC = RoutePlanListController()
        routePlanVC.routePlan = mRoutePlan
        routePlanVC.title = LocalizedString("map.route-results")
        routePlanVC.view.backgroundColor = UIColor.white
        //routePlanVC.modalTransitionStyle = .coverVertical
        //routePlanVC.modalPresentationStyle = .overCurrentContext
        let naviCtrl = UINavigationController(rootViewController: routePlanVC)
        self.present(naviCtrl, animated: true)
    }
    func routeIfConditionOk() {
        if mSelectedMarker != nil {
            clearDestinationMarker()
            // 將選取的 marker 設為目的地
            var placeId = mSelectedMarker!.userData as? String
            if placeId == nil {
                placeId = ""
            }
            setDestinationMarker(placeId:placeId!, title:mSelectedMarker!.title!, coordinate: mSelectedMarker!.position)
            clearSearchResult()
        }
        if mDestinationMarker != nil {
            mRouteRequestView!.destinationButton.setTitle(mDestinationMarker!.title, for: .normal)
            if mOriginMarker != nil {
                route(origin: mOriginMarker!.position, destination: mDestinationMarker!.position)
            } else {
                // 用 map 中心點頂著先
                //setOriginMarker("起始點", coordinate: (mMapView.camera.target)!)
                
                // 使用 GPS 位置?
                //if (mMustUpdateLocationByGPS) {
                    // 沒有得到過 GPS 位置...切換模式；要求設定起始點
                //} else {
                    route(origin: mGpsMarker.position, destination: mDestinationMarker!.position)
                //}
            }
        }
    }
    
    func clearRouteResult() {
        if mRoutePlan != nil {
            mRoutePlan!.hidePolyline()
            mRoutePlan = nil
        }
    }
    // 計算 Leg 中，step的距離，可選擇從哪個 step起算
    func estimateRemainingDistance(leg:RouteLeg, fromStepIndex:Int) -> Int {
        var totalDistanceM = 0
        //var totalDurationSec = 0
        var index = 0
        for step in leg.steps {
            if index >= fromStepIndex {
                totalDistanceM += step.distanceM
                //totalDurationSec += step.durationSec
            }
            index += 1
        }
        //mAfterCurrentStepEstimateRemainingDistanceM = totalDistanceM
        //mAfterCurrentStepEstimateRemainingDurationSec = totalDurationSec
        //dPrint("Estimate Remaining DistanceM = \(totalDistanceM)   DurationSec = \(totalDurationSec)")
        return totalDistanceM
    }
    // 更新 Route Result View - 目的地
    func updateResultViewDestination() {
        if let routePlan = mRoutePlan {
            // Distance
            let distance = estimateRemainingDistance(leg: routePlan.legs[0], fromStepIndex: 0)
            updateResultViewDistanceToDestination(CLLocationDistance(distance))
            // ---------
            var subInfo = ""
            if routePlan.summary != nil {
                subInfo = LocalizedString("map.through-") + routePlan.summary!
            }
            mRouteResultView?.infoLabel.text = subInfo + LocalizedString("map.-to-") + mDestinationMarker!.title!
        }
    }
    
    // 更新 Route Result View - 與目的地的距離
    func updateResultViewDistanceToDestination(_ distance:CLLocationDistance) {
        //mRouteResultView?.titleLabel.text = ""
        if distance > 0 {
            if distance < 10 {
                // 接近目的地
                mRouteResultView?.titleLabel.text = LocalizedString("map.close-to-destination")
            } else {
                mRouteResultView?.titleLabel.text = LocalizedString("map.estimate-remain-distance-") + ZPMapCommon.textDistanceFormatter.string(from: distance)
            }
        } else {
            // 不需代入 目的地的名稱
            let text = String(format: LocalizedString("map.arrived-s-route-over"), LocalizedString("map.destination"))
            mRouteResultView?.titleLabel.text = text
        }
    }
    //
    func afterRoute(plan:RoutePlan?, failedMessage: String?) {
        if plan != nil {
            // 成功 - 處理一下 一些沒有 maneuver的 step
            let firstLeg = plan!.legs[0]
            let firstStep = firstLeg.steps[0]
            if firstStep.maneuver == .none {
                firstStep.maneuver = .origin
            }
            // 附加一個 終點 (路名、圖示-如果是poi 可以考慮用它的圖)
            if let lastLeg = plan!.legs.last {
                let destinationStep = RouteStep()
                destinationStep.maneuver = .destination
                if let marker = mDestinationMarker {
                    destinationStep.start_location = marker.position
                    destinationStep.end_location = marker.position
                    destinationStep.instructions = marker.title
                }
                destinationStep.otherMessage = lastLeg.end_address
                lastLeg.steps.append(destinationStep)
            }
            mRoutePlan = plan
            clearSearchResult()
            mMapState.append(RouteMapState(self))
            mRoutePlan!.showPolylineInMap(mMapView)
            if let placeId = mDestinationMarker?.userData as? String {
                // placeId 要有值 才會加入 (會排除掉 自訂目的地)
                if placeId.lengthOfBytes(using: .utf8) > 6 {
                    let place = Place()
                    place.id = placeId
                    place.name = mDestinationMarker!.title!
                    place.coordinate = mDestinationMarker!.position
                    RecentlyUsedPlaces.shared.use(place: place)
                }
            }
        } else {
            // 顯示導航失敗訊息
            var message = LocalizedString("map.route-failed")
            if failedMessage != nil {
                message += failedMessage!
            }
            showNonBlockingMessage(message)
        }
        stopBusyIndicator()
    }
    // 重新規劃
    func reroute() {
        popupState()    // 先離開導航模式
        route(origin: mGpsMarker.position, destination: mDestinationMarker!.position)
    }
    //
    func route(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
        if !startBusyIndicator() {
            return
        }
        GoogleMapService.route(origin: origin, destination: destination, ifFailedTryAgain: true) { [weak self] (routePlan, errMsg) in
            self?.afterRoute(plan:routePlan, failedMessage: errMsg)
        }
    }
    
    
    // RouteGuide View
    func initRouteGuideView() {
        mRouteGuideView = RouteGuideView()
        guard let superView = getSuperView() else {
            return
        }
        superView.addSubview(mRouteGuideView!)
        mRouteGuideView!.snp.remakeConstraints { (make) -> Void in
            make.width.equalTo(superView)
            make.height.equalTo(RouteGuideView.HEIGHT)
            make.left.equalTo(superView.snp.left)
            mRouteGuideViewConstraint = make.bottom.equalTo(superView.snp.top).constraint
        }
        mRouteGuideView!.isHidden = true
    }
    func hideRouteGuideView() {
        mRouteGuideViewConstraint?.update(offset: -RouteGuideView.HEIGHT) // Request View
        // Start!
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) { (complete) in
            self.mRouteGuideView?.isHidden = true
        }
    }
    
}
