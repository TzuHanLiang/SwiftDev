//
//  ATCryptocurrencyWallet.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/5.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation
import EthereumKit

public enum ATCryptocurrencyType : CaseIterable {
    case btc
    case bch
    case eth
    case ltc
    case doge
    case dash
    
    public var symbol: String {
        get {
            switch self {
            case .btc:
                return "BTC"
            case .bch:
                return "BCH"
            case .eth:
                return "ETH"
            case .ltc:
                return "LTC"
            case .doge:
                return "DOGE"
            case .dash:
                return "DASH"
            }
        }
    }
    
    public var name: String {
        get {
            switch self {
            case .btc:
                #if TESTNET
                return "\(NSLocalizedString("bitcoin", tableName: nil, bundle: Bundle.main, value: "Bitcoin", comment: "")) \(NSLocalizedString("testnet", tableName: nil, bundle: Bundle.main, value: "Testnet", comment: ""))"
                #else
                return NSLocalizedString("bitcoin", tableName: nil, bundle: Bundle.main, value: "Bitcoin", comment: "")
                #endif
            case .bch:
                #if TESTNET
                return "\(NSLocalizedString("bitcoin_cash", tableName: nil, bundle: Bundle.main, value: "Bitcoin Cash", comment: "")) \(NSLocalizedString("testnet", tableName: nil, bundle: Bundle.main, value: "Testnet", comment: ""))"
                #else
                return NSLocalizedString("bitcoin_cash", tableName: nil, bundle: Bundle.main, value: "Bitcoin Cash", comment: "")
                #endif
            case .eth:
                #if TESTNET
                return "Ropsten \(NSLocalizedString("ethereum", tableName: nil, bundle: Bundle.main, value: "Ethereum", comment: "")) \(NSLocalizedString("testnet", tableName: nil, bundle: Bundle.main, value: "Testnet", comment: ""))"
                #else
                return NSLocalizedString("ethereum", tableName: nil, bundle: Bundle.main, value: "Ethereum", comment: "")
                #endif
            case .ltc:
                #if TESTNET
                return "\(NSLocalizedString("litecoin", tableName: nil, bundle: Bundle.main, value: "Litecoin", comment: "")) \(NSLocalizedString("testnet", tableName: nil, bundle: Bundle.main, value: "Testnet", comment: ""))"
                #else
                return NSLocalizedString("litecoin", tableName: nil, bundle: Bundle.main, value: "Litecoin", comment: "")
                #endif
            case .doge:
                #if TESTNET
                return "\(NSLocalizedString("dogecoin", tableName: nil, bundle: Bundle.main, value: "Dogecoin", comment: "")) \(NSLocalizedString("testnet", tableName: nil, bundle: Bundle.main, value: "Testnet", comment: ""))"
                #else
                return NSLocalizedString("dogecoin", tableName: nil, bundle: Bundle.main, value: "Dogecoin", comment: "")
                #endif
            case .dash:
                #if TESTNET
                return "\(NSLocalizedString("dash", tableName: nil, bundle: Bundle.main, value: "Dash", comment: "")) \(NSLocalizedString("testnet", tableName: nil, bundle: Bundle.main, value: "Testnet", comment: ""))"
                #else
                return NSLocalizedString("dash", tableName: nil, bundle: Bundle.main, value: "Dash", comment: "")
                #endif
            }
        }
    }
    
    public var coinType: UInt32 { // with hardened
        get {
            switch self {
            case .btc:
                #if TESTNET
                return 0x80000001
                #else
                return 0x80000000
                #endif
            case .bch:
                #if TESTNET
                return 0x80000001
                #else
                return 0x80000091
                #endif
            case .eth:
                #if TESTNET
                return 0x80000001
                #else
                return 0x8000003C
                #endif
            case .ltc:
                #if TESTNET
                return 0x80000001
                #else
                return 0x80000002
                #endif
            case .doge:
                #if TESTNET
                return 0x80000001
                #else
                return 0x80000003
                #endif
            case .dash:
                #if TESTNET
                return 0x80000001
                #else
                return 0x80000005
                #endif
            }
        }
    }
    
