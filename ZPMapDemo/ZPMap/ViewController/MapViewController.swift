//
//  MapViewController.swift
//
//  Created by EddieHua.
//
import UIKit
import SnapKit
import Alamofire
import SwiftyJSON
import GoogleMaps
import UserNotifications
import NVActivityIndicatorView

// ===== GPS Location Notification =====
// 或許其他畫面需要知道 GPS 座標
//public let GpsLocationDidChange = Notification.Name("GpsLocationDidChange")
//public let GpsCLLocation = "GpsCLLocation"  // 從中獲取 CLLocation


public class MapViewController: UIViewController {
    
    // ---- 手動操作GPS模擬 ----
    var mRepeatTimer:Timer?
    var mBtnForward:UIButton!
    var mBtnBackward:UIButton!
    var mBtnTurnLeft:UIButton!
    var mBtnTurnRight:UIButton!
    var dPadSimuLocationManager:DPadSimuLocationManager? = nil

    // ------------------------------

    let mGpsLocationManager = CLLocationManager()
    var mLocationManager : CLLocationManager? = nil
    
    // 正常只會有一條路線，除非規劃時代入 alternatives=true
    var mRoutePlan:RoutePlan? = nil
    
    // 3種 定位Button的狀態：
    enum Mode : Int {
        case PanMode        //   (灰-準心) 手動調整地圖 Pan Mode
        case GpsMode2D      //   (亮-準心) GPS 定位 2D
        case GpsMode3D      //   (亮-指南針) GPS 定位 3D
    }
    var mMode:Mode = .GpsMode2D {
        didSet {
            if mBtnMapMode != nil {
                switch mMode {
                case .GpsMode2D:
                    mBtnMapMode.setImage(UIImage(named: "ModeGps2d"), for: .normal)
                    mMapView.animate(toViewingAngle: 0)
                case .GpsMode3D:
                    mBtnMapMode.setImage(UIImage(named: "ModeGps3d"), for: .normal)
                    mMapView.animate(toViewingAngle: 65)
                default:
                    mBtnMapMode.setImage(UIImage(named: "ModePan"), for: .normal)
                }
            }
        }
    }
    var mUpdateBearingTimeIn3dMode:TimeInterval = 0
    var mMapState = [MapState]()    // Stack 方式
    let mCurrentCameraPosition = GMSMutableCameraPosition()
//    var mLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 47.6878154, longitude: 9.4011423)
    //var mLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.4220, longitude: -122.0740)
    var mMapView:GMSMapView!
    var mGpsMarker:GMSMarker!
    var mOriginMarker:GMSMarker?
    var mDestinationMarker:GMSMarker?
    var mSelectedMarker:GMSMarker?
    // Button
    var mBtnSearchPlaces:UIButton!
    var mBtnClearSearch:UIButton! // 放在 mBtnSearchPlaces 裡面，有搜尋結果時 才顯示
    var mBtnMapMode:UIButton!
    // POI Info View
    var mPOIinfoView:POIinfoView?
    var mPOIinfoViewConstraint: Constraint?
    // Route RequestView
    var mRouteRequestView: RouteRequestView?
    var mRouteRequestViewConstraint: Constraint?
    // Route ResultView
    var mRouteResultView: RouteResultView?
    var mRouteResultViewConstraint: Constraint?
    // Navi Guide View : 目前只用單一非捲動
    var mRouteGuideView: RouteGuideView?
    var mRouteGuideViewConstraint: Constraint?
    // Busy Indicator
    var mBusyIndicator: NVActivityIndicatorView?
    
    // 搜尋結果的 Marker
    var mFoundPlaceMarkers = [GMSMarker]()
    
