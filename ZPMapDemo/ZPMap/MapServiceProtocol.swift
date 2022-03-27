//
//  MapServiceProtocol.swift
//
//  Created by EddieHua.
//

import Foundation
import CoreLocation
import Alamofire
import SwiftyJSON


protocol MapService {
    // 路徑規劃
    static func route(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, ifFailedTryAgain:Bool, completion: @escaping (_ routePlan: RoutePlan?, _ errMsg: String?) -> Void)
    
    // 搜尋Place - 使用 autocomplete
    static func searchPlaceAutoComplete(text: String, location: CLLocationCoordinate2D, completion: @escaping (_ places: [AutoCompletePlace], _ errMsg: String?) -> Void)
    // 搜尋 Place - 使用 type (例如：food, Lodging…)
    static func searchPlacesType(_ type: String, location: CLLocationCoordinate2D, completion: @escaping (_ places: [Place], _ errMsg: String?) -> Void)
    // 取得 Place 詳細資料
    static func getPlaceDetail(_ placeId: String, completion: @escaping (_ place:Place?, _ errMsg: String?) -> Void)
}

fileprivate let OK = "OK"
fileprivate let STATUS = "status"
fileprivate let ZERO_RESULTS = "ZERO_RESULTS"
// Google Map API
class GoogleMapService : MapService {
//    class ZpJsonResponse : Codable {
//        var stateCode: Int?
//        var message: String?
//    }
    //struct DecodableJSON: Decodable { let json: String }
    // 第一次 tryAgain = true, mode = "bicycling"  - 常常會規劃不出結果
    // 第二次 tryAgain = false, mode = "driving" - (已知缺點：不會走最短路徑)
    // PS. 用walking的話，有時會走逆向道路
    // https://maps.googleapis.com/maps/api/directions/json?origin=Disneyland&destination=Universal+Studios+Hollywood&key=YOUR_API_KEY
    static func route(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, ifFailedTryAgain: Bool, completion: @escaping (_ routePlan: RoutePlan?, _ errMsg: String?) -> Void) {
        let mode = ifFailedTryAgain ? "bicycling" : "driving"
        let strOrigin = "\(origin.latitude),\(origin.longitude)"
        let strDestination = "\(destination.latitude),\(destination.longitude)"
        var url = "https://maps.googleapis.com/maps/api/directions/json?origin=\(strOrigin)&destination=\(strDestination)&mode=\(mode)&avoid=highways"
        url += "&key=" + GOOGLEMAP_API_KEY
        dPrint("route - \(mode) : \(origin) -> \(destination)")

        
        //debugPrint(" \(url)")
        //AF.request(url).responseDecodable(of: DecodableJSON.self) { response in
            //debugPrint("JSON > \(response)")
        AF.request(url).responseJSON { response in
            var routePlan:RoutePlan? = nil
            var errMsg: String? = response.error?.localizedDescription
            var json: JSON? = nil
            do {
                json = try JSON(data: response.data!)
            } catch let parseError {
                dPrint("JSON Error \(parseError.localizedDescription)")
            }
            //dPrint("JSON > \(json.description)")
            let status = json?[STATUS].stringValue
            // 通常 mode=bicycling 很容易得到 "沒結果"
            if status == ZERO_RESULTS && ifFailedTryAgain {
                // 會回傳 "available_travel_modes" : ["DRIVING", "WALKING", "TRANSIT"]
                // TODO: 不要在 main 裡呼叫
                let SerialQueue: DispatchQueue = DispatchQueue(label: "routeRetrySerial.HyMap")
                SerialQueue.asyncAfter(deadline: .now() + 0.5) {
                    self.route(origin: origin, destination: destination, ifFailedTryAgain:false, completion: completion)
                }
            } else if status == OK {
                let routes = json?["routes"].arrayValue
                // 一般而言只會傳回 routes 陣列中的一個項目，如果傳送 alternatives=true，路線規劃服務可能會傳回數條路線。
                if (routes != nil && routes!.count > 0)
                {
                    // print route using Polyline
                    routePlan = RoutePlan.create(json: routes![0])
                }
                DispatchQueue.main.async {
                    completion(routePlan, nil)
                }
            } else {
                dPrint("route failed status : \(String(describing: status))")
                errMsg = status
                DispatchQueue.main.async {
                    completion(routePlan, errMsg)
                }
            }
        }
    }
    // 【錯誤碼】
    // ZERO_RESULTS 指出無法在起點與目的地之間找到任何路線。
    // NOT_FOUND 指出要求的起點、目的地或途經地點中，至少有一個位置無法進行地理編碼。
    // MAX_WAYPOINTS_EXCEEDED 指出要求中提供過多的 waypoints。針對將 Google Maps Directions API 做為 Web 服務使用的應用程式，或使用 Google Maps JavaScript API 中路線規劃服務的應用程式，允許的 waypoints 數目上限是 23，加上起點與目的地。Google Maps APIs Premium Plan 客戶可以提交最多具有 23 個途經地點的要求，加上起點與目的地。
    // INVALID_REQUEST 指出提供的要求無效。出現此狀態的常見原因包括參數或參數值無效。
    // OVER_QUERY_LIMIT 指出服務在允許的期間內從您應用程式接收到過多要求。
    // REQUEST_DENIED 指出服務拒絕使用您應用程式提供的路線規劃服務。
    // UNKNOWN_ERROR 指出由於發生伺服器錯誤，而無法處理路線規劃要求。重新嘗試該要求或許會成功。
    // ======================== Auto Complete ============================
    // 成功回傳：[AutoCompletePlace]
    // 失敗回傳： Error
    static func searchPlaceAutoComplete(text: String, location: CLLocationCoordinate2D, completion: @escaping (_ places: [AutoCompletePlace], _ errMsg: String?) -> Void) {
        var url = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=" + text
        url += String(format: "&location=%f,%f", location.latitude, location.longitude)
        let preferredLanguage = NSLocale.preferredLanguages[0]
        url += "&language=" + preferredLanguage
        url += "&radius=50000"
        url += "&strickbounds"
        url += "&key=" + GOOGLEMAP_API_KEY
        dPrint("searchAutoCompletePlaces > \(url)")
        
        //AF.request(url).responseDecodable(of: DecodableJSON.self) { response in
            //debugPrint("JSON > \(response)")
        AF.request(url).responseJSON { response in
            var autoCompletePlaces = [AutoCompletePlace]()
            var errMsg: String? = response.error?.localizedDescription
            if let data = response.data {
                var json: JSON? = nil
                do {
                    json = try JSON(data: data)
                } catch let parseError {
                    dPrint("JSON Error \(parseError.localizedDescription)")
                }
                
                //dPrint("JSON > \(json.description)")
                let status = json?[STATUS].stringValue
                if status == OK {
                    let predictions = json?["predictions"].arrayValue
                    if (predictions != nil) {
                        for prediction in predictions! {
                            if let place = AutoCompletePlace.create(json: prediction) {
                                autoCompletePlaces.append(place)
                            }
                        }
                    }
                } else {
                    // status : ZERO_RESULTS (找不到)
                    errMsg = status
                    dPrint("status = \(String(describing: status))")
                }
            }
            completion(autoCompletePlaces, errMsg)
        }
    }
    
