//
//  CryptocurrencyTableCellView.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class CryptocurrencyTableCellView: NSTableCellView {
    
    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var exchangeRateLabel: NSTextField!
    @IBOutlet weak var currencyAmountLabel: NSTextField!
    @IBOutlet weak var cryptocurrencyAmountLabel: NSTextField!
    @IBOutlet weak var separator: NSView!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.separator.layer?.backgroundColor = AppController.SeparatorColor.cgColor
    }
    
}
