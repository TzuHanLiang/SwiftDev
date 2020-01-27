//
//  AppController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Foundation
import UIKit
import SideMenu
import ATWalletKit
import MBProgressHUD
import QRCode

class AppController: NSObject, ATDeviceManagerDelegate, ATDeviceDelegate, ATCryptocurrencyWalletDelegate {
    
    typealias BluetoothOnOffStateCallback = ((_ on: Bool) -> ())
    typealias ScanCallback = ((_ device: ATDevice) -> ())
    typealias CompletionCallback = ((_ succeeded: Bool, _ error: ATError?) -> ())
    typealias CryptocurrencyWalletStateChangedCallback = (@convention(block) (_ wallet: ATCryptocurrencyWallet) -> ())
    typealias TransactionCompletionCallback = ((_ succeeded: Bool, _ transaction: ATCryptocurrencyTransaction?, _ error: ATError?) -> ())
    
    public static var shared: AppController {
        get { return self.instance }
    }
    
    public var isBluetoothOn: Bool {
        get { return self.bleDeviceManager.state == .btOn }
    }
    
    public var appleDeviceType: UIUserInterfaceIdiom {
        get { return UIDevice.current.userInterfaceIdiom }
    }
    
    var isUsingPadUI: Bool = false
    
    private static let instance: AppController = AppController()
    private let uniqueId: UUID
    private let bleDeviceManager: ATBLEDeviceManager
    private var btOnOffStateCallback: BluetoothOnOffStateCallback?
    private var scanCallback: ScanCallback?
    private var connectCallback: CompletionCallback?
    private var coldWallet: ATColdWallet?
    private var navigationController: UINavigationController?
    private var splitMenuViewController: MenuViewController?
    private var allHuds: [UIView: MBProgressHUD] = [:]
    private var registeredCryptocurrencyWalletStateChangedCallbacks: [CryptocurrencyWalletStateChangedCallback] = []
    private var prepareSigningCallback: TransactionCompletionCallback?
    private var signTransactionCallback: TransactionCompletionCallback?
    private var publishTransactionCallback: TransactionCompletionCallback?
    
    private override init() {
        let userDefaults = UserDefaults.standard
        if let uid = userDefaults.object(forKey: "APP_UID") as? [UInt8], uid.count == 16 {
            self.uniqueId = UUID(uuid: (uid[0], uid[1], uid[2], uid[3], uid[4], uid[5], uid[6], uid[7],
                                        uid[8], uid[9], uid[10], uid[11], uid[12], uid[13], uid[14], uid[15]))
        }
        else if let identifier = UIDevice.current.identifierForVendor {
            self.uniqueId = identifier
            let uuid = identifier.uuid
            let uid = [uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7, uuid.8, uuid.9, uuid.10, uuid.11, uuid.12, uuid.13, uuid.14, uuid.15]
            userDefaults.set(uid, forKey: "APP_UID")
            userDefaults.synchronize()
        }
        else {
            var uid = [UInt8](repeating: 0, count: 16)
            if SecRandomCopyBytes(kSecRandomDefault, uid.count * MemoryLayout<UInt8>.size, &uid) != errSecSuccess {
                for index in 0..<uid.count where (index % 4) == 0 {
                    let randomValue = arc4random()
                    uid[index] = UInt8((randomValue >> 24) & 0xFF)
                    uid[index + 1] = UInt8((randomValue >> 16) & 0xFF)
                    uid[index + 2] = UInt8((randomValue >> 8) & 0xFF)
                    uid[index + 3] = UInt8(randomValue & 0xFF)
                }
            }
            self.uniqueId = UUID(uuid: (uid[0], uid[1], uid[2], uid[3], uid[4], uid[5], uid[6], uid[7],
                                        uid[8], uid[9], uid[10], uid[11], uid[12], uid[13], uid[14], uid[15]))
            userDefaults.set(uid, forKey: "APP_UID")
            userDefaults.synchronize()
        }
        self.bleDeviceManager = ATBLEDeviceManager.shared
        super.init()
        self.bleDeviceManager.delegate = self
        
        // update exchange rates
        let exchangeRates = ATExchangeRates()
        let defaultCurrencyUnit = AppConfig.shared.defaultCurrencyUnit
        for cryptocurrency in ATCryptocurrencyType.allCases {
            exchangeRates.cryptocurrencyToCurrency(cryptocurrency.symbol, defaultCurrencyUnit) { (rate) in
                // do nothing
            }
        }
    }
        
