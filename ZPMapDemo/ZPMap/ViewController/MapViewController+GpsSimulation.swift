//
//  MapViewController+GpsSimulation.swift
//
//  Created by EddieHua.
//

import UIKit


// ======================= 手動模擬 =========================
extension MapViewController {
    func startDPadGpsSimulation() {
        // 停止舊的
        if mLocationManager != nil {
            stopLocationManager(mLocationManager!)
        }
        // GPS 座標模擬
        dPadSimuLocationManager = DPadSimuLocationManager(coordinate: mCurrentCameraPosition.target)
        mLocationManager = dPadSimuLocationManager
        mLocationManager?.delegate = self
        dPrint("啟動手動模擬 GPS 座標模式")
        openGpsDPad()
    }
    func stopDPadGpsSimulation() {
        if mLocationManager != nil {
            stopLocationManager(mLocationManager!)
        }
        closeGpsDPad()
        dPadSimuLocationManager = nil
        mLocationManager = mGpsLocationManager
        startLocationManager(mGpsLocationManager)
        dPrint("關閉手動模擬 GPS 座標模式")
    }
    // 目前只有在離開 NaviMapState 時 才會呼叫關閉
    func closeGpsDPad() {
        mBtnForward?.removeFromSuperview()
        mBtnForward = nil
        mBtnBackward?.removeFromSuperview()
        mBtnBackward = nil
        mBtnTurnLeft?.removeFromSuperview()
        mBtnTurnLeft = nil
        mBtnTurnRight?.removeFromSuperview()
        mBtnTurnRight = nil
    }
    // 產生控制器
    func openGpsDPad() {
        if let view = self.view {
            let OffsetY = 180
            let PADDING = 60
            let size = CGSize(width: 80, height: 80)
            // 前進
            mBtnForward = addNewPadButton(tag: MapUiTags.DPAD_FORWARD, imageName: "DpadForward")
            mBtnForward.snp.makeConstraints { (make) in
                make.size.equalTo(size)
                make.centerX.equalTo(view.snp.centerX)
                make.centerY.equalTo(view.snp.centerY).offset(OffsetY-PADDING)
            }
            // 後退
            mBtnBackward = addNewPadButton(tag: MapUiTags.DPAD_BACKWARD, imageName: "DpadBackward")
            mBtnBackward.snp.makeConstraints { (make) in
                make.size.equalTo(size)
                make.centerX.equalTo(view.snp.centerX)
                make.centerY.equalTo(view.snp.centerY).offset(OffsetY+PADDING)
            }
            // 左轉
            mBtnTurnLeft = addNewPadButton(tag: MapUiTags.DPAD_TURN_LEFT, imageName: "DpadTurnLeft")
            mBtnTurnLeft.snp.makeConstraints { (make) in
                make.size.equalTo(size)
                make.centerX.equalTo(view.snp.centerX).offset(-PADDING)
                make.centerY.equalTo(view.snp.centerY).offset(OffsetY)
            }
            // 右轉
            mBtnTurnRight = addNewPadButton(tag: MapUiTags.DPAD_TURN_RIGHT, imageName: "DpadTurnRight")
            mBtnTurnRight.snp.makeConstraints { (make) in
                make.size.equalTo(size)
                make.centerX.equalTo(view.snp.centerX).offset(PADDING)
                make.centerY.equalTo(view.snp.centerY).offset(OffsetY)
            }
        }
    }
    
    func addNewPadButton(tag:Int, imageName:String) -> UIButton {
        let button = UIButton()
        button.alpha = 0.4;
        button.tag = tag
        button.setImage(UIImage(named: imageName), for: .normal)
        view.addSubview(button)
        button.addTarget(self, action: #selector(dPadButtonDown(button:)), for: .touchDown)
        button.addTarget(self, action: #selector(dPadButtonUp(button:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(dPadButtonUp(button:)), for: .touchUpOutside)
        return button
    }
    
    @objc func dPadButtonUp(button: UIButton) {
        mRepeatTimer?.invalidate()
        mRepeatTimer = nil
    }
    
    @objc func dPadButtonDown(button: UIButton) {
        //dPrint("\(button.tag)")
        switch (button.tag) {
        case MapUiTags.DPAD_FORWARD:   dPadSimuLocationManager?.forward()
        case MapUiTags.DPAD_BACKWARD:  dPadSimuLocationManager?.backward()
        case MapUiTags.DPAD_TURN_RIGHT:dPadSimuLocationManager?.turnRight()
        case MapUiTags.DPAD_TURN_LEFT: dPadSimuLocationManager?.turnLeft()
        default: break
        }
        if mRepeatTimer == nil {
            mRepeatTimer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(timerSetButton(timer:)), userInfo: button, repeats: true)
        }
    }
    @objc func timerSetButton(timer:Timer) {
        //dPrint("timerSetButton")
        if let button = timer.userInfo as? UIButton {
            dPadButtonDown(button: button)
        }
    }
}
