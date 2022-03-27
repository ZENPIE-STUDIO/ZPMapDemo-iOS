//
//  SimulatedLocationManager.swift
//
//  Created by EddieHua.
//

import UIKit
import CoreLocation

fileprivate let FireTimeInterval = 0.7

fileprivate let maximumSpeed: CLLocationSpeed = 25
fileprivate let minimumSpeed: CLLocationSpeed = 5
fileprivate var verticalAccuracy: CLLocationAccuracy = 40
fileprivate var horizontalAccuracy: CLLocationAccuracy = 40
// minimumSpeed will be used when a location have maximumTurnPenalty
fileprivate let maximumTurnPenalty: CLLocationDirection = 90
// maximumSpeed will be used when a location have minimumTurnPenalty
fileprivate let minimumTurnPenalty: CLLocationDirection = 0
// Go maximum speed if distance to nearest coordinate is >= `safeDistance`
fileprivate let safeDistance: CLLocationDistance = 50

fileprivate let baseMoveDistance:CLLocationDistance = 0.000002  // 公尺
// ======================== 使用方向鍵來控制 GPS 座標 ========================
class DPadSimuLocationManager: CLLocationManager {
    fileprivate var mCoordinate = CLLocationCoordinate2D()
    fileprivate var mSpeed: CLLocationSpeed = 5
    fileprivate var mCourse: CLLocationDirection = 0
    fileprivate var mForwardTimeIntervalSince1970:TimeInterval = 0
    fileprivate var mBackwardTimeIntervalSince1970:TimeInterval = 0
    fileprivate var mTurnTimeIntervalSince1970:TimeInterval = 0
    
    public init(coordinate: CLLocationCoordinate2D) {
        super.init()
        mCoordinate = coordinate
        updateLocation(0)
    }
    // 如何決定前進的幅度 - 長按 button 時，連續呼叫 - speed 就會變快
    func forward() {
        if mBackwardTimeIntervalSince1970 > 0 {
            mSpeed = 5
            mBackwardTimeIntervalSince1970 = 0
        }
        
        let forwardTimeIntervalSince1970 = NSDate().timeIntervalSince1970
        if (forwardTimeIntervalSince1970 - mForwardTimeIntervalSince1970) < FireTimeInterval {
            // 時間間隔短 - 加速
            mSpeed += 0.5
        }
        mForwardTimeIntervalSince1970 = forwardTimeIntervalSince1970
        let distance = mSpeed * baseMoveDistance
        //dPrint("DPad forward > Speed = \(mSpeed)  distance = \(distance)")
        updateLocation(distance)
    }
    func backward() {
        if mForwardTimeIntervalSince1970 > 0 {
            mSpeed = 5
            mForwardTimeIntervalSince1970 = 0
        }
        let backwardTimeIntervalSince1970 = NSDate().timeIntervalSince1970
        if (backwardTimeIntervalSince1970 - mBackwardTimeIntervalSince1970) < FireTimeInterval {
            // 時間間隔短 - 加速
            mSpeed += 0.5
        }
        mBackwardTimeIntervalSince1970 = backwardTimeIntervalSince1970
        let distance = -(mSpeed * baseMoveDistance)
        //dPrint("DPad backward > Speed = \(mSpeed)  distance = \(distance)")
        updateLocation(distance)
    }
    func turnRight() {
        let turnTimeIntervalSince1970 = NSDate().timeIntervalSince1970
        if (turnTimeIntervalSince1970 - mTurnTimeIntervalSince1970) < FireTimeInterval {
            // 時間間隔短
            mCourse += 8
        } else {
            mCourse += 2
        }
        mTurnTimeIntervalSince1970 = turnTimeIntervalSince1970
        //dPrint("DPad turnRight > Course = \(mCourse)")
        updateLocation(0)  // 移動一點點
    }
    
    func turnLeft() {
        let turnTimeIntervalSince1970 = NSDate().timeIntervalSince1970
        if (turnTimeIntervalSince1970 - mTurnTimeIntervalSince1970) < FireTimeInterval {
            // 時間間隔短
            mCourse -= 8
        } else {
            mCourse -= 2
        }
        mTurnTimeIntervalSince1970 = turnTimeIntervalSince1970
        //dPrint("DPad turnLeft > Course = \(mCourse)")
        updateLocation(0)  // 移動一點點
    }
    
