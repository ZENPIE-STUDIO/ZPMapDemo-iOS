//
//  SearchPlacesViewController.swift
//  （未輸入文字）顯示 使用的 Places 歷史記錄
//  （輸入文字）  顯示 搜尋結果
//
import UIKit
import SnapKit
import Alamofire
import SwiftyJSON
import GooglePlaces
import RealmSwift


fileprivate let kPlaceCellIdentifier = "placeCell"

// 快速搜尋項目
fileprivate let QUICK_SEARCH_CONVENIENCE_STORE = 1
fileprivate let QUICK_SEARCH_GAS_STATION = 2
fileprivate let QUICK_SEARCH_LODGING = 3

fileprivate let QUICK_SEARCH_RECENTLY_BASE = 100

protocol SearchPlacesViewDelegate : NSObjectProtocol {
    // autocomplete 所找到的點 沒有座標，所以需要另外再取得詳細資訊
    func searchPlaces(viewController: SearchPlacesViewController, selectedPlace:AutoCompletePlace)
    // 用"什麼功能" - 找到很多的 Places，會一一在地圖上標註
    func searchPlaces(viewController: SearchPlacesViewController, title:String, foundPlaces:[Place])
    // 從 Recently Places 中選擇
    func searchPlaces(viewController: SearchPlacesViewController, recentlyPlace:Place)
}

class QuickSearchOption {
    var type:Int = 0    // 目前沒用到
    var tag:Int = 0
    var title:String = ""
    var detail:String = ""
    
    init(tag:Int, title:String) {
        self.tag = tag
        self.title = title
    }
}

// 狀態：
//      初始：提供 快速搜尋選項 及 歷史記錄
//      快速搜尋結果
//      autocomplete 關鍵字搜尋結果
// TODO: 在設定 起/迄點 時，需可以選擇「GPS位置」、「在地圖上選擇」
class SearchPlacesViewController : UIViewController, UITextFieldDelegate {
    public var location: CLLocationCoordinate2D? = nil
    
    weak open var delegate: SearchPlacesViewDelegate?
    //
    var mBtnClose: UIButton! = nil
    var mTextField:UITextField! = nil
    var mTableView:UITableView! = nil
    
    // ========= item 顯示規則 ==========
    // 3種 狀態：
    enum Mode : Int {
        case InitMode                   //   初始：提供 快速搜尋選項 及 歷史記錄
        case AutoCompleteResultMode      //   autocomplete 關鍵字搜尋結果
    }
    var mMode:Mode = .InitMode
    // 未輸入文字(搜尋)前的顯示項目
    var mQuickSearchOptions = Array<QuickSearchOption>()
    // TextField 有內容時 - 以 autocomplete 的搜尋結果為主
    var mAutoCompletePlaces = Array<AutoCompletePlace>()
    // 歷史記錄
    var mRecentlyPlaces = [Place]()
    
