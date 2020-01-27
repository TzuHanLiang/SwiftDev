//
//  CAEthereumBasedWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/12/27.
//

import Foundation
import EthereumKit
import CryptoEthereumSwift
import BRCore
import CoreStore

fileprivate class CSAddressDetails : CoreStoreObject {
    var address = Value.Required<String>("address", initial: "")
    var balanceEther = Value.Required<String>("balanceEther", initial: "0")
    var totalEtherTxCount = Value.Required<Int32>("totalEtherTxCount", initial: 0)
    var etherInTxCount = Value.Required<Int32>("etherInCount", initial: 0)
    var etherOutTxCount = Value.Required<Int32>("etherOutTxCount", initial: 0)
    var lastSyncTime = Value.Required<Int32>("lastSyncTime", initial: 0)
    var totalTokenTxCount = Value.Required<Int32>("totalTokenTxCount", initial: 0)
    
    var etherTransactions = Relationship.ToManyUnordered<CSEtherTransaction>("etherTransactions", inverse: { $0.ownerDetail })
    var tokenDetails = Relationship.ToManyUnordered<CSTokenDetails>("tokenDetails", inverse: { $0.ownerDetail })
}

fileprivate class CSEtherTransaction : CoreStoreObject {
    var txHash = Value.Required<String>("txHash", initial: "")
    var from = Value.Required<String>("from", initial: "")
    var to = Value.Required<String>("to", initial: "")
    var timestamp = Value.Required<Int32>("timestamp", initial: 0)
    var nonce = Value.Required<Int32>("nonce", initial: 0)
    var confirmations = Value.Required<Int32>("confirmations", initial: 0)
    var block = Value.Required<Int32>("block", initial: 0)
    var value = Value.Required<String>("value", initial: "0")
    var gasPrice = Value.Required<String>("gasPrice", initial: "0")
    var gasUsed = Value.Required<String>("gasUsed", initial: "21000")
    
    var ownerDetail = Relationship.ToOne<CSAddressDetails>("ownerDetail")
}

fileprivate class CSTokenDetails : CoreStoreObject {
    var address = Value.Required<String>("address", initial: "")
    var contract = Value.Required<String>("contract", initial: "")
    var name = Value.Required<String>("name", initial: "")
    var symbol = Value.Required<String>("symbol", initial: "")
    var type = Value.Required<String>("type", initial: "")
    var decimals = Value.Required<Int>("decimals", initial: 0)
    var totalSupply = Value.Required<Double>("totalSupply", initial: 0)
    var amount = Value.Required<String>("amount", initial: "0")
    
    var ownerDetail = Relationship.ToOne<CSAddressDetails>("ownerDetail")
    var tokenTransactions = Relationship.ToManyUnordered<CSTokenTransaction>("tokenTransactions", inverse: { $0.ownerDetail })
}

fileprivate class CSTokenTransaction : CoreStoreObject {
    var txHash = Value.Required<String>("txHash", initial: "")
    var from = Value.Required<String>("from", initial: "")
    var to = Value.Required<String>("to", initial: "")
    var timestamp = Value.Required<Int32>("timestamp", initial: 0)
    var value = Value.Required<String>("value", initial: "0")
    
    var ownerDetail = Relationship.ToOne<CSTokenDetails>("ownerDetail")
}

fileprivate extension ATCryptocurrencyTransaction {
    convenience init?(_ transaction: CSEtherTransaction, _ currencyType: ATCryptocurrencyType) {
        guard let addressDetails = transaction.ownerDetail.value else { return nil }
        var direction: TransactionDirection = .sent
        (transaction.to.value.lowercased() == addressDetails.address.value.lowercased()) ? direction = .received : nil
        self.init(currencyType, direction, nil)
        
        guard let balanceWei = BInt(transaction.value.value, radix: 10) else { return nil }
        guard let balanceEther = try? Converter.toEther(wei: balanceWei) else { return nil }
        guard let gasPrice = BInt(transaction.gasPrice.value, radix: 10) else { return nil }
        guard let gasUsed = BInt(transaction.gasUsed.value, radix: 10) else { return nil }
        let feeWei = gasPrice * gasUsed
        guard let feeEther = try? Converter.toEther(wei: feeWei) else { return nil }
        
        switch direction {
        case .sent:
            self.address = transaction.to.value
            self.amount = ATUInt256(bint: balanceWei)
            self.amountString = balanceEther.toString()
            self.fee = ATUInt256(bint: feeWei)
            self.feeString = feeEther.toString()
            self.totalAmount = self.amount + self.fee
            self.totalAmountString = (balanceEther + feeEther).toString()
        case .received:
            self.address = transaction.from.value
            self.amount = ATUInt256(bint: balanceWei)
            self.amountString = balanceEther.toString()
            self.totalAmount = self.amount
            self.totalAmountString = self.amountString
        default:
            ATLog.error("impossible case")
            return nil
        }
        
        self.date = Date(timeIntervalSince1970: TimeInterval(UInt32(bitPattern: transaction.timestamp.value)))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
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
        
        self.detailDescription.append("""
        \n\n\(NSLocalizedString("transaction_id", tableName: nil, bundle: Bundle.main, value: "Transaction ID", comment: ""))
        \(transaction.txHash.value)
        """)
        
        (transaction.confirmations.value == 0) ? self.detailDescription.append("""
        \n\n\(NSLocalizedString("unconfirmed", tableName: nil, bundle: Bundle.main, value: "Unconfirmed", comment: ""))
        """) : nil
    }
    
    convenience init?(_ transaction: CSTokenTransaction, _ tokenInfo: ATTokenInfo, _ currencyType: ATCryptocurrencyType) {
        guard let tokenDetails = transaction.ownerDetail.value else { return nil }
        var direction: TransactionDirection = .sent
        (transaction.to.value.lowercased() == tokenDetails.address.value.lowercased()) ? direction = .received : nil
        self.init(currencyType, direction, nil)
        
        self.isTokenTransfer = true
        self.tokenInfo = tokenInfo
        self.tokenAmount = ATUInt256(bint: ATCryptocurrencyToken.stringToValue(transaction.value.value, tokenInfo.decimals))
        self.tokenAmountString = transaction.value.value
        self.address = (direction == .sent) ? transaction.to.value : transaction.from.value
        
        self.date = Date(timeIntervalSince1970: TimeInterval(UInt32(bitPattern: transaction.timestamp.value)))
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
        self.detailDescription = """
        \(NSLocalizedString("date", tableName: nil, bundle: Bundle.main, value: "Date", comment: ""))
        \(dateFormatter.string(from: self.date))
        
        \(self.direction.description)
        \(self.tokenAmountString) \(tokenInfo.symbol)
        """
        
        (self.direction != .moved) ? self.detailDescription.append("""
        \n\n\(NSLocalizedString((self.direction == .sent) ? "to" : "from", tableName: nil, bundle: Bundle.main, value: (self.direction == .sent) ? "To" : "From", comment: "")) \(self.address)
        """) : nil
        
        self.detailDescription.append("""
        \n\n\(NSLocalizedString("transaction_id", tableName: nil, bundle: Bundle.main, value: "Transaction ID", comment: ""))
        \(transaction.txHash.value)
        """)
    }
    
    convenience init?(_ ownAddress: String, _ toAddress: String, _ amount: Ether, _ fee: Ether, _ currencyType: ATCryptocurrencyType, _ object: AnyObject?) {
        self.init(currencyType, .received, object)
        guard let amountWei = try? Converter.toWei(ether: amount) else { return nil }
        guard let feeWei = try? Converter.toWei(ether: fee) else { return nil }
        self.ownAddress = ownAddress
        self.address = toAddress
        self.amount = ATUInt256(bint: amountWei)
        self.amountString = amount.toString()
        self.fee = ATUInt256(bint: feeWei)
        self.feeString = fee.toString()
        self.totalAmount = self.amount + self.fee
        self.totalAmountString = (amount + fee).toString()
    }
    
    convenience init?(_ ownAddress: String, _ toAddress: String, _ amount: BInt, _ gasPrice: BInt, _ currencyType: ATCryptocurrencyType, _ tokenInfo: ATTokenInfo, _ object: AnyObject?) {
        self.init(currencyType, .received, object)
        self.isTokenTransfer = true
        self.tokenInfo = tokenInfo
        self.ownAddress = ownAddress
        self.address = toAddress
        self.amount = ATUInt256(0)
        self.amountString = "0"
        self.tokenAmount = ATUInt256(bint: amount)
        self.tokenAmountString = ATCryptocurrencyToken.valueToString(amount, tokenInfo.decimals)
        self.fee = ATUInt256(bint: gasPrice)
        self.feeString = ATCryptocurrencyToken.valueToString(gasPrice, 9) // convert to GWEI
    }
}

