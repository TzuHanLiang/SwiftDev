//
//  EKEthereumWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/3/26.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Foundation
import EthereumKit
import CryptoEthereumSwift
import BRCore
import CoreStore

typealias EKTransaction = EthereumKit.Transaction

extension String {
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
}

extension Decimal {
    func toEther() -> Decimal {
        return self / Decimal(string: "1000000000000000000")!
    }
    
    func toWei() -> Decimal {
        return self * Decimal(string: "1000000000000000000")!
    }
}

fileprivate class CSTransaction : CoreStoreObject {
    var blockHash = Value.Required<String>("blockHash", initial: "")
    var blockNumber = Value.Required<String>("blockNumber", initial: "")
    var txHash = Value.Required<String>("txHash", initial: "")
    var input = Value.Required<String>("input", initial: "")
    var confirmations = Value.Required<String>("confirmations", initial: "")
    var nonce = Value.Required<String>("nonce", initial: "")
    var timeStamp = Value.Required<String>("timeStamp", initial: "")
    var contractAddress = Value.Required<String>("contractAddress", initial: "")
    var from = Value.Required<String>("from", initial: "")
    var to = Value.Required<String>("to", initial: "")
    var gas = Value.Required<String>("gas", initial: "")
    var gasPrice = Value.Required<String>("gasPrice", initial: "")
    var gasUsed = Value.Required<String>("gasUsed", initial: "")
    var cumulativeGasUsed = Value.Required<String>("cumulativeGasUsed", initial: "")
    var isError = Value.Required<String>("isError", initial: "")
    var transactionIndex = Value.Required<String>("transactionIndex", initial: "")
    var txReceiptStatus = Value.Required<String>("txReceiptStatus", initial: "")
    var value = Value.Required<String>("value", initial: "")
}

fileprivate class CSBalance : CoreStoreObject {
    var address = Value.Required<String>("address", initial: "")
    var wei = Value.Required<String>("wei", initial: "0")
}

fileprivate extension EKTransaction {
    init(_ transaction: CSTransaction) {
        self.init(blockHash: transaction.blockHash.value,
                  blockNumber: transaction.blockNumber.value,
                  hash: transaction.txHash.value,
                  input: transaction.input.value,
                  confirmations: transaction.confirmations.value,
                  nonce: transaction.nonce.value,
                  timeStamp: transaction.timeStamp.value,
                  contractAddress: transaction.contractAddress.value,
                  from: transaction.from.value,
                  to: transaction.to.value,
                  gas: transaction.gas.value,
                  gasPrice: transaction.gasPrice.value,
                  gasUsed: transaction.gasUsed.value,
                  cumulativeGasUsed: transaction.cumulativeGasUsed.value,
                  isError: transaction.isError.value,
                  transactionIndex: transaction.transactionIndex.value,
                  txReceiptStatus: transaction.txReceiptStatus.value,
                  value: transaction.value.value)
    }
    
    var serialization: String {
        get {
            return """
            {"blockHash":"\(self.blockHash)","blockNumber":"\(self.blockNumber)","hash":"\(self.hash)","input":"\(self.input)","confirmations":"\(self.confirmations)","nonce":"\(self.nonce)","timeStamp":"\(self.timeStamp)","contractAddress":"\(self.contractAddress)","from":"\(self.from)","to":"\(self.to)","gas":"\(self.gas)","gasPrice":"\(self.gasPrice)","gasUsed":"\(self.gasUsed)","cumulativeGasUsed":"\(self.cumulativeGasUsed)","isError":"\(self.isError)","transactionIndex":"\(self.transactionIndex)","txReceiptStatus":"\(self.txReceiptStatus)","value":"\(self.value)"
            }
            """
        }
    }
    
    var description: String {
        get {
            return """
            "blockHash":"\(self.blockHash)"
            "blockNumber":"\(self.blockNumber)"
            "hash":"\(self.hash)"
            "input":"\(self.input)"
            "confirmations":"\(self.confirmations)"
            "nonce":"\(self.nonce)"
            "timeStamp":"\(self.timeStamp)"
            "contractAddress":"\(self.contractAddress)"
            "from":"\(self.from)"
            "to":"\(self.to)"
            "gas":"\(self.gas)"
            "gasPrice":"\(self.gasPrice)"
            "gasUsed":"\(self.gasUsed)"
            "cumulativeGasUsed":"\(self.cumulativeGasUsed)"
            "isError":"\(self.isError)"
            "transactionIndex":"\(self.transactionIndex)"
            "txReceiptStatus":"\(self.txReceiptStatus)"
            "value":"\(self.value)"
            """
        }
    }
}

