//
//  TokenTransactionViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2020/1/9.
//  Copyright © 2020 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class TokenTransactionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var cryptocurrencyNameLabel: UILabel!
    @IBOutlet var exchangeRateLabel: UILabel!
    @IBOutlet var currencyAmountLabel: UILabel!
    @IBOutlet var cryptocurrencyAmountLabel: UILabel!
    @IBOutlet var transactionTableView: UITableView!
    @IBOutlet var receiveButton: UIButton!
    @IBOutlet var sendButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        guard self.navigationController?.topViewController == self else { return }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func receiveButtonAction(_ sender: UIButton) {
        self.performSegue(withIdentifier: "CryptocurrencyReceivingSegue", sender: self)
    }
    
    @IBAction func sendButtonAction(_ sender: UIButton) {
        self.performSegue(withIdentifier: "CryptocurrencySendingSegue", sender: self)
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    weak var token: ATCryptocurrencyToken?
    var transactions: [ATCryptocurrencyTransaction] = []
    
    private static var this: TokenTransactionViewController!
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard wallet == TokenTransactionViewController.this.cryptocurrency, let vc = TokenTransactionViewController.this.navigationController?.topViewController, vc == TokenTransactionViewController.this else { return }
        TokenTransactionViewController.this.updateUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        TokenTransactionViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
        self.receiveButton.setTitle("receive".localizedString, for: .normal)
        self.sendButton.setTitle("send".localizedString, for: .normal)
        
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
        self.titleLabel.text = self.token?.info.name
        self.cryptocurrencyNameLabel.text = self.cryptocurrency?.name
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit.description
        self.transactions = self.token?.transactions ?? []
        self.transactionTableView.reloadData()
        guard let token = self.token else { return }
        self.cryptocurrencyAmountLabel.text = "\(token.balanceString) \(token.info.symbol)"
        
        guard let rate = token.exchangeRates[currencyUnit.description] else {
            self.exchangeRateLabel.text = nil
            self.currencyAmountLabel.text = nil
            return
        }
        self.exchangeRateLabel.text = "1 \(token.info.symbol) = \((rate >= 1) ? rate.toString(2) : rate.toString(6)) \(currencyUnit.description)"
        
        guard let balance = Double(token.balanceString) else { return }
        let amount = balance * rate
        self.currencyAmountLabel.text = "\((amount >= 1) ? amount.toString(2) : amount.toString(6)) \(currencyUnit.description)"
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? CryptocurrencyReceivingViewController {
            vc.crytocurrencyType = self.cryptocurrency?.currencyType
            vc.tokenInfo = self.token?.info
            vc.addresses = self.cryptocurrency?.receivingAddressesWithFormat
        }
        else if let vc = segue.destination as? CryptocurrencySendingViewController {
            vc.cryptocurrency = self.cryptocurrency
            vc.token = self.token
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
        case .sent:
            cell.addressLabel.text = "\("to".localizedString) \(transaction.address)"
            cell.amountLabel.text = "-\(transaction.tokenAmountString) \(transaction.tokenInfo?.symbol ?? "")"
        case .received:
            cell.addressLabel.text = "\("from".localizedString) \(transaction.address)"
            cell.amountLabel.text = "+\(transaction.tokenAmountString) \(transaction.tokenInfo?.symbol ?? "")"
        case .moved:
            ATLog.warning("impossible case")
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.transactions.count > indexPath.row else { return }
        let transaction = self.transactions[indexPath.row]
        AppController.shared.showAlert(self, transaction.detailDescription, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: nil)], nil, .left)
    }

}