    public var currencyType: UInt32 { // without hardened
        get {
            switch self {
            case .btc:
                return 0x00000000
            case .bch:
                return 0x00000091
            case .eth:
                return 0x0000003C
            case .ltc:
                return 0x00000002
            case .doge:
                return 0x00000003
            case .dash:
                return 0x00000005
            }
        }
    }
    
    public var scheme: String {
        get {
            switch self {
            case .btc:
                return "bitcoin"
            case .bch:
                #if TESTNET
                return "bchtest"
                #else
                return "bitcoincash"
                #endif
            case .eth:
                return "ethereum"
            case .ltc:
                return "litecoin"
            case .doge:
                return "dogecoin"
            case .dash:
                return "dash"
            }
        }
    }
    
    // SECP256K1: 0x00
    // ED25519: 0x01
    public var curve: UInt8 {
        get {
            switch self {
            case .btc:
                return 0x00
            case .bch:
                return 0x00
            case .eth:
                return 0x00
            case .ltc:
                return 0x00
            case .doge:
                return 0x00
            case .dash:
                return 0x00
            }
        }
    }
    
    public var forkId: UInt8 {
        get {
            switch self {
            case .btc:
                return 0x00
            case .bch:
                return 0x40
            case .eth:
                return 0x00
            case .ltc:
                return 0x00
            case .doge:
                return 0x00
            case .dash:
                return 0x00
            }
        }
    }
    
    public var p2pkhAddressPrefix: UInt8 {
        var prefix: UInt8 = 0
        switch self {
        case .btc, .bch:
            #if TESTNET
            prefix = 0x6F
            #else
            prefix = 0
            #endif
        case .ltc:
            #if TESTNET
            prefix = 0x6F
            #else
            prefix = 0x30
            #endif
        case .doge:
            #if TESTNET
            prefix = 0x71
            #else
            prefix = 0x1E
            #endif
        case .dash:
            #if TESTNET
            prefix = 0x8C
            #else
            prefix = 0x4C
            #endif
        default:
            break
        }
        return prefix
    }
    
    public var p2shAddressPrefix: UInt8 {
        var prefix: UInt8 = 0
        switch self {
        case .btc, .bch:
            #if TESTNET
            prefix = 0xC4
            #else
            prefix = 0x05
            #endif
        case .ltc:
            #if TESTNET
            //prefix = 0xC4 // deprecated
            prefix = 0x3A
            #else
            //prefix = 0x05 // deprecated
            prefix = 0x32
            #endif
        case .doge:
            #if TESTNET
            prefix = 0xC4
            #else
            prefix = 0x16
            #endif
        case .dash:
            #if TESTNET
            prefix = 0x13
            #else
            prefix = 0x10
            #endif
        default:
            break
        }
        return prefix
    }
    
    public var cashAddrHRP: String {
        guard self == .bch else { return "" }
        #if TESTNET
        return "bchtest"
        #else
        return "bitcoincash"
        #endif
    }
    
    public var bech32HRP: String {
        var hrp: String = ""
        switch self {
        case .btc:
            #if TESTNET
            hrp = "tb"
            #else
            hrp = "bc"
            #endif
        case .ltc:
            #if TESTNET
            hrp = "tltc"
            #else
            hrp = "ltc"
            #endif
        default:
            break
        }
        return hrp
    }
    
    public var bech32Separator: String {
        var separator: String = ""
        switch self {
        case .btc, .ltc:
            separator = "1"
        default:
            break
        }
        return separator
    }
    
    public var isSegWitSupported: Bool {
        switch self {
        case .btc, .ltc:
            return true
        default:
            return false
        }
    }
}