fileprivate extension ATCryptocurrencyTransaction {
    convenience init(_ ownAddress: String, _ transaction: EKTransaction, _ currency: ATCryptocurrencyType, _ object: AnyObject?) {
        let direction: TransactionDirection = (transaction.to == ownAddress) ? .received : .sent
 
        self.init(currency, direction, object)
        
        guard let valueWei = Wei(transaction.value, radix: 10), let gasUsedDec = Decimal(string: transaction.gasUsed), let gasPriceDec = Decimal(string: transaction.gasPrice), let gasFeeWei = Wei("\(gasUsedDec * gasPriceDec)", radix: 10) else {
            self.detailDescription = transaction.description
            return
        }
        
        guard let valueEther = try? Converter.toEther(wei: valueWei), let gasFeeEther = try? Converter.toEther(wei: gasFeeWei) else {
            self.detailDescription = transaction.description
            return
        }
        
        let amount256 = ATUInt256(decimal: valueEther.toWei())
        let fee256 = ATUInt256(decimal: gasFeeEther.toWei())
        var str: String
        
        switch self.direction {
        case .sent:
            self.address = transaction.to
            self.amount = amount256
            self.amountString = "\(valueEther)"
            self.fee = fee256
            self.feeString = "\(gasFeeEther)"
            self.totalAmount = amount256 + fee256
            self.totalAmountString = "\(valueEther + gasFeeEther)"
            str = NSLocalizedString("to", comment: "")
        case .received, .moved:
            self.address = transaction.from
            self.amount = amount256
            self.amountString = "\(valueEther)"
            self.totalAmount = amount256
            self.totalAmountString = "\(valueEther)"
            str = NSLocalizedString("from", comment: "")
        }
        
        self.date = Date(timeIntervalSince1970: TimeInterval(transaction.timeStamp) ?? Date().timeIntervalSince1970)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        self.detailDescription.append(NSLocalizedString("date", tableName: nil, bundle: Bundle.main, value: "Date", comment: ""))
        self.detailDescription.append("\n")
        self.detailDescription.append(dateFormatter.string(from: self.date))
        self.detailDescription.append("\n\n")
        
        self.detailDescription.append("\(self.direction.description)\n\(self.amountString) \(self.currency.symbol)\n\n")
                
        self.detailDescription.append("\(str)\n\(self.address)\n\n")
        
        if self.fee > 0 { self.detailDescription.append("\(NSLocalizedString("fee", tableName: nil, bundle: Bundle.main, value: "Fee", comment: ""))\n\(self.feeString) \(self.currency.symbol)\n\n") }
        
        self.detailDescription.append("\(NSLocalizedString("transaction_id", tableName: nil, bundle: Bundle.main, value: "Transaction ID", comment: ""))\n\(transaction.hash)")
    }
}

class EKEthereumWallet : ATAbstractWallet {
    
    private let minimumGasPrice: UInt64 = 1
    private let lowGasPrice: UInt64 = 500000000
    private let mediumGasPrice: UInt64 = 15000000000
    private let highGasPrice: UInt64 = 25000000000
    private let transactionGas: UInt64 = 21000
    private let dispatchQueue: DispatchQueue
    private let dataStack: DataStack
    private let address: String
    private var geth: Geth
    private let minimumSyncInterval: TimeInterval = 30 // seconds
    private var balance: Balance
    private var transactions: [EKTransaction]
    
