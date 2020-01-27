//
//  ObjectObserverDemoViewController.swift
//  CoreStoreDemo
//
//  Created by John Rommel Estropia on 2015/05/06.
//  Copyright © 2018 John Rommel Estropia. All rights reserved.
//

import UIKit
import CoreStore


// MARK: - ObjectObserverDemoViewController

class ObjectObserverDemoViewController: UIViewController, ObjectObserver {
    
    func setPalette<O: ObjectRepresentation>(_ newValue: O?) where O.ObjectType == Palette {
        
        guard self.monitor?.object?.objectID() != newValue?.objectID() else {
            
            return
        }
        if let newValue = newValue {
            
            self.monitor = newValue.asReadOnly(in: ColorsDemo.stack).map(ColorsDemo.stack.monitorObject(_:))
        }
        else {
            
            self.monitor = nil
        }
    }
    
    
    // MARK: NSObject
    
    deinit {
        
        self.monitor?.removeObserver(self)
    }
    

    // MARK: UIViewController
    
    required init?(coder aDecoder: NSCoder) {
        
        if let palette = try! ColorsDemo.stack.fetchOne(From<Palette>().orderBy(.ascending(\.hue))) {
            
            self.monitor = ColorsDemo.stack.monitorObject(palette)
        }
        else {
            
            _ = try? ColorsDemo.stack.perform(
                synchronous: { (transaction) in
                    
                    let palette = transaction.create(Into<Palette>())
                    palette.setInitialValues(in: transaction)
                }
            )
            
            let palette = try! ColorsDemo.stack.fetchOne(From<Palette>().orderBy(.ascending(\.hue)))!
            self.monitor = ColorsDemo.stack.monitorObject(palette)
        }
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.monitor?.addObserver(self)
        
        if let palette = self.monitor?.object {
            
            self.reloadPaletteInfo(palette, changedKeys: nil)
        }
    }
    
    
    // MARK: ObjectObserver
    
    func objectMonitor(_ monitor: ObjectMonitor<Palette>, didUpdateObject object: Palette, changedPersistentKeys: Set<KeyPathString>) {
        
        self.reloadPaletteInfo(object, changedKeys: changedPersistentKeys)
    }
    
    func objectMonitor(_ monitor: ObjectMonitor<Palette>, didDeleteObject object: Palette) {
        
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        self.colorNameLabel?.alpha = 0.3
        self.colorView?.alpha = 0.3
        
        self.hsbLabel?.text = "Deleted"
        self.hsbLabel?.textColor = UIColor.red
        
        self.hueSlider?.isEnabled = false
        self.saturationSlider?.isEnabled = false
        self.brightnessSlider?.isEnabled = false
    }

    
    // MARK: Private
    
    var monitor: ObjectMonitor<Palette>?
    
    @IBOutlet weak var colorNameLabel: UILabel?
    @IBOutlet weak var colorView: UIView?
    @IBOutlet weak var hsbLabel: UILabel?
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var hueSlider: UISlider?
    @IBOutlet weak var saturationSlider: UISlider?
    @IBOutlet weak var brightnessSlider: UISlider?
    
    @IBAction dynamic func hueSliderValueDidChange(_ sender: AnyObject?) {
        
        let hue = self.hueSlider?.value ?? 0
        ColorsDemo.stack.perform(
            asynchronous: { [weak self] (transaction) in
                
                if let palette = transaction.edit(self?.monitor?.object) {
                    
                    palette.hue .= Int(hue)
                }
            },
            completion: { _ in }
        )
    }
    
    @IBAction dynamic func saturationSliderValueDidChange(_ sender: AnyObject?) {
        
        let saturation = self.saturationSlider?.value ?? 0
        ColorsDemo.stack.perform(
            asynchronous: { [weak self] (transaction) in
                
                if let palette = transaction.edit(self?.monitor?.object) {
                    
                    palette.saturation .= saturation
                }
            },
            completion: { _ in }
        )
    }
    
    @IBAction dynamic func brightnessSliderValueDidChange(_ sender: AnyObject?) {
        
        let brightness = self.brightnessSlider?.value ?? 0
        ColorsDemo.stack.perform(
            asynchronous: { [weak self] (transaction) in
                
                if let palette = transaction.edit(self?.monitor?.object) {
                    
                    palette.brightness .= brightness
                }
            },
            completion: { _ in }
        )
    }
    
    @IBAction dynamic func deleteBarButtonTapped(_ sender: AnyObject?) {
        
        ColorsDemo.stack.perform(
            asynchronous: { [weak self] (transaction) in
                
                transaction.delete(self?.monitor?.object)
            },
            completion: { _ in }
        )
    }
    
    func reloadPaletteInfo(_ palette: Palette, changedKeys: Set<String>?) {
        
        self.colorNameLabel?.text = palette.colorName.value
        
        let color = palette.color
        self.colorNameLabel?.textColor = color
        self.colorView?.backgroundColor = color
        
        self.hsbLabel?.text = palette.colorText
        
        if changedKeys == nil || changedKeys?.contains(String(keyPath: \Palette.hue)) == true {
            
            self.hueSlider?.value = Float(palette.hue.value)
        }
        if changedKeys == nil || changedKeys?.contains(String(keyPath: \Palette.saturation)) == true {
            
            self.saturationSlider?.value = palette.saturation.value
        }
        if changedKeys == nil || changedKeys?.contains(String(keyPath: \Palette.brightness)) == true {
            
            self.brightnessSlider?.value = palette.brightness.value
        }
    }
}
