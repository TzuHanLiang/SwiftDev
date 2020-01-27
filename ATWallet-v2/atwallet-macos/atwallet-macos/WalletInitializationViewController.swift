//
//  WalletInitializationViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class WalletInitializationViewController: NSViewController, NSTextViewDelegate {
    
    enum InitMethod: Int, CaseIterable {
        case create
        case recover
        
        var description: String {
            get {
                switch self {
                case .create:
                    return "create_a_new_wallet".localizedString
                case .recover:
                    return "recovery_your_wallet".localizedString
                }
            }
        }
    }
    
    enum PickerType {
        case initMethod
        case mnemonicLanguage
        case mnemonicLength
    }
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var nameTextField: NSTextField!
    @IBOutlet weak var initMethodPopUpButton: NSPopUpButton!
    @IBOutlet weak var mnemonicLanguagePopUpButton: NSPopUpButton!
    @IBOutlet weak var mnemonicLengthPopUpButton: NSPopUpButton!
    @IBOutlet weak var mnemonicDescriptionLable: NSTextField!
    @IBOutlet weak var mnemonicTextView: NSTextView!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var backButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    @IBAction func nextButtonAction(_ sender: NSButton) {
        if self.selectedMethod == .create {
            AppController.shared.pushSplitDetailView(.MnemonicChecking) { (vc) in
                guard let mnemonicCheckingVC = vc as? MnemonicCheckingViewController else { return }
                mnemonicCheckingVC.hdwIndex = self.hdwIndex
                mnemonicCheckingVC.mnemonic = self.mnemonic
                mnemonicCheckingVC.name = self.nameTextField.stringValue
            }
        }
        else if self.selectedMethod == .recover {
            let mnemonicString = self.mnemonicTextView.string
            guard mnemonicString.count > 0 else {
                AppController.shared.showAlert("invalid_mnemonic".localizedString)
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
                AppController.shared.showAlert("invalid_mnemonic".localizedString)
                return
            }
            AppController.shared.pushSplitDetailView(.WalletRecovery) { (vc) in
                guard let walletRecoveryVC = vc as? WalletRecoveryViewController else { return }
                walletRecoveryVC.hdwIndex = self.hdwIndex
                walletRecoveryVC.mnemonic = self.mnemonic
                walletRecoveryVC.name = self.nameTextField.stringValue
            }
        }
    }
    
    @IBAction func popUpButtonAction(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        if sender == self.initMethodPopUpButton {
            guard index > 0 else {
                self.mnemonicLanguagePopUpButton.selectItem(at: 0)
                self.mnemonicLengthPopUpButton.selectItem(at: 0)
                self.mnemonicLanguagePopUpButton.isHidden = true
                self.mnemonicLengthPopUpButton.isHidden = true
                self.mnemonicDescriptionLable.isHidden = true
                self.mnemonicTextView.isHidden = true
                self.nextButton.isHidden = true
                self.selectedMethod = nil
                self.selectedLanguage = nil
                self.selectedLength = nil
                self.mnemonic = []
                return
            }
            
            self.selectedMethod = InitMethod.allCases[index - 1]
            if self.selectedMethod == .create {
                self.mnemonicLanguagePopUpButton.selectItem(at: 0)
                self.mnemonicLanguagePopUpButton.isHidden = false
                self.mnemonicLengthPopUpButton.isHidden = true
                self.mnemonicDescriptionLable.isHidden = true
                self.mnemonicTextView.isEditable = false
                self.mnemonicTextView.isHidden = true
                self.nextButton.isHidden = true
                self.selectedLanguage = nil
                self.selectedLength = nil
                self.mnemonic = []
            }
            else {
                self.mnemonicLanguagePopUpButton.selectItem(at: 0)
                self.mnemonicLanguagePopUpButton.isHidden = true
                self.mnemonicLengthPopUpButton.isHidden = true
                self.mnemonicDescriptionLable.stringValue = "enter_mnemonic_phrases".localizedString
                self.mnemonicDescriptionLable.isHidden = false
                self.mnemonicTextView.string = ""
                self.mnemonicTextView.isEditable = true
                self.mnemonicTextView.isHidden = false
                self.nextButton.isHidden = false
                self.selectedLanguage = nil
                self.selectedLength = nil
                self.mnemonic = []
            }
        }
        else if sender == self.mnemonicLanguagePopUpButton {
            guard index > 0 else {
                self.mnemonicLengthPopUpButton.selectItem(at: 0)
                self.mnemonicLengthPopUpButton.isHidden = true
                self.mnemonicDescriptionLable.isHidden = true
                self.mnemonicTextView.isEditable = false
                self.mnemonicTextView.isHidden = true
                self.nextButton.isHidden = true
                self.selectedLanguage = nil
                self.selectedLength = nil
                self.mnemonic = []
                return
            }
            
            self.selectedLanguage = ATBIP39.Language.allCases[index - 1]
            self.mnemonicLengthPopUpButton.selectItem(at: 0)
            self.mnemonicLengthPopUpButton.isHidden = false
            self.mnemonicDescriptionLable.isHidden = true
            self.mnemonicTextView.isHidden = true
            self.nextButton.isHidden = true
            self.selectedLength = nil
            self.mnemonic = []
        }
        else if sender == self.mnemonicLengthPopUpButton {
            guard index > 0 else {
                self.mnemonicDescriptionLable.isHidden = true
                self.mnemonicTextView.isHidden = true
                self.nextButton.isHidden = true
                self.selectedLength = nil
                self.mnemonic = []
                return
            }
            
            self.selectedLength = ATBIP39.MnemonicLength.allCases[index - 1]
            if let language = self.selectedLanguage, let length = self.selectedLength, let mnemonic = ATBIP39().generateMnemonic(Length: length, Language: language) {
                self.mnemonic = mnemonic
                
                var text = ""
                var index = 0
                self.mnemonic.forEach({ (word) in
                    index += 1
                    text.append("\(index).\t\(word)\n")
                })
                let style = NSMutableParagraphStyle()
                style.tabStops = [NSTextTab(textAlignment: .left, location: 50, options: [:])]
                
                self.mnemonicTextView.scrollToBeginningOfDocument(self)
                self.mnemonicTextView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: [.paragraphStyle: style, .foregroundColor: AppController.TextColor, .font: NSFont.systemFont(ofSize: 18)]))
                
                self.mnemonicDescriptionLable.stringValue = "write_down_mnemonic_phrases".localizedString
                self.mnemonicDescriptionLable.isHidden = false
                self.mnemonicTextView.isHidden = false
                self.nextButton.isHidden = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard let documentView = self.scrollView.documentView else { return }
                    let contentView = self.scrollView.contentView
                    if (contentView.bounds.origin.y + contentView.bounds.height) >= documentView.bounds.height {
                        self.nextButton.isHidden = false
                    }
                }
            }
        }
    }
    
    @objc func contentViewDidChangeBounds(_ notification: Notification) {
        guard let documentView = self.scrollView.documentView else { return }
        let contentView = self.scrollView.contentView
        if (contentView.bounds.origin.y + contentView.bounds.height) >= documentView.bounds.height {
            self.nextButton.isHidden = false
        }
    }
    
    var hdwIndex: ATHDWallet.Index = .any
    
    private var selectedMethod: InitMethod?
    private var selectedLanguage: ATBIP39.Language?
    private var selectedLength: ATBIP39.MnemonicLength?
    private var mnemonic: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.titleLabel.stringValue = NSLocalizedString("initialize_wallet", comment: "")
        self.nameTextField.wantsLayer = true
        self.nameTextField.layer?.cornerRadius = 5
        self.scrollView.wantsLayer = true
        self.scrollView.layer?.cornerRadius = 8
        self.scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(contentViewDidChangeBounds(_:)), name: NSView.boundsDidChangeNotification, object: self.scrollView.contentView)
        self.mnemonicTextView.typingAttributes = [.foregroundColor: AppController.TextColor, .font: NSFont.systemFont(ofSize: 18)]
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.nextButton.attributedTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.TextColor.self, .paragraphStyle: style])
        self.nextButton.attributedAlternateTitle = NSAttributedString(string: "next".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
        
        var initMethodItems = ["select_initializing_method".localizedString]
        for method in InitMethod.allCases {
            initMethodItems.append(method.description)
        }
        self.initMethodPopUpButton.addItems(withTitles: initMethodItems)
        
        var languageItems = ["select_language".localizedString]
        for language in ATBIP39.Language.allCases {
            languageItems.append(language.description)
        }
        self.mnemonicLanguagePopUpButton.addItems(withTitles: languageItems)
        
        var lengthItems = ["select_length".localizedString]
        for length in ATBIP39.MnemonicLength.allCases {
            lengthItems.append(String(length.rawValue))
        }
        self.mnemonicLengthPopUpButton.addItems(withTitles: lengthItems)
    }
    
    override func viewWillAppear() {
        self.descriptionLabel.stringValue = ""
        self.nameTextField.stringValue = ""
        self.nameTextField.placeholderString = "input_wallet_name".localizedString
        self.initMethodPopUpButton.selectItem(at: 0)
        self.mnemonicLanguagePopUpButton.selectItem(at: 0)
        self.mnemonicLengthPopUpButton.selectItem(at: 0)
        self.mnemonicLanguagePopUpButton.isHidden = true
        self.mnemonicLengthPopUpButton.isHidden = true
        self.mnemonicDescriptionLable.isHidden = true
        self.mnemonicTextView.isHidden = true
        self.nextButton.isHidden = true
        self.backButton.isHidden = (AppController.shared.coldWalletGetHDWallet() == nil)
        self.selectedMethod = nil
        self.selectedLanguage = nil
        self.selectedLength = nil
        self.mnemonic = []
    }
        
    // MARK: - NSTextViewDelegate
    
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if replacementString == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}
