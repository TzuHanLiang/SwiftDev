//
//  TokenViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2020/1/9.
//  Copyright © 2020 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class TokenViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var cryptocurrencyNameLabel: UILabel!
    @IBOutlet var currencyAmountLabel: UILabel!
    @IBOutlet var tokenTableView: UITableView!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        guard self.navigationController?.topViewController == self else { return }
        self.navigationController?.popViewController(animated: true)
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    
    private static var this: TokenViewController!
    
    private weak var selectedToken: ATCryptocurrencyToken?
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard wallet == TokenViewController.this.cryptocurrency, let vc = TokenViewController.this.navigationController?.topViewController, vc == TokenViewController.this else { return }
        TokenViewController.this.updateUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        TokenViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
        self.titleLabel.text = "tokens".localizedString
        
        if !AppController.shared.isUsingPadUI {
        #if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
        #endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
    }
    
    func updateUI() {
        self.cryptocurrencyNameLabel.text = self.cryptocurrency?.name
        self.tokenTableView.reloadData()
        updateCurrencyAmount()
    }
    
    func updateCurrencyAmount() {
        let defaultCurrencyUnit = AppConfig.shared.defaultCurrencyUnit
        var amount = 0.0
        for token in self.cryptocurrency?.tokens ?? [] {
            let balance = Double(token.balanceString) ?? 0
            let rate = token.exchangeRates[defaultCurrencyUnit.description] ?? 0
            amount += balance * rate
        }
        self.currencyAmountLabel.text = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(defaultCurrencyUnit.description)"
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? TokenTransactionViewController {
            vc.cryptocurrency = self.cryptocurrency
            vc.token = self.selectedToken
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.cryptocurrency?.tokens.count ?? 0
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CryptocurrencyTableViewCell") as! CryptocurrencyTableViewCell
        cell.nameLabel.text = nil
        cell.exchangeRateLabel.text = nil
        cell.currencyAmountLabel.text = nil
        cell.cryptocurrencyAmountLabel.text = nil
        cell.isHidden = true
        guard let tokens = self.cryptocurrency?.tokens, tokens.count > indexPath.row else { return cell }
        let token = tokens[indexPath.row]
        cell.isHidden = false
        cell.nameLabel.text = token.info.name
        
        var shortBalanceStr = token.balanceString
        if shortBalanceStr.count > 16, let integerLength = shortBalanceStr.indexDistance(of: ".") {
            shortBalanceStr = (integerLength < 16) ? String(shortBalanceStr.prefix(16)) : String(shortBalanceStr.prefix(integerLength))
        }
        cell.cryptocurrencyAmountLabel.text = "\(shortBalanceStr) \(token.info.symbol)"
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit.description
        if let rate = token.exchangeRates[currencyUnit.description] {
            cell.exchangeRateLabel.text = "1 \(token.info.symbol) = \((rate >= 1) ? rate.toString(2) : rate.toString(6)) \(currencyUnit.description)"
            if let balance = Double(token.balanceString) {
                let amount = balance * rate
                cell.currencyAmountLabel.text = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(currencyUnit.description)"
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let tokens = self.cryptocurrency?.tokens, tokens.count > indexPath.row else { return }
        self.selectedToken = tokens[indexPath.row]
        self.performSegue(withIdentifier: "TokenTransactionSegue", sender: self)
    }

}
