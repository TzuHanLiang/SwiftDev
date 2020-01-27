//
//  MenuItemTableCellView.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/14.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class MenuItemTableCellView: NSTableCellView {
    
    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var separator: NSView!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.separator.layer?.backgroundColor = AppController.SeparatorColor.cgColor
        self.separator.isHidden = true
    }
    
}
