//
//  SettingsViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/17.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var collectionView: UICollectionView!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        guard self.navigationController?.topViewController == self else { return }
        self.navigationController?.popViewController(animated: true)
    }
    
    private var settingsFunctionGroups: KeyValuePairs<String, KeyValuePairs<String, () -> ()>> = [:]
    private var walletManagementFunctionGroup: KeyValuePairs<String, () -> ()> = [:]
    private var fingerprintManagementFunctionGroup: KeyValuePairs<String, () -> ()> = [:]
    private var deviceManagementFunctionGroup: KeyValuePairs<String, () -> ()> = [:]
    private var preferencesFunctionGroups: KeyValuePairs<String, () -> ()> = [:]
    private var functionImages: [String: UIImage] = [:]
    private var fpVerificationDelegate: FingerprintVerificationViewControllerDelegate?
    private var isFingerprintBound = false
    private var pickerView: UIPickerView!
    private var pickerViewItems: [String] = []
    private var pickerViewSelectionCallback: ((_ pickerView: UIPickerView, _ row: Int, _ component: Int) -> ())? = nil
    private var bindingFingerprintEnabled = false
    private var firmwareUpdateEnabled = false
    private let segwitPurposeItems = ["44'", "84'"] // TODO: 49'
    private let nonsegwitPurposeItems = ["44'"]
    private let purposeValues = ["44'": UInt32(0x8000002C), "49'": UInt32(0x80000031), "84'": UInt32(0x80000054)]

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        
        self.titleLabel.text = "settings".localizedString
        self.descriptionLabel.text = nil
        self.pickerView = UIPickerView()
        self.pickerView.dataSource = self
        self.pickerView.delegate = self
        
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
        
        self.functionImages["rename"] = UIImage(named: "Rename")
        self.functionImages["bind_login_fingerprint"] = UIImage(named: "BindFingerprint")
        self.functionImages["unbind_login_fingerprint"] = UIImage(named: "UnbindFingerprint")
        self.functionImages["init_hidden_wallet"] = UIImage(named: "InitWallet")
        self.functionImages["switch_to_another_wallet"] = UIImage(named: "SwitchWallet")
        self.functionImages["add_cryptocurrency"] = UIImage(named: "AddCryptocurrency")
        self.functionImages["delete_cryptocurrency"] = UIImage(named: "DeleteCryptocurrency")
        self.functionImages["logout"] = UIImage(named: "Logout")
        self.functionImages["enroll_fingerprint"] = UIImage(named: "EnrollFingerprint")
        self.functionImages["delete_fingerprint"] = UIImage(named: "DeleteFingerprint")
        self.functionImages["calibrate_fingerprint_sensor"] = UIImage(named: "CalibrateSensor")
        self.functionImages["firmware_update"] = UIImage(named: "FirmwareUpdate")
        self.functionImages["reset_wallet"] = UIImage(named: "ResetWallet")
        self.functionImages["factory_reset"] = UIImage(named: "FactoryReset")
        self.functionImages["device_information"] = UIImage(named: "DeviceInformation")
        self.functionImages["display_currency"] = UIImage(named: "Currency")
        
        if !AppController.shared.isUsingPadUI {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if AppController.shared.isUsingPadUI {
            self.collectionView.reloadData()
        }
        else {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
    }
        
    // MARK: - Wallet Management
    func rename() {
        guard let hdw = AppController.shared.coldWalletGetHDWallet() else { return }
        var names: [String] = [hdw.name ?? ""]
        for cryptocurrency in hdw.wallets ?? [] {
            names.append(cryptocurrency.name)
        }
        self.pickerViewItems = names
        
        var height = 70 * self.pickerViewItems.count
        (height > 250) ? height = 250 : nil
        let okAction = UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
            let index = self.pickerView.selectedRow(inComponent: 0)
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "rename".localizedString, message: "input_a_new_name".localizedString, preferredStyle: .alert)
                alert.addTextField { (textField) in
                    textField.placeholder = self.pickerViewItems[index]
                }
                
                let okAction = UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                    guard let name = alert.textFields?.first?.text else {
                        ATLog.debug("Text Field is empty")
                        return
                    }
                    if index == 0 {
                        AppController.shared.showBusyPrompt(self, nil)
                        AppController.shared.coldWalletChangeHDWalletName(name) { (succeeded, error) in
                            AppController.shared.hideBusyPrompt(self)
                            guard succeeded, error == nil else {
                                (error != nil) ? ATLog.debug(error!.description) : nil
                                switch error {
                                case .loginRequired:
                                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                        AppController.shared.popToRootViewController(self)
                                    }])
                                case .failToConnect:
                                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                                default:
                                    AppController.shared.showAlert(self, "failed_to_change_name".localizedString, nil)
                                }
                                return
                            }
                            AppController.shared.showAlert(self, "succeeded_to_change_name".localizedString, nil)
                        }
                    }
                    else {
                        guard (hdw.wallets?.count ?? 0) > (index - 1) , let cryptocurrency = hdw.wallets?[index - 1] else { return }
                        AppController.shared.showBusyPrompt(self, nil)
                        AppController.shared.coldWalletChangeCryptocurrencyNickname(cryptocurrency, name) { (succeeded, error) in
                            AppController.shared.hideBusyPrompt(self)
                            guard succeeded, error == nil else {
                                (error != nil) ? ATLog.debug(error!.description) : nil
                                switch error {
                                case .loginRequired:
                                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                        AppController.shared.popToRootViewController(self)
                                    }])
                                case .failToConnect:
                                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                                default:
                                    AppController.shared.showAlert(self, "failed_to_change_name".localizedString, nil)
                                }
                                return
                            }
                            AppController.shared.showAlert(self, "succeeded_to_change_name".localizedString, nil)
                        }
                    }
                }
                let cancelAction = UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil)
                alert.addAction(okAction)
                alert.addAction(cancelAction)
                self.present(alert, animated: true, completion: nil)
            }
        }
        let cancelAction = UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil)
        self.pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        self.pickerView.reloadAllComponents()
        AppController.shared.showAlert(self, "select_one_to_rename".localizedString, nil, [okAction, cancelAction], self.pickerView)
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
                vc.titleLabel.text = "bind_your_fingerprints".localizedString
                vc.descriptionLabel.text = "verify_fp_for_binding".localizedString
                vc.doneButton.setTitle("next".localizedString, for: .normal)
            }
            
            func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool {
                let complete = self.parent.isFingerprintBound
                if !self.parent.isFingerprintBound {
                    self.parent.isFingerprintBound = true
                    AppController.shared.showBusyPrompt(vc, nil)
                    self.cancelCallback = AppController.shared.coldWalletStartVerifyingBoundLoginFingerprin { (succeeded, error) in
                        AppController.shared.hideBusyPrompt(self.parent)
                        guard succeeded, error == nil else {
                            AppController.shared.showAlert(vc, "failed_to_bind_fp".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: { (action) in
                                vc.cancelButtonAction(vc.cancelButton)
                            })])
                            return
                        }
                        vc.titleLabel.text = "verify_bound_fingerprints".localizedString
                        vc.descriptionLabel.text = "verify_fp_for_verifying_binding".localizedString
                        vc.doneButton.setTitle("done".localizedString, for: .normal)
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
                AppController.shared.showBusyPrompt(self.parent, nil)
                self.cancelCallback = AppController.shared.coldWalletFinishVerifyingBoundLoginFingerprint(false) { (succeeded, error) in
                    guard succeeded, error == nil else {
                        AppController.shared.hideBusyPrompt(self.parent)
                        AppController.shared.showAlert(self.parent, "failed_to_bind_fp".localizedString, nil)
                        self.cancelCallback()
                        return
                    }
                    AppController.shared.coldWalletFinishBindingLoginFingerprint(false) { (succeeded, error) in
                        AppController.shared.hideBusyPrompt(self.parent)
                        guard succeeded, error == nil else {
                            AppController.shared.showAlert(self.parent, "failed_to_bind_fp".localizedString, nil)
                            self.cancelCallback()
                            return
                        }
                        AppController.shared.showAlert(self.parent, "bind_succeeded".localizedString, nil)
                    }
                }
            }
        }
        
        self.isFingerprintBound = false
        var cancelCallback: (() -> ())!
        AppController.shared.showBusyPrompt(self, nil)
        let callback = AppController.shared.coldWalletStartBindingLoginFingerprint { (succeeded, error) in
            AppController.shared.hideBusyPrompt(self)
            guard succeeded, error == nil else {
                (error != nil) ? ATLog.debug(error!.description) : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        AppController.shared.popToRootViewController(self)
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    AppController.shared.showAlert(self, "failed_to_start_binding_login_fp".localizedString, nil)
                }
                return
            }
            self.fpVerificationDelegate = Delegate(self, cancelCallback)
            self.performSegue(withIdentifier: "FingerprintVerificationSegue", sender: self)
        }
        cancelCallback = callback
    }
    
    func unbindLoginFingerprint() {
        let yesAction = UIAlertAction(title: "yes".localizedString, style: .default) { (action) in
            AppController.shared.showBusyPrompt(self, nil)
            AppController.shared.coldWalletUnbindLoginFingerprint { (succeeded, error) in
                AppController.shared.hideBusyPrompt(self)
                guard succeeded, error == nil else {
                    (error != nil) ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                            AppController.shared.popToRootViewController(self)
                        }])
                    case .failToConnect:
                        AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                    default:
                        AppController.shared.showAlert(self, "failed_to_unbind_fp".localizedString, nil)
                    }
                    return
                }
                AppController.shared.showAlert(self, "login_fp_have_been_unbound".localizedString, nil)
            }
        }
        let noAction = UIAlertAction(title: "no".localizedString, style: .cancel, handler: nil)
        AppController.shared.showAlert(self, "unbind_login_fp_check_msg".localizedString, nil, [yesAction, noAction])
    }
    
    func initHiddenWallet() {
        guard AppController.shared.coldWalletGetHDWallet()?.hdwIndex == ATHDWallet.Index.first.rawValue else { return }
        self.performSegue(withIdentifier: "WalletInitializationSegue", sender: self)
    }
    
    func switchToAnotherWallet() {
        AppController.shared.switchToAnotherHDWallet(self)
    }
    
    func addCryptocurrency() {
        class TextFieldDelegate: NSObject, UITextFieldDelegate {
            func textFieldDidEndEditing(_ textField: UITextField) {
                if textField.accessibilityIdentifier == "accountTextField" {
                    guard let text = textField.text, let coinType = UInt32(text.replacingOccurrences(of: "'", with: "")), coinType <= 0x7FFFFFFF else {
                        textField.text = nil
                        return
                    }
                    textField.text = "\(coinType)'"
                }
                else if textField.accessibilityIdentifier == "timestampTextField" {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    guard let text = textField.text, dateFormatter.date(from: text) != nil else {
                        textField.text = dateFormatter.string(from: Date())
                        return
                    }
                }
            }
        }
        var textFieldDelegate: TextFieldDelegate? = TextFieldDelegate()
        
        self.pickerViewItems = []
        for cryptocurrency in ATCryptocurrencyType.allCases {
            self.pickerViewItems.append(cryptocurrency.name)
        }
        
        var height = 70 * self.pickerViewItems.count
        (height > 250) ? height = 250 : nil
        let okAction = UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
            self.pickerViewSelectionCallback = nil
            let index = self.pickerView.selectedRow(inComponent: 0)
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
            AppController.shared.showBusyPrompt(self, nil)
            AppController.shared.coldWalletAddNewCryptocurrency(nil, cryptocurrencyType, nil, name, nil) { (added, error) in
                AppController.shared.hideBusyPrompt(self)
                guard added, error == nil else {
                    (error != nil) ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                            AppController.shared.popToRootViewController(self)
                        }])
                    case .failToConnect:
                        AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                    default:
                        AppController.shared.showAlert(self, "failed_to_add_cryptocurrency".localizedString, nil)
                    }
                    return
                }
            }
        }
        let advancedAction = UIAlertAction(title: "advanced".localizedString, style: .default) { (action) in
            let index = self.pickerView.selectedRow(inComponent: 0)
            guard ATCryptocurrencyType.allCases.count > index else { return }
            let cryptocurrency = ATCryptocurrencyType.allCases[index]
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "add_cryptocurrency".localizedString, message: nil, preferredStyle: .alert)
                alert.addTextField { (textField) in
                    textField.placeholder = "nickname".localizedString
                    textField.returnKeyType = .next
                }
                alert.addTextField { (textField) in
                    //textField.delegate = textFieldDelegate
                    textField.accessibilityIdentifier = "purposeTextField"
                    textField.placeholder = "Purpose'"
                    textField.text = "44'" // use BIP44 as default
                    guard cryptocurrency == .btc || cryptocurrency == .ltc else {
                        textField.isUserInteractionEnabled = false
                        textField.alpha = 0.3
                        return
                    }
                    
                    self.pickerViewItems = self.segwitPurposeItems
                    let pickerView = UIPickerView()
                    pickerView.delegate = self
                    pickerView.dataSource = self
                    pickerView.reloadAllComponents()
                    pickerView.selectRow(0, inComponent: 0, animated: false)
                    textField.inputView = pickerView
                    self.pickerViewSelectionCallback = { (pickerView, row, component) in
                        guard row < self.pickerViewItems.count else { return }
                        textField.text = self.pickerViewItems[row]
                    }
                }
                alert.addTextField { (textField) in
                    textField.delegate = textFieldDelegate
                    textField.accessibilityIdentifier = "coinTypeTextField"
                    textField.placeholder = "Coin Type'"
                    textField.returnKeyType = .next
                    textField.keyboardType = .numbersAndPunctuation
                    textField.text = "\(cryptocurrency.coinType & 0x7FFFFFFF)' (\(cryptocurrency.name))"
                    textField.isUserInteractionEnabled = false
                    textField.alpha = 0.3
                }
                alert.addTextField { (textField) in
                    textField.delegate = textFieldDelegate
                    textField.accessibilityIdentifier = "accountTextField"
                    textField.placeholder = "Account'"
                    textField.returnKeyType = .next
                    textField.keyboardType = .numbersAndPunctuation
                    textField.text = nil
                }
                alert.addTextField { (textField) in
                    textField.delegate = textFieldDelegate
                    textField.accessibilityIdentifier = "timestampTextField"
                    textField.placeholder = "timestamp".localizedString
                    textField.returnKeyType = .done
                    textField.keyboardType = .numbersAndPunctuation
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    textField.text = dateFormatter.string(from: Date())
                }
                alert.addAction(UIAlertAction(title: "ok".localizedString, style: .default, handler: { (action) in
                    textFieldDelegate = nil // hold this instance until ok button pressed
                    var name = alert.textFields?[0].text
                    if name == nil {
                        var walletNames: [String] = []
                        for wallet in AppController.shared.coldWalletGetHDWallet()?.wallets ?? [] {
                            walletNames.append(wallet.name)
                        }
                        name = cryptocurrency.name
                        var count = 1
                        while walletNames.contains(name!) {
                            count += 1
                            name = "\(cryptocurrency.name) \(count)"
                        }
                    }
                    var purpose = UInt32(alert.textFields?[1].text?.replacingOccurrences(of: "'", with: "") ?? "44")
                    (purpose != nil) ? purpose = purpose! | 0x80000000 : nil
                    var account = (alert.textFields?[3].text != nil) ? UInt32(alert.textFields![3].text!.replacingOccurrences(of: "'", with: "")) : nil
                    (account != nil) ? account = account! | 0x80000000 : nil
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let timestamp = (alert.textFields?[4].text != nil) ? dateFormatter.date(from: alert.textFields![4].text!) : nil
                    AppController.shared.showBusyPrompt(self, nil)
                    AppController.shared.coldWalletAddNewCryptocurrency(purpose, cryptocurrency, account, name, timestamp) { (succeeded, error) in
                        AppController.shared.hideBusyPrompt(self)
                        guard succeeded, error == nil else {
                            (error != nil) ? ATLog.debug(error!.description) : nil
                            switch error {
                            case .loginRequired:
                                AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                    AppController.shared.popToRootViewController(self)
                                }])
                            case .failToConnect:
                                AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                            default:
                                AppController.shared.showAlert(self, "failed_to_add_cryptocurrency".localizedString, nil)
                            }
                            return
                        }
                    }
                }))
                alert.addAction(UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        let cancelAction = UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil)
        self.pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        self.pickerView.reloadAllComponents()
        AppController.shared.showAlert(self, "select_one_to_add".localizedString, nil, [okAction, advancedAction, cancelAction], self.pickerView)
    }
    
    func deleteCryptocurrency() {
        guard let hdw = AppController.shared.coldWalletGetHDWallet() else { return }
        var names: [String] = []
        for cryptocurrency in hdw.wallets ?? [] {
            names.append(cryptocurrency.name)
        }
        self.pickerViewItems = names
        
        var height = 70 * self.pickerViewItems.count
        (height > 250) ? height = 250 : nil
        let okAction = UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
            let index = self.pickerView.selectedRow(inComponent: 0)
            guard (hdw.wallets?.count ?? 0) > index, let cryptocurrency = hdw.wallets?[index] else { return }
            DispatchQueue.main.async {
                let yesAction = UIAlertAction(title: "delete".localizedString, style: .destructive) { (action) in
                    AppController.shared.showBusyPrompt(self, nil)
                    AppController.shared.coldWalletDeleteCryptocurrency(cryptocurrency) { (succeeded, error) in
                        AppController.shared.hideBusyPrompt(self)
                        guard succeeded, error == nil else {
                            (error != nil) ? ATLog.debug(error!.description) : nil
                            switch error {
                            case .loginRequired:
                                AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                    AppController.shared.popToRootViewController(self)
                                }])
                            case .failToConnect:
                                AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                            default:
                                AppController.shared.showAlert(self, "failed_to_delete".localizedString, nil)
                            }
                            return
                        }
                        AppController.shared.showAlert(self, "succeeded_to_delete".localizedString, nil)
                    }
                }
                let noAction = UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil)
                AppController.shared.showAlert(self, "delete_account_warning".localizedString, "\(cryptocurrency.name)\nm / \(cryptocurrency.purpose & 0x7FFFFFFF)' / \(cryptocurrency.coinType & 0x7FFFFFFF)' / \(cryptocurrency.accountValue & 0x7FFFFFFF)'", [yesAction, noAction])
            }
        }
        let cancelAction = UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil)
        self.pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        self.pickerView.reloadAllComponents()
        AppController.shared.showAlert(self, "select_one_to_delete".localizedString, nil, [okAction, cancelAction], self.pickerView)
    }
    
    func logout() {
        AppController.shared.popToRootViewController(self)
    }
    
    // MARK: - Fingerprint Management
    
    func enrollFingerprint() {
        performSegue(withIdentifier: "FingerprintEnrollmentSegue", sender: true)
    }
    
    func deleteFingerprint() {
        struct Delegate: FingerprintVerificationViewControllerDelegate {
            
            let parent: SettingsViewController
            
            init(_ vc: SettingsViewController) {
                self.parent = vc
            }
            
            func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> () {
                vc.titleLabel.text = "delete_fingerprint".localizedString
                vc.descriptionLabel.text = "verify_fp_for_deleting".localizedString
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
                AppController.shared.showBusyPrompt(self.parent, "deleting".localizedString)
                AppController.shared.coldWalletFinishFingerprintDeletion({ (succeeded, fpids, error) in
                    AppController.shared.hideBusyPrompt(self.parent)
                    guard succeeded, error == nil, let fpids = fpids else {
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        AppController.shared.showAlert(self.parent, "failed_to_delete_fingerprints".localizedString, nil)
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
                    AppController.shared.showAlert(self.parent, message, nil)
                })
            }
        }
        
        AppController.shared.showBusyPrompt(self, nil)
        AppController.shared.coldWalletStartFingerprintDeletion { (succeeded, error) in
            AppController.shared.hideBusyPrompt(self)
            guard succeeded, error == nil else {
                (error != nil) ? ATLog.debug(error!.description) : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        AppController.shared.popToRootViewController(self)
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    AppController.shared.showAlert(self, "failed_to_start_fp_deletion".localizedString, nil)
                }
                return
            }
            self.fpVerificationDelegate = Delegate(self)
            self.performSegue(withIdentifier: "FingerprintVerificationSegue", sender: self)
        }
    }
    
    func calibrateFingerprintSensor() {
        AppController.shared.showAlert(self, "calibration_warning".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: { (action) in
            AppController.shared.showBusyPrompt(self, "calibrating".localizedString)
            AppController.shared.coldWalletCalibrateFingerprintSensor { (succeeded, error) in
                AppController.shared.hideBusyPrompt(self)
                guard succeeded, error == nil else {
                    (error != nil) ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                            AppController.shared.popToRootViewController(self)
                        }])
                    case .failToConnect:
                        AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                    default:
                        AppController.shared.showAlert(self, "failed_to_calibrate_fp_sensor".localizedString, nil)
                    }
                    return
                }
                AppController.shared.showAlert(self, "succeeded_to_calibrate_fp_sensor".localizedString, nil)
            }
        })])
    }
    
    // MARK: - Device Management
    
    func updateFirmware() {
        AppController.shared.showBusyPrompt(self, "checking_for_updates".localizedString)
        AppController.shared.checkNewUpdates { (fw, cos) in
            AppController.shared.hideBusyPrompt(self)
            let newFwAvailable = (fw != nil)
            let newCosAvailable = (cos != nil)
            let newFwVersion = fw?["version"] ?? ""
            let newCosVersion = cos?["version"] ?? ""
            let newFwUrlStr = fw?["url"] ?? ""
            let newCosUrlStr = cos?["url"] ?? ""
            guard fw != nil || cos != nil else {
                AppController.shared.showAlert(self, "firmware_is_update_to_date".localizedString, nil)
                return
            }
            let yesAction = UIAlertAction(title: "yes".localizedString, style: .default) { (action) in
                AppController.shared.showBusyPrompt(self, "0%", 0, "fw_updating_warning".localizedString)
                if newFwAvailable && newCosAvailable {
                    guard let fwUrl = URL(string: newFwUrlStr), let cosUrl = URL(string: newCosUrlStr) else {
                        ATLog.debug("Failed to convert string to URL")
                        AppController.shared.hideBusyPrompt(self)
                        AppController.shared.showAlert(self, "failed_to_download_fw".localizedString, nil)
                        return
                    }
                    let fwDownloadTask = URLSession.shared.dataTask(with: fwUrl) { (data, response, error) in
                        guard error == nil, let data = data else {
                            (error != nil) ? ATLog.debug("\(error!)") : nil
                            DispatchQueue.main.async {
                                AppController.shared.hideBusyPrompt(self)
                                AppController.shared.showAlert(self, "failed_to_download_fw".localizedString, nil)
                            }
                            return
                        }
                        let fwData = data
                        let cosDownloadTask = URLSession.shared.dataTask(with: cosUrl) { (data, response, error) in
                            guard error == nil, let data = data else {
                                (error != nil) ? ATLog.debug("\(error!)") : nil
                                DispatchQueue.main.async {
                                    AppController.shared.hideBusyPrompt(self)
                                    AppController.shared.showAlert(self, "failed_to_download_fw".localizedString, nil)
                                }
                                return
                            }
                            let cosData = data
                            AppController.shared.coldWalletUpdateFirmwareAndCos(fwData, cosData) { (progress, error) in
                                guard error == nil else {
                                    AppController.shared.hideBusyPrompt(self)
                                    ATLog.debug(error!.description)
                                    switch error {
                                    case .loginRequired:
                                        AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                            AppController.shared.popToRootViewController(self)
                                        }])
                                    case .failToConnect:
                                        AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                                    default:
                                        AppController.shared.showAlert(self, "failed_to_update_fw".localizedString, nil)
                                    }
                                    return
                                }
                                guard progress < 100 else {
                                    AppController.shared.hideBusyPrompt(self)
                                    AppController.shared.showAlert(self, "update_succeeded_description".localizedString, nil)
                                    return
                                }
                                AppController.shared.showBusyPrompt(self, "\(progress)%", Float(progress) / 100, "fw_updating_warning".localizedString)
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
                        AppController.shared.hideBusyPrompt(self)
                        AppController.shared.showAlert(self, "failed_to_download_fw".localizedString, nil)
                        return
                    }
                    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                        guard error == nil, let data = data else {
                            (error != nil) ? ATLog.debug("\(error!)") : nil
                            DispatchQueue.main.async {
                                AppController.shared.hideBusyPrompt(self)
                                AppController.shared.showAlert(self, "failed_to_download_fw".localizedString, nil)
                            }
                            return
                        }
                        let callback: (_ progress: Int, _ error: ATError?) -> () = { (progress, error) in
                            guard error == nil else {
                                AppController.shared.hideBusyPrompt(self)
                                AppController.shared.showAlert(self, "failed_to_update_fw".localizedString, nil)
                                return
                            }
                            guard progress < 100 else {
                                AppController.shared.hideBusyPrompt(self)
                                AppController.shared.showAlert(self, "update_succeeded_description".localizedString, nil)
                                return
                            }
                            AppController.shared.showBusyPrompt(self, "\(progress)%", Float(progress) / 100, "fw_updating_warning".localizedString)
                        }
                        newFwAvailable ? AppController.shared.coldWalletUpdateFirmware(data, callback) : AppController.shared.coldWalletUpdateCos(data, callback)
                    }
                    task.resume()
                }
            }
            let noAction = UIAlertAction(title: "no".localizedString, style: .cancel, handler: nil)
            AppController.shared.showAlert(self, "firmware_update_description".localizedString, "\((newFwAvailable) ? "FW: \(newFwVersion)\n" : "")\(newCosAvailable ? "COS: \(newCosVersion)\n" : "")", [yesAction, noAction])
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
                AppController.shared.showBusyPrompt(self.parent, "resetting".localizedString)
                AppController.shared.coldWalletResetHDWallet { (done, error) in
                    AppController.shared.hideBusyPrompt(self.parent)
                    guard done, error == nil else {
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        switch error {
                        case .loginRequired:
                            AppController.shared.showAlert(self.parent, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                AppController.shared.popToRootViewController(self.parent)
                            }])
                        case .failToConnect:
                            AppController.shared.showAlert(self.parent, "failed_to_connect_and_check_power_on".localizedString, nil)
                        default:
                            AppController.shared.showAlert(self.parent, "failed_to_reset".localizedString, nil)
                        }
                        return
                    }
                    AppController.shared.showAlert(self.parent, "reset_complete_description".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: { (action) in
                        AppController.shared.popToRootViewController(self.parent)
                    })])
                }
            }
        }
        
        let yesAction = UIAlertAction(title: "yes".localizedString, style: .default) { (action) in
            self.fpVerificationDelegate = Delegate(self)
            self.performSegue(withIdentifier: "FingerprintVerificationSegue", sender: self)
        }
        let noAction = UIAlertAction(title: "no".localizedString, style: .cancel)
        AppController.shared.showAlert(self, "reset_wallet_description".localizedString, nil, [yesAction, noAction])
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
                AppController.shared.showBusyPrompt(self.parent, "resetting".localizedString)
                AppController.shared.coldWalletDoFactoryReset { (done, error) in
                    AppController.shared.hideBusyPrompt(self.parent)
                    guard done, error == nil else {
                        AppController.shared.hideBusyPrompt(self.parent)
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        switch error {
                        case .loginRequired:
                            AppController.shared.showAlert(self.parent, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                AppController.shared.popToRootViewController(self.parent)
                            }])
                        case .failToConnect:
                            AppController.shared.showAlert(self.parent, "failed_to_connect_and_check_power_on".localizedString, nil)
                        default:
                            AppController.shared.showAlert(self.parent, "failed_to_reset".localizedString, nil)
                        }
                        return
                    }
                    AppController.shared.showAlert(self.parent, "reset_complete_description".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: { (action) in
                        (done) ? AppController.shared.popToRootViewController(self.parent) : nil
                    })])
                }
            }
        }

        let yesAction = UIAlertAction(title: "yes".localizedString, style: .default) { (action) in
            self.fpVerificationDelegate = Delegate(self)
            self.performSegue(withIdentifier: "FingerprintVerificationSegue", sender: self)
        }
        let noAction = UIAlertAction(title: "no".localizedString, style: .cancel)
        AppController.shared.showAlert(self, "factory_reset_description".localizedString, nil, [yesAction, noAction])
    }
    
    func showDeviceInformation() {
        AppController.shared.showBusyPrompt(self, nil)
        AppController.shared.coldWalletGetDeviceInformationDescription { (description, error) in
            AppController.shared.hideBusyPrompt(self)
            guard error == nil else {
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        AppController.shared.popToRootViewController(self)
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    AppController.shared.showAlert(self, "failed_to_get_device_info".localizedString, nil)
                }
                return
            }
            AppController.shared.showAlert(self, description, nil, nil, nil, .left, nil)
        }
    }
    
    // MARK: Preferences
    
    func changeDisplayCurrency() {
        self.pickerViewItems = ATExchangeRates.currencies
        
        var height = 70 * self.pickerViewItems.count
        (height > 250) ? height = 250 : nil
        let okAction = UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
            let index = self.pickerView.selectedRow(inComponent: 0)
            if index < self.pickerViewItems.count {
                AppConfig.shared.defaultCurrencyUnit = self.pickerViewItems[index]
                let exchangeRates = ATExchangeRates()
                for wallet in AppController.shared.coldWalletGetHDWallet()?.wallets ?? [] {
                    exchangeRates.cryptocurrencyToCurrency(wallet.currencyType.symbol, AppConfig.shared.defaultCurrencyUnit) { (rate) in
                        wallet.exchangeRates[AppConfig.shared.defaultCurrencyUnit.description] = rate
                    }
                }
            }
        }
        let cancelAction = UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil)
        self.pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        self.pickerView.reloadAllComponents()
        AppController.shared.showAlert(self, "select_currency".localizedString, nil, [okAction, cancelAction], self.pickerView)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? FingerprintVerificationViewController {
            vc.delegate = self.fpVerificationDelegate
        }
        else if let vc = segue.destination as? WalletInitializationViewController {
            vc.hdwIndex = .second
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.settingsFunctionGroups.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.settingsFunctionGroups[section].value.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.settingsFunctionGroups[section].key.localizedString
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else { return }
        headerView.textLabel?.textColor = UIColor(named: "TextColor")
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let functionName = self.settingsFunctionGroups[indexPath.section].value[indexPath.row].key
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell") as! SettingsTableViewCell
        cell.titleLabel.text = functionName.localizedString
        cell.titleLabel.alpha = 1.0
        cell.iconImageView.image = self.functionImages[functionName]
        cell.iconImageView.alpha = 1.0
        cell.isUserInteractionEnabled = true
        if functionName == "init_hidden_wallet", AppController.shared.coldWalletGetHDWallet()?.hdwIndex == ATHDWallet.Index.second.rawValue {
            cell.titleLabel.alpha = 0.3
            cell.iconImageView.alpha = 0.3
            cell.isUserInteractionEnabled = false
        }
        else if functionName == "bind_login_fingerprint", !bindingFingerprintEnabled {
            cell.titleLabel.alpha = 0.3
            cell.iconImageView.alpha = 0.3
            //cell.isUserInteractionEnabled = false
        }
        else if functionName == "firmware_update", !firmwareUpdateEnabled {
            cell.titleLabel.alpha = 0.3
            cell.iconImageView.alpha = 0.3
            //cell.isUserInteractionEnabled = false
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let function = self.settingsFunctionGroups[indexPath.section].value[indexPath.row].value
        let functionName = self.settingsFunctionGroups[indexPath.section].value[indexPath.row].key
        
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
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return
        }
        else if functionName == "firmware_update", !firmwareUpdateEnabled {
            if TapCounter.continuousTapTimes >= 20 {
                self.firmwareUpdateEnabled = true
                tableView.reloadRows(at: [indexPath], with: .none)
            }
            return
        }
        
        function()
    }
    
    // MARK: - UICollectionViewDataSource & UICollectionViewDelegate
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.settingsFunctionGroups.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.settingsFunctionGroups[section].value.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            let cell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FooterCollectionReusableView", for: indexPath)
            return cell
        }
        let cell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderCollectionReusableView", for: indexPath) as! HeaderCollectionReusableView
        cell.titleLabel.text = self.settingsFunctionGroups[indexPath.section].key.localizedString
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        guard let headerView = view as? HeaderCollectionReusableView else { return }
        headerView.titleLabel.textColor = UIColor(named: "TextColor")
    }
        
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let functionName = self.settingsFunctionGroups[indexPath.section].value[indexPath.row].key
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SettingsCollectionViewCell", for: indexPath) as! SettingsCollectionViewCell
        cell.titleLabel.text = functionName.localizedString
        cell.titleLabel.alpha = 1.0
        cell.iconImageView.image = self.functionImages[functionName]
        cell.iconImageView.alpha = 1.0
        cell.isUserInteractionEnabled = true
        if AppController.shared.coldWalletGetHDWallet()?.hdwIndex == ATHDWallet.Index.second.rawValue, functionName == "init_hidden_wallet" {
            cell.titleLabel.alpha = 0.3
            cell.iconImageView.alpha = 0.3
            cell.isUserInteractionEnabled = false
        }
        else if functionName == "bind_login_fingerprint", !bindingFingerprintEnabled {
            cell.titleLabel.alpha = 0.3
            cell.iconImageView.alpha = 0.3
            //cell.isUserInteractionEnabled = false
        }
        else if functionName == "firmware_update", !firmwareUpdateEnabled {
            cell.titleLabel.alpha = 0.3
            cell.iconImageView.alpha = 0.3
            //cell.isUserInteractionEnabled = false
        }
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let function = self.settingsFunctionGroups[indexPath.section].value[indexPath.item].value
        let functionName = self.settingsFunctionGroups[indexPath.section].value[indexPath.row].key
        
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
                collectionView.reloadItems(at: [indexPath])
            }
            return
        }
        else if functionName == "firmware_update", !firmwareUpdateEnabled {
            if TapCounter.continuousTapTimes >= 20 {
                self.firmwareUpdateEnabled = true
                collectionView.reloadItems(at: [indexPath])
            }
            return
        }
        
        function()
    }
    
    // MARK: - UIPickerViewDataSource & UIPickerViewDelegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerViewItems.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return (row < self.pickerViewItems.count) ? self.pickerViewItems[row] : nil
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.pickerViewSelectionCallback?(pickerView, row, component)
    }

}
