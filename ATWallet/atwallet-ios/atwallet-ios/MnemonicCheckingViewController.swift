//
//  MnemonicCheckingViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/30.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class MnemonicCheckingViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var question1Label: UILabel!
    @IBOutlet var question2Label: UILabel!
    @IBOutlet var question3Label: UILabel!
    @IBOutlet var answer1TextField: UITextField!
    @IBOutlet var answer2TextField: UITextField!
    @IBOutlet var answer3TextField: UITextField!
    @IBOutlet var passphraseDescriptionLabel: UILabel!
    @IBOutlet var passphraseTextField: UITextField!
    @IBOutlet var passphraseCheckTextField: UITextField!
    @IBOutlet var backButton: UIButton!
    @IBOutlet var nextButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func nextButtonAction(_ sender: UIButton) {
        let answer1 = Int(self.answer1TextField.text ?? "-1") == self.answer1TextField.tag
        let answer2 = self.answer2TextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) == self.mnemonic[self.answer2TextField.tag - 1]
        let answer3 = Int(self.answer3TextField.text ?? "-1") == self.answer3TextField.tag
        if answer1, answer2, answer3 {
            guard self.passphraseTextField.text == self.passphraseCheckTextField.text else {
                AppController.shared.showAlert(self, NSLocalizedString("passphrases_do_not_match", comment: ""), nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil)])
                return
            }
            createWallet()
        }
        else {
            AppController.shared.showAlert(self, NSLocalizedString("wrong_answer", comment: ""), nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: { (action) in
                self.generateQuestions()
            })])
        }
    }

    var hdwIndex: ATHDWallet.Index = .any
    var mnemonic: [String] = []
    var name: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        self.titleLabel.text = NSLocalizedString("check_mnemonic", comment: "")
        self.descriptionLabel.text = NSLocalizedString("double_check_mnemonic_description", comment: "")
        self.passphraseDescriptionLabel.text = NSLocalizedString("passphrase_description_for_create_wallet", comment: "")
        self.passphraseTextField.placeholder = "passphrase".localizedString
        self.passphraseCheckTextField.placeholder = "reenter_passphrase".localizedString
        
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
        generateQuestions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
    }
    
    @objc func hideKeyboard(_ tap: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    func generateQuestions() {
        var randomNumbers = [UInt32](repeating: 0, count: 4)
        if SecRandomCopyBytes(kSecRandomDefault, randomNumbers.count * MemoryLayout<UInt32>.size, &randomNumbers) !=  errSecSuccess {
            randomNumbers[0] = arc4random()
            randomNumbers[1] = arc4random()
            randomNumbers[2] = arc4random()
            randomNumbers[3] = arc4random()
        }
        let question1 = NSLocalizedString("what_is_the_index_number_of_$1", comment: "")
        self.answer1TextField.tag = Int(randomNumbers[0] % UInt32(self.mnemonic.count)) + 1
        self.answer1TextField.text = nil
        self.question1Label.text = question1.replacingOccurrences(of: "$1", with: self.mnemonic[self.answer1TextField.tag - 1])
        
        let question2 = NSLocalizedString("what_is_the_word_at_index_$1", comment: "")
        self.answer2TextField.tag = Int(randomNumbers[1] % UInt32(self.mnemonic.count)) + 1
        self.answer2TextField.text = nil
        self.question2Label.text = question2.replacingOccurrences(of: "$1", with: String(self.answer2TextField.tag))
        
        let question3 = NSLocalizedString("what_is_the_sum_of_index_numbers_of_$1_and_$2", comment: "")
        let number1 = Int(randomNumbers[2] % UInt32(self.mnemonic.count)) + 1
        let number2 = Int(randomNumbers[3] % UInt32(self.mnemonic.count)) + 1
        self.answer3TextField.tag = number1 + number2
        self.answer3TextField.text = nil
        self.question3Label.text = question3.replacingOccurrences(of: "$1", with: self.mnemonic[number1 - 1]).replacingOccurrences(of: "$2", with: self.mnemonic[number2 - 1])
    }
    
    func createWallet() {
        AppController.shared.showBusyPrompt(self, NSLocalizedString("creating", comment: ""))
        AppController.shared.coldWalletCreateHDWallet(self.hdwIndex, self.mnemonic, self.passphraseTextField.text, self.name) { (created, error) in
            AppController.shared.hideBusyPrompt(self)
            guard error == nil, created == true else {
                (error != nil ) ? ATLog.debug("\(error!.description)") : nil
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        AppController.shared.popToRootViewController(self)
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    AppController.shared.showAlert(self, "failed_to_create_wallet".localizedString, nil)
                }
                return
            }
            self.performSegue(withIdentifier: "WalletSegue", sender: self)
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

}
