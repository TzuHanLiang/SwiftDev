//
//  FingerprintEnrollmentViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class FingerprintEnrollmentViewController: NSViewController {
    
    enum State {
        case none
        case enrolling
        case verifying
        case done
        case failed
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
        switch self.state {
        case .enrolling, .verifying:
            self.cancellationCallback?()
            self.state = .failed
            updateUI()
        default:
            if AppController.shared.isTopSplitDetailView(self) {
                AppController.shared.popSplitDetailView()
            }
            else {
                dismiss(self)
            }
            self.state = .none
        }
    }
    
    @IBAction func middleButtonAction(_ sender: NSButton) {
        addFingerprint()
    }
    
    @IBAction func rightButtonAction(_ sender: NSButton) {
        if AppController.shared.isColdWalletLoggedIn() {
            if AppController.shared.isTopSplitDetailView(self) {
                AppController.shared.popSplitDetailView()
            }
            else {
                dismiss(self)
            }
        }
        else {
            AppController.shared.pushSplitDetailView(.Login) { (vc) in
                guard let loginVC = vc as? LoginViewController else { return }
                loginVC.hdwIndex = .any
            }
        }
        self.state = .none
    }
    
    private let verifyEnrollment = true
    private let swipeEnrollment = false
    private var cancellationCallback: (() -> ())?
    private var state: State = .none
    private var progress: Int = 0
    private var enrolledNumber: Int = 0
    private var enrollable = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.leftButton.attributedTitle = NSAttributedString(string: "cancel".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.leftButton.attributedAlternateTitle = NSAttributedString(string: "cancel".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.middleButton.attributedTitle = NSAttributedString(string: "enroll".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.middleButton.attributedAlternateTitle = NSAttributedString(string: "enroll".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
    }
    
    override func viewWillAppear() {
        if self.state == .none {
            updateUI()
            self.progress = 0
            self.enrolledNumber = 0
        }
    }
        
    override func viewDidAppear() {
        AppController.shared.showBusyPrompt()
        if self.state == .none {
            AppController.shared.isColdWalletAbleToAddFingerprint { (able, error) in
                AppController.shared.hideBusyPrompt()
                self.enrollable = able ?? false
                guard error == nil, able == true else {
                    error != nil ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                            if !AppController.shared.isTopSplitDetailView(self) {
                                self.dismiss(self)
                            }
                            AppController.shared.popSplitDetailViewToRootViewController()
                        })])
                    case .failToConnect:
                        AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                            if AppController.shared.isTopSplitDetailView(self) {
                                AppController.shared.popSplitDetailView()
                            }
                            else {
                                self.dismiss(self)
                            }
                        })])
                    default:
                        AppController.shared.showAlert("unable_to_add_fingerprints".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                            if AppController.shared.isTopSplitDetailView(self) {
                                AppController.shared.popSplitDetailView()
                            }
                            else {
                                self.dismiss(self)
                            }
                        })])
                    }
                    self.leftButton.isHidden = false
                    return
                }
                self.addFingerprint()
            }
        }
    }
    
    func updateUI() {
        switch self.state {
        case .none:
            self.titleLabel.stringValue = "enroll_fingerprint".localizedString
            self.descriptionLabel.stringValue = "";
            self.stateLabel.stringValue = ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = true
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .enrolling:
            self.titleLabel.stringValue = "enroll_fingerprint".localizedString
            self.descriptionLabel.stringValue = self.swipeEnrollment ? "swipe_your_finger".localizedString : "lift_and_rest_your_finger_repeatedly".localizedString
            self.stateLabel.stringValue = "\(progress)%"
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = false
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .verifying:
            self.titleLabel.stringValue = "verify_fingerprint".localizedString
            self.descriptionLabel.stringValue = "lift_and_rest_your_finger".localizedString
            self.stateLabel.stringValue = (progress >= 100) ? "\(progress)%" : ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = false
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .done:
            self.descriptionLabel.stringValue = ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = true
            self.middleButton.isHidden = true // update state in checkEnrollibility()
            self.rightButton.isHidden = false
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            self.rightButton.attributedTitle = NSAttributedString(string: AppController.shared.isColdWalletLoggedIn() ? "done".localizedString : "next".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
            self.rightButton.attributedAlternateTitle = NSAttributedString(string: AppController.shared.isColdWalletLoggedIn() ? "done".localizedString : "next".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
            break
        case .failed:
            self.titleLabel.stringValue = "enroll_fingerprint".localizedString
            self.descriptionLabel.stringValue = ""
            self.stateLabel.stringValue = ""
            self.stateDescriptionLabel.stringValue = ""
            self.leftButton.isHidden = (self.enrolledNumber > 0)
            self.middleButton.isHidden = !self.enrollable
            self.rightButton.isHidden = (self.enrolledNumber == 0)
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            self.rightButton.attributedTitle = NSAttributedString(string: AppController.shared.isColdWalletLoggedIn() ? "done".localizedString : "next".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
            self.rightButton.attributedAlternateTitle = NSAttributedString(string: AppController.shared.isColdWalletLoggedIn() ? "done".localizedString : "next".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        }
    }
    
    func addFingerprint() {
        self.state = .enrolling
        self.progress = 0
        updateUI()
        self.cancellationCallback = AppController.shared.coldWalletAddFingerprint(self.verifyEnrollment, self.swipeEnrollment) { (progress, placeFingerRequired, verifyMatched, done, error) in
            guard error == nil else {
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert("session_expired_and_relogin".localizedString, nil, [AppController.AlertAction(title: "ok".localizedString, callback: {
                        if AppController.shared.isTopSplitDetailView(self) {
                            self.dismiss(self)
                        }
                        AppController.shared.popSplitDetailViewToRootViewController()
                    })])
                case .failToConnect:
                    AppController.shared.showAlert("failed_to_connect_and_check_power_on".localizedString)
                default:
                    AppController.shared.showAlert("failed_to_enroll_fingerprint".localizedString)
                }
                self.state = .failed
                self.updateUI()
                return
            }
            if self.state == .verifying, let place = placeFingerRequired {
                !place ? AppController.shared.showBusyPrompt("matching_fingerprint".localizedString) : nil
            }
            if let progress = progress {
                self.progress = progress
                self.stateLabel.stringValue = "\(progress)%"
                if progress >= 100, self.verifyEnrollment {
                    self.state = .verifying
                    self.updateUI()
                }
            }
            if !self.swipeEnrollment, let place = placeFingerRequired {
                self.stateDescriptionLabel.stringValue = place ? "place_your_finger".localizedString : "lift_your_finger".localizedString
            }
            if let matched = verifyMatched {
                AppController.shared.hideBusyPrompt()
                self.stateLabel.stringValue = matched ? "matched".localizedString : "not_matched".localizedString
                self.enrolledNumber += matched ? 1 : 0
            }
            if done {
                self.state = .done
                self.updateUI()
                self.checkEnrollibility()
            }
        }
    }
    
    func checkEnrollibility() {
        AppController.shared.isColdWalletAbleToAddFingerprint { (able, error) in
            self.enrollable = able ?? false
            self.middleButton.isHidden = !self.enrollable
        }
    }
    
}
