//
//  CryptocurrencySendingViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/9.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit
import QRCodeReader
import AVFoundation

class CryptocurrencySendingViewController: UIViewController, UITextFieldDelegate, QRCodeReaderViewControllerDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var toLabel: UILabel!
    @IBOutlet var amountLabel: UILabel!
    @IBOutlet var maxAmountLabel: UILabel!
    @IBOutlet var feeLabel: UILabel!
    @IBOutlet var noteLabel: UILabel!
    @IBOutlet var addressTextField: UITextField!
    @IBOutlet var amountTextField: UITextField!
    @IBOutlet var feeTextField: UITextField!
    @IBOutlet var noteTextField: UITextField!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var pasteButton: UIButton!
    @IBOutlet var lowSpeedButton: UIButton!
    @IBOutlet var mediumSpeedButton: UIButton!
    @IBOutlet var highSpeedButton: UIButton!
    @IBOutlet var sendButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func cameraButtonAction(_ sender: UIButton) {
        self.addressTextField.text = ""
        self.qrcodeReaderViewController.modalPresentationStyle = .formSheet
        let token = self.token
        present(self.qrcodeReaderViewController, animated: true, completion: {
            self.token = token
        })
    }
    
    @IBAction func pasteButtonAction(_ sender: UIButton) {
        self.addressTextField.text = nil
        guard let cryptocurrency = self.cryptocurrency ,let address = UIPasteboard.general.string?.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        guard AppController.shared.checkSendingAddressValidity(cryptocurrency, address) else {
            AppController.shared.showAlert(self, "invalid_address".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: nil)])
            return
        }
        self.addressTextField.text = address
    }
    
    @IBAction func lowSpeedButtonAction(_ sender: UIButton) {
        guard  let cryptocurrency = self.cryptocurrency, let amountStr = self.amountTextField.text, amountStr.count > 0 else { return }
        self.feeTextField.text = cryptocurrency.calculateLowFee(amountStr, self.noteTextField.text, self.token)
    }
    
    @IBAction func mediumSpeedButtonAction(_ sender: UIButton) {
        guard  let cryptocurrency = self.cryptocurrency, let amountStr = self.amountTextField.text, amountStr.count > 0 else { return }
        self.feeTextField.text = cryptocurrency.calculateMediumFee(amountStr, self.noteTextField.text, self.token)
    }
    
    @IBAction func highSpeedButtonAction(_ sender: UIButton) {
        guard  let cryptocurrency = self.cryptocurrency, let amountStr = self.amountTextField.text, amountStr.count > 0 else { return }
        self.feeTextField.text = cryptocurrency.calculateHighFee(amountStr, self.noteTextField.text, self.token)
    }
    
    @IBAction func sendButtonAction(_ sender: UIButton) {
        guard let cryptocurrency = self.cryptocurrency else { return }
        guard var address = self.addressTextField.text?.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .whitespacesAndNewlines) else {
            AppController.shared.showAlert(self, "invalid_address".localizedString, nil)
            return
        }
        
        if cryptocurrency.currencyType == ATCryptocurrencyType.bch && !address.contains(":") && (address.uppercased() == address || address.lowercased() == address) {
            address = "\(cryptocurrency.currencyType.scheme):\(address)"
        }
        guard AppController.shared.checkSendingAddressValidity(cryptocurrency, address) else {
            AppController.shared.showAlert(self, "invalid_address".localizedString, nil)
            return
        }
        guard let amount = self.amountTextField.text, amount.count > 0 else {
            AppController.shared.showAlert(self, "amount_is_empty".localizedString, nil)
            return
        }
        guard amount.isNumeric, let amountValue = Double(amount) else {
            AppController.shared.showAlert(self, "invalid_amount".localizedString, nil)
            self.amountTextField.text = nil
            return
        }
        let minAmountValue = Double(cryptocurrency.getMinOutputAmount(self.token)) ?? 0
        guard amountValue > minAmountValue else {
            AppController.shared.showAlert(self, "amount_is_too_small".localizedString, nil)
            return
        }
        let maxAmountValue = Double(cryptocurrency.getMaxOutputAmount(self.token)) ?? Double.infinity
        guard maxAmountValue > 0 else {
            AppController.shared.showAlert(self, "failed_to_create_transaction_description".localizedString, nil)
            return
        }
        guard amountValue <= maxAmountValue else {
            AppController.shared.showAlert(self, "amount_is_too_high".localizedString, nil)
            return
        }

        guard let fee = self.feeTextField.text, fee.count > 0 else {
            AppController.shared.showAlert(self, "fee_is_empty".localizedString, nil)
            return
        }
        guard fee.isNumeric, let feeValue = Double(fee) else {
            AppController.shared.showAlert(self, "invalid_fee".localizedString, nil)
            self.feeTextField.text = nil
            return
        }
        let minFeeValue = Double(cryptocurrency.calculateMinimumFee(amount, self.noteTextField.text, self.token)) ?? 0
        guard feeValue >= minFeeValue else {
            AppController.shared.showAlert(self, (self.token != nil && self.cryptocurrency?.currencyType == .eth) ? "gas_price_is_too_small".localizedString : "fee_is_too_small".localizedString, nil)
            return
        }
        let balanceValue = Double(cryptocurrency.balanceString) ?? 0
        if self.token == nil {
            guard (amountValue + feeValue) <= balanceValue else {
                AppController.shared.showAlert(self, "no_enough_balance_for_amount_and_fee".localizedString, nil)
                return
            }
            guard feeValue < amountValue else {
                AppController.shared.showAlert(self, "fee_is_greater_than_amount".localizedString, nil)
                return
            }
        }
        let note = self.noteTextField.text ?? ""
        guard let transaction = cryptocurrency.createTransaction(amount, fee, address, (note.count > 0) ? note : nil, self.token) else {
            AppController.shared.showAlert(self, "failed_to_create_transaction_description".localizedString, nil)
            return
        }
        
        struct Delegate: FingerprintVerificationViewControllerDelegate {
            
            let parent: CryptocurrencySendingViewController
            
            init(_ vc: CryptocurrencySendingViewController) {
                self.parent = vc
            }
            
            func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> () {
                // do nothing
            }
            
            func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool {
                return true
            }
            
            func fpVerificationDidComplete(_ vc: FingerprintVerificationViewController, _ done: Bool, _ verified: Bool) {
                self.parent.fpVerificationDelegate = nil
                self.parent.isWaitingFingerprintVerification = false
                guard let cryptocurrency = self.parent.cryptocurrency, let transaction = self.parent.transaction else {
                    AppController.shared.showAlert(self.parent, "failed_to_finish_transaction".localizedString, nil)
                    return
                }
                if done {
                    AppController.shared.showBusyPrompt(self.parent, nil)
                    AppController.shared.coldWalletSignTransaction(cryptocurrency, transaction) { (succeeded, transaction, error) in
                        (error != nil) ? ATLog.debug("\(error!.description)") : nil
                        guard let transaction = transaction, succeeded else {
                            AppController.shared.hideBusyPrompt(self.parent)
                            self.parent.transaction = nil
                            switch error {
                            case .loginRequired:
                                AppController.shared.showAlert(self.parent, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                                    AppController.shared.popToRootViewController(self.parent)
                                }])
                            case .failToConnect:
                                AppController.shared.showAlert(self.parent, "failed_to_connect_and_check_power_on".localizedString, nil)
                            default:
                                AppController.shared.showAlert(self.parent, "failed_to_sign_transaction".localizedString, nil)
                            }
                            return
                        }
                        self.parent.transaction = transaction
                        AppController.shared.coldWalletPublishTransaction(cryptocurrency, transaction) { (succeeded, transaction, error) in
                            AppController.shared.hideBusyPrompt(self.parent)
                            (error != nil) ? ATLog.debug("\(error!.description)") : nil
                            self.parent.transaction = nil
                            if succeeded {
                                AppController.shared.showAlert(self.parent, "transaction_succeeded".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default, handler: { (action) in
                                    self.parent.navigationController?.popViewController(animated: true)
                                })])
                            }
                            else {
                                AppController.shared.showAlert(self.parent, "transaction_failed".localizedString, nil)
                            }
                        }
                    }
                }
                else {
                    AppController.shared.coldWalletCancelSigningTransaction(cryptocurrency, transaction)
                }
            }
        }
        
        self.transaction = transaction
        AppController.shared.showBusyPrompt(self, nil)
        AppController.shared.coldWalletPrepareToSignTransaction(cryptocurrency, transaction) { (succeeded, transaction, error) in
            AppController.shared.hideBusyPrompt(self)
            (error != nil) ? ATLog.debug("\(error!.description)") : nil
            guard succeeded, let transaction = transaction else {
                self.transaction = nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        AppController.shared.popToRootViewController(self)
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    AppController.shared.showAlert(self, "failed_to_start_transaction".localizedString, nil)
                }
                return
            }
            self.transaction = transaction
            
            let confirmationMessage = "transaction_confirmation".localizedString
            var transactionDescription = """
            
            \("send".localizedString)
            \(transaction.amountString) \((self.token != nil) ? self.token!.info.symbol : transaction.currency.symbol)
            
            \("to".localizedString)
            \(transaction.address)
            
            \("fee".localizedString)
            \(transaction.feeString) \(transaction.currency.symbol)
            """
            if let note = self.noteTextField.text, note.count > 0 {
                let noteDescription = """
                
                
                \("note".localizedString)
                \(note)
                """
                transactionDescription.append(noteDescription)
            }
            if self.token != nil && self.cryptocurrency?.currencyType == .eth {
                transactionDescription = """
                
                \("send".localizedString)
                \(transaction.tokenAmountString) \(self.token!.info.symbol)
                
                \("to".localizedString)
                \(transaction.address)
                
                \("gas_price".localizedString)
                \(transaction.feeString) GWEI
                """
            }
            
            let cancelAction = UIAlertAction(title: "cancel".localizedString, style: .cancel) { (action) in
                guard let cryptocurrency = self.cryptocurrency, let transaction = self.transaction else { return }
                AppController.shared.coldWalletCancelSigningTransaction(cryptocurrency, transaction)
            }
            let confirmAction = UIAlertAction(title: "confirm".localizedString, style: .default) { (action) in
                self.isWaitingFingerprintVerification = true
                self.fpVerificationDelegate = Delegate(self)
                self.performSegue(withIdentifier: "FingerprintVerificationSegue", sender: self)
            }
            AppController.shared.showAlert(self, confirmationMessage, transactionDescription, [cancelAction, confirmAction], nil, .center, .left)
        }
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    weak var token: ATCryptocurrencyToken?
    
    lazy var qrcodeReaderViewController: QRCodeReaderViewController = {
        let builder = QRCodeReaderViewControllerBuilder { (builder) in
            builder.reader = QRCodeReader(metadataObjectTypes: [.qr], captureDevicePosition: .back)
        }
        return QRCodeReaderViewController(builder: builder)
    }()
    
    private var transaction: ATCryptocurrencyTransaction?
    private var isWaitingFingerprintVerification = false
    private var fpVerificationDelegate: FingerprintVerificationViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        self.descriptionLabel.text = nil
        self.toLabel.text = "to".localizedString
        self.amountLabel.text = "amount".localizedString
        self.maxAmountLabel.text = nil
        self.feeLabel.text = "fee".localizedString
        self.noteLabel.text = "note".localizedString
        self.sendButton.setTitle("send".localizedString, for: .normal)
        self.qrcodeReaderViewController.delegate = self
        self.qrcodeReaderViewController.completionBlock = { (result) in
            guard let uri = result?.value else { return }
            guard let cryptocurrency = self.cryptocurrency else { return }
            guard let address = AppController.shared.parseQRCodeAddress(cryptocurrency, uri) else { return }
            DispatchQueue.main.async {
                self.addressTextField.text = address
            }
        }
        
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
        guard !self.isWaitingFingerprintVerification else { return }
        self.titleLabel.text = "\("send".localizedString) \(self.token?.info.symbol ?? self.cryptocurrency?.currencyType.symbol ?? "cryptocurrency".localizedString)"
        self.addressTextField.text = nil
        self.addressTextField.placeholder = nil
        self.amountTextField.text = nil
        self.amountTextField.placeholder = self.token?.info.symbol ?? self.cryptocurrency?.currencyType.symbol
        self.feeLabel.text = (self.token != nil && self.cryptocurrency?.currencyType == .eth) ? "gas_price".localizedString : "fee".localizedString
        self.feeTextField.text = nil
        self.feeTextField.placeholder = (self.token != nil && self.cryptocurrency?.currencyType == .eth) ? "GWEI" : cryptocurrency?.currencyType.symbol
        self.noteTextField.text = nil
        self.noteTextField.placeholder = nil
        self.noteTextField.isHidden = (self.cryptocurrency?.currencyType == .eth)
        self.noteLabel.isHidden = (self.cryptocurrency?.currencyType == .eth)
        self.maxAmountLabel.text = nil
        if let symbol = self.token?.info.symbol, let maxAmount = self.token?.balanceString {
            self.maxAmountLabel.text = "( \("max_amount".localizedString): \(maxAmount) \(symbol) )"
        }
        else if let symbol = self.cryptocurrency?.currencyType.symbol, let maxAmount = self.cryptocurrency?.getMaxOutputAmount() {
            self.maxAmountLabel.text = "( \("max_amount".localizedString): \(maxAmount) \(symbol) )"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.token = nil
    }
    
    @objc func hideKeyboard(_ tap: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? FingerprintVerificationViewController {
            vc.delegate = self.fpVerificationDelegate
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == self.amountTextField, let symbol = self.token?.info.symbol, let maxAmount = self.token?.balanceString {
            self.maxAmountLabel.text = "( \("max_amount".localizedString): \(maxAmount) \(symbol) )"
        }
        else if textField == self.amountTextField, let symbol = self.cryptocurrency?.currencyType.symbol, let maxAmount = self.cryptocurrency?.getMaxOutputAmount() {
            self.maxAmountLabel.text = "( \("max_amount".localizedString): \(maxAmount) \(symbol) )"
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == self.amountTextField || textField == self.noteTextField {
            guard let cryptocurrency = self.cryptocurrency, let amountStr = self.amountTextField.text, amountStr.count > 0 else { return }
            guard amountStr.isNumeric else {
                AppController.shared.showAlert(self, "invalid_amount".localizedString, nil)
                textField.text = nil
                return
            }
            let minFeeStr = cryptocurrency.calculateMinimumFee(amountStr, self.noteTextField.text, self.token)
            let medFeeStr = cryptocurrency.calculateMediumFee(amountStr, self.noteTextField.text, self.token)
            guard let feeStr = self.feeTextField.text, let fee = Double(feeStr), fee > 0 else {
                self.feeTextField.text = medFeeStr
                return
            }
            if let minFee = Double(minFeeStr), minFee > fee {
                self.feeTextField.text = minFeeStr
            }
        }
        else if textField == self.feeTextField {
            guard let feeStr = self.feeTextField.text, feeStr.count > 0 else { return }
            guard feeStr.isNumeric else {
                AppController.shared.showAlert(self, (self.token != nil && self.cryptocurrency?.currencyType == .eth) ? "invalid_gas_price".localizedString : "invalid_fee".localizedString, nil)
                textField.text = nil
                return
            }
        }
    }
    
    // MARK: - QRCodeReaderViewControllerDelegate
    
    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        reader.stopScanning()
        dismiss(animated: true, completion: nil)
    }
    
    func readerDidCancel(_ reader: QRCodeReaderViewController) {
        reader.stopScanning()
        dismiss(animated: true, completion: nil)
    }

}
