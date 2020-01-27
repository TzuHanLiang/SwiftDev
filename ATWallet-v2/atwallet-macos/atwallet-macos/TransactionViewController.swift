//
//  TransactionViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class TransactionViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var bip32PathLabel: NSTextField!
    @IBOutlet weak var exchangeRateLabel: NSTextField!
    @IBOutlet weak var currencyAmountLabel: NSTextField!
    @IBOutlet weak var cryptocurrencyAmountLabel: NSTextField!
    @IBOutlet weak var transactionTableView: NSTableView!
    @IBOutlet weak var receiveButton: NSButton!
    @IBOutlet weak var sendButton: NSButton!
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var tokenButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    @IBAction func receiveButtonAction(_ sender: NSButton) {
        guard self.cryptocurrency?.initialized == true else {
            AppController.shared.showAlert("wallet_is_still_initializing".localizedString)
            return
        }
        AppController.shared.pushSplitDetailView(.CryptocurrencyReceiving) { (vc) in
            guard let cryptocurrencyReceivingVC = vc as? CryptocurrencyReceivingViewController else { return }
            cryptocurrencyReceivingVC.crytocurrencyType = self.cryptocurrency?.currencyType
            cryptocurrencyReceivingVC.addresses = self.cryptocurrency?.receivingAddressesWithFormat
        }
    }
    
    @IBAction func sendButtonAction(_ sender: NSButton) {
        guard self.cryptocurrency?.initialized == true else {
            AppController.shared.showAlert("wallet_is_still_initializing".localizedString)
            return
        }
        AppController.shared.pushSplitDetailView(.CryptocurrencySending) { (vc) in
            guard let cryptocurrencySendingVC = vc as? CryptocurrencySendingViewController else { return }
            cryptocurrencySendingVC.cryptocurrency = self.cryptocurrency
        }
    }
    
    @IBAction func tokenButtonAction(_ sender: NSButton) {
        guard self.cryptocurrency?.initialized == true else {
            AppController.shared.showAlert("wallet_is_still_initializing".localizedString)
            return
        }
        AppController.shared.pushSplitDetailView(.Token) { (vc) in
            guard let tokenVC = vc as? TokenViewController else { return }
            tokenVC.cryptocurrency = self.cryptocurrency
        }
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    var transactions: [ATCryptocurrencyTransaction] = []
    
    private static var this: TransactionViewController!
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard wallet == TransactionViewController.this.cryptocurrency, AppController.shared.isTopSplitDetailView(TransactionViewController.this) else { return }
        TransactionViewController.this.updateUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        TransactionViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.receiveButton.attributedTitle = NSAttributedString(string: "receive".localizedString, attributes: [.foregroundColor: AppController.TextColor.self, .paragraphStyle: style])
        self.receiveButton.attributedAlternateTitle = NSAttributedString(string: "receive".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.sendButton.attributedTitle = NSAttributedString(string: "send".localizedString, attributes: [.foregroundColor: AppController.TextColor.self, .paragraphStyle: style])
        self.sendButton.attributedAlternateTitle = NSAttributedString(string: "send".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        self.tokenButton.attributedTitle = NSAttributedString(string: "tokens".localizedString, attributes: [.foregroundColor: AppController.TextColor.self, .paragraphStyle: style])
        self.tokenButton.attributedAlternateTitle = NSAttributedString(string: "tokens".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
    }
    
    override func viewWillAppear() {
        updateUI()
    }
    
    func updateUI() {
        self.titleLabel.stringValue = self.cryptocurrency?.name ?? ""
        self.bip32PathLabel.stringValue = ""
        self.tokenButton.isHidden = true
        if let cryptocurrency = self.cryptocurrency {
            self.bip32PathLabel.stringValue = "m / \(cryptocurrency.purpose & 0x7FFFFFFF)' / \(cryptocurrency.coinType & 0x7FFFFFFF)' / \(cryptocurrency.accountValue & 0x7FFFFFFF)'"
            self.tokenButton.isHidden = (cryptocurrency.currencyType != .eth || cryptocurrency.tokens.count == 0)
        }
        self.transactions = self.cryptocurrency?.transactions ?? []
        self.transactionTableView.reloadData()
        self.exchangeRateLabel.stringValue = ""
        self.currencyAmountLabel.stringValue = ""
        guard let cryptocurrency = self.cryptocurrency else { return }
        self.cryptocurrencyAmountLabel.stringValue = "\(cryptocurrency.balanceString) \(cryptocurrency.currencyType.symbol)"
        updateCurrencyAmount()
    }
    
    func updateCurrencyAmount() {
        self.currencyAmountLabel.stringValue = ""
        guard let cryptocurrency = self.cryptocurrency else { return }
        guard let balance = Double(cryptocurrency.balanceString) else { return }
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit
        guard let rate = cryptocurrency.exchangeRates[currencyUnit.description] else { return }
        self.exchangeRateLabel.stringValue = "1 \(cryptocurrency.currencyType.symbol) = \((rate >= 1) ? rate.toString(2) : rate.toString(6)) \(currencyUnit.description)"
        var amount = balance * rate
        for token in cryptocurrency.tokens {
            let balance = Double(token.balanceString) ?? 0
            let rate = token.exchangeRates[currencyUnit.description] ?? 0
            amount += abs(balance * rate)
        }
        self.currencyAmountLabel.stringValue = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(currencyUnit.description)"
    }
    
    // MARK: - NSTableViewDataSource & NSTableViewDelegate
    
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.transactions.count
    }
        
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 60
    }
        
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TransactionTableCellView"), owner: self) as? TransactionTableCellView
        view?.dateLabel.stringValue = ""
        view?.addressLabel.stringValue = ""
        view?.amountLabel.stringValue = ""
        view?.isHidden = true
        guard self.transactions.count > row else { return view }
        let transaction = self.transactions[row]
        view?.isHidden = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        view?.dateLabel.stringValue = dateFormatter.string(from: transaction.date)
        
        switch transaction.direction {
        case .moved:
            view?.addressLabel.stringValue = "\("moved".localizedString)"
            view?.amountLabel.stringValue = "-\(transaction.feeString) \(transaction.currency.symbol)"
        case .sent:
            view?.addressLabel.stringValue = "\("to".localizedString) \(transaction.address)"
            view?.amountLabel.stringValue = "-\(transaction.amountString) \(transaction.currency.symbol)"
        case .received:
            view?.addressLabel.stringValue = "\("from".localizedString) \(transaction.address)"
            view?.amountLabel.stringValue = "+\(transaction.amountString) \(transaction.currency.symbol)"
        }
        view?.alphaValue = transaction.detailDescription.contains("unconfirmed".localizedString) ? 0.3 : 1.0
        
        return view
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let row = tableView.selectedRow
        tableView.deselectAll(self)
        guard row >= 0, row < self.transactions.count else { return }
        let transaction = self.transactions[row]
        var icon: NSImage? = nil
        if let imageName = self.cryptocurrency?.currencyType.symbol {
            icon = NSImage(named: imageName)
        }
        AppController.shared.showInformation(transaction.detailDescription, nil, nil, nil, icon)
    }
    
}
