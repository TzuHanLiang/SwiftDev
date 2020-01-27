//
//  RecoveryTableCellView.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class RecoveryGroupHeaderTableCellView: NSTableCellView {
    
    @IBOutlet weak var titleTextField: NSTextField!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}

class RecoveryMainTableCellView: NSTableCellView {
    
    @IBOutlet weak var coinTypePopUpButton: NSPopUpButton!
    @IBOutlet weak var expansionButton: NSButton!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}

class RecoveryFullTableCellView: NSTableCellView {
    
    @IBOutlet weak var coinTypePopUpButton: NSPopUpButton!
    @IBOutlet weak var nicknameTextField: NSTextField!
    @IBOutlet weak var yearPupUpButton: NSPopUpButton!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.nicknameTextField.wantsLayer = true
        self.nicknameTextField.layer?.cornerRadius = 5
    }
    
}

class RecoveryPathTableCellView: NSTableCellView {
    
    @IBOutlet weak var purposeTextField: NSTextField!
    @IBOutlet weak var coinTypeTextField: NSTextField!
    @IBOutlet weak var accountTextField: NSTextField!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.purposeTextField.wantsLayer = true
        self.purposeTextField.layer?.cornerRadius = 5
        self.coinTypeTextField.wantsLayer = true
        self.coinTypeTextField.layer?.cornerRadius = 5
        self.accountTextField.wantsLayer = true
        self.accountTextField.layer?.cornerRadius = 5
    }
    
}
