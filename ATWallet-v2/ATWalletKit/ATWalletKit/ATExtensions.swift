//
//  ATExtensions.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/10/9.
//

import Foundation
import CryptoEthereumSwift
import EthereumKit
import BRCore

extension Double {
    func toString(_ decimalPlace: UInt8) -> String {
        var str = String(format: "%.\(decimalPlace)f", self)
        while let c = str.last, c == "0" {
            str.removeLast()
        }
        if let c = str.last, c == "." {
            str.append("0")
        }
        return str
    }
}

extension Decimal {
    var uint64: UInt64 {
        return NSDecimalNumber(decimal: self).uint64Value
    }
    
    func toString() -> String {
        return "\(self)"
    }
}

extension Data {
    var ripemd160: Data {
        return CryptoHash.ripemd160(self)
    }
    
    var base58: String {
        return Base58.encode(self)
    }
    
    var base58Check: String {
        var buffer = self
        let checksum = buffer.sha256().sha256().prefix(4)
        buffer.append(checksum)
        return buffer.base58
    }
    
    func pubkeyToP2PKHAddress(_ type: ATCryptocurrencyType) -> String {
        var buffer = self.sha256().ripemd160
        buffer.insert(type.p2pkhAddressPrefix, at: 0)
        let checksum = buffer.sha256().sha256().prefix(4)
        buffer.append(checksum)
        return buffer.base58
    }
    
    func pubkeyToP2SHAddress(_ type: ATCryptocurrencyType) -> String {
        let redeemScript = pubkeyToP2SHRedeemScript()
        var buffer = redeemScript.sha256().ripemd160
        buffer.insert(type.p2shAddressPrefix, at: 0)
        let checksum = buffer.sha256().sha256().prefix(4)
        buffer.append(checksum)
        return buffer.base58
    }
    
    func pubkeyToP2PKHScript() -> Data {
        var script = Data()
        script.append(UInt8(OP_DUP))
        script.append(UInt8(OP_HASH160))
        script.append(UInt8(20))
        script.append(self.sha256().ripemd160)
        script.append(UInt8(OP_EQUALVERIFY))
        script.append(UInt8(OP_CHECKSIG))
        return script
    }
    
    func pubkeyHashToP2PKHScript() -> Data {
        var script = Data()
        script.append(UInt8(OP_DUP))
        script.append(UInt8(OP_HASH160))
        script.append(UInt8(20))
        script.append(self)
        script.append(UInt8(OP_EQUALVERIFY))
        script.append(UInt8(OP_CHECKSIG))
        return script
    }
    
    func pubkeyToP2SHRedeemScript() -> Data {
        var redeemScript = Data()
        // One-Signature-Required
        redeemScript.append(UInt8(self.count))
        redeemScript.append(self)
        redeemScript.append(UInt8(OP_CHECKSIG))
        /*// N-of-M Multiple Signatures
        redeemScript.append(UInt8(OP_1))
        redeemScript.append(UInt8(self.count))
        redeemScript.append(self)
        redeemScript.append(UInt8(OP_1))
        redeemScript.append(UInt8(0xAE)) // OP_CHECKMULTISIG
        */
        return redeemScript
    }
    
    func pubkeyToP2SHScript() -> Data {
        let redeemScript = pubkeyToP2SHRedeemScript()
        
        var script = Data()
        script.append(UInt8(OP_HASH160))
        script.append(UInt8(20))
        script.append(redeemScript.sha256().ripemd160)
        script.append(UInt8(OP_EQUAL))
        return script
    }
    
    func redeemScriptHashToP2SHScript() -> Data {
        var script = Data()
        script.append(UInt8(OP_HASH160))
        script.append(UInt8(20))
        script.append(self)
        script.append(UInt8(OP_EQUAL))
        return script
    }
    
    func pubkeyToP2PKHCashAddress() -> String? {
        CashAddressCoder.encode(self.sha256().ripemd160, prefix: ATCryptocurrencyType.bch.cashAddrHRP)
        return pubkeyToP2PKHAddress(.bch).p2pkhAddressToCashAddress()
    }
    
