//
//  RouteStep.swift
//
//  Created by EddieHua.
//

import Foundation
import GoogleMaps
import SwiftyJSON

/* maneuver
 turn-right
 fork-left          // 岔路靠左
 turn-slight-left   // 稍微向左轉
 ramp-left          // 下左側出口
 straight   // 繼續直行
 */

// 規劃路線時的最小單位
public class RouteStep : RouteStepLegBase {
    // 步驟的文字字串指示
    var attrInstructions:NSAttributedString?    // 指示訊息 (由html_instructions 轉過來的) - UILabel的font size無用
    
    // 純文字(去除 html tag)，TTS 也要用。目的地可以考慮 "抵達 {目的地名稱}"
    var instructions:String?
    
    var travel_mode: String = ""    // travel_mode: DRIVING, CYCLING...
    var maneuver: RouteManeuver = .none       // 轉彎提示-影響要顯示的圖示，不一定都有
    
    // 模擬時取點、 判斷是否在路徑上
    var coordinates = [CLLocationCoordinate2D]()  // 路徑上的所有座標 CLLocationCoordinate2D
    var polyline:GMSPolyline? = nil     // 用來畫精細的路線
    
    // polyline 編碼折線處理 - https://github.com/raphaelmor/Polyline
    class func create(json:JSON) -> RouteStep {
        let Step = RouteStep()
        // ---- Step, Leg 都有的部份 ----
        Step.parseCommonPart(json)
        // 自己的部份
        let strHtml = json["html_instructions"].stringValue
        Step.attrInstructions = RouteStep.htmlToAttributedString(strHtml, fontSize: 22)
        Step.instructions = RouteStep.replaceHtmlTag(strHtml)
        Step.travel_mode = json["travel_mode"].stringValue
        Step.maneuver = RouteManeuver(google:json["maneuver"].stringValue)
        
        // ----------------------------
        let stepPolyline = json["polyline"].dictionary
        let encodedPoints = stepPolyline?["points"]?.stringValue
        
        if let path = GMSPath.init(fromEncodedPath: encodedPoints!) {
            Step.polyline = GMSPolyline.init(path: path)
            for i in 0..<path.count() {
                Step.coordinates.append(path.coordinate(at: i))
                //dPrint("\(Step.path.coordinate(at: i))")
            }
        }
        return Step
    }
    
    func showPolylineInMap(_ mapView:GMSMapView) {
        if polyline != nil {
            polyline!.strokeWidth = 6
            polyline!.strokeColor = ZPMapCommon.appearance.mainColor
            polyline!.map = mapView
        }
    }
    func hidePolyline() {
        polyline?.map = nil
    }
    
    // 計算Step 的進入方向
    func getEntryDirection() -> CLLocationDirection {
        if coordinates.count > 2 {
            // 第0, 1 點
            return wrap(floor(coordinates[0].direction(to: coordinates[1])), min: 0, max: 360)
        }
        return 0
    }
    // 計算Step 的離開方向
    func getDepartureDirection() -> CLLocationDirection {
        if coordinates.count > 2 {
            // 第 last - 1, last
            let lastIdx = coordinates.count - 1
            return wrap(floor(coordinates[lastIdx-1].direction(to: coordinates[lastIdx])), min: 0, max: 360)
        }
        return 0
    }
    // 將 html string 轉為 Attributed String
    internal class func htmlToAttributedString(_ strHtml:String, fontSize:CGFloat) -> NSAttributedString? {
        //        let htmlAttrs = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType] - 這個中文會有問題
        let modifiedFont = NSString(format:"<span style=\"font-family: '-apple-system', 'HelveticaNeue'; font-size: \(fontSize)\">%@</span>" as NSString, strHtml) as String
        
        let htmlAttrs = [NSAttributedString.DocumentReadingOptionKey.documentType : NSAttributedString.DocumentType.html,
                         NSAttributedString.DocumentReadingOptionKey.characterEncoding : String.Encoding.utf8.rawValue] as [NSAttributedString.DocumentReadingOptionKey : Any]
        var attrString:NSAttributedString? = nil
        do {
            try attrString = NSAttributedString(data: modifiedFont.data(using: .utf8)!, options:htmlAttrs, documentAttributes: nil)
        } catch {
            dPrint("error creating HTML from Attributed String")
        }
        return attrString
    }
    // 移除 html tag - 為了 TTS
    internal class func replaceHtmlTag(_ strHtml:String) -> String {
        return strHtml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}
