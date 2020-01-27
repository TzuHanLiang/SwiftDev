//
//  FingerprintVerificationViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/11.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

protocol FingerprintVerificationViewControllerDelegate {
    func fpVerificationViewWillAppear(_ vc: FingerprintVerificationViewController) -> ()
    func fpVerificationShouldComplete(_ vc: FingerprintVerificationViewController) -> Bool
    func fpVerificationDidComplete(_ vc: FingerprintVerificationViewController, _ done: Bool, _ verified: Bool)
}

class FingerprintVerificationViewController: UIViewController {
    
    typealias PrecompletionCallback = ((_ vc: FingerprintVerificationViewController) -> Bool)
    typealias CompletionCallback = ((_ done: Bool, _ verified: Bool) -> ())
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var stateLabel: UILabel!
    @IBOutlet var stateDescriptionLabel: UILabel!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var verifyButton: UIButton!
    @IBOutlet var doneButton: UIButton!
    
    @IBAction func cancelButtonAction(_ sender: UIButton) {
        self.cancelCallback?()
        dismiss(animated: true) {
            self.delegate?.fpVerificationDidComplete(self, false, self.numberOfVerified > 0)
            self.delegate = nil
        }
    }
    
    @IBAction func verifyButtonAction(_ sender: UIButton) {
        verifyFingerprint()
    }
    
    @IBAction func doneButtonAction(_ sender: UIButton) {
        if self.delegate?.fpVerificationShouldComplete(self) == false { return }
        dismiss(animated: true) {
            self.delegate?.fpVerificationDidComplete(self, true, self.numberOfVerified > 0)
            self.delegate = nil
        }
    }
    
    var delegate: FingerprintVerificationViewControllerDelegate?
    
    private var cancelCallback: (() -> ())?
    private var numberOfVerified = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.titleLabel.text = "verify_fingerprint".localizedString
        self.descriptionLabel.text = "lift_and_rest_your_finger".localizedString
        self.cancelButton.setTitle("cancel".localizedString, for: .normal)
        self.verifyButton.setTitle("verify".localizedString, for: .normal)
        self.doneButton.setTitle("done".localizedString, for: .normal)
        self.delegate?.fpVerificationViewWillAppear(self)
        
        self.numberOfVerified = 0
        verifyFingerprint()
    }
    
    func verifyFingerprint() {
        self.descriptionLabel.isHidden = false
        self.stateLabel.text = nil
        self.stateDescriptionLabel.text = nil
        self.verifyButton.isHidden = true
        self.doneButton.isHidden = true
        AppController.shared.showBusyPrompt(self, nil)
        self.cancelCallback = AppController.shared.coldWalletVerifyFingerprint { (matched, placeFingerRequired, error) in
            guard error == nil else {
                ATLog.debug(error!.description)
                AppController.shared.hideBusyPrompt(self)
                switch error {
                case .loginRequired:
                    AppController.shared.showAlert(self, "session_expired_and_relogin".localizedString, nil, [UIAlertAction(title: "ok".localizedString, style: .default) { (action) in
                        self.dismiss(animated: true, completion: nil)
                        (self.parent != nil) ? AppController.shared.popToRootViewController(self.parent!) : nil
                    }])
                case .failToConnect:
                    AppController.shared.showAlert(self, "failed_to_connect_and_check_power_on".localizedString, nil)
                default:
                    break
                }
                self.descriptionLabel.isHidden = true
                self.stateLabel.text = "failed".localizedString
                self.verifyButton.isHidden = false
                self.doneButton.isHidden = (self.numberOfVerified == 0)
                return
            }
            if let place = placeFingerRequired {
                self.stateDescriptionLabel.text = place ? "place_your_finger".localizedString : "lift_your_finger".localizedString
                (!place && matched == nil) ? AppController.shared.showBusyPrompt(self, "matching_fingerprint".localizedString) : AppController.shared.hideBusyPrompt(self)
            }
            if let matched = matched {
                AppController.shared.hideBusyPrompt(self)
                matched ? self.numberOfVerified += 1 : nil
                self.descriptionLabel.isHidden = true
                self.stateDescriptionLabel.text = nil
                self.verifyButton.isHidden = false
                self.doneButton.isHidden = (self.numberOfVerified == 0)
                self.stateLabel.text = matched ? "matched".localizedString : "not_matched".localizedString
            }
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

}
