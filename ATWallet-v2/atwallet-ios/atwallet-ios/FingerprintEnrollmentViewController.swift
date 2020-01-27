//
//  FingerprintEnrollmentViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/27.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class FingerprintEnrollmentViewController: UIViewController {
    
    enum State {
        case none
        case enrolling
        case verifying
        case done
        case failed
    }
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var stateLabel: UILabel!
    @IBOutlet var stateDescriptionLabel: UILabel!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var leftButton: UIButton!
    @IBOutlet var middleButton: UIButton!
    @IBOutlet var rightButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func leftButtonAction(_ sender: UIButton) {
        switch self.state {
        case .enrolling, .verifying:
            self.cancellationCallback?()
            self.state = .failed
            updateUI()
        default:
            if self.isModal {
                dismiss(animated: true, completion: nil)
            }
            else {
                self.navigationController?.popViewController(animated: true)
            }
            self.state = .none
        }
    }
    
    @IBAction func middleButtonAction(_ sender: UIButton) {
        addFingerprint()
    }
    
    @IBAction func rightButtonAction(_ sender: UIButton) {
        if AppController.shared.isColdWalletLoggedIn() || !AppController.shared.isColdWalletConnected() {
            if self.isModal {
                dismiss(animated: true, completion: nil)
            }
            else {
                self.navigationController?.popViewController(animated: true)
            }
        }
        else {
            self.performSegue(withIdentifier: "LoginSegue", sender: self)
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
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.setHidesBackButton(true, animated: true)
        if !AppController.shared.isUsingPadUI {
#if TESTNET
            self.logoImageView?.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if self.state == .none {
            updateUI()
            self.progress = 0
            self.enrolledNumber = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
        AppController.shared.showBusyPrompt(self, nil)
        if self.state == .none {
            AppController.shared.isColdWalletAbleToAddFingerprint { (able, error) in
                AppController.shared.hideBusyPrompt(self)
                self.enrollable = able ?? false
                guard error == nil, able == true else {
                    error != nil ? ATLog.debug(error!.description) : nil
                    switch error {
                    case .loginRequired:
                        AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                            if self.isModal {
                                self.dismiss(animated: true, completion: nil)
                                (self.presentingViewController != nil ) ? AppController.shared.popToRootViewController(self.presentingViewController!) : nil
                            }
                            else {
                                AppController.shared.popToRootViewController(self)
                            }
                        }])
                    case .failToConnect:
                        AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                            if self.isModal {
                                self.dismiss(animated: true, completion: nil)
                            }
                            else {
                                self.navigationController?.popViewController(animated: true)
                            }
                        }])
                    default:
                        AppController.shared.showAlert(self, "unable_to_add_fingerprints".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                            if self.isModal {
                                self.dismiss(animated: true, completion: nil)
                            }
                            else {
                                self.navigationController?.popViewController(animated: true)
                            }
                        }])
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
            self.titleLabel.text = NSLocalizedString("enroll_fingerprint", comment: "")
            self.descriptionLabel.text = nil;
            self.stateLabel.text = nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
            self.leftButton.isHidden = true
            self.middleButton.setTitle(NSLocalizedString("enroll", comment: ""), for: .normal)
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .enrolling:
            self.titleLabel.text = NSLocalizedString("enroll_fingerprint", comment: "")
            self.descriptionLabel.text = NSLocalizedString(self.swipeEnrollment ? "swipe_your_finger" : "lift_and_rest_your_finger_repeatedly", comment: "")
            self.stateLabel.text = "\(progress)%"
            self.stateDescriptionLabel.text = nil
            self.leftButton.isHidden = false
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .verifying:
            self.titleLabel.text = NSLocalizedString("verify_fingerprint", comment: "")
            self.descriptionLabel.text = NSLocalizedString("lift_and_rest_your_finger", comment: "")
            self.stateLabel.text = (progress >= 100) ? "\(progress)%" : nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.isHidden = false
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .done:
            self.descriptionLabel.text = nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.isHidden = true
            self.middleButton.setTitle(NSLocalizedString("enroll", comment: ""), for: .normal)
            self.middleButton.isHidden = true // update state in checkEnrollibility()
            self.rightButton.setTitle(NSLocalizedString(AppController.shared.isColdWalletLoggedIn() ? "done" : "next", comment: ""), for: .normal)
            self.rightButton.isHidden = false
            break
        case .failed:
            self.titleLabel.text = NSLocalizedString("enroll_fingerprint", comment: "")
            self.descriptionLabel.text = nil;
            self.stateLabel.text = nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.isHidden = false
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
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
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        AppController.shared.popToRootViewController(self)
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    AppController.shared.showAlert(self, "failed_to_enroll_fingerprint".localizedString, nil)
                }
                self.state = .failed
                self.updateUI()
                return
            }
            if self.state == .verifying, let place = placeFingerRequired {
                !place ? AppController.shared.showBusyPrompt(self, NSLocalizedString("matching_fingerprint", comment: "")) : nil
            }
            if let progress = progress {
                self.progress = progress
                self.stateLabel.text = "\(progress)%"
                if progress >= 100, self.verifyEnrollment {
                    self.state = .verifying
                    self.updateUI()
                }
            }
            if !self.swipeEnrollment, let place = placeFingerRequired {
                self.stateDescriptionLabel.text = NSLocalizedString(place ? "place_your_finger" : "lift_your_finger", comment: "")
            }
            if let matched = verifyMatched {
                AppController.shared.hideBusyPrompt(self)
                self.stateLabel.text = NSLocalizedString(matched ? "matched" : "not_matched", comment: "")
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
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? LoginViewController {
            vc.hdwIndex = .any
        }
    }

}
