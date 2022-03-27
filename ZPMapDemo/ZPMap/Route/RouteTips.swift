//
//  RouteTips.swift
//  包含了　"背景" 提示　及 "TTS語音" 提示
//
//  Created by EddieHua.
//

import Foundation
import CoreLocation
import AVFoundation
import UserNotifications

fileprivate let NaviBgNotificationIdentifier = "ZPMap-NaviBgNoti"

class RouteTips : NSObject {
    // 語音提示之間 需要有緩衝 (３秒內不會重覆提示　同個 Step)
    public let bufferBetweenAnnouncements: TimeInterval = 3
    var recentlyAnnouncedRouteStep: RouteStep?
    var announcementTimer: Timer!
    
    var didLastAnnouncedDeviate = false    // 最後提示的是　偏離
    var allowAnnouncedDeviateOrBack = false      // 是否可以再提示　偏離路線 或 回到路線
    
    // TTS - Speech
    public var isSpeechEnabled: Bool = true
    public var volume: Float = 1.0
    public var instructionVoiceSpeedRate = 1.08
    public var instructionVoiceVolume = "x-loud"
    lazy var speechSynth = AVSpeechSynthesizer()
    var audioPlayer: AVAudioPlayer?
    
    override init() {
        super.init()
        
        do {
            try duckAudio() // 會讓音樂變小聲
        } catch {
            dPrint("duckAudio error = \(error)")
        }
        speechSynth.delegate = self
        resumeNotifications()
    }
    
