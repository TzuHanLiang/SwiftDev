//
//  AppConfig.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/5.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Foundation

class AppConfig: NSObject {
    
    private static let instance: AppConfig = AppConfig()
    private let userDefaults: UserDefaults
    private var currencyUnit: ExchangeRate.Currency
    
    public static var shared: AppConfig {
        get { return self.instance }
    }
    
    public var defaultCurrencyUnit: ExchangeRate.Currency {
        get { return self.currencyUnit }
        set {
            self.currencyUnit = newValue
            self.userDefaults.set(newValue, forKey: "currencyUnit")
            self.userDefaults.synchronize()
        }
    }
    
    private override init() {
        self.userDefaults = UserDefaults.standard
        var currencySymbol: ExchangeRate.Currency? = nil
        if self.userDefaults.value(forKey: "currencyUnit") == nil {
            currencySymbol = Locale.current.currencyCode
        }
        self.currencyUnit = currencySymbol ?? "USD"
        super.init()
    }
    
    deinit {
        
    }
    
}
