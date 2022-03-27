//
//  NaviMapState.swift
//
//  Created by EddieHua.
//

import UIKit
import GoogleMaps
import UserNotifications


// 當到下個提示點的時間 小於 HighAlertInterval 秒 && 距離大於 MinimumDistanceForHighAlert 就把 alert level 拉 high
public var HighAlertInterval: TimeInterval = 10
// 當到下個提示點的時間 小於 MediumAlertInterval 秒 && 距離大於 MinimumDistanceForMediumAlert 就把 alert level 拉 medium
public let MediumAlertInterval: TimeInterval = 60
// 2個提示的距離 (公尺)
public let MinimumDistanceForHighAlert:CLLocationDistance = 60
public let MinimumDistanceForMediumAlert:CLLocationDistance = 200

public let MaxSecondsSpentTravelingAwayFromStartOfRoute: TimeInterval = 3
public let DeadReckoningTimeInterval:TimeInterval = 1.0  // 估算時間間隔
// Accepted deviation - 容許 座標 差距幾公尺 (不包含 GPS Accuracy)
public let AcceptedDeviationDistance: CLLocationDistance = 10

// (重新路徑規劃) 最大容忍的偏離距離 -- 公尺
public let MaximumDistanceDeviationFromPath: CLLocationDistance = 50
// 提示區域半徑
public var ManeuverZoneRadius: CLLocationDistance = 40


// ===== Navi Notification =====
// 導航進度更新
public let NaviProgressDidChange = Notification.Name("NaviProgressDidChange")
// TTS Notification
public let NaviAlertLevelDidChange = Notification.Name("NaviAlertLevelDidChange")
// curretStep Alert Level
public let NaviCurrentStepAlertLevel = "NaviCurrentStepAlertLevel"
// 下一個 RouteStep
public let NaviNextStep = "NextStep"
// 連續轉彎時，需要再把下下個 提示 提前告知
public let NaviMoreStep = "MoreStep"
// 距離提示點多遠 - CLLocationDistance
public let NaviDistanceToNextStep = "DistanceToNextStep"

// 偏離路徑 Notification
public let NaviAlertDeviateFromRoute = Notification.Name("NaviAlertDeviateFromRoute")
public let NaviAlertBackToRoute = Notification.Name("NaviAlertBackToRoute")


/**
 Threshold user must be in within to count as completing a step. One of two heuristics used to know when a user completes a step, see `ManeuverZoneRadius`.
 
 The users `heading` and the `finalHeading` are compared. If this number is within `MaximumAllowedDegreeOffsetForTurnCompletion`, the user has completed the step.
 */
public var MaximumAllowedDegreeOffsetForTurnCompletion: Double = 30


public enum AlertLevel: Int {
    // Default `AlertLevel`
    case none
    // 開始導航
    case depart
    // 完成一個 Step
    case low
    // 往提示點前進
    case medium
    // 非常靠近提示點
    case high
    // 抵達目的地
    case arrive
}

/// Navi 導航狀態
class NaviMapState: MapState {
    var mRouteTips = RouteTips()    // 語音提示
    var simulation = false
    var didDeviateFromRouteStepIndex = -1   // 偏離路徑時，是在哪個step
    
    // 在 current step之後的所有 step，預估剩餘的距離及時間
    var mAfterCurrentStepEstimateRemainingDistanceM = 0
    //var mAfterCurrentStepEstimateRemainingDurationSec = 0
    deinit {
        dPrint("deinit")
    }
    
    // clear
    override func clear() {
        // 關閉螢幕恆亮
        UIApplication.shared.isIdleTimerDisabled = false
        stopNaviSimulation()
        mapVC.dismissRerouteSnackbar()
        mapVC.mGpsMarker.map = nil
        mapVC.hideRouteGuideView()
        mapVC.mMode = .GpsMode2D
        mapVC.stopDPadGpsSimulation()
    }
    
