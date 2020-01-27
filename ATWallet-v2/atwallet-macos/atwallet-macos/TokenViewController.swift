//
//  TokenViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2020/1/3.
//  Copyright © 2020 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class TokenViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var cryptocurrencyNameLabel: NSTextField!
    @IBOutlet weak var currencyAmountLabel: NSTextField!
    @IBOutlet weak var tokenTableView: NSTableView!
    @IBOutlet weak var backButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    
    private static var this: TokenViewController!
    
    private weak var selectedToken: ATCryptocurrencyToken?
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard wallet == TokenViewController.this.cryptocurrency, AppController.shared.isTopSplitDetailView(TokenViewController.this) else { return }
        TokenViewController.this.updateUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        TokenViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
        self.titleLabel.stringValue = "tokens".localizedString
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
    }
    
    override func viewWillAppear() {
        updateUI()
    }
    
    func updateUI() {
        self.cryptocurrencyNameLabel.stringValue = self.cryptocurrency?.name ?? ""
        self.tokenTableView.reloadData()
        updateCurrencyAmount()
    }
    
    func updateCurrencyAmount() {
        let defaultCurrencyUnit = AppConfig.shared.defaultCurrencyUnit
        var amount = 0.0
        for token in self.cryptocurrency?.tokens ?? [] {
            let balance = Double(token.balanceString) ?? 0
            let rate = token.exchangeRates[defaultCurrencyUnit.description] ?? 0
            amount += abs(balance * rate)
        }
        self.currencyAmountLabel.stringValue = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(defaultCurrencyUnit.description)"
    }
    
    // MARK: - NSTableViewDataSource & NSTableViewDelegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.cryptocurrency?.tokens.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CryptocurrencyTableCellView"), owner: self) as? CryptocurrencyTableCellView
        view?.nameLabel.stringValue = ""
        view?.exchangeRateLabel.stringValue = ""
        view?.currencyAmountLabel.stringValue = ""
        view?.cryptocurrencyAmountLabel.stringValue = ""
        view?.isHidden = true
        guard let tokens = self.cryptocurrency?.tokens, tokens.count > row else { return view }
        let token = tokens[row]
        view?.isHidden = false
        view?.nameLabel.stringValue = token.info.name
        
        var shortBalanceStr = token.balanceString
        if shortBalanceStr.count > 16, let integerLength = shortBalanceStr.indexDistance(of: ".") {
            shortBalanceStr = (integerLength < 16) ? String(shortBalanceStr.prefix(16)) : String(shortBalanceStr.prefix(integerLength))
        }
        view?.cryptocurrencyAmountLabel.stringValue = "\(shortBalanceStr) \(token.info.symbol)"
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit.description
        if let rate = token.exchangeRates[currencyUnit.description] {
            view?.exchangeRateLabel.stringValue = "1 \(token.info.symbol) = \((rate >= 1) ? rate.toString(2) : rate.toString(6)) \(currencyUnit.description)"
            if let balance = Double(token.balanceString) {
                let amount = abs(balance * rate)
                view?.currencyAmountLabel.stringValue = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(currencyUnit.description)"
            }
        }
        return view
    }
            
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let row = tableView.selectedRow
        tableView.deselectAll(self)
        guard let tokens = self.cryptocurrency?.tokens, row >= 0, tokens.count > row else { return }
        self.selectedToken = tokens[row]
        AppController.shared.pushSplitDetailView(.TokenTransaction) { (vc) in
            guard let tokenTransactionVC = vc as? TokenTransactionViewController else { return }
            tokenTransactionVC.cryptocurrency = self.cryptocurrency
            tokenTransactionVC.token = self.selectedToken
        }
    }
    
}
