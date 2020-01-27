//
//  FingerprintVerificationViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

protocol FingerprintVerificationViewControllerDelegate {
    func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> ()
    func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool
    func fpVerificationDidComplete(_ vc: FingerprintVerificationViewController, _ done: Bool, _ verified: Bool)
}

class FingerprintVerificationViewController: NSViewController {
    
    typealias PrecompletionCallback = ((_ vc: FingerprintVerificationViewController) -> Bool)
    typealias CompletionCallback = ((_ done: Bool, _ verified: Bool) -> ())
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var stateLabel: NSTextField!
    @IBOutlet weak var stateDescriptionLabel: NSTextField!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var verifyButton: NSButton!
    @IBOutlet weak var doneButton: NSButton!
    
    @IBAction func cancelButtonAction(_ sender: NSButton) {
        self.cancelCallback?()
        dismiss(self)
        DispatchQueue.main.async {
            self.delegate?.fpVerificationDidComplete(self, false, self.numberOfVerified > 0)
            self.delegate = nil
        }
    }
    
    @IBAction func verifyButtonAction(_ sender: NSButton) {
        verifyFingerprint()
    }
    
    @IBAction func doneButtonAction(_ sender: NSButton) {
        if self.delegate?.fpVerificationShouldComplete(self) == false { return }
        dismiss(self)
        DispatchQueue.main.async {
            self.delegate?.fpVerificationDidComplete(self, true, self.numberOfVerified > 0)
            self.delegate = nil
        }
    }
    
    var delegate: FingerprintVerificationViewControllerDelegate?
    
    private var cancelCallback: (() -> ())?
    private var numberOfVerified = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.MenuBackgroundColor.cgColor
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.cancelButton.attributedTitle = NSAttributedString(string: "cancel".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.cancelButton.attributedAlternateTitle = NSAttributedString(string: "cancel".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.verifyButton.attributedTitle = NSAttributedString(string: "verify".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.verifyButton.attributedAlternateTitle = NSAttributedString(string: "verify".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.doneButton.attributedTitle = NSAttributedString(string: "done".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.doneButton.attributedAlternateTitle = NSAttributedString(string: "done".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
    }
    
    override func viewWillAppear() {
        self.titleLabel.stringValue = "verify_fingerprint".localizedString
        self.descriptionLabel.stringValue = "lift_and_rest_your_finger".localizedString
        self.delegate?.fpVerificationViewWillAppear(self)
        
        self.numberOfVerified = 0
        verifyFingerprint()
    }
    
    func verifyFingerprint() {
        self.descriptionLabel.isHidden = false
        self.stateLabel.stringValue = ""
        self.stateDescriptionLabel.stringValue = ""
        self.verifyButton.isHidden = true
        self.doneButton.isHidden = true
        AppController.shared.showBusyPrompt(self)
        self.cancelCallback = AppController.shared.coldWalletVerifyFingerprint { (matched, placeFingerRequired, error) in
            guard error == nil else {
                ATLog.debug(error!.description)
                AppController.shared.hideBusyPrompt(self)
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        self.dismiss(self)
                        DispatchQueue.main.async {
                            (self.parent != nil) ? AppController.shared.popSplitDetailViewToRootViewController() : nil
                        }
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    break
                }
                self.descriptionLabel.isHidden = true
                self.stateLabel.stringValue = "failed".localizedString
                self.verifyButton.isHidden = false
                self.doneButton.isHidden = (self.numberOfVerified == 0)
                return
            }
            if let place = placeFingerRequired {
                self.stateDescriptionLabel.stringValue = place ? "place_your_finger".localizedString : "lift_your_finger".localizedString
                (!place && matched == nil) ? AppController.shared.showBusyPrompt(self, "matching_fingerprint".localizedString) : AppController.shared.hideBusyPrompt(self)
            }
            if let matched = matched {
                AppController.shared.hideBusyPrompt(self)
                matched ? self.numberOfVerified += 1 : nil
                self.descriptionLabel.isHidden = true
                self.stateDescriptionLabel.stringValue = ""
                self.verifyButton.isHidden = false
                self.doneButton.isHidden = (self.numberOfVerified == 0)
                self.stateLabel.stringValue = matched ? "matched".localizedString : "not_matched".localizedString
            }
        }
    }
    
}