    func updateLocation(_ moveDistance:CLLocationDistance) {
        var newCoordinate = CLLocationCoordinate2D()
        let radCourse = mCourse * Double.pi / 180
        // 緯度 -90 ~ 0 ~ 90
        newCoordinate.latitude = mCoordinate.latitude + moveDistance * cos(radCourse)
        // 經度 -180 ~ 0 ~ 180
        newCoordinate.longitude = mCoordinate.longitude + moveDistance * sin(radCourse)
        //dPrint("Coordinate Old \(mCoordinate.latitude), \(mCoordinate.longitude) => New \(newCoordinate.latitude), \(newCoordinate.longitude)")
        let location = CLLocation(coordinate: newCoordinate,
                                     altitude: 0,
                                     horizontalAccuracy: horizontalAccuracy,
                                     verticalAccuracy: verticalAccuracy,
                                     course: mCourse,
                                     speed: mSpeed,
                                     timestamp: Date())
        //DispatchQueue.main.async { [weak self] in
            delegate?.locationManager?(self, didUpdateLocations: [location])
        //}
        mCoordinate = newCoordinate
    }
}

// ======================= 利用規劃路徑來模擬 GPS 座標 ===============================

fileprivate class SimulatedLocation: CLLocation {
    var turnPenalty: Double = 0
    
    override var description: String {
        return "\(super.description) \(turnPenalty)"
    }
}

class SimulatedLocationManager: CLLocationManager {
    fileprivate var currentDistance: CLLocationDistance = 0
    fileprivate var currentLocation = CLLocation()
    fileprivate var currentSpeed: CLLocationSpeed = 20
    
    fileprivate var locations: [SimulatedLocation]!
    fileprivate var routeLine = [CLLocationCoordinate2D]()  // 路線 座標點
    
    var routePlan: RoutePlan? {
        didSet {
            reset()
        }
    }
    
    public init(routePlan: RoutePlan) {
        super.init()
        self.routePlan = routePlan
        reset()
        //NotificationCenter.default.addObserver(self, selector: #selector(didReroute(notification:)), name: RouteControllerDidReroute, object: nil)
    }
    
    func reset() {
        if let coordinates = routePlan?.coordinates {
            routeLine = coordinates
            locations = coordinates.simulatedLocationsWithTurnPenalties()
            currentDistance = 0
            currentSpeed = 20
            // 等一下再開始
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.startUpdatingLocation()
            }
        }
    }
    
    deinit {
    }
    
    override public func startUpdatingLocation() {
        tick()
    }
    
    override public func stopUpdatingLocation() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(tick), object: nil)
    }
    
    @objc fileprivate func tick() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(tick), object: nil)
        
        guard let newCoordinate = coordinate(at: currentDistance, fromStartOf: routeLine) else {
            return
        }
        
        // Closest coordinate ahead
        guard let lookAheadCoordinate = coordinate(at: currentDistance + 20, fromStartOf: routeLine) else { return }
        guard let closestCoordinate = closestCoordinate(on: routeLine, to: newCoordinate) else { return }
        
        let closestLocation = locations[closestCoordinate.index]
        let distanceToClosest:CLLocationDistance = 0 // closestLocation.distance(from: CLLocation(newCoordinate))
        
        let distance = min(max(distanceToClosest, 10), safeDistance)
        let coordinatesNearby = polyline(along: routeLine, within: 100, of: newCoordinate)
        
        // 很多的點-表示在彎彎的道路(像山路) - 開慢一點
        if coordinatesNearby.count >= 10
        {
            currentSpeed = minimumSpeed
            //dPrint("currentSpeed = minimumSpeed = \(minimumSpeed)")
        }
        // Maximum speed if we are a safe distance from the closest coordinate
        else if distance >= safeDistance
        {
            currentSpeed = maximumSpeed
            //dPrint("currentSpeed = maximumSpeed = \(maximumSpeed)")
        }
            // Base speed on previous or upcoming turn penalty
        else {
            let reversedTurnPenalty = maximumTurnPenalty - closestLocation.turnPenalty
            // minimun TurnPenalty = 0 (全速)
            currentSpeed = reversedTurnPenalty.scale(minimumIn: minimumTurnPenalty, maximumIn: maximumTurnPenalty, minimumOut: minimumSpeed, maximumOut: maximumSpeed)
            //dPrint("currentSpeed = \(currentSpeed)   closestLocation.turnPenalty = \(closestLocation.turnPenalty)")
        }
        
        currentLocation = CLLocation(coordinate: newCoordinate,
                                     altitude: 0,
                                     horizontalAccuracy: horizontalAccuracy,
                                     verticalAccuracy: verticalAccuracy,
                                     course: wrap(floor(newCoordinate.direction(to: lookAheadCoordinate)), min: 0, max: 360),
                                     speed: currentSpeed,
                                     timestamp: Date())
        
        delegate?.locationManager?(self, didUpdateLocations: [currentLocation])
        currentDistance += currentSpeed
        perform(#selector(tick), with: nil, afterDelay: 0.95)
    }
}


