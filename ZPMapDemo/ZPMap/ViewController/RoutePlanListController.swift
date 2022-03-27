//
//  RoutePlanListController.swift
//
//  Created by EddieHua.
//

import UIKit
import CoreLocation


fileprivate let kRouteCellIdentifier = "routeCell"

// 為了解決 detailTextLabel 的內容讓 可變高度 Cell 失效的狀況
class ZPTableViewCell : UITableViewCell {
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        self.layoutIfNeeded()
        var size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority)
        
        if (self.detailTextLabel != nil) {
            let detailHeight = self.detailTextLabel!.frame.height
            if self.detailTextLabel!.frame.origin.x > self.textLabel!.frame.origin.x {
                // style = Value1 or Value2
                let textHeight = self.textLabel!.frame.height
                if detailHeight > textHeight {
                    size.height += detailHeight - textHeight
                }
            } else {
                size.height += detailHeight;
            }
        }
        return size
    }
}

// TODO: 將 RoutePlan 處理成 Table 要顯示的 Item?
// 還是 一個 Leg 就是一個 section，一個 Step 就是一個 Cell
class RoutePlanListController : UITableViewController {
    var routePlan:RoutePlan?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
        self.tableView.estimatedRowHeight = 80;
        self.tableView.rowHeight = UITableView.automaticDimension;
        resumeNotifications()
    }
    
    deinit {
        suspendNotifications()
    }
    
    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(notification:)), name: NaviProgressDidChange, object: nil)
        //NotificationCenter.default.addObserver(self, selector: #selector(alertLevelDidChange(notification:)), name: RouteControllerAlertLevelDidChange, object: routeController)
    }
    
    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: NaviProgressDidChange, object: nil)
        //NotificationCenter.default.removeObserver(self, name: RouteControllerAlertLevelDidChange, object: routeController)
    }
    
    @objc func progressDidChange(notification: NSNotification) {
        // 距離提示點多遠
        let nextStep = notification.userInfo![NaviNextStep] as? RouteStep
        let distance = notification.userInfo![NaviDistanceToNextStep] as? CLLocationDistance
        dPrint("NaviStepManeuverDistance = \(String(describing: distance))")
        //mapViewController?.notifyDidChange(routeProgress: routeProgress, location: location, secondsRemaining: secondsRemaining)
        //tableViewController?.notifyDidChange(routeProgress: routeProgress)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    /// MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        if routePlan != nil {
            return routePlan!.legs.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return routePlan!.legs[section].steps.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ZPTableViewCell? = tableView.dequeueReusableCell(withIdentifier: kRouteCellIdentifier) as? ZPTableViewCell
        if cell == nil {
            cell = ZPTableViewCell(style: .subtitle, reuseIdentifier: kRouteCellIdentifier)
            //cell!.selectionStyle = .none
            cell!.textLabel?.font = UIFont.systemFont(ofSize: 24)
            cell!.textLabel?.numberOfLines = 0
            // - font size 對 attributedText沒用
            cell!.detailTextLabel?.font = UIFont.systemFont(ofSize: 18)
            cell!.detailTextLabel?.numberOfLines = 0
        }
        let step:RouteStep = routePlan!.legs[indexPath.section].steps[indexPath.row]
        
        if step.attrInstructions != nil {
            cell!.textLabel?.attributedText = step.attrInstructions // 會把轉彎提示及路名變粗體
        } else {
            cell!.textLabel?.text = step.instructions
        }
        cell?.imageView?.image = step.maneuver.icon()
        if step.maneuver != .destination {
            cell!.detailTextLabel?.text = ZPMapCommon.textDistanceFormatter.string(from: Double(step.distanceM))
        } else {
            if step.otherMessage != nil {
                cell!.detailTextLabel?.text = step.otherMessage
            }
        }
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath
    }
}
