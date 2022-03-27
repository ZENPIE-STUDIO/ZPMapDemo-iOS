//
//  Place.swift
//
//  Created by EddieHua.
//

import UIKit
import SwiftyJSON
import RealmSwift
import CoreLocation

// 打算存在本地DB，當作使用者查詢的歷史清單
class Place: Object {
    @objc dynamic var id: String = ""         // place_id
    @objc dynamic var name: String = ""
    @objc dynamic var address: String = ""        // vicinity
    @objc dynamic var latitude: Double = 0.0
    @objc dynamic var longitude: Double = 0.0
    @objc dynamic var usedDate = Date()
    //var icon:UIImage? = nil     // 圖示
    var coordinate:CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    override static func ignoredProperties() -> [String] {
        return ["coordinate"]
    }
    override static func primaryKey() -> String? {
        return "id"
    }

    
    static func create(json: JSON) -> Place? {
        var place:Place! = nil
        let geometry = json["geometry"]
        let location = geometry["location"]
        if let placeId = json["place_id"].string,
            let name = json["name"].string,
            let latitude = location["lat"].double,
            let longitude = location["lng"].double {
            place = Place()
            place.id = placeId
            place.name = name
            place.latitude = latitude
            place.longitude = longitude
            // place 會有
            if let address = json["vicinity"].string {
                place.address = address
            }
            // 道路會有
            if let address = json["formatted_address"].string {
                place.address = address
            }
        }
        return place
    }
}


// 使用 Google Places API 的 autocomplete 得到的回傳結果
class AutoCompletePlace {
    var place_id: String!
    var mainText: String!           // Place 的名稱
    var secondaryText: String!      // 位於哪條路上
    
    // highlight 輸入字元
    var mainAttrubitedText: NSAttributedString!
    
    class func create(json: JSON) -> AutoCompletePlace? {
        let place = AutoCompletePlace()
        place.place_id = json["place_id"].string
        let structuredFormatting = json["structured_formatting"]
        place.mainText = structuredFormatting["main_text"].string
        place.secondaryText = structuredFormatting["secondary_text"].string
        
        if let matchedSubStrings = structuredFormatting["main_text_matched_substrings"].array {
            let attributedString = NSMutableAttributedString(string:place.mainText)
            for matchedSubString in matchedSubStrings {
                let offset = matchedSubString["offset"].intValue
                let length = matchedSubString["length"].intValue
                let range = NSRange(location: offset, length: length)
                attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.red , range: range)
            }
            place.mainAttrubitedText = attributedString
        }
        return place
    }
}
