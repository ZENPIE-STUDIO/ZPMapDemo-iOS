//
//  RouteRequestView.swift
//
//  Created by EddieHua.
//

import UIKit

//class UILabelPadding: UILabel {
//    let padding = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
//    override func drawText(in rect: CGRect) {
//        super.drawText(in: UIEdgeInsetsInsetRect(rect, padding))
//    }
//    override var intrinsicContentSize : CGSize {
//        let superContentSize = super.intrinsicContentSize
//        let width = superContentSize.width + padding.left + padding.right
//        let heigth = superContentSize.height + padding.top + padding.bottom
//        return CGSize(width: width, height: heigth)
//    }
//}

//
class RouteRequestView: UIView {
    static let PADDING:CGFloat = 10.0
    public static let LABEL_HEIGHT:CGFloat = 38
    public static let HEIGHT:CGFloat = PADDING + (LABEL_HEIGHT + PADDING) * 2
    // Google Map 上有的功能 - 把 button 的 action 交給外面指定
    // < 離開此模式
    public private(set) var closeButton: UIButton!
    // [ ] origin: icon, textfield, button
    // [ ] destination: icon, textfield, button (交換起迄點)
    // [x] 各種模式預算時間
    public private(set) var originButton: UIButton!
    public private(set) var destinationButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ZPMapCommon.appearance.navigationBarBackgroundColor
        enableShadowLayer()
        
        closeButton = UIButton()
        let image = UIImage(named: "Back")?.withRenderingMode(.alwaysTemplate)
        closeButton.setImage(image, for: .normal)
        closeButton.tintColor = UIColor.white
        self.addSubview(closeButton)
        
        originButton = newUIButton(imageName: "RouteOrigin")
        //originButton.isEnabled = false
        self.addSubview(originButton)
        destinationButton = newUIButton(imageName: "RouteTarget")
        //destinationButton.isEnabled = false
        self.addSubview(destinationButton)
    }
    func newUIButton(imageName: String) -> UIButton {
        let label = UIButton()
        label.setImage(UIImage(named: imageName), for: .normal)
        label.imageEdgeInsets = UIEdgeInsets(top: 1, left: 0, bottom: 1, right: 12)
        //label.layer.masksToBounds
        label.layer.cornerRadius = 4
        label.contentHorizontalAlignment = .left
        label.contentEdgeInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8);
        label.backgroundColor = UIColor(white: 0.3, alpha: 0.1)
        label.setTitleColor(.white, for: .normal)
        return label
    }
    
    convenience init() {
        self.init(frame:.zero)
    }
    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    override func layoutSubviews() {
        let frame = self.frame
        let padding = RouteRequestView.PADDING
        let iconSize:CGFloat = 32
        let btnWidth = frame.width - padding * 3 - iconSize
        var top:CGFloat = padding
        let left:CGFloat = iconSize + padding * 2
        
        closeButton.frame = CGRect(x: padding, y:top, width: 40, height: 40)
        
        originButton.frame = CGRect(x: left, y: top, width: btnWidth, height: CGFloat(RouteRequestView.LABEL_HEIGHT))
        top = top + RouteRequestView.LABEL_HEIGHT + padding
        destinationButton.frame = CGRect(x: left, y: top, width: btnWidth, height: RouteRequestView.LABEL_HEIGHT)
    }
}