    // radius=2000 (單位是公尺)
    // https://maps.googleapis.com/maps/api/place/nearbysearch/json?radius=1500&location=24.135124,120.657893&types=food&language=zh-TW&key=YOUR_API_KEY
    static func searchPlacesType(_ type: String, location: CLLocationCoordinate2D, completion: @escaping (_ places: [Place], _ errMsg: String?) -> Void) {
        var url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?radius=2000"
        url += String(format: "&location=%f,%f", location.latitude, location.longitude)
        url += "&types=" + type
        var preferredLanguage = NSLocale.preferredLanguages[0]
        if (preferredLanguage.hasPrefix("zh-Hant")) {
            preferredLanguage = preferredLanguage.replacingOccurrences(of: "-Hant", with: "")
        }
        url += "&language=" + preferredLanguage
        url += "&key=" + GOOGLEMAP_API_KEY
        dPrint("searchPlacesType > \(url)")
        
        // TODO: 用Decodable處理
//        AF.request(url).responseDecodable(of: DecodableJSON.self) { response in
//            debugPrint("JSON > \(response)")
        AF.request(url).responseJSON { response in
            var foundPlaces = [Place]()
            var errMsg: String? = response.error?.localizedDescription
            if let data = response.data {
                var json: JSON? = nil
                do {
                    json = try JSON(data: data)
                } catch let parseError {
                    dPrint("JSON Error \(parseError.localizedDescription)")
                }
                //dPrint("JSON > \(json.description)")
                let status = json?[STATUS].stringValue
                if status == OK {
                    //mNextPageToken = json["next_page_token"].string
                    let results = json?["results"].arrayValue
                    if (results != nil) {
                        for result in results! {
                            if let place = Place.create(json: result) {
                                foundPlaces.append(place)
                            } else {
                                dPrint("searchPlacesType > \(result) Parse 出錯")
                            }
                        }
                    }
                } else {
                    errMsg = status
                    dPrint("searchPlacesType Status : \(String(describing: status))")
                }
            }
            completion(foundPlaces, errMsg)
        }
    }
    // 取得 Place 的詳細資訊
    static func getPlaceDetail(_ placeId: String, completion: @escaping (_ place:Place?, _ errMsg: String?) -> Void) {
        var url = "https://maps.googleapis.com/maps/api/place/details/json?placeid=" + placeId
        url += "&key=" + GOOGLEMAP_API_KEY
        dPrint("getPlaceDetail > \(url)")
        
        //AF.request(url).responseDecodable(of: DecodableJSON.self) { response in
            //dPrint("JSON > \(response)")
        AF.request(url).responseJSON { response in
            var errMsg: String? = response.error?.localizedDescription
            var place:Place? = nil
            var json: JSON? = nil
            do {
                json = try JSON(data: response.data!)
            } catch let parseError {
                dPrint("JSON Error \(parseError.localizedDescription)")
            }
            //dPrint("JSON > \(json.description)")
            let status = json?[STATUS].stringValue
            if status == OK {
                let result = json?["result"]
                if (result != nil) {
                    place = Place.create(json: result!)
                    if place == nil {
                        dPrint("getPlaceDetail Parse Failed!")
                    }
                }
            } else {
                errMsg = status
                dPrint("getPlaceDetail Status : \(status)")
            }
            completion(place, errMsg)
        }
    }
    
    
    // TODO: 實驗中
    struct PathElevationDecodableJSON: Decodable { let json: String }
    
    func getPathElevation(_ routePlan: RoutePlan) {
        guard routePlan.encodedPath != nil else {
            return
        }
        let url = "https://maps.googleapis.com/maps/api/elevation/json?path=enc:" + routePlan.encodedPath! + "&key=" + GOOGLEMAP_API_KEY + "&samples=10"
        dPrint("Elevation > \(url)")
//        AF.request(url).responseDecodable(of: PathElevationDecodableJSON.self) { response in
//            debugPrint("JSON > \(response)")
//        }
        AF.request(url).responseJSON { response in
            //print(response.request as Any)  // original URL request
            //print(response.response as Any) // HTTP URL response
            //print(response.data as Any)     // server data
            //print(response.result as Any)   // result of response serialization
            //let json = JSON(data: response.data!)
            var json: JSON? = nil
            do {
                json = try JSON(data: response.data!)
            } catch let parseError {
                dPrint("JSON Error \(parseError.localizedDescription)")
            }
            //dPrint("JSON > \(json.description)")
        }
    }
}

