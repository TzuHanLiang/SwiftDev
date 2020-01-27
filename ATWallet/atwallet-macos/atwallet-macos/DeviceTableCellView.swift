//
//  DeviceTableCellView.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/11/14.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class DeviceTableCellView: NSTableCellView {
    
    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var signalLabel: NSTextField!
    @IBOutlet weak var typeImageView: NSImageView!
    @IBOutlet weak var separator: NSView!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.separator.layer?.backgroundColor = AppController.SeparatorColor.cgColor
    }
        
}
