//
//  SettingsViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class SettingsViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var backButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    private var settingsFunctionGroups: KeyValuePairs<String, KeyValuePairs<String, () -> ()>> = [:]
    private var walletManagementFunctionGroup: KeyValuePairs<String, () -> ()> = [:]
    private var fingerprintManagementFunctionGroup: KeyValuePairs<String, () -> ()> = [:]
    private var deviceManagementFunctionGroup: KeyValuePairs<String, () -> ()> = [:]
    private var preferencesFunctionGroups: KeyValuePairs<String, () -> ()> = [:]
    private var functionImages: [String: NSImage] = [:]
    private var fpVerificationDelegate: FingerprintVerificationViewControllerDelegate?
    private var isFingerprintBound = false
    private var bindingFingerprintEnabled = false
    private var firmwareUpdateEnabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.titleLabel.stringValue = "settings".localizedString
        self.descriptionLabel.stringValue = ""
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        /*// Floating section header
        if let layout = self.collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        */
        self.collectionView.register(NSNib(nibNamed: "SettingsCollectionViewSectionHeader", bundle: nil), forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader, withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SettingsCollectionViewSectionHeader"))
        self.collectionView.register(NSNib(nibNamed: "SettingsCollectionViewItem", bundle: nil), forItemWithIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SettingsCollectionViewItem"))
        
        self.walletManagementFunctionGroup = ["rename": rename,
                                              "bind_login_fingerprint": bindLoginFingerprint,
                                              "unbind_login_fingerprint": unbindLoginFingerprint,
                                              "init_hidden_wallet": initHiddenWallet,
                                              "switch_to_another_wallet": switchToAnotherWallet,
                                              "add_cryptocurrency": addCryptocurrency,
                                              "delete_cryptocurrency": deleteCryptocurrency,
                                              "logout": logout]
        
        self.fingerprintManagementFunctionGroup = ["enroll_fingerprint": enrollFingerprint,
                                                   "delete_fingerprint": deleteFingerprint,
                                                   "calibrate_fingerprint_sensor": calibrateFingerprintSensor]
        
        self.deviceManagementFunctionGroup = ["firmware_update": updateFirmware,
                                              "reset_wallet": resetWallet,
                                              "factory_reset": resetToFactory,
                                              "device_information": showDeviceInformation]
        
        self.preferencesFunctionGroups = ["display_currency": changeDisplayCurrency]
        
        self.settingsFunctionGroups = ["wallet_management": walletManagementFunctionGroup,
                                       "fingerprint_management": fingerprintManagementFunctionGroup,
                                       "device_management": deviceManagementFunctionGroup,
                                       "preferences": preferencesFunctionGroups]
        
        self.functionImages["rename"] = NSImage(named: "Rename")
        self.functionImages["bind_login_fingerprint"] = NSImage(named: "BindFingerprint")
        self.functionImages["unbind_login_fingerprint"] = NSImage(named: "UnbindFingerprint")
        self.functionImages["init_hidden_wallet"] = NSImage(named: "InitWallet")
        self.functionImages["switch_to_another_wallet"] = NSImage(named: "SwitchWallet")
        self.functionImages["add_cryptocurrency"] = NSImage(named: "AddCryptocurrency")
        self.functionImages["delete_cryptocurrency"] = NSImage(named: "DeleteCryptocurrency")
        self.functionImages["logout"] = NSImage(named: "Logout")
        self.functionImages["enroll_fingerprint"] = NSImage(named: "EnrollFingerprint")
        self.functionImages["delete_fingerprint"] = NSImage(named: "DeleteFingerprint")
        self.functionImages["calibrate_fingerprint_sensor"] = NSImage(named: "CalibrateSensor")
        self.functionImages["firmware_update"] = NSImage(named: "FirmwareUpdate")
        self.functionImages["reset_wallet"] = NSImage(named: "ResetWallet")
        self.functionImages["factory_reset"] = NSImage(named: "FactoryReset")
        self.functionImages["device_information"] = NSImage(named: "DeviceInformation")
        self.functionImages["display_currency"] = NSImage(named: "Currency")
    }
    
    override func viewWillAppear() {
        self.collectionView.reloadData()
    }
    
    // MARK: - Wallet Management
    
    func rename() {
        guard let hdw = AppController.shared.coldWalletGetHDWallet() else { return }
        var items: [String] = [hdw.name ?? ""]
        var width: CGFloat = items[0].sizeOfFont(NSFont.systemFont(ofSize: 13)).width
        var height: CGFloat = 0
        for wallet in hdw.wallets ?? [] {
            var name = wallet.name
            var count = 1
            while items.contains(name) {
                count += 1
                name = "\(wallet.name) (\(count))"
            }
            items.append(name)
            let size = name.sizeOfFont(NSFont.systemFont(ofSize: 13))
            (size.width > width) ? width = size.width : nil
            (size.height > height) ? height = size.height : nil
        }
        let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, width + 40, height + 10))
        popUpButton.addItems(withTitles: items)
        let cancelAction = AppController.AlertAction(title: "cancel".localizedString, callback: nil)
        let okAction = AppController.AlertAction(title: "ok".localizedString) {
            let index = popUpButton.indexOfSelectedItem
            guard (hdw.wallets?.count ?? 0) > (index - 1) else { return }
            let currentName = ((index == 0) ? hdw.name : hdw.wallets?[index - 1].name) ?? ""
            let textField = NSTextField(string: "")
            textField.frame = NSRect(x: 0, y: 0, width: 200, height: textField.frame.height)
            textField.isEditable = true
            textField.alignment = .center
            textField.textColor = AppController.TextColor
            textField.backgroundColor = AppController.InputFieldBackgroundColor
            textField.placeholderString = "new_nickname".localizedString
            let cancelAction = AppController.AlertAction(title: "cancel".localizedString, callback: nil)
            let okAction = AppController.AlertAction(title: "ok".localizedString, callback: {
                guard textField.stringValue != "" else { return }
                let newName = textField.stringValue
                if index == 0 {
                    AppController.shared.showBusyPrompt()
                    AppController.shared.coldWalletChangeHDWalletName(newName) { (succeeded, error) in
                        AppController.shared.hideBusyPrompt()
                        guard succeeded, error == nil else {
                            (error != nil) ? ATLog.debug(error!.description) : nil
                            switch error {
                            case .loginRequired:
                                AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString) {
                                    AppController.shared.popSplitDetailViewToRootViewController()
                                }])
                            case .failToConnect:
                                AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                            default:
                                AppController.shared.showAlert("failed_to_change_name".localizedString)
                            }
                            return
                        }
                        AppController.shared.showInformation("succeeded_to_change_name".localizedString)
                    }
                }
                else if let cryptocurrency = hdw.wallets?[index - 1] {
                    AppController.shared.showBusyPrompt()
                    AppController.shared.coldWalletChangeCryptocurrencyNickname(cryptocurrency, newName) { (succeeded, error) in
                        AppController.shared.hideBusyPrompt()
                        guard succeeded, error == nil else {
                            (error != nil) ? ATLog.debug(error!.description) : nil
                            switch error {
                            case .loginRequired:
                                AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString) {
                                    AppController.shared.popSplitDetailViewToRootViewController()
                                }])
                            case .failToConnect:
                                AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                            default:
                                AppController.shared.showAlert("failed_to_change_name".localizedString)
                            }
                            return
                        }
                        AppController.shared.showInformation("succeeded_to_change_name".localizedString)
                    }
                }
            })
            AppController.shared.showInformation(currentName, nil, [okAction, cancelAction], textField)
        }
        AppController.shared.showInformation("select_one_to_rename".localizedString, nil, [okAction, cancelAction], popUpButton)
    }
    
    func bindLoginFingerprint() {
        class Delegate: FingerprintVerificationViewControllerDelegate {
            
            let parent: SettingsViewController
            var cancelCallback: (() -> ())
            
            init(_ vc: SettingsViewController, _ cancelCallback: @escaping () -> ()) {
                self.parent = vc
                self.cancelCallback = cancelCallback
            }
            
            func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> () {
                vc.titleLabel.stringValue = "bind_your_fingerprints".localizedString
                vc.descriptionLabel.stringValue = "verify_fp_for_binding".localizedString
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                vc.doneButton.attributedTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
                vc.doneButton.attributedAlternateTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
            }
            
            func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool {
                let complete = self.parent.isFingerprintBound
                if !self.parent.isFingerprintBound {
                    self.parent.isFingerprintBound = true
                    AppController.shared.showBusyPrompt(vc)
                    self.cancelCallback = AppController.shared.coldWalletStartVerifyingBoundLoginFingerprint { (succeeded, error) in
                        AppController.shared.hideBusyPrompt(vc)
                        guard succeeded, error == nil else {
                            AppController.shared.showAlert("failed_to_bind_fp".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                                vc.cancelButtonAction(vc.cancelButton)
                            })])
                            return
                        }
                        vc.titleLabel.stringValue = "verify_bound_fingerprints".localizedString
                        vc.descriptionLabel.stringValue = "verify_fp_for_verifying_binding".localizedString
                        let style = NSMutableParagraphStyle()
                        style.alignment = .center
                        vc.doneButton.attributedTitle = NSAttributedString(string: "done".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
                        vc.doneButton.attributedAlternateTitle = NSAttributedString(string: "done".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
                        vc.verifyFingerprint()
                    }
                }
                return complete
            }
            
            func fpVerificationDidComplete(_ vc: FingerprintVerificationViewController, _ done: Bool, _ verified: Bool) {
                self.parent.fpVerificationDelegate = nil
                guard done, verified else {
                    self.cancelCallback()
                    return
                }
                AppController.shared.showBusyPrompt()
                self.cancelCallback = AppController.shared.coldWalletFinishVerifyingBoundLoginFingerprint(false) { (succeeded, error) in
                    guard succeeded, error == nil else {
                        AppController.shared.hideBusyPrompt()
                        AppController.shared.showAlert("failed_to_bind_fp".localizedString)
                        self.cancelCallback()
                        return
                    }
                    AppController.shared.coldWalletFinishBindingLoginFingerprint(false) { (succeeded, error) in
                        AppController.shared.hideBusyPrompt()
                        guard succeeded, error == nil else {
                            AppController.shared.showAlert("failed_to_bind_fp".localizedString)
                            self.cancelCallback()
                            return
                        }
                        AppController.shared.showInformation("bind_succeeded".localizedString)
                    }
                }
            }
        }
        
        self.isFingerprintBound = false
        var cancelCallback: (() -> ())!
        AppController.shared.showBusyPrompt()
        let callback = AppController.shared.coldWalletStartBindingLoginFingerprint { (succeeded, error) in
            AppController.shared.hideBusyPrompt()
            guard succeeded, error == nil else {
                (error != nil) ? ATLog.debug(error!.description) : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    AppController.shared.showAlert("failed_to_start_binding_login_fp".localizedString)
                }
                return
            }
            self.fpVerificationDelegate = Delegate(self, cancelCallback)
            AppController.shared.presentAsSheet(.FingerprintVerification) { (vc) in
                guard let fpVerificationVC = vc as? FingerprintVerificationViewController else { return }
                fpVerificationVC.delegate = self.fpVerificationDelegate
            }
        }
        cancelCallback = callback
    }
    
    func unbindLoginFingerprint() {
        let yesAction = AppController.AlertAction(title: "yes".localizedString) {
            AppController.shared.showBusyPrompt()
            AppController.shared.coldWalletUnbindLoginFingerprint { (succeeded, error) in
                AppController.shared.hideBusyPrompt()
                guard succeeded, error == nil else {
                    (error != nil) ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString) {
                            AppController.shared.popSplitDetailViewToRootViewController()
                        }])
                    case .failToConnect:
                        AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                    default:
                        AppController.shared.showAlert("failed_to_unbind_fp".localizedString)
                    }
                    return
                }
                AppController.shared.showInformation("login_fp_have_been_unbound".localizedString)
            }
        }
        let noAction = AppController.AlertAction(title: "no".localizedString, callback: nil)
        AppController.shared.showInformation("unbind_login_fp_check_msg".localizedString, nil, [yesAction, noAction])
    }
    
    func initHiddenWallet() {
        guard AppController.shared.coldWalletGetHDWallet()?.hdwIndex == ATHDWallet.Index.first.rawValue else { return }
        AppController.shared.pushSplitDetailView(.WalletInitialization) { (vc) in
            guard let walletInitVC = vc as? WalletInitializationViewController else { return }
            walletInitVC.hdwIndex = .second
        }
    }
    
    func switchToAnotherWallet() {
        AppController.shared.switchToAnotherHDWallet(self)
    }
    
    func addCryptocurrency() {
        var items: [String] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        for cryptocurrencyType in ATCryptocurrencyType.allCases {
            items.append(cryptocurrencyType.name)
            let size = cryptocurrencyType.name.sizeOfFont(NSFont.systemFont(ofSize: 13))
            (size.width > width) ? width = size.width : nil
            (size.height > height) ? height = size.height : nil
        }
        let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, width + 40, height + 10))
        popUpButton.addItems(withTitles: items)
        popUpButton.selectItem(at: 0)
        let okAction = AppController.AlertAction(title: "ok".localizedString) {
            let index = popUpButton.indexOfSelectedItem
            let cryptocurrencyType = ATCryptocurrencyType.allCases[index]
            var walletNames: [String] = []
            for wallet in AppController.shared.coldWalletGetHDWallet()?.wallets ?? [] {
                walletNames.append(wallet.name)
            }
            var name = cryptocurrencyType.name
            var count = 1
            while walletNames.contains(name) {
                count += 1
                name = "\(cryptocurrencyType.name) \(count)"
            }
            AppController.shared.showBusyPrompt()
            AppController.shared.coldWalletAddNewCryptocurrency(nil, cryptocurrencyType, nil, name, nil) { (succeeded, error) in
                AppController.shared.hideBusyPrompt()
                guard succeeded, error == nil else {
                    (error != nil) ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString) {
                            AppController.shared.popSplitDetailViewToRootViewController()
                        }])
                    case .failToConnect:
                        AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                    default:
                        AppController.shared.showAlert("failed_to_add_cryptocurrency".localizedString)
                    }
                    return
                }
            }
        }
        let cancelAction = AppController.AlertAction(title: "cancel".localizedString, callback: nil)
        let advancedAction = AppController.AlertAction(title: "advanced".localizedString) {
            let index = popUpButton.indexOfSelectedItem
            let cryptocurrencyType = ATCryptocurrencyType.allCases[index]
            var topLevelArray: NSArray? = nil
            Bundle.main.loadNibNamed("AdvancedCryptocurrencyInfoView", owner: nil, topLevelObjects: &topLevelArray)
            var v: AdvancedCryptocurrencyInfoView?
            for object in topLevelArray ?? [] {
                if let view = object as? AdvancedCryptocurrencyInfoView {
                    v = view
                    break
                }
            }
            guard let view = v else { return }
            view.nickNameTextField.placeholderString = "nickname".localizedString
            view.nickNameTextField.stringValue = ""
            let segwitPurposeItems = ["44'", "84'"] // TODO: 49'
            let nonsegwitPurposeItems = ["44'"]
            let purposeItems = (cryptocurrencyType == .btc || cryptocurrencyType == .ltc) ? segwitPurposeItems : nonsegwitPurposeItems
            let purposeValues = ["44'": UInt32(0x8000002C), "49'": UInt32(0x80000031), "84'": UInt32(0x80000054)]
            view.purposePupUpButton.removeAllItems()
            view.purposePupUpButton.addItems(withTitles: purposeItems)
            view.purposePupUpButton.selectItem(at: 0)
            view.coinTypeTextField.placeholderString = "Coin Type'"
            view.coinTypeTextField.stringValue = "\(cryptocurrencyType.coinType & 0x7FFFFFFF)'"
            view.coinTypeTextField.isEditable = false
            view.coinTypeTextField.alphaValue = 0.3
            view.accountTextField.placeholderString = "Account'"
            view.accountTextField.stringValue = ""
            view.timestampTexdtField.placeholderString = "timestamp".localizedString
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            view.timestampTexdtField.stringValue = dateFormatter.string(from: Date())
            let okAction = AppController.AlertAction(title: "ok".localizedString, callback: {
                var name = (view.nickNameTextField.stringValue != "") ? view.nickNameTextField.stringValue : nil
                if name == nil {
                    var walletNames: [String] = []
                    for wallet in AppController.shared.coldWalletGetHDWallet()?.wallets ?? [] {
                        walletNames.append(wallet.name)
                    }
                    name = cryptocurrencyType.name
                    var count = 1
                    while walletNames.contains(name!) {
                        count += 1
                        name = "\(cryptocurrencyType.name) \(count)"
                    }
                }
                let purpose = purposeValues[view.purposePupUpButton.titleOfSelectedItem ?? "44'"] ?? 0x8000002C // use BIP44 as default
                let account = (view.accountTextField.stringValue != "") ? UInt32(view.accountTextField.stringValue.replacingOccurrences(of: "'", with: "")) : nil
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let timestamp = (view.timestampTexdtField.stringValue != "") ? dateFormatter.date(from: view.timestampTexdtField.stringValue) : nil
                AppController.shared.showBusyPrompt()
                AppController.shared.coldWalletAddNewCryptocurrency(purpose, cryptocurrencyType, account, name, timestamp) { (succeeded, error) in
                    AppController.shared.hideBusyPrompt()
                    guard succeeded, error == nil else {
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        switch error {
                        case .loginRequired:
                            AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString) {
                                AppController.shared.popSplitDetailViewToRootViewController()
                            }])
                        case .failToConnect:
                            AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                        default:
                            AppController.shared.showAlert("failed_to_add_cryptocurrency".localizedString)
                        }
                        return
                    }
                }
            })
            AppController.shared.showInformation(cryptocurrencyType.name, nil, [okAction, cancelAction], view)
        }
        AppController.shared.showInformation("select_one_to_add".localizedString, nil, [okAction, advancedAction, cancelAction], popUpButton)
    }
    
    func deleteCryptocurrency() {
        guard let hdw = AppController.shared.coldWalletGetHDWallet() else { return }
        var items: [String] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        for wallet in hdw.wallets ?? [] {
            var name = wallet.name
            var count = 1
            while items.contains(name) {
                count += 1
                name = "\(wallet.name) (\(count))"
            }
            items.append(name)
            let size = name.sizeOfFont(NSFont.systemFont(ofSize: 13))
            (size.width > width) ? width = size.width : nil
            (size.height > height) ? height = size.height : nil
        }
        let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, width + 40, height + 10))
        popUpButton.addItems(withTitles: items)
        let okAction = AppController.AlertAction(title: "ok".localizedString) {
            let index = popUpButton.indexOfSelectedItem
            guard (hdw.wallets?.count ?? 0) > index, let cryptocurrency = hdw.wallets?[index] else { return }
            let yesAction = AppController.AlertAction(title: "delete".localizedString, callback: {
                AppController.shared.showBusyPrompt()
                AppController.shared.coldWalletDeleteCryptocurrency(cryptocurrency) { (succeeded, error) in
                    AppController.shared.hideBusyPrompt()
                    guard succeeded, error == nil else {
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        switch error {
                        case .loginRequired:
                            AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString) {
                                AppController.shared.popSplitDetailViewToRootViewController()
                            }])
                        case .failToConnect:
                            AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                        default:
                            AppController.shared.showAlert("failed_to_delete".localizedString)
                        }
                        return
                    }
                    AppController.shared.showInformation("succeeded_to_delete".localizedString)
                }
            })
            let noAction = AppController.AlertAction(title: "cancel".localizedString, callback: nil)
            AppController.shared.showInformation("delete_account_warning".localizedString, "\(cryptocurrency.name)\nm / \(cryptocurrency.purpose & 0x7FFFFFFF)' / \(cryptocurrency.coinType & 0x7FFFFFFF)' / \(cryptocurrency.accountValue & 0x7FFFFFFF)'", [yesAction, noAction])
        }
        let cancelAction = AppController.AlertAction(title: "cancel".localizedString, callback: nil)
        AppController.shared.showInformation("select_one_to_delete".localizedString, nil, [okAction, cancelAction], popUpButton)
    }
    
    func logout() {
        AppController.shared.popSplitDetailViewToRootViewController()
    }
    
    // MARK: - Fingerprint Management
    
    func enrollFingerprint() {
        AppController.shared.presentAsSheet(.FingerprintEnrollment)
    }
    
    func deleteFingerprint() {
        struct Delegate: FingerprintVerificationViewControllerDelegate {
            
            let parent: SettingsViewController
            
            init(_ vc: SettingsViewController) {
                self.parent = vc
            }
            
            func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> () {
                vc.titleLabel.stringValue = "delete_fingerprint".localizedString
                vc.descriptionLabel.stringValue = "verify_fp_for_deleting".localizedString
            }
            
            func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool {
                return true
            }
            
            func fpVerificationDidComplete(_ vc: FingerprintVerificationViewController, _ done: Bool, _ verified: Bool) {
                self.parent.fpVerificationDelegate = nil
                guard done, verified else {
                    AppController.shared.coldWalletCancelFingerprintDeletion { (succeeded, error) in
                        // do nothing
                    }
                    return
                }
                AppController.shared.showBusyPrompt("deleting".localizedString)
                AppController.shared.coldWalletFinishFingerprintDeletion({ (succeeded, fpids, error) in
                    AppController.shared.hideBusyPrompt()
                    guard succeeded, error == nil, let fpids = fpids else {
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        AppController.shared.showAlert("failed_to_delete_fingerprints".localizedString)
                        return
                    }
                    
                    var message = ""
                    if fpids.count == 0 {
                        message = "no_fp_deleted".localizedString
                    }
                    else if fpids.count == 1 {
                        message = "1_fp_deleted".localizedString
                    }
                    else {
                        message = "\(fpids.count)\("_fps_deleted".localizedString)"
                    }
                    AppController.shared.showInformation(message)
                })
            }
        }
        
        AppController.shared.showBusyPrompt()
        AppController.shared.coldWalletStartFingerprintDeletion { (succeeded, error) in
            AppController.shared.hideBusyPrompt()
            guard succeeded, error == nil else {
                (error != nil) ? ATLog.debug(error!.description) : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    AppController.shared.showAlert("failed_to_start_fp_deletion".localizedString)
                }
                return
            }
            self.fpVerificationDelegate = Delegate(self)
            AppController.shared.presentAsSheet(.FingerprintVerification) { (vc) in
                guard let fpVerificationVC = vc as? FingerprintVerificationViewController else { return }
                fpVerificationVC.delegate = self.fpVerificationDelegate
            }
        }
    }
    
    func calibrateFingerprintSensor() {
        AppController.shared.showInformation("calibration_warning".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
            AppController.shared.showBusyPrompt("calibrating".localizedString)
            AppController.shared.coldWalletCalibrateFingerprintSensor { (succeeded, error) in
                AppController.shared.hideBusyPrompt()
                guard succeeded, error == nil else {
                    (error != nil) ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                            AppController.shared.popSplitDetailViewToRootViewController()
                        })])
                    case .failToConnect:
                        AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                    default:
                        AppController.shared.showAlert("failed_to_calibrate_fp_sensor".localizedString)
                    }
                    return
                }
                AppController.shared.showInformation("succeeded_to_calibrate_fp_sensor".localizedString)
            }
        })])
    }
    
    // MARK: - Device Management
    
    func updateFirmware() {
        AppController.shared.showBusyPrompt("checking_for_updates".localizedString)
        AppController.shared.checkNewUpdates { (fw, cos) in
            AppController.shared.hideBusyPrompt()
            let newFwAvailable = (fw != nil)
            let newCosAvailable = (cos != nil)
            let newFwVersion = fw?["version"] ?? ""
            let newCosVersion = cos?["version"] ?? ""
            let newFwUrlStr = fw?["url"] ?? ""
            let newCosUrlStr = cos?["url"] ?? ""
            guard fw != nil || cos != nil else {
                AppController.shared.showInformation("firmware_is_update_to_date".localizedString)
                return
            }
            let yesAction = AppController.AlertAction(title: "yes".localizedString, callback: {
                AppController.shared.showBusyPrompt("0%", 0, "fw_updating_warning".localizedString)
                if newFwAvailable && newCosAvailable {
                    guard let fwUrl = URL(string: newFwUrlStr), let cosUrl = URL(string: newCosUrlStr) else {
                        ATLog.debug("Failed to convert string to URL")
                        AppController.shared.hideBusyPrompt()
                        AppController.shared.showAlert("failed_to_download_fw".localizedString)
                        return
                    }
                    let fwDownloadTask = URLSession.shared.dataTask(with: fwUrl) { (data, response, error) in
                        guard error == nil, let data = data else {
                            (error != nil) ? ATLog.debug("\(error!)") : nil
                            DispatchQueue.main.async {
                                AppController.shared.hideBusyPrompt()
                                AppController.shared.showAlert("failed_to_download_fw".localizedString)
                            }
                            return
                        }
                        let fwData = data
                        let cosDownloadTask = URLSession.shared.dataTask(with: cosUrl) { (data, response, error) in
                            guard error == nil, let data = data else {
                                (error != nil) ? ATLog.debug("\(error!)") : nil
                                DispatchQueue.main.async {
                                    AppController.shared.hideBusyPrompt()
                                    AppController.shared.showAlert("failed_to_download_fw".localizedString)
                                }
                                return
                            }
                            let cosData = data
                            AppController.shared.coldWalletUpdateFirmwareAndCos(fwData, cosData) { (progress, error) in
                                guard error == nil else {
                                    AppController.shared.hideBusyPrompt()
                                    ATLog.debug(error!.description)
                                    switch error {
                                    case .loginRequired:
                                        AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                                            AppController.shared.popSplitDetailViewToRootViewController()
                                        })])
                                    case .failToConnect:
                                        AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                                    default:
                                        AppController.shared.showAlert("failed_to_update_fw".localizedString)
                                    }
                                    return
                                }
                                guard progress < 100 else {
                                    AppController.shared.hideBusyPrompt()
                                    AppController.shared.showInformation("update_succeeded_description".localizedString)
                                    return
                                }
                                AppController.shared.showBusyPrompt("\(progress)%", Float(progress) / 100, "fw_updating_warning".localizedString)
                            }
                        }
                        cosDownloadTask.resume()
                    }
                    fwDownloadTask.resume()
                }
                else {
                    let urlStr = newFwAvailable ? newFwUrlStr : newCosUrlStr
                    guard let url = URL(string: urlStr) else {
                        ATLog.debug("Failed to convert string to URL")
                        AppController.shared.hideBusyPrompt()
                        AppController.shared.showAlert("failed_to_download_fw".localizedString)
                        return
                    }
                    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                        guard error == nil, let data = data else {
                            (error != nil) ? ATLog.debug("\(error!)") : nil
                            DispatchQueue.main.async {
                                AppController.shared.hideBusyPrompt()
                                AppController.shared.showAlert("failed_to_download_fw".localizedString)
                            }
                            return
                        }
                        let callback: (_ progress: Int, _ error: ATError?) -> () = { (progress, error) in
                            guard error == nil else {
                                AppController.shared.hideBusyPrompt()
                                AppController.shared.showAlert("failed_to_update_fw".localizedString)
                                return
                            }
                            guard progress < 100 else {
                                AppController.shared.hideBusyPrompt()
                                AppController.shared.showInformation("update_succeeded_description".localizedString)
                                return
                            }
                            AppController.shared.showBusyPrompt("\(progress)%", Float(progress) / 100, "fw_updating_warning".localizedString)
                        }
                        newFwAvailable ? AppController.shared.coldWalletUpdateFirmware(data, callback) : AppController.shared.coldWalletUpdateCos(data, callback)
                    }
                    task.resume()
                }
            })
            let noAction = AppController.AlertAction(title: "no".localizedString, callback: nil)
            AppController.shared.showInformation("firmware_update_description".localizedString, "\((newFwAvailable) ? "FW: \(newFwVersion)\n" : "")\(newCosAvailable ? "COS: \(newCosVersion)\n" : "")", [yesAction, noAction])
        }
    }
    
    func resetWallet() {
        struct Delegate: FingerprintVerificationViewControllerDelegate {
            
            let parent: SettingsViewController
            
            init(_ vc: SettingsViewController) {
                self.parent = vc
            }
            
            func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> () {
                // do nothing
            }
            
            func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool {
                return true
            }
            
            func fpVerificationDidComplete(_ vc: FingerprintVerificationViewController, _ done: Bool, _ verified: Bool) {
                self.parent.fpVerificationDelegate = nil
                guard done, verified else { return }
                AppController.shared.showBusyPrompt("resetting".localizedString)
                AppController.shared.coldWalletResetHDWallet { (done, error) in
                    AppController.shared.hideBusyPrompt()
                    guard done, error == nil else {
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        switch error {
                        case .loginRequired:
                            AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                                AppController.shared.popSplitDetailViewToRootViewController()
                            })])
                        case .failToConnect:
                            AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                        default:
                            AppController.shared.showAlert("failed_to_reset".localizedString)
                        }
                        return
                    }
                    AppController.shared.showInformation("reset_complete_description".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                }
            }
        }
        
        let yesAction = AppController.AlertAction(title: "yes".localizedString, callback: {
            self.fpVerificationDelegate = Delegate(self)
            AppController.shared.presentAsSheet(.FingerprintVerification) { (vc) in
                guard let fpVerificationVC = vc as? FingerprintVerificationViewController else { return }
                fpVerificationVC.delegate = self.fpVerificationDelegate
            }
        })
        let noAction = AppController.AlertAction(title: "no".localizedString, callback: nil)
        AppController.shared.showInformation("reset_wallet_description".localizedString, nil, [yesAction, noAction])
    }
    
    func resetToFactory() {
        struct Delegate: FingerprintVerificationViewControllerDelegate {
            
            let parent: SettingsViewController
            
            init(_ vc: SettingsViewController) {
                self.parent = vc
            }
            
            func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> () {
                // do nothing
            }
            
            func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool {
                return true
            }
            
            func fpVerificationDidComplete(_ vc: FingerprintVerificationViewController, _ done: Bool, _ verified: Bool) {
                self.parent.fpVerificationDelegate = nil
                guard done, verified else { return }
                AppController.shared.showBusyPrompt("resetting".localizedString)
                AppController.shared.coldWalletDoFactoryReset { (done, error) in
                    AppController.shared.hideBusyPrompt()
                    guard done, error == nil else {
                        AppController.shared.hideBusyPrompt()
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        switch error {
                        case .loginRequired:
                            AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                                AppController.shared.popSplitDetailViewToRootViewController()
                            })])
                        case .failToConnect:
                            AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                        default:
                            AppController.shared.showAlert("failed_to_reset".localizedString)
                        }
                        return
                    }
                    AppController.shared.showInformation("reset_complete_description".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        (done) ? AppController.shared.popSplitDetailViewToRootViewController() : nil
                    })])
                }
            }
        }

        let yesAction = AppController.AlertAction(title: "yes".localizedString, callback: {
            self.fpVerificationDelegate = Delegate(self)
            AppController.shared.presentAsSheet(.FingerprintVerification) { (vc) in
                guard let fpVerificationVC = vc as? FingerprintVerificationViewController else { return }
                fpVerificationVC.delegate = self.fpVerificationDelegate
            }
        })
        let noAction = AppController.AlertAction(title: "no".localizedString, callback: nil)
        AppController.shared.showInformation("factory_reset_description".localizedString, nil, [yesAction, noAction])
    }
    
    func showDeviceInformation() {
        AppController.shared.showBusyPrompt()
        AppController.shared.coldWalletGetDeviceInformationDescription { (description, error) in
            AppController.shared.hideBusyPrompt()
            guard error == nil else {
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    AppController.shared.showAlert("failed_to_get_device_info".localizedString)
                }
                return
            }
            AppController.shared.showInformation(description)
        }
    }
    
    // MARK: Preferences
    
    func changeDisplayCurrency() {
        var items: [String] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        for currency in ATExchangeRates.currencies {
            items.append(currency)
            let size = currency.sizeOfFont(NSFont.systemFont(ofSize: 13))
            (size.width > width) ? width = size.width : nil
            (size.height > height) ? height = size.height : nil
        }
        let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, width + 40, height + 10))
        popUpButton.addItems(withTitles: items)
        if let index = ATExchangeRates.currencies.firstIndex(of: AppConfig.shared.defaultCurrencyUnit) {
            popUpButton.selectItem(at: index)
        }
        let okAction = AppController.AlertAction(title: "ok".localizedString) {
            let index = popUpButton.indexOfSelectedItem
            AppConfig.shared.defaultCurrencyUnit = ATExchangeRates.currencies[index]
            for wallet in AppController.shared.coldWalletGetHDWallet()?.wallets ?? [] {
                ATExchangeRates().cryptocurrencyToCurrency(wallet.currencyType.symbol, AppConfig.shared.defaultCurrencyUnit) { (rate) in
                    wallet.exchangeRates[AppConfig.shared.defaultCurrencyUnit.description] = rate
                }
            }
        }
        let cancelAction = AppController.AlertAction(title: "cancel".localizedString, callback: nil)
        AppController.shared.showInformation("select_currency".localizedString, nil, [okAction, cancelAction], popUpButton)
    }
    
    // MARK: - NSCollectionViewDataSource & NSCollectionViewDelegate
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return self.settingsFunctionGroups.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.settingsFunctionGroups[section].value.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
        return NSSize(width: self.collectionView.bounds.width, height: 60)
    }
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: 130, height: 130)
    }
    
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        guard kind == NSCollectionView.elementKindSectionHeader else { return NSView() }
        guard let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader, withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SettingsCollectionViewSectionHeader"), for: indexPath) as? SettingsCollectionViewSectionHeader else { return NSView() }
        view.titleLabel.stringValue = self.settingsFunctionGroups[indexPath.section].key.localizedString
        return view
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let functionName = self.settingsFunctionGroups[indexPath.section].value[indexPath.item].key
        guard let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "SettingsCollectionViewItem"), for: indexPath) as? SettingsCollectionViewItem else { return NSCollectionViewItem() }
        item.titleLabel.stringValue = functionName.localizedString
        item.titleLabel.alphaValue = 1.0
        item.iconImageView.image = self.functionImages[functionName]
        item.iconImageView.alphaValue = 1.0
        item.isHighlightable = true
        if AppController.shared.coldWalletGetHDWallet()?.hdwIndex == ATHDWallet.Index.second.rawValue, functionName == "init_hidden_wallet" {
            item.titleLabel.alphaValue = 0.3
            item.iconImageView.alphaValue = 0.3
        }
        else if functionName == "bind_login_fingerprint", !bindingFingerprintEnabled {
            item.isHighlightable = false
            item.titleLabel.alphaValue = 0.3
            item.iconImageView.alphaValue = 0.3
        }
        else if !AppController.shared.isColdWalletUSBDevice(), functionName == "firmware_update", !firmwareUpdateEnabled {
            item.isHighlightable = false
            item.titleLabel.alphaValue = 0.3
            item.iconImageView.alphaValue = 0.3
        }
        return item
    }
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        collectionView.deselectItems(at: indexPaths)
        guard let indexPath = indexPaths.first else { return }
        let function = self.settingsFunctionGroups[indexPath.section].value[indexPath.item].value
        let functionName = self.settingsFunctionGroups[indexPath.section].value[indexPath.item].key
        
        struct TapCounter {
            static var itemName = ""
            static var timestamp = Date()
            static var continuousTapTimes = 0
        }
        if TapCounter.itemName != functionName {
            TapCounter.itemName = functionName
            TapCounter.timestamp = Date()
            TapCounter.continuousTapTimes = 1
        }
        else if abs(TapCounter.timestamp.timeIntervalSinceNow) > 1 {
            TapCounter.timestamp = Date()
            TapCounter.continuousTapTimes = 1
        }
        else {
            TapCounter.timestamp = Date()
            TapCounter.continuousTapTimes += 1
        }
        
        if functionName == "bind_login_fingerprint", !bindingFingerprintEnabled {
            if TapCounter.continuousTapTimes >= 20 {
                self.bindingFingerprintEnabled = true
                collectionView.reloadItems(at: Set<IndexPath>(arrayLiteral: indexPath))
            }
            return
        }
        else if !AppController.shared.isColdWalletUSBDevice(), functionName == "firmware_update", !firmwareUpdateEnabled {
            if TapCounter.continuousTapTimes >= 20 {
                self.firmwareUpdateEnabled = true
                collectionView.reloadItems(at: Set<IndexPath>(arrayLiteral: indexPath))
            }
            return
        }
        
        function()
    }
            
}