    func pubkeyToP2WPKHAddress(_ type: ATCryptocurrencyType) -> String? {
        guard type == .btc || type == .ltc else { return nil }
        return try? SegwitAddressCoder().encode(hrp: type.bech32HRP, version: 0, program: self.sha256().ripemd160)
    }
    
    func pubkeyToP2WPKHScript() -> Data {
        var script = Data()
        script.append(UInt8(OP_0))
        script.append(UInt8(20))
        script.append(self.sha256().ripemd160)
        return script
    }
    
    func pubkeyHashToP2WPKHScript() -> Data {
        var script = Data()
        script.append(UInt8(OP_0))
        script.append(UInt8(20))
        script.append(self)
        return script
    }
}

extension String {
    
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
    
    func base58CheckDecode() -> Data? {
        guard var decodedData = Base58.decode(self), decodedData.count > 4 else { return nil }
        let checksum = decodedData.subdata(in: (decodedData.count-4)..<decodedData.count)
        decodedData = decodedData.subdata(in: 0..<(decodedData.count-4))
        guard decodedData.sha256().sha256().prefix(4) == checksum else { return nil }
        return decodedData
    }
    
    func cashAddressEncode() -> String? {
        guard let addrData = self.data(using: .ascii) else { return nil }
        let addrArray = [UInt8](addrData).map { (byte) -> Int8 in
            return Int8(bitPattern: byte)
        }
        let addrPointer = UnsafePointer(addrArray)
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: 55)
        let length = BRBCashAddrEncode(buffer, addrPointer)
        let cashAddrData = Data(buffer: UnsafeMutableBufferPointer<Int8>(start: buffer, count: length))
        buffer.deallocate()
        guard length > 0 else { return nil }
        return String(data: cashAddrData, encoding: .ascii)?.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func cashAddressDecode() -> String? {
        guard let decodedData = CashAddressCoder.decode(self) else { return nil }
        guard let version = decodedData.data.first else { return nil }
        var buffer = decodedData.data
        // Version: P2PKH = 0, P2SH = 8
        if decodedData.prefix == "bitcoincash", version == 0 {
            buffer[0] = 0
        }
        else if decodedData.prefix == "bchtest", version == 0 {
            buffer[0] = 0x6F
        }
        else if decodedData.prefix == "bitcoincash", version == 8 {
            buffer[0] = 0x05
        }
        else if decodedData.prefix == "bchtest", version == 8 {
            buffer[0] = 0xC4
        }
        else {
            return nil
        }
        return buffer.base58Check
    }
    
    func p2pkhAddressToPubKeyHash() -> Data? {
        guard let decodedData = base58CheckDecode(), decodedData.count == 21 else { return nil }
        let pubkeyHash = decodedData.subdata(in: 1..<decodedData.count)
        return pubkeyHash
    }
    
    func p2pkhAddressToCashAddress() -> String? {
        return self.cashAddressEncode()
    }
    
    func p2shAddressToCashAddress() -> String? {
        return self.cashAddressEncode()
    }
    
    func p2shAddressToRedeemScriptHash() -> Data? {
        guard let decodedData = base58CheckDecode(), decodedData.count == 21 else { return nil }
        let redeemScriptHash = decodedData.subdata(in: 1..<decodedData.count)
        return redeemScriptHash
    }
    
    func isP2PKHAddress(_ type: ATCryptocurrencyType) -> Bool {
        guard let decodedData = base58CheckDecode(), decodedData.count == 21 else { return false }
        return decodedData.first == type.p2pkhAddressPrefix
    }
    
    func isP2SHAddress(_ type: ATCryptocurrencyType) -> Bool {
        guard let decodedData = base58CheckDecode(), decodedData.count == 21 else { return false }
        return decodedData.first == type.p2shAddressPrefix
    }
    
