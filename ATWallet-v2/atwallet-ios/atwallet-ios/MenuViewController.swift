//
//  MenuViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class MenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    struct MenuItem {
        let icon: UIImage
        let title: String
        let callback: ((_ menuItem: MenuItem) -> ())?
    }
    
    enum State {
        case none
        case connected
        case loggedIn
    }
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var batteryImageView: UIImageView!
    @IBOutlet var menuTableView: UITableView!
    @IBOutlet var aboutButton: UIButton!
    @IBOutlet var disconnectButton: UIButton!
    @IBOutlet var settingsButton: UIButton!
    
    @IBAction func aboutButtonAction(_ sender: Any) {
        AppController.shared.showAbout(self);
    }
    
    @IBAction func disconnectButtonAction(_ sender: UIButton) {
        AppController.shared.popSplitDetailViewToRootViewController()
    }
    
    @IBAction func settingsButtonAction(_ sender: UIButton) {
        AppController.shared.showSettings(self)
    }
    
    private let SECTION_HDW = 0
    private let SECTION_CRYPTOCURRENCIES = 1
    private let SECTION_SETTINGS = 2
    private let SECTION_LOGOUT = 3
    private let SECTION_ABOUT = 4
    
    private var hdwMenuItem: MenuItem?
    private var cryptocurrencyMenuItems: [MenuItem] = []
    private var state: State = .none
    private var name: String?
    private var batteryImage: UIImage?
    private var tapCount = 0
    private var lastTapTime = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(tapDetected))
        singleTap.numberOfTapsRequired = 1
        self.logoImageView.isUserInteractionEnabled = true
        self.logoImageView.addGestureRecognizer(singleTap)
        
        if AppController.shared.isUsingPadUI {
            AppController.shared.setSplitMasterViewController(self)
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetWalletLogo")
#endif
        }
        else {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.nameLabel.text = self.name
        self.batteryImageView.image = self.batteryImage
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.hdwMenuItem = nil
        self.cryptocurrencyMenuItems = []
        self.state = .none
        self.tapCount = 0
    }
    
    @objc func tapDetected() {
        let now = Date()
        if now.timeIntervalSince(self.lastTapTime) > 1 {
            self.tapCount = 0
        }
        self.lastTapTime = now
        self.tapCount += 1
        if self.tapCount == 20 {
            ATLog.setLogLevel(.debug)
            self.logoImageView.image = UIImage(named: "GoldenLogo")
        }
    }
    
    func setConnected(_ deviceName: String?, _ batteryLevel: UInt?, _ charging: Bool?) {
        self.state = .connected
        self.name = deviceName
        if let batteryLevel = batteryLevel {
            switch batteryLevel {
            case 0:
                self.batteryImage = UIImage(named: "BatteryEmpty")
            case 1..<34:
                self.batteryImage = UIImage(named: "BatteryLow")
            case 34..<67:
                self.batteryImage = UIImage(named: "BatteryMedium")
            case 67..<100:
                self.batteryImage = UIImage(named: "BatteryHigh")
            default:
                self.batteryImage = UIImage(named: "BatteryFull")
            }
        }
        else {
            self.batteryImage = nil
        }
        if charging == true {
            self.batteryImage = UIImage(named: "BatteryCharging")
        }
        
        if AppController.shared.isUsingPadUI {
            self.nameLabel.text = self.name
            self.batteryImageView.image = self.batteryImage
            self.disconnectButton.isHidden = false
            self.settingsButton.isHidden = true
        }
    }
    
    func setLoggedIn(_ hdwMenuItem: MenuItem, _ cryptocurrencyMenuItems: [MenuItem]) {
        self.state = .loggedIn
        self.hdwMenuItem = hdwMenuItem
        self.cryptocurrencyMenuItems = cryptocurrencyMenuItems
        if AppController.shared.isUsingPadUI {
            self.disconnectButton.isHidden = false
            self.settingsButton.isHidden = false
            self.menuTableView.reloadData()
        }
    }
    
    func setloggedOut() {
        self.state = .connected
        self.hdwMenuItem = nil
        self.cryptocurrencyMenuItems = []
        self.disconnectButton.isHidden = false
        self.settingsButton.isHidden = true
        self.menuTableView.reloadData()
    }
    
    func setDisconnected() {
        setloggedOut()
        self.state = .none
        self.name = nil
        self.batteryImage = nil
        self.nameLabel.text = nil
        self.batteryImageView.image = nil
        self.disconnectButton.isHidden = true
        self.settingsButton.isHidden = true
    }
    
    func updateDeviceName(_ deviceName: String) {
        self.name = deviceName
        self.nameLabel.text = deviceName
    }
        
    func updateBatteryState(_ batteryLevel: UInt?, _ charging: Bool?) {
        if let batteryLevel = batteryLevel {
            switch batteryLevel {
            case 0:
                self.batteryImage = UIImage(named: "BatteryEmpty")
            case 1..<34:
                self.batteryImage = UIImage(named: "BatteryLow")
            case 34..<67:
                self.batteryImage = UIImage(named: "BatteryMedium")
            case 67..<100:
                self.batteryImage = UIImage(named: "BatteryHigh")
            default:
                self.batteryImage = UIImage(named: "BatteryFull")
            }
        }
        else {
            self.batteryImage = nil
        }
        if charging == true {
            self.batteryImage = UIImage(named: "BatteryCharging")
        }
        self.batteryImageView.image = self.batteryImage
    }
    
    func updateHDWalletMenuItem(_ menuItem: MenuItem) {
        self.hdwMenuItem = menuItem
        self.menuTableView.reloadData()
        self.settingsButton.isHidden = false
    }
    
    func updateCryptocurrencyMenuItems(_ menuItems: [MenuItem]) {
        self.cryptocurrencyMenuItems = menuItems
        self.menuTableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return AppController.shared.isUsingPadUI ? 2 : 5
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case SECTION_HDW:
            return (self.state == .loggedIn) ? 1 : 0
        case SECTION_CRYPTOCURRENCIES:
            return self.cryptocurrencyMenuItems.count
        case SECTION_SETTINGS:
            return (self.state == .loggedIn) ? 1 : 0
        case SECTION_LOGOUT:
            return (self.state != .none) ? 1 : 0
        case SECTION_ABOUT:
            return 1
        default:
            return 0
        }
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuItemTableViewCell") as! MenuItemTableViewCell
        cell.isHidden = false
        switch indexPath.section {
        case SECTION_HDW:
            cell.titleLabel.text = self.hdwMenuItem?.title
            cell.iconImageView.image = self.hdwMenuItem?.icon
        case SECTION_CRYPTOCURRENCIES:
            cell.titleLabel.text = self.cryptocurrencyMenuItems[indexPath.row].title
            cell.iconImageView.image = self.cryptocurrencyMenuItems[indexPath.row].icon
        case SECTION_SETTINGS:
            cell.titleLabel.text = NSLocalizedString("settings", comment: "")
            cell.iconImageView.image = UIImage(named: "Settings")
        case SECTION_LOGOUT:
            cell.titleLabel.text = NSLocalizedString((self.state == .connected) ? "disconnect" : "logout", comment: "")
            cell.iconImageView.image = UIImage(named: "Disconnect")
        case SECTION_ABOUT:
            cell.titleLabel.text = NSLocalizedString("about", comment: "")
            cell.iconImageView.image = UIImage(named: "Info")
        default:
            cell.isHidden = true
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !AppController.shared.isUsingPadUI {
            self.dismiss(animated: true, completion: nil)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case SECTION_HDW:
            if let item = self.hdwMenuItem {
                item.callback?(item)
            }
        case SECTION_CRYPTOCURRENCIES:
            guard self.cryptocurrencyMenuItems.count > indexPath.row else { return }
            let item = self.cryptocurrencyMenuItems[indexPath.row]
            item.callback?(item)
        case SECTION_SETTINGS:
            AppController.shared.showSettings(self.presentingViewController!);
        case SECTION_LOGOUT:
            AppController.shared.popToRootViewController(self.presentingViewController!)
        case SECTION_ABOUT:
            AppController.shared.showAbout(self.presentingViewController!);
        default:
            break
        }
    }

}