fileprivate let ONE_GWEI = BInt(UInt(1000000000))

class CAEthereumBasedWallet: ATAbstractWallet {
    
    internal var NETWORK = "mainnet"
    internal var CHAIN_ID = Network.mainnet.chainID
    
    internal var SYNC_INTERVAL: TimeInterval = 60 * 2 // seconds
    internal var CRYPTOCURRENCY_TYPE: ATCryptocurrencyType = ATCryptocurrencyType.eth
    internal var API_KEY: String = ATConstants.CRYPTOAPIS_API_KEY_ETHEREUM
    
    internal var LOW_GAS_PRICE = BInt(UInt(500000000)) // 0.5 GWei
    internal var MEDIUM_GAS_PRICE = ONE_GWEI * BInt(3) // 3 GWei
    internal var HIGH_GAS_PRICE = ONE_GWEI * BInt(8) // 8 GWei
    
    private let MIN_GAS_PRICE = BInt(1) // 1 Wei
    private let ETHER_TX_GAS = BInt(21000)
    private let ETHER_TX_GAS_LIMIT = BInt(21000)
    private let TOKEN_TX_GAS_LIMIT = BInt(200000)
    
    private let uid: [UInt8]
    private let extendedPublicKey: BRMasterPubKey
    private let dispatchQueue: DispatchQueue
    private let dataStack: DataStack
    private var balance: BInt
    private var etherTransactions: [ATCryptocurrencyTransaction]
    private var tokens: [ATCryptocurrencyToken]
    private var appUniqueId: String?
    private var isSyncing = false
    private var lastSyncTime = Date(timeIntervalSince1970: 0)
    private var syncTimer: Timer?
    
    private var isSyncNeeded: Bool {
        return abs(self.lastSyncTime.timeIntervalSinceNow) > self.SYNC_INTERVAL
    }
    
    init?(UniqueId uid: [UInt8], EarlistKeyTime timestamp: UInt32, PublicKey pubKey: [UInt8], ChainCode chainCode: [UInt8], FingerprintOfParentKey fingerprint: UInt32, Delegate delegate: ATAbstractWalletDelegate) {
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
        self.dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.CAEthereumBasedWallet.\(Data(uid).toHexString())")
        self.dataStack = DataStack(CoreStoreSchema(modelVersion: "V1", entities: [Entity<CSAddressDetails>("CSAddressDetails"), Entity<CSEtherTransaction>("CSEtherTransaction"), Entity<CSTokenDetails>("CSTokenDetails"), Entity<CSTokenTransaction>("CSTokenTransaction")]))
        
        self.balance = BInt(0)
        self.etherTransactions = []
        self.tokens = []
                
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
        
        // TODO: what if there are multiple addresses
        if let addressDetails = try? self.dataStack.fetchOne(From<CSAddressDetails>()) {
            self.lastSyncTime = Date(timeIntervalSince1970: TimeInterval(UInt32(bitPattern: addressDetails.lastSyncTime.value)))
        }
        loadEtherBalance()
        loadEtherTransactions()
        loadTokens()
        
        if let appUid = UserDefaults.standard.object(forKey: "APP_UID") as? [UInt8], appUid.count == 16 {
            let uuid = UUID(uuid: (appUid[0], appUid[1], appUid[2], appUid[3], appUid[4], appUid[5], appUid[6], appUid[7],
                                   appUid[8], appUid[9], appUid[10], appUid[11], appUid[12], appUid[13], appUid[14], appUid[15]))
            self.appUniqueId = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        }
    }
    
    private func loadEtherBalance() {
        guard let addressesDetails = try? self.dataStack.fetchAll(From<CSAddressDetails>()) else { return }
        var balanceWei = BInt(0)
        for addressDetails in addressesDetails {
            guard let wei = try? Converter.toWei(ether: addressDetails.balanceEther.value) else {
                ATLog.error("Failed to conver ether to wei")
                continue
            }
            balanceWei += wei
        }
        self.balance = balanceWei
    }
    