    deinit {
        dPrint("deinit")
        suspendNotifications()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [NaviBgNotificationIdentifier])
        speechSynth.stopSpeaking(at: .word)
        do {
            try unDuckAudio()
        } catch {
            dPrint("unDuckAudio error = \(error)")
        }
    }
    
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(alertLevelDidChange(notification:)), name: NaviAlertLevelDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(alertDeviateFromRoute(notification:)), name: NaviAlertDeviateFromRoute, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(alertBackToRoute(notification:)), name: NaviAlertBackToRoute, object: nil)
    }
    
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: NaviAlertLevelDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: NaviAlertDeviateFromRoute, object: nil)
        NotificationCenter.default.removeObserver(self, name: NaviAlertBackToRoute, object: nil)
        //NotificationCenter.default.removeObserver(self, name: RouteControllerWillReroute, object: nil)
    }
    // 決定要不要提示
    func shouldAnnounce(step: RouteStep?, alertLevel: AlertLevel?) -> Bool {
        // 目前３秒(bufferBetweenAnnouncements) 內不會重覆提示　同個Step
        guard recentlyAnnouncedRouteStep != step else {
            dPrint("Skip RouteStep \(step!.instructions!)")
            return false
        }
        if step != nil && (step!.maneuver != .destination || step!.maneuver != .origin) {
            if alertLevel == .low {
                return false
            }
        }
        recentlyAnnouncedRouteStep = step
        return true
    }
    
    func startAnnouncementTimer() {
        announcementTimer = Timer.scheduledTimer(timeInterval: bufferBetweenAnnouncements, target: self, selector: #selector(resetAnnouncementTimer), userInfo: nil, repeats: false)
    }
    
    @objc func resetAnnouncementTimer() {
        dPrint("resetAnnouncementTimer")
        recentlyAnnouncedRouteStep = nil
        allowAnnouncedDeviateOrBack = true
        //announcedDeviateFromRoute = false // 一直提示太囉嗦
        announcementTimer.invalidate()
    }
    // 偏離路徑　（目前只會提示一次）
    @objc open func alertDeviateFromRoute(notification: NSNotification) {
        guard allowAnnouncedDeviateOrBack else { return }
        allowAnnouncedDeviateOrBack = true
        
        if didLastAnnouncedDeviate {
            return
        }
        didLastAnnouncedDeviate = true
        // 偏離導航路線
        let text = LocalizedString("map.deviated-from-route.message")
        // 背景提示
        localBgNotify(title: text, body: "")
        // TTS
        if isSpeechEnabled && volume > 0 {
            speak(text, error: nil)
        }
        startAnnouncementTimer()
    }
    // 回到路徑
    @objc open func alertBackToRoute(notification: NSNotification) {
        guard allowAnnouncedDeviateOrBack else { return }
        allowAnnouncedDeviateOrBack = true
        
        if !didLastAnnouncedDeviate {
            return
        }
        didLastAnnouncedDeviate = false     // 回到路線上
        
        let text = LocalizedString("map.back-to-navigation-route.message")
        // 背景提示
        localBgNotify(title: text, body: "")
        // TTS
        if isSpeechEnabled && volume > 0 {
            speak(text, error: nil)
        }
        startAnnouncementTimer()
    }
    
    // 導航進度更新
    @objc open func alertLevelDidChange(notification: NSNotification) {
        if didLastAnnouncedDeviate {
            dPrint("還沒回到導航路線，不提示!")
            return
        }
        if let userInfo = notification.userInfo {
            if let alertLevel = userInfo[NaviCurrentStepAlertLevel] as? AlertLevel,
                let distance = userInfo[NaviDistanceToNextStep] as? CLLocationDistance,
                let nextStep = userInfo[NaviNextStep] as? RouteStep {
                
                guard true == shouldAnnounce(step: nextStep, alertLevel: alertLevel) else { return }
                
                // 背景提示
                if nextStep.maneuver == .destination && alertLevel == .arrive {
                    // 結束了，把之前的提示畫面拿掉
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [NaviBgNotificationIdentifier])
                } else {
                    localBgNotify(level: alertLevel, distance: distance, nextStep: nextStep)
                }
                // --------------
                if isSpeechEnabled && volume > 0 {
                    // TTS
                    let moreStep = userInfo[NaviMoreStep] as? RouteStep
                    tts(alertLevel: alertLevel, distance: distance, nextStep: nextStep, moreStep: moreStep)
                }
                startAnnouncementTimer()
            }
        }
    }
    // ======================== Speech ============================
    func replaceSomeCharacter(text:String) -> String {
        return text.replacingOccurrences(of: "/", with: ",")
    }
    // tts 語音提示
    func tts(alertLevel:AlertLevel, distance:CLLocationDistance ,nextStep: RouteStep, moreStep: RouteStep?) {
        let instructions = replaceSomeCharacter(text: (nextStep.instructions)!)
        
        var text:String? = nil
        
        if nextStep.maneuver == .destination {
            if alertLevel == .arrive {
                text = String(format: LocalizedString("map.arrived-s-route-over"), instructions)
            } else {
                text = LocalizedString("map.close-to-destination") + " " + instructions
            }
        } else if nextStep.maneuver == .origin {
            text = LocalizedString("map.start-voice-navigation-") + instructions
        } else {
            switch (alertLevel) {
            case .arrive:   break  // 不發音
            case .high:
                text = instructions
                if moreStep != nil {
                    if moreStep!.maneuver.text().lengthOfBytes(using: .utf8) > 0 {   // 有字才加
                        // xxx 然後再 ooo
                        text = instructions + LocalizedString("map.-then-") + moreStep!.maneuver.text()
                    }
                }
                break
            default:
                if distance < 10 {
                    text = instructions// 小於 10公尺，不提示距離
                } else {
                    // "xx 距離" 後 "指示"
                    text = String(format: LocalizedString("map.in-dis-ins"), ZPMapCommon.voiceDistanceFormatter.string(from: distance),
                        instructions)
                }
                break
            }
        }
        
        if text != nil {
            dPrint("[\(alertLevel)] \(distance)  \(text!)")
            speak(text!, error: nil)
        } else {
            dPrint("text == nil!?")
        }
    }
    func speak(_ text: String, error: String? = nil) {
        // Note why it failed
        if let error = error {
            print(error)
        }
        let utterance = AVSpeechUtterance(string: text)
        // Only localized languages will have a proper fallback voice
        let locale = Locale.preferredLanguages.first
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
        utterance.volume = volume
        
        speechSynth.speak(utterance)
    }
    // ======================== 背景時　local notification ============================
    // 使用 UNMutableNotificationContent 同時只能有一個提示，要有固定的 ID，有 ID就能消除

    func localBgNotify(title: String, body: String) {
        let notificationContent = UNMutableNotificationContent()
        // TODO: 附圖 - UNNotificationAttachment，需要用 URL
        //notificationContent.subtitle =
        //notificationContent.categoryIdentifier = "ZPMap"
        notificationContent.title = title
        notificationContent.body = body
        // Create a notification request with the above components)
        let request = UNNotificationRequest(identifier: NaviBgNotificationIdentifier, content: notificationContent, trigger: nil)
        // Add this notification to the UserNotificationCenter
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { error in
            if error != nil {
                dPrint("Add Notification > \(String(describing: error))")
            }
        })
    }
    func localBgNotify(level: AlertLevel, distance:CLLocationDistance, nextStep:RouteStep) {
        var title = ""
        if level == .high || distance < 10 {
            // 不用提示距離
            title = nextStep.maneuver.text()
        } else {
            // "xx 距離" 後 "指示"
            title = String(format: LocalizedString("map.in-dis-ins"), ZPMapCommon.voiceDistanceFormatter.string(from: distance),
                          nextStep.maneuver.text())
        }
        localBgNotify(title: title, body: nextStep.instructions!)
    }
}

extension RouteTips : AVSpeechSynthesizerDelegate {
    func audioPlayerDidFinishPlaying(notification: NSNotification) {
        do {
            try unDuckAudio()
        } catch {
            print(error)
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        do {
            try unDuckAudio()
        } catch {
            print(error)
        }
    }
    
    // 阻斷背景音樂播放
    func duckAudio() throws {
        // AVAudioSessionCategoryPlayback：設定參數 阻斷其他聲音 + 混音播放；允许后台播放，且忽略静音键作用
        // 需要在应用程序的 info.plist 文件中正确设置 Required background modes。
        let categoryOptions: AVAudioSession.CategoryOptions = [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.spokenAudio, options: categoryOptions)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    // 不阻斷背景音樂
    func unDuckAudio() throws {
        if !speechSynth.isSpeaking {
            //try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)  // 試-不要停掉音樂
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }
}
