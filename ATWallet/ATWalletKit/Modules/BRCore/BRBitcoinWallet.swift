//
//  BRBitcoinWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/12/18.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation
import BRCore
import SystemConfiguration
import CoreStore

typealias BRTxRef = UnsafeMutablePointer<BRTransaction>
typealias BRBlockRef = UnsafeMutablePointer<BRMerkleBlock>
typealias BufferRef = UnsafeMutablePointer<UInt8>

func SatoshiToBtc(_ satoshi: Decimal) -> Decimal {
    return satoshi / 100000000 // 1 BTC == 100,000,000 satoshi
}

func BtcToSatoshi(_ btc: Decimal) -> UInt64 {
    return (btc * 100000000).uint64
}

extension UInt128 {
    init(bytes: [UInt8]) {
        self.init(u8: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
    
    init(data: Data) {
        self.init(bytes: [UInt8](data))
    }
    
    var bytes: [UInt8] {
        get {
            return [self.u8.0, self.u8.1, self.u8.2, self.u8.3, self.u8.4, self.u8.5, self.u8.6, self.u8.7, self.u8.8, self.u8.9, self.u8.10, self.u8.11, self.u8.12, self.u8.13, self.u8.14, self.u8.15]
        }
    }
    
    var data: Data {
        get {
            return Data(self.bytes)
        }
    }
    
    var description: String {
        get {
            return String(format:"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          self.u8.15, self.u8.14, self.u8.13, self.u8.12, self.u8.11, self.u8.10, self.u8.9, self.u8.8,
                          self.u8.7, self.u8.6, self.u8.5, self.u8.4, self.u8.3, self.u8.2, self.u8.1, self.u8.0)
        }
    }
}

extension UInt256 {
    init(bytes: [UInt8]) {
        self.init(u8: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15], bytes[16], bytes[17], bytes[18], bytes[19], bytes[20], bytes[21], bytes[22], bytes[23], bytes[24], bytes[25], bytes[26], bytes[27], bytes[28], bytes[29], bytes[30], bytes[31]))
    }
    
    init(data: Data) {
        self.init(bytes: [UInt8](data))
    }
    
    var bytes: [UInt8] {
        get {
            return [self.u8.0, self.u8.1, self.u8.2, self.u8.3, self.u8.4, self.u8.5, self.u8.6, self.u8.7, self.u8.8, self.u8.9, self.u8.10, self.u8.11, self.u8.12, self.u8.13, self.u8.14, self.u8.15, self.u8.16, self.u8.17, self.u8.18, self.u8.19, self.u8.20, self.u8.21, self.u8.22, self.u8.23, self.u8.24, self.u8.25, self.u8.26, self.u8.27, self.u8.28, self.u8.29, self.u8.30, self.u8.31]
        }
    }
    
    var data: Data {
        get {
            return Data(self.bytes)
        }
    }
    
    var description: String {
        get {
            return String(format:"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          self.u8.31, self.u8.30, self.u8.29, self.u8.28, self.u8.27, self.u8.26, self.u8.25, self.u8.24,
                          self.u8.23, self.u8.22, self.u8.21, self.u8.20, self.u8.19, self.u8.18, self.u8.17, self.u8.16,
                          self.u8.15, self.u8.14, self.u8.13, self.u8.12, self.u8.11, self.u8.10, self.u8.9, self.u8.8,
                          self.u8.7, self.u8.6, self.u8.5, self.u8.4, self.u8.3, self.u8.2, self.u8.1, self.u8.0)
        }
    }
}

extension BRAddress: CustomStringConvertible, Hashable {
    init?(string: String) {
        self.init()
        let cStr = [CChar](string.utf8CString)
        guard cStr.count <= MemoryLayout<BRAddress>.size else { return nil }
        UnsafeMutableRawPointer(mutating: &self.s).assumingMemoryBound(to: CChar.self).assign(from: cStr,
                                                                                              count: cStr.count)
    }
    
    init?(scriptPubKey: [UInt8]) {
        self.init()
        guard BRAddressFromScriptPubKey(UnsafeMutableRawPointer(mutating: &self.s).assumingMemoryBound(to: CChar.self),
                                        MemoryLayout<BRAddress>.size, scriptPubKey, scriptPubKey.count) > 0
            else { return nil }
    }
    
    init?(scriptSig: [UInt8]) {
        self.init()
        guard BRAddressFromScriptSig(UnsafeMutableRawPointer(mutating: &self.s).assumingMemoryBound(to: CChar.self),
                                     MemoryLayout<BRAddress>.size, scriptSig, scriptSig.count) > 0 else { return nil }
    }
    
    var scriptPubKey: [UInt8]? {
        var script = [UInt8](repeating: 0, count: 25)
        let count = BRAddressScriptPubKey(&script, script.count,
                                          UnsafeRawPointer([self.s]).assumingMemoryBound(to: CChar.self))
        guard count > 0 else { return nil }
        if count < script.count { script.removeSubrange(count...) }
        return script
    }
    
    var hash160: UInt160? {
        var hash = UInt160()
        guard BRAddressHash160(&hash, UnsafeRawPointer([self.s]).assumingMemoryBound(to: CChar.self)) != 0
            else { return nil }
        return hash
    }
    
    public var description: String {
        return String(cString: UnsafeRawPointer([self.s]).assumingMemoryBound(to: CChar.self))
    }
    
    public var hashValue: Int {
        return BRAddressHash([self.s])
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes: UnsafeRawBufferPointer(start: [self.s], count: 75))
    }
    
    static public func == (l: BRAddress, r: BRAddress) -> Bool {
        return BRAddressEq([l.s], [r.s]) != 0
    }
}

extension BRTxInput {
    var swiftAddress: String {
        get { return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self)) }
        set { BRTxInputSetAddress(&self, newValue) }
    }
    
    var swiftScript: [UInt8] {
        get { return [UInt8](UnsafeBufferPointer(start: self.script, count: self.scriptLen)) }
        set { BRTxInputSetScript(&self, newValue, newValue.count) }
    }
    
    var swiftSignature: [UInt8] {
        get { return [UInt8](UnsafeBufferPointer(start: self.signature, count: self.sigLen)) }
        set { BRTxInputSetSignature(&self, newValue, newValue.count) }
    }
}

extension BRTxOutput {
    init(_ address: String, _ amount: UInt64) {
        self.init()
        self.amount = amount
        BRTxOutputSetAddress(&self, address)
    }
    
    var swiftAddress: String {
        get { return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self)) }
        set { BRTxOutputSetAddress(&self, newValue) }
    }
    
    var swiftScript: [UInt8] {
        get { return [UInt8](UnsafeBufferPointer(start: self.script, count: self.scriptLen)) }
        set { BRTxOutputSetScript(&self, newValue, newValue.count) }
    }
}

