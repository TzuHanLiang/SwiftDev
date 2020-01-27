//
//  WalletRecoveryViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class WalletRecoveryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var recoveryTableView: NSTableView!
    @IBOutlet weak var passphraseDescriptionLabel: NSTextField!
    @IBOutlet weak var passphraseTextField: NSTextField!
    @IBOutlet weak var passphraseCheckTextField: NSTextField!
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    @IBAction func nextButtonAction(_ sender: NSButton) {
        struct SingleClick {
            static var timestamp: TimeInterval = 0
            static func click() -> Bool {
                let current = Date().timeIntervalSince1970
                guard (current - self.timestamp) > 1 else { return false }
                self.timestamp = current
                return true
            }
        }
        guard SingleClick.click() else { return }
        
        guard self.passphraseTextField.stringValue == self.passphraseCheckTextField.stringValue else {
            AppController.shared.showAlert("passphrases_do_not_match".localizedString)
            return
        }
        recoverWallet()
    }
    
    @IBAction func expansionButtonAction(_ sender: NSButton) {
        self.recoveryTableView.tag |= (1 << sender.tag)
        self.recoveryTableView.reloadData()
    }
    
    @objc func popUpButtonAction(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        let group = sender.tag
        guard index >= 0 else { return }
        if sender.accessibilityIdentifier() == "coinTypePopUpButton" {
            guard index > 0 else {
                if self.recoveryCryptocurrencies.count > group, let index = ATCryptocurrencyType.allCases.firstIndex(of: self.recoveryCryptocurrencies[group].currency) {
                    sender.selectItem(at: index + 1)
                }
                return
            }
            let cryptocurrencyType = ATCryptocurrencyType.allCases[index - 1]
            if self.recoveryCryptocurrencies.count > group {
                let old = self.recoveryCryptocurrencies[group]
                var purpose = self.purposeValues["44'"] // use BIP44 as default
                if old.currency == .btc || old.currency == .ltc {
                    purpose = old.purpose
                }
                self.recoveryCryptocurrencies[group] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: purpose, Currency: cryptocurrencyType, Account: old.account, Timestamp: old.timestamp, Name: (old.name == old.currency.name) ? cryptocurrencyType.name : old.name)
            }
            else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
                let timestamp = UInt32(dateFormatter.date(from: "2009-01-03")?.timeIntervalSince1970 ?? 0) // the first bitcoin block was created on 3 January 2009
                let purpose = self.purposeValues["44'"] // use BIP44 as default
                self.recoveryCryptocurrencies.append(ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: purpose, Currency: cryptocurrencyType, Account: nil, Timestamp: timestamp, Name: cryptocurrencyType.name))
            }
        }
        else if sender.accessibilityIdentifier() == "yearPopUpButton" {
            guard index > 0 else {
                if self.recoveryCryptocurrencies.count > group {
                    let old = self.recoveryCryptocurrencies[group]
                    self.recoveryCryptocurrencies[group] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: old.purpose, Currency: old.currency, Account: old.account, Timestamp: UInt32(Date().timeIntervalSince1970), Name: old.name)
                }
                return
            }
            if self.recoveryCryptocurrencies.count > group {
                let old = self.recoveryCryptocurrencies[group]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
                let timestamp = UInt32(dateFormatter.date(from: "\(2009 + index - 1)-01-01")?.timeIntervalSince1970 ?? 0)
                self.recoveryCryptocurrencies[group] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: old.purpose, Currency: old.currency, Account: old.account, Timestamp: timestamp, Name: old.name)
            }
        }
        else if sender.accessibilityIdentifier() == "purposePopUpButton" {
            guard index >= 0 else { return }
            if self.recoveryCryptocurrencies.count > group {
                let old = self.recoveryCryptocurrencies[group]
                var purpose: UInt32 = 0x8000002C
                if old.currency == .btc || old.currency == .ltc {
                    purpose = self.purposeValues[self.segwitPurposeItems[index]] ?? 0x8000002C // use BIP44 as default
                }
                self.recoveryCryptocurrencies[group] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: purpose, Currency: old.currency, Account: old.account, Timestamp: old.timestamp, Name: old.name)
            }
        }
        self.recoveryTableView.reloadData()
        if sender.accessibilityIdentifier() == "coinTypePopUpButton", self.recoveryCryptocurrencies.count == (group + 1), (group + 1) < 10 {
            DispatchQueue.main.async {
                self.recoveryTableView.scrollToEndOfDocument(self)
            }
        }
    }
    
    var hdwIndex: ATHDWallet.Index = .any
    var mnemonic: [String] = []
    var name: String?
    
    private let segwitPurposeItems = ["44'", "84'"] // TODO: 49'
    private let nonsegwitPurposeItems = ["44'"]
    private let purposeValues = ["44'": UInt32(0x8000002C), "49'": UInt32(0x80000031), "84'": UInt32(0x80000054)]
    
    private var recoveryCryptocurrencies: [ATColdWallet.CurrencyWalletRecoveryInfo]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.passphraseTextField.wantsLayer = true
        self.passphraseTextField.layer?.cornerRadius = 5
        self.passphraseCheckTextField.wantsLayer = true
        self.passphraseCheckTextField.layer?.cornerRadius = 5
        self.titleLabel.stringValue = "recover_wallet".localizedString
        self.descriptionLabel.stringValue = ""
        self.passphraseDescriptionLabel.stringValue = "passphrase_description_for_recover_wallet".localizedString
        self.passphraseTextField.placeholderString = "passphrase".localizedString
        self.passphraseCheckTextField.placeholderString = "reenter_passphrase".localizedString
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.nextButton.attributedTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.TextColor.self, .paragraphStyle: style])
        self.nextButton.attributedAlternateTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
    }
    
    override func viewWillAppear() {
        self.passphraseTextField.stringValue = ""
        self.passphraseCheckTextField.stringValue = ""
        self.recoveryCryptocurrencies = []
        self.recoveryTableView.tag = 0
        self.recoveryTableView.reloadData()
        self.recoveryTableView.isHidden = (self.hdwIndex == .second)
    }
    
    func recoverWallet() {
        AppController.shared.showBusyPrompt("recovering".localizedString)
        if self.name == nil || self.name?.count == 0 {
            self.name = ((self.hdwIndex == .first) ? "wallet" : "hidden_wallet").localizedString
        }
        let hdwInfo = ATColdWallet.HDWalletRecoveryInfo(Mnemonics: self.mnemonic, Passphrase: self.passphraseTextField.stringValue, Name: self.name!)
        AppController.shared.coldWalletRecoverHDWallet(self.hdwIndex, hdwInfo, self.recoveryCryptocurrencies) { (recovered, error) in
            guard error == nil, recovered == true else {
                AppController.shared.hideBusyPrompt()
                (error != nil ) ? ATLog.debug(error!.description) : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    AppController.shared.showAlert("failed_to_recover_wallet".localizedString)
                }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                AppController.shared.hideBusyPrompt()
                if self.hdwIndex == .first {
                    AppController.shared.pushSplitDetailView(.Wallet)
                }
                else {
                    AppController.shared.showInformation("succeeded_to_initialize_wallet".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        guard AppController.shared.coldWalletGetHDWallet() != nil else {
                            AppController.shared.pushSplitDetailView(.Wallet)
                            return
                        }
                        if !AppController.shared.popSplitDetailViewTo(.Settings) {
                            AppController.shared.pushSplitDetailView(.Wallet)
                        }
                    })])
                }
            }
        }
    }
    
    // MARK: - NSTextFieldDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let group = textField.tag
        guard self.recoveryCryptocurrencies.count > group else { return }
        let old = self.recoveryCryptocurrencies[group]
        let purpose = old.purpose
        let currency = old.currency
        var account = old.account
        let timestamp = old.timestamp
        var name = old.name
        if textField.accessibilityIdentifier() == "nicknameTextField" {
            if textField.stringValue.count > 0 {
                name = textField.stringValue
            }
            else {
                name = currency.name
            }
        }
        else if textField.accessibilityIdentifier() == "accountTextField" {
            account = nil
            if let number = UInt32(textField.stringValue.replacingOccurrences(of: "'", with: "")) {
                account = number | 0x80000000
                textField.stringValue = "\(number)'"
            }
            else {
                textField.stringValue = ""
            }
        }
        self.recoveryCryptocurrencies[group] = ATColdWallet.CurrencyWalletRecoveryInfo(Purpose: purpose, Currency: currency, Account: account, Timestamp: timestamp, Name: name)
    }
    
    // MARK: - NSTableViewDataSource & NSTableViewDelegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        let group = (self.recoveryCryptocurrencies.count >= 10) ? 10 : (self.recoveryCryptocurrencies.count + 1)
        var numberOfRows = 0
        for index in 0..<group {
            let numberOfLines = (((1 << index) & tableView.tag) > 0) ? 3 : 2
            numberOfRows += numberOfLines
        }
        return numberOfRows
    }
    
    func groupForRow(in tableView: NSTableView, _ row: Int) -> (Int, Int) {
        guard row != 0 else { return (0, 0) }
        let group = (self.recoveryCryptocurrencies.count >= 10) ? 10 : (self.recoveryCryptocurrencies.count + 1)
        var numberOfRows = 0
        var groupNumber = 0
        var rowInGroup = row
        for index in 0..<group {
            let numberOfLines = (((1 << index) & tableView.tag) > 0) ? 3 : 2
            numberOfRows += numberOfLines
            guard numberOfRows <= row else { break }
            groupNumber += 1
            rowInGroup = row - numberOfRows
        }
        return (groupNumber, rowInGroup)
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let position = groupForRow(in: tableView, row)
        let group = position.0
        let index = position.1
        if index == 0 {
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RecoveryGroupHeaderTableCellView"), owner: self) as? RecoveryGroupHeaderTableCellView
            view?.titleTextField.stringValue = "\("cryptocurrency".localizedString) \(group + 1)"
            return view
        }
        else if index == 1, ((1 << group) & tableView.tag) == 0 {
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RecoveryMainTableCellView"), owner: self) as? RecoveryMainTableCellView
            view?.coinTypePopUpButton.tag = group
            view?.expansionButton.tag = group
            view?.coinTypePopUpButton.setAccessibilityIdentifier("coinTypePopUpButton")
            view?.expansionButton.isHidden = (self.recoveryCryptocurrencies.count <= group)
            
            view?.coinTypePopUpButton.target = nil
            view?.coinTypePopUpButton.action = nil
            view?.coinTypePopUpButton.removeAllItems()
            var items: [String] = ["select_currency".localizedString]
            var width: CGFloat = 0
            var height: CGFloat = 0
            for cryptocurrencyType in ATCryptocurrencyType.allCases {
                items.append(cryptocurrencyType.name)
                let size = cryptocurrencyType.name.sizeOfFont(NSFont.systemFont(ofSize: 18))
                (size.width > width) ? width = size.width : nil
                (size.height > height) ? height = size.height : nil
            }
            view?.coinTypePopUpButton.setFrameSize(NSSize(width: width + 40, height: height + 10))
            view?.coinTypePopUpButton.addItems(withTitles: items)
            view?.coinTypePopUpButton.selectItem(at: 0)
            
            if self.recoveryCryptocurrencies.count > group, let index = ATCryptocurrencyType.allCases.firstIndex(of: self.recoveryCryptocurrencies[group].currency) {
                view?.coinTypePopUpButton.selectItem(at: index + 1)
            }
            view?.coinTypePopUpButton.target = self
            view?.coinTypePopUpButton.action = #selector(popUpButtonAction(_:))
            return view
        }
        else if index == 1, ((1 << group) & tableView.tag) > 0 {
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RecoveryFullTableCellView"), owner: self) as? RecoveryFullTableCellView
            view?.coinTypePopUpButton.tag = group
            view?.nicknameTextField.tag = group
            view?.yearPopUpButton.tag = group
            view?.coinTypePopUpButton.setAccessibilityIdentifier("coinTypePopUpButton")
            view?.nicknameTextField.stringValue = ""
            view?.nicknameTextField.placeholderString = "nickname".localizedString
            view?.nicknameTextField.setAccessibilityIdentifier("nicknameTextField")
            view?.yearPopUpButton.setAccessibilityIdentifier("yearPopUpButton")
            
            view?.coinTypePopUpButton.target = nil
            view?.coinTypePopUpButton.action = nil
            view?.coinTypePopUpButton.removeAllItems()
            var items = ["select_currency".localizedString]
            var width: CGFloat = 0
            var height: CGFloat = 0
            for cryptocurrencyType in ATCryptocurrencyType.allCases {
                items.append(cryptocurrencyType.name)
                let size = cryptocurrencyType.name.sizeOfFont(NSFont.systemFont(ofSize: 18))
                (size.width > width) ? width = size.width : nil
                (size.height > height) ? height = size.height : nil
            }
            view?.coinTypePopUpButton.setFrameSize(NSSize(width: width + 40, height: height + 10))
            view?.coinTypePopUpButton.addItems(withTitles: items)
            view?.coinTypePopUpButton.selectItem(at: 0)
            
            view?.yearPopUpButton.target = nil
            view?.yearPopUpButton.action = nil
            view?.yearPopUpButton.removeAllItems()
            items = ["year".localizedString]
            let size = items[0].sizeOfFont(NSFont.systemFont(ofSize: 18))
            width = size.width
            height = size.height
            let thisYear = Calendar.current.component(.year, from: Date())
            if thisYear >= 2009 {
                for year in 2009...thisYear {
                    let yearStr = String(year)
                    items.append(yearStr)
                    let size = yearStr.sizeOfFont(NSFont.systemFont(ofSize: 18))
                    (size.width > width) ? width = size.width : nil
                    (size.height > height) ? height = size.height : nil
                }
            }
            view?.yearPopUpButton.setFrameSize(NSSize(width: width + 40, height: height + 10))
            view?.yearPopUpButton.addItems(withTitles: items)
            view?.yearPopUpButton.selectItem(at: 0)
            
            if self.recoveryCryptocurrencies.count > group, let index = ATCryptocurrencyType.allCases.firstIndex(of: self.recoveryCryptocurrencies[group].currency) {
                let currencyName = self.recoveryCryptocurrencies[group].currency.name
                let nickname = self.recoveryCryptocurrencies[group].name
                view?.nicknameTextField.stringValue = (nickname != currencyName) ? nickname : ""
                view?.coinTypePopUpButton.selectItem(at: index + 1)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(abbreviation: "GMT+0:00")
                if self.recoveryCryptocurrencies[group].timestamp != UInt32(dateFormatter.date(from: "2009-01-03")?.timeIntervalSince1970 ?? 0) {
                    let date = Date(timeIntervalSince1970: TimeInterval(self.recoveryCryptocurrencies[group].timestamp))
                    let year = Calendar.current.component(.year, from: date)
                    if let index = view?.yearPopUpButton.indexOfItem(withTitle: String(year)), index > 0 {
                        view?.yearPopUpButton.selectItem(at: index)
                    }
                }
            }
            view?.coinTypePopUpButton.target = self
            view?.coinTypePopUpButton.action = #selector(popUpButtonAction(_:))
            view?.yearPopUpButton.target = self
            view?.yearPopUpButton.action = #selector(popUpButtonAction(_:))
            return view
        }
        else if index == 2 {
            let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RecoveryPathTableCellView"), owner: self) as? RecoveryPathTableCellView
            view?.purposePopUpButton.tag = group
            view?.coinTypeTextField.tag = group
            view?.accountTextField.tag = group
            view?.purposePopUpButton.target = nil
            view?.purposePopUpButton.action = nil
            view?.purposePopUpButton.setAccessibilityIdentifier("purposePopUpButton")
            view?.purposePopUpButton.removeAllItems()
            view?.purposePopUpButton.addItems(withTitles: self.nonsegwitPurposeItems)
            view?.purposePopUpButton.selectItem(withTitle: "44'") // use BIP44 as default
            view?.coinTypeTextField.stringValue = ""
            view?.coinTypeTextField.setAccessibilityIdentifier("coinTypeTextField")
            view?.accountTextField.stringValue = ""
            view?.accountTextField.setAccessibilityIdentifier("accountTextField")
            view?.coinTypeTextField.isEditable = false
            view?.coinTypeTextField.alphaValue = 0.3
            if self.recoveryCryptocurrencies.count > group {
                let purpose = self.recoveryCryptocurrencies[group].purpose
                let cryptocurrencyType = self.recoveryCryptocurrencies[group].currency
                let account = self.recoveryCryptocurrencies[group].account
                let purposeString = self.purposeValues.findKeyForValue(purpose ?? 0x8000002C) ?? "44'" // use BIP44 as default
                if cryptocurrencyType == .btc || cryptocurrencyType == .ltc {
                    view?.purposePopUpButton.removeAllItems()
                    view?.purposePopUpButton.addItems(withTitles: self.segwitPurposeItems)
                    view?.purposePopUpButton.selectItem(withTitle: purposeString)
                }
                view?.coinTypeTextField.stringValue = "\(cryptocurrencyType.coinType & 0x7FFFFFFF)'"
                (account != nil) ? view?.accountTextField.stringValue = "\(account! & 0x7FFFFFFF)'" : nil
            }
            view?.purposePopUpButton.target = self
            view?.purposePopUpButton.action = #selector(popUpButtonAction(_:))
            return view
        }
        return nil
    }
    
}

fileprivate extension Dictionary where Value: Hashable {
    func findKeyForValue(_ value: UInt32) -> String? {
        var key: String? = nil
        for k in self.keys {
            if let v = self[k] as? UInt32, v == value {
                key = k as? String
                break
            }
        }
        return key
    }
}