    deinit {
        mQuickSearchOptions.removeAll()
        mAutoCompletePlaces.removeAll()
        mRecentlyPlaces.removeAll()
        mBtnClose = nil
        mTextField = nil
        mTableView = nil
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view.backgroundColor = UIColor.init(white: 0.9, alpha: 0.9)
        
        let PADDING:CGFloat = 8
        let barViewHeight:CGFloat = 48
        let topBottomMargin:CGFloat = 2
        let backButtonSize = barViewHeight - (topBottomMargin * 2)
        
        // bar - 尺寸跟 map 畫面上的 SearchButton 一樣
        let barView = UIView()
        barView.backgroundColor = .white
        self.view.addSubview(barView)
        barView.snp.makeConstraints { (make) in
            make.left.equalTo(self.view!.snp.left).offset(10)
            make.right.equalTo(self.view!.snp.right).offset(-10)
            make.top.equalTo(self.view!.snp.top).offset(30)
            make.height.equalTo(barViewHeight)
        }
        // back button
        mBtnClose = UIButton()
        mBtnClose.setImage(UIImage(named:"Back"), for: .normal)
        //mBtnClose.setTitle("X", for: .normal)
        mBtnClose.setTitleColor(.black, for: .normal)
        barView.addSubview(mBtnClose)
        mBtnClose.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: backButtonSize, height: backButtonSize))
            make.left.equalTo(barView.snp.left).offset(3)
            make.top.equalTo(barView.snp.top).offset(topBottomMargin)
        }
        mBtnClose.addTarget(self, action: #selector(close), for: .touchUpInside)
        // Input Text Field
        mTextField = UITextField()
        mTextField.returnKeyType = .search
        mTextField.placeholder = LocalizedString("map.search-places-or-roads")
        mTextField.delegate = self
        mTextField.clearButtonMode = UITextField.ViewMode.unlessEditing // 清除按鈕
        barView.addSubview(mTextField)
        mTextField.snp.makeConstraints { (make) in
            //make.size.equalTo(CGSize(width: 40, height: 40))
            make.left.equalTo(mBtnClose.snp.right).offset(PADDING)
            make.top.equalTo(barView.snp.top).offset(topBottomMargin)
            make.bottom.equalTo(barView.snp.bottom).offset(-topBottomMargin)
            make.right.equalTo(barView.snp.right).offset(-PADDING)
        }
        
        // 建立 table
        mTableView = UITableView()
        //mTableView.backgroundColor = .white
        self.view.addSubview(mTableView)
        mTableView.delegate = self
        mTableView.dataSource = self
        mTableView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view).inset(UIEdgeInsets(top: barViewHeight + 23 + PADDING, left: PADDING+2, bottom: 0, right: PADDING+2))
        }
        mTableView.rowHeight = 58;
        // ------- 快速搜尋項目 ---------
        initQuickSearchOptions()
        // 顯示鍵盤
        mTextField.becomeFirstResponder()
        
        // 更新 table
        mMode = .InitMode
        // 沒有輸入搜尋文字 - 顯示歷史記錄；如果是 設定 起/迄點模式的話，再加上一個「地圖指定」
        mTableView.reloadData()
    }
    func hideKeyboard() {
        mTextField.resignFirstResponder()
    }
    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initQuickSearchOptions() {
        // 1. 常註的搜尋
        mQuickSearchOptions.append(QuickSearchOption(tag: QUICK_SEARCH_CONVENIENCE_STORE, title:LocalizedString("map.search-nearby-convenience-stores")))
        mQuickSearchOptions.append(QuickSearchOption(tag: QUICK_SEARCH_GAS_STATION, title:LocalizedString("map.search-nearby-gas-stations")))
        mQuickSearchOptions.append(QuickSearchOption(tag: QUICK_SEARCH_LODGING, title:LocalizedString("map.search-nearby-lodging")))
        // History - 從 DB 裡面尋找
        mRecentlyPlaces.removeAll()
        
        do {
            if let places = try RecentlyUsedPlaces.shared.getTop(limit: 10, deleteOther: true) {
                var index = 0
                for place in places {
                    print("place \(index) > \(place)")
                    let option = QuickSearchOption(tag: QUICK_SEARCH_RECENTLY_BASE + index, title:place.name)
                    option.detail = place.address
                    mQuickSearchOptions.append(option)
                    mRecentlyPlaces.append(place)
                    index += 1
                }
            }
        } catch let error as NSError {
            dPrint("getTop > \(error.localizedDescription)")
            showAlertMessage(error.localizedDescription)
        }
    }
    // =========== Autocomplete 地點自動完成 ===========
    // 參考 https://developers.google.com/places/web-service/autocomplete
    // 1秒後才開始搜尋
    func delaySearchAutoComplete(textCount: Int) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        if textCount > 0 {
            var delaySec:TimeInterval = 3  // (預設) 最久 delay 3秒
            // 最短 delay 1秒
            if textCount > 3 {
                delaySec = 1    // 字較多的時候
            }
            self.perform(#selector(searchAutoCompletePlaces), with: nil, afterDelay: delaySec)
        }
    }
    // 搜尋
    @objc func searchAutoCompletePlaces() {
        if let text = mTextField.text!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            GoogleMapService.searchPlaceAutoComplete(text: text, location: location!) { [weak self](places, errMsg) in
                if errMsg == nil {
                    self?.mAutoCompletePlaces.removeAll()
                    self?.mAutoCompletePlaces.append(contentsOf: places)
                    // 呈現搜尋結果
                    self?.mMode = .AutoCompleteResultMode
                    self?.mTableView.reloadData()
                } else {
                    self?.showAlertMessage(errMsg)
                }
            }
        }
    }
    
    func showAlertMessage(_ errMsg: String?) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: LocalizedString("error"), message: errMsg, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: LocalizedString("cancel"), style: .cancel, handler: { (action) in
                
            }))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    // ============== 分類搜尋附近的 Places nearbysearch ============
    func searchPlacesType(_ type:String, title: String) {
        GoogleMapService.searchPlacesType(type, location: location!) { [weak self] (places, errMsg) in
            // 直接跳回地圖、並標註在上面
            if errMsg == nil && places.count > 0 {
                self?.delegate?.searchPlaces(viewController: self!, title: title, foundPlaces: places)
            } else {
                self?.showAlertMessage(errMsg)
            }
        }
    }

    // ============ UITextFieldDelegate ===========
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        //print("textField.text: \(textField.text!)")
        //print("range: \(range.location)")
        //print("string: \(string)")
        if let text = textField.text {
            let newLength = text.utf16.count + string.utf16.count - range.length
            // 不要馬上搜尋
            delaySearchAutoComplete(textCount: newLength)
        }
        return true  // return NO to not change text
    }
    // 按下 Enter Key
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text {
            if text.lengthOfBytes(using: .utf8) > 0 {
                dPrint("馬上搜尋 : \(String(describing: textField.text))")
                NSObject.cancelPreviousPerformRequests(withTarget: self)
                searchAutoCompletePlaces()
            }
        }
        return true
    }
    // clear
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        mMode = .InitMode
        mTableView.reloadData()
        return true
    }
}