    deinit {
        suspendNotifications()
        mPOIinfoView = nil
        mPOIinfoViewConstraint = nil
        mRouteRequestView = nil
        mRouteRequestViewConstraint = nil
        mRouteResultView = nil
        mRouteResultViewConstraint = nil
        mRouteGuideView = nil
        mRouteGuideViewConstraint = nil
        mBtnSearchPlaces = nil
        mBtnMapMode = nil
        mOriginMarker = nil
        mDestinationMarker = nil
        mSelectedMarker = nil
        mMapView = nil
        mBusyIndicator = nil
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
//        for i in 990..<1002 {
//            testdd(value: CLLocationDistance(i))
//        }
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        let initLocation = MyDefaults.shared.lastCoordinate
        // ----
        mCurrentCameraPosition.bearing = 0
        mCurrentCameraPosition.target = initLocation!
        mCurrentCameraPosition.zoom = 16
        // Create a map.
        let mapView = GMSMapView.map(withFrame: view.bounds, camera: mCurrentCameraPosition)
        // TODO: map style
//        if let filepath = Bundle.main.path(forResource: "GMapNight", ofType: "json") {
//            do {
//                let strMapStyle = try String(contentsOfFile: filepath)
//                mapView.mapStyle = try GMSMapStyle(jsonString: strMapStyle)
//            } catch {
//                // contents could not be loaded
//            }
//        } else {
//            // example.txt not found!
//        }
        
        mMapView = mapView
        mapView.delegate = self
        mapView.isMyLocationEnabled = true
        mapView.settings.setAllGesturesEnabled(true)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]    // 轉orientation時，才會跟著變
        // 將 compassButton 向下移，不然會被元件蓋住
        mapView.settings.compassButton = true
        mapView.padding = UIEdgeInsets(top: RouteRequestView.HEIGHT + 20, left: 0.0, bottom: 0.0, right: 0.0)
        self.view!.addSubview(mapView)
        // 顯示在地圖上的 Gps 標誌
        mGpsMarker = newGpsMarker()
        mGpsMarker.position = initLocation!
        
        // BtnSearch Places Button
        initSearchPlaces()
        //
        initButtons()
        //
        initGPS()
        mLocationManager = mGpsLocationManager

        // 其他 View
        initPOIinfo()
        initRouteRequestView()
        initRouteResultView()
        
        // 初始State
        mMapState.append(MapState(self))
        
