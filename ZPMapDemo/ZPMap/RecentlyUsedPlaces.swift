//
//  RecentlyAccessPlaces.swift
//
//  Created by EddieHua.
//

import Foundation
import RealmSwift
import CoreLocation

//  儲存最近有 搜尋、設為導航目的地 的 Places
class RecentlyUsedPlaces {
    /// Shared Instance
    public static let shared = RecentlyUsedPlaces()
    private var mConfig = Realm.Configuration()
    
    init() {
        do {
            let documentDirectory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
            let fileURL = documentDirectory.appendingPathComponent("RecentlyUsedPlaces.realm")
            mConfig.fileURL = fileURL
            //Realm.Configuration.defaultConfiguration = config
            dPrint("[RecentlyUsedPlaces] init, DB Path : \(fileURL)")
        } catch {
            print(error)
        }
    }
    // 使用 Place：更新 存取時間
    func use(place:Place) {
        let realm = try! Realm(configuration: mConfig)
        place.usedDate = Date()
        try! realm.write {
            realm.add(place, update: Realm.UpdatePolicy.modified)
            //realm.add(place, update: true)
        }
    }
    // 取得全部、照時間排序
    private func getAll(realm: Realm) -> Results<Place> {
        var places = realm.objects(Place.self)
        if places.count > 0 {
            places = places.sorted(byKeyPath: "usedDate", ascending: false)
        }
        return places
    }
    // 取得前幾名資料 (照時間排序)，其餘刪除
    func getTop(limit:Int, deleteOther:Bool) throws -> [Place]? {
        guard limit > 0 else {
            return nil
        }
        var places = [Place]()
        let realm = try Realm(configuration: mConfig)
        let placeResults = getAll(realm:realm)
        let count = placeResults.count
        // 取出要回傳的資料
        let mincnt = min(limit, count)
        for i in 0..<mincnt {
            let place = placeResults[i]
            let p = Place()
            p.id = place.id
            p.name = place.name
            p.address = place.address
            p.coordinate = place.coordinate
            p.usedDate = place.usedDate
            places.append(p)
        }
        // 刪除 名落孫山的
        if deleteOther && count > limit {
            realm.beginWrite()
            for i in limit..<count {
                realm.delete(placeResults[i])
            }
            try realm.commitWrite()
        }
        return places
    }
}