extension SearchPlacesViewController: UITableViewDelegate, UITableViewDataSource {
    // ScrollViewDelegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        hideKeyboard()
    }
    // =========================
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = 0
        switch mMode {
        case .InitMode:                 count = mQuickSearchOptions.count
        case .AutoCompleteResultMode:   count = mAutoCompletePlaces.count
        }
        return count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: kPlaceCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: kPlaceCellIdentifier)
        }
        //cell?.contentView.backgroundColor = .white
        switch mMode {
        case .InitMode:
            let option = mQuickSearchOptions[indexPath.row]
            switch option.tag {
            case QUICK_SEARCH_GAS_STATION:
                cell?.imageView?.image = UIImage(named: "SearchGasStation")
                break
            case QUICK_SEARCH_LODGING:
                cell?.imageView?.image = UIImage(named: "SearchLodging")
                break
            case QUICK_SEARCH_CONVENIENCE_STORE:
                cell?.imageView?.image = UIImage(named: "SearchStore")
                break
            default:
                cell?.imageView?.image = UIImage(named: "RecentMarker")
                break
            }
//            if option.tag >= QUICK_SEARCH_RECENTLY_BASE {
//            } else {
//                cell?.imageView?.image = UIImage(named: "SearchIcon")
//            }
            cell?.textLabel?.text = option.title
            cell?.detailTextLabel?.text = option.detail
            break
        case .AutoCompleteResultMode:
            let place = mAutoCompletePlaces[indexPath.row]
            if place.mainAttrubitedText != nil {
                cell?.textLabel?.attributedText = place.mainAttrubitedText
            } else {
                cell?.textLabel?.text = place.mainText
            }
            cell?.detailTextLabel?.text = place.secondaryText
            cell?.imageView?.image = UIImage(named: "RecentMarker")
            break
        }
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if mMode == .InitMode {
            let option = mQuickSearchOptions[indexPath.row]
            switch (option.tag) {
            case QUICK_SEARCH_CONVENIENCE_STORE: searchPlacesType("convenience_store", title:option.title)
            case QUICK_SEARCH_GAS_STATION:       searchPlacesType("gas_station", title:option.title)
            case QUICK_SEARCH_LODGING:           searchPlacesType("lodging", title:option.title)
            default:
                let recentlyIdx = option.tag - QUICK_SEARCH_RECENTLY_BASE
                if recentlyIdx >= 0 {
                    if mRecentlyPlaces.count > recentlyIdx {
                        let place = mRecentlyPlaces[recentlyIdx]
                        delegate?.searchPlaces(viewController: self, recentlyPlace: place)
                    }
                }
                break
            }
        } else if mMode == .AutoCompleteResultMode {
            // TODO : 點選 Place
            //  1. 移往該地
            //  2. 設為 起/迄點
            let place = mAutoCompletePlaces[indexPath.row]
            delegate?.searchPlaces(viewController: self, selectedPlace: place)
        }
    }
//    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        return "Title"
//    }
}