    init?(UniqueId uid: [UInt8], EarlistKeyTime timestamp: UInt32, PublicKey pubKey: [UInt8], ChainCode chainCode: [UInt8], FingerprintOfParentKey fingerprint: UInt32, ExternalPublicKey0 extPubKey: [UInt8], Delegate delegate: ATAbstractWalletDelegate) {
        guard (pubKey.count == 33 || pubKey.count == 65) && chainCode.count == 32 else {
            ATLog.debug("Invalid public key or chain code")
            return nil
        }
        
        guard extPubKey.count == 65 else {
            ATLog.debug("Invalid external public key")
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
        
        /*// use BRCore to generate external public key 0 from extended public key
        let masterPubKey = BRMasterPubKey(fingerPrint: fingerprint, chainCode: UInt256(bytes: chainCode), pubKey: (compressedPubKey[0], compressedPubKey[1], compressedPubKey[2], compressedPubKey[3], compressedPubKey[4], compressedPubKey[5], compressedPubKey[6], compressedPubKey[7], compressedPubKey[8], compressedPubKey[9], compressedPubKey[10], compressedPubKey[11], compressedPubKey[12], compressedPubKey[13], compressedPubKey[14], compressedPubKey[15], compressedPubKey[16], compressedPubKey[17], compressedPubKey[18], compressedPubKey[19], compressedPubKey[20], compressedPubKey[21], compressedPubKey[22], compressedPubKey[23], compressedPubKey[24], compressedPubKey[25], compressedPubKey[26], compressedPubKey[27], compressedPubKey[28], compressedPubKey[29], compressedPubKey[30], compressedPubKey[31], compressedPubKey[32]))
        let pubKeyPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65)
        let pubKeyLen = BRBIP32PubKey(pubKeyPointer, 65, masterPubKey, 0, 0)
        var pubKeyArray = [UInt8]()
        for index in 0..<pubKeyLen {
            pubKeyArray.append(pubKeyPointer[index])
        }
        pubKeyPointer.deallocate()
        ATLog.debug("Compressed Public Key: \(Data(pubKeyArray) as NSData)")
        // TODO: convert compressed public key to uncompressed
        */
        
        /*// use EthereumKit to generate external public key 0 from extended public key
        // m/purpose'/cointype'/account'/0
        guard let depth4KeyDeriver = KeyDerivation(privateKey: nil, publicKey: Data(compressedPubKey), chainCode: Data(chainCode), depth: 3, fingerprint: fingerprint, childIndex: 3 | 0x80000000).derived(at: 0, hardened: false) else {
            return nil
        }
        // m/purpose'/cointype'/account'/0/0
        guard let depth5KeyDeriver = KeyDerivation(privateKey: nil, publicKey: depth4KeyDeriver.publicKey, chainCode: depth4KeyDeriver.chainCode, depth: 4, fingerprint: depth4KeyDeriver.fingerprint, childIndex: 0).derived(at: 0, hardened: false) else {
            return nil
        }
        guard let pubKeyData = depth5KeyDeriver.publicKey else {
            ATLog.debug("Empty public key")
            return nil
        }
        ATLog.debug("Compressed Public Key: \(pubKeyData as NSData)")
        // TODO: convert compressed public key to uncompressed
        //ATLog.debug("Uncompressed Public Key: \(pubKeyData as NSData)")
        //self.address = PublicKey(raw: pubKeyData).address()
        */
        
        self.address = PublicKey(raw: Data(extPubKey)).address().lowercased()
        ATLog.debug("Address: \(self.address)")
        
        #if TESTNET
        let network = Network.ropsten
        let nodeEndpoint = ATConstants.INFURA_ROPSTEN_ENDPOINT
        #else
        let network = Network.mainnet
        let nodeEndpoint = ATConstants.INFURA_MAINNET_ENDPOINT
        #endif
        let apiKey = ATConstants.INFURA_API_KEY
        #if DEBUG
        let debugPrint = true
        #else
        let debugPrint = false
        #endif
        let configuration = Configuration(network: network, nodeEndpoint: nodeEndpoint, etherscanAPIKey: apiKey, debugPrints: debugPrint)
        self.geth = Geth(configuration: configuration)
        
        self.balance = Balance(wei: Wei(0))
        self.transactions = []
        
        self.dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.EKEthereumWallet")

        self.dataStack = DataStack(CoreStoreSchema(modelVersion: "V1", entities: [Entity<CSBalance>("CSBalance"), Entity<CSTransaction>("CSTransaction")]))
        let fileName = uid.withUnsafeBufferPointer { (pointer: UnsafeBufferPointer<UInt8>) -> String in
            return pointer.map{String(format: "%02hhx", $0)}.reduce("", {$0 + $1})
        }
        do {
            try self.dataStack.addStorageAndWait(SQLiteStore(fileName: "\(fileName).sqlite", localStorageOptions: .recreateStoreOnModelMismatch))
        } catch {
            ATLog.error("Failed to add CoreStore storage \(fileName).sqlite")
            return nil
        }
        
        super.init(Delegate: delegate)
        
        if let balanceItems = try? self.dataStack.fetchAll(From<CSBalance>()) {
            for item in balanceItems {
                if self.address == item.address.value, let wei = Wei(item.wei.value, radix: 10) {
                    self.balance = Balance(wei: wei)
                    break
                }
            }
        }
        
        if let transactionItems = try? self.dataStack.fetchAll(From<CSTransaction>()) {
            var transactions: [EKTransaction] = []
            for item in transactionItems {
                transactions.append(EKTransaction(item))
            }
            self.transactions = transactions
        }
    }
    
    private func getBalance(_ forceUpdate: Bool = false, _ waitUntilDone: Bool = false) -> Balance {
        ATLog.debug("\(#function)")
        struct Static { static var lastSyncTimestamp: TimeInterval = Date().timeIntervalSince1970 }
        let timestamp = Date().timeIntervalSince1970
        guard forceUpdate || (timestamp - Static.lastSyncTimestamp) > self.minimumSyncInterval else {
            return self.balance
        }
        ATLog.debug("Updating balance via geth")
        let condition = NSCondition()
        self.geth.getBalance(of: self.address, blockParameter: .latest) { (result) in
            switch result {
            case .success(let balance):
                Static.lastSyncTimestamp = Date().timeIntervalSince1970
                if self.balance.wei.asString(withBase: 10) != balance.wei.asString(withBase: 10) {
                    self.balance = balance
                    if let ether = try? balance.ether() {
                        self.delegate?.abstractWalletDidUpdateBalance(ATUInt256(decimal: ether.toWei()))
                    }
                    try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                        var csBalance: CSBalance
                        if let item = try transaction.fetchOne(From<CSBalance>().where(\.address == self.address)) {
                            csBalance = item
                        }
                        else {
                            csBalance = transaction.create(Into<CSBalance>())
                            csBalance.address.value = self.address
                        }
                        csBalance.wei.value = self.balance.wei.asString(withBase: 10)
                    })
                }
            case .failure(let error):
                ATLog.debug("Failed to get balance via geth. Error: \(error.localizedDescription)")
            }
            if waitUntilDone { condition.signal() }
        }
        if waitUntilDone { condition.wait() }
        return self.balance
    }
    
    private func getTransactions(_ forceUpdate: Bool = false, _ waitUntilDone: Bool = false) -> [EKTransaction] {
        ATLog.debug("\(#function)")
        // TODO: how to get internal transactions?
        struct Static { static var lastSyncTimestamp: TimeInterval = Date().timeIntervalSince1970 }
        guard forceUpdate || abs(Date(timeIntervalSince1970: Static.lastSyncTimestamp).timeIntervalSinceNow) > self.minimumSyncInterval else {
            return self.transactions
        }
        ATLog.debug("Updating transactions via geth")
        let condition = NSCondition()
        self.geth.getTransactions(address: self.address) { (result) in
            switch result {
            case .success(let transactions):
                Static.lastSyncTimestamp = Date().timeIntervalSince1970
                self.transactions = transactions.elements
                self.delegate?.abstractWalletDidUpdateTransaction()
                try? self.dataStack.perform(synchronous: { (transaction) -> Void in
                    //_ = try? transaction.deleteAll(From<CSTransaction>())
                    for tx in transactions.elements {
                        var cstx: CSTransaction
                        if let item = try transaction.fetchOne(From<CSTransaction>().where(\.txHash == tx.hash)) {
                            cstx = item
                        }
                        else {
                            cstx = transaction.create(Into<CSTransaction>())
                        }
                        cstx.blockHash.value = tx.blockHash
                        cstx.blockNumber.value = tx.blockNumber
                        cstx.txHash.value = tx.hash
                        cstx.input.value = tx.input
                        cstx.confirmations.value = tx.confirmations
                        cstx.nonce.value = tx.nonce
                        cstx.timeStamp.value = tx.timeStamp
                        cstx.contractAddress.value = tx.contractAddress
                        cstx.from.value = tx.from
                        cstx.to.value = tx.to
                        cstx.gas.value = tx.gas
                        cstx.gasPrice.value = tx.gasPrice
                        cstx.gasUsed.value = tx.gasUsed
                        cstx.cumulativeGasUsed.value = tx.cumulativeGasUsed
                        cstx.isError.value = tx.isError
                        cstx.transactionIndex.value = tx.transactionIndex
                        cstx.txReceiptStatus.value = tx.txReceiptStatus
                        cstx.value.value = tx.value
                    }
                })
            case .failure(let error):
                ATLog.debug("Failed to get transactions via geth. Error: \(error.localizedDescription)")
            }
            if waitUntilDone { condition.signal() }
        }
        if waitUntilDone { condition.wait() }
        return self.transactions
    }
    
    private func calculateTransactionFee(_ gasPrice: UInt64) -> UInt64 {
        ATLog.debug("\(#function)")
        let fee = self.transactionGas * gasPrice
        return fee
    }
    
    override func startSync(_ autoSync: Bool = true) {
        // TODO: autoSync
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            self.delegate?.abstractWalletDidStartSync()
            _ = self.getTransactions(true, true)
            _ = self.getBalance(true, true)
            self.delegate?.abstractWalletDidStopSync(nil)
        }
    }
    
    override func stopAutoSync() {
        // TODO
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    override func getBalance() -> ATUInt256 {
        ATLog.debug("\(#function)")
        let balance: Balance = getBalance()
        guard let ether = try? balance.ether() else { return ATUInt256(0) }
        return ATUInt256(decimal: ether.toWei())
    }
    
    override func getBalanceString() -> String {
        ATLog.debug("\(#function)")
        let balance: Balance = getBalance()
        guard let ether = try? balance.ether() else { return "0" }
        return "\(ether)"
    }
    
    override func getTransactions() -> [ATCryptocurrencyTransaction] {
        ATLog.debug("\(#function)")
        let ektransactions: [EKTransaction] = getTransactions()
        var transactions: [ATCryptocurrencyTransaction] = []
        for ektransaction in ektransactions {
            transactions.append(ATCryptocurrencyTransaction(self.address, ektransaction, .eth, nil))
        }
        transactions.sort { (tx1, tx2) -> Bool in
            return tx1.date.compare(tx2.date) == ComparisonResult.orderedDescending
        }
        return transactions
    }
    
    override func getReceivingAddress() -> String {
        ATLog.debug("\(#function)")
        return self.address
    }
    
    override func getReceivingAddressesWithFormat() -> [String: String]? {
        ATLog.debug("\(#function)")
        var addresses = [String: String]()
        addresses.updateValue(self.address, forKey: "Address")
        return addresses
    }
    
    override func checkAddressValidity(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        guard address.count == 42, address.hasPrefix("0x"), address.isAlphanumeric else { return false }
        return true
    }
    
    override func containAddress(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        // TODO: there's no need to check if it always uses the first external public key as the only one receiving address
        return address == self.address
    }
    
    override func calculateMinimumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = Decimal(calculateTransactionFee(self.minimumGasPrice))
        return "\(wei.toEther())"
    }
    
    override func calculateLowFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = Decimal(calculateTransactionFee(self.lowGasPrice))
        return "\(wei.toEther())"
    }
    
    override func calculateMediumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = Decimal(calculateTransactionFee(self.mediumGasPrice))
        return "\(wei.toEther())"
    }
    
    override func calculateHighFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        let wei = Decimal(calculateTransactionFee(self.highGasPrice))
        return "\(wei.toEther())"
    }
    
    override func getMaxOutputAmount() -> String {
        ATLog.debug("\(#function)")
        let error = "0"
        guard let balance = try? getBalance().ether() else { return error }
        guard let gasFee = Decimal(string: calculateMinimumFee("\(balance)")) else { return error }
        return "\(balance - gasFee)"
    }
    
    override func getMinOutputAmount() -> String {
        ATLog.debug("\(#function)")
        return calculateMinimumFee("1")
    }
    
    override func createTransaction(_ amount: String, _ fee: String, _ address: String, _ message: String? = nil) -> ATCryptocurrencyTransaction? {
        ATLog.debug("\(#function)")
        guard checkAddressValidity(address) else {
            ATLog.debug("Invalid address")
            return nil
        }
        guard let amountWei = Ether(string: amount)?.toWei() else { return nil }
        guard let feeEther = Ether(string: fee) else { return nil }
        guard feeEther.toWei() >= Decimal(self.transactionGas) else {
            ATLog.debug("Transaction fee is not enough")
            return nil
        }
        let gasLimit = self.transactionGas * 2
        let gasPrice = NSDecimalNumber(decimal: feeEther.toWei() / Decimal(self.transactionGas)).uint64Value
        let rawTransaction = RawTransaction(wei: "\(amountWei)", to: address, gasPrice: Int(gasPrice), gasLimit: Int(gasLimit), nonce: 0)
        let ekTx = EKTransaction(blockHash: "", blockNumber: "", hash: "", input: "", confirmations: "", nonce: "", timeStamp: "\(Date().timeIntervalSince1970)", contractAddress: "", from: self.address, to: address, gas: "\(gasLimit)", gasPrice: "\(gasPrice)", gasUsed: "\(self.transactionGas)", cumulativeGasUsed: "", isError: "", transactionIndex: "", txReceiptStatus: "", value: "\(amountWei)")
        return ATCryptocurrencyTransaction(self.address, ekTx, .eth, rawTransaction as AnyObject)
    }
    
    override func destroyTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        transaction.object = nil
    }
    
    override func generateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let rawTx = transaction.object as? RawTransaction else {
            self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
            return
        }
        #if TESTNET
        let chainId = Network.ropsten.chainID
        #else
        let chainId = Network.mainnet.chainID
        #endif
        self.dispatchQueue.async {
            self.geth.getTransactionCount(of: self.address) { (result) in
                switch result {
                case .success(let nonce):
                    ATLog.debug("Got transation count: \(nonce)")
                    let rawTx = RawTransaction(wei: rawTx.value.asString(withBase: 10), to: rawTx.to.string, gasPrice: rawTx.gasPrice, gasLimit: rawTx.gasLimit, nonce: nonce)
                    transaction.object = rawTx as AnyObject
                    let signer = EIP155Signer.init(chainID: chainId)
                    guard let hash = try? signer.hash(rawTransaction: rawTx) else {
                        self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
                        return
                    }
                    let unsignedTxData = ATCryptocurrencyTransaction.UnsignedTransactionDataInfo(chainId: 0, keyId: 0, data: ATUInt256(hash.bytes))
                    transaction.unsignedTransactionDataInfos = [unsignedTxData]
                    self.delegate?.abstractWalletDidGenerateTransactionDataForSigning(transaction)
                case .failure(let error):
                    ATLog.debug("Failed to get the current nonce via geth. Error: \(error.localizedDescription)")
                    self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
                }
            }
        }
    }
    
    override func generateSignedTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let rawTx = transaction.object as? RawTransaction else {
            self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            return
        }
        guard let signature = transaction.rsvSignatures?.first else {
            self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            return
        }
        #if TESTNET
        let chainId = Network.ropsten.chainID
        #else
        let chainId = Network.mainnet.chainID
        #endif
        self.dispatchQueue.async {
            let signer = EIP155Signer.init(chainID: chainId)
            let (r, s, v) = signer.calculateRSV(signature: signature)
            guard let rawData = try? RLP.encode([rawTx.nonce, rawTx.gasPrice, rawTx.gasLimit, rawTx.to.data, rawTx.value, rawTx.data, v, r, s]) else {
                self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
                return
            }
            let hash = rawData.toHexString().addHexPrefix()
            transaction.object = hash as AnyObject
            self.delegate?.abstractWalletDidGenerateSignedTransaction(transaction)
        }
    }
    
    override func publishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let rawTx = transaction.object as? String else {
            self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
            return
        }
        self.dispatchQueue.async {
            self.geth.sendRawTransaction(rawTransaction: rawTx, completionHandler: { (result) in
                switch result {
                case .success(let sentTx):
                    ATLog.debug("Transaction \(sentTx.id) sent")
                    self.delegate?.abstractWalletDidPublishTransaction(transaction)
                    Thread.detachNewThread {
                        Thread.sleep(forTimeInterval: 10)
                        _ = self.getTransactions(true)
                    }
                case .failure(let error):
                    ATLog.debug("Failed to send raw transaction. Error: \(error.localizedDescription)")
                    self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
                }
            })
        }
    }
}