public protocol ATCryptocurrencyWalletDelegate {
    func cryptocurrencyWalletDidInit(_ wallet: ATCryptocurrencyWallet)
    func cryptocurrencyWalletDidFailToInit(_ wallet: ATCryptocurrencyWallet, _ error: ATError?)
    func cryptocurrencyWalletDidStartSync(_ wallet: ATCryptocurrencyWallet)
    func cryptocurrencyWalletDidStopSync(_ wallet: ATCryptocurrencyWallet, _ error: ATError?)
    func cryptocurrencyWalletDidUpdateBalance(_ wallet: ATCryptocurrencyWallet)
    func cryptocurrencyWalletDidUpdateTransaction(_ wallet: ATCryptocurrencyWallet)
    func cryptocurrencyWalletDidUpdateTokens(_ wallet: ATCryptocurrencyWallet)
    func cryptocurrencyWalletDidPrepareForSigningTransaction(_ transaction: ATCryptocurrencyTransaction)
    func cryptocurrencyWalletDidFailToPrepareForSigningTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError)
    func cryptocurrencyWalletDidSignTransaction(_ transaction: ATCryptocurrencyTransaction)
    func cryptocurrencyWalletDidFailToSignTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError)
    func cryptocurrencyWalletDidPublishTransaction(_ transaction: ATCryptocurrencyTransaction)
    func cryptocurrencyWalletDidFailToPublishTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError)
}

extension ATAbstractWallet {
    static func convertBalanceToString(Balance balance: ATUInt256, CurrencyType type: ATCryptocurrencyType) -> String {
        switch type {
        case .btc, .bch, .ltc, .doge, .dash:
            // 1 BTC  == 100,000,000 satoshi
            // 1 LTC  == 100,000,000 litoshi
            // 1 DOGE == 100,000,000 sadoge
            // 1 DASH == 100,000,000 duff
            let coin = Decimal(balance.uint64) / 100000000
            return coin.toString()
        case .eth:
            guard let wei = balance.bint, let ether = try? Converter.toEther(wei: wei) else { return "0" }
            return ether.toString()
        }
    }
}

public class ATCryptocurrencyWallet : NSObject, ATAbstractWalletDelegate {
    
    private let dispatchQueue: DispatchQueue

    private weak var coldWallet: ATColdWallet?
    
    private var currencyWallet: ATAbstractWallet?
    private var creationTimestamp: UInt32?
    private var balance: ATUInt256
    
    public let uid: [UInt8]
    public let purpose: UInt32
    public let coinType: UInt32
    public let accountValue: UInt32
    public let currencyType: ATCryptocurrencyType
    
    internal(set) public var name: String
    internal(set) public var accountIndex: UInt32
    internal(set) public var numberOfUsedExternalKey: UInt32
    internal(set) public var numberOfUsedInternalKey: UInt32
    internal(set) public var externalPublicKeys: [[UInt8]]
    internal(set) public var internalPublicKeys: [[UInt8]]
    internal(set) public var isSyncing = false
    internal(set) public var lastSyncTime: TimeInterval = 0
    internal(set) public var initializing = false;
    
    public var delegate: ATCryptocurrencyWalletDelegate?
    public var exchangeRates = [String: Double]()
    
    public var balanceString: String {
        get {
            return self.currencyWallet?.getBalanceString() ?? ATAbstractWallet.convertBalanceToString(Balance: self.balance, CurrencyType: self.currencyType)
        }
    }
    
    public var receivingAddress: String {
        get {
            return self.currencyWallet?.getReceivingAddress() ?? ""
        }
    }
    
    public var receivingAddressesWithFormat: [String: String]? {
        get {
            return self.currencyWallet?.getReceivingAddressesWithFormat()
        }
    }
    
    public var transactions: [ATCryptocurrencyTransaction] {
        get {
            return self.currencyWallet?.getTransactions() ?? []
        }
    }
    
    public var initialized: Bool {
        get {
            return self.currencyWallet != nil
        }
    }
    
    public var tokens: [ATCryptocurrencyToken] {
        guard self.currencyType == .eth else { return [] }
        return self.currencyWallet?.getTokens() ?? []
    }
    
