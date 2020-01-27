//
//  ATProprietaryProtocol.swift
//  ATWalletKit
//
//  Created by Joshua on 2019/5/31.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import Foundation
import BRCore
import CryptoSwift
import CryptoEthereumSwift
import Ed25519Swift

public class ATProprietaryProtocol : ATSecurityProtocol {
    
    private let type: UInt32 = 0x41540001
    private let psk: [UInt8] = ATConstants.PSK
    
    private var appUUID: [UInt8]
    private var sharedSecret: [UInt8]
    private var hmacKey: [UInt8]
    private var requestCount: UInt32
    private var responseCount: UInt32
    
    required init() {
        self.appUUID = []
        self.sharedSecret = []
        self.hmacKey = []
        self.requestCount = 0
        self.responseCount = 0
    }
    
    override func setupSession(_ device: ATDevice, Callback callback: @escaping (Bool, ATError?) -> ()) {
        // Command: 00 76 01 00 00 ?? ?? (Handshaking Data) 00 00
        // Handshaking Data: | Data ( Type (1 byte) | PSK ID (1 byte) | Sub-PSK ID (4 bytes) | Encrypted UUID (16 bytes) | Ephemeral EC Public Key (32 bytes) ) | Signature ( SHA256 (Sub-PSK | Data) ) |
        // get uuid
        if let uuid = UserDefaults.standard.object(forKey: "AT_SC_UUID") as? [UInt8], uuid.count == 16 {
            self.appUUID = uuid
        }
        else {
            var uuid = [UInt8](repeating: 0, count: 16)
            if SecRandomCopyBytes(kSecRandomDefault, uuid.count * MemoryLayout<UInt8>.size, &uuid) != errSecSuccess {
                for index in 0..<uuid.count where (index % 4) == 0 {
                    let randomValue = arc4random()
                    uuid[index] = UInt8((randomValue >> 24) & 0xFF)
                    uuid[index + 1] = UInt8((randomValue >> 16) & 0xFF)
                    uuid[index + 2] = UInt8((randomValue >> 8) & 0xFF)
                    uuid[index + 3] = UInt8(randomValue & 0xFF)
                }
            }
            self.appUUID = uuid
            UserDefaults.standard.set(uuid, forKey: "AT_SC_UUID")
            UserDefaults.standard.synchronize()
        }
        
        // generate key pair
        guard let keyPair = try? Ed25519Swift.createKeyPair(Ed25519Swift.createSeed()) else {
            ATLog.error("Failed to generate key pair")
            callback(false, .failToSetupSession)
            return
        }
        //ATLog.debug("Public Key: \(Data(keyPair.publicKey) as NSData)")
        
        // generate sub-psk
        let subPSKID = arc4random()
        let subPSK = generateSubPSK(self.psk, subPSKID)
        //ATLog.debug("Sub-PSK ID: \(String(format: "%08X", subPSKID))")
        //ATLog.debug("Sub-PSK: \(Data(subPSK) as NSData)")
        
        // generate uuid encryption key and iv
        var buffer = Data()
        buffer.append(contentsOf: subPSK)
        buffer.append(contentsOf: keyPair.publicKey)
        var sha256Data = buffer.sha256()
        let aesKey = sha256Data.bytes
        let aesIV = Array(aesKey[0..<16])
        //ATLog.debug("UUID Encryption KEY: \(Data(aesKey) as NSData)")
        //ATLog.debug("UUID Encryption IV: \(Data(aesIV) as NSData)")
        
        // encrypt uuid
        guard let aes = try? AES(key: aesKey, blockMode: CBC(iv: aesIV), padding: .noPadding) else {
            ATLog.error("Failed to initialize AES")
            callback(false, .failToSetupSession)
            return
        }
        guard let encryptedUUID = try? aes.encrypt(self.appUUID) else {
            ATLog.error("Failed to encrypt data")
            callback(false, .failToSetupSession)
            return
        }
        
        // fill data
        var data = Data()
        // put type
        var typeBig = self.type.bigEndian
        data.append(Data(bytes: &typeBig, count: MemoryLayout.size(ofValue: typeBig)))
        // put psk id
        data.append(self.psk[0])
        // put sub-psk id
        var subPSKIDBig = subPSKID.bigEndian
        data.append(Data(bytes: &subPSKIDBig, count: MemoryLayout.size(ofValue: subPSKIDBig)))
        // put encrypted uuid
        data.append(contentsOf: encryptedUUID)
        // put public key
        data.append(contentsOf: keyPair.publicKey)
        
        // generate signature
        var signatureMaterial = Data()
        signatureMaterial.append(contentsOf: subPSK)
        signatureMaterial.append(data)
        sha256Data = signatureMaterial.sha256()
        //ATLog.debug("Signature Material: \(sha256Data as NSData)")
        guard let signature = try? Ed25519Swift.sign(sha256Data.bytes, keyPair) else {
            ATLog.error("Failed to generate signature")
            callback(false, .failToSetupSession)
            return
        }
        //ATLog.debug("Signature: \(Data(signature) as NSData)")
        
        // put signature
        data.append(contentsOf: signature)
        
        // handshaking command
        var command = Data()
        command.append(contentsOf: [0x00, 0x76, 0x01, 0x00, 0x00, 0x00])
        command.append(UInt8(data.count & 0xFF))
        command.append(data)
        command.append(contentsOf: [0x00, 0x00])
        
        // send
        device.send(command) { (response, error) in
            // Handshaking response: | Peer Ephemeral EC Public Key | HMAC ( Peer Ephemeral EC Public Key ) | SW
            if let error = error {
                callback(false, error)
                return
            }
            guard let resp = response?.bytes, resp.count == (32 + 32 + 2) else {
                ATLog.error("Incorrect response")
                callback(false, .failToSetupSession)
                return
            }
            guard resp[resp.count - 2] == 0x90, resp.last == 0 else {
                ATLog.error("Incorrect SW")
                callback(false, .failToSetupSession)
                return
            }
            let peerPubKey = Array(resp[0..<32])
            let hmac = Array(resp[32..<64])
            //ATLog.debug("Peer Public Key: \(Data(peerPubKey) as NSData)")
            //ATLog.debug("HMAC: \(Data(hmac) as NSData)")
            
            // calculate shared secret
            guard let sharedSecret = try? Ed25519Swift.keyExchange(peerPubKey, keyPair.privateKey) else {
                ATLog.error("Failed to calculate shared secret")
                callback(false, .failToSetupSession)
                return
            }
            //ATLog.debug("Raw Shared Secret: \(Data(sharedSecret) as NSData)")
            self.sharedSecret = Data(sharedSecret).sha256().bytes
            //ATLog.debug("Shared Secret Hash: \(Data(self.sharedSecret) as NSData)")
            
            // calculate hmac key
            var hmacKeyMatirial = Data()
            hmacKeyMatirial.append(contentsOf: subPSK)
            hmacKeyMatirial.append(contentsOf: self.sharedSecret)
            self.hmacKey = hmacKeyMatirial.sha256().bytes
            //ATLog.debug("HMAC Key: \(Data(self.hmacKey) as NSData)")
            
            // verify hmac
            guard let newHMAC = try? HMAC(key: self.hmacKey, variant: .sha256).authenticate(peerPubKey) else {
                ATLog.error("Failed to calculate HMAC")
                callback(false, .failToSetupSession)
                return
            }
            //ATLog.debug("New HMAC: \(Data(newHMAC) as NSData)")
            guard hmac.elementsEqual(newHMAC) else {
                ATLog.error("Incorrect HMAC")
                callback(false, .failToSetupSession)
                return
            }
            
            self.requestCount = 0
            self.responseCount = 0
            
            callback(true, nil)
        }
    }
    
