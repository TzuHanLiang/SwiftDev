//
//  SettingsCollectionViewSectionHeader.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/12/2.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class SettingsCollectionViewSectionHeader: NSView {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var separator: NSView!

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
        self.separator.layer?.backgroundColor = AppController.SeparatorColor.cgColor
    }
    
}
