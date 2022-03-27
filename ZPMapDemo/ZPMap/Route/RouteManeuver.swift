//
//  RouteManeuver.swift
//
//  Created by EddieHua.
//

import UIKit

extension UIImage {
    func scaleImage(toSize newSize: CGSize) -> UIImage? {
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            context.interpolationQuality = .high
            let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: newSize.height)
            context.concatenate(flipVertical)
            context.draw(self.cgImage!, in: newRect)
            let newImage = UIImage(cgImage: context.makeImage()!)
            UIGraphicsEndImageContext()
            return newImage
        }
        return nil
    }
}

public enum RouteManeuver {
    case none   // 沒有
    // 起點、終點
    case origin, destination
    case merge, straight
    // 右轉 (角度由大到小)
    case uturnRight, sharpRight, right, slightRight
    // 左轉(角度由大到小)
    case uturnLeft, sharpLeft, left, slightLeft
    // 靠! 右or左
    case keepRight, keepLeft
    // 叉路
    case forkRight, forkLeft
    // 斜坡
    case rampRight, rampLeft
    // 圓環
    case roundAboutLeft, roundAboutRight
    // 搭船…
    case ferry, ferryTrain
    
    // 由 google directions 的結果轉化而來，是否需要這麼多種提示(再看看)
    init(google:String) {
        switch (google) {
        case "uturn-right":         self = .uturnRight;
        case "turn-right":          self = .right;
        case "turn-sharp-right":    self = .sharpRight;
        case "turn-slight-right":   self = .slightRight;
        case "uturn-left":          self = .uturnLeft;
        case "turn-left":           self = .left;
        case "turn-sharp-left":     self = .sharpLeft;
        case "turn-slight-left":    self = .slightLeft;
        case "merge":               self = .merge;
        case "straight":            self = .straight;       // 直走
        case "roundabout-left":     self = .roundAboutLeft;
        case "roundabout-right":    self = .roundAboutRight;
        case "ramp-right":          self = .rampRight;
        case "fork-right":          self = .forkRight;
        case "ramp-left":           self = .rampLeft;
        case "fork-left":           self = .forkLeft;
        case "ferry":               self = .ferry;
        case "ferry-train":         self = .ferryTrain;
        case "keep-right":          self = .keepRight;
        case "keep-left":           self = .keepLeft;
        default:                    self = .none
            // 上下交流道、過橋 - 直接parse字串的話，有語系的問題
        }
    }
    
    func text() -> String {
        var text:String = ""
        switch self {
        // Right
        case .uturnRight:   text = LocalizedString("map.u-turn-right");
        case .sharpRight:   text = LocalizedString("map.sharp-right");
        case .right:        text = LocalizedString("map.turn-right");
        case .forkRight:    text = LocalizedString("map.fork-right");
        case .slightRight:  text = LocalizedString("map.slight-right");
        // Left
        case .uturnLeft:    text = LocalizedString("map.u-turn-left");
        case .sharpLeft:    text = LocalizedString("map.sharp-left");
        case .left:         text = LocalizedString("map.turn-left");
        case .forkLeft:     text = LocalizedString("map.fork-left");
        case .slightLeft:   text = LocalizedString("map.slight-left");
            
        case .merge:        text = LocalizedString("map.merge");
        case .straight:     text = LocalizedString("map.straight");
        case .roundAboutRight: text = LocalizedString("map.round-about-right");
        case .roundAboutLeft:  text = LocalizedString("map.round-about-left");
        case .keepRight:    text = LocalizedString("map.keep-right");
        case .keepLeft:     text = LocalizedString("map.keep-left");
        case .rampRight:    text = LocalizedString("map.ramp-right");
        case .rampLeft:     text = LocalizedString("map.ramp-left");
        case .ferry:        fallthrough
        case .ferryTrain:   text = LocalizedString("map.ferry");
        default: break
        }
        return text
    }
    func icon() -> UIImage? {
        var image:UIImage? = nil
        var strEmoji = ""
        //var mirror = false
        switch self {
            // Right
            case .uturnRight:   image = UIImage(named: "navi_uturn_right");
            case .sharpRight:   image = UIImage(named: "navi_sharp_right");
            case .right:        image = UIImage(named: "navi_right");
            case .forkRight:    image = UIImage(named: "navi_fork_right");
            case .slightRight:  image = UIImage(named: "navi_slight_right");
            // Left
            case .uturnLeft:    image = UIImage(named: "navi_uturn_left");
            case .sharpLeft:    image = UIImage(named: "navi_sharp_left");
            case .left:         image = UIImage(named: "navi_left");
            case .forkLeft:     image = UIImage(named: "navi_fork_left");
            case .slightLeft:   image = UIImage(named: "navi_slight_left");

            case .merge:        image = UIImage(named: "navi_merge");
            case .straight:     image = UIImage(named: "navi_forward");
            case .roundAboutRight: image = UIImage(named: "navi_round_about_right");
            case .roundAboutLeft:  image = UIImage(named: "navi_round_about_left");
            case .keepRight:    image = UIImage(named: "navi_keep_right");
            case .keepLeft:     image = UIImage(named: "navi_keep_left");
            case .rampRight:    image = UIImage(named: "navi_ramp_right");
            case .rampLeft:     image = UIImage(named: "navi_ramp_left");
            case .ferry:        fallthrough
            case .ferryTrain:   strEmoji = "⛴";
            case .origin:       strEmoji = "🏳️";
            case .destination:  strEmoji = "🏁";
            default:            strEmoji = "🛵";    // 接著走 - 可考慮使用 straight
        }
        
        if image == nil {
            image = RouteManeuver.emojiToImage(strEmoji, mirror:false)
        }
        image = image!.scaleImage(toSize: CGSize(width: 20, height: 20))
        return image
    }
    
    static func emojiToImage(_ strEmoji:String, mirror:Bool) -> UIImage? {
        let fontSize:CGFloat = 40
        let size = CGSize(width: fontSize * 1.1, height: fontSize * 1.1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0);
        UIColor.clear.set()
        let rect = CGRect(origin: CGPoint.zero, size: size)
        UIRectFill(rect)
        
        if mirror {
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.translateBy(x: size.width, y: 0)
            ctx?.scaleBy(x: -1.0, y: 1.0)
        }
        
        (strEmoji as NSString).draw(in: rect, withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize)])
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
