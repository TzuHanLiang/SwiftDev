//
//  CABitcoinBasedWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/10/25.
//

import Foundation
import CoreStore
import BRCore

fileprivate let ONE_BTC_SATOSHI: Double = 100000000
fileprivate let ONE_SATOSHI_BTC: Double = 0.00000001

func SatoshiToBitcoin(_ satoshi: UInt64) -> Double {
    return Double(satoshi) / ONE_BTC_SATOSHI // 1 BTC == 100,000,000 satoshi
}

func BitcoinToSatoshi(_ btc: Double) -> UInt64 {
    return UInt64((btc * ONE_BTC_SATOSHI).rounded())
}

fileprivate class CSTransaction: CoreStoreObject {
    var txid = Value.Required<String>("txid", initial: "")
    var locktime = Value.Required<Int32>("locktime", initial: 0)
    var timestamp = Value.Required<Int32>("timestamp", initial: 0)
    var confirmations = Value.Required<Int32>("confirmations", initial: 0)
    var jsonData = Value.Required<Data>("jsonData", initial: Data())
    var direction = Value.Required<Int>("direction", initial: 0)
    var sourceAddresses = Value.Required<String>("sourceAddresses", initial: "")
    var destinationAddresses = Value.Required<String>("destinationAddresses", initial: "")
    var amount = Value.Required<Double>("amount", initial: 0)
    var fee = Value.Required<Double>("fee", initial: 0)
    var note = Value.Required<String>("note", initial: "")
}

fileprivate class CSUnspentTxOut: CoreStoreObject {
    var txid = Value.Required<String>("txid", initial: "")
    var vout = Value.Required<Int32>("vout", initial: 0)
    var type = Value.Required<String>("type", initial: "")
    var address = Value.Required<String>("address", initial: "")
    var amount = Value.Required<Double>("amount", initial: 0)
    var chainIndex = Value.Required<Int32>("chainIndex", initial: 0)
    var keyIndex = Value.Required<Int32>("keyIndex", initial: 0)
    var script = Value.Required<Data>("script", initial: Data())
    var locked = Value.Required<Bool>("locked", initial: false)
}

fileprivate class CSMetadata: CoreStoreObject {
    var numberOfUsedExternalPubKey = Value.Required<Int32>("numberOfUsedExternalPubKey", initial: 0)
    var numberOfUsedInternalPubKey = Value.Required<Int32>("numberOfUsedInternalPubKey", initial: 0)
    var lastSyncTime = Value.Required<Int32>("lastSyncTime", initial: 0)
    var lastFullSyncTime = Value.Required<Int32>("lastFllSyncTime", initial: 0)
}

fileprivate extension ATCryptocurrencyTransaction {
    convenience init(_ transaction: CSTransaction, _ currency: ATCryptocurrencyType) {
        var direction: TransactionDirection = .sent
        switch transaction.direction.value {
        case TransactionDirection.sent.rawValue:
            direction = TransactionDirection.sent
        case TransactionDirection.received.rawValue:
            direction = TransactionDirection.received
        case TransactionDirection.moved.rawValue:
            direction = TransactionDirection.moved
        default:
            ATLog.error("impossible case")
            break
        }
        
        self.init(currency, direction, nil)
        
        switch direction {
        case .sent:
            self.address = transaction.destinationAddresses.value
            self.amount = ATUInt256(BitcoinToSatoshi(transaction.amount.value))
            self.amountString = transaction.amount.value.toString(8)
            self.fee = ATUInt256(BitcoinToSatoshi(transaction.fee.value))
            self.feeString = transaction.fee.value.toString(8)
            self.totalAmount = self.amount + self.fee
            self.totalAmountString = (transaction.amount.value + transaction.fee.value).toString(8)
        case .received:
            self.address = transaction.sourceAddresses.value
            self.amount = ATUInt256(BitcoinToSatoshi(transaction.amount.value))
            self.amountString = transaction.amount.value.toString(8)
            self.totalAmount = self.amount
            self.totalAmountString = self.amountString
        case .moved:
            self.fee = ATUInt256(BitcoinToSatoshi(transaction.fee.value))
            self.feeString = transaction.fee.value.toString(8)
        }
        
        self.date = Date(timeIntervalSince1970: TimeInterval(UInt32(bitPattern: transaction.timestamp.value)))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
        self.message = transaction.note.value
        
        self.detailDescription = """
        \(NSLocalizedString("date", tableName: nil, bundle: Bundle.main, value: "Date", comment: ""))
        \(dateFormatter.string(from: self.date))
        
        \(self.direction.description)
        \(self.amountString) \(self.currency.symbol)
        """
        
        (self.direction != .moved) ? self.detailDescription.append("""
        \n\n\(NSLocalizedString((self.direction == .sent) ? "to" : "from", tableName: nil, bundle: Bundle.main, value: (self.direction == .sent) ? "To" : "From", comment: "")) \(self.address)
        """) : nil
        
        (self.fee > 0) ? self.detailDescription.append("""
        \n\n\(NSLocalizedString("fee", tableName: nil, bundle: Bundle.main, value: "Fee", comment: ""))
        \(self.feeString) \(self.currency.symbol)
        """) : nil
        
        (self.message.count > 0) ? self.detailDescription.append("""
        \n\n\(NSLocalizedString("note", tableName: nil, bundle: Bundle.main, value: "Note", comment: ""))
        \(self.message)
        """): nil
        
        self.detailDescription.append("""
        \n\n\(NSLocalizedString("transaction_id", tableName: nil, bundle: Bundle.main, value: "Transaction ID", comment: ""))
        \(transaction.txid.value)
        """)
        
        (transaction.confirmations.value == 0) ? self.detailDescription.append("""
        \n\n\(NSLocalizedString("unconfirmed", tableName: nil, bundle: Bundle.main, value: "Unconfirmed", comment: ""))
        """) : nil
    }
    
    convenience init(_ outputAddress: String, _ outputAmount: Double, _ fee: Double, _ currency: ATCryptocurrencyType, _ object: AnyObject, _ message: String? = nil) {
        self.init(currency, .sent, object)
        self.address = outputAddress
        self.amount = ATUInt256(BitcoinToSatoshi(outputAmount))
        self.amountString = outputAmount.toString(8)
        self.fee = ATUInt256(BitcoinToSatoshi(fee))
        self.feeString = fee.toString(8)
        self.totalAmount = self.amount + self.fee
        self.totalAmountString = (outputAmount + fee).toString(8)
        self.message = message ?? ""
    }
}

class CABitcoinBasedWallet: ATAbstractWallet {
    
    enum Chain: UInt32 {
        case externalChain = 0
        case internalChain = 1
    }
    enum TxType: String {
        case pubkeyhash = "pubkeyhash"
        case scripthash = "scripthash"
        case witness_v0_keyhash = "witness_v0_keyhash"
    }
    #if TESTNET
    private static let network = "testnet"
    #else
    private static let network = "mainnet"
    #endif
    internal var GAP_LIMIT: UInt32 = 3 // Standard is 20
    internal var AVERAGE_CONFIRMATION_TIME: TimeInterval = 2.5 * 60 // 2.5 minutes in seconds
    internal var FULL_SYNC_INTERVAL: TimeInterval = 8 * 60 * 60 // 8 hours in second
    internal var PARTIAL_SYNC_INTERVAL: TimeInterval = 5 * 60 // 5 minutes in second
    internal var CRYPTOCURRENCY_TYPE: ATCryptocurrencyType = ATCryptocurrencyType.btc
    internal var API_KEY: String = ATConstants.CRYPTOAPIS_API_KEY_BITCOIN
    internal var MIN_FEE_PER_BYTE: UInt64 = 1
    internal var LOW_FEE_PER_BYTE: UInt64 = 10
    internal var MEDIUM_FEE_PER_BYTE: UInt64 = 20
    internal var HIGH_FEE_PER_BYTE: UInt64 = 40
    
    private let uid: [UInt8]
    private let extendedPublicKey: BRMasterPubKey
    private let isSegWitAccount: Bool
    private let dataStack: DataStack
    private let dispatchQueue: DispatchQueue
    private var transactions: [ATCryptocurrencyTransaction] = []
    private var numberOfUsedExternalPubKey: UInt32 = 0
    private var numberOfUsedInternalPubKey: UInt32 = 0
    private var lastSyncTime = Date(timeIntervalSince1970: 0)
    private var lastFullSyncTime = Date(timeIntervalSince1970: 0)
    private var isSyncing = false
    private var balance: Double = 0 // Unit: BTC
    private var syncTimer: Timer?
    private var appUniqueId: String?
    
    private var isFullSyncNeeded: Bool {
        var needed = false
        (self.lastSyncTime.timeIntervalSince1970 == TimeInterval(0)) ? (needed = true) : nil
        (abs(self.lastFullSyncTime.timeIntervalSinceNow) > self.FULL_SYNC_INTERVAL) ? (needed = true) : nil
        return needed
    }
    
    private var isPartialSyncNeeded: Bool {
        var needed = false
        (self.lastSyncTime.timeIntervalSince1970 == TimeInterval(0)) ? (needed = true) : nil
        (abs(self.lastSyncTime.timeIntervalSinceNow) > self.PARTIAL_SYNC_INTERVAL) ? (needed = true) : nil
        return needed
    }
    
