//
//  RouteResultView.swift
//
//  Created by EddieHua.
//

import UIKit

// 用來顯示：
//  Route.  規劃結果：行程的距離、預計時間
//  Navi.   預計到達時間、剩餘距離
class RouteResultView : UIControl {
    private static let PADDING:CGFloat = 8
    public static let TITLE_HEIGHT:CGFloat = 32
    public static let INFO_HEIGHT:CGFloat = 22
    public static let HEIGHT:CGFloat = PADDING * 1.8 + TITLE_HEIGHT + INFO_HEIGHT
    public var titleLabel = UILabel()
    public var infoLabel = UILabel()
    public var destinationImageView = UIImageView()         // 最左邊：顯示圖示
    public private(set) var closeNaviButton: UIButton!      // 最左邊：(開始導航後才顯示) 關閉導航模式
    public private(set) var goNaviButton: UIButton!         // 最右邊
    //public private(set) var goSimuButton: UIButton!       // 拿掉: 改成Debug Mode時，詢問使用者

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initUI()
    }
    convenience init() {
        self.init(frame:.zero)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initUI() {
        let PADDING = RouteResultView.PADDING
        //let buttonSize:CGFloat = 50
        let buttonSize = CGSize(width: 50, height: 50)
        backgroundColor = .white
        enableShadowLayer()
        // 最左 destination image
        addSubview(destinationImageView)
        destinationImageView.image = UIImage(named: "RouteResultDestination")
        destinationImageView.snp.makeConstraints { (make) in
            make.size.equalTo(buttonSize)
            make.left.equalTo(self.snp.left).offset(PADDING)
            make.centerY.equalTo(self.snp.centerY)
        }
        // 最左: 關閉 Navi Mode - 跟 destination image 同樣位置
        closeNaviButton = UIButton()
        closeNaviButton.setImage(UIImage(named: "closeNavi"), for: .normal)
        addSubview(closeNaviButton)
        closeNaviButton.snp.makeConstraints { (make) in
            make.edges.equalTo(destinationImageView)
        }
        
        // 最右 Go Navi
        goNaviButton = UIButton()
        goNaviButton.setImage(UIImage(named: "GoNavi"), for: .normal)
        self.addSubview(goNaviButton)
        goNaviButton.snp.makeConstraints { (make) in
            make.size.equalTo(buttonSize)
            //make.left.equalTo(self.snp.left).offset(PADDING)
            make.right.equalTo(self.snp.right).offset(-PADDING)
            make.centerY.equalTo(self.snp.centerY)
        }

        // 顯示時間、距離
        addSubview(titleLabel)
        titleLabel.textColor = .black
        titleLabel.snp.makeConstraints { (make) in
            make.left.equalTo(closeNaviButton.snp.right).offset(PADDING)
            make.right.equalTo(self.snp.right).offset(-PADDING)
            make.top.equalTo(self.snp.top).offset(PADDING * 0.8)
            make.height.equalTo(RouteResultView.TITLE_HEIGHT)
        }
        titleLabel.font = UIFont.systemFont(ofSize: 22)
        titleLabel.text = ""
        // 顯示 地址?
        addSubview(infoLabel)
        infoLabel.textColor = .black
        infoLabel.snp.makeConstraints { (make) in
            make.left.equalTo(closeNaviButton.snp.right).offset(PADDING)
            make.right.equalTo(self.snp.right).offset(-PADDING)
            make.bottom.equalTo(self.snp.bottom).offset(-PADDING)
            make.height.equalTo(RouteResultView.INFO_HEIGHT)
        }
        infoLabel.font = UIFont.systemFont(ofSize: 16)
        infoLabel.text = ""
    }
}
