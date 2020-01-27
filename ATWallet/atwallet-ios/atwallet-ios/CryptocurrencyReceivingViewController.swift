//
//  CryptocurrencyReceivingViewController.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/9.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit
import ATWalletKit

class CryptocurrencyReceivingViewController: UIViewController {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var addressTypeLabel: UILabel!
    @IBOutlet var addressLabel: UILabel!
    @IBOutlet var qrCodeImageView: UIImageView!
    @IBOutlet var copyButton: UIButton!
    @IBOutlet var addressButton: UIButton!
    @IBOutlet var shareButton: UIButton!
    
    @IBAction func menuButtonAction(_ sender: Any) {
        AppController.shared.showMenu(self)
    }
    
    @IBAction func backButtonAction(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func copyButtonAction(_ sender: UIButton) {
        guard let address = self.addressLabel.text else { return }
        UIPasteboard.general.string = address
    }
    
    @IBAction func addressButtonAction(_ sender: UIButton) {
        guard let keys = self.addresses?.keys, keys.count > 1 else { return }
        let index = (self.addressLabel.tag + 1) % keys.count
        let format = Array(keys)[index]
        guard let address = self.addresses?[format] else { return }
        
        self.addressTypeLabel.text = format
        self.addressLabel.text = address
        self.addressLabel.tag = index
        self.qrCodeImageView.image = (self.crytocurrencyType != nil) ? AppController.shared.generateAddressQRCode(self.crytocurrencyType!, address, self.qrCodeImageView.frame.size) : nil
    }
    
    @IBAction func shareButtonAction(_ sender: UIButton) {
        guard let address = self.addressLabel.text else { return }
        let activityViewController = UIActivityViewController(activityItems: [address], applicationActivities: nil)
        if AppController.shared.appleDeviceType == .pad {
            present(activityViewController, animated: true, completion: nil)
            if let popOver = activityViewController.popoverPresentationController {
                popOver.sourceView = self.shareButton
            }
        }
        else {
            present(activityViewController, animated: true, completion: nil)
        }
    }
    
    var crytocurrencyType: ATCryptocurrencyType?
    var addresses: [String: String]?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        //self.navigationItem.setHidesBackButton(true, animated: true)
        self.descriptionLabel.text = nil
        self.copyButton.setTitle("copy".localizedString, for: .normal)
        self.addressButton.setTitle("address".localizedString, for: .normal)
        self.shareButton.setTitle("share".localizedString, for: .normal)
        
        if !AppController.shared.isUsingPadUI {
#if TESTNET
            self.logoImageView.image = UIImage(named: "TestnetLogo")
#endif
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.titleLabel.text = "\("receive".localizedString) \(self.crytocurrencyType?.name ?? "cryptocurrency")"
        self.addressTypeLabel.text = nil
        self.addressLabel.text = nil
        self.qrCodeImageView.image = nil
        self.addressButton.isHidden = true
        self.copyButton.isHidden = true
        self.shareButton.isHidden = true
        self.copyButton.isHidden = false
        self.shareButton.isHidden = false
        
        /*// Multiple addresses
        guard let format = self.addresses?.keys.first, let address = self.addresses?[format] else {
            return
        }
        self.addressButton.isHidden = self.addresses?.count == 1
        self.addressTypeLabel.text = format
        self.addressLabel.text = address
        */
        // Single address
        var address = ""
        if let p2pkhAddr = self.addresses?["P2PKH"] {
            address = p2pkhAddr
        }
        else if let addr = self.addresses?.first?.value {
            address = addr
        }
        else {
            return
        }
        self.addressButton.isHidden = self.addresses?.count == 1
        self.addressTypeLabel.text = "address".localizedString
        self.addressLabel.text = address
        
        self.addressLabel.tag = 0
        self.qrCodeImageView.image = (self.crytocurrencyType != nil) ? AppController.shared.generateAddressQRCode(self.crytocurrencyType!, address, self.qrCodeImageView.frame.size) : nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = !self.navigationItem.hidesBackButton
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