    init?(UniqueId uid: [UInt8], EarlistKeyTime timestamp: UInt32, PublicKey pubKey: [UInt8], ChainCode chainCode: [UInt8], FingerprintOfParentKey fingerprint: UInt32, Delegate delegate: ATAbstractWalletDelegate, SegWitAccount segwit: Bool = false) {
        guard (pubKey.count == 33 || pubKey.count == 65) && chainCode.count == 32 else {
            ATLog.debug("Invalid public key or chain code")
            return nil
        }
        var compressedPubKey: [UInt8] = []
        if pubKey[0] == 0x04 {
            compressedPubKey.append((pubKey.last! & 0x01) > 0 ? 0x03 : 0x02)
            compressedPubKey.append(contentsOf: pubKey[1..<33])
        }
        else if pubKey[0] == 0x03 || pubKey[0] == 0x02 {
            compressedPubKey = pubKey
        }
        else {
            ATLog.debug("Invalid public key")
            return nil
        }
        
        self.extendedPublicKey = BRMasterPubKey(fingerPrint: fingerprint, chainCode: UInt256(bytes: chainCode), pubKey: (compressedPubKey[0], compressedPubKey[1], compressedPubKey[2], compressedPubKey[3], compressedPubKey[4], compressedPubKey[5], compressedPubKey[6], compressedPubKey[7], compressedPubKey[8], compressedPubKey[9], compressedPubKey[10], compressedPubKey[11], compressedPubKey[12], compressedPubKey[13], compressedPubKey[14], compressedPubKey[15], compressedPubKey[16], compressedPubKey[17], compressedPubKey[18], compressedPubKey[19], compressedPubKey[20], compressedPubKey[21], compressedPubKey[22], compressedPubKey[23], compressedPubKey[24], compressedPubKey[25], compressedPubKey[26], compressedPubKey[27], compressedPubKey[28], compressedPubKey[29], compressedPubKey[30], compressedPubKey[31], compressedPubKey[32]))
        
        self.uid = uid
        self.dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.CABitcoinBasedWallet.\(Data(uid).toHexString())")
        self.dataStack = DataStack(CoreStoreSchema(modelVersion: "V1", entities: [Entity<CSMetadata>("CSMetadata"), Entity<CSTransaction>("CSTransaction"), Entity<CSUnspentTxOut>("CSUnspentTxOut")]))
        
        self.isSegWitAccount = segwit
        
        super.init(Delegate: delegate)
        
        let fileName = self.uid.withUnsafeBufferPointer { (pointer: UnsafeBufferPointer<UInt8>) -> String in
            return pointer.map{String(format: "CA\(self.CRYPTOCURRENCY_TYPE.symbol)%02hhx", $0)}.reduce("", {$0 + $1})
        }
        do {
            try self.dataStack.addStorageAndWait(SQLiteStore(fileName: "\(fileName).sqlite", localStorageOptions: .recreateStoreOnModelMismatch))
        } catch {
            ATLog.error("Failed to add CoreStore storage \(fileName).sqlite")
            return nil
        }
        
        if let metadata = try? self.dataStack.fetchOne(From<CSMetadata>()) {
            self.numberOfUsedExternalPubKey = UInt32(bitPattern: metadata.numberOfUsedExternalPubKey.value)
            self.numberOfUsedInternalPubKey = UInt32(bitPattern: metadata.numberOfUsedInternalPubKey.value)
            self.lastSyncTime = Date(timeIntervalSince1970: TimeInterval(UInt32(bitPattern: metadata.lastSyncTime.value)))
            self.lastFullSyncTime = Date(timeIntervalSince1970: TimeInterval(UInt32(bitPattern: metadata.lastFullSyncTime.value)))
        }
        loadUnspentTxOut()
        loadTransactions()
        
        if let appUid = UserDefaults.standard.object(forKey: "APP_UID") as? [UInt8], appUid.count == 16 {
            let uuid = UUID(uuid: (appUid[0], appUid[1], appUid[2], appUid[3], appUid[4], appUid[5], appUid[6], appUid[7],
                                   appUid[8], appUid[9], appUid[10], appUid[11], appUid[12], appUid[13], appUid[14], appUid[15]))
            self.appUniqueId = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        }
    }
    
