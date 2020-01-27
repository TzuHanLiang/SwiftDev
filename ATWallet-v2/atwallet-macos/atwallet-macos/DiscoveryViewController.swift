//
//  DiscoveryViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/8/13.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class DiscoveryViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var deviceTableView: NSTableView!
    
    @IBAction func refreshButtonAction(_ sender: Any) {
        refreshDeviceList()
    }
    
    private var deviceList: [ATDevice] = []
    private var deviceUpdateTimestamp: [ATDevice: Date] = [:]
    private var refreshTimer: Timer!
    
    private lazy var scanCallback: AppController.ScanCallback = { (device, found) in
        if found {
            if let index = self.deviceList.firstIndex(of: device) {
                self.deviceTableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
            }
            else {
                self.deviceList.append(device)
                self.deviceTableView.reloadData()
            }
            self.deviceUpdateTimestamp[device] = Date()
        }
        else if let index = self.deviceList.firstIndex(of: device) {
            self.deviceList.remove(at: index)
            self.deviceUpdateTimestamp[device] = nil
            self.deviceTableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.titleLabel.stringValue = NSLocalizedString("discovery", comment: "")
        self.refreshButton.alternateImage = self.refreshButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
    }
    
    override func viewWillAppear() {
        self.descriptionLabel.stringValue = ""
        AppController.shared.disconnect()
        //AppController.shared.stopScan() // WORKAROUND: to let bluetooth updates state
        self.deviceList.removeAll()
        self.deviceUpdateTimestamp.removeAll()
        self.deviceTableView.reloadData()
    }
    
    override func viewWillDisappear() {
        AppController.shared.stopScan()
        self.refreshTimer.invalidate()
    }
    
    override func viewDidAppear() {
        AppController.shared.scan(self.scanCallback)
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true, block: { (timer) in
            guard self.deviceList.count > 0 else { return }
            for device in self.deviceList {
                guard device.deviceType == .ble, let timestamp = self.deviceUpdateTimestamp[device] else { continue }
                if abs(timestamp.timeIntervalSinceNow) > 15 {
                    self.deviceUpdateTimestamp.removeValue(forKey: device)
                    if let index = self.deviceList.firstIndex(of: device) {
                        self.deviceList.remove(at: index)
                    }
                }
            }
            self.deviceTableView.reloadData()
        })
    }
    
    private func refreshDeviceList() {
        AppController.shared.stopScan()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.deviceList.removeAll()
            self.deviceUpdateTimestamp.removeAll()
            self.deviceTableView.reloadData()
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            AppController.shared.scan(self.scanCallback)
        }
    }
    
    // MARK: - NSTableViewDataSource & NSTableViewDelegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.deviceList.count
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("DeviceTableCellView"), owner: self) as? DeviceTableCellView
        view?.isHidden = true
        guard self.deviceList.count > row else { return view }
        let device = self.deviceList[row]
        view?.isHidden = false
        view?.nameLabel.stringValue = device.name
        view?.signalLabel.stringValue = ""
        view?.typeImageView.image = NSImage(named: "USB")
        if device.deviceType == .ble, let rssi = device.attributes[ATDevice.ATTR_RSSI] as? Int {
            view?.signalLabel.stringValue = "\(rssi) dBm"
            if let pairingMode = device.attributes[ATDevice.ATTR_PAIRING_MODE] as? Bool {
                view?.typeImageView.image = NSImage(named: pairingMode ? "BluetoothHighlight" : "Bluetooth")
            }
        }
        return view
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        AppController.shared.showBusyPrompt("connecting".localizedString)
        guard let tableView = notification.object as? NSTableView, tableView.selectedRowIndexes.count > 0 else { return }
        let row = tableView.selectedRow
        tableView.deselectAll(self)
        guard row >= 0 else { return }
        guard row < self.deviceList.count else { return }
        let device = self.deviceList[row]
        AppController.shared.stopScan()
        AppController.shared.connect(device) { (succeeded, error) in
            (error != nil) ? ATLog.debug(error!.description) : nil
            guard succeeded else {
                AppController.shared.hideBusyPrompt()
                AppController.shared.showAlert("\("failed_to_connect_to".localizedString) \(device.name)", nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                    self.refreshDeviceList()
                })])
                return
            }
            AppController.shared.hasColdWalletEnrolledFingerprint { (enrolled, error) in
                AppController.shared.hideBusyPrompt()
                guard error == nil, let enrolled = enrolled else {
                    ATLog.debug(error!.description)
                    AppController.shared.disconnect()
                    AppController.shared.showAlert("\("failed_to_connect_to".localizedString) \(device.name)", nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        self.refreshDeviceList()
                    })])
                    return
                }
                if enrolled {
                    AppController.shared.pushSplitDetailView(.Login) { (vc) in
                        guard let loginVC = vc as? LoginViewController else { return }
                        loginVC.hdwIndex = .any
                    }
                }
                else {
                    AppController.shared.pushSplitDetailView(.FingerprintEnrollment)
                }
            }
        }
    }
    
}
