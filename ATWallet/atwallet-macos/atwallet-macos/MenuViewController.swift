//
//  MenuViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/8/13.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class MenuViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    struct MenuItem {
        let icon: NSImage
        let title: String
        let callback: ((_ menuItem: MenuItem) -> ())?
    }
    
    enum State {
        case none
        case connected
        case loggedIn
    }
    
    @IBOutlet weak var logoImageView: NSImageView!
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var aboutButton: NSButton!
    @IBOutlet weak var disconnectButton: NSButton!
    @IBOutlet weak var settingsButton: NSButton!
    @IBOutlet weak var menuTableView: NSTableView!
    @IBOutlet weak var batteryImageView: NSImageView!
    
    @IBAction func aboutButtonAction(_ sender: Any) {
        AppController.shared.showAbout();
    }
    
    @IBAction func disconnectButtonAction(_ sender: NSButton) {
        AppController.shared.popSplitDetailViewToRootViewController()
    }
    
    @IBAction func settingsButtonAction(_ sender: NSButton) {
        AppController.shared.showSettings(self)
    }
    
    private let SECTION_HDW = 0
    private let SECTION_CRYPTOCURRENCIES = 1
    
    private var hdwMenuItem: MenuItem?
    private var cryptocurrencyMenuItems: [MenuItem] = []
    private var state: State = .none
    private var name: String?
    private var batteryImage: NSImage?
    private var tapCount = 0
    private var lastTapTime = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.aboutButton.alternateImage = self.aboutButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        self.disconnectButton.alternateImage = self.disconnectButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        self.settingsButton.alternateImage = self.settingsButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        #if TESTNET
        self.logoImageView.image = NSImage(named: "TestnetLogo")
        #endif
    }
    
    override func viewWillAppear() {
        self.nameLabel.stringValue = self.name ?? ""
        self.batteryImageView.image = self.batteryImage
    }
    
    override func viewDidDisappear() {
        self.hdwMenuItem = nil
        self.cryptocurrencyMenuItems = []
        self.state = .none
        self.tapCount = 0
    }
    
    override func mouseDown(with event: NSEvent) {
        let eventLocation = event.locationInWindow
        if self.logoImageView.frame.contains(eventLocation), event.clickCount > 20 {
            ATLog.setLogLevel(.debug)
            self.logoImageView.image = NSImage(named: "GoldenLogo")
        }
    }
    
    func setConnected(_ deviceName: String?, _ batteryLevel: UInt?, _ charging: Bool?) {
        self.state = .connected
        self.name = deviceName
        if let batteryLevel = batteryLevel {
            switch batteryLevel {
            case 0:
                self.batteryImage = NSImage(named: "BatteryEmpty")
            case 1..<34:
                self.batteryImage = NSImage(named: "BatteryLow")
            case 34..<67:
                self.batteryImage = NSImage(named: "BatteryMedium")
            case 67..<100:
                self.batteryImage = NSImage(named: "BatteryHigh")
            default:
                self.batteryImage = NSImage(named: "BatteryFull")
            }
        }
        else {
            self.batteryImage = nil
        }
        if charging == true {
            self.batteryImage = NSImage(named: "BatteryCharging")
        }
        
        self.nameLabel.stringValue = (self.name != nil) ? self.name! : ""
        self.batteryImageView.image = self.batteryImage
        self.disconnectButton.isHidden = false
        self.settingsButton.isHidden = true
    }
    
    func setLoggedIn(_ hdwMenuItem: MenuItem, _ cryptocurrencyMenuItems: [MenuItem]) {
        self.state = .loggedIn
        self.hdwMenuItem = hdwMenuItem
        self.cryptocurrencyMenuItems = cryptocurrencyMenuItems
        self.disconnectButton.isHidden = false
        self.settingsButton.isHidden = false
        self.menuTableView.reloadData()
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
        self.state = .none
        self.name = nil
        self.batteryImage = nil
        self.nameLabel.stringValue = ""
        self.batteryImageView.image = nil
        self.disconnectButton.isHidden = true
        self.settingsButton.isHidden = true
    }
    
    func updateDeviceName(_ deviceName: String) {
        self.name = deviceName
        self.nameLabel.stringValue = deviceName
    }
    
    func updateBatteryState(_ batteryLevel: UInt?, _ charging: Bool?) {
        if let batteryLevel = batteryLevel {
            switch batteryLevel {
            case 0:
                self.batteryImage = NSImage(named: "BatteryEmpty")
            case 1..<34:
                self.batteryImage = NSImage(named: "BatteryLow")
            case 34..<67:
                self.batteryImage = NSImage(named: "BatteryMedium")
            case 67..<100:
                self.batteryImage = NSImage(named: "BatteryHigh")
            default:
                self.batteryImage = NSImage(named: "BatteryFull")
            }
        }
        else {
            self.batteryImage = nil
        }
        if charging == true {
            self.batteryImage = NSImage(named: "BatteryCharging")
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
    
    // MARK: - NSTableViewDataSource & NSTableViewDelegate
        
    func numberOfRows(in tableView: NSTableView) -> Int {
        var count = 0
        count += (self.hdwMenuItem != nil) ? 1 : 0
        count += self.cryptocurrencyMenuItems.count
        return count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("MenuItemTableCellView"), owner: self) as? MenuItemTableCellView
        view?.isHidden = false
        if row == 0 {
            view?.titleLabel.stringValue = self.hdwMenuItem?.title ?? ""
            view?.iconImageView.image = self.hdwMenuItem?.icon
        }
        else if (row - 1) < self.cryptocurrencyMenuItems.count {
            view?.titleLabel.stringValue = self.cryptocurrencyMenuItems[row - 1].title
            view?.iconImageView.image = self.cryptocurrencyMenuItems[row - 1].icon
        }
        else {
            view?.isHidden = true
        }
        return view
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let row = tableView.selectedRow
        tableView.deselectAll(self)
        guard row >= 0 else { return }
        if row == 0 {
            if let item = self.hdwMenuItem {
                item.callback?(item)
            }
        }
        else if (row - 1) < self.cryptocurrencyMenuItems.count {
            let item = self.cryptocurrencyMenuItems[row - 1]
            item.callback?(item)
        }
    }
    
}