    func loadTransactions() {
        self.dataStack.perform(asynchronous: { (transaction) -> Void in
            guard let transactions = try? transaction.fetchAll(From<CSTransaction>().orderBy(.descending(\.timestamp))), transactions.count > 0 else { return }
            var txRecords: [ATCryptocurrencyTransaction] = []
            for cstx in transactions {
                txRecords.append(ATCryptocurrencyTransaction(cstx, self.CRYPTOCURRENCY_TYPE))
            }
            self.transactions = txRecords
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidUpdateTransaction()
            }
        }, completion: { _ in })
    }
    
    func loadUnspentTxOut() {
        self.dataStack.perform(asynchronous: { (transaction) -> Void in
            guard let utxos = try? transaction.fetchAll(From<CSUnspentTxOut>()), utxos.count > 0 else { return }
            var balance: Double = 0
            for utxo in utxos {
                balance += utxo.amount.value
            }
            self.balance = balance
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidUpdateTransaction()
            }
        }, completion: { _ in })
    }
    
    func parseTransaction(_ tx: [String: Any], _ address: String, _ isChange: Bool, _ keyIndex: UInt32) {
        guard let txid = tx["txid"] as? String else {
            ATLog.debug("txid not found")
            return
        }
        guard let locktime = tx["locktime"] as? Int32 else {
            ATLog.debug("locktime not found")
            return
        }
        guard let timestamp = tx["timestamp"] as? Int32 else {
            ATLog.debug("timestamp not found")
            return
        }
        guard let confirmations = tx["confirmations"] as? Int32 else {
            ATLog.debug("confirmatoins not found")
            return
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: tx, options: .fragmentsAllowed) else {
            ATLog.debug("Failed to convert JSON object to JSON data")
            return
        }
        guard let txins = tx["txins"] as? [[String: Any]] else {
            ATLog.debug("txins not found")
            return
        }
        guard let txouts = tx["txouts"] as? [[String: Any]] else {
            ATLog.debug("txins not found")
            return
        }
        
        var txDirection: ATCryptocurrencyTransaction.TransactionDirection?
        var txinsAmount: Double = 0
        var sourceAddresses: [String] = []
        var txinRecords: [(String, Int)] = []
        for txin in txins {
            guard let txid = txin["txout"] as? String, let vout = txin["vout"] as? Int else { continue }
            txinRecords.append((txid, vout))
            let amount = Double(txin["amount"] as? String ?? "0") ?? 0
            txinsAmount += amount
            guard let addresses = txin["addresses"] as? [String] else { continue }
            sourceAddresses.append(contentsOf: addresses)
            if addresses.contains(address) {
                txDirection = .sent
            }
        }
        var txoutsAmount: Double = 0
        var receivedAmount: Double = 0
        var destinationAddresses: [String] = []
        var spent = false
        var type = ""
        var vout = 0
        var script = Data()
        var note: String? = nil
        for index in 0..<txouts.count {
            let txout = txouts[index]
            let amount = Double(txout["amount"] as? String ?? "0") ?? 0
            txoutsAmount += amount
            if amount == 0, let scriptObject = txout["script"] as? [String: Any], let hex = scriptObject["hex"] as? String {
                // Note
                let data = Data(hex: hex)
                if data.first == 0x6A { // OP_RETURN
                    note = String(data: data.subdata(in: 2..<data.count), encoding: .utf8)
                }
            }
            guard let addresses = txout["addresses"] as? [String] else { continue }
            destinationAddresses.append(contentsOf: addresses)
            if addresses.contains(address) {
                if addresses.count > 1 {
                    // Multisig is not supported
                }
                txDirection = .received
                receivedAmount = amount
                spent = txout["spent"] as? Bool ?? false
                type = txout["type"] as? String ?? ""
                vout = index
                if let scriptObject = txout["script"] as? [String: Any], let hex = scriptObject["hex"] as? String {
                    script = Data(hex: hex)
                }
            }
        }
        let fee = txinsAmount - txoutsAmount
        
        guard txDirection != nil else {
            ATLog.debug("Address not found")
            return
        }
        
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            if !spent && txDirection == .received {
                var csutxo: CSUnspentTxOut
                if let item = try? transaction.fetchOne(From<CSUnspentTxOut>().where(\.txid == txid)) {
                    csutxo = item
                }
                else {
                    csutxo = transaction.create(Into<CSUnspentTxOut>())
                    self.balance += receivedAmount
                }
                csutxo.txid.value = txid
                csutxo.type.value = type
                csutxo.vout.value = Int32(vout)
                csutxo.address.value = address
                csutxo.amount.value = receivedAmount
                csutxo.chainIndex.value = Int32(bitPattern: isChange ? Chain.internalChain.rawValue : Chain.externalChain.rawValue)
                csutxo.keyIndex.value = Int32(bitPattern: keyIndex)
                csutxo.script.value = script
            }
            
            for txinRecord in txinRecords {
                if let utxo = try? transaction.fetchOne(From<CSUnspentTxOut>().where(\.txid == txinRecord.0 && \.vout == Int32(txinRecord.1))) {
                    self.balance -= utxo.amount.value
                    transaction.delete(utxo)
                }
            }
            DispatchQueue.main.async() {
                self.delegate?.abstractWalletDidUpdateBalance(self.getBalance())
            }
            
            var cstx: CSTransaction
            if let item = try? transaction.fetchOne(From<CSTransaction>().where(\.txid == txid)) {
                cstx = item
            }
            else {
                cstx = transaction.create(Into<CSTransaction>())
            }
            cstx.txid.value = txid
            cstx.locktime.value = locktime
            cstx.timestamp.value = timestamp
            cstx.confirmations.value = confirmations
            cstx.jsonData.value = jsonData
            cstx.fee.value = fee
            cstx.note.value = note ?? ""
            
            var sAddr = ""
            for addr in sourceAddresses {
                sAddr.append(contentsOf: (sAddr.count > 0) ? ",\(addr)" : addr)
            }
            cstx.sourceAddresses.value = sAddr
            
            if isChange, txDirection == .received {
                cstx.direction.value = ATCryptocurrencyTransaction.TransactionDirection.sent.rawValue
                cstx.amount.value = txinsAmount - receivedAmount - fee
                if let index = destinationAddresses.firstIndex(of: address) {
                    destinationAddresses.remove(at: index)
                }
                var dAddr = ""
                for addr in destinationAddresses {
                    dAddr.append(contentsOf: (dAddr.count > 0) ? ",\(addr)" : addr)
                }
                cstx.destinationAddresses.value = dAddr
                if dAddr.count == 0 { // moved
                    cstx.direction.value = ATCryptocurrencyTransaction.TransactionDirection.moved.rawValue
                    cstx.amount.value = receivedAmount
                }
            }
            else if txDirection == .received {
                cstx.direction.value = txDirection!.rawValue
                cstx.amount.value = receivedAmount
                cstx.destinationAddresses.value = address
            } else {
                cstx.direction.value = txDirection!.rawValue
                (cstx.amount.value == 0) ? (cstx.amount.value = txinsAmount - fee) : nil
                if cstx.destinationAddresses.value.count == 0 {
                    var dAddr = ""
                    for addr in destinationAddresses {
                        dAddr.append(contentsOf: (dAddr.count > 0) ? ",\(addr)" : addr)
                    }
                    cstx.destinationAddresses.value = dAddr
                }
            }
        })
    }
    
    func syncTransactions(_ chain: Chain, _ startIndex: UInt32, _ gapLimit: UInt32) {
        let semaphore = DispatchSemaphore(value: 0)
        let retryLimit = 3
        var retryCount = 0
        var keyIndex = startIndex
        var txIndex = 0
        var gapCount = 0
        var errorOccured = false
        var numberOfUsedExternalPubKey: UInt32 = (chain == .externalChain) ? startIndex : 0
        var numberOfUsedInternalPubKey: UInt32 = (chain == .internalChain) ? startIndex : 0
        while gapCount < gapLimit && !errorOccured {
            let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(chain.rawValue, keyIndex))
            var addresses: [String] = []
            if self.CRYPTOCURRENCY_TYPE == .bch {
                let p2pkhAddress = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
                addresses.append(pubkey.pubkeyToP2PKHCashAddress() ?? p2pkhAddress)
            }
            else if self.isSegWitAccount {
                guard let p2wpkhAddress = pubkey.pubkeyToP2WPKHAddress(self.CRYPTOCURRENCY_TYPE) else {
                    ATLog.debug("Failed to generate P2WPKH address")
                    return
                }
                addresses.append(p2wpkhAddress)
            }
            else {
                let p2pkhAddress = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
                addresses.append(p2pkhAddress)
            }
            
            var addressIndex = 0
            var txNotFoundCount = 0
            var totalTxCount = 0
            while addressIndex < addresses.count && !errorOccured {
                let address = addresses[addressIndex]
                var syncedTxCount = 0
                if let csTxs = try? self.dataStack.fetchAll(From<CSTransaction>()) {
                    for csTx in csTxs {
                        guard csTx.sourceAddresses.value.contains(address) || csTx.destinationAddresses.value.contains(address) else { continue }
                        guard csTx.confirmations.value > 0 else { continue }
                        syncedTxCount += 1
                    }
                }
                if totalTxCount > 0, syncedTxCount >= totalTxCount {
                    (syncedTxCount > totalTxCount) ? ATLog.warning("This should not happen!") : nil
                    txIndex = 0
                    totalTxCount = 0
                    addressIndex += 1
                    semaphore.signal()
                    return
                }
                
                let maxTxNumber = 50
                let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(CABitcoinBasedWallet.network)/address/\((self.CRYPTOCURRENCY_TYPE == .bch) ? address.removeCashAddressPrefix() : address)/transactions?index=\(txIndex)&limit=\(maxTxNumber)\((self.appUniqueId != nil) ? "&uid=\(self.appUniqueId!)" : "")"
                guard let url = URL(string: urlString) else {
                    ATLog.debug("Failed to create URL: \(urlString)")
                    break
                }
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(self.API_KEY, forHTTPHeaderField: "X-API-Key")
                let config = URLSessionConfiguration.default
                config.requestCachePolicy = .reloadIgnoringLocalCacheData
                config.urlCache = nil
                let session = URLSession(configuration: config)
                let task = session.dataTask(with: request) { (data, response, error) in
                    guard error == nil else {
                        ATLog.debug("\(error!)")
                        errorOccured = (retryCount >= retryLimit)
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    guard let jsonData = data else {
                        ATLog.debug("No data received")
                        errorOccured = (retryCount >= retryLimit)
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                    
                    let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                    let metaObject = jsonObject?["meta"] as? [String: Any]
                    
                    if let errorObjet = metaObject?["error"] as? [String: Any] {
                        let code = errorObjet["code"] as? Int
                        if code == 63 { // request limit reached
                            sleep(arc4random() % 10 + 1)
                            semaphore.signal()
                            return
                        }
                        else {
                            errorOccured = (retryCount >= retryLimit)
                            retryCount += 1
                            semaphore.signal()
                            return
                        }
                    }

                    guard let results = metaObject?["results"] as? Int else {
                        errorOccured = (retryCount >= retryLimit)
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    
                    guard let totalCount = metaObject?["totalCount"] as? Int else {
                        errorOccured = (retryCount >= retryLimit)
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    (totalTxCount == 0) ? totalTxCount = totalCount : nil
                    
                    retryCount = 0
                    
                    try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                        var metadata: CSMetadata
                        if let item = try? transaction.fetchOne(From<CSMetadata>()) {
                            metadata = item
                        }
                        else {
                            metadata = transaction.create(Into<CSMetadata>())
                        }
                        let timestamp = UInt32(round(Date().timeIntervalSince1970))
                        metadata.lastSyncTime.value = Int32(bitPattern: timestamp)
                    })
                                        
                    guard results > 0 else {
                        (txIndex == 0) ? (txNotFoundCount += 1) : nil
                        txIndex = 0
                        totalTxCount = 0
                        addressIndex += 1
                        semaphore.signal()
                        return
                    }
                                        
                    let payloadObject = jsonObject?["payload"] as? [[String: Any]]
                    for tx in payloadObject ?? [] {
                        self.parseTransaction(tx, address, chain == .internalChain, keyIndex)
                    }
                    
                    guard syncedTxCount < totalTxCount else {
                        txIndex = 0
                        totalTxCount = 0
                        addressIndex += 1
                        semaphore.signal()
                        return
                    }
                    
                    if results == maxTxNumber {
                        txIndex += results
                    }
                    else {
                        txIndex = 0
                        totalTxCount = 0
                        addressIndex += 1
                    }
                    semaphore.signal()
                }
                task.resume()
                semaphore.wait()
            }
            if txNotFoundCount == 0 {
                (chain == .externalChain) ? (numberOfUsedExternalPubKey = keyIndex + 1) : (numberOfUsedInternalPubKey = keyIndex + 1)
            }
            keyIndex += 1
            gapCount = (txNotFoundCount == addresses.count) ? (gapCount + 1) : 0
        }
        
        if chain == .externalChain {
            guard !errorOccured || numberOfUsedExternalPubKey > self.numberOfUsedExternalPubKey else { return }
            self.numberOfUsedExternalPubKey = numberOfUsedExternalPubKey
        }
        else {
            guard !errorOccured || numberOfUsedInternalPubKey > self.numberOfUsedInternalPubKey else { return }
            self.numberOfUsedInternalPubKey = numberOfUsedInternalPubKey
        }
        
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            var metadata: CSMetadata
            if let item = try? transaction.fetchOne(From<CSMetadata>()) {
                metadata = item
            }
            else {
                metadata = transaction.create(Into<CSMetadata>())
            }
            if chain == .externalChain {
                metadata.numberOfUsedExternalPubKey.value = Int32(bitPattern: self.numberOfUsedExternalPubKey)
            }
            else {
                metadata.numberOfUsedInternalPubKey.value = Int32(bitPattern: self.numberOfUsedInternalPubKey)
            }
        })
    }
    
    func syncTransaction(_ txid: String, _ untilConfirmed: Bool) -> Bool {
        let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(CABitcoinBasedWallet.network)/txs/txid/\(txid)\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
        guard let url = URL(string: urlString) else {
            ATLog.debug("Failed to create URL: \(urlString)")
            return false
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.API_KEY, forHTTPHeaderField: "X-API-Key")
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        let semaphore = DispatchSemaphore(value: 0)
        let retryLimit = 3
        var retryCount = 0
        var errorOccured = false
        var done = false
        while !done && !errorOccured {
            let task = session.dataTask(with: request) { (data, response, error) in
                guard error == nil else {
                    ATLog.debug("\(error!)")
                    errorOccured = (retryCount >= retryLimit)
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                guard let jsonData = data else {
                    ATLog.debug("No data received")
                    errorOccured = (retryCount >= retryLimit)
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                
                let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                let metaObject = jsonObject?["meta"] as? [String: Any]
                
                if let errorObjet = metaObject?["error"] as? [String: Any] {
                    let code = errorObjet["code"] as? Int
                    if code == 63 { // request limit reached
                        sleep(arc4random() % 10 + 1)
                        semaphore.signal()
                        return
                    }
                    else {
                        errorOccured = (retryCount >= retryLimit)
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                }
                
                guard let tx = jsonObject?["payload"] as? [String: Any], let confirmations = tx["confirmations"] as? Int else {
                    errorOccured = (retryCount >= retryLimit)
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                guard confirmations > 0 else {
                    ATLog.debug("transaction has not confirmed yet")
                    errorOccured = true
                    semaphore.signal()
                    if untilConfirmed {
                        self.dispatchQueue.asyncAfter(deadline: .now() + self.AVERAGE_CONFIRMATION_TIME) {
                            self.singleSync(txid)
                        }
                    }
                    return
                }
                guard let txins = tx["txins"] as? [[String: Any]], let txouts = tx["txouts"] as? [[String: Any]] else {
                    errorOccured = (retryCount >= retryLimit)
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                
                var txAddresses: [(String, String)] = []
                for txin in txins {
                    guard let addresses = txin["addresses"] as? [String], let addressType = txin["votype"] as? String else { continue }
                    for address in addresses {
                        txAddresses.append((address, addressType))
                    }
                }
                for txout in txouts {
                    guard let addresses = txout["addresses"] as? [String], let addressType = txout["type"] as? String else { continue }
                    for address in addresses {
                        txAddresses.append((address, addressType))
                    }
                }
                var ownedAddresses: [(String, UInt32, UInt32)] = []
                for index in 0..<(self.numberOfUsedExternalPubKey + self.GAP_LIMIT) {
                    let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(Chain.externalChain.rawValue, index))
                    for txAddress in txAddresses {
                        var address = ""
                        if txAddress.1 == TxType.pubkeyhash.rawValue {
                            address = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
                        }
                        else if txAddress.1 == TxType.scripthash.rawValue {
                            address = pubkey.pubkeyToP2SHAddress(self.CRYPTOCURRENCY_TYPE)
                        }
                        else if txAddress.1 == TxType.witness_v0_keyhash.rawValue {
                            // not supporting P2WSH
                            address = pubkey.pubkeyToP2WPKHAddress(self.CRYPTOCURRENCY_TYPE) ?? ""
                        }
                        guard address != "" else { continue }
                        if txAddress.0 == address {
                            ownedAddresses.append((address, Chain.externalChain.rawValue, index))
                            (index >= self.numberOfUsedExternalPubKey) ? self.numberOfUsedExternalPubKey = index + 1 : nil
                        }
                    }
                }
                for index in 0..<(self.numberOfUsedInternalPubKey + self.GAP_LIMIT) {
                    let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(Chain.internalChain.rawValue, index))
                    for txAddress in txAddresses {
                        var address = ""
                        if txAddress.1 == TxType.pubkeyhash.rawValue {
                            address = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
                        }
                        else if txAddress.1 == TxType.scripthash.rawValue {
                            address = pubkey.pubkeyToP2SHAddress(self.CRYPTOCURRENCY_TYPE)
                            continue
                        }
                        else if txAddress.1 == TxType.witness_v0_keyhash.rawValue {
                            // not supporting P2WSH
                            address = pubkey.pubkeyToP2WPKHAddress(self.CRYPTOCURRENCY_TYPE) ?? ""
                        }
                        guard address != "" else { continue }
                        if txAddress.0 == address {
                            ownedAddresses.append((address, Chain.internalChain.rawValue, index))
                            (index >= self.numberOfUsedInternalPubKey) ? self.numberOfUsedInternalPubKey = index + 1 : nil
                        }
                    }
                }
                
                for addressInfo in ownedAddresses {
                    self.parseTransaction(tx, addressInfo.0, addressInfo.1 == Chain.internalChain.rawValue, addressInfo.2)
                }
                
                try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                    var metadata: CSMetadata
                    if let item = try? transaction.fetchOne(From<CSMetadata>()) {
                        metadata = item
                    }
                    else {
                        metadata = transaction.create(Into<CSMetadata>())
                    }
                    metadata.numberOfUsedExternalPubKey.value = Int32(bitPattern: self.numberOfUsedExternalPubKey)
                    metadata.numberOfUsedInternalPubKey.value = Int32(bitPattern: self.numberOfUsedInternalPubKey)
                })
                
                done = true
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
        return done
    }
    
    func fullSync() {
        self.isSyncing = true
        
        syncTransactions(.externalChain, 0, self.GAP_LIMIT)
        DispatchQueue.main.async {
            self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.externalChain.rawValue, self.numberOfUsedExternalPubKey)
        }
        
        syncTransactions(.internalChain, 0, self.GAP_LIMIT)
        DispatchQueue.main.async {
            self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.internalChain.rawValue, self.numberOfUsedInternalPubKey)
        }
        
        loadTransactions()
        self.isSyncing = false
        
        let timestamp = UInt32(round(Date().timeIntervalSince1970))
        self.lastSyncTime = Date(timeIntervalSince1970: TimeInterval(timestamp))
        self.lastFullSyncTime = self.lastSyncTime
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            var metadata: CSMetadata
            if let item = try? transaction.fetchOne(From<CSMetadata>()) {
                metadata = item
            }
            else {
                metadata = transaction.create(Into<CSMetadata>())
            }
            metadata.lastSyncTime.value = Int32(bitPattern: timestamp)
            metadata.lastFullSyncTime.value = Int32(bitPattern: timestamp)
            
            guard let unconfirmedTxs = try? transaction.fetchAll(From<CSTransaction>().where(\.confirmations == 0)) else { return }
            for cstx in unconfirmedTxs {
                let txid = cstx.txid.value
                self.dispatchQueue.async() {
                    self.singleSync(txid)
                }
            }
        })
    }
    
    func partialSync() {
        self.isSyncing = true
        syncTransactions(.externalChain, self.numberOfUsedExternalPubKey, 1)
        DispatchQueue.main.async {
            self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.externalChain.rawValue, self.numberOfUsedExternalPubKey)
        }
        
        syncTransactions(.internalChain, self.numberOfUsedInternalPubKey, 1)
        DispatchQueue.main.async() {
            self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.internalChain.rawValue, self.numberOfUsedInternalPubKey)
        }
        
        loadTransactions()
        self.isSyncing = false
        
        self.lastSyncTime = Date()
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            guard let unconfirmedTxs = try? transaction.fetchAll(From<CSTransaction>().where(\.confirmations == 0)) else { return }
            for cstx in unconfirmedTxs {
                let txid = cstx.txid.value
                self.dispatchQueue.async() {
                    self.singleSync(txid)
                }
            }
        })
    }
    
    func singleSync(_ txid: String) {
        self.isSyncing = true
        let numberOfUsedExternalPubKey = self.numberOfUsedExternalPubKey
        let numberOfUsedInternalPubKey = self.numberOfUsedInternalPubKey
        
        guard self.syncTransaction(txid, true) else {
            self.isSyncing = false
            return
        }
        DispatchQueue.main.async {
            (self.numberOfUsedExternalPubKey != numberOfUsedExternalPubKey) ? self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.externalChain.rawValue, self.numberOfUsedExternalPubKey) : nil
            (self.numberOfUsedInternalPubKey != numberOfUsedInternalPubKey) ? self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.internalChain.rawValue, self.numberOfUsedInternalPubKey) : nil
        }
        
        self.loadTransactions()
        self.isSyncing = false
    }
    
    func calculateTransactionSize(_ amount: Double) -> UInt64 {
        var numberOfTxIn = 1
        let numberOfTxOut = 2
        guard let utxos = try? self.dataStack.fetchAll(From<CSUnspentTxOut>().orderBy(.descending(\.amount))) else {
            return UInt64((numberOfTxIn * 148) + (numberOfTxOut * 34) + 10 + numberOfTxIn)
        }
        
        var unspentAmount: Double = 0
        numberOfTxIn = 0
        for utxo in utxos {
            guard !utxo.locked.value else { continue }
            unspentAmount += utxo.amount.value
            numberOfTxIn += 1
            let fee = Double((numberOfTxIn * 148) + (numberOfTxOut * 34) + 10 + numberOfTxIn)
            if unspentAmount >= (amount + fee) {
                break
            }
        }
        guard numberOfTxIn > 0 else { return 0 }
        
        var size: UInt64 = 0
        if self.isSegWitAccount {
            //P2WPKH
            size = UInt64((((numberOfTxIn * 272) + (numberOfTxOut * 128) + 42) + 3) / 4)
        }
        else {
            // P2PKH
            size = UInt64((numberOfTxIn * 148) + (numberOfTxOut * 34) + 10 + numberOfTxIn)
        }
        
        return size
    }
    
    func createRawTransaction(_ address: String, _ amount: Double, _ fee: Double, _ message: String?) -> Data? {
        var segwit = false
        if self.CRYPTOCURRENCY_TYPE == .bch {
            guard (message?.data(using: .utf8)?.count ?? 0) <= (220) else { return nil } // at most 220 bytes
        }
        else {
            guard (message?.data(using: .utf8)?.count ?? 0) <= (80) else { return nil } // at most 80 bytes
        }
        guard let utxos = try? self.dataStack.fetchAll(From<CSUnspentTxOut>().orderBy(.descending(\.amount))), utxos.count > 0 else { return nil }
        
        var utxoAmount: Double = 0
        var unspendTxOuts: [CSUnspentTxOut] = []
        for utxo in utxos {
            guard !utxo.locked.value else { continue }
            unspendTxOuts.append(utxo)
            utxoAmount += utxo.amount.value
            if utxoAmount >= (amount + fee) { break }
        }
        guard unspendTxOuts.count > 0, utxoAmount >= (amount + fee) else { return nil }
        let change = utxoAmount - amount - fee
        let hasChange = BitcoinToSatoshi(change) > 0
        
        var rawTx = Data()
        
        // Version
        #if TESTNET
        var version: UInt32 = 2
        #else
        var version: UInt32 = 1
        #endif
        rawTx.append(UnsafeBufferPointer<UInt32>(start: &version, count: 1))
                
        // Input count
        let txinCount = UInt8(unspendTxOuts.count)
        rawTx.append(txinCount)
        
        for utxo in unspendTxOuts {
            // Input txid
            rawTx.append(Data(Data(hex: utxo.txid.value).reversed()))
            
            // Input vout
            var vout = UInt32(bitPattern: utxo.vout.value)
            rawTx.append(UnsafeBufferPointer<UInt32>(start: &vout, count: 1))
            
            // Script length
            rawTx.append(UInt8(0))
            
            // Sequence
            var sequence: UInt32 = 0xFFFFFFFF
            rawTx.append(UnsafeBufferPointer<UInt32>(start: &sequence, count: 1))
            
            if utxo.type.value == TxType.pubkeyhash.rawValue {
                // do nothing
            }
            else if utxo.type.value == TxType.scripthash.rawValue {
                segwit = true
            }
            else if utxo.type.value == TxType.witness_v0_keyhash.rawValue {
                segwit = true
            }
            else {
                return nil
            }
        }
        
        // Output count
        var txoutCount: UInt8 = hasChange ? 2 : 1
        ((message?.count ?? 0) > 0) ? txoutCount += 1 : nil
        rawTx.append(txoutCount)
        
        // Output
        // Amount
        var satoshi = BitcoinToSatoshi(amount)
        rawTx.append(UnsafeBufferPointer<UInt64>(start: &satoshi, count: 1))
        
        // Script length
        var script: Data?
        if address.isP2PKHAddress(self.CRYPTOCURRENCY_TYPE) {
            script = address.p2pkhAddressToPubKeyHash()?.pubkeyHashToP2PKHScript()
        }
        else if address.isP2SHAddress(self.CRYPTOCURRENCY_TYPE) {
            script = address.p2shAddressToRedeemScriptHash()?.redeemScriptHashToP2SHScript()
        }
        else if address.isCashAddress() {
            guard let decodedAddr = address.cashAddressDecode() else { return nil }
            if decodedAddr.isP2PKHAddress(self.CRYPTOCURRENCY_TYPE) {
                script = decodedAddr.p2pkhAddressToPubKeyHash()?.pubkeyHashToP2PKHScript()
            }
            else if decodedAddr.isP2SHAddress(self.CRYPTOCURRENCY_TYPE) {
                script = decodedAddr.p2shAddressToRedeemScriptHash()?.redeemScriptHashToP2SHScript()
            }
            else {
                return nil
            }
        }
        else if address.isSegWitAddress() {
            script = address.extractScriptPubKeyFromSegWitAddress()
        }
        else {
            return nil
        }
        guard script != nil else { return nil }
        if script!.count < 0xFD {
            rawTx.append(UInt8(script!.count))
        }
        else if script!.count <= UInt16.max {
            var scriptLen = UInt16(script!.count)
            rawTx.append(UInt8(0xFD))
            rawTx.append(UnsafeBufferPointer<UInt16>(start: &scriptLen, count: 1))
        }
        else if script!.count <= UInt32.max {
            // 0xFE
            return nil
        }
        else if script!.count <= UInt64.max {
            // 0xFF
            return nil
        }
        
        // Script
        rawTx.append(script!)
        
        // Change
        if hasChange {
            // Amount
            var satoshi = BitcoinToSatoshi(change)
            rawTx.append(UnsafeBufferPointer<UInt64>(start: &satoshi, count: 1))
            
            // Script length
            let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(Chain.internalChain.rawValue, self.numberOfUsedInternalPubKey))
            let script = self.isSegWitAccount ? pubkey.pubkeyToP2WPKHScript() : pubkey.pubkeyToP2PKHScript()
            if script.count < 0xFD {
                rawTx.append(UInt8(script.count))
            }
            else if script.count <= UInt16.max {
                var scriptLen = UInt16(script.count)
                rawTx.append(UInt8(0xFD))
                rawTx.append(UnsafeBufferPointer<UInt16>(start: &scriptLen, count: 1))
            }
            else if script.count <= UInt32.max {
                // 0xFE
                return nil
            }
            else if script.count <= UInt64.max {
                // 0xFF
                return nil
            }
            
            // Script
            rawTx.append(script)
        }
        
        // Message
        if let data = message?.data(using: .utf8), data.count > 0 {
            // Amount
            var satoshi: UInt64 = 0
            rawTx.append(UnsafeBufferPointer<UInt64>(start: &satoshi, count: 1))
            
            // Script length
            rawTx.append(UInt8(data.count) + 2)
            
            // Script
            rawTx.append(UInt8(0x6A)) // OP_RETURN
            rawTx.append(UInt8(data.count))
            rawTx.append(data)
        }
        
        // Locktime
        var locktime: UInt32 = 0
        rawTx.append(UnsafeBufferPointer<UInt32>(start: &locktime, count: 1))
        
        // SegWit flag
        if segwit {
            let segwitFlag: [UInt8] = [0x00, 0x01]
            rawTx.insert(contentsOf: segwitFlag, at: 4)
        }
        
        return rawTx
    }
    
    func generateLegacyRawTransactionHashForSigning(_ rawTx: Data, _ txinId: String) -> Data? {
        var offset = 0
        
        // Version: Mainnet = 1, Testnet = 2
        /*let version = rawTx.subdata(in: offset..<(offset+4)).withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
        
        // SegWit
        let segwit = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> Bool in
            let segwitFlag = CFSwapInt16BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee)
            return segwitFlag == 1
        }
        segwit ? offset += 2 : nil
        
        // Input count
        let inputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        
        var unsignedTx = rawTx.subdata(in: 0..<offset)
        for _ in 0..<Int(inputCount) {
            // Txid
            let txid = rawTx.subdata(in: offset..<(offset+32))
            offset += 32
            unsignedTx.append(txid)
            
            // Vout
            let vout = rawTx.subdata(in: offset..<(offset+4))
            offset += 4
            unsignedTx.append(vout)
            
            // Script length
            let length8 = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            var scriptLength = 0
            if length8 < 0xFD {
                scriptLength = Int(length8)
            }
            else if length8 == 0xFD {
                let length16  = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> UInt16 in
                    return pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
                }
                offset += 2
                scriptLength = Int(length16)
            }
            else if length8 == 0xFE {
                return nil
            }
            else if length8 == 0xFF {
                return nil
            }
            var pubkeyScript = Data()
            if txid.reversed().toHexString() == txinId {
                guard let utxo = try? self.dataStack.fetchOne(From<CSUnspentTxOut>().where(\.txid == txinId)) else { return nil }
                pubkeyScript = utxo.script.value
            }
            if pubkeyScript.count < 0xFD {
                unsignedTx.append(UInt8(pubkeyScript.count))
            }
            else if pubkeyScript.count <= UInt16.max {
                var scriptLen = UInt16(pubkeyScript.count)
                unsignedTx.append(UInt8(0xFD))
                unsignedTx.append(UnsafeBufferPointer<UInt16>(start: &scriptLen, count: 1))
            }
            else if pubkeyScript.count <= UInt32.max {
                // 0xFE
                return nil
            }
            else if pubkeyScript.count <= UInt64.max {
                // 0xFF
                return nil
            }
            
            // Script
            //let script = // skip
            offset += Int(scriptLength)
            (pubkeyScript.count > 0) ? unsignedTx.append(pubkeyScript) : nil
            
            // Sequence
            let sequence = rawTx.subdata(in: offset..<(offset+4))
            offset += 4
            unsignedTx.append(sequence)
        }
        
        // Output count
        let outputStartIndex = offset
        let outputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        for _ in 0..<outputCount {
            // Amount
            /*let amount = rawTx.subdata(in: offset..<(offset+8)).withUnsafeBytes { (pointer) -> UInt64 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt64.self).pointee
            }*/
            offset += 8
            
            // Script length
            let length8 = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            var scriptLength = 0
            if length8 < 0xFD {
                scriptLength = Int(length8)
            }
            else if length8 == 0xFD {
                let length16  = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> UInt16 in
                    return pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
                }
                offset += 2
                scriptLength = Int(length16)
            }
            else if length8 == 0xFE {
                return nil
            }
            else if length8 == 0xFF {
                return nil
            }
            
            // Script
            //let script = // skip
            offset += scriptLength
        }
        
        // Locktime
        /*let locktime = rawTx.subdata(in: offset..<(offset+4)).withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
        
        unsignedTx.append(rawTx.subdata(in: outputStartIndex..<offset))
        
        // Hash type
        var hashType: UInt32 = 1 | UInt32(self.CRYPTOCURRENCY_TYPE.forkId) // SIGHASH_ALL | Fork ID
        unsignedTx.append(UnsafeBufferPointer<UInt32>(start: &hashType, count: 1))
        ATLog.debug("Hash Preimage: \(unsignedTx.toHexString())")
        
        return unsignedTx.sha256().sha256()
    }
    
    func generateV0WitnessProgramRawTransactionHashForSigning(_ rawTx: Data, _ txinId: String) -> Data? {
        var inputData = Data()
        var outputData = Data()
        var sequenceData = Data()
        var outpoint = Data()
        var nSequence = Data()
        var offset = 0
        
        // Version: Mainnet = 1, Testnet = 2
        let version = rawTx.subdata(in: offset..<(offset+4))/*.withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
        
        // SegWit
        let segwit = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> Bool in
            let segwitFlag = CFSwapInt16BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee)
            return segwitFlag == 1
        }
        segwit ? offset += 2 : nil
        
        // Input count
        let inputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        
        for _ in 0..<Int(inputCount) {
            // Txid
            let txid = rawTx.subdata(in: offset..<(offset+32))
            offset += 32
            inputData.append(txid)
            (txid.reversed().toHexString() == txinId) ? outpoint.append(txid) : nil
            
            // Vout
            let vout = rawTx.subdata(in: offset..<(offset+4))
            offset += 4
            inputData.append(vout)
            (txid.reversed().toHexString() == txinId) ? outpoint.append(vout) : nil
            
            // Script length
            let length8 = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            var scriptLength = 0
            if length8 < 0xFD {
                scriptLength = Int(length8)
            }
            else if length8 == 0xFD {
                let length16  = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> UInt16 in
                    return pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
                }
                offset += 2
                scriptLength = Int(length16)
            }
            else if length8 == 0xFE {
                return nil
            }
            else if length8 == 0xFF {
                return nil
            }
            
            // Script
            //let script = // skip
            offset += Int(scriptLength)
            
            // Sequence
            let sequence = rawTx.subdata(in: offset..<(offset+4))
            offset += 4
            sequenceData.append(sequence)
            (txid.reversed().toHexString() == txinId) ? nSequence = sequence : nil
        }
        
        // Output count
        let outputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        for _ in 0..<outputCount {
            // Amount
            let amount = rawTx.subdata(in: offset..<(offset+8))/*.withUnsafeBytes { (pointer) -> UInt64 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt64.self).pointee
            }*/
            offset += 8
            outputData.append(amount)
            
            // Script length
            let length8 = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            outputData.append(length8)
            var scriptLength = 0
            if length8 < 0xFD {
                scriptLength = Int(length8)
            }
            else if length8 == 0xFD {
                var length16  = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> UInt16 in
                    return pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
                }
                offset += 2
                scriptLength = Int(length16)
                outputData.append(UnsafeBufferPointer<UInt16>(start: &length16, count: 1))
            }
            else if length8 == 0xFE {
                return nil
            }
            else if length8 == 0xFF {
                return nil
            }
            
            // Script
            let script = rawTx.subdata(in: offset..<(offset+scriptLength))
            offset += scriptLength
            outputData.append(script)
            
        }
        
        // Locktime
        let locktime = rawTx.subdata(in: offset..<(offset+4))/*.withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
                
        // Hash type
        var hashType: UInt32 = 1 | UInt32(self.CRYPTOCURRENCY_TYPE.forkId) // SIGHASH_ALL | Fork ID
        
        guard let utxo = try? self.dataStack.fetchOne(From<CSUnspentTxOut>().where(\.txid == txinId)) else { return nil }
        var scriptCode = Data()
        if utxo.type.value == TxType.pubkeyhash.rawValue {
            if utxo.script.value.count < 0xFD {
                scriptCode.append(UInt8(utxo.script.value.count))
            }
            else if utxo.script.value.count <= UInt16.max {
                var length16 = UInt16(utxo.script.value.count)
                scriptCode.append(UnsafeBufferPointer<UInt16>(start: &length16, count: 1))
            }
            else if utxo.script.value.count <= UInt32.max {
                return nil
            }
            else if utxo.script.value.count <= UInt64.max {
                return nil
            }
            scriptCode.append(utxo.script.value)
        }
        else if utxo.type.value == TxType.scripthash.rawValue {
            // P2SH, P2SH-P2WPKH, P2SH-P2WSH
            return nil
        }
        else if utxo.type.value == TxType.witness_v0_keyhash.rawValue {
            if utxo.script.value.count == 22, utxo.script.value[0] == UInt8(OP_0), utxo.script.value[1] == 20 {
                // P2WPKH
                let script = utxo.script.value.subdata(in: 2..<22).pubkeyHashToP2PKHScript()
                scriptCode.append(UInt8(script.count))
                scriptCode.append(script)
            }
            else {
                // P2WSH is not supported
            }
        }
        
        var amount = BitcoinToSatoshi(utxo.amount.value)
        var unsignedTx = Data()
        unsignedTx.append(version)
        unsignedTx.append(inputData.sha256().sha256())
        unsignedTx.append(sequenceData.sha256().sha256())
        unsignedTx.append(outpoint)
        unsignedTx.append(scriptCode)
        unsignedTx.append(UnsafeBufferPointer<UInt64>(start: &amount, count: 1))
        unsignedTx.append(nSequence)
        unsignedTx.append(outputData.sha256().sha256())
        unsignedTx.append(locktime)
        unsignedTx.append(UnsafeBufferPointer<UInt32>(start: &hashType, count: 1))
        ATLog.debug("Inputs: \(inputData.toHexString())")
        ATLog.debug("Sequences: \(sequenceData.toHexString())")
        ATLog.debug("Outputs: \(outputData.toHexString())")
        ATLog.debug("Hash Preimage: \(unsignedTx.toHexString())")
        
        return unsignedTx.sha256().sha256()
    }
    
    func generateRawTransactionHashForSigning(_ rawTx: Data, _ txinId: String) -> Data? {
        if self.CRYPTOCURRENCY_TYPE == .bch {
            return generateV0WitnessProgramRawTransactionHashForSigning(rawTx, txinId)
        }
        
        let segwit = rawTx.subdata(in: 4..<(4+2)).withUnsafeBytes { (pointer) -> Bool in
            let segwitFlag = pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
            return segwitFlag == 0x0100
        }
        if segwit {
            return generateV0WitnessProgramRawTransactionHashForSigning(rawTx, txinId)
        }
        else {
            return generateLegacyRawTransactionHashForSigning(rawTx, txinId)
        }
    }
    
    func extractInputTxIds(_ rawTx: Data) -> [String] {
        var offset = 0
        
        // Version: Mainnet = 1, Testnet = 2
        /*let version = rawTx.subdata(in: offset..<(offset+4)).withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
        
        // Segwit
        let segwit = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> Bool in
            let segwitFlag = CFSwapInt16BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee)
            return segwitFlag == 1
        }
        segwit ? offset += 2 : nil
        
        // Input Count
        let inputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        var inputTxIds: [String] = []
        for _ in 0..<inputCount {
            // txid
            let txid = rawTx.subdata(in: offset..<(offset+32)).toHexString()
            offset += 32
            inputTxIds.append(Data(Data(hex: txid).reversed()).toHexString())
            // vout
            //let vout = // skip
            offset += 4
            // script length
            let scriptLength = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            // script
            //let script = // skip
            offset += Int(scriptLength)
            // sequence
            //let sequence = // skip
            offset += 4
        }
        guard inputCount == inputTxIds.count else { return [] }
        
        return inputTxIds
    }
    
    func extractInputTxVouts(_ rawTx: Data) -> [UInt32] {
        var offset = 0
        
        // Version: Mainnet = 1, Testnet = 2
        /*let version = rawTx.subdata(in: offset..<(offset+4)).withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
        
        // Segwit
        let segwit = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> Bool in
            let segwitFlag = CFSwapInt16BigToHost(pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee)
            return segwitFlag == 1
        }
        segwit ? offset += 2 : nil
        
        // Input Count
        let inputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        var inputTxVouts: [UInt32] = []
        for _ in 0..<inputCount {
            // txid
            //let txid = rawTx.subdata(in: offset..<(offset+32)).toHexString()
            offset += 32
            // vout
            let vout = rawTx.subdata(in: offset..<(offset+4)).withUnsafeBytes { (pointer) -> UInt32 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
            }
            offset += 4
            inputTxVouts.append(vout)
            // script length
            let scriptLength = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            // script
            //let script = // skip
            offset += Int(scriptLength)
            // sequence
            //let sequence = // skip
            offset += 4
        }
        guard inputCount == inputTxVouts.count else { return [] }
        
        return inputTxVouts
    }
    
    func extractInputTxTypes(_ rawTx: Data) -> [String] {
        var types: [String] = []
        let txids = extractInputTxIds(rawTx)
        for txid in txids {
            guard let csutxo = try? self.dataStack.fetchOne(From<CSUnspentTxOut>().where(\.txid == txid)) else {
                ATLog.debug("Unspent Tx Output not found. TXID: \(txid)")
                continue
            }
            let type = csutxo.type.value
            types.append(type)
        }
        return types
    }
    
    func generateUnsignedTxDataInfos(_ rawTx: Data) -> [ATCryptocurrencyTransaction.UnsignedTransactionDataInfo] {
        let txids = extractInputTxIds(rawTx)
        guard txids.count > 0 else { return [] }
        var unsignedTxDataInfos: [ATCryptocurrencyTransaction.UnsignedTransactionDataInfo] = []
        for txid in txids {
            guard let csutxo = try? self.dataStack.fetchOne(From<CSUnspentTxOut>().where(\.txid == txid)) else {
                ATLog.debug("Unspent Tx Output not found. TXID: \(txid)")
                continue
            }
            let chainId = UInt32(bitPattern: csutxo.chainIndex.value)
            let keyId = UInt32(bitPattern: csutxo.keyIndex.value)
            guard let hash = generateRawTransactionHashForSigning(rawTx, txid) else { return [] }
            let txDataInfo = ATCryptocurrencyTransaction.UnsignedTransactionDataInfo(chainId: chainId, keyId: keyId, data: ATUInt256(hash.bytes))
            unsignedTxDataInfos.append(txDataInfo)
        }
        return unsignedTxDataInfos
    }
        
    func generateSignedTx(_ rawTx: Data, _ signatures: [Data], _ unsignedTxDataInfos: [ATCryptocurrencyTransaction.UnsignedTransactionDataInfo]) -> Data? {
        let segwit = rawTx.subdata(in: 4..<(4+2)).withUnsafeBytes { (pointer) -> Bool in
            let segwitFlag = pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
            return segwitFlag == 0x0100
        }
        
        let txinTypes = extractInputTxTypes(rawTx)
        guard signatures.count == unsignedTxDataInfos.count, txinTypes.count == signatures.count else { return nil }
        var signatureScripts: [Data] = []
        var witnesses: [Data] = []
        for index in 0..<signatures.count {
            guard let der = signatures[index].toDER() else { break }
            var signatureScript = Data()
            var witness = Data()
            let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(unsignedTxDataInfos[index].chainId, unsignedTxDataInfos[index].keyId))
            if txinTypes[index] == TxType.pubkeyhash.rawValue {
                signatureScript.append(UInt8(der.count + 1)) // signature length + hash type
                signatureScript.append(der)
                signatureScript.append(1 | self.CRYPTOCURRENCY_TYPE.forkId) // SIGHASH_ALL | Fork ID
                signatureScript.append(UInt8(pubkey.count))
                signatureScript.append(pubkey)
                segwit ? witness.append(0) : nil
            }
            else if txinTypes[index] == TxType.scripthash.rawValue {
                if segwit {
                    // not supporting P2SH-P2WSH
                    // P2SH-P2WPKH
                    witness.append(2)
                    witness.append(UInt8(der.count + 1)) // signature length + hash type
                    witness.append(der)
                    witness.append(1 | self.CRYPTOCURRENCY_TYPE.forkId) // SIGHASH_ALL | Fork ID
                    witness.append(UInt8(pubkey.count))
                    witness.append(pubkey)
                }
                else {
                    // P2SH
                    signatureScript.append(UInt8(der.count + 1)) // signature length + hash type
                    signatureScript.append(der)
                    signatureScript.append(1 | self.CRYPTOCURRENCY_TYPE.forkId) // SIGHASH_ALL | Fork ID
                    let redeemScript = pubkey.pubkeyToP2SHRedeemScript()
                    if let byte = redeemScript.last, byte == UInt8(0xAE) { // OP_CHECKMULTISIG
                        signatureScript.insert(UInt8(OP_0), at: 0)
                    }
                    if redeemScript.count <= UInt8.max {
                        signatureScript.append(UInt8(OP_PUSHDATA1))
                        signatureScript.append(UInt8(redeemScript.count))
                    }
                    else if redeemScript.count <= UInt16.max {
                        signatureScript.append(UInt8(OP_PUSHDATA2))
                        var length16 = UInt16(redeemScript.count)
                        signatureScript.append(UnsafeBufferPointer<UInt16>(start: &length16, count: 1))
                    }
                    else if redeemScript.count <= UInt32.max {
                        return nil
                    }
                    signatureScript.append(redeemScript)
                }
            }
            else if txinTypes[index] == TxType.witness_v0_keyhash.rawValue {
                // not supporting P2WSH
                // P2WPKH
                witness.append(2)
                witness.append(UInt8(der.count + 1)) // signature length + hash type
                witness.append(der)
                witness.append(1 | self.CRYPTOCURRENCY_TYPE.forkId) // SIGHASH_ALL | Fork ID
                witness.append(UInt8(pubkey.count))
                witness.append(pubkey)
            }
            signatureScripts.append(signatureScript)
            witnesses.append(witness)
        }
        guard signatureScripts.count == signatures.count else { return nil }
        
        var offset = 0
        
        // Version: Mainnet = 1, Testnet = 2
        /*let version = rawTx.subdata(in: offset..<(offset+4)).withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
        
        // SegWit
        segwit ? offset += 2 : nil
        
        // Input count
        let inputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        
        var signedData = rawTx.subdata(in: 0..<offset)
        for index in 0..<Int(inputCount) {
            // txid
            let txid = rawTx.subdata(in: offset..<(offset+32))
            offset += 32
            signedData.append(txid)
            
            // vout
            let vout = rawTx.subdata(in: offset..<(offset+4))
            offset += 4
            signedData.append(vout)
            
            // script length
            let length8 = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            var scriptLength = 0
            if length8 < 0xFD {
                scriptLength = Int(length8)
            }
            else if length8 == 0xFD {
                let length16  = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> UInt16 in
                    return pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
                }
                offset += 2
                scriptLength = Int(length16)
            }
            else if length8 == 0xFE {
                return nil
            }
            else if length8 == 0xFF {
                return nil
            }
            if signatureScripts[index].count < 0xFD {
                signedData.append(UInt8(signatureScripts[index].count))
            }
            else if signatureScripts[index].count <= UInt16.max {
                signedData.append(UInt8(0xFD))
                var length16 = UInt16(signatureScripts[index].count)
                signedData.append(UnsafeBufferPointer<UInt16>(start: &length16, count: 1))
            }
            else if signatureScripts[index].count <= UInt32.max {
                return nil
            }
            else if signatureScripts[index].count <= UInt64.max {
                return nil
            }
            
            // script
            //let script = // skip
            offset += scriptLength
            (signatureScripts[index].count > 0) ? signedData.append(signatureScripts[index]) : nil
            
            // sequence
            let sequence = rawTx.subdata(in: offset..<(offset+4))
            offset += 4
            signedData.append(sequence)
        }
        
        // Output count
        let outputStartIndex = offset
        let outputCount = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
        }
        offset += 1
        for _ in 0..<outputCount {
            // amount
            /*let amount = rawTx.subdata(in: offset..<(offset+8)).withUnsafeBytes { (pointer) -> UInt64 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt64.self).pointee
            }*/
            offset += 8
            
            // script length
            let length8 = rawTx.subdata(in: offset..<(offset+1)).withUnsafeBytes { (pointer) -> UInt8 in
                return pointer.baseAddress!.assumingMemoryBound(to: UInt8.self).pointee
            }
            offset += 1
            var scriptLength = 0
            if length8 < 0xFD {
                scriptLength = Int(length8)
            }
            else if length8 == 0xFD {
                let length16  = rawTx.subdata(in: offset..<(offset+2)).withUnsafeBytes { (pointer) -> UInt16 in
                    return pointer.baseAddress!.assumingMemoryBound(to: UInt16.self).pointee
                }
                offset += 2
                scriptLength = Int(length16)
            }
            else if length8 == 0xFE {
                return nil
            }
            else if length8 == 0xFF {
                return nil
            }
            
            // script
            //let script = // skip
            offset += scriptLength
        }
        
        signedData.append(rawTx.subdata(in: outputStartIndex..<offset))
        
        // Witness
        if segwit {
            for witness in witnesses {
                (witness.count > 0) ? signedData.append(witness) : nil
            }
        }
        
        // Locktime
        let locktime = rawTx.subdata(in: offset..<(offset+4))/*.withUnsafeBytes { (pointer) -> UInt32 in
            return pointer.baseAddress!.assumingMemoryBound(to: UInt32.self).pointee
        }*/
        offset += 4
        signedData.append(locktime)
        
        return signedData
    }
    
    override func startSync(_ autoSync: Bool = true) {
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidStartSync()
            }
            if self.isFullSyncNeeded {
                self.fullSync()
            }
            else if self.isPartialSyncNeeded {
                self.partialSync()
            }
            else {
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.externalChain.rawValue, self.numberOfUsedExternalPubKey)
                    self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(Chain.internalChain.rawValue, self.numberOfUsedInternalPubKey)
                }
            }
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidUpdateBalance(self.getBalance())
                self.delegate?.abstractWalletDidStopSync(nil)
                if autoSync {
                    self.syncTimer?.invalidate()
                    // check if sync is needed every 60 seconds
                    self.syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { (timer) in
                        guard !self.isSyncing else { return }
                        self.dispatchQueue.async {
                            self.isPartialSyncNeeded ? self.partialSync() : nil
                        }
                    })
                }
            }
        }
    }
    override func stopAutoSync() {
        ATLog.debug("\(#function)")
        self.syncTimer?.invalidate()
    }
    
    override func getBalance() -> ATUInt256 { // Unit: satoshi
        ATLog.debug("\(#function)")
        return ATUInt256(BitcoinToSatoshi(abs(self.balance)))
    }
    
    override func getBalanceString() -> String { // Unit: BTC
        ATLog.debug("\(#function)")
        return abs(self.balance).toString(8)
    }
    
    override func getTransactions() -> [ATCryptocurrencyTransaction] {
        ATLog.debug("\(#function)")
        return self.transactions
    }
    
    override func getReceivingAddress() -> String {
        ATLog.debug("\(#function)")
        let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(Chain.externalChain.rawValue, self.numberOfUsedExternalPubKey))
        var address = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
        if self.CRYPTOCURRENCY_TYPE == .bch, let cashAddress = pubkey.pubkeyToP2PKHCashAddress() {
            address = cashAddress
        }
        else if self.isSegWitAccount, let p2wpkhAddress = pubkey.pubkeyToP2WPKHAddress(self.CRYPTOCURRENCY_TYPE) {
            address = p2wpkhAddress
        }
        return address
    }
    
    override func getReceivingAddressesWithFormat() -> [String: String]? {
        ATLog.debug("\(#function)")
        let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(Chain.externalChain.rawValue, self.numberOfUsedExternalPubKey))
        var addresses: [String: String]? = nil
        if self.isSegWitAccount {
            if let p2wpkhAddress = pubkey.pubkeyToP2WPKHAddress(self.CRYPTOCURRENCY_TYPE) {
                addresses = ["P2WPKH": p2wpkhAddress]
            }
        }
        else {
            let p2pkhAddress = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
            addresses =  ["P2PKH": (self.CRYPTOCURRENCY_TYPE == .bch) ? (p2pkhAddress.p2pkhAddressToCashAddress() ?? p2pkhAddress) : p2pkhAddress]
        }
        return addresses
    }
    
    override func checkAddressValidity(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        return address.isP2PKHAddress(self.CRYPTOCURRENCY_TYPE) || address.isP2SHAddress(self.CRYPTOCURRENCY_TYPE) || ((self.CRYPTOCURRENCY_TYPE == .bch) ? address.isCashAddress() : false) || address.isSegWitAddress()
    }
    
    override func containAddress(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        enum AddressType {
            case p2pkh
            case p2sh
            case p2wpkh
            case p2wsh
        }
        var address = address
        if self.CRYPTOCURRENCY_TYPE == .bch, address.isCashAddress() {
            guard let decodedAddr = address.cashAddressDecode() else { return false }
            address = decodedAddr
        }
        var addressType: AddressType
        if address.isP2PKHAddress(self.CRYPTOCURRENCY_TYPE) {
            addressType = .p2pkh
        }
        else if address.isP2SHAddress(self.CRYPTOCURRENCY_TYPE) {
            addressType = .p2sh
        }
        else if address.isP2WPKHAddress() {
            addressType = .p2wpkh
        }
        else if address.isP2WSHAddress() {
            addressType = .p2wsh
        }
        else {
            return false
        }
        
        var contained = false
        for index in 0...(self.numberOfUsedExternalPubKey + self.GAP_LIMIT) {
            let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(Chain.externalChain.rawValue, index))
            var ownedAddress = ""
            switch addressType {
            case .p2pkh:
                ownedAddress = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
            case .p2sh:
                ownedAddress = pubkey.pubkeyToP2SHAddress(self.CRYPTOCURRENCY_TYPE)
            case .p2wpkh:
                ownedAddress = pubkey.pubkeyToP2WPKHAddress(self.CRYPTOCURRENCY_TYPE) ?? ""
            case .p2wsh:
                // unsupported
                break
            }
            if ownedAddress == address {
                contained = true
                break
            }
        }
        guard !contained else { return true }
        for index in 0...(self.numberOfUsedInternalPubKey + self.GAP_LIMIT) {
            let pubkey = Data(self.extendedPublicKey.deriveCompressedPubKey(Chain.internalChain.rawValue, index))
            var ownedAddress = ""
            switch addressType {
            case .p2pkh:
                ownedAddress = pubkey.pubkeyToP2PKHAddress(self.CRYPTOCURRENCY_TYPE)
            case .p2sh:
                ownedAddress = pubkey.pubkeyToP2SHAddress(self.CRYPTOCURRENCY_TYPE)
            case .p2wpkh:
                ownedAddress = pubkey.pubkeyToP2WPKHAddress(self.CRYPTOCURRENCY_TYPE) ?? ""
            case .p2wsh:
                // unsupported
                break
            }
            if ownedAddress == address {
                contained = true
                break
            }
        }
        return contained
    }
    
    override func calculateMinimumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let feePerByte: UInt64 = self.MIN_FEE_PER_BYTE
        let msgLen = UInt64(message?.data(using: .utf8)?.count ?? 0)
        let txSize = calculateTransactionSize(Double(amount) ?? ONE_SATOSHI_BTC)
        guard txSize > 0 else { return "0" }
        return SatoshiToBitcoin((txSize + (msgLen + 11)) * feePerByte).toString(8)
    }
    
    override func calculateLowFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let feePerByte: UInt64 = self.LOW_FEE_PER_BYTE
        let msgLen = UInt64(message?.data(using: .utf8)?.count ?? 0)
        let txSize = calculateTransactionSize(Double(amount) ?? ONE_SATOSHI_BTC)
        guard txSize > 0 else { return "0" }
        return SatoshiToBitcoin((txSize + (msgLen + 11)) * feePerByte).toString(8)
    }
    
    override func calculateMediumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let feePerByte: UInt64 = self.MEDIUM_FEE_PER_BYTE
        let msgLen = UInt64(message?.data(using: .utf8)?.count ?? 0)
        let txSize = calculateTransactionSize(Double(amount) ?? ONE_SATOSHI_BTC)
        guard txSize > 0 else { return "0" }
        return SatoshiToBitcoin((txSize + (msgLen + 11)) * feePerByte).toString(8)
    }
    
    override func calculateHighFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let feePerByte: UInt64 = self.HIGH_FEE_PER_BYTE
        let msgLen = UInt64(message?.data(using: .utf8)?.count ?? 0)
        let txSize = calculateTransactionSize(Double(amount) ?? ONE_SATOSHI_BTC)
        guard txSize > 0 else { return "0" }
        return SatoshiToBitcoin((txSize + (msgLen + 11)) * feePerByte).toString(8)
    }
    
    override func getMaxOutputAmount() -> String {
        ATLog.debug("\(#function)")
        guard let utxos = try? self.dataStack.fetchAll(From<CSUnspentTxOut>().where(\.locked == false)) else { return "0" }
        var spandableBalance = 0.0
        for utxo in utxos {
            spandableBalance += utxo.amount.value
        }
        guard spandableBalance > 0 else { return "0" }
        
        let minFee = calculateMinimumFee(spandableBalance.toString(8))
        guard let minFeeValue = Double(minFee), minFeeValue > 0, minFeeValue < spandableBalance else { return "0" }
        let maxOutput = spandableBalance - minFeeValue
        return abs(maxOutput).toString(8)
    }
    
    override func getMinOutputAmount() -> String {
        ATLog.debug("\(#function)")
        return calculateMinimumFee("0.00000001")
    }
    
    override func createTransaction(_ amount: String, _ fee: String, _ address: String, _ message: String? = nil) -> ATCryptocurrencyTransaction? {
        ATLog.debug("\(#function)")
        let balanceString = self.balance.toString(8) // to round
        guard !self.isSyncing, checkAddressValidity(address), let amount = Double(amount), let fee = Double(fee), let balance = Double(balanceString), (amount + fee) <= balance, fee <= amount else {
            return nil
        }
        
        guard let rawTx = createRawTransaction(address, amount, fee, message) else { return nil }
        ATLog.debug("Raw Tx: \(rawTx.toHexString())")
        let newTransaction = ATCryptocurrencyTransaction(address, amount, fee, self.CRYPTOCURRENCY_TYPE, rawTx as AnyObject, message)
        
        return newTransaction
    }
    
    override func destroyTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        transaction.object = nil
    }
    
    override func generateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            guard let rawTx = transaction.object as? Data else {
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .invalidParameter)
                }
                return
            }
                        
            let unsignedTxDataInfos = self.generateUnsignedTxDataInfos(rawTx)
            guard unsignedTxDataInfos.count > 0 else {
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
                }
                return
            }
            transaction.unsignedTransactionDataInfos = unsignedTxDataInfos
            transaction.object = rawTx as AnyObject
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidGenerateTransactionDataForSigning(transaction)
            }
        }
    }
    
    override func generateSignedTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let rawTx = transaction.object as? Data else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .invalidParameter)
            }
            return
        }
        guard let signatures = transaction.rsvSignatures, let unsignedTxInfos = transaction.unsignedTransactionDataInfos else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            }
            return
        }
        guard let signedTx = generateSignedTx(rawTx, signatures, unsignedTxInfos) else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            }
            return
        }
        transaction.object = signedTx as AnyObject
        DispatchQueue.main.async {
            self.delegate?.abstractWalletDidGenerateSignedTransaction(transaction)
        }
    }
    
    override func publishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        struct SignedTxData: Codable {
            let hex: String
        }
        
        guard let signedTx = transaction.object as? Data else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .invalidParameter)
            }
            return
        }
        let signedTxData = SignedTxData(hex: signedTx.toHexString())
        guard let jsonData = try? JSONEncoder().encode(signedTxData) else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .invalidParameter)
            }
            return
        }
        
        let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(CABitcoinBasedWallet.network)/txs/send\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
        guard let url = URL(string: urlString) else {
            ATLog.debug("Failed to create URL: \(urlString)")
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
            }
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.API_KEY, forHTTPHeaderField: "X-API-Key")
        request.httpBody = jsonData
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil, let jsonData = data else {
                (error != nil) ? ATLog.debug("\(error!)") : nil
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
                }
                return
            }
            ATLog.debug("Request: \(request.description)\n\(String(data: request.httpBody!, encoding: .utf8) ?? "empty")\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
            let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
            let payloadObject = jsonObject?["payload"] as? [String: Any]
            guard let txid = payloadObject?["txid"] as? String else {
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
                }
                return
            }
            
            // add an unconfirmed transaction, lock unconfirmed spent txo
            var newTransaction: ATCryptocurrencyTransaction? = nil
            try? self.dataStack.perform(synchronous: { (csDataTx) in
                let cstx = csDataTx.create(Into<CSTransaction>())
                cstx.txid.value = txid
                cstx.locktime.value = 0
                cstx.timestamp.value = Int32(bitPattern: UInt32(round(Date().timeIntervalSince1970)))
                cstx.confirmations.value = 0
                cstx.direction.value = ATCryptocurrencyTransaction.TransactionDirection.sent.rawValue
                cstx.amount.value = SatoshiToBitcoin(transaction.amount.uint64)
                cstx.fee.value = SatoshiToBitcoin(transaction.fee.uint64)
                cstx.destinationAddresses.value = transaction.address
                cstx.note.value = transaction.message
                newTransaction = ATCryptocurrencyTransaction(cstx, self.CRYPTOCURRENCY_TYPE)
                
                let txids = self.extractInputTxIds(signedTx)
                let vouts = self.extractInputTxVouts(signedTx)
                if txids.count == vouts.count {
                    for index in 0..<txids.count {
                        guard let utxo = try? csDataTx.fetchOne(From<CSUnspentTxOut>().where(\.txid == txids[index] && \.vout == Int32(vouts[index]))) else { continue }
                        utxo.locked.value = true
                    }
                }
            })
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidPublishTransaction(transaction)
                if let newTx = newTransaction {
                    self.transactions.insert(newTx, at: 0)
                    self.delegate?.abstractWalletDidUpdateTransaction()
                }
            }
            self.dispatchQueue.asyncAfter(deadline: .now() + self.AVERAGE_CONFIRMATION_TIME) {
                self.singleSync(txid)
            }
        }
        task.resume()
    }
}
