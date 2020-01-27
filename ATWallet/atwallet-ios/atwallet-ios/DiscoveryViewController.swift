//
//  DiscoveryViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/8.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class DiscoveryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var deviceTableView: UITableView!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func refreshButtonAction(_ sender: Any) {
        refreshDeviceList()
    }
    
    private var refreshControl: UIRefreshControl!
    private var deviceList: [ATDevice] = []
    private var deviceUpdateTimestamp: [ATDevice: Date] = [:]
    private var refreshTimer: Timer!
    
    private lazy var btOnOffStateCallback: AppController.BluetoothOnOffStateCallback = { (on) in
        guard self.navigationController?.topViewController == self else { return }
        if on {
            self.descriptionLabel.text = nil
            AppController.shared.scan(self.scanCallback)
        }
        else {
            self.descriptionLabel.text = NSLocalizedString("please_turn_on_bluetooth", comment: "")
            AppController.shared.stopScan()
        }
        self.deviceList.removeAll()
        self.deviceUpdateTimestamp.removeAll()
        self.deviceTableView.reloadData()
    }
    
    private lazy var scanCallback: AppController.ScanCallback = { (device) in
        if let index = self.deviceList.firstIndex(of: device) {
            self.deviceTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
        else {
            self.deviceList.append(device)
            self.deviceTableView.reloadData()
        }
        self.deviceUpdateTimestamp[device] = Date()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.setHidesBackButton(true, animated: true)
        self.titleLabel.text = NSLocalizedString("discovery", comment: "")
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: #selector(refreshDeviceList), for: .valueChanged)
        self.deviceTableView.addSubview(self.refreshControl)
        
        if AppController.shared.isUsingPadUI {
            AppController.shared.setSplitDetailViewNavigationController(self.navigationController!)
        }
        else {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
        
        AppController.shared.registerBluetoothOnOffStateCallback(self.btOnOffStateCallback)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.descriptionLabel.text = nil
        AppController.shared.disconnect()
        AppController.shared.stopScan() // WORKAROUND: to let bluetooth updates state
        self.deviceList.removeAll()
        self.deviceUpdateTimestamp.removeAll()
        self.deviceTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppController.shared.stopScan()
        self.refreshTimer.invalidate()
    }

    override func viewDidAppear(_ animated: Bool) {
        self.descriptionLabel.text = nil
        if AppController.shared.isBluetoothOn {
            AppController.shared.scan(self.scanCallback)
        }
        else {
            self.descriptionLabel.text = NSLocalizedString("please_turn_on_bluetooth", comment: "")
        }
        
        self.refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true, block: { (timer) in
            guard self.deviceList.count > 0 else { return }
            for device in self.deviceList {
                guard let timestamp = self.deviceUpdateTimestamp[device] else { continue }
                if abs(timestamp.timeIntervalSinceNow) > 15 {
                    self.deviceUpdateTimestamp.removeValue(forKey: device)
                    if let index = self.deviceList.firstIndex(of: device) {
                        self.deviceList.remove(at: index)
                    }
                }
            }
            if self.deviceList.count == 0 {
                self.deviceTableView.reloadData()
            }
        })
    }
    
    @objc private func refreshDeviceList() {
        AppController.shared.stopScan()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.deviceList.removeAll()
            self.deviceUpdateTimestamp.removeAll()
            self.deviceTableView.reloadData()
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            self.refreshControl.endRefreshing()
            AppController.shared.scan(self.scanCallback)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? LoginViewController {
            vc.hdwIndex = .any
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.deviceList.count
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceTableViewCell") as! DeviceTableViewCell
        guard self.deviceList.count > indexPath.row else {
            cell.isHidden = true
            return cell
        }
        let device = self.deviceList[indexPath.row]
        cell.isHidden = false
        cell.nameLabel.text = device.name
        cell.signalLabel.text = nil
        if let rssi = device.attributes[ATDevice.ATTR_RSSI] as? Int {
            cell.signalLabel.text = "\(rssi) dBm"
        }
        if let pairingMode = device.attributes[ATDevice.ATTR_PAIRING_MODE] as? Bool, pairingMode == true {
            cell.typeImageView.image = UIImage(named: "BluetoothHighlight")
        }
        else {
            cell.typeImageView.image = UIImage(named: "Bluetooth")
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        AppController.shared.showBusyPrompt(self, NSLocalizedString("connecting", comment: ""))
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < self.deviceList.count else { return }
        let device = self.deviceList[indexPath.row]
        AppController.shared.stopScan()
        AppController.shared.connect(device) { (succeeded, error) in
            (error != nil) ? ATLog.debug("\(error!.description)") : nil
            guard succeeded else {
                AppController.shared.hideBusyPrompt(self)
                AppController.shared.showAlert(self, "\(NSLocalizedString("failed_to_connect_to", comment: "")) \(device.name)", nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default) { (action) in
                    self.refreshDeviceList()
                }])
                return
            }
            AppController.shared.hasColdWalletEnrolledFingerprint { (enrolled, error) in
                AppController.shared.hideBusyPrompt(self)
                guard error == nil, let enrolled = enrolled else {
                    ATLog.debug(error!.description)
                    AppController.shared.disconnect()
                    AppController.shared.showAlert(self, "\(NSLocalizedString("failed_to_connect_to", comment: "")) \(device.name)", nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default) { (action) in
                        self.refreshDeviceList()
                    }])
                    return
                }
                if enrolled {
                    self.performSegue(withIdentifier: "LoginSegue", sender: self)
                }
                else {
                    self.performSegue(withIdentifier: "FingerprintEnrollmentSegue", sender: self)
                }
            }
        }
    }
}