    func isCashAddress() -> Bool {
        var cashAddr = self
        if cashAddr.firstIndex(of: ":") == nil {
            cashAddr.insert(contentsOf: "\(ATCryptocurrencyType.bch.scheme):", at: cashAddr.startIndex)
        }
        guard let decodedAddr = cashAddr.cashAddressDecode() else { return false }
        return decodedAddr.isP2PKHAddress(.bch) || decodedAddr.isP2SHAddress(.bch)
    }
    
    func isSegWitAddress() -> Bool {
        var hrp = ""
        if self.hasPrefix("\(ATCryptocurrencyType.btc.bech32HRP)\(ATCryptocurrencyType.btc.bech32Separator)") {
            hrp = ATCryptocurrencyType.btc.bech32HRP
        }
        else if self.hasPrefix("\(ATCryptocurrencyType.ltc.bech32HRP)\(ATCryptocurrencyType.ltc.bech32Separator)") {
            hrp = ATCryptocurrencyType.ltc.bech32HRP
        }
        else {
            return false
        }
        guard let decoded = try? SegwitAddressCoder().decode(hrp: hrp, addr: self) else { return false }
        if decoded.version == 0, decoded.program.count == 20 {
            // P2WPKH
            return true
        }
        else if decoded.version == 0, decoded.program.count == 32 {
            // P2WSH
            return true
        }
        return false
    }
    
    func isP2WPKHAddress() -> Bool {
        var hrp = ""
        if self.hasPrefix("\(ATCryptocurrencyType.btc.bech32HRP)\(ATCryptocurrencyType.btc.bech32Separator)") {
            hrp = ATCryptocurrencyType.btc.bech32HRP
        }
        else if self.hasPrefix("\(ATCryptocurrencyType.ltc.bech32HRP)\(ATCryptocurrencyType.ltc.bech32Separator)") {
            hrp = ATCryptocurrencyType.ltc.bech32HRP
        }
        else {
            return false
        }
        guard let decoded = try? SegwitAddressCoder().decode(hrp: hrp, addr: self) else { return false }
        if decoded.version == 0, decoded.program.count == 20 {
            // P2WPKH
            return true
        }
        return false
    }
    
    func isP2WSHAddress() -> Bool {
        var hrp = ""
        if self.hasPrefix("\(ATCryptocurrencyType.btc.bech32HRP)\(ATCryptocurrencyType.btc.bech32Separator)") {
            hrp = ATCryptocurrencyType.btc.bech32HRP
        }
        else if self.hasPrefix("\(ATCryptocurrencyType.ltc.bech32HRP)\(ATCryptocurrencyType.ltc.bech32Separator)") {
            hrp = ATCryptocurrencyType.ltc.bech32HRP
        }
        else {
            return false
        }
        guard let decoded = try? SegwitAddressCoder().decode(hrp: hrp, addr: self) else { return false }
        if decoded.version == 0, decoded.program.count == 32 {
            // P2WSH
            return true
        }
        return false
    }
    
    func extractScriptPubKeyFromSegWitAddress() -> Data? {
        var hrp = ""
        if self.hasPrefix("\(ATCryptocurrencyType.btc.bech32HRP)\(ATCryptocurrencyType.btc.bech32Separator)") {
            hrp = ATCryptocurrencyType.btc.bech32HRP
        }
        else if self.hasPrefix("\(ATCryptocurrencyType.ltc.bech32HRP)\(ATCryptocurrencyType.ltc.bech32Separator)") {
            hrp = ATCryptocurrencyType.ltc.bech32HRP
        }
        else {
            return nil
        }
        guard let decoded = try? SegwitAddressCoder().decode(hrp: hrp, addr: self) else { return nil }
        guard decoded.version == 0 && (decoded.program.count == 20 || decoded.program.count == 32) else { return nil }
        var scriptPubKey = decoded.program
        scriptPubKey.insert(UInt8(decoded.program.count), at: 0)
        scriptPubKey.insert(UInt8(decoded.version), at: 0)
        return scriptPubKey
    }
            
    func removeCashAddressPrefix() -> String {
        guard let index = self.firstIndex(of: ":") else { return self }
        return String(self.suffix(from: self.index(after: index)))
    }
}
