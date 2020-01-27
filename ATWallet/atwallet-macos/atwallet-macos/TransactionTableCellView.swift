//
//  TransactionTableCellView.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/22.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class TransactionTableCellView: NSTableCellView {
    
    @IBOutlet weak var dateLabel: NSTextField!
    @IBOutlet weak var addressLabel: NSTextField!
    @IBOutlet weak var amountLabel: NSTextField!
    @IBOutlet weak var separator: NSView!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.separator.layer?.backgroundColor = AppController.SeparatorColor.cgColor
    }
    
}
