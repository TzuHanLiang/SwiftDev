//
//  MnemonicCheckingViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class MnemonicCheckingViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var question1Label: NSTextField!
    @IBOutlet weak var question2Label: NSTextField!
    @IBOutlet weak var question3Label: NSTextField!
    @IBOutlet weak var answer1TextField: NSTextField!
    @IBOutlet weak var answer2TextField: NSTextField!
    @IBOutlet weak var answer3TextField: NSTextField!
    @IBOutlet weak var passphraseDescriptionLabel: NSTextField!
    @IBOutlet weak var passphraseTextField: NSTextField!
    @IBOutlet weak var passphraseCheckTextField: NSTextField!
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    @IBAction func nextButtonAction(_ sender: NSButton) {
        struct SingleClick {
            static var timestamp: TimeInterval = 0
            static func click() -> Bool {
                let current = Date().timeIntervalSince1970
                guard (current - self.timestamp) > 1 else { return false }
                self.timestamp = current
                return true
            }
        }
        guard SingleClick.click() else { return }
        
        let answer1 = Int(self.answer1TextField.stringValue) == self.answer1TextField.tag
        let answer2 = self.answer2TextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) == self.mnemonic[self.answer2TextField.tag - 1]
        let answer3 = Int(self.answer3TextField.stringValue) == self.answer3TextField.tag
        if answer1, answer2, answer3 {
            guard self.passphraseTextField.stringValue == self.passphraseCheckTextField.stringValue else {
                AppController.shared.showAlert("passphrases_do_not_match".localizedString)
                return
            }
            createWallet()
        }
        else {
            AppController.shared.showAlert("wrong_answer".localizedString, nil, [AppController.AlertAction(title: NSLocalizedString("ok", comment: ""), callback: {
                self.generateQuestions()
            })])
        }
    }

    var hdwIndex: ATHDWallet.Index = .any
    var mnemonic: [String] = []
    var name: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.answer1TextField.wantsLayer = true
        self.answer1TextField.layer?.cornerRadius = 5
        self.answer2TextField.wantsLayer = true
        self.answer2TextField.layer?.cornerRadius = 5
        self.answer3TextField.wantsLayer = true
        self.answer3TextField.layer?.cornerRadius = 5
        self.passphraseTextField.wantsLayer = true
        self.passphraseTextField.layer?.cornerRadius = 5
        self.passphraseCheckTextField.wantsLayer = true
        self.passphraseCheckTextField.layer?.cornerRadius = 5
        self.titleLabel.stringValue = "check_mnemonic".localizedString
        self.descriptionLabel.stringValue = "double_check_mnemonic_description".localizedString
        self.passphraseDescriptionLabel.stringValue = "passphrase_description_for_create_wallet".localizedString
        self.passphraseTextField.placeholderString = "passphrase".localizedString
        self.passphraseCheckTextField.placeholderString = "reenter_passphrase".localizedString
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.nextButton.attributedTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.nextButton.attributedAlternateTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
    }
    
    override func viewWillAppear() {
        generateQuestions()
    }
    
    func generateQuestions() {
        var randomNumbers = [UInt32](repeating: 0, count: 4)
        if SecRandomCopyBytes(kSecRandomDefault, randomNumbers.count * MemoryLayout<UInt32>.size, &randomNumbers) !=  errSecSuccess {
            randomNumbers[0] = arc4random()
            randomNumbers[1] = arc4random()
            randomNumbers[2] = arc4random()
            randomNumbers[3] = arc4random()
        }
        let question1 = "what_is_the_index_number_of_$1".localizedString
        self.answer1TextField.tag = Int(randomNumbers[0] % UInt32(self.mnemonic.count)) + 1
        self.answer1TextField.stringValue = ""
        self.question1Label.stringValue = question1.replacingOccurrences(of: "$1", with: self.mnemonic[self.answer1TextField.tag - 1])
        
        let question2 = "what_is_the_word_at_index_$1".localizedString
        self.answer2TextField.tag = Int(randomNumbers[1] % UInt32(self.mnemonic.count)) + 1
        self.answer2TextField.stringValue = ""
        self.question2Label.stringValue = question2.replacingOccurrences(of: "$1", with: String(self.answer2TextField.tag))
        
        let question3 = "what_is_the_sum_of_index_numbers_of_$1_and_$2".localizedString
        let number1 = Int(randomNumbers[2] % UInt32(self.mnemonic.count)) + 1
        let number2 = Int(randomNumbers[3] % UInt32(self.mnemonic.count)) + 1
        self.answer3TextField.tag = number1 + number2
        self.answer3TextField.stringValue = ""
        self.question3Label.stringValue = question3.replacingOccurrences(of: "$1", with: self.mnemonic[number1 - 1]).replacingOccurrences(of: "$2", with: self.mnemonic[number2 - 1])
    }
    
    func createWallet() {
        AppController.shared.showBusyPrompt("creating".localizedString)
        AppController.shared.coldWalletCreateHDWallet(self.hdwIndex, self.mnemonic, self.passphraseTextField.stringValue, self.name) { (created, error) in
            AppController.shared.hideBusyPrompt()
            guard error == nil, created == true else {
                (error != nil ) ? ATLog.debug("\(error!.description)") : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    AppController.shared.showAlert("failed_to_create_wallet".localizedString)
                }
                return
            }
            AppController.shared.pushSplitDetailView(.Wallet)
        }
    }
        
}
