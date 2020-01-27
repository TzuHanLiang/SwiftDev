//
//  WalletInitializationViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/30.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class WalletInitializationViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UITextViewDelegate {
    
    enum InitMethod: Int, CaseIterable {
        case create
        case recover
        
        var description: String {
            get {
                switch self {
                case .create:
                    return NSLocalizedString("create_a_new_wallet", comment: "")
                case .recover:
                    return NSLocalizedString("recovery_your_wallet", comment: "")
                }
            }
        }
    }
    
    enum PickerType {
        case initMethod
        case mnemonicLanguage
        case mnemonicLength
    }
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var nameTextField: UITextField!
    @IBOutlet var initMethodTextField: UITextField!
    @IBOutlet var mnemonicLanguageTextField: UITextField!
    @IBOutlet var mnemonicLengthTextField: UITextField!
    @IBOutlet var mnemonicDescriptionLable: UILabel!
    @IBOutlet var mnemonicTextView: UITextView!
    @IBOutlet var nextButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        guard self.navigationController?.topViewController == self else { return }
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func nextButtonAction(_ sender: UIButton) {
        if self.selectedMethod == .create {
            self.performSegue(withIdentifier: "MnemonicCheckingSegue", sender: self)
        }
        else if self.selectedMethod == .recover {
            guard let mnemonicString = self.mnemonicTextView.text else {
                AppController.shared.showAlert(self, NSLocalizedString("invalid_mnemonic", comment: ""), nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil)])
                return
            }
            self.mnemonic = mnemonicString.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            var invalid = true
            for mnemonicLength in ATBIP39.MnemonicLength.allCases {
                if mnemonic.count == mnemonicLength.rawValue {
                    invalid = false
                    break
                }
            }
            guard !invalid, ATBIP39().mnemonicIsValid(Mnemonic: mnemonic, Language: nil) else {
                AppController.shared.showAlert(self, NSLocalizedString("invalid_mnemonic", comment: ""), nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: nil)])
                return
            }
            self.performSegue(withIdentifier: "WalletRecoverySegue", sender: self)
        }
    }
    
    @IBAction func textFieldAction(_ sender: UITextField) {
        self.nameTextField.resignFirstResponder()
        
        var height: Int
        if sender.isEqual(self.initMethodTextField) {
            self.pickerType = .initMethod
            height = 70 * InitMethod.allCases.count
        }
        else if sender.isEqual(self.mnemonicLanguageTextField) {
            self.pickerType = .mnemonicLanguage
            height = 70 * ATBIP39.Language.allCases.count
        }
        else if sender.isEqual(self.mnemonicLengthTextField) {
            self.pickerType = .mnemonicLength
            height = 70 * ATBIP39.MnemonicLength.allCases.count
        }
        else {
            return
        }
        (height > 250) ? height = 250 : nil
        
        let action = UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default) { (action) in
            let index = self.pickerView.selectedRow(inComponent: 0)
            switch self.pickerType! {
            case .initMethod:
                let initMethod = InitMethod.allCases[index]
                self.initMethodTextField.text = initMethod.description
                self.selectedMethod = initMethod
                if initMethod == .create {
                    self.mnemonicLanguageTextField.text = nil
                    self.mnemonicLanguageTextField.placeholder = NSLocalizedString("select_language", comment: "")
                    self.mnemonicLanguageTextField.isHidden = false
                    self.mnemonicLengthTextField.isHidden = true
                    self.mnemonicDescriptionLable.isHidden = true
                    self.mnemonicTextView.isEditable = false
                    self.mnemonicTextView.isHidden = true
                    self.nextButton.isHidden = true
                    self.selectedLanguage = nil
                    self.selectedLength = nil
                    self.mnemonic = []
                }
                else {
                    self.mnemonicLanguageTextField.isHidden = true
                    self.mnemonicLengthTextField.isHidden = true
                    self.mnemonicDescriptionLable.text = NSLocalizedString("enter_mnemonic_phrases", comment: "")
                    self.mnemonicDescriptionLable.isHidden = false
                    self.mnemonicTextView.text = nil
                    self.mnemonicTextView.isEditable = true
                    self.mnemonicTextView.isHidden = false
                    self.nextButton.isHidden = false
                    self.selectedLanguage = nil
                    self.selectedLength = nil
                    self.mnemonic = []
                }
            case .mnemonicLanguage:
                self.selectedLanguage = ATBIP39.Language.allCases[index]
                self.mnemonicLanguageTextField.text = self.selectedLanguage!.description
                self.mnemonicLengthTextField.text = nil
                self.mnemonicLengthTextField.placeholder = NSLocalizedString("select_length", comment: "")
                self.mnemonicLengthTextField.isHidden = false
                self.mnemonicDescriptionLable.isHidden = true
                self.mnemonicTextView.isHidden = true
                self.nextButton.isHidden = true
                self.selectedLength = nil
                self.mnemonic = []
            case .mnemonicLength:
                self.selectedLength = ATBIP39.MnemonicLength.allCases[index]
                self.mnemonicLengthTextField.text = String(self.selectedLength!.rawValue)
                if let language = self.selectedLanguage, let length = self.selectedLength, let mnemonic = ATBIP39().generateMnemonic(Length: length, Language: language) {
                    self.mnemonic = mnemonic
                    
                    var text = ""
                    var index = 0
                    self.mnemonic.forEach({ (word) in
                        index += 1
                        text.append("\(index).\t\(word)\n")
                    })
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 100, options: [:])]
                    self.mnemonicTextView.setContentOffset(.zero, animated: false)
                    self.mnemonicTextView.attributedText = NSAttributedString(string: text, attributes: [.paragraphStyle: paragraph, .foregroundColor: UIColor(named: "TextColor") ?? UIColor.red, .font: UIFont.preferredFont(forTextStyle: .title2)])
                    
                    self.mnemonicDescriptionLable.text = NSLocalizedString("write_down_mnemonic_phrases", comment: "")
                    self.mnemonicDescriptionLable.isHidden = false
                    self.mnemonicTextView.isHidden = false
                    self.nextButton.isHidden = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if self.mnemonicTextView.contentOffset.y >= (self.mnemonicTextView.contentSize.height - self.mnemonicTextView.frame.size.height) {
                            self.nextButton.isHidden = false
                        }
                    }
                }
            }
        }
        self.pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView.frame = CGRect(x: 0, y: 0, width: 250, height: height)
        self.pickerView.reloadAllComponents()
        AppController.shared.showAlert(self, nil, nil, [action], self.pickerView)
    }
    
    var hdwIndex: ATHDWallet.Index = .any
    
    private var pickerView: UIPickerView!
    private var pickerType: PickerType!
    private var selectedMethod: InitMethod?
    private var selectedLanguage: ATBIP39.Language?
    private var selectedLength: ATBIP39.MnemonicLength?
    private var mnemonic: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.setHidesBackButton(true, animated: true)
        self.titleLabel.text = NSLocalizedString("initialize_wallet", comment: "")
        self.mnemonicTextView.layer.cornerRadius = 8
        self.nextButton.setTitle(NSLocalizedString("next", comment: ""), for: .normal)
        self.pickerView = UIPickerView()
        self.pickerView.dataSource = self
        self.pickerView.delegate = self
        
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
        if let viewControllers = self.navigationController?.viewControllers, viewControllers[viewControllers.count - 2].isKind(of: SettingsViewController.self) {
            self.navigationItem.setHidesBackButton(false, animated: true)
        }
        else {
            self.navigationItem.setHidesBackButton(true, animated: true)
        }
        self.descriptionLabel.text = nil
        self.nameTextField.text = nil
        self.nameTextField.placeholder = NSLocalizedString("input_wallet_name", comment: "")
        self.initMethodTextField.text = nil
        self.initMethodTextField.placeholder = NSLocalizedString("select_initializing_method", comment: "")
        self.mnemonicLanguageTextField.isHidden = true
        self.mnemonicLengthTextField.isHidden = true
        self.mnemonicDescriptionLable.isHidden = true
        self.mnemonicTextView.isHidden = true
        self.nextButton.isHidden = true
        self.selectedMethod = nil
        self.selectedLanguage = nil
        self.selectedLength = nil
        self.mnemonic = []
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
    }
        
    @objc func hideKeyboard(_ tap: UITapGestureRecognizer) {
        self.view.endEditing(true)
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? MnemonicCheckingViewController {
            vc.hdwIndex = self.hdwIndex
            vc.mnemonic = self.mnemonic
            vc.name = self.nameTextField.text
        }
        else if let vc = segue.destination as? WalletRecoveryViewController {
            vc.hdwIndex = self.hdwIndex
            vc.mnemonic = self.mnemonic
            vc.name = self.nameTextField.text
        }
    }

    // MARK: - UITextFieldDelegate
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        guard textField.isEqual(self.nameTextField) else { return false }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: - UIPickerViewDataSource & UIPickerViewDelegate
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch self.pickerType! {
        case .initMethod:
            return InitMethod.allCases.count
        case .mnemonicLanguage:
            return ATBIP39.Language.allCases.count
        case .mnemonicLength:
            return ATBIP39.MnemonicLength.allCases.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch self.pickerType! {
        case .initMethod:
            return InitMethod.allCases[row].description
        case .mnemonicLanguage:
            return ATBIP39.Language.allCases[row].description
        case .mnemonicLength:
            return String(ATBIP39.MnemonicLength.allCases[row].rawValue)
        }
    }
    
    // MARK: - UITextViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height) {
            self.nextButton.isHidden = false
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
        
}