    init(ColdWallet coldWallet: ATColdWallet?, Purpose purpose: UInt32, CoinType coinType: UInt32, Account account: UInt32, AccountIndex index: UInt32, Name name: String, Balance balance: ATUInt256, ExtKeys numberOfExtKey: UInt32, IntKeys numberOfIntKey: UInt32, CreationTime timestamp: UInt32, UniqueId uid:[UInt8], CurrencyType currencyType: UInt32) {
        ATLog.debug("Purpose: \(String(format: "%08X", purpose)), CoinType: \(String(format: "%08X", coinType)), Account: \(String(format: "%08X", account)), Number of Used External Key: \(numberOfExtKey), Number of Used Internal Key: \(numberOfIntKey)")
        self.coldWallet = coldWallet
        self.purpose = purpose
        self.coinType = coinType
        self.accountValue = account
        self.accountIndex = index
        self.name = name
        self.balance = balance
        self.numberOfUsedExternalKey = numberOfExtKey
        self.numberOfUsedInternalKey = numberOfIntKey
        self.externalPublicKeys = []
        self.internalPublicKeys = []
        self.creationTimestamp = timestamp
        self.uid = uid
        self.dispatchQueue = DispatchQueue(label: "com.AuthenTrend.ATWalletKit.ATCryptocurrencyWallet")
        
        var currency: ATCryptocurrencyType?
        for type in ATCryptocurrencyType.allCases {
            if type.currencyType == currencyType {
                currency = type
                break
            }
        }
        guard let type = currency else {
            ATLog.error("Unsupported currency type")
            abort()
        }
        self.currencyType = type
        
        super.init()
    }
    