    override func encode(_ data: Data) -> Data? {
        // Command: 00 76 02 00 00 ?? ?? (Encoded Data) 00 00
        // Encoded Data: | Encrypted Data ( Request Count | Data ) | HMAC ( Encrypted Data) | IV |
        // generate iv
        var iv = [UInt8](repeating: 0, count: 16)
        if SecRandomCopyBytes(kSecRandomDefault, iv.count * MemoryLayout<UInt8>.size, &iv) !=  errSecSuccess {
            for index in 0..<iv.count {
                iv[index] = UInt8(arc4random() % 0x100)
            }
        }
        //ATLog.debug("IV: \(Data(iv) as NSData)")
        
        if self.requestCount == UInt32.max {
            // TODO: re-handshaking
        }
        
        // insert requesrt count
        var requestData = Data()
        var requestCountBig = (self.requestCount + 1).bigEndian
        requestData.append(Data(bytes: &requestCountBig, count: MemoryLayout.size(ofValue: requestCountBig)))
        requestData.append(data)
        ATLog.debug("Plaintext: \(requestData as NSData)")
        
        // encrypt data
        guard let aes = try? AES(key: self.sharedSecret, blockMode: CBC(iv: iv), padding: .pkcs7) else {
            ATLog.error("Failed to initialize AES")
            return nil
        }
        guard let encryptedData = try? aes.encrypt(requestData.bytes) else {
            ATLog.error("Failed to encrypt data")
            return nil
        }
        
        // calculate hmac
        guard let hmac = try? HMAC(key: self.hmacKey, variant: .sha256).authenticate(encryptedData) else {
            ATLog.error("Failed to calculate HMAC")
            return nil
        }
        //ATLog.debug("HMAC: \(Data(hmac) as NSData)")
        
        self.requestCount += 1
        
        let encodedDataLength = encryptedData.count + hmac.count + iv.count
        var command = Data()
        command.append(contentsOf: [0x00, 0x76, 0x02, 0x00, UInt8((encodedDataLength >> 16) & 0xFF), UInt8((encodedDataLength >> 8) & 0xFF), UInt8(encodedDataLength & 0xFF)])
        command.append(contentsOf: encryptedData)
        command.append(contentsOf: hmac)
        command.append(contentsOf: iv)
        command.append(contentsOf: [0x00, 0x00])
        
        return command
    }
    
