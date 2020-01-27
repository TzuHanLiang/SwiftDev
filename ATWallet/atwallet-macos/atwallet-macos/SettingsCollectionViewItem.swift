//
//  SettingsCollectionViewItem.swift
//  atwallet-macos
//
//  Created by Joshua on 2019/12/2.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Cocoa

class SettingsCollectionViewItem: NSCollectionViewItem {
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var iconImageView: NSImageView!
    
    var isHighlightable: Bool = true
    
    private var originalIconImage: NSImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 8
    }
    
    override func mouseUp(with event: NSEvent) {
        setHighlight(false)
        super.mouseUp(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        setHighlight(true)
        super.mouseDown(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        setHighlight(false)
        super.mouseExited(with: event)
    }
    
    func setHighlight(_ highlighted: Bool) {
        guard self.isHighlightable else { return }
        self.view.layer?.backgroundColor = highlighted ? AppController.HighlightedTextColor.cgColor : AppController.BackgroundColor.cgColor
    }
    
}
