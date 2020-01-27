//
//  CAExchangeRates.swift
//  ATWalletKit
//
//  Created by Joshua on 2020/1/10.
//

import Foundation
import CoreStore

fileprivate class CSMetaData: CoreStoreObject {
    var assetsCount = Value.Required<Int>("assetsCount", initial: 0)
}

fileprivate class CSAsset: CoreStoreObject {
    var symbol = Value.Required<String>("symbol", initial: "")
    var name = Value.Required<String>("name", initial: "")
    var id = Value.Required<String>("id", initial: "")
    var isCrypto = Value.Required<Bool>("isCrypto", initial: false)
}

fileprivate class CSExchangeRate: CoreStoreObject {
    var baseAssetId = Value.Required<String>("baseAssetId", initial: "")
    var quoteAssetId = Value.Required<String>("quoteAssetId", initial: "")
    var timestamp = Value.Required<Int32>("timestamp", initial: 0)
    var rate = Value.Required<Double>("rate", initial: 0)
}

class CAExchangeRates: ATExchangeRatesImpl {
    
    private static let VALID_TIME: TimeInterval = 60 * 60 // 1 hour
    
    private let API_KEY = ATConstants.CRYPTOAPIS_API_KEY_MARKET_DATA
    
    private let dataStack: DataStack
    private var appUniqueId: String?
    
    override init(_ dispatchQueue: DispatchQueue) {
        self.dataStack = DataStack(CoreStoreSchema(modelVersion: "V1", entities: [Entity<CSMetaData>("CSMetaData"), Entity<CSAsset>("CSAsset"), Entity<CSExchangeRate>("CSExchangeRate")]))
        super.init(dispatchQueue)
        let fileName = "cryptoapis_exchange_rates"
        do {
            try self.dataStack.addStorageAndWait(SQLiteStore(fileName: "\(fileName).sqlite", localStorageOptions: .recreateStoreOnModelMismatch))
        } catch {
            ATLog.error("Failed to add CoreStore storage \(fileName).sqlite")
        }
        if let appUid = UserDefaults.standard.object(forKey: "APP_UID") as? [UInt8], appUid.count == 16 {
            let uuid = UUID(uuid: (appUid[0], appUid[1], appUid[2], appUid[3], appUid[4], appUid[5], appUid[6], appUid[7],
                                   appUid[8], appUid[9], appUid[10], appUid[11], appUid[12], appUid[13], appUid[14], appUid[15]))
            self.appUniqueId = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        }
        self.dispatchQueue.async {
            self.syncAssets()
        }
    }
    
    private func syncAssets() {
        if let csMetaData = try? self.dataStack.fetchOne(From<CSMetaData>()), let csAssets = try? self.dataStack.fetchAll(From<CSAsset>()) {
            guard csMetaData.assetsCount.value > 0, csMetaData.assetsCount.value > csAssets.count else { return }
        }
        let skip = 0
        let limit = 10000
        let urlString = "https://api.cryptoapis.io/v1/assets/meta?skip=\(skip)&limit=\(limit)\((self.appUniqueId != nil) ? "&uid=\(self.appUniqueId!)" : "")"
        guard let url = URL(string: urlString) else {
            ATLog.debug("Failed to create URL: \(urlString)")
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.API_KEY, forHTTPHeaderField: "X-API-Key")
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                ATLog.debug("\(error!)")
                semaphore.signal()
                return
            }
            guard let jsonData = data else {
                ATLog.debug("No data received")
                semaphore.signal()
                return
            }
            ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
            
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
            guard let metaObject = jsonObject?["meta"] as? [String: Any] else {
                semaphore.signal()
                return
            }
            guard let totalCount = metaObject["totalCount"] as? Int else {
                semaphore.signal()
                return
            }
            