    private func loadEtherTransactions() {
        guard let csEtherTransactions = try? self.dataStack.fetchAll(From<CSEtherTransaction>().orderBy(.descending(\.timestamp))), csEtherTransactions.count > 0 else {
            self.etherTransactions = []
            return
        }
        var etherTransactions: [ATCryptocurrencyTransaction] = []
        for csEtherTransaction in csEtherTransactions {
            guard let etherTransaction = ATCryptocurrencyTransaction(csEtherTransaction, self.CRYPTOCURRENCY_TYPE) else {
                ATLog.warning("Failed to conver CSEtherTransaction to ATCryptocurrencyTransaction")
                continue
            }
            etherTransactions.append(etherTransaction)
        }
        self.etherTransactions = etherTransactions
    }
    
    private func loadTokens() {
        guard let tokensDetails = try? self.dataStack.fetchAll(From<CSTokenDetails>()), tokensDetails.count > 0 else { return }
        var tokens: [String: ATCryptocurrencyToken] = [:]
        for tokenDetails in tokensDetails {
            let token = tokens[tokenDetails.contract.value] ?? ATCryptocurrencyToken(ATTokenInfo(address: tokenDetails.contract.value, name: tokenDetails.name.value, symbol: tokenDetails.symbol.value, type: tokenDetails.type.value, decimals: UInt(bitPattern: tokenDetails.decimals.value), totalSupply: tokenDetails.totalSupply.value))
            token.balance += ATCryptocurrencyToken.stringToValue(tokenDetails.amount.value, UInt(bitPattern: tokenDetails.decimals.value))
            for cstx in tokenDetails.tokenTransactions.value {
                guard let tx = ATCryptocurrencyTransaction(cstx, token.info, self.CRYPTOCURRENCY_TYPE) else { continue }
                token.transactions.append(tx)
            }
            tokens[token.info.address] = token
        }
        for token in tokens.values {
            token.transactions.sort { (tx1, tx2) -> Bool in
                return tx1.date.timeIntervalSince1970 > tx2.date.timeIntervalSince1970
            }
        }
        
        var oldTokens = self.tokens
        for token in tokens.values {
            var found = false
            for oldToken in oldTokens {
                if token.info.address == oldToken.info.address {
                    found = true
                    oldToken.balance = token.balance
                    oldToken.transactions = token.transactions
                }
            }
            (!found) ? oldTokens.append(token) : nil
        }
        
        let sortedTokens = oldTokens.sorted { (token1, token2) -> Bool in
            return token1.info.name.compare(token2.info.name) == ComparisonResult.orderedAscending
        }
        self.tokens = sortedTokens
    }
    
