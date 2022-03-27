//
//  POIinfoView.swift
//
//  Created by EddieHua.
//
import UIKit

/// 顯示 點選之地的訊息
/// 目前只會顯示 title 跟一個 Go(Route) 的 button
class POIinfoView: UIView {
    public static let HEIGHT:CGFloat = 54
    public static let TITLE_HEIGHT:CGFloat = 42
    public static let BUTTON_WIDTH:CGFloat = 100
    public static let BUTTON_HEIGHT:CGFloat = 42
    let PADDING:CGFloat = 6.0

    public private(set) var titleLabel:UILabel!
    public private(set) var goButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        enableShadowLayer()
        titleLabel = UILabel()
        titleLabel.textColor = .black
        self.addSubview(titleLabel)
        
        
        goButton = UIButton()
        goButton.layer.cornerRadius = 6.0
        goButton.setTitle(LocalizedString("map.poi-info.route"), for: .normal)
        goButton.backgroundColor = ZPMapCommon.appearance.buttonBackgroundColor
        self.addSubview(goButton)
    }
    
    convenience init() {
        self.init(frame:.zero)
    }
    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    override func layoutSubviews() {
        let frame = self.frame
        let uiWidth = frame.width - PADDING * 2
        titleLabel.frame = CGRect(x: PADDING * 2, y: PADDING, width: uiWidth, height: CGFloat(POIinfoView.TITLE_HEIGHT))
        goButton.frame = CGRect(x: frame.width - PADDING - POIinfoView.BUTTON_WIDTH, y: POIinfoView.HEIGHT - (POIinfoView.BUTTON_HEIGHT + PADDING), width: POIinfoView.BUTTON_WIDTH, height: POIinfoView.BUTTON_HEIGHT)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
