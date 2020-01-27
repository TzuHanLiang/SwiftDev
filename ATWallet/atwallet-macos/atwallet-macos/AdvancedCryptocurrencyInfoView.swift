//
//  AdvancedCryptocurrencyInfoView.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/12/3.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class AdvancedCryptocurrencyInfoView: NSView {
    
    @IBOutlet weak var nickNameTextField: NSTextField!
    @IBOutlet weak var purposeTextField: NSTextField!
    @IBOutlet weak var coinTypeTextField: NSTextField!
    @IBOutlet weak var accountTextField: NSTextField!
    @IBOutlet weak var timestampTexdtField: NSTextField!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.nickNameTextField.wantsLayer = true
        self.nickNameTextField.layer?.cornerRadius = 5
        self.purposeTextField.wantsLayer = true
        self.purposeTextField.layer?.cornerRadius = 5
        self.coinTypeTextField.wantsLayer = true
        self.coinTypeTextField.layer?.cornerRadius = 5
        self.accountTextField.wantsLayer = true
        self.accountTextField.layer?.cornerRadius = 5
        self.timestampTexdtField.wantsLayer = true
        self.timestampTexdtField.layer?.cornerRadius = 5
    }
    
}