    init(_ mapViewCtrl: MapViewController, simulation:Bool) {
        super.init(mapViewCtrl)
        self.simulation = simulation
        
        currentLegIndex = 0
        currentStepIndex = 0
        currentStepDistanceTraveled = 0
        
        mapVC.mMapView?.isMyLocationEnabled = false
        mapVC.hideRouteViews(skipResultView: true)
        mapVC.mGpsMarker.map = mapVC.mMapView   // 顯示 GPS Marker
        //
        mapVC.mRouteResultView?.closeNaviButton.isHidden = false
        mapVC.mRouteResultView?.goNaviButton.isHidden = true
        mapVC.mRouteResultView?.destinationImageView.isHidden = true
        
        // 移動到起始點
        if let routePlan = mapVC.mRoutePlan {
            // route plan 裡面每個 step 的 alertUserLevel 要重設
            routePlan.resetNavigationInfo()
            if routePlan.legs[0].steps.count > 2 {
                mAfterCurrentStepEstimateRemainingDistanceM = mapVC.estimateRemainingDistance(leg: routePlan.legs[0], fromStepIndex: currentStepIndex)
            } else {
                // 只有2個 step的話，第一個step的距離就是總距離
                // TODO :估算剩餘距離的方法要再想想
                mAfterCurrentStepEstimateRemainingDistanceM = 0
            }
            // 固定某視角
            mapVC.mCurrentCameraPosition.target = (routePlan.legs.first?.start_location)!
            mapVC.mCurrentCameraPosition.zoom = 19
            mapVC.mCurrentCameraPosition.viewingAngle = 65
            CATransaction.begin()
            mapVC.mMapView.animate(to: mapVC.mCurrentCameraPosition)
            mapVC.mMode = .GpsMode3D  // 注意：移到 animate 之後，是為了讓改變 mode 時的切換視角失敗
            CATransaction.commit()
            if simulation {
                startNaviSimulation(routePlan: routePlan)
            } else {
                // 模擬器的話，馬上就啟動 GPS 座標控制器
                #if DEBUG
                    #if (arch(i386) || arch(x86_64))
                        mapVC.startDPadGpsSimulation()
                    #endif
                #endif
            }
            // 發出第一個提示
            notifyNaviAlert(AlertLevel.depart, distance: CLLocationDistance(0), nextStep: routePlan.legs[0].steps[0], moreStep: nil)
            routePlan.legs[0].alertUserLevel = .depart
        }
        // 保持螢幕恆亮
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    // 初始 / 重回 狀態 - 因為 Navi 不會"重回"，所以全部放 init
    override func reset() {
    }
    
    override func mapViewController(_ mapViewCtrl:MapViewController, didLongPressAt coordinate: CLLocationCoordinate2D) {
        // DO Nothing!
    }
    
    override func mapViewController(_ mapViewCtrl:MapViewController, didTapAt coordinate: CLLocationCoordinate2D) {
        
    }
    override func mapViewController(_ mapViewCtrl:MapViewController, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
        
    }

    // ========================= Navigation =========================
    var preDistanceToNextManeuver:CLLocationDistance = 0                // 上次運算結果-離提示點的距離
    var currentLegIndex:Int = 0
    var currentStepIndex:Int = 0
    var currentStepDistanceTraveled:CLLocationDistance = 0              // 在目前 Step 上，已走完多少距離
    var lastTimeStampSpentMovingAwayFromStart = Date()
    var userDistanceToManeuverLocation: CLLocationDistance? = nil
    
    var lastUserDistanceToStartOfRoute = Double.infinity

    // 通知導航結束
    func notifyNaviOver(step:RouteStep) {
        dPrint("到達目的地，結束導航") // 是否要
        mAfterCurrentStepEstimateRemainingDistanceM = 0
        //mAfterCurrentStepEstimateRemainingDurationSec = 0
        mapVC.updateResultViewDistanceToDestination(0)
        mapVC.updateNaviGuideView(step: step, remainDistance: 0)
        
        NotificationCenter.default.post(name: NaviProgressDidChange, object: self, userInfo: [
            NaviNextStep: step,
            NaviDistanceToNextStep: distance])
    }
    // 通知導航資訊更新 (UI)
    func notifyNaviProgressDidChange(nextStep:RouteStep, distance:CLLocationDistance) {
        dPrint("notifyNaviProgressDidChange")
        // 預估剩餘距離
        let remainingDistance = CLLocationDistance(mAfterCurrentStepEstimateRemainingDistanceM) + distance
        mapVC.updateResultViewDistanceToDestination(remainingDistance)
        // 導航資訊
        mapVC.updateNaviGuideView(step: nextStep, remainDistance: distance)
        NotificationCenter.default.post(name: NaviProgressDidChange, object: self, userInfo: [
            NaviNextStep: nextStep,
            NaviDistanceToNextStep: distance])
    }
    // 通知 發出語音導航 及 背景提示
    func notifyNaviAlert(_ level: AlertLevel, distance:CLLocationDistance, nextStep:RouteStep, moreStep:RouteStep?) {
        dPrint("notifyNaviAlert")
        var info:[AnyHashable : Any] = [AnyHashable : Any]()
        info[NaviCurrentStepAlertLevel] = level
        info[NaviDistanceToNextStep] = distance
        info[NaviNextStep] = nextStep
        if moreStep != nil {
            info[NaviMoreStep] = moreStep!
        }
        NotificationCenter.default.post(name: NaviAlertLevelDidChange, object: self, userInfo:info)
    }

    // 通知偏離路線
    func notifyDeviateFromRoute(stepIndex:Int) {
        dPrint("notifyDeviateFromRoute : \(stepIndex)")
        NotificationCenter.default.post(name: NaviAlertDeviateFromRoute, object: self, userInfo:nil)
        didDeviateFromRouteStepIndex = stepIndex
    }
    // 通知回到路線
    func notifyBackToRoute() {
        dPrint("notifyBackToRoute")
        NotificationCenter.default.post(name: NaviAlertBackToRoute, object: self, userInfo:nil)
        didDeviateFromRouteStepIndex = -1
    }
    // 找出 目前座標及Leg下，最近的 Step Index 及 最近點
    func findClosestStepInCurrentLeg(location: CLLocation) -> (index:Int, coordinateAlongPolyline: CoordinateAlongPolyline?) {
        var closetCoordinateAlongPolyline:CoordinateAlongPolyline? = nil
        var closetStepIndex = -1

        if let routePlan = mapVC.mRoutePlan {
            let currentLeg = routePlan.legs[currentLegIndex]
            var closestDistance = max(MaximumDistanceDeviationFromPath,
                                      location.horizontalAccuracy + AcceptedDeviationDistance)
            var index = 0
            for step in currentLeg.steps {
                if index >= currentStepIndex {
                    if let closestCoord = closestCoordinate(on: step.coordinates, to: location.coordinate) {
                        if closestCoord.distance < closestDistance {
                            closetCoordinateAlongPolyline = closestCoord
                            closestDistance = closestCoord.distance
                            closetStepIndex = index
                        }
                    }
                }
                index += 1
            }
        }
        return (closetStepIndex, closetCoordinateAlongPolyline)
    }
    // =============== 坐標更新時，呼叫這個 ===============
    func navigationProgress(_ location: CLLocation) -> CLLocation? {
        guard let routePlan = mapVC.mRoutePlan else {
            dPrint("mapVC.mRoutePlan is nil")
            return nil
        }
        dPrint("=========== navigationProgress [\(currentLegIndex) - \(currentStepIndex)] ==========")
        // --------------------[思考]----------------------
        // (合理) 預期前進方向-依路徑算出 == 車子行進方向
        // (合理) 距離下個提示點越來越近
        // (合理) 長期來看 - 會離目的地越來越近
        // <不合理> 發生時，需有容忍值。 warning!
        // [抄近路-走小巷] - 只要離目的地變近的，容忍值加大

        let currentLeg = routePlan.legs[currentLegIndex]
        let currentStep = currentLeg.steps[currentStepIndex]
        // 距下個提示點多遠
        let distanceToNextManeuver = distance(along: currentStep.coordinates, from: location.coordinate)
        
        // 在目前時速下，多久會到?
        //let secondsToEndOfStep = distanceToNextManeuver / location.speed
        //dPrint("[\(currentLegIndex):\(currentStepIndex)] Navi latitude = \(location.coordinate.latitude), \(location.coordinate.longitude)  course = \(location.course)  DistanceToManeuver = \(distanceToNextManeuver)")
        // 如果這個 Leg 已經抵達…
        guard currentLeg.alertUserLevel != .arrive else {
            if let nextStep = getNextRouteStep() {
                if nextStep.alertUserLevel != .arrive {
                    nextStep.alertUserLevel = .arrive
                    notifyNaviOver(step: nextStep)
                }
            }
            return nil
        }
        var snapToPathLocation: CLLocation? = nil   // 行駛在規劃路徑附近時，會修正GPS座標
        let closestCoord = closestCoordinate(on: currentStep.coordinates, to: location.coordinate)
        dPrint("location = \(location.coordinate.latitude), \(location.coordinate.longitude)  Course = \(location.course)")
        // 取得座標在目前 step 上的最接近點
        if closestCoord != nil {
            dPrint("SNAP Closest Coordinate = \(closestCoord!.coordinate.latitude), \(closestCoord!.coordinate.longitude)  Course = \(closestCoord!.course)  Distance = \(closestCoord!.distance)")
            // 修正 GPS 座標 - 合理範圍內 鎖在道路上
            if closestCoord!.distance <= (location.horizontalAccuracy + AcceptedDeviationDistance) {
                var newCourse = location.course
                if abs(closestCoord!.course - location.course) < 30 {
                    newCourse = closestCoord!.course    // 方向也要修正
                }
                snapToPathLocation = CLLocation(coordinate: closestCoord!.coordinate,
                                                altitude: location.altitude,
                                                horizontalAccuracy: location.horizontalAccuracy,
                                                verticalAccuracy: location.verticalAccuracy,
                                                course: newCourse,
                                                speed: location.speed,
                                                timestamp: location.timestamp)
                // 如果提示偏離，現在要提示「回到路徑」
                if didDeviateFromRouteStepIndex > -1 {
                    dPrint("[提醒] A 回到 導航路線 \(currentStepIndex)")
                    notifyBackToRoute()
                }
            }
            // 還剩多少距離
            let remainingDistance = distance(along: currentStep.coordinates, from: closestCoord!.coordinate)
            let distanceTraveled = CLLocationDistance(currentStep.distanceM) - remainingDistance
            if distanceTraveled != currentStepDistanceTraveled {
                dPrint("distanceTraveled = \(currentStepDistanceTraveled) => \(distanceTraveled)")
                currentStepDistanceTraveled = distanceTraveled
                if let nextStep = getNextRouteStep() {
                    notifyNaviProgressDidChange(nextStep: nextStep, distance: distanceToNextManeuver)
                }
            }
        }
        // 出發時的　check－好像拿掉也沒關係...
        if currentStep.maneuver == .origin && !isLocation(location, onRouteStep: currentStep) {
            // 起步時
            guard let userSnappedDistanceToClosestCoordinate = closestCoord?.distance else {
                return snapToPathLocation
            }
            // Give the user x seconds of moving away from the start of the route before rerouting
            guard Date().timeIntervalSince(lastTimeStampSpentMovingAwayFromStart) > MaxSecondsSpentTravelingAwayFromStartOfRoute else {
                lastUserDistanceToStartOfRoute = userSnappedDistanceToClosestCoordinate
                return snapToPathLocation
            }
            // 不用檢查 `isLocation` 如果 已經移動
            guard userSnappedDistanceToClosestCoordinate != lastUserDistanceToStartOfRoute else {
                lastUserDistanceToStartOfRoute = userSnappedDistanceToClosestCoordinate
                dPrint("update lastUserDistanceToStartOfRoute = \(lastUserDistanceToStartOfRoute)")
                return snapToPathLocation
            }
            if userSnappedDistanceToClosestCoordinate > lastUserDistanceToStartOfRoute {
                lastTimeStampSpentMovingAwayFromStart = location.timestamp
                dPrint("[提醒] 離出發地越來越遠 update lastTimeStampSpentMovingAwayFromStart = \(lastTimeStampSpentMovingAwayFromStart)")
                notifyDeviateFromRoute(stepIndex: 0)
            }
            lastUserDistanceToStartOfRoute = userSnappedDistanceToClosestCoordinate
        }
        //
        guard isLocation(location, onRouteStep: currentStep) else {
            var maybeDeviate = true
            // 如果不在 currentStep 之上，尋找最接近的 step
            let closetStep = findClosestStepInCurrentLeg(location: location)
            if let closetStepCoord = closetStep.coordinateAlongPolyline {
                dPrint("SNAP to Closest Step \(closetStep.index) Coordinate = \(closetStepCoord.coordinate.latitude), \(closetStepCoord.coordinate.longitude)  Distance = \(closetStepCoord.distance)")
                
                if closetStep.index > currentStepIndex {
                    // 在 current Step 之後
                    if closetStepCoord.distance <= AcceptedDeviationDistance
                        && closetStepCoord.distance < closestCoord!.distance
                    {
                        snapToPathLocation = CLLocation(coordinate: closetStepCoord.coordinate,
                                                        altitude: location.altitude,
                                                        horizontalAccuracy: location.horizontalAccuracy,
                                                        verticalAccuracy: location.verticalAccuracy,
                                                        course: location.course,
                                                        speed: location.speed,
                                                        timestamp: location.timestamp)
                        
                        // 比current Step近，而且小於　偏離距離１０m
                        updateCurrentStepIndex(closetStep.index)
                        if didDeviateFromRouteStepIndex > -1 {
                            dPrint("[提醒] B 回到 導航路線 : \(closetStep.index)")
                            notifyBackToRoute()
                        }
                        maybeDeviate = false
                    }
                } else if closetStep.index == currentStepIndex {
                    // 是current Step 呀？
                    maybeDeviate = false    // 如果不設為 false，很容易在轉彎處 判斷成 偏離
                }
            }
            if maybeDeviate {
                dPrint("[提醒] A 偏離 導航路線 : \(currentStepIndex)")  // 這裡的機率太高
                notifyDeviateFromRoute(stepIndex: currentStepIndex)
            }
            return snapToPathLocation
        }
        //if didDeviateFromRouteStepIndex > -1 {
            //dPrint("[提醒] 回到 導航路線 : \(currentStepIndex)")
            //notifyBackToRoute()
        //}
        monitorProgress(currentLeg: currentLeg, location: location, distanceToNextManeuver: distanceToNextManeuver)
        // -------
        preDistanceToNextManeuver = distanceToNextManeuver
        return snapToPathLocation
    }
    //
    func monitorProgress(currentLeg: RouteLeg, location: CLLocation, distanceToNextManeuver: CLLocationDistance) {
        dPrint("monitorStepProgress")
        let currentStep = currentLeg.steps[currentStepIndex]
        // Force an announcement when the user begins a route
        var alertLevel: AlertLevel = currentLeg.alertUserLevel == .none ? .depart : currentLeg.alertUserLevel
        var updateStepIndex = false
        // 使用者離 current Step的最近距離
        //let distanceToNextManeuver = distance(along: currentStep.coordinates, from: location.coordinate)
        let secondsToEndOfStep = distanceToNextManeuver / location.speed
        // 是否有轉到正確的道路上
        var courseMatchesManeuverFinalHeading = false
        
        // Bearings need to normalized so when the `finalHeading` is 359 and the user heading is 1,
        // we count this as within the `MaximumAllowedDegreeOffsetForTurnCompletion`
        let nextStep = getNextRouteStep()
        if nextStep != nil && nextStep!.maneuver != .destination {  // 目的地不需要check
            // currentStep 的離開方向
            let departureCurrentStepDirection = currentStep.getDepartureDirection()
            // nextStep 的進入方向
            let entryNextStepDirection = nextStep!.getEntryDirection()
            // 預期要轉彎的方向 (兩個線段夾角)
            let expectedTurningAngle = differenceBetweenAngles(departureCurrentStepDirection, entryNextStepDirection)
            // 使用者的航向
            let userHeadingNormalized = wrap(location.course, min: 0, max: 360)
            // 如果 next step 的 maneuver 預期轉彎角度 - 相當"直"，不要check 離開時的角度
            if expectedTurningAngle <= MaximumAllowedDegreeOffsetForTurnCompletion {
                // 像 ramp(斜坡)的方向一般很接近離開 current Step時的航向，需要等它離開maneuver的位置
                courseMatchesManeuverFinalHeading = distanceToNextManeuver == 0
            } else {
                //
                courseMatchesManeuverFinalHeading = differenceBetweenAngles(entryNextStepDirection, userHeadingNormalized) <= MaximumAllowedDegreeOffsetForTurnCompletion
            }
        }

        // 出發時，通常會在提示區內
        if alertLevel == .depart && distanceToNextManeuver <= ManeuverZoneRadius {
            // If the user is close to the maneuver location,
            // don't give a depature instruction.
            // Instead, give a `.high` alert.
            if secondsToEndOfStep <= HighAlertInterval {
                alertLevel = .high
                dPrint("alertLevel == .depart => .high")
            }
        } else if distanceToNextManeuver <= ManeuverZoneRadius {
            // 如果沒有 next Step 就用 current step
            var step = currentStep
            if nextStep != nil {
                step = nextStep!
            }
            let endLocation = step.end_location
            let userAbsoluteDistance = endLocation! - location.coordinate
            
            if userDistanceToManeuverLocation == nil {
                userDistanceToManeuverLocation = ManeuverZoneRadius
            }
            
            let lastKnownUserAbsoluteDistance = userDistanceToManeuverLocation
            if  userAbsoluteDistance <= lastKnownUserAbsoluteDistance! {
                userDistanceToManeuverLocation = userAbsoluteDistance
            }
            
            dPrint("userAbsoluteDistance = \(userAbsoluteDistance)")
            dPrint("userDistanceToManeuverLocation = \(userDistanceToManeuverLocation!)")
            if nextStep != nil {
                if nextStep!.maneuver == .destination {
                    alertLevel = .arrive
                } else if courseMatchesManeuverFinalHeading {
                    updateStepIndex = true
                    alertLevel = TimeInterval(nextStep!.durationSec) <= MediumAlertInterval ? .medium : .low
                } else {
                    // 當"轉彎角度判別" 無法跳到下一步時，就用 兩step的最近距離來處理
//                    let current = closestCoordinate(on: currentStep.coordinates, to: location.coordinate)
//                    let next = closestCoordinate(on: nextStep!.coordinates, to: location.coordinate)
//                    if current != nil && next != nil && next!.distance < current!.distance {
//                        updateStepIndex = true
//                        dPrint("currentStepIndex = \(currentStepIndex) 強迫 跳下個 Step!!")
//                    }
                }
            }
        } else if secondsToEndOfStep <= HighAlertInterval && distanceToNextManeuver > MinimumDistanceForHighAlert {
            dPrint("alertLevel =>   high  Speed = \(location.speed) secondsToEndOfStep = \(secondsToEndOfStep)  distance = \(distanceToNextManeuver)")
            alertLevel = .high
        } else if secondsToEndOfStep <= MediumAlertInterval && distanceToNextManeuver > MinimumDistanceForMediumAlert {
            dPrint("alertLevel => medium  Speed = \(location.speed) secondsToEndOfStep = \(secondsToEndOfStep)  distance = \(distanceToNextManeuver)")
            alertLevel = .medium
        }
        incrementRouteProgress(alertLevel, location: location, updateStepIndex: updateStepIndex)
    }
    // 處理 導航進度 - currentStepIndex 增加
    func incrementRouteProgress(_ newlyCalculatedAlertLevel: AlertLevel, location: CLLocation, updateStepIndex: Bool) {
        guard let routePlan = mapVC.mRoutePlan else {
            dPrint("mapVC.mRoutePlan is nil")
            return
        }

        if updateStepIndex {
            updateCurrentStepIndex(currentStepIndex + 1)
        }
        
        let currentLeg = routePlan.legs[currentLegIndex]
        // If the step is not being updated, don't accept a lower alert level.
        // A lower alert level can only occur when the user begins the next step.
        guard newlyCalculatedAlertLevel.rawValue > currentLeg.alertUserLevel.rawValue || updateStepIndex else {
            return
        }
        if currentLeg.alertUserLevel != newlyCalculatedAlertLevel {
            currentLeg.alertUserLevel = newlyCalculatedAlertLevel
            
            let currentStep = currentLeg.steps[currentStepIndex]
            var distanceToNext = distance(along: currentStep.coordinates, from: location.coordinate)
            
            // [語音提示] - NaviAlertLevelDidChange
            if let nextStep = getNextRouteStep() {
                if distanceToNext == 0 && updateStepIndex {
                    distanceToNext = CLLocationDistance(nextStep.distanceM)
                }
                var moreStep: RouteStep? = nil
                dPrint("NaviAlertLevelDidChange : AlertLevel = \(newlyCalculatedAlertLevel)  distanceToNext = \(distanceToNext)")
                if currentStep.maneuver != .origin && nextStep.distanceM < 80/* && newlyCalculatedAlertLevel == .high*/ {
                    moreStep = getRouteStepInCurrentLeg(index: currentStepIndex + 2)
                    if moreStep != nil {
                        dPrint("將更後面的提示 附帶上去：\(moreStep!.instructions!)  Distance = \(nextStep.distanceM)")
                    }
                }
                // TTS & 背景提示都會收到
                notifyNaviAlert(currentLeg.alertUserLevel, distance: distanceToNext,
                                nextStep: nextStep, moreStep: moreStep)
            }
        }
    }
    
    func updateCurrentStepIndex(_ index:Int) {
        guard let routePlan = mapVC.mRoutePlan else {
            dPrint("mapVC.mRoutePlan is nil")
            return
        }
        dPrint("-------------- updateStepIndex ---------------")
        dPrint("先前的 Step DistanceTraveled = \(currentStepDistanceTraveled)")
        currentStepIndex = index
        currentStepDistanceTraveled = 0
        preDistanceToNextManeuver = 0
        userDistanceToManeuverLocation = nil
        dPrint("currentStepIndex = \(currentStepIndex)")
        // 算出剩下多少距離 (不含 current Step)
        mAfterCurrentStepEstimateRemainingDistanceM = mapVC.estimateRemainingDistance(leg: routePlan.legs[0], fromStepIndex: index + 1)
        //mAfterCurrentStepEstimateRemainingDurationSec = totalDurationSec
        dPrint("Estimate Remaining DistanceM = \(mAfterCurrentStepEstimateRemainingDistanceM)")
    }
    // 判斷使用者座標是否在目前的Step上
    // (廢棄) => 如果比較靠近下個 Step，就會跳往下個 Step
    public func isLocation(_ location: CLLocation, onRouteStep step: RouteStep) -> Bool {
        // Find future location of user
        let metersInFrontOfUser = location.speed * DeadReckoningTimeInterval
        let locationInfrontOfUser = location.coordinate.coordinate(at: metersInFrontOfUser, facing: location.course)
        let newLocation = CLLocation(latitude: locationInfrontOfUser.latitude, longitude: locationInfrontOfUser.longitude)
        let radius = max(MaximumDistanceDeviationFromPath,
                         location.horizontalAccuracy + AcceptedDeviationDistance)
        return newLocation.isWithin(radius, of: step)
    }
    // -----
    func getNextRouteStep() -> RouteStep? {
        return getRouteStepInCurrentLeg(index: currentStepIndex + 1)
    }
    
    func getRouteStepInCurrentLeg(index:Int) -> RouteStep? {
        guard let routePlan = mapVC.mRoutePlan else {
            dPrint("mapVC.mRoutePlan is nil")
            return nil
        }
        let currentLeg = routePlan.legs[currentLegIndex]
        guard index >= 0 && index < currentLeg.steps.endIndex else {
            return nil
        }
        return currentLeg.steps[index]
    }
    // ============== Simulation ==============
    var simuLocationManager:SimulatedLocationManager? = nil
    // 開始 模擬導航
    func startNaviSimulation(routePlan: RoutePlan) {
        if mapVC.mLocationManager != nil {
            mapVC.stopLocationManager(mapVC.mLocationManager!)
        }
        // GPS 座標模擬
        simuLocationManager = SimulatedLocationManager(routePlan: routePlan)
        mapVC.mLocationManager = simuLocationManager
        mapVC.mLocationManager?.delegate = mapVC
    }
    // 停止 模擬導航
    func stopNaviSimulation() {
        if mapVC.mLocationManager != nil {
            mapVC.stopLocationManager(mapVC.mLocationManager!)
            simuLocationManager = nil
        }
        mapVC.mLocationManager = mapVC.mGpsLocationManager
        mapVC.startLocationManager(mapVC.mGpsLocationManager)
    }
}
