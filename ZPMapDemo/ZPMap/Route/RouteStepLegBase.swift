//
//  RouteStepLegBase.swift
//
//  Created by EddieHua.
//

import Foundation
import SwiftyJSON
import GoogleMaps


public class RouteStepLegBase : RouteBase {
    // ---- navigation 使用 ----
    var alertUserLevel: AlertLevel = .none
    
    // TODO: 補充訊息 (跟原本的 json 內容無關)，如果有字串的話，就給 detailLable 顯示。例如 目的地可以顯示地址
    var otherMessage:String? = nil
    
    // 線段起迄點
    var start_location:CLLocationCoordinate2D! = nil
    var end_location:CLLocationCoordinate2D! = nil
    
    // 分段 總距離
    var distanceM:Int = 0           // distance - value : 固定單位 m
    var distanceText:String = ""    // distance - text  : 在地化文字訊息 (可用 UnitSystem 參數改變)
    // 分段 總時間長度
    var durationSec: Int = 0        // duration - value : (秒)
    var durationText: String = ""   // duration - text : 字串方式呈現的時間長度
    
    func parseCommonPart(_ json:JSON) {
        // ---- Step, Leg 都有的部份 ----
        start_location = RouteBase.parseLocationCoordinate2D(json["start_location"].dictionary)
        end_location = RouteBase.parseLocationCoordinate2D(json["end_location"].dictionary)
        
        // 距離
        let distanceDict = json["distance"].dictionary
        distanceM = (distanceDict?["value"]?.int)!
        distanceText = (distanceDict?["text"]?.string)!
        
        // 時間
        let durationDict = json["duration"].dictionary
        durationSec = (durationDict?["value"]?.int)!
        durationText = (durationDict?["text"]?.string)!
    }
}