    private func updateSplitMasterViewLoggedInState() {
        guard AppController.shared.isUsingPadUI else { return }
#if TESTNET
        let icon = UIImage(named: "CircleTestnetAppIcon")
#else
        let icon = UIImage(named: "CircleAppIcon")
#endif
        let hdwMenuItem = MenuViewController.MenuItem(icon: icon ?? UIImage(), title: self.coldWallet?.hdwallet?.name ?? "wallet".localizedString) { (menuItem) in
            guard self.navigationController?.topViewController as? WalletViewController == nil else { return }
            for vc in self.navigationController?.viewControllers ?? [] {
                if vc as? WalletViewController != nil {
                    self.navigationController?.popToViewController(vc, animated: true)
                    break
                }
            }
        }
        var cryptocurrencyMenuItems: [MenuViewController.MenuItem] = []
        for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
            let menuItem = MenuViewController.MenuItem(icon: UIImage(named: wallet.currencyType.symbol) ?? UIImage(), title: wallet.name) { (menuItem) in
                if let vc = self.navigationController?.topViewController as? TransactionViewController, vc.cryptocurrency == wallet {
                    return
                }
                
                if self.navigationController?.topViewController as? WalletViewController == nil {
                    for vc in self.navigationController?.viewControllers ?? [] {
                        if vc as? WalletViewController != nil {
                            self.navigationController?.popToViewController(vc, animated: false)
                            break
                        }
                    }
                }
                if let vc = self.navigationController?.topViewController as? WalletViewController {
                    vc.selectedCryptocurrency = wallet
                    vc.performSegue(withIdentifier: "TransactionSegue", sender: vc)
                }
            }
            cryptocurrencyMenuItems.append(menuItem)
        }
        self.splitMenuViewController?.setLoggedIn(hdwMenuItem, cryptocurrencyMenuItems)
    }
    
    func setSplitMasterViewController(_ viewController: MenuViewController) {
        self.splitMenuViewController = viewController
    }
    
    func setSplitDetailViewNavigationController(_ navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func popToRootViewController(_ target: UIViewController) {
        (target.navigationController != nil) ? self.navigationController = target.navigationController : nil
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    func popSplitDetailViewToRootViewController() {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    func showBusyPrompt(_ target: UIViewController, _ message: String?, _ progress: Float? = nil, _ details: String? = nil) {
        var progressHud: MBProgressHUD
        if let hud = self.allHuds[target.view], hud.superview != nil {
            hud.label.text = message
            progressHud = hud
        }
        else {
            UIApplication.shared.beginIgnoringInteractionEvents()
            let hud = MBProgressHUD.showAdded(to: target.view, animated: true)
            hud.label.text = message
            self.allHuds[target.view] = hud
            progressHud = hud
        }
        if let progress = progress {
            progressHud.mode = .determinateHorizontalBar
            progressHud.progress = progress
        }
        progressHud.detailsLabel.text = details
    }
    
    func hideBusyPrompt(_ target: UIViewController) {
        UIApplication.shared.endIgnoringInteractionEvents()
        MBProgressHUD.hide(for: target.view, animated: true)
    }
    
    func showAlert(_ target: UIViewController, _ title: String?, _ message: String?, _ actions: [UIAlertAction]? = nil , _ subView: UIView? = nil, _ titleAlignment: NSTextAlignment? = nil, _ messageAlignment: NSTextAlignment? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        var actions = actions
        (actions == nil) ? actions = [UIAlertAction(title: "ok".localizedString, style: .default, handler: nil)] : nil
        actions?.forEach({ (action) in
            alertController.addAction(action)
        })
        if let subView = subView {
            let vc = UIViewController()
            vc.preferredContentSize = subView.frame.size
            vc.view.addSubview(subView)
            alertController.setValue(vc, forKey: "contentViewController")
        }
        if let alignment = titleAlignment {
            (title != nil) ? alertController.setTitleAlignment(alignment) : nil
        }
        if let alignment = messageAlignment {
            (message != nil) ? alertController.setMessageAlignment(alignment) : nil
        }
        target.present(alertController, animated: true, completion: nil)
        UIApplication.shared.endIgnoringInteractionEvents()
    }
    
    func showMenu(_ target: UIViewController) {
        (target.navigationController != nil) ? self.navigationController = target.navigationController : nil
        let menuViewController = target.storyboard!.instantiateViewController(withIdentifier: "MenuViewController")
        if let menuViewController = menuViewController as? MenuViewController {
            if let coldWallet = self.coldWallet {
                menuViewController.setConnected(coldWallet.name, coldWallet.batteryLevel, coldWallet.batteryCharging)
            }
            if let hdw = self.coldWallet?.hdwallet, let wallets = hdw.wallets {
#if TESTNET
                let icon = UIImage(named: "CircleTestnetAppIcon")
#else
                let icon = UIImage(named: "CircleAppIcon")
#endif
                let hdwMenuItem = MenuViewController.MenuItem(icon: icon ?? UIImage(), title: hdw.name ?? "wallet".localizedString) { (menuItem) in
                    guard self.navigationController?.topViewController as? WalletViewController == nil else { return }
                    for vc in self.navigationController?.viewControllers ?? [] {
                        if vc as? WalletViewController != nil {
                            self.navigationController?.popToViewController(vc, animated: true)
                            break
                        }
                    }
                }
                var cryptocurrencyMenuItems: [MenuViewController.MenuItem] = []
                for wallet in wallets {
                    let menuItem = MenuViewController.MenuItem(icon: UIImage(named: wallet.currencyType.symbol) ?? UIImage(), title: wallet.name) { (menuItem) in
                        if let vc = self.navigationController?.topViewController as? TransactionViewController, vc.cryptocurrency == wallet {
                            return
                        }
                        
                        if self.navigationController?.topViewController as? WalletViewController == nil {
                            for vc in self.navigationController?.viewControllers ?? [] {
                                if vc as? WalletViewController != nil {
                                    self.navigationController?.popToViewController(vc, animated: false)
                                    break
                                }
                            }
                        }
                        if let vc = self.navigationController?.topViewController as? WalletViewController {
                            vc.selectedCryptocurrency = wallet
                            vc.performSegue(withIdentifier: "TransactionSegue", sender: vc)
                        }
                    }
                    cryptocurrencyMenuItems.append(menuItem)
                }
                menuViewController.setLoggedIn(hdwMenuItem, cryptocurrencyMenuItems)
            }
        }
        
        let menu = SideMenuNavigationController(rootViewController: menuViewController)
        menu.navigationBar.isHidden = true
        menu.presentationStyle = .menuSlideIn
        menu.statusBarEndAlpha = 0
        target.definesPresentationContext = true
        target.present(menu, animated: true, completion: nil)
    }
    
    func showAbout(_ target: UIViewController) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "???"
        let alertController = UIAlertController(title: Bundle.main.displayName, message: "\("app_version".localizedString) \(version)\n\n\(NSLocalizedString("copyright", comment: ""))\n\n\(NSLocalizedString("atwallet_url", comment: ""))\n\n\(self.uniqueId.uuidString)", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil)
        alertController.addAction(alertAction)
        target.present(alertController, animated: true, completion: nil)
    }
    
    func showSettings(_ target: UIViewController) {
        (target.navigationController != nil) ? self.navigationController = target.navigationController : nil
        if let _ = self.navigationController?.topViewController as? SettingsViewController { return }
        guard let settingsViewController = target.storyboard!.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else { return }
        self.navigationController?.pushViewController(settingsViewController, animated: true)
    }
    
    func setAutoLock(_ enabled: Bool) {
        struct Counter {
            static var count = 0
        }
        
        if enabled {
            (Counter.count > 0) ? Counter.count -= 1 : nil
            if Counter.count == 0 {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
        else {
            Counter.count += 1
            if Counter.count == 1 {
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
        }
    }
        
    func scan(_ callback: @escaping ScanCallback) {
        guard self.bleDeviceManager.state == .btOn else { return }
        self.scanCallback = callback
        self.bleDeviceManager.scan()
    }
    
    func connect(_ device: ATDevice, _ callback: @escaping CompletionCallback) {
        self.connectCallback = callback
        device.delegate = self
        device.connect()
    }
    
    func disconnect() {
        if self.coldWallet?.loggedIn ?? false {
            coldWalletLogout { (loggedOut, error) in
                self.coldWallet?.disconnect()
                self.coldWallet = nil
                self.splitMenuViewController?.setDisconnected()
            }
        }
        else {
            self.coldWallet?.disconnect()
            self.coldWallet = nil
            self.splitMenuViewController?.setDisconnected()
        }
    }
    
    func stopScan() {
        self.bleDeviceManager.stopScan()
    }
    
    func registerBluetoothOnOffStateCallback(_ callback: BluetoothOnOffStateCallback?) {
        self.btOnOffStateCallback = callback
    }
    
    func registerCryptocurrencyWalletStateChangedCallback(_ callback: @escaping CryptocurrencyWalletStateChangedCallback) {
        let callbackObj = unsafeBitCast(callback, to: AnyObject.self)
        var contained = false
        for registeredCallback in registeredCryptocurrencyWalletStateChangedCallbacks {
            let registeredCallbackObj = unsafeBitCast(registeredCallback, to: AnyObject.self)
            if callbackObj === registeredCallbackObj {
                contained = true
                break
            }
        }
        if !contained {
            registeredCryptocurrencyWalletStateChangedCallbacks.append(callback)
        }
    }
    
    func unregisterCryptocurrencyWalletStateChangedCallback(_ callback: @escaping CryptocurrencyWalletStateChangedCallback) {
        let callbackObj = unsafeBitCast(callback, to: AnyObject.self)
        var callbackIndex: Int?
        for index in 0..<registeredCryptocurrencyWalletStateChangedCallbacks.count {
            let registeredCallbackObj = unsafeBitCast(registeredCryptocurrencyWalletStateChangedCallbacks[index], to: AnyObject.self)
            if callbackObj === registeredCallbackObj {
                callbackIndex = index
                break
            }
        }
        if let index = callbackIndex {
            _ = registeredCryptocurrencyWalletStateChangedCallbacks.remove(at: index)
        }
    }
    
    func notifyCryptocurrencyWalletStateChanged(_ wallet: ATCryptocurrencyWallet) {
        for callback in registeredCryptocurrencyWalletStateChangedCallbacks {
            DispatchQueue.main.async {
                callback(wallet)
            }
        }
    }
    
    func generateAddressQRCode(_ cryptocurrencyType: ATCryptocurrencyType,_ address: String, _ size: CGSize) -> UIImage? {
        var uri = address
        if !uri.hasPrefix(cryptocurrencyType.scheme), cryptocurrencyType != .bch {
            uri = "\(cryptocurrencyType.scheme):\(address)"
        }
        var qrCode = QRCode(uri)
        qrCode?.size = size
        return qrCode?.image
    }
    
    func checkSendingAddressValidity(_ cryptocurrency: ATCryptocurrencyWallet, _ address: String) -> Bool {
        guard cryptocurrency.checkAddressValidity(address) else {
            ATLog.debug("Invalid address: \(address)")
            return false
        }
        guard !cryptocurrency.containAddress(address) else {
            ATLog.debug("Invalid address for sending out: \(address)")
            return false
        }
        return true
    }
    
    func parseQRCodeAddress(_ cryptocurrency: ATCryptocurrencyWallet, _ text: String) -> String? {
        var address = text
        if address.contains(":"), let scheme = address.split(separator: ":").first, String(scheme) != cryptocurrency.currencyType.scheme  {
            return nil
        }
        address.contains(":") ? address = String(address.split(separator: ":")[1]) : nil
        address.contains("?") ? address = String(address.split(separator: "?").first ?? "") : nil
        guard address.count > 0 else { return nil }
        if cryptocurrency.currencyType == .bch, (address.uppercased() == address || address.lowercased() == address) {
            // non P2PKH address format
            address = "\(cryptocurrency.currencyType.scheme):\(address)"
        }
        guard checkSendingAddressValidity(cryptocurrency, address) else { return nil }
        return address
    }
    
    func checkNewUpdates(_ callback: @escaping (_ fw: [String: String]?, _ cos: [String: String]?) -> ()) {
        guard self.coldWallet != nil else {
            callback(nil, nil)
            return
        }
        coldWalletGetVersionInfo { (fwVersion, cosVersion, error) in
            guard error == nil, let currentFwVersion = fwVersion else {
                ATLog.debug("Failed to get version info")
                callback(nil, nil)
                return
            }
            let currentCosVersion = cosVersion ?? "0"
            
            let urlStr = "https://autoupdate.authentrend.com/Autoupdate/621/\(currentFwVersion.split(separator: ".")[1])/fwcast.json"
            guard let url = URL(string: urlStr) else {
                ATLog.debug("Failed to convert string to URL. String: \(urlStr)")
                callback(nil, nil)
                return
            }
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: url) { (data, response, error) in
                guard error == nil else {
                    ATLog.debug("\(error!)")
                    DispatchQueue.main.async {
                        callback(nil, nil)
                    }
                    return
                }
                guard let jsonData = data else {
                    ATLog.debug("No data available")
                    DispatchQueue.main.async {
                        callback(nil, nil)
                    }
                    return
                }
                guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any] else {
                    ATLog.debug("Unable to parse JSON data")
                    DispatchQueue.main.async {
                        callback(nil, nil)
                    }
                    return
                }
                guard let firmwares = jsonObject["firmwares"] as? [[String: Any]] else {
                    ATLog.debug("firmwares not found")
                    DispatchQueue.main.async {
                        callback(nil, nil)
                    }
                    return
                }
                // find the newest firmware
                var onlineFw: [String: Any]?
                for firmware in firmwares {
                    guard let fwType = firmware["fwType"] as? String, fwType == "mcu" else { continue }
                    guard let version = firmware["version"] as? String else { continue }
                    guard let newestVersion = onlineFw?["version"] as? String else {
                        onlineFw = firmware
                        continue
                    }
                    let versionComponents = version.split(separator: ".")
                    let newestVersionComponents = newestVersion.split(separator: ".")
                    guard versionComponents.count == 4, newestVersionComponents.count == 4, let vMajor = Int(versionComponents[0]), let nvMajor = Int(newestVersionComponents[0]), let vMinor = Int(versionComponents[3]), let nvMinor = Int(newestVersionComponents[3]) else { continue }
                    if vMajor > nvMajor || (vMajor == nvMajor && vMinor > nvMinor) {
                        onlineFw = firmware
                    }
                }
                // find cos
                guard let dependencies = onlineFw?["dependencies"] as? [[String: Any]] else {
                    ATLog.debug("dependencies not found")
                    DispatchQueue.main.async {
                        callback(nil, nil)
                    }
                    return
                }
                var onlineCos: [String: Any]?
                for dependency in dependencies {
                    if let fwType = dependency["fwType"] as? String, fwType == "cos", let cosVersion = dependency["version"] as? String {
                        for firmware in firmwares {
                            if let fwType = firmware["fwType"] as? String, fwType == "cos", let version = firmware["version"] as? String, version == cosVersion {
                                onlineCos = firmware
                                break
                            }
                        }
                        break
                    }
                }
                guard let onlineFwVersion = onlineFw?["version"] as? String, let onlineCosVersion = onlineCos?["version"] as? String, let fwUrlStr = onlineFw?["fwUrl"] as? String, let cosUrlStr = onlineCos?["fwUrl"] as? String else {
                    ATLog.debug("firmware or cos not found")
                    DispatchQueue.main.async {
                        callback(nil, nil)
                    }
                    return
                }
                // compare version
                let currentFwVersionComponents = currentFwVersion.split(separator: ".")
                let onlineFwVersionComponents = onlineFwVersion.split(separator: ".")
                guard currentFwVersionComponents.count == 4, onlineFwVersionComponents.count == 4, let cMajor = Int(currentFwVersionComponents[0]), let oMajor = Int(onlineFwVersionComponents[0]), let cMinor = Int(currentFwVersionComponents[3]), let oMinor = Int(onlineFwVersionComponents[3]) else {
                    DispatchQueue.main.async {
                        callback(nil, nil)
                    }
                    return
                }
                let newFwAvailable = (oMajor > cMajor) || (oMajor == cMajor && oMinor > cMinor)
                let newCosAvailable = (Int(onlineCosVersion) ?? 0) > (Int(currentCosVersion) ?? 0)
                DispatchQueue.main.async {
                    callback(newFwAvailable ? ["version": onlineFwVersion, "url": fwUrlStr] : nil, newCosAvailable ? ["version": onlineCosVersion, "url": cosUrlStr] : nil)
                }
            }
            task.resume()
        }
    }
    
    func switchToAnotherHDWallet(_ target: UIViewController) {
        guard let currentHDWIndex = self.coldWalletGetHDWallet()?.hdwIndex else { return }
        var loginViewController: LoginViewController?
        for vc in target.navigationController?.viewControllers ?? [] {
            if let loginVC = vc as? LoginViewController {
                loginViewController = loginVC
                break
            }
        }
        guard loginViewController != nil else { return }
        self.coldWalletLogout { (loggedOut, error) in
            guard loggedOut == true, error == nil else {
                (error != nil) ? ATLog.debug(error!.description) : nil
                self.showAlert(target, "failed_to_log_out".localizedString, nil)
                return
            }
            loginViewController?.hdwIndex = (currentHDWIndex == ATHDWallet.Index.first.rawValue) ? .second : .first
            target.navigationController?.popToViewController(loginViewController!, animated: true)
        }
    }
        
    // MARK: - Cold Wallet Commands
    
    func isColdWalletConnected() -> Bool {
        return self.coldWallet?.connected ?? false
    }
    
    func coldWalletGetHDWallet() -> ATHDWallet? {
        return self.coldWallet?.hdwallet
    }
    
    func coldWalletSetLanguage(_ language: ATColdWallet.Language) {
        self.coldWallet?.setLanguage(Language: language, Delegate: ATColdWalletDelegate())
    }
    
    func coldWalletGetVersionInfo(_ callback: @escaping (_ fwVersion: String?, _ cosVersion: String?, _ error: ATError?) -> ()) {
        self.coldWallet?.getVersionInfo(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, nil, .failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, nil, error)
            }
            
            delegate.coldWalletDidGetVersionInfo = { (fwVersion, seVersion) in
                let fwVersionStr = String(data: fwVersion, encoding: .utf8)
                ATLog.debug("FW version: \(fwVersionStr ?? "unknown")")
                let cosPrefix = Data([0xD0, 0xA5, 0xE3, 0xB0, 0x43, 0x57])
                let preloaderPrefix = Data([0xD0, 0xA5, 0x59, 0x51, 0x42, 0x35])
                var cosVersion: String?
                if seVersion.subdata(in: 0..<cosPrefix.count) == cosPrefix {
                    cosVersion = String(data: seVersion.subdata(in: cosPrefix.count..<(seVersion.count)), encoding: .utf8)
                    ATLog.debug("COS version: \(cosVersion ?? "unknown")")
                    (cosVersion != nil) ? cosVersion = String(cosVersion!.prefix(4)) : nil
                    callback(fwVersionStr, cosVersion, nil)
                }
                else if seVersion.subdata(in: 0..<preloaderPrefix.count) == preloaderPrefix {
                    let preloaderVersion = String(data: seVersion.subdata(in: preloaderPrefix.count..<seVersion.count), encoding: .utf8)
                    ATLog.debug("Preloader version: \(preloaderVersion ?? "unknown")")
                    callback(fwVersionStr, nil, nil)
                }
                else {
                    ATLog.debug("Unknown SE version")
                    callback(fwVersionStr, nil, nil)
                }
            }
        })
    }
    
    func coldWalletGetDeviceInfo(_ callback: @escaping (_ devieName: String?, _ batteryLevel: UInt?, _ batteryCharging: Bool?, _ error: ATError?) -> ()) {
        self.coldWallet?.getDeviceInfo(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, nil, nil, .failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, nil, nil, error)
            }
            
            delegate.coldWalletDidGetDeviceInfo = { (name, batteryLevel, batteryCharging) in
                callback(name, batteryLevel, batteryCharging, nil)
                self.splitMenuViewController?.updateBatteryState(batteryLevel, batteryCharging)
            }
        })
    }
    
    func coldWalletGetDeviceInformationDescription(_ callback: @escaping (_ description: String?, _ error: ATError?) -> ()) {
        coldWalletGetVersionInfo { (fwVersion, cosVersion, error) in
            guard error == nil else {
                callback(nil, error)
                return
            }
            self.coldWalletGetDeviceInfo { (deviceName, batteryLevel, batteryCharging, error) in
                guard error == nil else {
                    callback(nil, error)
                    return
                }
                let description = """
                \("device_name".localizedString): \(deviceName ?? "")
                
                \("fw_version".localizedString): \(fwVersion ?? "")
                
                \("cos_version".localizedString): \(cosVersion ?? "")
                
                \("battery".localizedString): \(batteryLevel != nil ? "\(batteryLevel!)%" : "")
                """
                callback(description, nil)
            }
        }
    }
    
    func hasColdWalletEnrolledFingerprint(_ callback: @escaping (_ enrolled: Bool?, _ error: ATError?) -> ()) {
        self.coldWallet?.hasFingerprintBeenEnrolled(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, .failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, error)
            }
            
            delegate.coldWalletHasEnrolledFingerprint = { (enrolled) in
                callback(enrolled, nil)
            }
        })
    }
    
    func isColdWalletAbleToAddFingerprint(_ callback: @escaping (_ able: Bool?, _ error: ATError?) -> ()) {
        self.coldWallet?.isAbleToAddFingerprint(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, error)
            }
            
            delegate.coldWalletIsAbleToAddFingerprint = { (able) in
                callback(able, nil)
            }
        })
    }
    
    func isColdWalletLoggedIn() -> Bool {
        return self.coldWallet?.loggedIn ?? false
    }
        
    func coldWalletAddFingerprint(_ withVerify: Bool, _ swipeMode: Bool, _ callback: @escaping (_ progress: Int?, _ placeFingerRequired: Bool?, _ verifyMatched: Bool?, _ done: Bool, _ error: ATError?) -> ()) -> (() -> ()) {
        var cancelled = false
        var cancellationCallback: (() -> ())?
        
        var updateStateDelegate: ATColdWalletDelegate!
        let enrollStateDelegate = ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, nil, nil, false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(nil, nil, nil, false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                self.coldWallet?.cancelEnrollFingerprint(Delegate: ATColdWalletDelegate())
                callback(nil, nil, nil, false, error)
            }
            
            delegate.coldWalletDidUpdateFingerprintEnrollmentState = { (progress, placeFingerRequired) in
                guard !cancelled else { return }
                if progress >= 100 {
                    guard withVerify else {
                        swipeMode ? self.coldWallet?.swipeEnrollFingerprintEnd(Delegate: ATColdWalletDelegate()) : self.coldWallet?.touchEnrollFingerprintEnd(Delegate: ATColdWalletDelegate())
                        return
                    }
                    cancellationCallback = self.coldWalletVerifyFingerprint { (matched, placeFingerRequired, error) in
                        guard error == nil else {
                            self.coldWallet?.cancelEnrollFingerprint(Delegate: ATColdWalletDelegate())
                            callback(nil, nil, nil, false, error)
                            return
                        }
                        if let matched = matched {
                            if matched {
                                swipeMode ? self.coldWallet?.swipeEnrollFingerprintEnd(Delegate: ATColdWalletDelegate()) : self.coldWallet?.touchEnrollFingerprintEnd(Delegate: ATColdWalletDelegate())
                            }
                            else {
                                self.coldWallet?.cancelEnrollFingerprint(Delegate: ATColdWalletDelegate())
                            }
                        }
                        callback(nil, placeFingerRequired, matched, matched != nil, nil)
                    }
                    callback(100, false, nil, withVerify ? false : true, nil)
                }
                else {
                    callback(Int(progress), placeFingerRequired, nil, false, nil)
                    Thread.detachNewThread {
                        usleep(200000)
                        self.coldWallet?.getFingerprintEnrollmentState(Delegate: updateStateDelegate)
                    }
                }
            }
        }
        updateStateDelegate = enrollStateDelegate
        
        let enrollBeginDelegate = ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, false, nil, false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(nil, false, nil, false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, false, nil, false, error)
            }
            
            delegate.coldWalletDidStartFingerprintEnrollment = {
                guard !cancelled else { return }
                Thread.detachNewThread {
                    self.coldWallet?.getFingerprintEnrollmentState(Delegate: enrollStateDelegate)
                }
            }
        }
        swipeMode ? self.coldWallet?.swipeEnrollFingerprintBegin(Delegate: enrollBeginDelegate) : self.coldWallet?.touchEnrollFingerprintBegin(Delegate: enrollBeginDelegate)
        
        return { cancelled = true; cancellationCallback?(); self.coldWallet?.cancelEnrollFingerprint(Delegate: ATColdWalletDelegate()) }
    }
    
    func coldWalletVerifyFingerprint(_ callback: @escaping (_ matched: Bool?, _ placeFingerRequired: Bool?, _ error: ATError?) -> ()) -> (() -> ()) {
        var cancelled = false
        
        var updateStateDelegate: ATColdWalletDelegate!
        let verifyStateDelegate = ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, nil, .failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                self.coldWallet?.verifyFingerprintEnd(Delegate: ATColdWalletDelegate())
                callback(nil, nil, error)
            }
            
            delegate.coldWalletDidUpdateFingerprintVerificationState = { (matched, placeFingerRequired) in
                guard !cancelled else { return }
                if matched != nil {
                    self.coldWallet?.verifyFingerprintEnd(Delegate: ATColdWalletDelegate())
                }
                else {
                    Thread.detachNewThread {
                        usleep(200000)
                        self.coldWallet?.getFingerprintVerificationState(Delegate: updateStateDelegate)
                    }
                }
                callback(matched, placeFingerRequired, nil)
            }
        }
        updateStateDelegate = verifyStateDelegate
        
        self.coldWallet?.verifyFingerprintBegin(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(nil, nil, .failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, nil, error)
            }
            
            delegate.coldWalletDidStartFingerprintVerification = {
                guard !cancelled else { return }
                Thread.detachNewThread {
                    self.coldWallet?.getFingerprintVerificationState(Delegate: verifyStateDelegate)
                }
            }
        })
        
        return { cancelled = true; self.coldWallet?.verifyFingerprintEnd(Delegate: ATColdWalletDelegate()) }
    }
    
    func coldWalletPrepareForLogin(_ callback: @escaping (_ prepared: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.loginWithFingerprintBegin(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidStartLoginWithFingerprint = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletLogin(_ hdwIndex: ATHDWallet.Index, _ callback: @escaping (_ loggedIn: Bool, _ initRequired: Bool?, _ error: ATError?) -> ()) {
        self.coldWallet?.loginWithFingerprintEnd(HDWIndex: hdwIndex.rawValue, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, nil, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, nil, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, nil, error)
            }
            
            delegate.coldWalletDidFailToLogin = {
                callback(false, nil, nil);
            }
            
            delegate.coldWalletDidLogin = { (hdwallet) in
                callback(true, hdwallet == nil, nil)
                guard let hdw = hdwallet else { return }
                hdw.infoExpired ? self.coldWalletUpdateHDWalletInfo() : self.updateSplitMasterViewLoggedInState()
            }
        })
    }
    
    func coldWalletCancelLogin(_ callback: @escaping (_ error: ATError?) -> ()) {
        self.coldWallet?.loginWithFingerprintCancel(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(.failToConnect)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(error)
            }
            
            delegate.coldWalletDidCancelLoginWithFingerprint = {
                callback(nil)
            }
        })
    }
    
    func coldWalletLogout(_ callback: @escaping (_ loggedOut: Bool?, _ error: ATError?) -> ()) {
        self.coldWallet?.logout(Delegate: ATColdWalletDelegate () {(delegate) in
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(nil, error)
            }
            
            delegate.coldWalletDidLogout = {
                self.splitMenuViewController?.setloggedOut()
                callback(true, nil)
            }
        })
    }
    
    func coldWalletCreateHDWallet(_ hdwIndex: ATHDWallet.Index, _ mnemonic: [String], _ passphrase: String?, _ name: String?, _ callback: @escaping (_ created: Bool, _ error: ATError?) -> ()) {
        var walletName = NSLocalizedString((hdwIndex.rawValue == 0) ? "wallet" : "hidden_wallet", comment: "")
        if name != nil, name!.count > 0 {
            walletName = name!
        }
        self.coldWallet?.initializeHDWallet(HDWIndex: hdwIndex.rawValue, Mnemonic: mnemonic, Passphrase: passphrase, Name: walletName, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
                        
            delegate.coldWalletDidFailToInitializeHDWallet = {
                callback(false, nil)
            }
            
            delegate.coldWalletDidInitializeHDWallet = { (hdwallet) in
                callback(true, nil)
                if let hdw = hdwallet, hdw.hdwIndex == ATHDWallet.Index.first.rawValue {
                    self.coldWalletUpdateHDWalletInfo()
                }
            }
        })
    }
    
    func coldWalletRecoverHDWallet(_ hdwIndex: ATHDWallet.Index, _ hdWalletInfo: ATColdWallet.HDWalletRecoveryInfo, _ currencyWalletInfo: [ATColdWallet.CurrencyWalletRecoveryInfo], _ callback: @escaping (_ recovered: Bool, _ error:ATError?) -> ()) {
        self.coldWallet?.recoverHDWallet(HDWIndex: hdwIndex.rawValue, HDWalletRecoveryInfo: hdWalletInfo, CurrencyWalletRecoveryInfo: currencyWalletInfo, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidFailToRecoverHDWallet = {
                callback(false, nil)
            }
            
            delegate.coldWalletDidRecoverHDWallet = { (hdwallet) in
                callback(true, nil)
                if let hdw = hdwallet, hdw.hdwIndex == ATHDWallet.Index.first.rawValue {
                    self.coldWalletUpdateHDWalletInfo()
                }
            }
        })
    }
    
    func coldWalletUpdateHDWalletInfo() {
        self.coldWallet?.hdwallet?.updateWalletInfo({ (error) in
            if error != nil {
                ATLog.debug("\(error!.description)")
                if error == .loginRequired {
                    // TODO: ask user to login
                }
            }
            var initStarted = false
            let exchangeRates = ATExchangeRates()
            self.coldWallet?.hdwallet?.wallets?.forEach({ (wallet) in
                exchangeRates.cryptocurrencyToCurrency(wallet.currencyType.symbol, AppConfig.shared.defaultCurrencyUnit) { (rate) in
                    wallet.exchangeRates[AppConfig.shared.defaultCurrencyUnit.description] = rate
                    self.notifyCryptocurrencyWalletStateChanged(wallet)
                }
                wallet.delegate = self
                if !initStarted, !wallet.initialized, !wallet.initializing {
                    initStarted = true
                    AppController.shared.setAutoLock(false)
                    wallet.initWallet()
                }
            })
            self.updateSplitMasterViewLoggedInState()
        })
    }
    
    func hasColdWalletInfoUpdated() -> Bool {
        return self.coldWallet?.hdwallet?.infoExpired == false
    }
    
    func coldWalletAddNewCryptocurrency(_ purpose: UInt32?, _ cryptocurrencyType: ATCryptocurrencyType, _ account: UInt32?, _ nickname: String?, _ timestamp: Date?, _ callback: @escaping (_ added: Bool, _ error:ATError?) -> ()) {
        self.coldWallet?.hdwallet?.addWallet(Purpose: purpose, Currency: cryptocurrencyType, Account: account, Name: (nickname == nil || nickname?.count == 0) ? cryptocurrencyType.name : nickname!, Timestamp: UInt32(timestamp?.timeIntervalSince1970 ?? Date().timeIntervalSince1970), { (wallet, error) in
            guard error == nil, wallet != nil else {
                ATLog.debug("\(error!.description)")
                if error == .loginRequired {
                    // TODO: ask user to login
                }
                callback(false, error)
                return
            }
            ATExchangeRates().cryptocurrencyToCurrency(wallet!.currencyType.symbol, AppConfig.shared.defaultCurrencyUnit) { (rate) in
                wallet!.exchangeRates[AppConfig.shared.defaultCurrencyUnit.description] = rate
            }
            callback(true, nil)
            
            wallet?.delegate = self
            var initializing = false
            for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
                if wallet.initializing {
                    initializing = true
                    break
                }
            }
            if !initializing {
                wallet?.initWallet()
            }
            
            if AppController.shared.isUsingPadUI {
                var cryptocurrencyMenuItems: [MenuViewController.MenuItem] = []
                for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
                    let menuItem = MenuViewController.MenuItem(icon: UIImage(named: wallet.currencyType.symbol) ?? UIImage(), title: wallet.name) { (menuItem) in
                        if let vc = self.navigationController?.topViewController as? TransactionViewController, vc.cryptocurrency == wallet {
                            return
                        }
                        
                        if self.navigationController?.topViewController as? WalletViewController == nil {
                            for vc in self.navigationController?.viewControllers ?? [] {
                                if vc as? WalletViewController != nil {
                                    self.navigationController?.popToViewController(vc, animated: false)
                                    break
                                }
                            }
                        }
                        if let vc = self.navigationController?.topViewController as? WalletViewController {
                            vc.selectedCryptocurrency = wallet
                            vc.performSegue(withIdentifier: "TransactionSegue", sender: vc)
                        }
                    }
                    cryptocurrencyMenuItems.append(menuItem)
                }
                self.splitMenuViewController?.updateCryptocurrencyMenuItems(cryptocurrencyMenuItems)
            }
        })
    }
    
    func coldWalletPrepareToSignTransaction(_ cryptocurrency: ATCryptocurrencyWallet, _ transaction: ATCryptocurrencyTransaction, _ callback: @escaping TransactionCompletionCallback) {
        self.prepareSigningCallback = callback
        cryptocurrency.prepareForSigningTransaction(transaction)
    }
    
    func coldWalletSignTransaction(_ cryptocurrency: ATCryptocurrencyWallet, _ transaction: ATCryptocurrencyTransaction, _ callback: @escaping TransactionCompletionCallback) {
        self.signTransactionCallback = callback
        cryptocurrency.signTransaction(transaction)
    }
    
    func coldWalletPublishTransaction(_ cryptocurrency: ATCryptocurrencyWallet, _ transaction: ATCryptocurrencyTransaction, _ callback: @escaping TransactionCompletionCallback) {
        self.publishTransactionCallback = callback
        cryptocurrency.publishTransaction(transaction)
    }
    
    func coldWalletCancelSigningTransaction(_ cryptocurrency: ATCryptocurrencyWallet, _ transaction: ATCryptocurrencyTransaction) {
        cryptocurrency.cancelSigningTransaction(transaction)
    }
        
    func coldWalletUpdateFirmware(_ fwData: Data, _ callback: @escaping (_ progress: Int, _ error: ATError?) -> ()) {
        setAutoLock(false)
        let maxSegmentSize = 256 // 256 will take about 8 minutes and 35 seconds to update firmware
        //let maxSegmentSize = 1024 // 1024 will take about 8 minutes to update firmware
        let fwDataBytes = [UInt8](fwData)
        let fwDataLength = Int(((UInt32(fwDataBytes[2]) << 16) & 0x00FF0000) | ((UInt32(fwDataBytes[3]) << 8) & 0x0000FF00) | (UInt32(fwDataBytes[4])) & 0x000000FF)
        var fwDataOffset = 0
        var sendFirmwareDataDelegate: ATColdWalletDelegate!
        let coldWalletDelegate = ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(0, .failToConnect)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(0, .loginRequired)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                self.coldWallet?.cancelFirmwareOTA(Delegate: ATColdWalletDelegate())
                callback(0, error)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidSendFirmwareData = {
                fwDataOffset += maxSegmentSize
                if fwDataLength > fwDataOffset {
                    var progress = Int(Float(fwDataOffset) / Float(fwDataLength) * 100)
                    (progress == 0) ? progress = 1 : nil
                    callback(progress, nil)
                    let dataLength = (fwDataLength > (fwDataOffset + maxSegmentSize)) ? maxSegmentSize : fwDataLength - fwDataOffset
                    self.coldWallet?.sendFirmwareData(Data: fwData.subdata(in: (14 + fwDataOffset)..<(14 + fwDataOffset + dataLength)), Delegate: sendFirmwareDataDelegate)
                }
                else {
                    callback(99, nil)
                    var data = Data()
                    data.append(contentsOf: [UInt8((UInt32(fwDataLength) >> 24) & 0xFF), UInt8((UInt32(fwDataLength) >> 16) & 0xFF), UInt8((UInt32(fwDataLength) >> 8) & 0xFF), UInt8(UInt32(fwDataLength) & 0xFF)])
                    data.append(fwData.subdata(in: (14 + fwDataLength)..<(14 + fwDataLength + 20)))
                    self.coldWallet?.finishFirmwareOTA(Data: data, Delegate: ATColdWalletDelegate { (delegate) in
                        delegate.coldWalletDidFailToConnect = {
                            callback(0, .failToConnect)
                            self.setAutoLock(true)
                        }
                        
                        delegate.coldWalletDidFailToExecuteCommand = { (error) in
                            callback(0, error)
                            self.setAutoLock(true)
                        }
                        
                        delegate.coldWalletDidFinishFirmwareOTA = {
                            callback(100, nil)
                            self.setAutoLock(true)
                        }
                    })
                }
            }
        }
        sendFirmwareDataDelegate = coldWalletDelegate
        
        self.coldWallet?.startFirmwareOTA(Type: .mcu, Data: fwData.subdata(in: 0..<14), Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(0, .failToConnect)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(0, .loginRequired)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(0, error)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidStartFirmwareOTA = {
                callback(1, nil)
                fwDataOffset = 0
                let dataLength = (fwDataLength > (fwDataOffset + maxSegmentSize)) ? maxSegmentSize : fwDataLength - fwDataOffset
                self.coldWallet?.sendFirmwareData(Data: fwData.subdata(in: (14 + fwDataOffset)..<(14 + fwDataOffset + dataLength)), Delegate: sendFirmwareDataDelegate)
            }
        })
    }
    
    func coldWalletUpdateCos(_ cosData: Data, _ callback: @escaping (_ progress: Int, _ error: ATError?) -> ()) {
        class CosDataHandler {
            var index: Int
            let cosCommands: [String.SubSequence]
            var isEnd: Bool {
                return (self.cosCommands.count - self.index) < 3
            }
            var progress: Float {
                return Float(self.index) / Float(self.cosCommands.count)
            }
            var nextData: Data? {
                var buffer: Data? = nil
                while buffer == nil, self.index < self.cosCommands.count {
                    buffer = String(self.cosCommands[self.index]).hexStringData
                    self.index += 1
                }
                return buffer
            }
            var nextString: String? {
                var str: String?
                while str == nil, self.index < self.cosCommands.count {
                    str = String(self.cosCommands[self.index])
                    (str?.count == 0) ? str = nil : nil
                    self.index += 1
                }
                return str
            }
            init?(_ data: Data) {
                guard let lines = String(data: data, encoding: .ascii)?.split(separator: "\n") else { return nil }
                self.cosCommands = lines
                self.index = 0
            }
        }
        
        guard let cosDataHandler = CosDataHandler(cosData) else {
            callback(0, .invalidParameter)
            return
        }
        
        setAutoLock(false)
        
        var sendFirmwareDataDelegate: ATColdWalletDelegate!
        let coldWalletDelegate = ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(0, .failToConnect)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(0, .loginRequired)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                self.coldWallet?.cancelFirmwareOTA(Delegate: ATColdWalletDelegate())
                callback(0, error)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidSendFirmwareData = {
                if !cosDataHandler.isEnd {
                    var progress = Int(cosDataHandler.progress * 100)
                    (progress == 0) ? progress = 1 : nil
                    callback(progress, nil)
                    guard let str = cosDataHandler.nextString, let blockId = UInt8(String(str.suffix(str.count - 1))), let blockData = cosDataHandler.nextData, let mac = cosDataHandler.nextData else {
                        callback(0, .invalidParameter)
                        return
                    }
                    var data = Data()
                    data.append(blockId)
                    data.append(blockData)
                    data.append(mac)
                    self.coldWallet?.sendFirmwareData(Data: data, Delegate: sendFirmwareDataDelegate)
                }
                else {
                    callback(99, nil)
                    self.coldWallet?.finishFirmwareOTA(Data: nil, Delegate: ATColdWalletDelegate { (delegate) in
                        delegate.coldWalletDidFailToConnect = {
                            callback(0, .failToConnect)
                            self.setAutoLock(true)
                        }
                        
                        delegate.coldWalletNeedsLoginWithFingerprint = {
                            callback(0, .loginRequired)
                            self.setAutoLock(true)
                        }
                        
                        delegate.coldWalletDidFailToExecuteCommand = { (error) in
                            callback(0, error)
                            self.setAutoLock(true)
                        }
                        
                        delegate.coldWalletDidFinishFirmwareOTA = {
                            callback(100, nil)
                            self.setAutoLock(true)
                        }
                    })
                }
            }
        }
        sendFirmwareDataDelegate = coldWalletDelegate
        
        var initData = Data()
        guard let authMtrl = cosDataHandler.nextData, let encSmk = cosDataHandler.nextData else {
            ATLog.debug("data not found")
            callback(0, .invalidParameter)
            self.setAutoLock(true)
            return
        }
        initData.append(authMtrl)
        initData.append(encSmk)
        self.coldWallet?.startFirmwareOTA(Type: .cos, Data: initData, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(0, .failToConnect)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(0, .loginRequired)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(0, error)
                self.setAutoLock(true)
            }
            
            delegate.coldWalletDidStartFirmwareOTA = {
                callback(1, nil)
                guard let str = cosDataHandler.nextString, let blockId = UInt8(String(str.suffix(str.count - 1))), let blockData = cosDataHandler.nextData, let mac = cosDataHandler.nextData else {
                    callback(0, .invalidParameter)
                    return
                }
                var data = Data()
                data.append(blockId)
                data.append(blockData)
                data.append(mac)
                self.coldWallet?.sendFirmwareData(Data: data, Delegate: sendFirmwareDataDelegate)
            }
        })
    }
    
    func coldWalletUpdateFirmwareAndCos(_ fwData: Data, _ cosData: Data, _ callback: @escaping (_ progress: Int, _ error: ATError?) -> ()) {
        coldWalletUpdateFirmware(fwData) { (progress, error) in
            let newProgress = (progress == 1) ? 1 : (progress / 2)
            callback(newProgress, error)
            if progress == 100 {
                self.coldWalletUpdateCos(cosData) { (progress, error) in
                    var newProgress = (progress == 1) ? 1 : (progress / 2)
                    newProgress += 50
                    callback(newProgress, error)
                }
            }
        }
    }
    
    func coldWalletResetHDWallet(_ callback: @escaping (_ done: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.resetHDWallet(Delegate: ATColdWalletDelegate() { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidResetHDWallets = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletDoFactoryReset(_ callback: @escaping (_ done: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.factoryReset(Delegate: ATColdWalletDelegate() { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidFactoryReset = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletStartBindingLoginFingerprint(_ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) -> (() -> ()) {
        self.coldWallet?.bindLoginFingerprintsBegin(Delegate: ATColdWalletDelegate() { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidStartBindingLoginFingerprints = {
                callback(true, nil)
            }
        })
        
        let cancelCallback: () -> () = {
            self.coldWallet?.cancelBindingLoginFingerprints(Delegate: ATColdWalletDelegate())
        }
        return cancelCallback
    }
    
    func coldWalletFinishBindingLoginFingerprint(_ sequential: Bool, _ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.bindLoginFingerprintsEnd(Sequential: sequential, Delegate: ATColdWalletDelegate() { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidFailToBindLoginFingerprints = {
                callback(false, nil)
            }
            
            delegate.coldWalletDidBindLoginFingerprints = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletStartVerifyingBoundLoginFingerprin(_ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) -> (() -> ()) {
        self.coldWallet?.verifyBoundFPBegin(Delegate: ATColdWalletDelegate() { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidStartToVerifyBoundLoginFingerprints = {
                callback(true, nil)
            }
        })
        
        let cancelCallback: () -> () = {
            self.coldWallet?.cancelBindingLoginFingerprints(Delegate: ATColdWalletDelegate())
        }
        return cancelCallback
    }
    
    func coldWalletFinishVerifyingBoundLoginFingerprint(_ sequential: Bool, _ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) -> (() -> ()) {
        self.coldWallet?.verifyBoundFPEnd(Sequential: sequential, Delegate: ATColdWalletDelegate() { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidFailToVerifyBoundLoginFingerprints = {
                callback(false, nil)
            }
            
            delegate.coldWalletDidVerifyBoundLoginFingerprints = {
                callback(true, nil)
            }
        })
        
        let cancelCallback: () -> () = {
            self.coldWallet?.cancelBindingLoginFingerprints(Delegate: ATColdWalletDelegate())
        }
        return cancelCallback
    }
    
    func coldWalletUnbindLoginFingerprint(_ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.unbindLoginFingerprints(Delegate: ATColdWalletDelegate () { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidUnbindLoginFingerprints = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletCalibrateFingerprintSensor(_ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.calibrateFingerprintSensor(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidCalibrateFingerprintSensor = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletStartFingerprintDeletion(_ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.startFingerprintDeletion(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidStartFingerprintDeletion = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletFinishFingerprintDeletion(_ callback: @escaping (_ succeeded: Bool, _ deletedFpids: [UInt32]?, _ error: ATError?) -> ()) {
        self.coldWallet?.finishFingerprintDeletion(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, nil, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, nil, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, nil, error)
            }
            
            delegate.coldWalletDidFinishFingerprintDeletion = { (fpids) in
                guard let fpids = fpids else {
                    callback(false, nil, .commandError)
                    return
                }
                callback(true, fpids, nil)
            }
        })
    }
    
    func coldWalletCancelFingerprintDeletion(_ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.cancelFingerprintDeletion(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidCancelFingerprintDeletion = {
                callback(true, nil)
            }
        })
    }
    
    func coldWalletChangeHDWalletName(_ name: String, _ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.changeHDWalletName(Name: name, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidChangeHDWalletName = {
                callback(true, nil)
                
                if self.isUsingPadUI {
                    if let hdw = self.coldWallet?.hdwallet {
#if TESTNET
                        let icon = UIImage(named: "CircleTestnetAppIcon")
#else
                        let icon = UIImage(named: "CircleAppIcon")
#endif
                        let hdwMenuItem = MenuViewController.MenuItem(icon: icon ?? UIImage(), title: hdw.name ?? "wallet".localizedString) { (menuItem) in
                            guard self.navigationController?.topViewController as? WalletViewController == nil else { return }
                            for vc in self.navigationController?.viewControllers ?? [] {
                                if vc as? WalletViewController != nil {
                                    self.navigationController?.popToViewController(vc, animated: true)
                                    break
                                }
                            }
                        }
                        self.splitMenuViewController?.updateHDWalletMenuItem(hdwMenuItem)
                    }
                }
            }
        })
    }
    
    func coldWalletChangeCryptocurrencyNickname(_ cryptocurrency: ATCryptocurrencyWallet, _ name: String, _ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.changeWalletName(AccountIndex: cryptocurrency.accountIndex, Name: name, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                callback(false, .failToConnect)
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                callback(false, .loginRequired)
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                callback(false, error)
            }
            
            delegate.coldWalletDidChangeWalletName = { (index) in
                callback(true, nil)
                
                if AppController.shared.isUsingPadUI {
                    var cryptocurrencyMenuItems: [MenuViewController.MenuItem] = []
                    for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
                        let menuItem = MenuViewController.MenuItem(icon: UIImage(named: wallet.currencyType.symbol) ?? UIImage(), title: wallet.name) { (menuItem) in
                            if let vc = self.navigationController?.topViewController as? TransactionViewController, vc.cryptocurrency == wallet {
                                return
                            }
                            
                            if self.navigationController?.topViewController as? WalletViewController == nil {
                                for vc in self.navigationController?.viewControllers ?? [] {
                                    if vc as? WalletViewController != nil {
                                        self.navigationController?.popToViewController(vc, animated: false)
                                        break
                                    }
                                }
                            }
                            if let vc = self.navigationController?.topViewController as? WalletViewController {
                                vc.selectedCryptocurrency = wallet
                                vc.performSegue(withIdentifier: "TransactionSegue", sender: vc)
                            }
                        }
                        cryptocurrencyMenuItems.append(menuItem)
                    }
                    self.splitMenuViewController?.updateCryptocurrencyMenuItems(cryptocurrencyMenuItems)
                }
            }
        })
    }
    
    func coldWalletDeleteCryptocurrency(_ cryptocurrency: ATCryptocurrencyWallet, _ callback: @escaping (_ succeeded: Bool, _ error: ATError?) -> ()) {
        self.coldWallet?.hdwallet?.removeWallet(Wallet: cryptocurrency, { (error) in
            callback((error == nil), error)
            
            if error == nil, AppController.shared.isUsingPadUI {
                var cryptocurrencyMenuItems: [MenuViewController.MenuItem] = []
                for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
                    let menuItem = MenuViewController.MenuItem(icon: UIImage(named: wallet.currencyType.symbol) ?? UIImage(), title: wallet.name) { (menuItem) in
                        if let vc = self.navigationController?.topViewController as? TransactionViewController, vc.cryptocurrency == wallet {
                            return
                        }
                        
                        if self.navigationController?.topViewController as? WalletViewController == nil {
                            for vc in self.navigationController?.viewControllers ?? [] {
                                if vc as? WalletViewController != nil {
                                    self.navigationController?.popToViewController(vc, animated: false)
                                    break
                                }
                            }
                        }
                        if let vc = self.navigationController?.topViewController as? WalletViewController {
                            vc.selectedCryptocurrency = wallet
                            vc.performSegue(withIdentifier: "TransactionSegue", sender: vc)
                        }
                    }
                    cryptocurrencyMenuItems.append(menuItem)
                }
                self.splitMenuViewController?.updateCryptocurrencyMenuItems(cryptocurrencyMenuItems)
            }
        })
        
        notifyCryptocurrencyWalletStateChanged(cryptocurrency)
    }
    
    // MARK: - ATDeviceManagerDelegate
    
    func deviceManager(_ deviceManager: ATDeviceManager, didUpdateState state: ATDeviceManagerState) {
        self.btOnOffStateCallback?(state == .btOn)
    }
    
    func deviceManager(_ deviceManager: ATDeviceManager, didDiscover device: ATDevice) {
        self.scanCallback?(device)
    }
    
    func deviceManager(_ deviceManager: ATDeviceManager, didLose device: ATDevice) {
        // do nothing
    }
    
    // MARK: - ATDeviceDelegate
    
    func deviceDidConnect(_ device: ATDevice) {
        self.splitMenuViewController?.setConnected(device.name, nil, nil)
        let cmdGetVersionInfo: [UInt8] = [0x00, 0x77, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        device.send(Data(cmdGetVersionInfo)) { (response, error) in
            guard error == nil, let response = response else {
                ATLog.debug(error!.description)
                DispatchQueue.main.async {
                    self.connectCallback?(false, error)
                }
                return
            }
            guard response.count >= 4, response.count >= (1 + response.first! + 2) else {
                ATLog.debug("Wrong response length")
                DispatchQueue.main.async {
                    self.connectCallback?(false, .incorrectResponse)
                }
                return
            }
            let sw = response.subdata(in: (response.count - 2)..<(response.count)).withUnsafeBytes { (pointer) -> UInt16 in
                return CFSwapInt16BigToHost(pointer.load(as: UInt16.self))
            }
            guard sw == 0x9000 else {
                DispatchQueue.main.async {
                    self.connectCallback?(false, .incorrectSW)
                }
                return
            }
            let fwVersionLength = Int(response.first!)
            let fwVersion = String(data: response.subdata(in: 1..<(1 + fwVersionLength)), encoding: .utf8)
            ATLog.debug("FW version: \(fwVersion ?? "unknown")")
            let seVersionLength = Int([UInt8](response)[1 + fwVersionLength])
            let seVersionData = response.subdata(in: (1 + fwVersionLength + 1)..<(1 + fwVersionLength + 1 + seVersionLength))
            let cosPrefix = Data([0xD0, 0xA5, 0xE3, 0xB0, 0x43, 0x57])
            let preloaderPrefix = Data([0xD0, 0xA5, 0x59, 0x51, 0x42, 0x35])
            if seVersionData.subdata(in: 0..<cosPrefix.count) == cosPrefix {
                ATLog.debug("COS version: \(String(data: seVersionData.subdata(in: cosPrefix.count..<seVersionData.count), encoding: .utf8) ?? "unknown")")
            }
            else if seVersionData.subdata(in: 0..<preloaderPrefix.count) == preloaderPrefix {
                ATLog.debug("Preloader version: \(String(data: seVersionData.subdata(in: preloaderPrefix.count..<seVersionData.count), encoding: .utf8) ?? "unknown")")
            }
            else {
                ATLog.debug("Unknown SE version")
            }
            if fwVersion?.hasPrefix("1.") ?? false {
                // NOTE: ATColdWallet should use ATTLSProtocol or ATProprietaryProtocol. ATPlainProtocol is only for debugging
                self.coldWallet = ATColdWallet(Device: device, Protocol: ATPlainProtocol.self)
            }
            else {
                // NOTE: ATColdWallet should use ATTLSProtocol or ATProprietaryProtocol. ATPlainProtocol is only for debugging
                self.coldWallet = ATColdWallet(Device: device, Protocol: ATProprietaryProtocol.self)
            }
            self.coldWallet?.updateBatteryState({
                self.splitMenuViewController?.updateBatteryState(self.coldWallet?.batteryLevel, self.coldWallet?.batteryCharging)
            })
            
            // find a supported preferred languages
            var language = ATColdWallet.Language.english
            for preferredLanguage in NSLocale.preferredLanguages {
                var matched = false
                for supportedLanguage in ATColdWallet.Language.allCases {
                    if preferredLanguage.hasPrefix(supportedLanguage.code) {
                        language = supportedLanguage
                        matched = true
                        break
                    }
                }
                if matched {
                    break
                }
            }
            self.coldWalletSetLanguage(language)
            
            DispatchQueue.main.async {
                self.connectCallback?(true, nil)
            }
        }
    }
    
    func deviceDidDisconnect(_ device: ATDevice) {
        // unused
    }
    
    func deviceDidFailToConnect(_ device: ATDevice) {
        self.connectCallback?(false, .failToConnect)
    }
    
    // MARK: - ATCryptocurrencyWalletDelegate
    
    func cryptocurrencyWalletDidInit(_ wallet: ATCryptocurrencyWallet) {
        if wallet.currencyType == .eth, wallet.tokens.count > 0 {
            let exchangeRates = ATExchangeRates()
            let currencySymbol = AppConfig.shared.defaultCurrencyUnit
            for token in wallet.tokens {
                exchangeRates.cryptocurrencyToCurrency(token.info.symbol, currencySymbol) { (rate) in
                    token.exchangeRates[currencySymbol] = rate
                    self.notifyCryptocurrencyWalletStateChanged(wallet)
                }
            }
        }
        else {
            notifyCryptocurrencyWalletStateChanged(wallet)
        }
        
        var initableWallet: ATCryptocurrencyWallet?
        for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
            if wallet.initializing {
                initableWallet = nil
                break
            }
            if initableWallet == nil, !wallet.initialized {
                initableWallet = wallet
            }
        }
        if let wallet = initableWallet {
            wallet.initWallet()
        }
        
        var syncableWallet: ATCryptocurrencyWallet?
        for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
            if wallet.isSyncing {
                syncableWallet = nil
                break
            }
            if syncableWallet == nil, wallet.initialized, wallet.lastSyncTime == 0 {
                syncableWallet = wallet
            }
        }
        if let wallet = syncableWallet {
            wallet.syncWallet()
        }
    }
    
    func cryptocurrencyWalletDidFailToInit(_ wallet: ATCryptocurrencyWallet, _ error: ATError?) {
        notifyCryptocurrencyWalletStateChanged(wallet)
        
        let failedWallet = wallet
        var initableWallet: ATCryptocurrencyWallet?
        for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
            if wallet.initializing {
                initableWallet = nil
                break
            }
            if initableWallet == nil, !wallet.initialized, wallet != failedWallet {
                initableWallet = wallet
            }
        }
        if let wallet = initableWallet {
            wallet.initWallet()
        }
        
        struct RetryInterval {
            static var value: TimeInterval = 1
        }
        if initableWallet == nil {
            RetryInterval.value *= 2
            DispatchQueue.main.asyncAfter(deadline: .now() + RetryInterval.value) {
                failedWallet.initWallet()
            }
        }
    }
    
    func cryptocurrencyWalletDidStartSync(_ wallet: ATCryptocurrencyWallet) {
        notifyCryptocurrencyWalletStateChanged(wallet)
    }
    
    func cryptocurrencyWalletDidStopSync(_ wallet: ATCryptocurrencyWallet, _ error: ATError?) {
        (error != nil) ? ATLog.debug("\(error!.description)") : nil
        notifyCryptocurrencyWalletStateChanged(wallet)
        
        let syncedWallet = wallet
        var syncableWallet: ATCryptocurrencyWallet?
        for wallet in self.coldWallet?.hdwallet?.wallets ?? [] {
            if wallet.isSyncing {
                syncableWallet = nil
                break
            }
            if syncableWallet == nil, wallet.initialized, wallet.lastSyncTime == 0, wallet != syncedWallet {
                syncableWallet = wallet
            }
        }
        
        struct RetryInterval {
            static var value: TimeInterval = 1
        }
        
        if let wallet = syncableWallet {
            wallet.syncWallet()
        }
        else if error != nil {
            RetryInterval.value *= 2
            DispatchQueue.main.asyncAfter(deadline: .now() + RetryInterval.value) {
                syncedWallet.syncWallet()
            }
        }
        else {
            AppController.shared.setAutoLock(true)
        }
    }
    
    func cryptocurrencyWalletDidUpdateBalance(_ wallet: ATCryptocurrencyWallet) {
        notifyCryptocurrencyWalletStateChanged(wallet)
    }
    
    func cryptocurrencyWalletDidUpdateTransaction(_ wallet: ATCryptocurrencyWallet) {
        notifyCryptocurrencyWalletStateChanged(wallet)
    }
    
    func cryptocurrencyWalletDidUpdateTokens(_ wallet: ATCryptocurrencyWallet) {
        notifyCryptocurrencyWalletStateChanged(wallet)
    }
    
    func cryptocurrencyWalletDidPrepareForSigningTransaction(_ transaction: ATCryptocurrencyTransaction) {
        self.prepareSigningCallback?(true, transaction, nil)
        self.prepareSigningCallback = nil
    }
    
    func cryptocurrencyWalletDidFailToPrepareForSigningTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError) {
        self.prepareSigningCallback?(false, nil, error)
        self.prepareSigningCallback = nil
    }
    
    func cryptocurrencyWalletDidSignTransaction(_ transaction: ATCryptocurrencyTransaction) {
        self.signTransactionCallback?(true, transaction, nil)
        self.signTransactionCallback = nil
    }
    
    func cryptocurrencyWalletDidFailToSignTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError) {
        self.signTransactionCallback?(false, nil, error)
        self.signTransactionCallback = nil
    }
    
    func cryptocurrencyWalletDidPublishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        self.publishTransactionCallback?(true, transaction, nil)
        self.publishTransactionCallback = nil
    }
    
    func cryptocurrencyWalletDidFailToPublishTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError) {
        self.publishTransactionCallback?(false, nil, error)
        self.publishTransactionCallback = nil
    }
}

extension String {
    var localizedString: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localizedString(_ defaultValue: String) -> String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: defaultValue, comment: "")
    }
    
    func indexDistance(of character: Character) -> Int? {
        guard let index = self.firstIndex(of: character) else { return nil }
        return self.distance(from: self.startIndex, to: index)
    }
    
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
    
    var isNumeric: Bool {
        return !isEmpty && (Double(self) != nil)
    }
    
    var hexStringData: Data? {
        guard self.count % 2 == 0 else { return nil }
        var data: Data? = Data()
        for index in stride(from: 0, to: self.count, by: 2) {
            guard let byte = UInt8(String(self.prefix(index + 2).suffix(2)), radix: 16) else {
                data = nil
                break
            }
            data?.append(byte)
        }
        return data
    }
}

