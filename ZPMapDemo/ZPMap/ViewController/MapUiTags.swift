//
//  MapUiTags.swift
//
//  Created by EddieHua.
//

import Foundation

// Map畫面中 UI元件的 TAG
public struct MapUiTags {
    public static let BUTTON_ROUTE = 100
    public static let BUTTON_SET_ORIGIN = 101
    public static let BUTTON_SET_DESTINATION = 102
    public static let BUTTON_CLOSE_DIRECTION_REQUEST_VIEW = 103
    public static let BUTTON_MapMode = 200
    public static let BUTTON_GONAVI = 201   // 開始導航
    //public static let BUTTON_GOSIMU = 202   // 模擬駕駛
    public static let BUTTON_CLOSE_NAVI = 203   // 離開導航模式

    public static let DPAD_FORWARD = 301   // 前進
    public static let DPAD_BACKWARD = 302   // 後退
    public static let DPAD_TURN_LEFT = 303   // 左轉
    public static let DPAD_TURN_RIGHT = 304   // 右轉
}
