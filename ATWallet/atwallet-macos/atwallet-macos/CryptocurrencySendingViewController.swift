//
//  CryptocurrencySendingViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class CryptocurrencySendingViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var toLabel: NSTextField!
    @IBOutlet weak var amountLabel: NSTextField!
    @IBOutlet weak var feeLabel: NSTextField!
    @IBOutlet weak var noteLabel: NSTextField!
    @IBOutlet weak var addressTextField: NSTextField!
    @IBOutlet weak var amountTextField: NSTextField!
    @IBOutlet weak var feeTextField: NSTextField!
    @IBOutlet weak var noteTextField: NSTextField!
    @IBOutlet weak var pasteButton: NSButton!
    @IBOutlet weak var lowSpeedButton: NSButton!
    @IBOutlet weak var mediumSpeedButton: NSButton!
    @IBOutlet weak var highSpeedButton: NSButton!
    @IBOutlet weak var sendButton: NSButton!
    @IBOutlet weak var backButton: NSButton!
        
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    @IBAction func pasteButtonAction(_ sender: NSButton) {
        self.addressTextField.stringValue = ""
        guard let cryptocurrency = self.cryptocurrency ,let address = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        guard AppController.shared.checkSendingAddressValidity(cryptocurrency, address) else {
            AppController.shared.showAlert("invalid_address".localizedString)
            return
        }
        self.addressTextField.stringValue = address
    }
    
    @IBAction func lowSpeedButtonAction(_ sender: NSButton) {
        guard  let cryptocurrency = self.cryptocurrency, self.amountTextField.stringValue.count > 0 else { return }
        self.feeTextField.stringValue = cryptocurrency.calculateMinimumFee(self.amountTextField.stringValue, self.noteTextField.stringValue)
    }
    
    @IBAction func mediumSpeedButtonAction(_ sender: NSButton) {
        guard  let cryptocurrency = self.cryptocurrency, self.amountTextField.stringValue.count > 0 else { return }
        self.feeTextField.stringValue = cryptocurrency.calculateMediumFee(self.amountTextField.stringValue, self.noteTextField.stringValue)
    }
    
    @IBAction func highSpeedButtonAction(_ sender: NSButton) {
        guard  let cryptocurrency = self.cryptocurrency, self.amountTextField.stringValue.count > 0 else { return }
        self.feeTextField.stringValue = cryptocurrency.calculateHighFee(self.amountTextField.stringValue, self.noteTextField.stringValue)
    }
    
    @IBAction func sendButtonAction(_ sender: NSButton) {
        guard let cryptocurrency = self.cryptocurrency else { return }
        var address = self.addressTextField.stringValue.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.count > 0 else {
            AppController.shared.showAlert("invalid_address".localizedString)
            return
        }
        
        if cryptocurrency.currencyType == ATCryptocurrencyType.bch && !address.contains(":") && (address.uppercased() == address || address.lowercased() == address) {
            address = "\(cryptocurrency.currencyType.scheme):\(address)"
        }
        guard AppController.shared.checkSendingAddressValidity(cryptocurrency, address) else {
            AppController.shared.showAlert("invalid_address".localizedString)
            return
        }
        let amount = self.amountTextField.stringValue
        guard amount.count > 0 else {
            AppController.shared.showAlert("amount_is_empty".localizedString)
            return
        }
        guard let amountD = Double(amount), let minAmountD = Double(cryptocurrency.getMinOutputAmount()) , amountD > minAmountD else {
            AppController.shared.showAlert("amount_is_too_small".localizedString)
            return
        }
        let fee = self.feeTextField.stringValue
        guard fee.count > 0 else {
            AppController.shared.showAlert("fee_is_empty".localizedString)
            return
        }
        let note = self.noteTextField.stringValue
        guard let transaction = cryptocurrency.createTransaction(amount, fee, address, (note.count > 0) ? note : nil) else {
            AppController.shared.showAlert("failed_to_create_transaction".localizedString)
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
                    AppController.shared.showAlert("failed_to_finish_transaction".localizedString)
                    return
                }
                if done {
                    AppController.shared.showBusyPrompt()
                    AppController.shared.coldWalletSignTransaction(cryptocurrency, transaction) { (succeeded, transaction, error) in
                        (error != nil) ? ATLog.debug(error!.description) : nil
                        guard let transaction = transaction, succeeded else {
                            AppController.shared.hideBusyPrompt()
                            self.parent.transaction = nil
                            switch error {
                            case .loginRequired:
                                AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                                    AppController.shared.popSplitDetailViewToRootViewController()
                                })])
                            case .failToConnect:
                                AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                            default:
                            AppController.shared.showAlert("failed_to_sign_transaction".localizedString)
                            }
                            return
                        }
                        self.parent.transaction = transaction
                        AppController.shared.coldWalletPublishTransaction(cryptocurrency, transaction) { (succeeded, transaction, error) in
                            AppController.shared.hideBusyPrompt()
                            (error != nil) ? ATLog.debug(error!.description) : nil
                            self.parent.transaction = nil
                            if succeeded {
                                AppController.shared.showAlert("transaction_succeeded".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                                    AppController.shared.popSplitDetailView()
                                })])
                            }
                            else {
                                AppController.shared.showAlert("transaction_failed".localizedString)
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
        AppController.shared.showBusyPrompt()
        AppController.shared.coldWalletPrepareToSignTransaction(cryptocurrency, transaction) { (succeeded, transaction, error) in
            AppController.shared.hideBusyPrompt()
            (error != nil) ? ATLog.debug(error!.description) : nil
            guard succeeded, let transaction = transaction else {
                self.transaction = nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    AppController.shared.showAlert("failed_to_start_transaction".localizedString)
                }
                return
            }
            self.transaction = transaction
            
            let confirmationMessage = "transaction_confirmation".localizedString
            let transactionDescription = """
            
            \("sent".localizedString)
            \(transaction.amountString) \(transaction.currency.symbol)
            
            \("to".localizedString)
            \(transaction.address)
            
            \("fee".localizedString)
            \(transaction.feeString) \(transaction.currency.symbol)
            
            \("note".localizedString)
            \(self.noteTextField.stringValue)
            """
            let cancelAction = AppController.AlertAction(title: "cancel".localizedString) {
                guard let cryptocurrency = self.cryptocurrency, let transaction = self.transaction else { return }
                AppController.shared.coldWalletCancelSigningTransaction(cryptocurrency, transaction)
            }
            let confirmAction = AppController.AlertAction(title: "confirm".localizedString) {
                self.isWaitingFingerprintVerification = true
                self.fpVerificationDelegate = Delegate(self)
                AppController.shared.presentAsSheet(.FingerprintVerification) { (vc) in
                    guard let fpVerificationVC = vc as? FingerprintVerificationViewController else { return }
                    fpVerificationVC.delegate = self.fpVerificationDelegate
                }
            }
            AppController.shared.showAlert(confirmationMessage, transactionDescription, [confirmAction, cancelAction])
        }
    }
    
    weak var cryptocurrency: ATCryptocurrencyWallet?
    
    private var transaction: ATCryptocurrencyTransaction?
    private var isWaitingFingerprintVerification = false
    private var fpVerificationDelegate: FingerprintVerificationViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.descriptionLabel.stringValue = ""
        self.toLabel.stringValue = "to".localizedString
        self.amountLabel.stringValue = "amount".localizedString
        self.feeLabel.stringValue = "fee".localizedString
        self.noteLabel.stringValue = "note".localizedString
        self.addressTextField.wantsLayer = true
        self.addressTextField.layer?.cornerRadius = 5
        self.amountTextField.wantsLayer = true
        self.amountTextField.layer?.cornerRadius = 5
        self.feeTextField.wantsLayer = true
        self.feeTextField.layer?.cornerRadius = 5
        self.noteTextField.wantsLayer = true
        self.noteTextField.layer?.cornerRadius = 5
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.sendButton.attributedTitle = NSAttributedString(string: "send".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.sendButton.attributedAlternateTitle = NSAttributedString(string: "send".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.pasteButton.alternateImage = self.pasteButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        self.lowSpeedButton.alternateImage = self.lowSpeedButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        self.mediumSpeedButton.alternateImage = self.mediumSpeedButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        self.highSpeedButton.alternateImage = self.highSpeedButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
    }
    
    override func viewWillAppear() {
        guard !self.isWaitingFingerprintVerification else { return }
        self.titleLabel.stringValue = "\("send".localizedString) \(cryptocurrency?.currencyType.name ?? "cryptocurrency")"
        self.addressTextField.stringValue = ""
        self.addressTextField.placeholderString = nil
        self.amountTextField.stringValue = ""
        self.amountTextField.placeholderString = cryptocurrency?.currencyType.symbol
        self.feeTextField.stringValue = ""
        self.feeTextField.placeholderString = cryptocurrency?.currencyType.symbol
        self.noteTextField.stringValue = ""
        self.noteTextField.placeholderString = nil
    }
    
    // MARK: - NSTextFieldDelegate
        
    func textFieldShouldReturn(_ textField: NSTextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: NSTextField) {
        // TODO
        if textField == self.amountTextField || textField == self.noteTextField {
            let amountStr = self.amountTextField.stringValue
            guard let cryptocurrency = self.cryptocurrency, amountStr.count > 0 else { return }
            guard amountStr.isNumeric else {
                AppController.shared.showAlert("invalid_amount".localizedString)
                textField.stringValue = ""
                return
            }
            let minFeeStr = cryptocurrency.calculateMinimumFee(amountStr, self.noteTextField.stringValue)
            let medFeeStr = cryptocurrency.calculateMediumFee(amountStr, self.noteTextField.stringValue)
            guard let fee = Double(self.feeTextField.stringValue), fee > 0 else {
                self.feeTextField.stringValue = medFeeStr
                return
            }
            if let minFee = Double(minFeeStr), minFee > fee {
                self.feeTextField.stringValue = minFeeStr
            }
        }
        else if textField == self.feeTextField {
            let feeStr = self.feeTextField.stringValue
            guard feeStr.count > 0 else { return }
            guard feeStr.isNumeric else {
                AppController.shared.showAlert("invalid_fee".localizedString)
                textField.stringValue = ""
                return
            }
        }
    }
    
}
