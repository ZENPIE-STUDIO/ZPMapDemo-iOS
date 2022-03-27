//
//  RouteGuideView.swift
//
//  Created by EddieHua.
//

import UIKit

/// 負責顯示路口提示
class RouteGuideView: UIView {
    private static let PADDING:CGFloat = 8
    public static let IMAGE_SIZE:CGFloat = 64
    public static let DISTANCE_TEXT_HEIGHT:CGFloat = 28        // 距離提示的高度
    public static let HEIGHT:CGFloat = PADDING * 3 + IMAGE_SIZE + DISTANCE_TEXT_HEIGHT
    
    let imageView = UIImageView()
    let distanceLabel = UILabel()
    let instrcutionLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        enableShadowLayer()
        
        addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.left.equalTo(self.snp.left).offset(RouteGuideView.PADDING)
            make.size.equalTo(CGSize(width: RouteGuideView.IMAGE_SIZE, height: RouteGuideView.IMAGE_SIZE))
            make.top.equalTo(self.snp.top).offset(20 + RouteGuideView.PADDING)
        }
        
        // 顯示距離提示 - 在 icon 下方
        distanceLabel.textAlignment = .center
        addSubview(distanceLabel)
        distanceLabel.snp.makeConstraints { (make) in
            make.width.equalTo(RouteGuideView.IMAGE_SIZE + RouteGuideView.PADDING * 2)
            make.height.equalTo(RouteGuideView.DISTANCE_TEXT_HEIGHT)
            make.centerX.equalTo(imageView.snp.centerX)
            make.bottom.equalTo(self.snp.bottom)
        }
        
        //
        instrcutionLabel.font = UIFont.systemFont(ofSize: 26)
        instrcutionLabel.numberOfLines = 0
        addSubview(instrcutionLabel)
        instrcutionLabel.snp.makeConstraints { (make) in
            make.left.equalTo(imageView.snp.right).offset(RouteGuideView.PADDING)
            make.right.equalTo(self.snp.right).offset(-RouteGuideView.PADDING)
            make.centerY.equalTo(imageView.snp.centerY)
            make.height.equalTo(RouteGuideView.IMAGE_SIZE)
        }
    }
    
    convenience init() {
        self.init(frame:.zero)
    }
    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    // 設置導航提示 image
    func setImage(image:UIImage?) {
        imageView.image = image
    }
    // 設置 距離提示
    func setDistance(text: String?) {
        distanceLabel.text = text
    }
    // 設置導航提示
    func setInstrcution(text: String?) {
        instrcutionLabel.text = text
    }
    // 設置導航提示
    func setAttrInstrcution(attributedText: NSAttributedString?) {
        instrcutionLabel.attributedText = attributedText
    }
    
}
