//
//  WalletViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/30.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class WalletViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var currencyAmountLabel: UILabel!
    @IBOutlet var cryptocurrencyTableView: UITableView!
    @IBOutlet var addButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func addButtonAction(_ sender: UIButton) {
        var height = 70 * ATCryptocurrencyType.allCases.count
        (height > 250) ? height = 250 : nil
        let okAction = UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
            let index = self.pickerView.selectedRow(inComponent: 0)
            let cryptocurrencyType = ATCryptocurrencyType.allCases[index]
            AppController.shared.showBusyPrompt(self, nil)
            AppController.shared.coldWalletAddNewCryptocurrency(nil, cryptocurrencyType, nil, nil, nil) { (added, error) in
                AppController.shared.hideBusyPrompt(self)
                guard added, error == nil else {
                    AppController.shared.showAlert(self, (error == .failToConnect) ? "failed_to_connect_and_check_power_on".localizedString : "failed_to_add_cryptocurrency".localizedString, nil)
                    return
                }
                self.updateUI()
            }
        }
        let cancelAction = UIAlertAction(title: "cancel".localizedString, style: .cancel, handler: nil)
        self.pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        self.pickerView.reloadAllComponents()
        AppController.shared.showAlert(self, "select_one_to_add".localizedString, nil, [okAction, cancelAction], self.pickerView)
    }
    
    weak var selectedCryptocurrency: ATCryptocurrencyWallet?
    
    private static var this: WalletViewController!
    
    private weak var hdWallet: ATHDWallet?
    private var pickerView: UIPickerView!
    
    private let cryptocurrencyWalletStateChangedCallback: AppController.CryptocurrencyWalletStateChangedCallback = { (wallet) in
        guard let vc = WalletViewController.this.navigationController?.topViewController, vc == WalletViewController.this else { return }
        
        WalletViewController.this.updateCurrencyAmount()
        if let index = WalletViewController.this.hdWallet?.wallets?.firstIndex(of: wallet) {
            WalletViewController.this.cryptocurrencyTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
        else {
            WalletViewController.this.cryptocurrencyTableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.setHidesBackButton(true, animated: true)
        self.pickerView = UIPickerView()
        self.pickerView.dataSource = self
        self.pickerView.delegate = self
        WalletViewController.this = self
        AppController.shared.registerCryptocurrencyWalletStateChangedCallback(self.cryptocurrencyWalletStateChangedCallback)
        
        if !AppController.shared.isUsingPadUI {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.titleLabel.text = nil
        self.currencyAmountLabel.text = nil
        self.addButton.isHidden = true
        self.hdWallet = nil
        if AppController.shared.hasColdWalletInfoUpdated() {
            self.hdWallet = AppController.shared.coldWalletGetHDWallet()
            updateUI()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
        guard AppController.shared.hasColdWalletInfoUpdated() else {
            AppController.shared.showBusyPrompt(self, nil)
            Thread.detachNewThread {
                while !AppController.shared.hasColdWalletInfoUpdated() {
                    sleep(1)
                }
                self.hdWallet = AppController.shared.coldWalletGetHDWallet()
                DispatchQueue.main.async {
                    self.updateUI()
                    AppController.shared.hideBusyPrompt(self)
                }
            }
            return
        }
        self.hdWallet = AppController.shared.coldWalletGetHDWallet()
        updateUI()
    }
    
    func updateUI() {
        self.titleLabel.text = self.hdWallet?.name
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
            amount += balance * rate
        }
        self.currencyAmountLabel.text = "\(amount.toString(2)) \(defaultCurrencyUnit.description)"
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? TransactionViewController {
            vc.cryptocurrency = self.selectedCryptocurrency
            vc.transactions = self.selectedCryptocurrency?.transactions ?? []
        }
    }
    
    // MARK: - UITableViewDataSource & UITableViewDelegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.hdWallet?.wallets?.count ?? 0
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CryptocurrencyTableViewCell") as! CryptocurrencyTableViewCell
        cell.iconImageView.image = nil
        cell.nameLabel.text = nil
        cell.exchangeRateLabel.text = nil
        cell.currencyAmountLabel.text = nil
        cell.cryptocurrencyAmountLabel.text = nil
        cell.isHidden = true
        guard let wallet = self.hdWallet?.wallets?[indexPath.row] else { return cell }
        cell.isHidden = false
        cell.iconImageView.image = UIImage(named: wallet.currencyType.symbol)
        cell.nameLabel.text = wallet.name
        guard wallet.initialized else {
            cell.currencyAmountLabel.text = "synchronizing".localizedString
            return cell
        }
        
        var shortBalanceStr = wallet.balanceString
        if shortBalanceStr.count > 7, let integerLength = shortBalanceStr.indexDistance(of: ".") {
            shortBalanceStr = (integerLength < 7) ? String(shortBalanceStr.prefix(7)) : String(shortBalanceStr.prefix(integerLength))
        }
        cell.cryptocurrencyAmountLabel.text = "\(shortBalanceStr) \(wallet.currencyType.symbol)"
        let currencyUnit = AppConfig.shared.defaultCurrencyUnit.description
        if let rate = wallet.exchangeRates[currencyUnit.description] {
            cell.exchangeRateLabel.text = "1 \(wallet.currencyType.symbol) = \(rate.toString(2)) \(currencyUnit.description)"
            if let balance = Double(wallet.balanceString) {
                cell.currencyAmountLabel.text = "\((balance * rate).toString(2)) \(currencyUnit.description)"
            }
        }
        if wallet.isSyncing {
            cell.currencyAmountLabel.text = "synchronizing".localizedString
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.selectedCryptocurrency = self.hdWallet?.wallets?[indexPath.row]
        if self.selectedCryptocurrency != nil {
            self.performSegue(withIdentifier: "TransactionSegue", sender: self)
        }
    }
    
    // MARK: - UIPickerViewDataSource & UIPickerViewDelegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return ATCryptocurrencyType.allCases.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return ATCryptocurrencyType.allCases[row].name
    }
    
}
