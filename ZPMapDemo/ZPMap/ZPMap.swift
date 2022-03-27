//
//  ZPMap.swift
//  ZPMap
//
//  Created by EddieHua on 2022/3/24.
//
import Swift
import Foundation


public final class ZPMap : NSObject {
    private static var mapApiKey: Swift.String? = nil
    public static func setupMapApiKey(_ apiKey: Swift.String) {
        mapApiKey = apiKey
    }
}