    private func getAddressDetails(_ address: String) -> (balance: String, txCount: Int, txinCount: Int, txoutCount: Int)? {
        let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/address/\(address)\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
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
        let session = URLSession(configuration: config)
        let semaphore = DispatchSemaphore(value: 0)
        var balance: String?
        var txCount: Int?
        var txinCount: Int?
        var txoutCount: Int?
        var retryCount = 0
        var done = false
        while !done && retryCount < 3 {
            let task = session.dataTask(with: request) { (data, response, error) in
                guard error == nil else {
                    ATLog.debug("\(error!)")
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                guard let jsonData = data else {
                    ATLog.debug("No data received")
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                
                let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                guard let payloadObject = jsonObject?["payload"] as? [String: Any] else {
                    ATLog.debug("payload not found")
                    if let metaObject = jsonObject?["meta"] as? [String: Any], let errorObject = metaObject["error"] as? [String: Any], let code = errorObject["code"] as? Int, code == 63 { // request limit reached
                        sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                    }
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                balance = payloadObject["balance"] as? String
                txCount = payloadObject["txs_count"] as? Int
                txinCount = payloadObject["from"] as? Int
                txoutCount = payloadObject["to"] as? Int
                done = true
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
        guard balance != nil, txCount != nil, txinCount != nil, txoutCount != nil else { return nil }
        return (balance!, txCount!, txinCount!, txoutCount!)
    }
    
    private func parseEtherTransaction(_ address: String, _ tx: [String: Any]) {
        guard let from = tx["from"] as? String else {
            ATLog.debug("from not found")
            return
        }
        guard let to = tx["to"] as? String else {
            ATLog.debug("to not found")
            return
        }
        guard let hash = tx["hash"] as? String else {
            ATLog.debug("from not found")
            return
        }
        guard let value = tx["value"] as? String else {
            ATLog.debug("value not found")
            return
        }
        guard let timestamp = tx["timestamp"] as? UInt32 else {
            ATLog.debug("timestamp not found")
            return
        }
        guard let nonce = tx["nonce"] as? UInt32 else {
            ATLog.debug("nonce not found")
            return
        }
        guard let confirmations = tx["confirmations"] as? UInt32 else {
            ATLog.debug("confirmations not found")
            return
        }
        guard let block = tx["block"] as? UInt32 else {
            ATLog.debug("block not found")
            return
        }
        guard let gasPrice = tx["gas_price"] as? String else {
            ATLog.debug("gas_price not found")
            return
        }
        guard let gasUsed = tx["gas_used"] as? String else {
            ATLog.debug("gas_used not found")
            return
        }
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            var csEtherTransaction: CSEtherTransaction
            if let item = try? transaction.fetchOne(From<CSEtherTransaction>().where(\.txHash == hash)) {
                csEtherTransaction = item
            }
            else {
                csEtherTransaction = transaction.create(Into<CSEtherTransaction>())
                csEtherTransaction.txHash.value = hash
                // TODO: what if moving ether beteen two of owned addresses?
                if let csAddressDetails = try? transaction.fetchOne(From<CSAddressDetails>().where(\.address == address)) {
                    csEtherTransaction.ownerDetail.value = csAddressDetails
                }
            }
            csEtherTransaction.from.value = from
            csEtherTransaction.to.value = to
            csEtherTransaction.value.value = value
            csEtherTransaction.timestamp.value = Int32(bitPattern: timestamp)
            csEtherTransaction.nonce.value = Int32(bitPattern: nonce)
            csEtherTransaction.confirmations.value = Int32(bitPattern: confirmations)
            csEtherTransaction.block.value = Int32(bitPattern: block)
            csEtherTransaction.gasPrice.value = gasPrice
            csEtherTransaction.gasUsed.value = gasUsed
        })
    }
    
    private func syncEther(_ address: String) {
        guard let addressDetails = getAddressDetails(address) else { return }
        var syncedTxCount = 0
        if let csAddressDetails = try? self.dataStack.fetchOne(From<CSAddressDetails>().where(\.address == address)) {
            for tx in csAddressDetails.etherTransactions {
                (tx.confirmations.value > 0) ? syncedTxCount += 1 : nil
            }
            guard syncedTxCount < addressDetails.txCount else {
                (syncedTxCount > addressDetails.txCount) ? ATLog.warning("This should not happen!") : nil
                return
            }
        }
        else {
            try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                let csAddressDetails = transaction.create(Into<CSAddressDetails>())
                csAddressDetails.address.value = address
                csAddressDetails.balanceEther.value = addressDetails.balance
                csAddressDetails.totalEtherTxCount.value = Int32(addressDetails.txCount)
                csAddressDetails.etherInTxCount.value = Int32(addressDetails.txinCount)
                csAddressDetails.etherOutTxCount.value = Int32(addressDetails.txoutCount)
            })
        }
        
        // Sync Transactions
        var txIndex = 0
        let maxTxNumber = 50
        let semaphore = DispatchSemaphore(value: 0)
        var retryCount = 0
        var done = false
        while !done && retryCount < 3 {
            let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/address/\(address)/transactions?index=\(txIndex)&limit=\(maxTxNumber)\((self.appUniqueId != nil) ? "&uid=\(self.appUniqueId!)" : "")"
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
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: request) { (data, response, error) in
                guard error == nil else {
                    ATLog.debug("\(error!)")
                    done = true
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
                let metaObject = jsonObject?["meta"] as? [String: Any]
                
                if let errorObject = metaObject?["error"] as? [String: Any] {
                    if let code = errorObject["code"] as? Int, code == 63 { // request limit reached
                        sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                    }
                    retryCount += 1
                    semaphore.signal()
                    return
                }

                guard let results = metaObject?["results"] as? Int else {
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                
                /*
                guard let totalCount = metaObject?["totalCount"] as? Int else {
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                */
                
                guard results > 0 else {
                    done = true
                    semaphore.signal()
                    return
                }
                
                retryCount = 0
                
                let payloadObject = jsonObject?["payload"] as? [[String: Any]]
                for tx in payloadObject ?? [] {
                    self.parseEtherTransaction(address, tx)
                }
                
                guard let csAddressDetails = try? self.dataStack.fetchOne(From<CSAddressDetails>().where(\.address == address)) else {
                    ATLog.warning("This should not happen!")
                    done = true
                    semaphore.signal()
                    return
                }
                syncedTxCount = csAddressDetails.etherTransactions.count
                
                if addressDetails.txCount > syncedTxCount, results == maxTxNumber {
                    txIndex += results
                }
                else {
                    done = true
                }
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
        
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            var csAddressDetails: CSAddressDetails
            if let item = try? transaction.fetchOne(From<CSAddressDetails>().where(\.address == address)) {
                csAddressDetails = item
            }
            else {
                csAddressDetails = transaction.create(Into<CSAddressDetails>())
                csAddressDetails.address.value = address
            }
            csAddressDetails.balanceEther.value = addressDetails.balance
            csAddressDetails.totalEtherTxCount.value = Int32(addressDetails.txCount)
            csAddressDetails.etherInTxCount.value = Int32(addressDetails.txinCount)
            csAddressDetails.etherOutTxCount.value = Int32(addressDetails.txoutCount)
            let timestamp = UInt32(round(Date().timeIntervalSince1970))
            csAddressDetails.lastSyncTime.value = Int32(bitPattern: timestamp)
        })
    }
    
    private func getOwnedTokensInfo(_ address: String) -> [ATTokenInfo] {
        // Get Owned Tokens
        var ownedTokens: [(contract: String, symbol: String, name: String, type: String)] = []
        var tokensInfo: [ATTokenInfo] = []
        var tokenIndex = 0
        let maxResultNumber = 50
        let semaphore = DispatchSemaphore(value: 0)
        var retryCount = 0
        var done = false
        while !done && retryCount < 3 {
            let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/tokens/address/\(address)?index=\(tokenIndex)&limit=\(maxResultNumber)\((self.appUniqueId != nil) ? "&uid=\(self.appUniqueId!)" : "")"
            guard let url = URL(string: urlString) else {
                ATLog.debug("Failed to create URL: \(urlString)")
                return []
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
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                guard let jsonData = data else {
                    ATLog.debug("No data received")
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                
                let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                let metaObject = jsonObject?["meta"] as? [String: Any]
                
                if let errorObject = metaObject?["error"] as? [String: Any] {
                    if let code = errorObject["code"] as? Int, code == 63 { // request limit reached
                        sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                    }
                    retryCount += 1
                    semaphore.signal()
                    return
                }

                guard let results = metaObject?["results"] as? Int else {
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                
                guard let totalCount = metaObject?["totalCount"] as? Int else {
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                
                guard results > 0 else {
                    done = true
                    semaphore.signal()
                    return
                }
                
                retryCount = 0
                let payloadObject = jsonObject?["payload"] as? [[String: Any]]
                for tokenObject in payloadObject ?? [] {
                    guard let contract = tokenObject["contract"] as? String else { continue }
                    guard let symbol = tokenObject["symbol"] as? String else { continue }
                    guard let name = tokenObject["name"] as? String else { continue }
                    guard let type = tokenObject["type"] as? String else { continue }
                    let ownedToken = (contract, symbol, name, type)
                    ownedTokens.append(ownedToken)
                }
                
                if totalCount > (tokenIndex + results) {
                    tokenIndex += results
                }
                else {
                    done = true
                }
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
        
        // Get Token Decimals and Total Supply
        for ownedToken in ownedTokens {
            if let csTokenDetails = try? self.dataStack.fetchOne(From<CSTokenDetails>().where(\.contract == ownedToken.contract)) {
                let decimals = UInt(bitPattern: csTokenDetails.decimals.value)
                let totalSupply = csTokenDetails.totalSupply.value
                if decimals > 0, totalSupply > 0 {
                    let tokenInfo = ATTokenInfo(address: ownedToken.contract, name: ownedToken.name, symbol: ownedToken.symbol, type: ownedToken.type, decimals: decimals, totalSupply: totalSupply)
                    tokensInfo.append(tokenInfo)
                    continue
                }
            }
            
            var retryCount = 0
            var done = false
            while !done && retryCount < 3 {
                let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/tokens/contract/\(ownedToken.contract)\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
                guard let url = URL(string: urlString) else {
                    ATLog.debug("Failed to create URL: \(urlString)")
                    return []
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
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    guard let jsonData = data else {
                        ATLog.debug("No data received")
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                    
                    let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                    guard let payloadObject = jsonObject?["payload"] as? [String: Any] else {
                        ATLog.debug("payload not found")
                        if let metaObject = jsonObject?["meta"] as? [String: Any], let errorObject = metaObject["error"] as? [String: Any], let code = errorObject["code"] as? Int, code == 63 {
                            sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                        }
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    guard let decimals = payloadObject["decimals"] as? UInt else {
                        ATLog.debug("decimals not found")
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    guard let totalSupply = payloadObject["totalSupply"] as? Double else {
                        ATLog.debug("totalSupply not found")
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    retryCount = 0
                    let tokenInfo = ATTokenInfo(address: ownedToken.contract, name: ownedToken.name, symbol: ownedToken.symbol, type: ownedToken.type, decimals: decimals, totalSupply: totalSupply)
                    tokensInfo.append(tokenInfo)
                    done = true
                    semaphore.signal()
                }
                task.resume()
                semaphore.wait()
            }
        }
        return tokensInfo
    }
    
    private func syncTokenBalance(_ address: String, _ contract: String) {
        var balance: String?
        let semaphore = DispatchSemaphore(value: 0)
        var retryCount = 0
        var done = false
        while !done && retryCount < 3 {
            let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/tokens/\(address)/\(contract)/balance\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
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
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: request) { (data, response, error) in
                guard error == nil else {
                    ATLog.debug("\(error!)")
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                guard let jsonData = data else {
                    ATLog.debug("No data received")
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                
                let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                let payloadObject = jsonObject?["payload"] as? [String: Any]
                guard let token = payloadObject?["token"] as? String else {
                    ATLog.debug("token not found")
                    if let metaObject = jsonObject?["meta"] as? [String: Any], let errorObject = metaObject["error"] as? [String: Any], let code = errorObject["code"] as? Int, code == 63 {
                        sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                    }
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                retryCount = 0
                balance = token
                done = true
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
        
        if let balanceString = balance {
            try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                guard let csTokenDetails = try? transaction.fetchOne(From<CSTokenDetails>().where(\.address == address && \.contract == contract)) else {
                    ATLog.warning("csTokenDetails not found")
                    return
                }
                csTokenDetails.amount.value = balanceString
            })
        }
    }
    
    private func parseTokenTransaction(_ address: String, _ tx: [String: Any]) {
        guard let from = tx["from"] as? String else {
            ATLog.debug("from not found")
            return
        }
        guard let to = tx["to"] as? String else {
            ATLog.debug("to not found")
            return
        }
        guard let txHash = tx["txHash"] as? String else {
            ATLog.debug("from not found")
            return
        }
        guard let value = tx["value"] as? String else {
            ATLog.debug("value not found")
            return
        }
        guard let timestamp = tx["timestamp"] as? UInt32 else {
            ATLog.debug("timestamp not found")
            return
        }
        guard let name = tx["name"] as? String else {
            ATLog.debug("name not found")
            return
        }
        guard let symbol = tx["symbol"] as? String else {
            ATLog.debug("symbol not found")
            return
        }
        guard let type = tx["type"] as? String else {
            ATLog.debug("type not found")
            return
        }
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            var csTokenTransaction: CSTokenTransaction
            if let item = try? transaction.fetchOne(From<CSTokenTransaction>().where(\.txHash == txHash)) {
                csTokenTransaction = item
            }
            else {
                csTokenTransaction = transaction.create(Into<CSTokenTransaction>())
                csTokenTransaction.txHash.value = txHash
                if let csTokenDetails = try? transaction.fetchOne(From<CSTokenDetails>().where(\.address == address).where(\.name == name && \.symbol == symbol && \.type == type)) {
                    csTokenTransaction.ownerDetail.value = csTokenDetails
                }
            }
            csTokenTransaction.from.value = from
            csTokenTransaction.to.value = to
            csTokenTransaction.value.value = value
            csTokenTransaction.timestamp.value = Int32(bitPattern: timestamp)
        })
    }
    
    private func syncTokenTransactions(_ address: String) {
        guard let csAddressDetails = try? self.dataStack.fetchOne(From<CSAddressDetails>().where(\.address == address)) else { return }
        var syncedTxCount = 0
        for tokenDetail in csAddressDetails.tokenDetails {
            syncedTxCount += tokenDetail.tokenTransactions.count
        }
        
        var txIndex = 0
        var totalTxCount = 0
        //let maxTxNumber = 50
        let maxTxNumber = 1000 // TODO: specifying a huge limit number because this API doesn't accept the index parameter, CryptoAPIs will fix it later
        let semaphore = DispatchSemaphore(value: 0)
        var retryCount = 0
        var done = false
        while !done && retryCount < 3 {
            // Note: currently this API doesn't allow to specify index parameter
            let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/tokens/address/\(address)/transfers?index=\(txIndex)&limit=\(maxTxNumber)\((self.appUniqueId != nil) ? "&uid=\(self.appUniqueId!)" : "")"
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
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: request) { (data, response, error) in
                guard error == nil else {
                    ATLog.debug("\(error!)")
                    done = true
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
                let metaObject = jsonObject?["meta"] as? [String: Any]
                
                if let errorObject = metaObject?["error"] as? [String: Any] {
                    if let code = errorObject["code"] as? Int, code == 63 { // request limit reached
                        sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                    }
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                
                guard let results = metaObject?["results"] as? Int else {
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                
                guard let totalCount = metaObject?["totalCount"] as? Int else {
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                (totalTxCount == 0) ? totalTxCount = totalCount : nil
                
                guard results > 0 else {
                    done = true
                    semaphore.signal()
                    return
                }
                
                retryCount = 0
                                
                let payloadObject = jsonObject?["payload"] as? [[String: Any]]
                for tx in payloadObject ?? [] {
                    self.parseTokenTransaction(address, tx)
                }
                
                guard syncedTxCount < totalTxCount else {
                    done = true
                    syncedTxCount = totalTxCount
                    semaphore.signal()
                    return
                }
                
                guard let csAddressDetails = try? self.dataStack.fetchOne(From<CSAddressDetails>().where(\.address == address)) else {
                    ATLog.warning("This should not happen!")
                    done = true
                    semaphore.signal()
                    return
                }
                syncedTxCount = 0
                for tokenDetail in csAddressDetails.tokenDetails {
                    syncedTxCount += tokenDetail.tokenTransactions.count
                }
                
                if totalTxCount > syncedTxCount, results == maxTxNumber {
                    txIndex += results
                }
                else {
                    done = true
                }
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
        try? self.dataStack.perform(synchronous: { (transaction) -> Void in
            guard let csAddressDetails = try? transaction.fetchOne(From<CSAddressDetails>().where(\.address == address)) else { return }
            csAddressDetails.totalTokenTxCount.value = Int32(totalTxCount)
        })
    }
    
    private func syncTokens(_ address: String) {
        let tokensInfo = getOwnedTokensInfo(address)
        for tokenInfo in tokensInfo {
            try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                var csTokenDetails: CSTokenDetails
                if let item = try? transaction.fetchOne(From<CSTokenDetails>().where(\.address == address && \.contract == tokenInfo.address)) {
                    csTokenDetails = item
                }
                else {
                    csTokenDetails = transaction.create(Into<CSTokenDetails>())
                    csTokenDetails.address.value = address
                    csTokenDetails.contract.value = tokenInfo.address
                    if let csAddressDetails = try? transaction.fetchOne(From<CSAddressDetails>().where(\.address == address)) {
                        csTokenDetails.ownerDetail.value = csAddressDetails
                    }
                }
                csTokenDetails.name.value = tokenInfo.name
                csTokenDetails.type.value = tokenInfo.type
                csTokenDetails.symbol.value = tokenInfo.symbol
                csTokenDetails.decimals.value = Int(bitPattern: tokenInfo.decimals)
                csTokenDetails.totalSupply.value = tokenInfo.totalSupply
            })
            syncTokenBalance(address, tokenInfo.address)
        }
        syncTokenTransactions(address)
    }
    
    private func syncAddress(_ address: String) {
        let originalBalance = self.balance
        let originalEtherTxCount = self.etherTransactions.count
        syncEther(address)
        loadEtherBalance()
        loadEtherTransactions()
        DispatchQueue.main.async {
            if self.balance != originalBalance {
                self.delegate?.abstractWalletDidUpdateBalance(ATUInt256(bint: self.balance))
            }
            if self.etherTransactions.count != originalEtherTxCount {
                self.delegate?.abstractWalletDidUpdateTransaction()
            }
        }
        
        let originalTokenCount = self.tokens.count
        var originalTokensTxCount: [Int] = []
        for token in self.tokens {
            originalTokensTxCount.append(token.transactions.count)
        }
        syncTokens(address)
        loadTokens()
        guard self.tokens.count > 0 else { return }
        DispatchQueue.main.async {
            guard self.tokens.count == originalTokenCount else {
                self.delegate?.abstractWalletDidUpdateTokens()
                return
            }
            var updateNeeded = false
            for index in 0..<originalTokensTxCount.count {
                if self.tokens[index].transactions.count != originalTokensTxCount[index] {
                    updateNeeded = true
                    break
                }
            }
            updateNeeded ? self.delegate?.abstractWalletDidUpdateTokens() : nil
        }
    }
    
    private func sync() {
        // TODO: to support multiple addresses?
        guard let pubkey = self.extendedPublicKey.deriveUncompressedPubKey(0, 0) else {
            ATLog.error("Failed to derive public key")
            return
        }
        guard !self.isSyncing else { return }
        self.isSyncing = true
        let address = PublicKey(raw: Data(pubkey)).address()
        syncAddress(address.lowercased())
        self.isSyncing = false
        
        self.lastSyncTime = Date()
    }
    
    private func calculateTransactionFee(_ gasPrice: BInt) -> BInt {
        let fee = gasPrice * self.ETHER_TX_GAS
        return fee
    }
    
    private func getNonce(_ address: String) -> Int? {
        let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/address/\(address)/nonce\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
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
        let session = URLSession(configuration: config)
        let semaphore = DispatchSemaphore(value: 0)
        var nonce: Int?
        var retryCount = 0
        var done = false
        while !done && retryCount < 3 {
            let task = session.dataTask(with: request) { (data, response, error) in
                guard error == nil else {
                    ATLog.debug("\(error!)")
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                guard let jsonData = data else {
                    ATLog.debug("No data received")
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                
                let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                guard let payloadObject = jsonObject?["payload"] as? [String: Any] else {
                    ATLog.debug("payload not found")
                    if let metaObject = jsonObject?["meta"] as? [String: Any], let errorObject = metaObject["error"] as? [String: Any], let code = errorObject["code"] as? Int, code == 63 { // request limit reached
                        sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                    }
                    retryCount += 1
                    semaphore.signal()
                    return
                }
                nonce = payloadObject["nonce"] as? Int
                done = true
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
        }
        return nonce
    }
    
    override func startSync(_ autoSync: Bool = true) {
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidStartSync()
            }
            self.isSyncNeeded ? self.sync() : nil
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidUpdateBalance(self.getBalance())
                self.delegate?.abstractWalletDidStopSync(nil)
                // TODO: check webhook, if webhook doesn't work, enable auto sync
                if autoSync {
                    self.syncTimer?.invalidate()
                    // check if sync is needed every 60 seconds
                    self.syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true, block: { (timer) in
                        guard !self.isSyncing else { return }
                        self.dispatchQueue.async {
                            self.isSyncNeeded ? self.sync() : nil
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
    
    override func getBalance() -> ATUInt256 {
        ATLog.debug("\(#function)")
        return ATUInt256(bint: self.balance)
    }
    
    override func getBalanceString() -> String {
        ATLog.debug("\(#function)")
        guard let ether = try? Converter.toEther(wei: self.balance) else { return "0" }
        return ether.toString()
    }
    
    override func getTransactions() -> [ATCryptocurrencyTransaction] {
        ATLog.debug("\(#function)")
        return self.etherTransactions
    }
    
    override func getTokens() -> [ATCryptocurrencyToken]? {
        ATLog.debug("\(#function)")
        return self.tokens
    }
    
    override func getReceivingAddress() -> String {
        ATLog.debug("\(#function)")
        guard let pubkey = self.extendedPublicKey.deriveUncompressedPubKey(0, 0) else { return "" }
        let address = PublicKey(raw: Data(pubkey)).address()
        return address
    }
    
    override func getReceivingAddressesWithFormat() -> [String: String]? {
        ATLog.debug("\(#function)")
        // TODO: to support multiple addresses?
        guard let pubkey = self.extendedPublicKey.deriveUncompressedPubKey(0, 0) else { return nil }
        let address = PublicKey(raw: Data(pubkey)).address()
        return ["Address": address]
    }
    
    override func checkAddressValidity(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        guard address.count == 42, address.hasPrefix("0x"), address.isAlphanumeric else { return false }
        let addressData = Data(hex: address)
        guard addressData.count == 20 else { return false }
        
        let hasUppercase = address.contains(where: { (c) -> Bool in
            for letter in "ABCDEF" {
                if c == letter { return true }
            }
            return false
        })
        let hasLowercase = address.contains(where: { (c) -> Bool in
            for letter in "abcdef" {
                if c == letter { return true }
            }
            return false
        })
        guard hasUppercase && hasLowercase else { return true } // Address doesn't use EIP-55
        
        return address.hasSuffix(EIP55.encode(addressData))
    }
    
    override func containAddress(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        // there's no need to check if it always uses the first external public key as the only one receiving address
        // TODO: to support multiple addresses?
        guard let pubkey = self.extendedPublicKey.deriveUncompressedPubKey(0, 0) else { return true }
        let ownAddress = PublicKey(raw: Data(pubkey)).address()
        return address.lowercased() == ownAddress.lowercased()
    }
    
    override func calculateMinimumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = calculateTransactionFee(self.MIN_GAS_PRICE)
        guard let ether = try? Converter.toEther(wei: wei) else { return "0.000000000000021" }
        return ether.toString()
    }
    
    override func calculateLowFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = calculateTransactionFee(self.LOW_GAS_PRICE)
        guard let ether = try? Converter.toEther(wei: wei) else { return "0.0000105" }
        return ether.toString()
    }
    
    override func calculateMediumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = calculateTransactionFee(self.MEDIUM_GAS_PRICE)
        guard let ether = try? Converter.toEther(wei: wei) else { return "0.000063" }
        return ether.toString()
    }
    
    override func calculateHighFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = calculateTransactionFee(self.HIGH_GAS_PRICE)
        guard let ether = try? Converter.toEther(wei: wei) else { return "0.000168" }
        return ether.toString()
    }
    
    override func getMaxOutputAmount() -> String {
        ATLog.debug("\(#function)")
        guard let balanceEther = try? Converter.toEther(wei: self.balance) else { return "0" }
        guard let feeEther = try? Converter.toEther(wei: calculateTransactionFee(self.MIN_GAS_PRICE)) else { return "0" }
        guard balanceEther > feeEther else { return "0" }
        var maxOutput = balanceEther - feeEther
        let unconfirmedTxs = try? self.dataStack.fetchAll(From<CSEtherTransaction>().where(\.confirmations == 0))
        for tx in unconfirmedTxs ?? [] {
            guard let wei = Wei(tx.value.value, radix: 10), let ether = try? Converter.toEther(wei: wei) else { continue }
            maxOutput -= ether
        }
        guard maxOutput > 0 else { return "0" }
        return maxOutput.toString()
    }
    
    override func getMinOutputAmount() -> String {
        ATLog.debug("\(#function)")
        return "0"
    }
    
    override func createTransaction(_ amount: String, _ fee: String, _ address: String, _ message: String? = nil) -> ATCryptocurrencyTransaction? {
        ATLog.debug("\(#function)")
        guard checkAddressValidity(address) else {
            ATLog.debug("Invalid address")
            return nil
        }
        guard let amountEther = Ether(string: amount), let amountWei = try? Converter.toWei(ether: amountEther) else { return nil }
        guard let feeEther = Ether(string: fee), let feeWei = try? Converter.toWei(ether: feeEther) else { return nil }
        guard feeWei >= self.ETHER_TX_GAS else {
            ATLog.debug("Transaction fee is not enough")
            return nil
        }
        // TODO: what if this account owns mulitple addresses?
        guard let csAddressDetails = try? self.dataStack.fetchOne(From<CSAddressDetails>()) else { return nil }
        let ownAddress = csAddressDetails.address.value
        let nonce = csAddressDetails.etherOutTxCount.value
        let gasLimit = self.ETHER_TX_GAS_LIMIT.magnitude
        let gasPrice = (feeWei / self.ETHER_TX_GAS).magnitude
        let rawTx = RawTransaction(value: amountWei, to: address, gasPrice: Int(gasPrice), gasLimit: Int(gasLimit), nonce: Int(nonce))
        return ATCryptocurrencyTransaction(ownAddress, address.lowercased(), amountEther, feeEther, self.CRYPTOCURRENCY_TYPE, rawTx as AnyObject)
    }
    
    override func destroyTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        transaction.object = nil
    }
    
    override func generateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard var rawTx = transaction.object as? RawTransaction, let ownAddress = transaction.ownAddress else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
            }
            return
        }
        self.dispatchQueue.async {
            if let newNonce = self.getNonce(ownAddress), newNonce != rawTx.nonce {
                let newRawTx = RawTransaction(wei: rawTx.value.asString(withBase: 10), to: rawTx.to.string, gasPrice: rawTx.gasPrice, gasLimit: rawTx.gasLimit, nonce: newNonce, data: rawTx.data)
                transaction.object = newRawTx as AnyObject
                rawTx = newRawTx
            }
            let signer = EIP155Signer.init(chainID: self.CHAIN_ID)
            guard let hash = try? signer.hash(rawTransaction: rawTx) else {
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
                }
                return
            }
            // TODO: find out which chainId and keyId the transaction.ownAddress is for supporting multiple addresses
            let unsignedTxData = ATCryptocurrencyTransaction.UnsignedTransactionDataInfo(chainId: 0, keyId: 0, data: ATUInt256(hash.bytes))
            transaction.unsignedTransactionDataInfos = [unsignedTxData]
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidGenerateTransactionDataForSigning(transaction)
            }
        }
    }
    
    override func generateSignedTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let rawTx = transaction.object as? RawTransaction else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            }
            return
        }
        guard let signature = transaction.rsvSignatures?.first else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            }
            return
        }
        self.dispatchQueue.async {
            let signer = EIP155Signer.init(chainID: self.CHAIN_ID)
            let (r, s, v) = signer.calculateRSV(signature: signature)
            guard let serializedData = try? RLP.encode([rawTx.nonce, rawTx.gasPrice, rawTx.gasLimit, rawTx.to.data, rawTx.value, rawTx.data, v, r, s]) else {
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
                }
                return
            }
            let serializedHexString = serializedData.toHexString().addHexPrefix()
            transaction.object = serializedHexString as AnyObject
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidGenerateSignedTransaction(transaction)
            }
        }
    }
    
    override func publishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        struct SignedTxData: Codable {
            let hex: String
        }
        guard let serializedHexString = transaction.object as? String else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
            }
            return
        }
        let signedTxData = SignedTxData(hex: serializedHexString)
        guard let jsonData = try? JSONEncoder().encode(signedTxData) else {
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .invalidParameter)
            }
            return
        }
        self.dispatchQueue.async {
            let urlString = "https://api.cryptoapis.io/v1/bc/\(self.CRYPTOCURRENCY_TYPE.cryptoApiUrlComponent)/\(self.NETWORK)/txs/push\((self.appUniqueId != nil) ? "?uid=\(self.appUniqueId!)" : "")"
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
            let semaphore = DispatchSemaphore(value: 0)
            var hex: String?
            var retryCount = 0
            var done = false
            while !done && retryCount < 3 {
                let task = session.dataTask(with: request) { (data, response, error) in
                    guard error == nil else {
                        ATLog.debug("\(error!)")
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    guard let jsonData = data else {
                        ATLog.debug("No data received")
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    ATLog.debug("Request: \(request.description)\nResponse: \(String(data: jsonData, encoding: .utf8) ?? "empty")")
                    
                    let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any]
                    guard let payloadObject = jsonObject?["payload"] as? [String: Any] else {
                        ATLog.debug("payload not found")
                        if let metaObject = jsonObject?["meta"] as? [String: Any], let errorObject = metaObject["error"] as? [String: Any], let code = errorObject["code"] as? Int, code == 63 { // request limit reached
                            sleep(arc4random() % 10 + 1) // wait 1 - 10 seconds before retry
                        }
                        retryCount += 1
                        semaphore.signal()
                        return
                    }
                    hex = payloadObject["hex"] as? String
                    done = true
                    semaphore.signal()
                }
                task.resume()
                semaphore.wait()
            }
            guard let txHash = hex else {
                DispatchQueue.main.async {
                    self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
                }
                return
            }
            var txUpdated = false
            try? self.dataStack.perform(synchronous: { (cstx) -> Void in
                guard let ownAddress = transaction.ownAddress else { return }
                guard let csAddressDetails = try? cstx.fetchOne(From<CSAddressDetails>().where(\.address == ownAddress)) else { return }
                let csEtherTransaction = cstx.create(Into<CSEtherTransaction>())
                csEtherTransaction.txHash.value = txHash
                csEtherTransaction.from.value = ownAddress
                csEtherTransaction.to.value = transaction.address
                csEtherTransaction.timestamp.value = Int32(bitPattern: UInt32(round(Date().timeIntervalSince1970)))
                csEtherTransaction.value.value = transaction.amount.bint?.asString(withBase: 10) ?? "0"
                csEtherTransaction.gasUsed.value = "\(self.ETHER_TX_GAS)"
                csEtherTransaction.gasPrice.value = ((transaction.fee.bint ?? BInt(0)) / self.ETHER_TX_GAS).asString(withBase: 10)
                csEtherTransaction.ownerDetail.value = csAddressDetails
                
                var etherTransactions = self.etherTransactions
                guard let etherTx = ATCryptocurrencyTransaction(csEtherTransaction, self.CRYPTOCURRENCY_TYPE) else { return }
                etherTransactions.insert(etherTx, at: 0)
                self.etherTransactions = etherTransactions
                txUpdated = true
            })
            DispatchQueue.main.async {
                self.delegate?.abstractWalletDidPublishTransaction(transaction)
                txUpdated ? self.delegate?.abstractWalletDidUpdateTransaction() : nil
            }
        }
    }
    
    // return Gas Price in GWEI
    override func calculateTokenMinimumFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        return (Double(self.MIN_GAS_PRICE.magnitude) / Double(ONE_GWEI.magnitude)).toString(9)
    }
    
    // return Gas Price in GWEI
    override func calculateTokenLowFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        return (Double(self.LOW_GAS_PRICE.magnitude) / Double(ONE_GWEI.magnitude)).toString(9)
    }
    
    // return Gas Price in GWEI
    override func calculateTokenMediumFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        return (Double(self.MEDIUM_GAS_PRICE.magnitude) / Double(ONE_GWEI.magnitude)).toString(9)
    }
    
    // return Gas Price in GWEI
    override func calculateTokenHighFee(_ token: ATCryptocurrencyToken, _ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        return (Double(self.HIGH_GAS_PRICE.magnitude) / Double(ONE_GWEI.magnitude)).toString(9)
    }
    
    override func getTokenMaxOutputAmount(_ token: ATCryptocurrencyToken) -> String {
        ATLog.debug("\(#function)")
        return token.balanceString
    }
    
    override func getTokenMinOutputAmount(_ token: ATCryptocurrencyToken) -> String {
        ATLog.debug("\(#function)")
        var divisorString = "1"
        for _ in 0..<token.info.decimals {
            divisorString.append("0")
        }
        guard let divisor = Double(divisorString) else { return String(UInt64.max) }
        return (1 / divisor).toString(UInt8(token.info.decimals))
    }
    
    override func createTokenTransaction(_ token: ATCryptocurrencyToken, _ amount: String, _ fee: String, _ address: String, _ message: String? = nil) -> ATCryptocurrencyTransaction? {
        ATLog.debug("\(#function)")
        guard checkAddressValidity(address) else {
            ATLog.debug("Invalid address")
            return nil
        }
        // TODO: to support ERC-721
        guard token.info.type.lowercased() == "erc-20" else { return nil }
        let erc20Token = ERC20(contractAddress: token.info.address, decimal: Int(bitPattern: token.info.decimals), symbol: token.info.symbol)
        guard let parameterData = try? erc20Token.generateDataParameter(toAddress: address, amount: amount) else { return nil }
        // TODO: what if this account owns mulitple addresses?
        guard let csAddressDetails = try? self.dataStack.fetchOne(From<CSAddressDetails>()) else { return nil }
        let ownAddress = csAddressDetails.address.value
        let nonce = Int(csAddressDetails.etherOutTxCount.value)
        let gasLimit = Int(self.TOKEN_TX_GAS_LIMIT.magnitude)
        guard let gasPriceValue = Double(fee) else { return nil }
        let gasPrice = Int((gasPriceValue * Double(ONE_GWEI.magnitude)).rounded())
        let rawTx = RawTransaction(wei: "0", to: erc20Token.contractAddress, gasPrice: gasPrice, gasLimit: gasLimit, nonce: nonce, data: parameterData)
        let amountValue = ATCryptocurrencyToken.stringToValue(amount, token.info.decimals)
        let feeValue = ATCryptocurrencyToken.stringToValue(fee, 9) // convert to WEI
        return ATCryptocurrencyTransaction(ownAddress, address.lowercased(), amountValue, feeValue, self.CRYPTOCURRENCY_TYPE, token.info, rawTx as AnyObject)
    }
    
}