extension Double {
    fileprivate func scale(minimumIn: Double, maximumIn: Double, minimumOut: Double, maximumOut: Double) -> Double {
        return ((maximumOut - minimumOut) * (self - minimumIn) / (maximumIn - minimumIn)) + minimumOut
    }
}

extension CLLocation {
    fileprivate convenience init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension Array where Element == CLLocationCoordinate2D {
    
    // TODO: 應該按照"行進距離" 來產生 location 座標，不然 polyline 線段長短會影響行進長短
    // 不然就是要依長短來決定 animate 時間
    fileprivate func simulatedLocationsWithTurnPenalties() -> [SimulatedLocation] {
        var locations = [SimulatedLocation]()
        
//        dPrint("SELF > \(self)")
//        dPrint("prefix > \(prefix(upTo: endIndex - 1))")
//        dPrint("suffix > \(suffix(from: 1))")
//        dPrint("zip > \(zip(prefix(upTo: endIndex - 1), suffix(from: 1)))")
        
        var preTurnPenalty:Double = 90
        var preCourse:CLLocationDirection = -1000
        // 這種寫法 - 是利用 函數式編程的特性；
        // 其實就是等同於 for loop 取 pt0-pt1 ; pt1-pt2 的意思
        for (coordinate, nextCoordinate) in zip(prefix(upTo: endIndex - 1), suffix(from: 1)) {
            //let currentCoordinate = locations.isEmpty ? first! : coordinate
            // 線段方向
            let course: CLLocationDirection = wrap(floor(coordinate.direction(to: nextCoordinate)), min: 0, max: 360)
            let location = SimulatedLocation(coordinate: coordinate,
                                             altitude: 0,
                                             horizontalAccuracy: horizontalAccuracy,
                                             verticalAccuracy: verticalAccuracy,
                                             course: course,
                                             speed: minimumSpeed,
                                             timestamp: Date())
            
            var turnPenalty:Double = maximumTurnPenalty // 起步慢
            if preCourse > -1000 {
                turnPenalty = floor(differenceBetweenAngles(preCourse, course))
            }
            //dPrint("turnPenalty = \(turnPenalty)")
            preCourse = course
            //if turnPenalty > 50 {   // 一次
                location.turnPenalty = Swift.max(Swift.min((turnPenalty + preTurnPenalty) / 2, maximumTurnPenalty), minimumTurnPenalty)
            //} else {
                //location.turnPenalty = Swift.max(Swift.min(turnPenalty, maximumTurnPenalty), minimumTurnPenalty)
            //}
            preTurnPenalty = turnPenalty
            //dPrint("location = \(location)")
            locations.append(location)
        }
        
        locations.append(SimulatedLocation(coordinate: last!,
                                           altitude: 0,
                                           horizontalAccuracy: horizontalAccuracy,
                                           verticalAccuracy: verticalAccuracy,
                                           course: locations.last!.course,
                                           speed: minimumSpeed,
                                           timestamp: Date()))
        
        return locations
    }
}
