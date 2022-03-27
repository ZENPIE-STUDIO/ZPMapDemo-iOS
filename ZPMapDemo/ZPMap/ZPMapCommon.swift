//
//  ZPMapCommon.swift
//
//  Created by EddieHua.
//

import UIKit


public let GOOGLEMAP_API_KEY = "⚠️YOUR KEY⚠️"

class ZPMapCommon {
    public static let voiceDistanceFormatter = DistanceFormatter(approximate: true, forVoiceUse: true)  // 語音用
    public static let textDistanceFormatter = DistanceFormatter(approximate: true, forVoiceUse: false)  // 文字用
    
    
    // TODO: 切換模式
//    static var nightMode: Bool = false
    class public var appearance: BaseTheme {
        get {
//            if nightMode {
//                return night
//            } else {
                return day
//            }
        }
    }
    
    static private let day = BaseTheme()
    //static private let night = BaseTheme()
}


// ---- 顏色設置 ----
extension UIColor {
    convenience init(R: UInt8, G: UInt8, B: UInt8) {
        self.init(red: CGFloat(R)/255, green: CGFloat(G)/255, blue: CGFloat(B)/255, alpha: 1)
    }
    convenience init(R: UInt8, G: UInt8, B: UInt8, A: UInt8) {
        self.init(red: CGFloat(R)/255, green: CGFloat(G)/255, blue: CGFloat(B)/255, alpha: CGFloat(A)/255)
    }
}

extension UIView {
    func enableShadowLayer() {
        self.layer.shadowColor = UIColor.darkGray.cgColor
        self.layer.shadowRadius = 3
        self.layer.shadowOpacity = 0.6
        self.layer.shadowOffset = CGSize.zero
    }
}



class BaseTheme {
    // 數字用這個字型："等寬"在變動時-比較不會造成視覺痛苦
    public let numberFontName = "Helvetica Neue"
    
    public let mainFontName = "Helvetica"
    public let mainBoldFontName = "Helvetica-Bold"
    // ====================== Color ==========================
    //public static let mainColor = UIColor(R: 80, G: 168, B: 158)
    class var _mainColor: UIColor {
        //return UIColor(R: 80, G: 168, B: 158)
        return UIColor(R: 0, G: 117, B: 255)
    }
    public let mainColor = _mainColor
    public let bgColor = UIColor.white
    public let navigationBarBackgroundColor = _mainColor
    public let navigationBarTintColor = UIColor.white
    public let tabBarBackgroundColor = UIColor(R: 91, G: 92, B: 96)
    public let tabBarTintColor = UIColor.white
    public let buttonBackgroundColor = _mainColor
    
    // Dashboard
    public let dashboardCircleColor1 = _mainColor   // drvInfo 有讀到助力值時
    //public let dashboardCircleColor2 = UIColor(R: 137, G: 194, B: 58) // 綠色
    public let dashboardSpeedColor = UIColor(R: 0x9F, G: 0x9F, B: 0x9F)
    // AssistCircleBar - 圓形的 助力Bar
    public let assistCircleBarBgColor = UIColor(R: 0xEE, G: 0xEE, B: 0xEE)
    public let assistCircleBarLineColor = UIColor(R: 0x7E, G: 0xB4, B: 0x47)
    public let assistCircleBarMaskColor = UIColor(R: 0xC7, G: 0xCA, B: 0xC3)

    
    // Battery Color
    public let batteryOffColor = UIColor(R: 0xEE, G: 0xEE, B: 0xEE)
    public let batteryColor = UIColor(R: 0x9F, G: 0x9F, B: 0x9F)
    public let batteryFewColor = UIColor(R: 0xFB, G: 0xCE, B: 0x2F)
    public let batteryDangerColor = UIColor(R: 0xE2, G: 0x0F, B: 0x24)
    
    // More Info
    public let moreInfoBgColor = UIColor(R: 0xA3, G: 0xBA, B: 0xBF)
    public let moreInfoTextColor = UIColor.white
}