extension UnsafeMutablePointer where Pointee == BRTransaction {
    init?() {
        self.init(BRTransactionNew())
    }
    
    // bytes must contain a serialized tx
    init?(bytes: [UInt8]) {
        self.init(BRTransactionParse(bytes, bytes.count))
    }
    
    var txHash: UInt256 {
        return self.pointee.txHash
    }
    
    var version: UInt32 {
        return self.pointee.version
    }
    
    var inputs: [BRTxInput] {
        return [BRTxInput](UnsafeBufferPointer(start: self.pointee.inputs, count: self.pointee.inCount))
    }
    
    var outputs: [BRTxOutput] {
        return [BRTxOutput](UnsafeBufferPointer(start: self.pointee.outputs, count: self.pointee.outCount))
    }
    
    var lockTime: UInt32 {
        return self.pointee.lockTime
    }
    
    var blockHeight: UInt32 {
        get { return self.pointee.blockHeight }
        set { self.pointee.blockHeight = newValue }
    }
    
    var timestamp: TimeInterval {
        get { return TimeInterval(self.pointee.timestamp) }
        set { self.pointee.timestamp = UInt32(newValue) }
    }
    
    // serialized transaction (blockHeight and timestamp are not serialized)
    var bytes: [UInt8]? {
        var bytes = [UInt8](repeating:0, count: BRTransactionSerialize(self, nil, 0))
        guard BRTransactionSerialize(self, &bytes, bytes.count) == bytes.count else { return nil }
        return bytes
    }
    
    // adds an input to tx
    func addInput(txHash: UInt256, index: UInt32, amount: UInt64, script: [UInt8],
                  signature: [UInt8]? = nil, sequence: UInt32 = TXIN_SEQUENCE) {
        BRTransactionAddInput(self, txHash, index, amount, script, script.count, signature, signature?.count ?? 0, [], 0, sequence)
    }
    
    // adds an output to tx
    func addOutput(amount: UInt64, script: [UInt8]) {
        BRTransactionAddOutput(self, amount, script, script.count)
    }
    
    // shuffles order of tx outputs
    func shuffleOutputs() {
        BRTransactionShuffleOutputs(self)
    }
    
    // size in bytes if signed, or estimated size assuming compact pubkey sigs
    var size: Int {
        return BRTransactionSize(self)
    }
    
    // minimum transaction fee needed for tx to relay across the bitcoin network
    var standardFee: UInt64 {
        return BRTransactionStandardFee(self)
    }
    
    // checks if all signatures exist, but does not verify them
    var isSigned: Bool {
        return BRTransactionIsSigned(self) != 0
    }
    
    var hashValue: Int {
        return BRTransactionHash(self)
    }
    
    static func == (l: UnsafeMutablePointer<Pointee>, r: UnsafeMutablePointer<Pointee>) -> Bool {
        return BRTransactionEq(l, r) != 0
    }
}

