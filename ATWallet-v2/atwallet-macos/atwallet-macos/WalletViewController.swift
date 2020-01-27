//
//  WalletViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class WalletViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate  {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var currencyAmountLabel: NSTextField!
    @IBOutlet weak var cryptocurrencyTableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    
    @IBAction func addButtonAction(_ sender: NSButton) {
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
            AppController.shared.coldWalletAddNewCryptocurrency(nil, cryptocurrencyType, nil, name, nil) { (added, error) in
                AppController.shared.hideBusyPrompt()
                guard added, error == nil else {
                    AppController.shared.showAlert((error == .failToConnect) ? "failed_to_connect_and_check_power_on".localizedString : "failed_to_add_cryptocurrency".localizedString)
                    return
                }
                self.updateUI()
            }
        }
        let cancelAction = AppController.AlertAction(title: "cancel".localizedString, callback: nil)
        AppController.shared.showInformation("select_one_to_add".localizedString, nil, [okAction, cancelAction], popUpButton)
    }
    
    weak var selectedCryptocurrency: ATCryptocurrencyWallet?
    
    private static var this: WalletViewController!
    
    private weak var hdWallet: ATHDWallet?
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard AppController.shared.isTopSplitDetailView(WalletViewController.this) else { return }
        
        WalletViewController.this.updateCurrencyAmount()
        if let index = WalletViewController.this.hdWallet?.wallets?.firstIndex(of: wallet) {
            WalletViewController.this.cryptocurrencyTableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
        }
        else {
            WalletViewController.this.cryptocurrencyTableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.addButton.alternateImage = self.addButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        WalletViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
    }
    
    override func viewWillAppear() {
        self.titleLabel.stringValue = ""
        self.currencyAmountLabel.stringValue = ""
        self.addButton.isHidden = true
        self.hdWallet = nil
        if AppController.shared.hasColdWalletInfoUpdated() {
            self.hdWallet = AppController.shared.coldWalletGetHDWallet()
            updateUI()
        }
    }
    
    override func viewDidAppear() {
        guard AppController.shared.hasColdWalletInfoUpdated() else {
            AppController.shared.showBusyPrompt()
            Thread.detachNewThread {
                var retryCount = 0
                while !AppController.shared.hasColdWalletInfoUpdated() {
                    sleep(1)
                    retryCount += 1
                    if retryCount >= 10 {
                        break
                    }
                }
                self.hdWallet = AppController.shared.coldWalletGetHDWallet()
                DispatchQueue.main.async {
                    self.updateUI()
                    AppController.shared.hideBusyPrompt()
                }
            }
            return
        }
        self.hdWallet = AppController.shared.coldWalletGetHDWallet()
        updateUI()
    }
    
    func updateUI() {
        self.titleLabel.stringValue = self.hdWallet?.name ?? ""
        self.addButton.isHidden = false
        self.cryptocurrencyTableView.reloadData()
        updateCurrencyAmount()
    }
    
    func updateCurrencyAmount() {
        let defaultCurrencyUnit = AppConfig.shared.defaultCurrencyUnit
        var amount = 0.0
        for wallet in self.hdWallet?.wallets ?? [] {
            let balance = Double(wallet.balanceString) ?? 0
            let rate = wallet.exchangeRates[defaultCurrencyUnit.description] ?? 0
            amount += abs(balance * rate)
            for token in wallet.tokens {
                let balance = Double(token.balanceString) ?? 0
                let rate = token.exchangeRates[defaultCurrencyUnit.description] ?? 0
                amount += abs(balance * rate)
            }
        }
        self.currencyAmountLabel.stringValue = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(defaultCurrencyUnit.description)"
    }
        
    // MARK: - NSTableViewDataSource & NSTableViewDelegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.hdWallet?.wallets?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CryptocurrencyTableCellView"), owner: self) as? CryptocurrencyTableCellView
        view?.iconImageView.image = NSImage()
        view?.nameLabel.stringValue = ""
        view?.exchangeRateLabel.stringValue = ""
        view?.currencyAmountLabel.stringValue = ""
        view?.cryptocurrencyAmountLabel.stringValue = ""
        view?.isHidden = true
        guard let wallet = self.hdWallet?.wallets?[row] else { return view }
        view?.isHidden = false
        view?.iconImageView.image = NSImage(named: wallet.currencyType.symbol)
        view?.nameLabel.stringValue = wallet.name
        guard wallet.initialized else {
            view?.currencyAmountLabel.stringValue = "synchronizing".localizedString
            return view
        }
        
        var shortBalanceStr = wallet.balanceString
        if shortBalanceStr.count > 16, let integerLength = shortBalanceStr.indexDistance(of: ".") {
            shortBalanceStr = (integerLength < 16) ? String(shortBalanceStr.prefix(16)) : String(shortBalanceStr.prefix(integerLength))
        }
        view?.cryptocurrencyAmountLabel.stringValue = "\(shortBalanceStr) \(wallet.currencyType.symbol)"
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit.description
        if let rate = wallet.exchangeRates[currencyUnit.description] {
            view?.exchangeRateLabel.stringValue = "1 \(wallet.currencyType.symbol) = \((rate >= 1) ? rate.toString(2) : rate.toString(6)) \(currencyUnit.description)"
            if let balance = Double(wallet.balanceString) {
                let amount = abs(balance * rate)
                view?.currencyAmountLabel.stringValue = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(currencyUnit.description)"
            }
        }
        if wallet.isSyncing {
            view?.currencyAmountLabel.stringValue = "synchronizing".localizedString
        }
        return view
    }
            
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let row = tableView.selectedRow
        tableView.deselectAll(self)
        guard row >= 0 else { return }
        self.selectedCryptocurrency = self.hdWallet?.wallets?[row]
        if self.selectedCryptocurrency != nil {
            AppController.shared.pushSplitDetailView(.Transaction) { (vc) in
                guard let transactionVC = vc as? TransactionViewController else { return }
                transactionVC.cryptocurrency = self.selectedCryptocurrency
                transactionVC.transactions = self.selectedCryptocurrency?.transactions ?? []
            }
        }
    }
    
}
