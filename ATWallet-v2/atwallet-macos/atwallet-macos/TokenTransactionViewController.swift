//
//  TokenTransactionViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2020/1/3.
//  Copyright © 2020 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class TokenTransactionViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var cryptocurrencyNameLabel: NSTextField!
    @IBOutlet weak var exchangeRateLabel: NSTextField!
    @IBOutlet weak var currencyAmountLabel: NSTextField!
    @IBOutlet weak var tokenAmountLabel: NSTextField!
    @IBOutlet weak var transactionTableView: NSTableView!
    @IBOutlet weak var receiveButton: NSButton!
    @IBOutlet weak var sendButton: NSButton!
    @IBOutlet weak var backButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    @IBAction func receiveButtonAction(_ sender: NSButton) {
        AppController.shared.pushSplitDetailView(.CryptocurrencyReceiving) { (vc) in
            guard let cryptocurrencyReceivingVC = vc as? CryptocurrencyReceivingViewController else { return }
            cryptocurrencyReceivingVC.crytocurrencyType = self.cryptocurrency?.currencyType
            cryptocurrencyReceivingVC.tokenInfo = self.token?.info
            cryptocurrencyReceivingVC.addresses = self.cryptocurrency?.receivingAddressesWithFormat
        }
    }
    
    @IBAction func sendButtonAction(_ sender: NSButton) {
        AppController.shared.pushSplitDetailView(.CryptocurrencySending) { (vc) in
            guard let cryptocurrencySendingVC = vc as? CryptocurrencySendingViewController else { return }
            cryptocurrencySendingVC.cryptocurrency = self.cryptocurrency
            cryptocurrencySendingVC.token = self.token
        }
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    weak var token: ATCryptocurrencyToken?
    var transactions: [ATCryptocurrencyTransaction] = []
    
    private static var this: TokenTransactionViewController!
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard wallet == TokenTransactionViewController.this.cryptocurrency, AppController.shared.isTopSplitDetailView(TokenTransactionViewController.this) else { return }
        
        TokenTransactionViewController.this.updateUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        TokenTransactionViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.receiveButton.attributedTitle = NSAttributedString(string: "receive".localizedString, attributes: [.foregroundColor: AppController.TextColor.self, .paragraphStyle: style])
        self.receiveButton.attributedAlternateTitle = NSAttributedString(string: "receive".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.sendButton.attributedTitle = NSAttributedString(string: "send".localizedString, attributes: [.foregroundColor: AppController.TextColor.self, .paragraphStyle: style])
        self.sendButton.attributedAlternateTitle = NSAttributedString(string: "send".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
    }
    
    override func viewWillAppear() {
        updateUI()
    }
    
    func updateUI() {
        self.titleLabel.stringValue = self.token?.info.name ?? ""
        self.cryptocurrencyNameLabel.stringValue = self.cryptocurrency?.name ?? ""
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit.description
        guard let token = self.token else { return }
        self.transactions = token.transactions
        self.transactionTableView.reloadData()
        self.tokenAmountLabel.stringValue = "\(token.balanceString) \(token.info.symbol)"
        
        guard let rate = token.exchangeRates[currencyUnit.description] else {
            self.exchangeRateLabel.stringValue = ""
            self.currencyAmountLabel.stringValue = ""
            return
        }
        self.exchangeRateLabel.stringValue = "1 \(token.info.symbol) = \((rate >= 1) ? rate.toString(2) : rate.toString(6)) \(currencyUnit.description)"
        
        guard let balance = Double(token.balanceString) else { return }
        let amount = abs(balance * rate)
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
        case .sent:
            view?.addressLabel.stringValue = "\("to".localizedString) \(transaction.address)"
            view?.amountLabel.stringValue = "-\(transaction.tokenAmountString) \(transaction.tokenInfo?.symbol ?? "")"
        case .received:
            view?.addressLabel.stringValue = "\("from".localizedString) \(transaction.address)"
            view?.amountLabel.stringValue = "+\(transaction.tokenAmountString) \(transaction.tokenInfo?.symbol ?? "")"
        case .moved:
            ATLog.warning("impossible case")
        }
        
        return view
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let row = tableView.selectedRow
        tableView.deselectAll(self)
        guard row >= 0, row < self.transactions.count else { return }
        let transaction = self.transactions[row]
        AppController.shared.showInformation(transaction.detailDescription)
    }
    
}