        resumeNotifications()
    }
    
    func newGpsMarker() -> GMSMarker {
        let gpsMarker = GMSMarker()
        gpsMarker.icon = UIImage(named: "gps_arrow")
        gpsMarker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
        gpsMarker.isDraggable = false
        gpsMarker.isFlat = true
        gpsMarker.zIndex = 1
        //
        gpsMarker.layer.shadowColor = UIColor.darkGray.cgColor
        gpsMarker.layer.shadowRadius = 3
        gpsMarker.layer.shadowOpacity = 0.6
        gpsMarker.layer.shadowOffset = CGSize.zero
        return gpsMarker
    }
    
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(alertDeviateFromRoute(notification:)), name: NaviAlertDeviateFromRoute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(alertBackToRoute(notification:)), name: NaviAlertBackToRoute, object: nil)
    }
    
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: NaviAlertDeviateFromRoute, object: nil)
        NotificationCenter.default.removeObserver(self, name: NaviAlertBackToRoute, object: nil)
    }
    // ================= 偏離路線 警告訊息 ==================
    var mRerouteTipShown = false
    func dismissRerouteSnackbar() {
        if mRerouteTipShown {
            mRerouteTipShown = false
            view.dodo.hide()
        }
    }
    @objc func alertDeviateFromRoute(notification: NSNotification) {
        guard mRerouteTipShown == false else {
            return
        }
        mRerouteTipShown = true
        // 下面的用來做 reroute 提醒
        view.dodo.style.bar.locationTop = true
        view.dodo.style.bar.hideOnTap = false
        view.dodo.style.rightButton.hideOnTap = true
        view.dodo.style.rightButton.onTap = { [weak self] in
            dPrint("重新規劃中")
            self?.reroute()
            self?.dismissRerouteSnackbar()
        }
        //view.dodo.style.label.shadowColor = DodoColor.fromHexString("#00000050")
        //view.dodo.style.bar.animationShow = currentShowAnimation.show
        //view.dodo.style.bar.animationHide = currentHideAnimation.hide
        view.dodo.style.rightButton.icon = .reload
        let PADDING: CGFloat = 10
        view.dodo.style.bar.marginToSuperview = CGSize(width: PADDING, height: RouteRequestView.HEIGHT + PADDING)
        view.dodo.warning(LocalizedString("map.deviated-from-route.message"))
    }
    
    @objc func alertBackToRoute(notification: NSNotification) {
        dismissRerouteSnackbar()
    }
    
    func popupState() {
        if mMapState.count > 1 {
            let state = mMapState.popLast()
            state?.clear()
        }
        mMapState.last?.reset()
    }
    // =======
    func initSearchPlaces() {
        mBtnSearchPlaces = UIButton()
        mBtnSearchPlaces.alpha = 0.7
        mBtnSearchPlaces.backgroundColor = .white
        mBtnSearchPlaces.setTitleColor(.black, for: .normal)
        mBtnSearchPlaces.contentHorizontalAlignment = .left
        mBtnSearchPlaces.contentEdgeInsets = UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 0)
        mBtnSearchPlaces.setImage(UIImage(named:"MapSearch"), for: .normal)
        var imgInsets = mBtnSearchPlaces.imageEdgeInsets
        imgInsets.left = -14
        mBtnSearchPlaces.imageEdgeInsets = imgInsets
        mBtnSearchPlaces.enableShadowLayer()
        self.view!.addSubview(mBtnSearchPlaces)
        mBtnSearchPlaces.snp.makeConstraints { (make) in
            make.left.equalTo(self.view!.snp.left).offset(10)
            make.right.equalTo(self.view!.snp.right).offset(-10)
            make.top.equalTo(self.view!.snp.top).offset(10)
            make.height.equalTo(50)
        }
        mBtnSearchPlaces.addTarget(self, action: #selector(showSearchPlacesViewController), for:.touchUpInside)
        // Clear Search Button
        mBtnClearSearch = UIButton()
        mBtnSearchPlaces.addSubview(mBtnClearSearch)    // 加到 Search Button裡面
        mBtnClearSearch.isHidden = true
        mBtnClearSearch.setTitle("X", for: .normal)
        mBtnClearSearch.setTitleColor(.black, for: .normal)
        mBtnClearSearch.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: 30, height: 30))
            make.centerY.equalTo(mBtnSearchPlaces.snp.centerY)
            make.right.equalTo(mBtnSearchPlaces.snp.right).offset(-10)
        }
        mBtnClearSearch.addTarget(self, action: #selector(clearSearchResult), for:.touchUpInside)
        mBtnSearchPlaces.bringSubviewToFront(mBtnClearSearch)
    }
    // ========================== GPS ==========================
    func initGPS() {
        // restricted (限制) : 這個也算是不行吧?
        // 1. 還沒有詢問過用戶以獲得權限
        var authorizationStatus: CLAuthorizationStatus
        if #available(iOS 14, *) {
            authorizationStatus = mGpsLocationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        
        if authorizationStatus == .notDetermined {
            //locationManager.requestAlwaysAuthorization()    // NSLocationAlwaysUsageDescription
            mGpsLocationManager.requestWhenInUseAuthorization()     // NSLocationWhenInUseUsageDescription
            return
        } else if authorizationStatus == .denied {
            // 2. 用戶不同意
            return
        }
        // 3. 用戶已經同意
        let location = mGpsLocationManager.location
        if location != nil {
            dPrint("location : \(String(describing: location!))")
        }
        // User Location
        mGpsLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        startLocationManager(mGpsLocationManager)
    }
    
    func startLocationManager(_ lm:CLLocationManager) {
        lm.startUpdatingLocation()
        lm.startUpdatingHeading()
        lm.delegate = self
    }
    func stopLocationManager(_ lm:CLLocationManager) {
        lm.stopUpdatingLocation()
        lm.stopUpdatingHeading()
        lm.delegate = nil
    }
    
    // ========================== Button / UI ==========================
    
    func showNonBlockingMessage(_ message:String) {
        view.dodo.style.bar.hideOnTap = false
        view.dodo.style.bar.hideAfterDelaySeconds = 3
        let PADDING: CGFloat = 10
        view.dodo.style.bar.marginToSuperview = CGSize(width: PADDING, height: 70 + PADDING)
        view.dodo.warning(message)
    }
    
    func initButtons() {
        let buttonSize:CGFloat = 50
        let PADDING:CGFloat = 16
        mBtnMapMode = UIButton()
        mBtnMapMode.tag = MapUiTags.BUTTON_MapMode
        mBtnMapMode.enableShadowLayer()
        mBtnMapMode.layer.cornerRadius = CGFloat(buttonSize / 2)
        mBtnMapMode.backgroundColor = .white
        mBtnMapMode.setImage(UIImage(named: "ModePan"), for: .normal)
        self.view!.addSubview(mBtnMapMode)
        mBtnMapMode.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: buttonSize, height: buttonSize))
            make.right.equalTo(self.view!.snp.right).offset(-PADDING)
            make.bottom.equalTo(self.view!.snp.bottom).offset(-(buttonSize + PADDING * 2))
        }
        mBtnMapMode.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
    }
    
    func requestLocalNotificationPermission() {
        // 事先告知 - 提升成功率
        let alertController = UIAlertController(title: nil, message: LocalizedString("map.request-noti-permission"), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: LocalizedString("ok"), style: .cancel, handler: { (action) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (permissionGranted, error) in
                if permissionGranted {
                    dPrint("UserNotification 允許")
                } else {
                    dPrint("UserNotification 不允許 : \(String(describing: error))")
                }
            }
        }))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func enterNaviState(simu:Bool = false) {
        if mMapState.count < 3 {
            // 先 check 有沒有權限
            UNUserNotificationCenter.current().getNotificationSettings {
                [weak self] settings in
                //dPrint("authorizationStatus = \(settings.authorizationStatus.rawValue)") // .authorized | .denied | .notDetermined
                // 被 denied 的話，就不會出現
                if settings.authorizationStatus == .notDetermined {
                    // 要求權限
                    DispatchQueue.main.async { [weak self] in
                        self?.requestLocalNotificationPermission()
                    }
                }
            }
            // -------
            mMapState.append(NaviMapState(self, simulation:simu))
        }
    }
    
    func askUseGpsSimuNavi() {
        let refreshAlert = UIAlertController(title: "Refresh", message: "[DEBUG Only] 是否要模擬行駛.", preferredStyle: UIAlertController.Style.alert)

        refreshAlert.addAction(UIAlertAction(title: "YES", style: .default, handler: { [self] (action: UIAlertAction!) in
            enterNaviState(simu: true)
        }))

        refreshAlert.addAction(UIAlertAction(title: "NO", style: .cancel, handler: { [self] (action: UIAlertAction!) in
            enterNaviState()
        }))
        present(refreshAlert, animated: true, completion: nil)
    }
    @objc func buttonTapped(button: UIButton) {
        //print("buttonTapped")
        switch button.tag {
        case MapUiTags.BUTTON_ROUTE:
            routeIfConditionOk()
            break
        case MapUiTags.BUTTON_SET_ORIGIN:
            // TODO:
            break
        case MapUiTags.BUTTON_GONAVI:
            #if DEBUG
            // Debug Mode 詢問是否要模擬行駛
            askUseGpsSimuNavi()
            #else
            enterNaviState()
            #endif
        //case MapUiTags.BUTTON_GOSIMU: enterNaviState(simu:true)
        case MapUiTags.BUTTON_MapMode:
            if mMode == .PanMode {
                mMode = .GpsMode2D
            } else if (mMode == .GpsMode2D) {
                mMode = .GpsMode3D
            } else if (mMode == .GpsMode3D) {
                mMode = .GpsMode2D
            }
            break
        case MapUiTags.BUTTON_CLOSE_DIRECTION_REQUEST_VIEW:
            fallthrough
        case MapUiTags.BUTTON_CLOSE_NAVI:
            popupState()
            break
        default:
            break
        }
    }
    // MARK: - POI info View -
    func initPOIinfo() {
        mPOIinfoView = POIinfoView()
        view.addSubview(mPOIinfoView!)
        mPOIinfoView!.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(view)
            make.height.equalTo(POIinfoView.HEIGHT)
            make.left.equalTo(view.snp.left)
            mPOIinfoViewConstraint = make.top.equalTo(view.snp.bottom).constraint
        }
        mPOIinfoView?.goButton.tag = MapUiTags.BUTTON_ROUTE
        mPOIinfoView?.goButton.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
        mPOIinfoView?.isHidden = true
    }
    
    func showPOIinfo(title: String) {
        mPOIinfoView!.titleLabel.text = title
        showBottomInfoView(mPOIinfoView!, constraint: mPOIinfoViewConstraint!)
    }
    
    func hidePOIinfo() {
        mPOIinfoViewConstraint?.update(offset: POIinfoView.HEIGHT)
        UIView.animate(withDuration: 0.2, animations: {
            self.view.layoutIfNeeded()
        }) { (complete) in
            self.mPOIinfoView?.isHidden = true
        }
    }
    
    func showBottomInfoView(_ view:UIView, constraint :Constraint) {
        view.isHidden = false
        constraint.update(offset: -(view.frame.height))
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    // 更新 NaviGuideView - 如果還沒顯示的話，就動畫顯示
    func updateNaviGuideView(step: RouteStep, remainDistance:CLLocationDistance) {
        if mRouteGuideView == nil {
            initRouteGuideView()
        }
        if let naviGuide = mRouteGuideView {
            if step.alertUserLevel != .arrive && remainDistance >= 10 {
                naviGuide.setDistance(text: ZPMapCommon.textDistanceFormatter.string(from: remainDistance))
            } else {
                naviGuide.setDistance(text: "")
            }
            naviGuide.setImage(image: step.maneuver.icon())
            if step.attrInstructions != nil {
                naviGuide.setAttrInstrcution(attributedText: step.attrInstructions!)
            } else {
                naviGuide.setInstrcution(text: step.instructions)
            }
            if naviGuide.isHidden {
                naviGuide.isHidden = false
                mRouteGuideViewConstraint?.update(offset: RouteGuideView.HEIGHT)
                UIView.animate(withDuration: 0.2) {
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    func getSuperView() -> UIView? {
        var superView = self.navigationController?.view
        if (superView == nil) {
            superView = self.view
        }
        return superView
    }
    
    
    // ---------
    @objc func showSearchPlacesViewController() {
        // -------
        let spVc = SearchPlacesViewController()
        spVc.location = mCurrentCameraPosition.target   // 地圖中央 or GPS位置?
        spVc.modalPresentationStyle = .custom
        spVc.modalTransitionStyle = .crossDissolve
        spVc.delegate = self
        self.present(spVc, animated: true, completion: nil)
    }
    // ---------
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startBusyIndicator() -> Bool {
        if mBusyIndicator != nil {
            return false
        }
        
        mBusyIndicator = NVActivityIndicatorView(frame: CGRect(x:0,y:0,width:120,height:120), type: .ballPulse, color: UIColor.blue, padding: 0)
        if mBusyIndicator != nil {
            mBusyIndicator!.center = mMapView.center
            self.view.addSubview(mBusyIndicator!)
            mBusyIndicator!.startAnimating()
        }
        return true
    }
    func stopBusyIndicator() {
        if mBusyIndicator != nil {
            mBusyIndicator!.stopAnimating()
            mBusyIndicator = nil
        }
    }
}

// MARK: CLLocationManagerDelegate
extension MapViewController : CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            // 或許其他畫面需要知道 GPS 座標
            //NotificationCenter.default.post(name: GpsLocationDidChange, object: self, userInfo: [GpsCLLocation: location])
            //dPrint("\(Date()) didUpdate Locations")
            // =======================================
            var coordinate:CLLocationCoordinate2D = location.coordinate
            var course = location.course
            let naviMapState = mMapState.last as? NaviMapState
            if naviMapState != nil && mRoutePlan != nil {
                // navi check
                if let snapToPathLocation = naviMapState?.navigationProgress(location) {
                    coordinate.latitude = snapToPathLocation.coordinate.latitude
                    coordinate.longitude = snapToPathLocation.coordinate.longitude
                    course = snapToPathLocation.course
                }
            }
            
            // =======================================
            let oldCourse = self.mGpsMarker.rotation
            CATransaction.begin()
            CATransaction.setCompletionBlock({ [weak self] in
                self?.mGpsMarker.rotation = course
            })
            CATransaction.setAnimationDuration(0.95) // 秒數要等於 GPS 更新時間 (目前是 0.95)
            mGpsMarker.position = coordinate

            switch (mMode) {
            case .GpsMode3D:
                // 不要太常更新；角度變化不大／更新時間太短
                let deltaCourse = abs(oldCourse - course)
                let now = Date().timeIntervalSince1970
                
                if deltaCourse >= 5 || (deltaCourse >= 1 && (now - mUpdateBearingTimeIn3dMode) > 2) {
                    mUpdateBearingTimeIn3dMode = now
                    mMapView.animate(toBearing: course)   // 車頭朝前
                    dPrint("deltaCourse = \(deltaCourse)   toBearing = \(course)")
                }
                fallthrough
            case .GpsMode2D:
                mMapView.animate(toLocation: coordinate)
                break
            default:
                break
            }
            CATransaction.commit()
        }
    }
//    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
//        dPrint("didUpdate Heading = \(newHeading)")
//    }
}

// MARK: GMSMapViewDelegate
extension MapViewController: GMSMapViewDelegate {
    // 統一用這個 func 加入 marker
    func newMarker(coordinate:CLLocationCoordinate2D, text: String?, color: UIColor? = .brown) -> GMSMarker {
        let marker = GMSMarker(position: coordinate)
        marker.appearAnimation = .pop
        marker.icon = GMSMarker.markerImage(with: color)
        marker.title = text
        marker.map = mMapView
        return marker
    }
    
    public func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
        //print("willMove : \(mCurrentCameraPosition)")
        if gesture {
            mMode = .PanMode
        }
    }
    
//    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
//    }
    
    public func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        mCurrentCameraPosition.zoom = position.zoom
        mCurrentCameraPosition.bearing = position.bearing
        mCurrentCameraPosition.target = position.target
        mCurrentCameraPosition.viewingAngle = position.viewingAngle
        //dPrint("didChange Camera Position viewingAngle = \(position.viewingAngle)   zoom = \(position.zoom)")
        // TODO: 不同比例尺時，顯示的路徑精細度也要有所不同
        //     zoom > 14 : 就要顯示較精細的導航 Polyline
    }
    func setOriginMarker(_ title: String, coordinate: CLLocationCoordinate2D) {
        mOriginMarker = newMarker(coordinate: coordinate, text: title, color: .green)
        mOriginMarker!.map = mMapView
    }
    func setDestinationMarker(placeId:String, title: String, coordinate: CLLocationCoordinate2D) {
        unselectMarker()
        if mDestinationMarker == nil {
            mDestinationMarker = newMarker(coordinate: coordinate, text: title, color: .red)
        } else {
            mDestinationMarker!.title = title
            // 關閉移動時的動畫
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            mDestinationMarker!.position = coordinate
            CATransaction.commit()
        }
        mDestinationMarker!.map = mMapView
        mDestinationMarker!.userData = placeId
    }
    func clearDestinationMarker() {
        if mDestinationMarker != nil {
            mDestinationMarker!.map = nil
            mDestinationMarker = nil
        }
    }
    // 選擇地圖上標示的 Marker，要排除 mOriginMarker & mDestinationMarker
    func selectMarker(_ marker: GMSMarker) {
        guard marker != mDestinationMarker && marker != mOriginMarker else {
            dPrint("排除 mOriginMarker & mDestinationMarker")
            return
        }
        clearDestinationMarker()
        marker.icon = GMSMarker.markerImage(with: UIColor.blue)
        mSelectedMarker = marker
    }
    // 復原所選擇的 Marker
    func unselectMarker() {
        if mSelectedMarker != nil {
            mSelectedMarker!.icon = GMSMarker.markerImage(with: UIColor.brown)
            mSelectedMarker = nil
        }
    }
    // long press - 放置 marker；進入 SetPointMode
    public func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
        //dPrint("didLongPressAt")
        if let state = mMapState.last {
            state.mapViewController(self, didLongPressAt: coordinate)
        }
    }
    
    public func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        //dPrint("You tapped at \(marker)")
        if let state = mMapState.last {
            return state.mapViewController(self, didTap: marker)
        }
        return false
    }
    public func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
        //dPrint("You tapped at \(coordinate.latitude), \(coordinate.longitude)")
        if let state = mMapState.last {
            state.mapViewController(self, didTapAt: coordinate)
        }
    }
    
    public func mapView(_ mapView: GMSMapView, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
        //dPrint("You tapped at POI \(placeID) - \(name)")
        if let state = mMapState.last {
            state.mapViewController(self, didTapPOIWithPlaceID: placeID, name: name, location: location)
        }
    }
    
//    func mapView(_ mapView: GMSMapView, didTap overlay: GMSOverlay) {
//        print("You tapped at overlay = \(overlay)")
//    }
//    
//    func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
//        print("didTapInfoWindowOf = \(marker)")
//    }
//    
//    func didTapMyLocationButton(for mapView: GMSMapView) -> Bool {
//        print("didTapMyLocationButton")
//        return true
//    }
}
