//
//  ATExchangeRates.swift
//  ATWalletKit
//
//  Created by Joshua on 2020/1/10.
//

import Foundation

class ATExchangeRatesImpl: NSObject {
    
    let dispatchQueue: DispatchQueue
    
    init(_ dispatchQueue: DispatchQueue) {
        self.dispatchQueue = dispatchQueue
    }
    
    func currencyToCryptocurrency(_ currencySymbol: String, _ cryptocurrencySymbol: String, _ callback: @escaping (_ rate: Double?) -> ()) {
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    func cryptocurrencyToCurrency(_ cryptocurrencySymbol: String, _ currencySymbol: String, _ callback: @escaping (_ rate: Double?) -> ()) {
        ATLog.debug("\(#function) needs to be implementd")
    }
}

public class ATExchangeRates: NSObject {
    
    public static let currencies = Locale.commonISOCurrencyCodes
    
    private let impl: ATExchangeRatesImpl
    
    public override init() {
        let dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.ATExchangeRates")
        //self.impl = CBExchangeRates(dispatchQueue) // CoinBase
        self.impl = CAExchangeRates(dispatchQueue) // CryptoAPIs
        super.init()
    }
    
    public func currencyToCryptocurrency(_ currencySymbol: String, _ cryptocurrencySymbol: String, _ callback: @escaping (_ rate: Double?) -> ()) {
        self.impl.currencyToCryptocurrency(currencySymbol, cryptocurrencySymbol, callback)
    }
    
    public func cryptocurrencyToCurrency(_ cryptocurrencySymbol: String, _ currencySymbol: String, _ callback: @escaping (_ rate: Double?) -> ()) {
        self.impl.cryptocurrencyToCurrency(cryptocurrencySymbol, currencySymbol, callback)
    }
}
