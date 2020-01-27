//
//  LoginViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/27.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class LoginViewController: UIViewController {
    
    enum State {
        case none
        case verifying
        case done
        case failed
        case cancelled
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
        case .verifying:
            self.cancellationCallback?()
            self.state = .cancelled
            updateUI()
        default:
            AppController.shared.coldWalletCancelLogin { (error) in
                // do nothing
            }
            AppController.shared.popToRootViewController(self)
        }
    }
    
    @IBAction func middleButtonAction(_ sender: UIButton) {
        verifyFingerprint()
    }
    
    @IBAction func rightButtonAction(_ sender: UIButton) {
        login()
    }
    
    var hdwIndex: ATHDWallet.Index = .any
    
    private var cancellationCallback: (() -> ())?
    private var state: State = .none
    private var verifiedNumber = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.setHidesBackButton(true, animated: true)
        if !AppController.shared.isUsingPadUI {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if self.state == .none {
            self.titleLabel.text = NSLocalizedString("Login", comment: "")
            self.descriptionLabel.text = nil
            self.stateLabel.text = nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.isHidden = true
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
            self.verifiedNumber = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
        AppController.shared.showBusyPrompt(self, nil)
        AppController.shared.coldWalletPrepareForLogin { (prepared, error) in
            AppController.shared.hideBusyPrompt(self)
            guard error == nil, prepared == true else {
                AppController.shared.showAlert(self, NSLocalizedString("failed_to_start_login_process", comment: ""), nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: { (action) in
                    AppController.shared.popToRootViewController(self)
                })])
                return
            }
            self.verifyFingerprint()
        }
    }

    func updateUI() {
        switch self.state {
        case .none:
            self.titleLabel.text = NSLocalizedString("login", comment: "")
            self.descriptionLabel.text = nil
            self.stateLabel.text = nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.isHidden = true
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .verifying:
            self.titleLabel.text = NSLocalizedString("login", comment: "")
            self.descriptionLabel.text = NSLocalizedString("lift_and_rest_your_finger", comment: "")
            self.stateLabel.text = nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
            self.leftButton.isHidden = false
            self.middleButton.isHidden = true
            self.rightButton.isHidden = true
        case .done:
            self.descriptionLabel.text = nil
            self.stateDescriptionLabel.text = nil
            self.leftButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
            self.leftButton.isHidden = false
            self.middleButton.setTitle(NSLocalizedString("verify", comment: ""), for: .normal)
            self.middleButton.isHidden = false
            self.rightButton.setTitle(NSLocalizedString("login", comment: ""), for: .normal)
            self.rightButton.isHidden = self.verifiedNumber == 0
        case .failed, .cancelled:
            self.titleLabel.text = NSLocalizedString("login", comment: "")
            self.descriptionLabel.text = nil
            self.stateLabel.text = (self.state == .failed) ? NSLocalizedString("failed", comment: "") : NSLocalizedString("cancelled", comment: "")
            self.stateDescriptionLabel.text = nil
            self.leftButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
            self.leftButton.isHidden = false
            self.middleButton.setTitle(NSLocalizedString("verify", comment: ""), for: .normal)
            self.middleButton.isHidden = false
            self.rightButton.setTitle(NSLocalizedString("login", comment: ""), for: .normal)
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
                self.stateDescriptionLabel.text = NSLocalizedString(place ? "place_your_finger" : "lift_your_finger", comment: "")
                !place ? AppController.shared.showBusyPrompt(self, NSLocalizedString("matching_fingerprint", comment: "")) : nil
            }
            guard let matched = verifyMatched else { return }
            AppController.shared.hideBusyPrompt(self)
            self.state = .done
            self.stateLabel.text = NSLocalizedString(matched ? "matched" : "not_matched", comment: "")
            self.verifiedNumber += matched ? 1 : 0
            self.updateUI()
        }
    }
    
    func login() {
        AppController.shared.showBusyPrompt(self, "logging_in".localizedString)
        AppController.shared.coldWalletLogin(self.hdwIndex) { (loggedIn, initRequired, error) in
            AppController.shared.hideBusyPrompt(self)
            guard error == nil, loggedIn == true else {
                AppController.shared.showAlert(self, NSLocalizedString("failed_to_log_in_atwallet", comment: ""), nil, [UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default, handler: { (action) in
                    AppController.shared.popToRootViewController(self)
                })])
                return
            }
            if initRequired == true {
                self.performSegue(withIdentifier: "WalletInitializationSegue", sender: self)
            }
            else {
                self.performSegue(withIdentifier: "WalletSegue", sender: self)
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let vc = segue.destination as? WalletInitializationViewController {
            vc.hdwIndex = (self.hdwIndex == .any) ? .first : self.hdwIndex
        }
    }
    
}