    private func initCurrencyWallet(_ pubKey: [UInt8], _ chainCode: [UInt8], _ fingerprint: UInt32) {
        switch self.currencyType {
        /*
        case .btc: // breadwallet-core
            guard let wallet = BRBitcoinWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, ForkId: .btc, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        */
        case .btc: // CryptoAPIs
            guard let wallet = CABitcoinWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self, SegWitAccount: self.purpose == (UInt32(0x80000000) | 84)) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        /*
        case .bch: // breadwallet-core
            guard let wallet = BRBitcoinWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, ForkId: .bch, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        */
        case .bch: // CryptoAPIs
            guard let wallet = CABitcoinCashWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        /*
        case .eth: // Infura
            guard let wallet = EKEthereumWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        */
        case .eth: // CryptoAPIs
            guard let wallet = CAEthereumWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        case .ltc: // CryptoAPIs
            guard let wallet = CALitecoinWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self, SegWitAccount: self.purpose == (UInt32(0x80000000) | 84)) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        case .doge: // CryptoAPIs
            guard let wallet = CADogecoinWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        case .dash: // CryptoAPIs
            guard let wallet = CADashWallet(UniqueId: self.uid, EarlistKeyTime: self.creationTimestamp ?? 0, PublicKey: pubKey, ChainCode: chainCode, FingerprintOfParentKey: fingerprint, Delegate: self) else {
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToInitWallet)
                }
                return
            }
            
            self.currencyWallet = wallet
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
        }
    }
    
    private func deinitCurrencyWallet() {
        self.currencyWallet?.delegate = nil
        self.currencyWallet?.stopAutoSync()
        self.currencyWallet = nil
    }
    
    func updateColdWalletBalance() {
        ATLog.debug("\(#function)")
        guard let balance = self.currencyWallet?.getBalance() else { return }
        self.coldWallet?.updateWalletBalance(AccountIndex: self.accountIndex, Balance: balance, Delegate: ATColdWalletDelegate() {(delegate) in
            delegate.coldWalletDidFailToConnect = {
                ATLog.info("\(ATError.failToConnect.description)")
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                ATLog.info("\(error.description)")
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                ATLog.info("\(ATError.loginRequired.description)")
            }
            
            delegate.coldWalletDidUpdateWalletBalance = {
                ATLog.debug("Update wallet balance succeeded")
            }
        })
    }
    
    public func initWallet() {
        ATLog.debug("\(#function)")
        self.initializing = true
        guard self.currencyWallet == nil else {
            self.initializing = false
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidInit(self)
            }
            return
        }
        
        var path: [UInt32] = []
        path.append(self.purpose | 0x80000000)
        path.append(self.coinType | 0x80000000)
        path.append(self.accountValue | 0x80000000)
        
        self.coldWallet?.hdwallet?.getExtendedPublicKeyInfo(path, { (key, chainCode, fingerprint, error) in
            if error != nil {
                ATLog.error("Failed to get extended public key info")
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToUpdateWalletKeyInfo)
                }
                return
            }
            guard var key = key, let chainCode = chainCode, let fingerprint = fingerprint else {
                ATLog.error("Failed to get extended public key info")
                self.initializing = false
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToInit(self, .failToUpdateWalletKeyInfo)
                }
                return
            }
            if key.count == 64 { // uncompressed: 64 bytes
                key.insert(0x04, at: 0) // 0x04 is the prefix for uncompressed public key
            }
            else if (key[31] & 0x01) > 0 { // compressed: 32 bytes
                key.insert(0x03, at: 0) // 0x03 is the prefix for compressed public key that y is odd
            }
            else {
                key.insert(0x02, at: 0) // 0x02 is the prefix for compressed public key that y is even
            }
            self.initCurrencyWallet(key, chainCode, fingerprint)
        })
    }
    
    public func deinitWallet() {
        deinitCurrencyWallet()
    }
    
    public func syncWallet() {
        ATLog.debug("\(#function)")
        if self.currencyWallet == nil {
            DispatchQueue.main.async {
                self.abstractWalletDidStartSync()
                self.abstractWalletDidStopSync(.uninitialized)
            }
        }
        else {
            self.currencyWallet?.startSync()
        }
    }
    
    public func checkAddressValidity(_ address: String) -> Bool {
        guard let wallet = self.currencyWallet else { return false }
        return wallet.checkAddressValidity(address)
    }
    
    public func containAddress(_ address: String) -> Bool {
        guard let wallet = self.currencyWallet else { return false }
        return wallet.containAddress(address)
    }
    
    public func calculateMinimumFee(_ amount: String, _ message: String? = nil, _ token: ATCryptocurrencyToken? = nil) -> String {
        guard let wallet = self.currencyWallet else { return "0" }
        guard let value = Double(amount), value > 0 else { return "0" }
        return (token == nil) ? wallet.calculateMinimumFee(amount, message) : wallet.calculateTokenMinimumFee(token!, amount, message)
    }
    
    public func calculateLowFee(_ amount: String, _ message: String? = nil, _ token: ATCryptocurrencyToken? = nil) -> String {
        guard let wallet = self.currencyWallet else { return "0" }
        guard let value = Double(amount), value > 0 else { return "0" }
        return (token == nil) ? wallet.calculateLowFee(amount, message) : wallet.calculateTokenLowFee(token!, amount, message)
    }
    
    public func calculateMediumFee(_ amount: String, _ message: String? = nil, _ token: ATCryptocurrencyToken? = nil) -> String {
        guard let wallet = self.currencyWallet else { return "0" }
        guard let value = Double(amount), value > 0 else { return "0" }
        return (token == nil) ? wallet.calculateMediumFee(amount, message) : wallet.calculateTokenMediumFee(token!, amount, message)
    }
    
    public func calculateHighFee(_ amount: String, _ message: String? = nil, _ token: ATCryptocurrencyToken? = nil) -> String {
        guard let wallet = self.currencyWallet else { return "0" }
        guard let value = Double(amount), value > 0 else { return "0" }
        return (token == nil) ? wallet.calculateHighFee(amount, message) : wallet.calculateTokenHighFee(token!, amount, message)
    }
    
    public func getMaxOutputAmount(_ token: ATCryptocurrencyToken? = nil) -> String {
        guard let wallet = self.currencyWallet else { return "0" }
        return (token == nil) ? wallet.getMaxOutputAmount() : wallet.getTokenMaxOutputAmount(token!)
    }
    
    public func getMinOutputAmount(_ token: ATCryptocurrencyToken? = nil) -> String {
        guard let wallet = self.currencyWallet else { return "0" }
        return (token == nil) ? wallet.getMinOutputAmount() : wallet.getTokenMinOutputAmount(token!)
    }
    
    public func createTransaction(_ amount: String, _ fee: String, _ address: String, _ message: String? = nil, _ token: ATCryptocurrencyToken? = nil) -> ATCryptocurrencyTransaction? {
        guard let wallet = self.currencyWallet else { return nil }
        return (token == nil) ? wallet.createTransaction(amount, fee, address, message) : wallet.createTokenTransaction(token!, amount, fee, address, message)
    }
    
    public func destroyTransaction(_ transaction: ATCryptocurrencyTransaction) {
        guard let wallet = self.currencyWallet else { return }
        return wallet.destroyTransaction(transaction)
    }
    
    public func prepareForSigningTransaction(_ transaction: ATCryptocurrencyTransaction) {
        guard let wallet = self.currencyWallet else {
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidFailToPrepareForSigningTransaction(transaction, .failToPrepareForSign)
            }
            return
        }
        wallet.generateTransactionDataForSigning(transaction)
    }
    
    public func cancelSigningTransaction(_ transaction: ATCryptocurrencyTransaction) {
        self.coldWallet?.cancelToSignData()
        destroyTransaction(transaction)
    }
    
    public func signTransaction(_ transaction: ATCryptocurrencyTransaction) {
        self.coldWallet?.signDataWithFpVerificationResult(Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToSignTransaction(transaction, error)
                }
            }
            
            delegate.coldWalletDidSignData = { (signatures) in
                transaction.rsvSignatures = signatures
                guard let wallet = self.currencyWallet else {
                    DispatchQueue.main.async {
                        self.delegate?.cryptocurrencyWalletDidFailToSignTransaction(transaction, .failToSign)
                    }
                    return
                }
                wallet.generateSignedTransaction(transaction)
            }
        })
    }
    
    public func publishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        guard let wallet = self.currencyWallet else {
            DispatchQueue.main.async {
                self.delegate?.cryptocurrencyWalletDidFailToPublishTransaction(transaction, .failToPublish)
            }
            return
        }
        wallet.publishTransaction(transaction)
    }
    
    // MARK: - ATAbstractWalletDelegate
    
    func abstractWalletDidUpdateBalance(_ balance: ATUInt256) {
        ATLog.debug("\(#function)")
        ATLog.debug("\(self.currencyType.symbol) Balance: \(Data(balance.bytes) as NSData)")
        if balance != self.balance {
            self.balance = balance
            updateColdWalletBalance()
        }
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidUpdateBalance(self)
        }
    }
    
    func abstractWalletDidStartSync() {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            if self.isSyncing == false {
                self.isSyncing = true
                self.delegate?.cryptocurrencyWalletDidStartSync(self)
            }
        }
    }
    
    func abstractWalletDidStopSync(_ error: ATError?) {
        ATLog.debug("\(#function)")
        if error == nil {
            self.lastSyncTime = Date().timeIntervalSince1970
            updateColdWalletBalance()
        }
        DispatchQueue.main.async {
            if self.isSyncing == true {
                self.isSyncing = false
                self.delegate?.cryptocurrencyWalletDidStopSync(self, error)
            }
        }
    }
    
    func abstractWalletDidRequestResync() {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.currencyWallet?.startSync()
        }
    }
    
    func abstractWalletDidUpdateTransaction() {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidUpdateTransaction(self)
        }
    }
    
    func abstractWalletDidUpdateTokens() {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidUpdateTokens(self)
        }
    }
    
    func abstractWalletDidGenerateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        self.coldWallet?.prepareToSignDataWithFpVerification(AccountIndex: self.accountIndex, Transaction: transaction, Delegate: ATColdWalletDelegate { (delegate) in
            delegate.coldWalletDidFailToConnect = {
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToPrepareForSigningTransaction(transaction, .failToConnect)
                }
            }
            
            delegate.coldWalletDidFailToExecuteCommand = { (error) in
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToPrepareForSigningTransaction(transaction, error)
                }
            }
            
            delegate.coldWalletNeedsLoginWithFingerprint = {
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidFailToPrepareForSigningTransaction(transaction, .loginRequired)
                }
            }
            
            delegate.coldWalletDidPrepareToSignData = {
                DispatchQueue.main.async {
                    self.delegate?.cryptocurrencyWalletDidPrepareForSigningTransaction(transaction)
                }
            }
        })
    }
    
    func abstractWalletDidFailToGenerateTransactionDataForSigning(_ transaction: ATCryptocurrencyTransaction, _ error: ATError) {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidFailToPrepareForSigningTransaction(transaction, error)
        }
    }
    
    func abstractWalletDidGenerateSignedTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidSignTransaction(transaction)
        }
    }
    
    func abstractWalletDidFailToGenerateSignedTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError) {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidFailToSignTransaction(transaction, error)
        }
    }
    
    func abstractWalletDidPublishTransaction(_ transaction: ATCryptocurrencyTransaction) {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidPublishTransaction(transaction)
        }
    }
    
    func abstractWalletDidFailToPublishTransaction(_ transaction: ATCryptocurrencyTransaction, _ error: ATError) {
        ATLog.debug("\(#function)")
        DispatchQueue.main.async {
            self.delegate?.cryptocurrencyWalletDidFailToPublishTransaction(transaction, error)
        }
    }
    
    func abstractWalletDidUpdateNumberOfUsedPublicKey(_ chainId:UInt32, _ count:UInt32) {
        ATLog.debug("\(#function)")
        if chainId == 0 {
            guard count != ((self.numberOfUsedExternalKey == 0) ? self.numberOfUsedExternalKey : (self.numberOfUsedExternalKey - 1)) else { return }
            self.coldWallet?.updateWalletExternalKeyIndex(AccountIndex: self.accountIndex, KeyId: count, Delegate: ATColdWalletDelegate { (delegate) in
                delegate.coldWalletDidFailToConnect = {
                    ATLog.debug("Failed to connect")
                }
                
                delegate.coldWalletDidFailToExecuteCommand = { (error) in
                    ATLog.debug("\(error.description)")
                }
                
                delegate.coldWalletNeedsLoginWithFingerprint = {
                    ATLog.debug("Login required")
                }
                
                delegate.coldWalletDidUpdateWalletExternalKeyIndex = {
                    self.numberOfUsedExternalKey = count + 1 // the number on card is the real number plus one
                    ATLog.debug("External key index has been updated")
                }
            })
        }
        else if chainId == 1 {
            guard count > ((self.numberOfUsedInternalKey == 0) ? self.numberOfUsedInternalKey : (self.numberOfUsedInternalKey - 1)) else { return }
            self.coldWallet?.updateWalletInternalKeyIndex(AccountIndex: self.accountIndex, KeyId: count, Delegate: ATColdWalletDelegate { (delegate) in
                delegate.coldWalletDidFailToConnect = {
                    ATLog.debug("Failed to connect")
                }
                
                delegate.coldWalletDidFailToExecuteCommand = { (error) in
                    ATLog.debug("\(error.description)")
                }
                
                delegate.coldWalletNeedsLoginWithFingerprint = {
                    ATLog.debug("Login required")
                }
                
                delegate.coldWalletDidUpdateWalletInternalKeyIndex = {
                    self.numberOfUsedInternalKey = count + 1 // the number on card is the real number plus one
                    ATLog.debug("Internal key index has been updated")
                }
            })
        }
    }
 }
