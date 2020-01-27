//
//  WalletRecoveryViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/30.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class WalletRecoveryViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    
    enum PickerType {
        case cryptocurrencyType
        case year
    }
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var recoveryTableView: UITableView!
    @IBOutlet var passphraseDescriptionLabel: UILabel!
    @IBOutlet var passphraseTextField: UITextField!
    @IBOutlet var passphraseCheckTextField: UITextField!
    @IBOutlet var backButton: UIButton!
    @IBOutlet var nextButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func nextButtonAction(_ sender: UIButton) {
        guard self.passphraseTextField.text == self.passphraseCheckTextField.text else {
            AppController.shared.showAlert(self, "passphrases_do_not_match".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: nil)])
            return
        }
        recoverWallet()
    }
    
    @IBAction func expansionButtonAction(_ sender: UIButton) {
        self.recoveryTableView.tag |= (1 << sender.tag)
        self.recoveryTableView.reloadData()
    }
    
    @IBAction func textFieldAction(_ sender: UITextField) {
        let section = sender.tag
        var height: Int
        if sender.accessibilityIdentifier == "cryptocurrencyTypeTextField" {
            self.pickerType = .cryptocurrencyType
            height = 70 * ATCryptocurrencyType.allCases.count
        }
        else if sender.accessibilityIdentifier == "yearTextField" {
            self.pickerType = .year
            height = 70 * (Calendar.current.component(.year, from: Date()) - 2009 + 1)
        }
        else {
            return
        }
        (height > 250) ? height = 250 : nil
        
        let action = UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default) { (action) in
            let index = self.pickerView.selectedRow(inComponent: 0)
            switch self.pickerType! {
            case .cryptocurrencyType:
                let cryptocurrencyType = ATCryptocurrencyType.allCases[index]
                if self.recoveryCryptocurrencies.count > section {
                    let old = self.recoveryCryptocurrencies[section]
                    self.recoveryCryptocurrencies[section] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: old.purpose, Currency: cryptocurrencyType, Account: old.account, Timestamp: old.timestamp, Name: (old.name == old.currency.name) ? cryptocurrencyType.name : old.name)
                }
                else {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
                    let timestamp = UInt32(dateFormatter.date(from: "2009-01-03")?.timeIntervalSince1970 ?? 0) // the first bitcoin block was created on 3 January 2009
                    self.recoveryCryptocurrencies.append(ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: nil, Currency: cryptocurrencyType, Account: nil, Timestamp: timestamp, Name: cryptocurrencyType.name))
                }
            case .year:
                if self.recoveryCryptocurrencies.count > section {
                    let old = self.recoveryCryptocurrencies[section]
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
                    let timestamp = UInt32(dateFormatter.date(from: "\(2009 + index)-01-01")?.timeIntervalSince1970 ?? 0)
                    self.recoveryCryptocurrencies[section] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: old.purpose, Currency: old.currency, Account: old.account, Timestamp: timestamp, Name: old.name)
                }
            }
            self.recoveryTableView.reloadData()
            if self.pickerType == .cryptocurrencyType, self.recoveryCryptocurrencies.count == (section + 1), (section + 1) < 10 {
                DispatchQueue.main.async {
                    self.recoveryTableView.scrollToRow(at: IndexPath(row: 0, section: section + 1), at: .bottom, animated: true)
                }
            }
        }
        self.pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        self.pickerView.reloadAllComponents()
        AppController.shared.showAlert(self, nil, nil, [action], self.pickerView)
    }
    
    var hdwIndex: ATHDWallet.Index = .any
    var mnemonic: [String] = []
    var name: String?
    
    private var pickerView: UIPickerView!
    private var pickerType: PickerType!
    private var recoveryCryptocurrencies: [ATColdWallet.CurrencyWalletRecoveryInfo]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        self.pickerView = UIPickerView()
        self.pickerView.dataSource = self
        self.pickerView.delegate = self
        self.titleLabel.text = NSLocalizedString("recover_wallet", comment: "")
        //self.descriptionLabel.text = NSLocalizedString("", comment: "") // TODO
        self.passphraseDescriptionLabel.text = NSLocalizedString("passphrase_description_for_recover_wallet", comment: "")
        self.passphraseTextField.placeholder = "passphrase".localizedString
        self.passphraseCheckTextField.placeholder = "reenter_passphrase".localizedString
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        if !AppController.shared.isUsingPadUI {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.passphraseTextField.text = nil
        self.passphraseCheckTextField.text = nil
        self.recoveryCryptocurrencies = []
        self.recoveryTableView.tag = 0
        self.recoveryTableView.reloadData()
        self.recoveryTableView.isHidden = (self.hdwIndex == .second)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
    }
    
    @objc func hideKeyboard(_ tap: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    func recoverWallet() {
        AppController.shared.showBusyPrompt(self, "recovering".localizedString)
        if self.name == nil || self.name?.count == 0 {
            self.name = ((self.hdwIndex == .first) ? "wallet" : "hidden_wallet").localizedString
        }
        let hdwInfo = ATColdWallet.HDWalletRecoveryInfo(Mnemonics: self.mnemonic, Passphrase: self.passphraseTextField.text, Name: self.name!)
        AppController.shared.coldWalletRecoverHDWallet(self.hdwIndex, hdwInfo, self.recoveryCryptocurrencies) { (recovered, error) in
            guard error == nil, recovered == true else {
                AppController.shared.hideBusyPrompt(self)
                (error != nil ) ? ATLog.debug("\(error!.description)") : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        AppController.shared.popToRootViewController(self)
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    AppController.shared.showAlert(self, "failed_to_recover_wallet".localizedString, nil)
                }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                AppController.shared.hideBusyPrompt(self)
                if self.hdwIndex == .first {
                    self.performSegue(withIdentifier: "WalletSegue", sender: self)
                }
                else {
                    AppController.shared.showAlert(self, "succeeded_to_initialize_wallet".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: { (action) in
                        guard let viewControllers = self.navigationController?.viewControllers else {
                            self.performSegue(withIdentifier: "WalletSegue", sender: self)
                            return
                        }
                        var settingsViewController: SettingsViewController?
                        for vc in viewControllers {
                            if let settingsVC = vc as? SettingsViewController {
                                settingsViewController = settingsVC
                                break
                            }
                        }
                        if let settingsVC = settingsViewController {
                            self.navigationController?.popToViewController(settingsVC, animated: true)
                        }
                        else {
                            self.performSegue(withIdentifier: "WalletSegue", sender: self)
                        }
                    })])
                }
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField.accessibilityIdentifier == "cryptocurrencyTypeTextField" || textField.accessibilityIdentifier == "yearTextField" {
            self.view.endEditing(true)
            textFieldAction(textField)
            return false
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let section = textField.tag
        guard self.recoveryCryptocurrencies.count > section else { return }
        let old = self.recoveryCryptocurrencies[section]
        var purpose = old.purpose
        let currency = old.currency
        var account = old.account
        let timestamp = old.timestamp
        var name = old.name
        if textField.accessibilityIdentifier == "nicknameTextField" {
            if let text = textField.text, text.count > 0 {
                name = text
            }
            else {
                name = currency.name
            }
        }
        else if textField.accessibilityIdentifier == "purposeTextField" {
            purpose = nil
            if let text = textField.text, let number = UInt32(text.replacingOccurrences(of: "'", with: "")) {
                purpose = number | 0x80000000
                textField.text = "\(number)'"
            }
            else {
                textField.text = "44'"
            }
        }
        else if textField.accessibilityIdentifier == "accountTextField" {
            account = nil
            if let text = textField.text, let number = UInt32(text.replacingOccurrences(of: "'", with: "")) {
                account = number | 0x80000000
                textField.text = "\(number)'"
            }
            else {
                textField.text = nil
            }
        }
        self.recoveryCryptocurrencies[section] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: purpose, Currency: currency, Account: account, Timestamp: timestamp, Name: name)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        let number = self.recoveryCryptocurrencies.count + 1
        return (number > 10) ? 10 : number
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var number = 1
        if AppController.shared.isUsingPadUI {
            number = (((1 << section) & tableView.tag) > 0) ? 2 : 1
        }
        else {
            number = (((1 << section) & tableView.tag) > 0) ? 3 : 1
        }
        return number
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\(NSLocalizedString("cryptocurrency", comment: "")) \(section + 1)"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell: UITableViewCell
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RecoveryMainTableViewCell") as! RecoveryMainTableViewCell
            cell.coinTypeTextField.tag = indexPath.section
            cell.expansionButton.tag = indexPath.section
            cell.coinTypeTextField.text = nil
            cell.expansionButton.isHidden = (((1 << indexPath.section) & tableView.tag) > 0)
            if self.recoveryCryptocurrencies.count > indexPath.section {
                cell.coinTypeTextField.text = self.recoveryCryptocurrencies[indexPath.section].currency.name
            }
            else {
                cell.expansionButton.isHidden = true
            }
            tableViewCell = cell
            
            if AppController.shared.isUsingPadUI, ((1 << indexPath.section) & tableView.tag) > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "RecoveryFullTableViewCell") as! RecoveryFullTableViewCell
                cell.coinTypeTextField.tag = indexPath.section
                cell.nicknameTextField.tag = indexPath.section
                cell.yearTextField.tag = indexPath.section
                cell.coinTypeTextField.text = nil
                cell.nicknameTextField.text = nil
                cell.yearTextField.text = nil
                if self.recoveryCryptocurrencies.count > indexPath.section {
                    cell.coinTypeTextField.text = self.recoveryCryptocurrencies[indexPath.section].currency.name
                    let nickname = self.recoveryCryptocurrencies[indexPath.section].name
                    let currencyName = self.recoveryCryptocurrencies[indexPath.section].currency.name
                    cell.nicknameTextField.text = (nickname != currencyName) ? nickname : nil
                    let date = Date(timeIntervalSince1970: TimeInterval(self.recoveryCryptocurrencies[indexPath.section].timestamp))
                    let year = Calendar.current.component(.year, from: date)
                    cell.yearTextField.text = (year != 2009) ? "\(year)" : nil
                }
                tableViewCell = cell
            }
        }
        else if indexPath.row == 1 {
            if AppController.shared.isUsingPadUI {
                // ((1 << indexPath.section) & tableView.tag) > 0
                let cell = tableView.dequeueReusableCell(withIdentifier: "RecoveryPathTableViewCell") as! RecoveryPathTableViewCell
                cell.purposeTextField.tag = indexPath.section
                cell.coinTypeTextField.tag = indexPath.section
                cell.accountTextField.tag = indexPath.section
                cell.purposeTextField.text = nil
                cell.coinTypeTextField.text = nil
                cell.accountTextField.text = nil
                cell.coinTypeTextField.isUserInteractionEnabled = false
                if self.recoveryCryptocurrencies.count > indexPath.section {
                    let purpose = self.recoveryCryptocurrencies[indexPath.section].purpose
                    let coinType = self.recoveryCryptocurrencies[indexPath.section].currency.coinType
                    let account = self.recoveryCryptocurrencies[indexPath.section].account
                    cell.purposeTextField.text = "\((purpose ?? 44) & 0x7FFFFFFF)'"
                    cell.coinTypeTextField.text = "\(coinType & 0x7FFFFFFF)'"
                    (account != nil) ? cell.accountTextField.text = "\(account! & 0x7FFFFFFF)'" : nil
                }
                tableViewCell = cell
            }
            else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "RecoveryMinorTableViewCell") as! RecoveryMinorTableViewCell
                cell.nicknameTextField.tag = indexPath.section
                cell.yearTextField.tag = indexPath.section
                cell.nicknameTextField.text = nil
                cell.yearTextField.text = nil
                if self.recoveryCryptocurrencies.count > indexPath.section {
                    let nickname = self.recoveryCryptocurrencies[indexPath.section].name
                    let currencyName = self.recoveryCryptocurrencies[indexPath.section].currency.name
                    cell.nicknameTextField.text = (nickname != currencyName) ? nickname : nil
                    let date = Date(timeIntervalSince1970: TimeInterval(self.recoveryCryptocurrencies[indexPath.section].timestamp))
                    let year = Calendar.current.component(.year, from: date)
                    cell.yearTextField.text = (year != 2009) ? "\(year)" : nil
                }
                tableViewCell = cell
            }
        }
        else {
            // ((1 << indexPath.section) & tableView.tag) > 0
            let cell = tableView.dequeueReusableCell(withIdentifier: "RecoveryPathTableViewCell") as! RecoveryPathTableViewCell
            cell.purposeTextField.tag = indexPath.section
            cell.coinTypeTextField.tag = indexPath.section
            cell.accountTextField.tag = indexPath.section
            cell.purposeTextField.text = nil
            cell.coinTypeTextField.text = nil
            cell.accountTextField.text = nil
            cell.coinTypeTextField.isUserInteractionEnabled = false
            if self.recoveryCryptocurrencies.count > indexPath.section {
                let purpose = self.recoveryCryptocurrencies[indexPath.section].purpose
                let coinType = self.recoveryCryptocurrencies[indexPath.section].currency.coinType
                let account = self.recoveryCryptocurrencies[indexPath.section].account
                cell.purposeTextField.text = "\((purpose ?? 44) & 0x7FFFFFFF)'"
                cell.coinTypeTextField.text = "\(coinType & 0x7FFFFFFF)'"
                (account != nil) ? cell.accountTextField.text = "\(account! & 0x7FFFFFFF)'" : nil
            }
            tableViewCell = cell
        }
        return tableViewCell
    }
    
    // MARK: - UIPickerViewDataSource & UIPickerViewDelegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch self.pickerType! {
        case .cryptocurrencyType:
            return ATCryptocurrencyType.allCases.count
        case .year:
            return Calendar.current.component(.year, from: Date()) - 2009 + 1
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch self.pickerType! {
        case .cryptocurrencyType:
            return ATCryptocurrencyType.allCases[row].name
        case .year:
            return "\(2009 + row)"
        }
    }

}
