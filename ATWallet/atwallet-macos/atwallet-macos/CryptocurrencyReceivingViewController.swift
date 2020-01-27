//
//  CryptocurrencyReceivingViewController.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa
import ATWalletKit

class CryptocurrencyReceivingViewController: NSViewController {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var addressTypeLabel: NSTextField!
    @IBOutlet weak var addressLabel: NSTextField!
    @IBOutlet weak var qrCodeImageView: NSImageView!
    @IBOutlet weak var copyButton: NSButton!
    @IBOutlet weak var addressButton: NSButton!
    @IBOutlet weak var shareButton: NSButton!
    @IBOutlet weak var backButton: NSButton!
    
    @IBAction func backButtonAction(_ sender: NSButton) {
        guard AppController.shared.isTopSplitDetailView(self) else { return }
        AppController.shared.popSplitDetailView()
    }
    
    @IBAction func copyButtonAction(_ sender: NSButton) {
        let address = self.addressLabel.stringValue
        guard address != "" else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(address, forType: .string)
    }
    
    @IBAction func addressButtonAction(_ sender: NSButton) {
        guard let keys = self.addresses?.keys, keys.count > 1 else { return }
        let index = (self.addressLabel.tag + 1) % keys.count
        let format = Array(keys)[index]
        guard let address = self.addresses?[format] else { return }
        
        self.addressTypeLabel.stringValue = format
        self.addressLabel.stringValue = address
        self.addressLabel.tag = index
        self.qrCodeImageView.image = (self.crytocurrencyType != nil) ? AppController.shared.generateAddressQRCode(self.crytocurrencyType!, address, self.qrCodeImageView.frame.size) : nil
    }
    
    @IBAction func shareButtonAction(_ sender: NSButton) {
        let address = self.addressLabel.stringValue
        guard address != "" else { return }
        let shareingServicePicker = NSSharingServicePicker(items: [address])
        //shareingServicePicker.delegate = self
        shareingServicePicker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
    }
    
    var crytocurrencyType: ATCryptocurrencyType?
    var addresses: [String: String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = AppController.BackgroundColor.cgColor
        self.descriptionLabel.stringValue = ""
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        self.copyButton.attributedTitle = NSAttributedString(string: "copy".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.copyButton.attributedAlternateTitle = NSAttributedString(string: "copy".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.addressButton.attributedTitle = NSAttributedString(string: "address".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.addressButton.attributedAlternateTitle = NSAttributedString(string: "address".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.shareButton.attributedTitle = NSAttributedString(string: "share".localizedString, attributes: [.foregroundColor: AppController.TextColor, .paragraphStyle: style])
        self.shareButton.attributedAlternateTitle = NSAttributedString(string: "share".localizedString, attributes: [.foregroundColor: AppController.HighlightedTextColor, .paragraphStyle: style])
        self.backButton.alternateImage = self.backButton.image?.tintedImage(tint: AppController.HighlightedTextColor)
    }
    
    override func viewWillAppear() {
        self.titleLabel.stringValue = "\("receive".localizedString) \(self.crytocurrencyType?.name ?? "cryptocurrency")"
        self.addressTypeLabel.stringValue = ""
        self.addressLabel.stringValue = ""
        self.qrCodeImageView.image = NSImage()
        self.addressButton.isHidden = true
        self.copyButton.isHidden = true
        self.shareButton.isHidden = true
        self.copyButton.isHidden = false
        self.shareButton.isHidden = false
        
        /*// Multiple addresses
        guard let format = self.addresses?.keys.first, let address = self.addresses?[format] else {
            return
        }
        self.addressButton.isHidden = (self.addresses?.count == 1)
        self.addressTypeLabel.stringValue = format
        self.addressLabel.stringValue = address
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
        self.addressButton.isHidden = (self.addresses?.count == 1)
        self.addressTypeLabel.stringValue = "address".localizedString
        self.addressLabel.stringValue = address
        
        self.addressLabel.tag = 0
        self.qrCodeImageView.image = (self.crytocurrencyType != nil) ? AppController.shared.generateAddressQRCode(self.crytocurrencyType!, address, self.qrCodeImageView.frame.size) : nil
    }
    
}