fileprivate extension ATCryptocurrencyTransaction {
    convenience init(_ wallet: OpaquePointer, _ txRef: BRTxRef, _ currency: ATCryptocurrencyType) {
        let amountReceived = BRWalletAmountReceivedFromTx(wallet, txRef)
        let amountSent = BRWalletAmountSentByTx(wallet, txRef)
        let fee = BRWalletFeeForTx(wallet, txRef)
        
        let peerInputAddress = txRef.inputs.filter({ (input) -> Bool in
            return BRWalletContainsAddress(wallet, input.swiftAddress) == 0 // TODO: why some input address is empty?
        }).first?.swiftAddress ?? ""
        let myOutputAddress = txRef.outputs.filter({ (output) -> Bool in
            return BRWalletContainsAddress(wallet, output.swiftAddress) != 0
        }).first?.swiftAddress ?? ""
        let peerOutputAddress = txRef.outputs.filter({ (output) -> Bool in
            return BRWalletContainsAddress(wallet, output.swiftAddress) == 0
        }).first?.swiftAddress ?? ""
        
        var direction: TransactionDirection
        if amountSent > 0 && (amountReceived + fee) == amountSent {
            direction = .moved
        } else if amountSent > 0 {
            direction = .sent
        } else {
            direction = .received
        }
        
        self.init(currency, direction, nil)
                
        var str: String
        switch self.direction {
        case .moved:
            self.address = myOutputAddress
            self.amount = ATUInt256(amountSent)
            self.amountString = SatoshiToBtc(Decimal(amountSent)).toString()
            self.totalAmount = self.amount
            self.totalAmountString = self.amountString
            str = NSLocalizedString("to", comment: "")
        case .sent:
            self.address = peerOutputAddress
            self.amount = ATUInt256(amountSent - amountReceived - fee)
            self.amountString = SatoshiToBtc(Decimal(amountSent - amountReceived - fee)).toString()
            self.fee = ATUInt256(fee)
            self.feeString = SatoshiToBtc(Decimal(fee)).toString()
            self.totalAmount = ATUInt256(amountSent - amountReceived)
            self.totalAmountString = SatoshiToBtc(Decimal(amountSent - amountReceived)).toString()
            str = NSLocalizedString("to", comment: "")
        case .received:
            self.address = peerInputAddress
            self.amount = ATUInt256(amountReceived)
            self.amountString = SatoshiToBtc(Decimal(amountReceived)).toString()
            self.totalAmount = self.amount
            self.totalAmountString = self.amountString
            str = NSLocalizedString("from", comment: "")
        }
        
        self.date = txRef.timestamp == 0 ? Date() : Date(timeIntervalSince1970: txRef.timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        self.detailDescription.append(NSLocalizedString("date", tableName: nil, bundle: Bundle.main, value: "Date", comment: ""))
        self.detailDescription.append("\n")
        self.detailDescription.append(dateFormatter.string(from: self.date))
        self.detailDescription.append("\n\n")
        
        self.detailDescription.append("\(self.direction.description)\n\(self.amountString) \(self.currency.symbol)\n\n")
        
        self.detailDescription.append("\(str)\n\(self.address)\n\n")
        
        if self.fee > 0 {
            self.detailDescription.append("\(NSLocalizedString("fee", tableName: nil, bundle: Bundle.main, value: "Fee", comment: ""))\n\(self.feeString) \(self.currency.symbol)\n\n")
        }
        
        self.detailDescription.append("\(NSLocalizedString("transaction_id", tableName: nil, bundle: Bundle.main, value: "Transaction ID", comment: ""))\n\(txRef.txHash.description)")
    }
    
    convenience init(_ wallet: OpaquePointer, _ txRef: BRTxRef, _ currency: ATCryptocurrencyType, _ address: String) {
        self.init(currency, .sent, txRef as AnyObject)
        self.address = address
        
        let amountSent = BRWalletAmountSentByTx(wallet, txRef)
        let amountReceived = BRWalletAmountReceivedFromTx(wallet, txRef)
        let fee = BRWalletFeeForTx(wallet, txRef)
        self.amount = ATUInt256(amountSent - amountReceived - fee)
        self.amountString = SatoshiToBtc(Decimal(amountSent - amountReceived - fee)).toString()
        self.fee = ATUInt256(fee)
        self.feeString = SatoshiToBtc(Decimal(fee)).toString()
        self.totalAmount = ATUInt256(amountSent - amountReceived)
        self.totalAmountString = SatoshiToBtc(Decimal(amountSent - amountReceived)).toString()
    }
    
    func freeTxRef() {
        guard let object = self.object else { return }
        let txRef = object as! BRTxRef
        BRTransactionFree(txRef)
        self.object = nil
    }
}

enum BRPeerManagerError: Error {
    case posixError(errorCode: Int32, description: String)
}

protocol BRWalletListener {
    func balanceChanged(_ balance: UInt64)
    func txAdded(_ tx: BRTxRef)
    func txUpdated(_ txHashes: [UInt256], _ blockHeight: UInt32, _ timestamp: UInt32)
    func txDeleted(_ txHash: UInt256, _ notifyUser: Bool, _ recommendRescan: Bool)
}

protocol BRPeerManagerListener {
    func syncStarted()
    func syncStopped(_ error: BRPeerManagerError?)
    func txStatusUpdate()
    func saveBlocks(_ replace: Bool, _ blockRefs: [BRBlockRef?])
    func savePeers(_ replace: Bool, _ peers: [BRPeer])
    func networkIsReachable() -> Bool
}

protocol BRTransactionListener {
    func publishCompleted(_ error: BRPeerManagerError?)
}

fileprivate class Block : CoreStoreObject {
    var blockHash = Value.Required<Data>("blockHash", initial: Data()) // UInt256
    var version = Value.Required<Int32>("version", initial: 0)
    var prevBlock = Value.Required<Data>("prevBlock", initial: Data()) // UInt256
    var merkleRoot = Value.Required<Data>("merkleRoot", initial: Data()) // UInt256
    var timestamp = Value.Required<Int32>("timestamp", initial: 0)
    var target = Value.Required<Int32>("target", initial: 0)
    var nonce = Value.Required<Int32>("nonce", initial: 0)
    var totalTx = Value.Required<Int32>("totalTx", initial: 0)
    var hashes = Value.Required<Data>("hashes", initial: Data()) // [UInt256]
    var hashesCount = Value.Required<Int>("hashesCount", initial: 0)
    var flags = Value.Required<Data>("flags", initial: Data()) // [UInt256]
    var flagsLen = Value.Required<Int>("flagsLen", initial: 0)
    var height = Value.Required<Int32>("height", initial: 0)
}

fileprivate class Transaction : CoreStoreObject {
    var txHash = Value.Required<Data>("txHash", initial: Data()) // UInt256
    var blockHeight = Value.Required<Int32>("blockHeight", initial: 0)
    var timestamp = Value.Required<Int32>("timestamp", initial: 0)
    var txBuffer = Value.Required<Data>("txBuffer", initial: Data())
}

fileprivate class Peer : CoreStoreObject {
    var address = Value.Required<Data>("address", initial: Data()) // UInt128
    var port = Value.Required<Int16>("port", initial: 0)
    var services = Value.Required<Int64>("services", initial: 0)
    var timestamp = Value.Required<Int64>("timestamp", initial: 0)
    var flags = Value.Required<Int8>("flags", initial: 0)
}

class BRBitcoinWallet : ATAbstractWallet, BRWalletListener, BRPeerManagerListener {
    
    private let uid: [UInt8]
    private let dataStack: DataStack
    private let dispatchQueue: DispatchQueue
    
    let forkId: Int32
    let chainParams: [BRChainParams]
    
    var walletPtr: OpaquePointer?
    var peerManagerPtr: OpaquePointer?
    
    private var publishingTransaction: ATCryptocurrencyTransaction? = nil
    
    enum ForkId : Int32 {
        case btc = 0x00 // Bitcoin
        case bch = 0x40 // Bitcoin Cash
        //case btg = 0x4F // Bitcoin Gold
        //case bsv = 0x?? // Bitcoin SV
        
        var description: String {
            get {
                switch self {
                case .btc:
                    return "btc"
                case .bch:
                    return "bch"
                }
            }
        }
    }
    
    init?(UniqueId uid: [UInt8], EarlistKeyTime timestamp: UInt32, ForkId forkId: ForkId, PublicKey pubKey: [UInt8], ChainCode chainCode: [UInt8], FingerprintOfParentKey fingerprint: UInt32, Delegate delegate: ATAbstractWalletDelegate) {
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
        
        self.uid = uid
        self.forkId = forkId.rawValue
        self.dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.BRBitcoinWallet")
        self.dataStack = DataStack(CoreStoreSchema(modelVersion: "V1", entities: [Entity<Block>("Block"), Entity<Peer>("Peer"), Entity<Transaction>("Transaction")]))
        let fileName = self.uid.withUnsafeBufferPointer { (pointer: UnsafeBufferPointer<UInt8>) -> String in
            return pointer.map{String(format: "%02hhx", $0)}.reduce("", {$0 + $1})
        }
        do {
            try self.dataStack.addStorageAndWait(SQLiteStore(fileName: "\(fileName).sqlite", localStorageOptions: .recreateStoreOnModelMismatch))
        } catch {
            ATLog.error("Failed to add CoreStore storage \(fileName).sqlite")
            return nil
        }
        
        switch forkId {
        case .btc:
            #if TESTNET
            self.chainParams = [BRTestNetParams]
            #else
            self.chainParams = [BRMainNetParams]
            #endif
        case .bch:
            #if TESTNET
            self.chainParams = [BRBCashTestNetParams]
            #else
            self.chainParams = [BRBCashParams]
            #endif
        }
        
        super.init(Delegate: delegate)
        
        let peerItems: [Peer]? = try? self.dataStack.fetchAll(From<Peer>())
        
        var peers: [BRPeer] = []
        peerItems?.forEach({ (item) in
            var peer = BRPeer()
            peer.address = UInt128(data: item.address.value)
            peer.port = UInt16(bitPattern: item.port.value)
            peer.services = UInt64(bitPattern: item.services.value)
            peer.timestamp = UInt64(bitPattern: item.timestamp.value)
            peer.flags = UInt8(bitPattern: item.flags.value)
            peers.append(peer)
        })
        ATLog.debug("Saved Peers: \(peers.count)")
        
        let blockItems: [Block]? = try? self.dataStack.fetchAll(From<Block>())
        
        var blockRefs: [BRBlockRef?] = []
        blockItems?.forEach({ (item) in
            guard item.height.value != BLOCK_UNKNOWN_HEIGHT else {
                ATLog.debug("skipped invalid blockheight: \(item.height.value)")
                return
            }
            guard let blockRef = BRMerkleBlockNew() else { return }
            blockRef.pointee.blockHash = UInt256(data: item.blockHash.value)
            blockRef.pointee.version = UInt32(bitPattern: item.version.value)
            blockRef.pointee.prevBlock = UInt256(data: item.prevBlock.value)
            blockRef.pointee.merkleRoot = UInt256(data: item.merkleRoot.value)
            blockRef.pointee.timestamp = UInt32(bitPattern: item.timestamp.value)
            blockRef.pointee.target = UInt32(bitPattern: item.target.value)
            blockRef.pointee.nonce = UInt32(bitPattern: item.nonce.value)
            blockRef.pointee.totalTx = UInt32(bitPattern: item.totalTx.value)
            blockRef.pointee.height = UInt32(bitPattern: item.height.value)
            
            let hashesCount = item.hashes.value.count / MemoryLayout<UInt256>.size
            let hashes = UnsafeMutablePointer<UInt256>.allocate(capacity: hashesCount)
            for i in 0..<hashesCount {
                let start = i * MemoryLayout<UInt256>.size
                let end = (i + 1) * MemoryLayout<UInt256>.size
                let hash = UInt256(data: item.hashes.value.subdata(in: start..<end))
                (hashes + i).initialize(to: hash)
            }
            let flags = UnsafePointer([UInt8](item.flags.value))
            BRMerkleBlockSetTxHashes(blockRef, UnsafePointer(hashes), hashesCount, flags, item.flags.value.count)
            blockRefs.append(blockRef)
            hashes.deallocate()
        })
        ATLog.debug("Saved Blocks: \(blockRefs.count)")
        
        let transactionItems: [Transaction]? = try? self.dataStack.fetchAll(From<Transaction>())
        
        var txRefs: [BRTxRef?] = []
        transactionItems?.forEach({ (item) in
            let txBuffer = [UInt8](item.txBuffer.value)
            guard let tx = BRTransactionParse(txBuffer, txBuffer.count) else {
                ATLog.debug("Failed to parse tx buffer")
                return
            }
            tx.pointee.timestamp = UInt32(bitPattern: item.timestamp.value)
            tx.pointee.blockHeight = UInt32(bitPattern: item.blockHeight.value)
            txRefs.append(tx)
        })
        ATLog.debug("Saved Transactions: \(txRefs.count)")
        
        let masterPubKey = BRMasterPubKey(fingerPrint: fingerprint, chainCode: UInt256(bytes: chainCode), pubKey: (compressedPubKey[0], compressedPubKey[1], compressedPubKey[2], compressedPubKey[3], compressedPubKey[4], compressedPubKey[5], compressedPubKey[6], compressedPubKey[7], compressedPubKey[8], compressedPubKey[9], compressedPubKey[10], compressedPubKey[11], compressedPubKey[12], compressedPubKey[13], compressedPubKey[14], compressedPubKey[15], compressedPubKey[16], compressedPubKey[17], compressedPubKey[18], compressedPubKey[19], compressedPubKey[20], compressedPubKey[21], compressedPubKey[22], compressedPubKey[23], compressedPubKey[24], compressedPubKey[25], compressedPubKey[26], compressedPubKey[27], compressedPubKey[28], compressedPubKey[29], compressedPubKey[30], compressedPubKey[31], compressedPubKey[32]))
        guard let walletPtr = BRWalletNew(&txRefs, txRefs.count, masterPubKey, self.forkId) else {
            ATLog.debug("Failed to create BRWallet")
            return nil
        }
        self.walletPtr = walletPtr
        BRWalletSetFeePerKb(self.walletPtr, MIN_FEE_PER_KB) // set transaction fee to minimum
        
        // TODO: if earlistKeyTime is earlier than BCH fork time, bch should merge btc's blocks if wallet was created after the fork time
        guard let peerManagerPtr = BRPeerManagerNew(self.chainParams, self.walletPtr, timestamp, &blockRefs, blockRefs.count, peers, peers.count) else {
            ATLog.error("Failed to new BRPeerManager")
            BRWalletFree(self.walletPtr)
            return nil
        }
        self.peerManagerPtr = peerManagerPtr
        
        BRWalletSetCallbacks(self.walletPtr, Unmanaged.passUnretained(self).toOpaque(),
                             { (info, balance) in // balanceChanged
                                guard let info = info else { return }
                                Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().balanceChanged(balance)
                             },
                             { (info, tx) in // txAdded
                                guard let info = info, let tx = tx else { return }
                                Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().txAdded(tx)
                             },
                             { (info, txHashes, txCount, blockHeight, timestamp) in // txUpdated
                                guard let info = info else { return }
                                let hashes = [UInt256](UnsafeBufferPointer(start: txHashes, count: txCount))
                                Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().txUpdated(hashes, blockHeight, timestamp)
                             },
                             { (info, txHash, notify, rescan) in // txDeleted
                                guard let info = info else { return }
                                Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().txDeleted(txHash, (notify != 0), (rescan != 0))
                             })
        
        BRPeerManagerSetCallbacks(self.peerManagerPtr, Unmanaged.passUnretained(self).toOpaque(),
                                  { (info) in // syncStarted
                                    guard let info = info else { return }
                                    Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().syncStarted()
                                  },
                                  { (info, error) in // syncStopped
                                    guard let info = info else { return }
                                    let err = BRPeerManagerError.posixError(errorCode: error, description: String(cString: strerror(error)))
                                    Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().syncStopped(error != 0 ? err : nil)
                                  },
                                  { (info) in // txStatusUpdate
                                    guard let info = info else { return }
                                    Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().txStatusUpdate()
                                  },
                                  { (info, replace, blocks, blocksCount) in // saveBlocks
                                    guard let info = info else { return }
                                    let blockRefs = [BRBlockRef?](UnsafeBufferPointer(start: blocks, count: blocksCount))
                                    Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().saveBlocks(replace != 0, blockRefs)
                                  },
                                  { (info, replace, peers, peersCount) in // savePeers
                                    guard let info = info else { return }
                                    let peerList = [BRPeer](UnsafeBufferPointer(start: peers, count: peersCount))
                                    Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().savePeers(replace != 0, peerList)
                                  },
                                  { (info) -> Int32 in // networkIsReachable
                                    guard let info = info else { return 0 }
                                    return Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().networkIsReachable() ? 1 : 0
                                  },
                                  nil) // threadCleanup
    }
    
    deinit {
        if self.peerManagerPtr != nil {
            BRPeerManagerDisconnect(self.peerManagerPtr)
            BRPeerManagerFree(self.peerManagerPtr)
        }
        if self.walletPtr != nil {
            BRWalletFree(self.walletPtr)
        }
    }
    
    override func startSync(_ autoSync: Bool = true) {
        // TODO: autoSync
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            guard self.peerManagerPtr != nil else {
                self.delegate?.abstractWalletDidStopSync(.failToSync)
                return
            }
            if BRPeerManagerConnectStatus(self.peerManagerPtr) == BRPeerStatusConnected {
                BRPeerManagerRescan(self.peerManagerPtr) // TODO: does it need to rescan all?
            }
            else {
                BRPeerManagerConnect(self.peerManagerPtr)
            }
        }
    }
    
    override func stopAutoSync() {
        // TODO
        ATLog.debug("\(#function) needs to be implementd")
    }
    
    override func getBalance() -> ATUInt256 {
        ATLog.debug("\(#function)")
        guard self.walletPtr != nil else { return ATUInt256(0) }
        let balance64 = BRWalletBalance(self.walletPtr)
        return ATUInt256(balance64)
    }
    
    override func getBalanceString() -> String {
        ATLog.debug("\(#function)")
        guard self.walletPtr != nil else { return "0" }
        let balance = BRWalletBalance(self.walletPtr)
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            let btc = SatoshiToBtc(Decimal(balance))
            return btc.toString()
        }
        return String(balance)
    }
    
    override func getTransactions() -> [ATCryptocurrencyTransaction] {
        ATLog.debug("\(#function)")
        guard self.walletPtr != nil else { return [ATCryptocurrencyTransaction]() }
        var txRefs = [BRTxRef?](repeating: nil, count: BRWalletTransactions(self.walletPtr, nil, 0)) // sort by date, oldest first
        guard BRWalletTransactions(self.walletPtr, &txRefs, txRefs.count) == txRefs.count, txRefs.count > 0 else { return [] }
        
        var transactions = [ATCryptocurrencyTransaction]()
        txRefs.forEach { (txRef) in
            guard let txRef = txRef else { return }
            transactions.append(ATCryptocurrencyTransaction(self.walletPtr!, txRef, self.forkId == ForkId.btc.rawValue ? .btc : .bch))
        }
        
        return transactions.reversed()
    }
    
    override func getReceivingAddress() -> String {
        ATLog.debug("\(#function)")
        guard self.walletPtr != nil else { return "" }
        if self.forkId == ForkId.btc.rawValue {
            //let address = BRWalletLegacyAddress(self.walletPtr).description
            //ATLog.debug("Unused P2PKH Address: \(address)")
            let address = BRWalletReceiveAddress(self.walletPtr).description
            ATLog.debug("Unused Bech32 Address: \(address)")
            //let address = BRWalletReceiveP2SHAddress(self.walletPtr).description
            //ATLog.debug("Unused P2SH Address: \(address)")
            return address
        }
        else if self.forkId == ForkId.bch.rawValue {
            let address = BRWalletLegacyAddress(self.walletPtr).description
            ATLog.debug("Unused Legacy Address: \(address)")
            return address
        }
        else {
            // TODO: btg, bsv
            return ""
        }
    }
    
    override func getReceivingAddressesWithFormat() -> [String: String]? {
        ATLog.debug("\(#function)")
        guard self.walletPtr != nil else { return nil }
        if self.forkId == ForkId.btc.rawValue {
            var addresses = [String: String]()
            addresses.updateValue(BRWalletReceiveAddress(self.walletPtr).description, forKey: "Bech32")
            addresses.updateValue(BRWalletLegacyAddress(self.walletPtr).description, forKey: "P2PKH")
            //addresses.updateValue(BRWalletReceiveP2SHAddress(self.walletPtr).description, forKey: "P2SH")
            return addresses
        }
        else if self.forkId == ForkId.bch.rawValue {
            var addresses = [String: String]()
            let legacyAddress = BRWalletLegacyAddress(self.walletPtr).description
            addresses.updateValue(legacyAddress, forKey: "Legacy")
            
            var chars: [Int8] = Array(legacyAddress.utf8).map { (byte) -> Int8 in
                return Int8(bitPattern: byte)
            }
            chars.append(0)
            var buffer = [Int8](repeating: 0, count: 64)
            BRBCashAddrEncode(&buffer, UnsafePointer(chars))
            let cashAddr = String(cString: &buffer)
            if cashAddr.hasPrefix("bitcoincash") || cashAddr.hasPrefix("bchtest") || cashAddr.hasPrefix("bchreg") {
                addresses.updateValue(cashAddr, forKey: "CashAddr")
            }
            
            return addresses
        }
        else {
            // TODO: btg, bsv
            return nil
        }
    }
    
    override func checkAddressValidity(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        var bitcoinAddress = address
        if self.forkId == ForkId.btc.rawValue {
            // do nothing
        }
        else if self.forkId == ForkId.bch.rawValue && (address.hasPrefix("bitcoincash") || address.hasPrefix("bchtest") || address.hasPrefix("bchreg")) {
            var chars: [Int8] = Array(address.utf8).map { (byte) -> Int8 in
                return Int8(bitPattern: byte)
            }
            chars.append(0)
            var buffer = [Int8](repeating: 0, count: 64)
            BRBCashAddrDecode(&buffer, UnsafePointer(chars))
            bitcoinAddress = String(cString: &buffer)
        }
        else {
            // TODO: btg, bsv
        }
        
        var chars: [Int8] = Array(bitcoinAddress.utf8).map { (byte) -> Int8 in
            return Int8(bitPattern: byte)
        }
        chars.append(0)
        return BRAddressIsValid(UnsafePointer(chars)) != 0
    }
    
    override func containAddress(_ address: String) -> Bool {
        ATLog.debug("\(#function)")
        var bitcoinAddress = address
        if self.forkId == ForkId.btc.rawValue {
            // do nothing
        }
        else if self.forkId == ForkId.bch.rawValue && (address.hasPrefix("bitcoincash") || address.hasPrefix("bchtest") || address.hasPrefix("bchreg")) {
            var chars: [Int8] = Array(address.utf8).map { (byte) -> Int8 in
                return Int8(bitPattern: byte)
            }
            chars.append(0)
            var buffer = [Int8](repeating: 0, count: 64)
            BRBCashAddrDecode(&buffer, UnsafePointer(chars))
            bitcoinAddress = String(cString: &buffer)
        }
        else {
            // TODO: btg, bsv
        }
        
        var chars: [Int8] = Array(bitcoinAddress.utf8).map { (byte) -> Int8 in
            return Int8(bitPattern: byte)
        }
        chars.append(0)
        return BRWalletContainsAddress(self.walletPtr, UnsafePointer(chars)) != 0
    }
    
    override func calculateMinimumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            guard let amount = Decimal(string: amount) else { return String(UInt64.max) }
            let satoshiFee = BRWalletFeeForTxAmount(self.walletPtr, BtcToSatoshi(amount));
            guard satoshiFee < UInt64.max else { return String(UInt64.max) }
            return SatoshiToBtc(Decimal(satoshiFee)).toString()
        }
        else {
            // TODO: btg, bsv
            return String(UInt64.max)
        }
    }
    
    override func calculateLowFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            guard let amount = Decimal(string: amount) else { return String(UInt64.max) }
            let satoshiFee = BRWalletFeeForTxAmount(self.walletPtr, BtcToSatoshi(amount));
            guard satoshiFee < UInt64.max else { return String(UInt64.max) }
            return SatoshiToBtc(Decimal(satoshiFee * 2)).toString()
        }
        else {
            // TODO: btg, bsv
            return String(UInt64.max)
        }
    }
    
    override func calculateMediumFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            guard let amount = Decimal(string: amount) else { return String(UInt64.max) }
            let satoshiFee = BRWalletFeeForTxAmount(self.walletPtr, BtcToSatoshi(amount));
            guard satoshiFee < UInt64.max else { return String(UInt64.max) }
            return SatoshiToBtc(Decimal(satoshiFee * 10)).toString()
        }
        else {
            // TODO: btg, bsv
            return String(UInt64.max)
        }
    }
    
    override func calculateHighFee(_ amount: String, _ message: String? = nil) -> String {
        ATLog.debug("\(#function)")
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            guard let amount = Decimal(string: amount) else { return String(UInt64.max) }
            let satoshiFee = BRWalletFeeForTxAmount(self.walletPtr, BtcToSatoshi(amount));
            guard satoshiFee < UInt64.max else { return String(UInt64.max) }
            return SatoshiToBtc(Decimal(satoshiFee * 20)).toString()
        }
        else {
            // TODO: btg, bsv
            return String(UInt64.max)
        }
    }
    
    override func getMaxOutputAmount() -> String {
        ATLog.debug("\(#function)")
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            let satoshi = BRWalletMaxOutputAmount(self.walletPtr)
            return SatoshiToBtc(Decimal(satoshi)).toString()
        }
        else {
            // TODO: btg, bsv
            return "0"
        }
    }
    
    override func getMinOutputAmount() -> String {
        ATLog.debug("\(#function)")
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            let satoshi = BRWalletMinOutputAmount(self.walletPtr)
            return SatoshiToBtc(Decimal(satoshi)).toString()
        }
        else {
            // TODO: btg, bsv
            return String(UInt64.max)
        }
    }
    
    override func createTransaction(_ amount: String, _ fee: String, _ address: String, _ message: String? = nil) -> ATCryptocurrencyTransaction? {
        ATLog.debug("\(#function)")
        if self.forkId == ForkId.btc.rawValue || self.forkId == ForkId.bch.rawValue {
            guard let btcAmount = Decimal(string: amount), btcAmount > 0 else { return nil }
            let satoshiAmount = BtcToSatoshi(btcAmount)
            guard satoshiAmount <= BRWalletMaxOutputAmount(self.walletPtr) else { return nil }
            guard let btcFee = Decimal(string: fee), btcAmount > 0 else { return nil }
            let satoshiFee = BtcToSatoshi(btcFee)
            
            var bitcoinAddress = address
            var cashAddr = address
            if self.forkId == ForkId.bch.rawValue && (address.hasPrefix("bitcoincash") || address.hasPrefix("bchtest") || address.hasPrefix("bchreg")) {
                var chars: [Int8] = Array(address.utf8).map { (byte) -> Int8 in
                    return Int8(bitPattern: byte)
                }
                chars.append(0)
                var buffer = [Int8](repeating: 0, count: 64)
                BRBCashAddrDecode(&buffer, UnsafePointer(chars))
                bitcoinAddress = String(cString: &buffer)
                
                if let index = cashAddr.firstIndex(of: ":") {
                    cashAddr = String(cashAddr.suffix(from: cashAddr.index(after: index)))
                }
            }
            
            guard checkAddressValidity(bitcoinAddress) else { return nil }
            var chars: [Int8] = Array(bitcoinAddress.utf8).map { (byte) -> Int8 in
                return Int8(bitPattern: byte)
            }
            chars.append(0)
            guard let txRef = BRWalletCreateTransaction(self.walletPtr, satoshiAmount, satoshiFee, UnsafePointer(chars)) else { return nil }
            return ATCryptocurrencyTransaction(self.walletPtr!, txRef, self.forkId == ForkId.btc.rawValue ? .btc : .bch, self.forkId == ForkId.bch.rawValue ? cashAddr : address)
        }
        else {
            // TODO: btg, bsv
            return nil
        }
    }
    
    override func destroyTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard transaction.object != nil else { return }
        transaction.freeTxRef()
    }
    
    override func generateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let txRef = transaction.object as? BRTxRef else {
            self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
            return
        }
        self.dispatchQueue.async {
            var dataInfos = [BRTxUnsignedDataInfo](repeating: BRTxUnsignedDataInfo(), count: BRWalletGenerateTransactionDataForSigning(self.walletPtr, txRef, nil))
            BRWalletGenerateTransactionDataForSigning(self.walletPtr, txRef, UnsafeMutablePointer<BRTxUnsignedDataInfo>(&dataInfos))
            var unsignedDataInfos: [ATCryptocurrencyTransaction.UnsignedTransactionDataInfo] = []
            dataInfos.forEach({ (dataInfo) in
                ATLog.debug("Chain ID: \(dataInfo.chainId), Key ID: \(dataInfo.keyId), Unsigned Data: \(dataInfo.data.data as NSData)")
                let unsignedTxDataInfo = ATCryptocurrencyTransaction.UnsignedTransactionDataInfo(chainId: dataInfo.chainId, keyId: dataInfo.keyId, data: ATUInt256(dataInfo.data.bytes))
                unsignedDataInfos.append(unsignedTxDataInfo)
            })
            guard unsignedDataInfos.count > 0 else {
                self.delegate?.abstractWalletDidFailToGenerateTransactionDataForSigning(transaction, .failToPrepareForSign)
                return
            }
            transaction.unsignedTransactionDataInfos = unsignedDataInfos
            self.delegate?.abstractWalletDidGenerateTransactionDataForSigning(transaction)
        }
    }
    
    override func generateSignedTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let txRef = transaction.object as? BRTxRef else {
            self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            return
        }
        guard let signatures = transaction.rsvSignatures else {
            self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            return
        }
        guard let unsignedDataInfos = transaction.unsignedTransactionDataInfos else {
            self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            return
        }
        var txSignatures: [BRTxSignature] = []
        signatures.forEach { (data) in
            guard let der = data.toDER() else {
                ATLog.info("Failed to convert rsv to der")
                return
            }
            ATLog.debug("Signature(r,s,v): \(data as NSData)")
            ATLog.debug("DER: \(der as NSData)")
            
            var bytes = [UInt8](der)
            let signatureLen = bytes.count
            for _ in bytes.count..<73 {
                bytes.append(0)
            }
            let txSignature = BRTxSignature(signature: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9],
                                                        bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15], bytes[16], bytes[17], bytes[18], bytes[19],
                                                        bytes[20], bytes[21], bytes[22], bytes[23], bytes[24], bytes[25], bytes[26], bytes[27], bytes[28], bytes[29],
                                                        bytes[30], bytes[31], bytes[32], bytes[33], bytes[34], bytes[35], bytes[36], bytes[37], bytes[38], bytes[39],
                                                        bytes[40], bytes[41], bytes[42], bytes[43], bytes[44], bytes[45], bytes[46], bytes[47], bytes[48], bytes[49],
                                                        bytes[50], bytes[51], bytes[52], bytes[53], bytes[54], bytes[55], bytes[56], bytes[57], bytes[58], bytes[59],
                                                        bytes[60], bytes[61], bytes[62], bytes[63], bytes[64], bytes[65], bytes[66], bytes[67], bytes[68], bytes[69],
                                                        bytes[70], bytes[71], bytes[72]), signatureLen: signatureLen)
            txSignatures.append(txSignature)
        }
        var dataInfos: [BRTxUnsignedDataInfo] = []
        unsignedDataInfos.forEach { (info) in
            let dataInfo = BRTxUnsignedDataInfo(chainId: info.chainId, keyId: info.keyId, data: UInt256(bytes: info.data.bytes))
            dataInfos.append(dataInfo)
        }
        DispatchQueue(label: "com.AuthenTrend.ATWalletKit.BRBitcoinWallet.generateSignedTransaction").async {
            if BRWalletGenerateSignedTransaction(self.walletPtr, txRef, UnsafePointer<BRTxUnsignedDataInfo>(dataInfos), dataInfos.count, UnsafePointer<BRTxSignature>(txSignatures), txSignatures.count) != 0 {
                self.delegate?.abstractWalletDidGenerateSignedTransaction(transaction)
            }
            else {
                self.delegate?.abstractWalletDidFailToGenerateSignedTransaction(transaction, .failToSign)
            }
        }
    }
    
    override func publishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        guard let txRef = transaction.object as? BRTxRef else {
            self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
            return
        }
        guard self.publishingTransaction == nil else {
            ATLog.debug("Previous publishing has not completed yet")
            self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
            return
        }
        self.publishingTransaction = transaction
        self.dispatchQueue.async {
            BRPeerManagerPublishTx(self.peerManagerPtr, txRef, Unmanaged.passUnretained(self).toOpaque(), { (info, error) in
                guard let info = info else { return }
                let err = BRPeerManagerError.posixError(errorCode: error, description: String(cString: strerror(error)))
                Unmanaged<BRBitcoinWallet>.fromOpaque(info).takeUnretainedValue().publishCompleted(error != 0 ? err : nil)
            })
        }
    }
    
    // MARK: - BRWalletListener
    
    func balanceChanged(_ balance: UInt64) {
        ATLog.debug("\(#function)")
        self.delegate?.abstractWalletDidUpdateBalance(ATUInt256(balance))
        self.delegate?.abstractWalletDidUpdateTransaction()
        self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(0, UInt32(BRWalletNumberOfUsedPublicKey(self.walletPtr, 0)))
        self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(1, UInt32(BRWalletNumberOfUsedPublicKey(self.walletPtr, 1)))
    }
    
    func txAdded(_ tx: BRTxRef) {
        ATLog.debug("\(#function)")
        ATLog.debug("txHash: \(tx.pointee.txHash.data as NSData)")
        ATLog.debug("wtxHash: \(tx.pointee.wtxHash.data as NSData)")
        ATLog.debug("version: \(tx.pointee.version)")
        ATLog.debug("inCount: \(tx.pointee.inCount)")
        ATLog.debug("outCount: \(tx.pointee.outCount)")
        ATLog.debug("lockTime: \(tx.pointee.lockTime)")
        ATLog.debug("blockHeight: \(tx.pointee.blockHeight)");
        ATLog.debug("timestamp: \(tx.pointee.timestamp)");
        let received = BRWalletAmountReceivedFromTx(self.walletPtr, tx)
        let sent = BRWalletAmountSentByTx(self.walletPtr, tx)
        let fee = BRWalletFeeForTx(self.walletPtr, tx)
        ATLog.debug("Tx: received \(received), sent \(sent), fee \(fee)")
        self.dispatchQueue.async {
            do {
                try self.dataStack.perform(synchronous: { (transaction) -> Void in
                    var buf = [UInt8](repeating: 0, count: BRTransactionSerialize(tx, nil, 0))
                    guard BRTransactionSerialize(tx, &buf, buf.count) == buf.count else { return }

                    var item: Transaction?
                    do {
                        if let itm = try transaction.fetchOne(From<Transaction>().where(\.txHash == tx.pointee.txHash.data)) {
                            item = itm
                        }
                        else {
                            item = transaction.create(Into<Transaction>())
                            item!.txHash.value = tx.pointee.txHash.data
                        }
                        item!.timestamp.value = Int32(bitPattern: tx.pointee.timestamp)
                        item!.blockHeight.value = Int32(bitPattern: tx.pointee.blockHeight)
                        item!.txBuffer.value = Data(buf)
                    } catch {
                        ATLog.error("Entity Transaction not found")
                    }
                })
            } catch {
                ATLog.debug("Failed to add transaction")
            }
        }
    }
    
    func txUpdated(_ txHashes: [UInt256], _ blockHeight: UInt32, _ timestamp: UInt32) {
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            do {
                try self.dataStack.perform(synchronous: { (transaction) -> Void in
                    guard txHashes.count > 0 else { return }
                    txHashes.forEach({ (txHash) in
                        do {
                            guard let item = try transaction.fetchOne(From<Transaction>().where(\.txHash == txHash.data)) else {
                                ATLog.debug("tx hash not found")
                                return
                            }
                            item.timestamp.value = Int32(bitPattern: timestamp)
                            item.blockHeight.value = Int32(bitPattern: blockHeight)
                        } catch {
                            ATLog.error("Entity Transaction not found")
                        }
                    })
                })
            } catch {
                ATLog.debug("Failed to update transaction")
            }
        }
    }
    
    func txDeleted(_ txHash: UInt256, _ notifyUser: Bool, _ recommendRescan: Bool) {
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            do {
                try self.dataStack.perform(synchronous: { (transaction) -> Void in
                    guard let item = try transaction.fetchOne(From<Transaction>().where(\.txHash == txHash.data)) else {
                        ATLog.debug("tx hash not found")
                        return
                    }
                    transaction.delete(item)
                })
            } catch {
                ATLog.debug("Failed to delete transaction")
            }
        }
        if notifyUser && recommendRescan {
            self.delegate?.abstractWalletDidRequestResync()
        }
        self.delegate?.abstractWalletDidUpdateTransaction()
    }
    
    // MARK: - BRPeerManagerListener
    
    func syncStarted() {
        ATLog.debug("\(#function)")
        self.delegate?.abstractWalletDidStartSync()
    }
    
    func syncStopped(_ error: BRPeerManagerError?) {
        ATLog.debug("\(#function)")
        switch error {
        case .none:
            ATLog.debug("Sync complete")
            self.delegate?.abstractWalletDidStopSync(nil)
            self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(0, UInt32(BRWalletNumberOfUsedPublicKey(self.walletPtr, 0)))
            self.delegate?.abstractWalletDidUpdateNumberOfUsedPublicKey(1, UInt32(BRWalletNumberOfUsedPublicKey(self.walletPtr, 1)))
        case .some(let .posixError(errorCode, description)):
            ATLog.debug("Sync error: \(description) \(errorCode)")
            self.delegate?.abstractWalletDidStopSync(.failToSync)
        }
    }
    
    func txStatusUpdate() {
        ATLog.debug("\(#function)")
        self.delegate?.abstractWalletDidUpdateTransaction()
    }
    
    func saveBlocks(_ replace: Bool, _ blockRefs: [BRBlockRef?]) {
        ATLog.debug("\(#function)")
        // make a copy before crossing thread boundary
        let blocks: [BRBlockRef?] = blockRefs.map { blockRef in
            if let b = blockRef {
                return BRMerkleBlockCopy(&b.pointee)
            } else {
                return nil
            }
        }
        
        self.dispatchQueue.async {
            do {
                try self.dataStack.perform(synchronous: { (transaction) -> Void in
                    if replace {
                        do {
                            try transaction.deleteAll(From<Block>())
                        } catch {
                            ATLog.error("Entity Block not found")
                        }
                    }
                    blocks.forEach({ (blockRef) in
                        guard let block = blockRef?.pointee else { return }
                        let height = Int32(bitPattern: block.height)
                        guard height != BLOCK_UNKNOWN_HEIGHT else {
                            ATLog.debug("skipped block with invalid blockheight: \(height)")
                            BRMerkleBlockFree(blockRef)
                            return
                        }
                        
                        let blockHashData = block.blockHash.data
                        do {
                            if let _ = try transaction.fetchOne(From<Block>().where(\.blockHash == blockHashData)) {
                                ATLog.debug("Found the same block")
                                BRMerkleBlockFree(blockRef)
                                return
                            }
                        } catch {
                            ATLog.error("Entity Block not found")
                        }
                        let item = transaction.create(Into<Block>())
                        item.blockHash.value = blockHashData
                        item.version.value = Int32(bitPattern: block.version)
                        item.prevBlock.value = block.prevBlock.data
                        item.merkleRoot.value = block.merkleRoot.data
                        item.timestamp.value = Int32(bitPattern: block.timestamp)
                        item.target.value = Int32(bitPattern: block.target)
                        item.nonce.value = Int32(bitPattern: block.nonce)
                        item.totalTx.value = Int32(bitPattern: block.totalTx)
                        item.height.value = height
                        
                        let hashes = Array(UnsafeBufferPointer(start: block.hashes, count: block.hashesCount))
                        var hashesData = Data()
                        hashes.forEach({ (hash) in
                            hashesData.append(hash.data)
                        })
                        item.hashes.value = hashesData
                        item.hashesCount.value = block.hashesCount
                        
                        let flags = Array(UnsafeBufferPointer(start: block.flags, count: block.flagsLen))
                        item.flags.value = Data(flags)
                        item.flagsLen.value = block.flagsLen
                        
                        BRMerkleBlockFree(blockRef)
                    })
                })
            } catch {
                ATLog.debug("Failed to save blocks")
            }
        }
    }
    
    func savePeers(_ replace: Bool, _ peers: [BRPeer]) {
        ATLog.debug("\(#function)")
        self.dispatchQueue.async {
            do {
                try self.dataStack.perform(synchronous: { (transaction) -> Void in
                    if replace {
                        do {
                            try transaction.deleteAll(From<Peer>())
                        } catch {
                            ATLog.error("Entity Peer not found")
                        }
                    }
                    peers.forEach({ (peer) in
                        let addrData = peer.address.data
                        let item: Peer?
                        do {
                            if let itm = try transaction.fetchOne(From<Peer>().where(\.address == addrData)) {
                                item = itm
                            }
                            else {
                                item = transaction.create(Into<Peer>())
                                item!.address.value = addrData
                            }
                            item!.port.value = Int16(bitPattern: peer.port)
                            item!.services.value = Int64(bitPattern: peer.services)
                            item!.timestamp.value = Int64(bitPattern: (peer.timestamp))
                            item!.flags.value = Int8(bitPattern: peer.flags)
                        } catch {
                            ATLog.error("Entity Peer not found")
                        }
                    })
                })
            } catch {
                ATLog.debug("Failed to save peers")
            }
        }
    }
    
    func networkIsReachable() -> Bool {
        ATLog.debug("\(#function)")
        var flags: SCNetworkReachabilityFlags = []
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else { return false }
        if !SCNetworkReachabilityGetFlags(reachability, &flags) { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
    
    // MARK: - BRTransactionListener
    
    func publishCompleted(_ error: BRPeerManagerError?) {
        guard let transaction = self.publishingTransaction else { return }
        switch error {
        case .none:
            ATLog.debug("Publish complete")
            self.delegate?.abstractWalletDidPublishTransaction(transaction)
        case .some(let .posixError(errorCode, description)):
            ATLog.debug("Publish error: \(description) \(errorCode)")
            self.delegate?.abstractWalletDidFailToPublishTransaction(transaction, .failToPublish)
        }
    }
    
    // hack to keep the swift compiler happy
    let a = BRBCashCheckpoints
    let b = BRBCashDNSSeeds
    let c = BRBCashVerifyDifficulty
    let d = BRBCashTestNetCheckpoints
    let e = BRBCashTestNetDNSSeeds
    let f = BRBCashTestNetVerifyDifficulty
    let g = BRMainNetDNSSeeds
    let h = BRMainNetCheckpoints
    let i = BRMainNetVerifyDifficulty
    let j = BRTestNetDNSSeeds
    let k = BRTestNetCheckpoints
    let l = BRTestNetVerifyDifficulty
}