    override func decode(_ data: Data) -> Data? {
        // | Encrypted Data ( Response Count | Data ) | HMAC ( Encrypted Data ) | IV |
        guard data.count >= 2 else {
            ATLog.error("Incorrect data length")
            return nil
        }
        if data.count == 2 {
            return data
        }
        guard data.count >= (16 + 32 + 16 + 2) else {
            ATLog.error("Incorrect data length")
            return nil
        }
        
        let sw = data.subdata(in: (data.count - 2)..<data.count).bytes
        let iv = data.subdata(in: (data.count - 2 - 16)..<(data.count - 2)).bytes
        let hmac = data.subdata(in: (data.count - 2 - 16 - 32)..<(data.count - 2 - 16)).bytes
        let encryptedData = data.subdata(in: 0..<(data.count - 2 - 16 - 32)).bytes
        //ATLog.debug("IV: \(Data(iv) as NSData)")
        //ATLog.debug("HMAC: \(Data(hmac) as NSData)")
        
        // verify hmac
        guard let newHMAC = try? HMAC(key: self.hmacKey, variant: .sha256).authenticate(encryptedData) else {
            ATLog.error("Failed to calculate HMAC")
            return nil
        }
        //ATLog.debug("New HMAC: \(Data(newHMAC) as NSData)")
        guard hmac.elementsEqual(newHMAC) else {
            ATLog.error("Incorrect HMAC")
            return nil
        }
        
        // decrypt data
        guard let aes = try? AES(key: self.sharedSecret, blockMode: CBC(iv: iv), padding: .pkcs7) else {
            ATLog.error("Failed to initialize AES")
            return nil
        }
        guard let decryptedData = try? aes.decrypt(encryptedData) else {
            ATLog.error("Failed to decrypt data")
            return nil
        }
        ATLog.debug("Plaintext: \(Data(decryptedData) as NSData)")
        
        // verify response count
        guard decryptedData.count > 4 else {
            ATLog.error("Incorrect response data")
            return nil
        }
        var count: UInt32 = 0
        count |= ((UInt32(decryptedData[0]) << 24) & 0xFF000000)
        count |= ((UInt32(decryptedData[1]) << 16) & 0x00FF0000)
        count |= ((UInt32(decryptedData[2]) << 8) & 0x0000FF00)
        count |= (UInt32(decryptedData[3]) & 0x000000FF)
        guard count > self.responseCount else {
            ATLog.error("Incorrect response count: \(count), Last response count: \(self.responseCount)")
            return nil
        }
        
        self.responseCount = count
        
        var decodedData = Data()
        decodedData.append(contentsOf: decryptedData[4...])
        decodedData.append(contentsOf: sw)
        
        return decodedData
    }
    
    private func generateSubPSK(_ psk: [UInt8], _ parameter: UInt32) -> [UInt8] {
        var seed: [UInt8] = psk
        for round in 0..<4 {
            let param = UInt8((parameter >> (round * 8)) & UInt32(0xFF))
            let p1 = param & 0x0F
            let p2 = param & 0xF0
            
            var data = Data()
            data.append(p1)
            data.append(contentsOf: seed[0..<(seed.count/2)])
            let hash160Data1 = CryptoHash.ripemd160(data)
            
            data = Data()
            data.append(p2)
            data.append(contentsOf: seed[(seed.count/2)..<seed.count])
            let hash160Data2 = CryptoHash.ripemd160(data)
            
            data = Data()
            data.append(hash160Data1)
            data.append(hash160Data2)
            let hash256Data = Crypto.hashSHA3_256(data)
            
            seed = hash256Data.bytes
        }
        return seed
    }
}

