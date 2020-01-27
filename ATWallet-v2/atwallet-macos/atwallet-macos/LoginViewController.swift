//
//  LoginViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/8/12.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class LoginViewController: NSViewController {
    
    enum State {
        case none
        case verifying
        case done
        case failed
        case cancelled
    }
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var stateLabel: NSTextField!
    @IBOutlet weak var stateDescriptionLabel: NSTextField!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var leftButton: NSButton!
    @IBOutlet weak var middleButton: NSButton!
    @IBOutlet weak var rightButton: NSButton!
    
    @IBAction func leftButtonAction(_ sender: NSButton) {
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
        
        switch self.state {
        case .verifying:
            self.cancellationCallback?()
            self.cancellationCallback = nil
            self.state = .cancelled
            updateUI()
        default:
            AppController.shared.coldWalletCancelLogin { (error) in
                AppController.shared.popSplitDetailViewToRootViewController()
            }
        }
    }
    
    @IBAction func middleButtonAction(_ sender: NSButton) {
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
        
        verifyFingerprint()
    }
    
    @IBAction func rightButtonAction(_ sender: NSButton) {
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
        
        login()
    }
    
    var hdwIndex: ATHDWallet.Index = .any
    
    private var cancellationCallback: (() -> ())?
    private var state: State = .none
    private var verifiedNumber = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.leftButton.attributedTitle = NSAttributedString(string: "cancel".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.leftButton.attributedAlternateTitle = NSAttributedString(string: "cancel".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.middleButton.attributedTitle = NSAttributedString(string: "verify".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.middleButton.attributedAlternateTitle = NSAttributedString(string: "verify".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.rightButton.attributedTitle = NSAttributedString(string: "login".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.rightButton.attributedAlternateTitle = NSAttributedString(string: "login".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
    }
    
    override func viewWillAppear() {
        if self.state == .none {
            self.titleLabel.stringValue = "Login".localizedString
            self.descriptionLabel.stringValue = ""
            self.stateLabel.stringValue = ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = true
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
            self.verifiedNumber = 0
        }
    }
    
    override func viewDidAppear() {
        AppController.shared.showBusyPrompt()
        AppController.shared.coldWalletPrepareForLogin { (prepared, error) in
            AppController.shared.hideBusyPrompt()
            guard error == nil, prepared == true else {
                AppController.shared.showAlert("failed_to_start_login_process".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                    // TODO: dismiss this vc in another way if this vc is not presented by the push method
                    AppController.shared.popSplitDetailViewToRootViewController()
                })])
                return
            }
            self.verifyFingerprint()
        }
    }
    
    override func viewWillDisappear() {
        switch self.state {
        case .verifying:
            self.cancellationCallback?()
            self.cancellationCallback = nil
            AppController.shared.coldWalletCancelLogin { (error) in
                // do nothing
            }
            self.state = .none
        case .done, .failed, .cancelled:
            AppController.shared.coldWalletCancelLogin { (error) in
                // do nothing
            }
            self.state = .none
        default:
            break
        }
    }

    func updateUI() {
        switch self.state {
        case .none:
            self.titleLabel.stringValue = "login".localizedString
            self.descriptionLabel.stringValue = ""
            self.stateLabel.stringValue = ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = true
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .verifying:
            self.titleLabel.stringValue = "login".localizedString
            self.descriptionLabel.stringValue = "lift_and_rest_your_finger".localizedString
            self.stateLabel.stringValue = ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = false
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .done:
            self.descriptionLabel.stringValue = ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = false
            self.middleButton.isHidden = false
            self.rightButton.isHidden = self.verifiedNumber == 0
        case .failed, .cancelled:
            self.titleLabel.stringValue = "login".localizedString
            self.descriptionLabel.stringValue = ""
            self.stateLabel.stringValue = (self.state == .failed) ? "failed".localizedString : "cancelled".localizedString
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = false
            self.middleButton.isHidden = false
            self.rightButton.isHidden = self.verifiedNumber == 0
        }
    }
    
    func verifyFingerprint() {
        self.state = .verifying
        updateUI()
        self.cancellationCallback = AppController.shared.coldWalletVerifyFingerprint { (verifyMatched, placeFingerRequired, error) in
            guard error == nil else {
                guard self.state != .cancelled else { return }
                self.state = .failed
                self.updateUI()
                return
            }
            if let place = placeFingerRequired {
                self.stateDescriptionLabel.stringValue = place ? "place_your_finger".localizedString : "lift_your_finger".localizedString
                !place ? AppController.shared.showBusyPrompt("matching_fingerprint".localizedString) : nil
            }
            guard let matched = verifyMatched else { return }
            AppController.shared.hideBusyPrompt()
            self.state = .done
            self.stateLabel.stringValue = matched ? "matched".localizedString : "not_matched".localizedString
            self.verifiedNumber += matched ? 1 : 0
            self.updateUI()
        }
    }
    
    func login() {
        AppController.shared.showBusyPrompt("logging_in".localizedString)
        AppController.shared.coldWalletLogin(self.hdwIndex) { (loggedIn, initRequired, error) in
            AppController.shared.hideBusyPrompt()
            guard error == nil, loggedIn == true else {
                AppController.shared.showAlert("failed_to_log_in_atwallet".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                    AppController.shared.popSplitDetailViewToRootViewController()
                })])
                return
            }
            if initRequired == true {
                AppController.shared.pushSplitDetailView(.WalletInitialization) { (vc) in
                    guard let walletInitializationVC = vc as? WalletInitializationViewController else { return }
                    walletInitializationVC.hdwIndex = (self.hdwIndex == .any) ? .first : self.hdwIndex
                }
            }
            else {
                AppController.shared.pushSplitDetailView(.Wallet)
            }
        }
    }
    
}
