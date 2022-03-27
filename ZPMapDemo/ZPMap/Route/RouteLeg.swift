//
//  RouteLeg.swift
//
//  Created by EddieHua.
//

import Foundation
import SwiftyJSON
import GoogleMaps

// 定義計算路線中從起點到目的地的一段旅程。
// 一或多個途經地點的路線，該路線會包含一或多個分段
public class RouteLeg : RouteStepLegBase {
    var start_address: String = ""
    var end_address: String = ""
    
    // 行程分段每一步驟的資訊
    var steps:[RouteStep] = [RouteStep]();
    
    class func create(json:JSON) -> RouteLeg {
        let Leg = RouteLeg()
        // 處理共用的部份：距離、時間、起迄點
        Leg.parseCommonPart(json)
        // 起點地址
        Leg.start_address = json["start_address"].stringValue
        // 終點地址
        Leg.end_address = json["end_address"].stringValue
        // Steps
        let stepsArray = json["steps"].array
        if stepsArray != nil {
            for stepJson in stepsArray! {
                let step = RouteStep.create(json:stepJson)
                Leg.steps.append(step)
            }
        } else {
            dPrint("沒有 Steps!")
        }
        return Leg
    }
}
