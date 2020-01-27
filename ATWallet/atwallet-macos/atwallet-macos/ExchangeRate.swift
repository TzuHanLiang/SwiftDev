//
//  ExchangeRate.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/4.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Foundation
import ATWalletKit

class ExchangeRate: NSObject {
    
    typealias Currency = String
    
    enum Exchanges: CaseIterable {
        case coinbase
    }
    
    public static let currencies: [Currency] = Locale.commonISOCurrencyCodes
    
    private let exchange: Exchanges
    
    init(_ exchange: Exchanges) {
        self.exchange = exchange
        super.init()
    }
    
    private func coinbaseExchange(_ currency1: String, _ currency2: String, _ callback: @escaping (_ rate: Double) -> ()) {
        let userDefaults = UserDefaults.standard
        var cacheData = userDefaults.value(forKey: "coinbase\(currency1)ExchangeRates") as? [String: Any]
        let timestamp = cacheData?["timestamp"] as? Date
        let exchangeRates = cacheData?["exchangeRates"] as? [String: Any]
        // cached data is valid in 15 minuts
        if timestamp != nil, exchangeRates != nil, timestamp!.timeIntervalSinceNow > -(15 * 60), let rate = exchangeRates?[currency2] as? String {
            DispatchQueue.main.async {
                callback(Double(rate) ?? 0)
            }
            return
        }
        
        let urlString = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=\(currency1)")
        guard let url = urlString else {
            DispatchQueue.main.async {
                callback(0)
            }
            return
        }
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: url) { (data, response, error) in
            guard error == nil else {
                print(error!)
                DispatchQueue.main.async {
                    callback(0)
                }
                return
            }
            guard let jsonData = data else {
                DispatchQueue.main.async {
                    callback(0)
                }
                return
            }
            
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
            let dataObj = jsonObject?["data"] as? [String: Any]
            let currencyStr = dataObj?["currency"] as? String
            let ratesObj = dataObj?["rates"] as? [String: Any]
            let rateStr = ratesObj?[currency2] as? String
            guard let exchangeRates = ratesObj, let rate = rateStr, currencyStr == currency1  else {
                DispatchQueue.main.async {
                    callback(0)
                }
                return
            }
            cacheData = ["timestamp": Date(), "exchangeRates": exchangeRates]
            userDefaults.set(cacheData, forKey: "coinbase\(currency1)ExchangeRates")
            DispatchQueue.main.async {
                callback(Double(rate) ?? 0)
            }
            userDefaults.synchronize()
        }
        task.resume()
    }
    
    func currencyToCryptocurrency(_ currency: Currency, _ cryptocurrency: ATCryptocurrencyType, _ callback: @escaping (_ rate: Double) -> ()) {
        switch self.exchange {
        case .coinbase:
            return coinbaseExchange(currency.description, cryptocurrency.symbol, callback)
        }
    }
    
    func cryptocurrencyToCurrency(_ cryptocurrency: ATCryptocurrencyType, _ currency: Currency, _ callback: @escaping (_ rate: Double) -> ()) {
        switch self.exchange {
        case .coinbase:
            return coinbaseExchange(cryptocurrency.symbol, currency.description, callback)
        }
    }
    
}