extension Double {
    func toString(_ decimalPlace: UInt8) -> String {
        var str = String(format: "%.\(decimalPlace)f", self)
        while let c = str.last, c == "0" {
            str.removeLast()
        }
        if let c = str.last, c == "." {
            str.append("0")
        }
        return str
    }
}

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
}

extension UIAlertController {
    func setTitleAlignment(_ alignment : NSTextAlignment) {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = alignment
        let titleText = NSMutableAttributedString(
            string: self.title ?? "",
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16),
            ]
        )
        self.title = nil
        self.setValue(titleText, forKey: "attributedTitle")
    }
    
    func setMessageAlignment(_ alignment : NSTextAlignment) {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = alignment
        let messageText = NSMutableAttributedString(
            string: self.message ?? "",
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13),
            ]
        )
        self.message = nil
        self.setValue(messageText, forKey: "attributedMessage")
    }
}

extension UIApplication {
    public var isSplitOrSlideOver: Bool {
        guard let w = self.delegate?.window, let window = w else { return false }
        return !window.frame.equalTo(window.screen.bounds)
    }
}

extension UINavigationController {
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self as? UIGestureRecognizerDelegate
    }
}

extension UIViewController {
    var isModal: Bool {
        return self.presentingViewController?.presentedViewController == self || (self.navigationController != nil && self.navigationController?.presentingViewController?.presentedViewController == self.navigationController) || self.tabBarController?.presentingViewController is UITabBarController
    }
}