            try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                var csMetaData: CSMetaData
                if let item = try? transaction.fetchOne(From<CSMetaData>()) {
                    csMetaData = item
                }
                else {
                    csMetaData = transaction.create(Into<CSMetaData>())
                }
                csMetaData.assetsCount.value = totalCount
            })
            
            guard let assets = jsonObject?["payload"] as? [[String: Any]] else {
                semaphore.signal()
                return
            }
            for asset in assets {
                guard let name = asset["name"] as? String else { continue }
                guard let id = asset["_id"] as? String else { continue }
                guard let isCrypto = asset["cryptoType"] as? Bool else { continue }
                let originalSymbol = asset["originalSymbol"] as? String
                let assetId = asset["originalSymbol"] as? String
                let symbol = originalSymbol ?? assetId ?? name
                try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                    var csAsset: CSAsset
                    if let item = try? transaction.fetchOne(From<CSAsset>().where(\.id == id)) {
                        csAsset = item
                    }
                    else {
                        csAsset = transaction.create(Into<CSAsset>())
                        csAsset.id.value = id
                    }
                    csAsset.symbol.value = symbol
                    csAsset.name.value = name
                    csAsset.isCrypto.value = isCrypto
                })
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
    }
    
    private func queryExchangeRate(_ baseAssetId: String, _ quoteAssetId: String) -> Double? {
        let urlString = "https://api.cryptoapis.io/v1/exchange-rates/\(baseAssetId)/\(quoteAssetId)\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
        guard let url = URL(string: urlString) else {
            ATLog.debug("Failed to create URL: \(urlString)")
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.API_KEY, forHTTPHeaderField: "X-API-Key")
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        var rate: Double?
        let semaphore = DispatchSemaphore(value: 0)
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                ATLog.debug("\(error!)")
                semaphore.signal()
                return
            }
            guard let jsonData = data else {
                ATLog.debug("No data received")
                semaphore.signal()
                return
            }
            ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
            
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
            guard let payload = jsonObject?["payload"] as? [String: Any] else {
                if let metaObject = jsonObject?["meta"] as? [String: Any], let errorObject = metaObject["error"] as? [String: Any], let code = errorObject["code"] as? Int, code == 6000 { // Exchange rate not found for the pair
                    try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                        var csExchangeRate: CSExchangeRate
                        if let item = try? transaction.fetchOne(From<CSExchangeRate>().where(\.baseAssetId == baseAssetId && \.quoteAssetId == quoteAssetId)) {
                            csExchangeRate = item
                        }
                        else {
                            csExchangeRate = transaction.create(Into<CSExchangeRate>())
                            csExchangeRate.baseAssetId.value = baseAssetId
                            csExchangeRate.quoteAssetId.value = quoteAssetId
                        }
                        csExchangeRate.rate.value = -1
                        csExchangeRate.timestamp.value = Int32(bitPattern: UInt32(round(Date().timeIntervalSince1970)))
                    })
                }
                semaphore.signal()
                return
            }
            guard let weightedAveragePrice = payload["weightedAveragePrice"] as? Double else {
                semaphore.signal()
                return
            }
            
            try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                var csExchangeRate: CSExchangeRate
                if let item = try? transaction.fetchOne(From<CSExchangeRate>().where(\.baseAssetId == baseAssetId && \.quoteAssetId == quoteAssetId)) {
                    csExchangeRate = item
                }
                else {
                    csExchangeRate = transaction.create(Into<CSExchangeRate>())
                    csExchangeRate.baseAssetId.value = baseAssetId
                    csExchangeRate.quoteAssetId.value = quoteAssetId
                }
                csExchangeRate.rate.value = weightedAveragePrice
                csExchangeRate.timestamp.value = Int32(bitPattern: UInt32(round(Date().timeIntervalSince1970)))
            })
            rate = weightedAveragePrice
            
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        return rate
    }
    
    private func exchangeRate(_ baseAssetSymbol: String, _ quoteAssetSymbol: String, _ callback: @escaping (_ rate: Double?) -> ()) {
        var baseAssetId: String?
        var quoteAssetId: String?
        if let baseAsset = try? self.dataStack.fetchOne(From<CSAsset>().where(\.symbol == baseAssetSymbol)), let quoteAsset = try? self.dataStack.fetchOne(From<CSAsset>().where(\.symbol == quoteAssetSymbol)) {
            baseAssetId = baseAsset.id.value
            quoteAssetId = quoteAsset.id.value
        }
        else {
            syncAssets()
        }
        guard let baseAsset = try? self.dataStack.fetchOne(From<CSAsset>().where(\.symbol == baseAssetSymbol)), let quoteAsset = try? self.dataStack.fetchOne(From<CSAsset>().where(\.symbol == quoteAssetSymbol)) else {
            DispatchQueue.main.async {
                callback(nil)
            }
            return
        }
        baseAssetId = baseAsset.id.value
        quoteAssetId = quoteAsset.id.value
        guard let csExchangeRate = try? self.dataStack.fetchOne(From<CSExchangeRate>().where(\.baseAssetId == baseAssetId! && \.quoteAssetId == quoteAssetId!)) else {
            callback(queryExchangeRate(baseAssetId!, quoteAssetId!))
            return
        }
        let oldRate = (csExchangeRate.rate.value < 0) ? nil : csExchangeRate.rate.value
        let timestamp = Date(timeIntervalSince1970: TimeInterval(UInt32(bitPattern: csExchangeRate.timestamp.value)))
        guard abs(timestamp.timeIntervalSinceNow) > CAExchangeRates.VALID_TIME else {
            callback(oldRate)
            return
        }
        callback(queryExchangeRate(baseAssetId!, quoteAssetId!) ?? oldRate)
    }
    
    override func currencyToCryptocurrency(_ currencySymbol: String, _ cryptocurrencySymbol: String, _ callback: @escaping (_ rate: Double?) -> ()) {
        self.dispatchQueue.async {
            self.exchangeRate(currencySymbol.uppercased(), cryptocurrencySymbol.uppercased(), callback)
        }
    }
    
    override func cryptocurrencyToCurrency(_ cryptocurrencySymbol: String, _ currencySymbol: String, _ callback: @escaping (_ rate: Double?) -> ()) {
        self.dispatchQueue.async {
            self.exchangeRate(cryptocurrencySymbol.uppercased(), currencySymbol.uppercased(), callback)
        }
    }
    
}
