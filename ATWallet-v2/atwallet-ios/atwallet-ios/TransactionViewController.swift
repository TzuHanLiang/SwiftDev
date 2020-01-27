//
//  TransactionViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/9.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class TransactionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var bip32PathLabel: UILabel!
    @IBOutlet var exchangeRateLabel: UILabel!
    @IBOutlet var currencyAmountLabel: UILabel!
    @IBOutlet var cryptocurrencyAmountLabel: UILabel!
    @IBOutlet var transactionTableView: UITableView!
    @IBOutlet var receiveButton: UIButton!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var tokenButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        guard self.navigationController?.topViewController == self else { return }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func receiveButtonAction(_ sender: UIButton) {
        guard self.cryptocurrency?.initialized == true else {
            AppController.shared.showAlert(self, "wallet_is_still_initializing".localizedString, nil)
            return
        }
        self.performSegue(withIdentifier: "CryptocurrencyReceivingSegue", sender: self)
    }
    
    @IBAction func sendButtonAction(_ sender: UIButton) {
        guard self.cryptocurrency?.initialized == true else {
            AppController.shared.showAlert(self, "wallet_is_still_initializing".localizedString, nil)
            return
        }
        self.performSegue(withIdentifier: "CryptocurrencySendingSegue", sender: self)
    }
    
    @IBAction func tokenButtonAction(_ sender: UIButton) {
        guard self.cryptocurrency?.initialized == true else {
            AppController.shared.showAlert(self, "wallet_is_still_initializing".localizedString, nil)
            return
        }
        self.performSegue(withIdentifier: "TokenSegue", sender: self)
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    var transactions: [ATCryptocurrencyTransaction] = []
    
    private static var this: TransactionViewController!
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard wallet == TransactionViewController.this.cryptocurrency, let vc = TransactionViewController.this.navigationController?.topViewController, vc == TransactionViewController.this else { return }
        TransactionViewController.this.updateUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        TransactionViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
        self.receiveButton.setTitle("receive".localizedString, for: .normal)
        self.sendButton.setTitle("send".localizedString, for: .normal)
        self.tokenButton.setTitle("tokens".localizedString, for: .normal)
        
        if !AppController.shared.isUsingPadUI {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
    }
    
    func updateUI() {
        self.titleLabel.text = self.cryptocurrency?.name
        self.bip32PathLabel.text = nil
        self.tokenButton.isHidden = true
        if let cryptocurrency = self.cryptocurrency {
            self.bip32PathLabel.text = "m / \(cryptocurrency.purpose & 0x7FFFFFFF)' / \(cryptocurrency.coinType & 0x7FFFFFFF)' / \(cryptocurrency.accountValue & 0x7FFFFFFF)'"
            self.tokenButton.isHidden = (cryptocurrency.currencyType != .eth || cryptocurrency.tokens.count == 0)
        }
        self.transactions = self.cryptocurrency?.transactions ?? []
        self.transactionTableView.reloadData()
        self.exchangeRateLabel.text = nil
        self.currencyAmountLabel.text = nil
        guard let cryptocurrency = self.cryptocurrency else { return }
        self.cryptocurrencyAmountLabel.text = "\(cryptocurrency.balanceString) \(cryptocurrency.currencyType.symbol)"
        updateCurrencyAmount()
    }
    
    func updateCurrencyAmount() {
        self.currencyAmountLabel.text = nil
        guard let cryptocurrency = self.cryptocurrency else { return }
        guard let balance = Double(cryptocurrency.balanceString) else { return }
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit
        guard let rate = cryptocurrency.exchangeRates[currencyUnit.description] else { return }
        self.exchangeRateLabel.text = "1 \(cryptocurrency.currencyType.symbol) = \((rate >= 1) ? rate.toString(2) : rate.toString(6)) \(currencyUnit.description)"
        var amount = balance * rate
        for token in cryptocurrency.tokens {
            let balance = Double(token.balanceString) ?? 0
            let rate = token.exchangeRates[currencyUnit.description] ?? 0
            amount += balance * rate
        }
        self.currencyAmountLabel.text = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(currencyUnit.description)"
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? CryptocurrencyReceivingViewController {
            vc.crytocurrencyType = self.cryptocurrency?.currencyType
            vc.addresses = self.cryptocurrency?.receivingAddressesWithFormat
        }
        else if let vc = segue.destination as? CryptocurrencySendingViewController {
            vc.cryptocurrency = self.cryptocurrency
        }
        else if let vc = segue.destination as? TokenViewController {
            vc.cryptocurrency = self.cryptocurrency
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.transactions.count
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionTableViewCell") as! TransactionTableViewCell
        cell.dateLabel.text = nil
        cell.addressLabel.text = nil
        cell.amountLabel.text = nil
        cell.isHidden = true
        guard self.transactions.count > indexPath.row else { return cell }
        let transaction = self.transactions[indexPath.row]
        cell.isHidden = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        cell.dateLabel.text = dateFormatter.string(from: transaction.date)
        
        switch transaction.direction {
        case .moved:
            cell.addressLabel.text = "\("moved".localizedString)"
            cell.amountLabel.text = "-\(transaction.feeString) \(transaction.currency.symbol)"
        case .sent:
            cell.addressLabel.text = "\("to".localizedString) \(transaction.address)"
            cell.amountLabel.text = "-\(transaction.amountString) \(transaction.currency.symbol)"
        case .received:
            cell.addressLabel.text = "\("from".localizedString) \(transaction.address)"
            cell.amountLabel.text = "+\(transaction.amountString) \(transaction.currency.symbol)"
        }
        cell.contentView.alpha = transaction.detailDescription.contains("unconfirmed".localizedString) ? 0.3 : 1.0
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.transactions.count > indexPath.row else { return }
        let transaction = self.transactions[indexPath.row]
        AppController.shared.showAlert(self, transaction.detailDescription, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: nil)], nil, .left)
    }

}
