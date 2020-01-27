//
//  Ed25519Swift.swift
//  Ed25519Swift
//
//  Created by Joshua on 2019/6/18.
//  Copyright © 2019 Joshua Lin. All rights reserved.
//

import Foundation
import ed25519

public class Ed25519Swift {
    
    public struct KeyPair {
        public let publicKey: [UInt8]
        public let privateKey: [UInt8]
    }
    
    public enum Ed25519Error: Error {
        case invalidSeedLength
        case invalidKeyLength
        case invalidMessageLength
        case invalidSignatureLength
        case invalidKey
        case invalidScalarLength
        
    }
    
    private static let SeedLength = 32
    
    
    
    public static func createSeed() -> [UInt8] {
        var seed = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, seed.count * MemoryLayout<UInt8>.size, &seed) !=  errSecSuccess {
            for index in 0..<seed.count {
                seed[index] = UInt8(arc4random() % 0x100)
            }
        }
        return seed
    }
    
    public static func createKeyPair(_ seed: [UInt8]) throws -> KeyPair {
        guard seed.count == 32 else {
            throw Ed25519Error.invalidSeedLength
        }
        
        var pubkey = [UInt8](repeating: 0, count: 32)
        var privkey = [UInt8](repeating: 0, count: 64)
        pubkey.withUnsafeMutableBufferPointer { (pubkeyPointer) -> Void in
            privkey.withUnsafeMutableBufferPointer({ (privkeyPointer) -> Void in
                seed.withUnsafeBufferPointer({ (seedPointer) -> Void in
                    ed25519_create_keypair(pubkeyPointer.baseAddress, privkeyPointer.baseAddress, seedPointer.baseAddress)
                })
            })
        }
        
        return KeyPair(publicKey: pubkey, privateKey: privkey)
    }
    
    public static func sign(_ message: [UInt8], _ keyPair: KeyPair) throws -> [UInt8] {
        guard message.count > 0 else {
            throw Ed25519Error.invalidMessageLength
        }
        guard keyPair.publicKey.count == 32, keyPair.privateKey.count == 64 else {
            throw Ed25519Error.invalidKeyLength
        }
        
        var signature = [UInt8](repeating: 0, count: 64)
        signature.withUnsafeMutableBufferPointer { (signaturePointer) -> Void in
            keyPair.publicKey.withUnsafeBufferPointer({ (pubkeyPointer) -> Void in
                keyPair.privateKey.withUnsafeBufferPointer({ (privkeyPointer) -> Void in
                    message.withUnsafeBufferPointer({ (messagePointer) -> Void in
                        ed25519_sign(signaturePointer.baseAddress, messagePointer.baseAddress, message.count, pubkeyPointer.baseAddress, privkeyPointer.baseAddress)
                    })
                })
            })
        }
        
        return signature
    }
    
    public static func verify(_ signature: [UInt8], _ message: [UInt8], _ pubkey: [UInt8]) throws -> Bool {
        guard signature.count == 64 else {
            throw Ed25519Error.invalidSignatureLength
        }
        guard message.count > 0 else {
            throw Ed25519Error.invalidMessageLength
        }
        guard pubkey.count == 32 else {
            throw Ed25519Error.invalidKeyLength
        }
        
        var result: Int32 = 0
        signature.withUnsafeBufferPointer { (signaturePointer) -> Void in
            pubkey.withUnsafeBufferPointer({ (pubkeyPointer) -> Void in
                message.withUnsafeBufferPointer({ (messagePointer) -> Void in
                    result = ed25519_verify(signaturePointer.baseAddress, messagePointer.baseAddress, message.count, pubkeyPointer.baseAddress)
                })
            })
        }
        
        return result != 0
    }
    
    public static func addScalar(_ pubkey: [UInt8]?, _ privkey: [UInt8]?, _ scalar: [UInt8]) throws -> KeyPair {
        if pubkey == nil && privkey == nil {
            throw Ed25519Error.invalidKey
        }
        if pubkey != nil && pubkey?.count != 32 {
            throw Ed25519Error.invalidKeyLength
        }
        if privkey != nil && privkey?.count != 64 {
            throw Ed25519Error.invalidKeyLength
        }
        guard scalar.count == 32 else {
            throw Ed25519Error.invalidScalarLength
        }
        
        var publicKey = pubkey ?? [UInt8](repeating: 0, count: 32)
        var privateKey = privkey ?? [UInt8](repeating: 0, count: 64)
        publicKey.withUnsafeMutableBufferPointer { (pubkeyPointer) -> Void in
            privateKey.withUnsafeMutableBufferPointer({ (privkeyPointer) -> Void in
                scalar.withUnsafeBufferPointer { (scalarPointer) -> Void in
                    ed25519_add_scalar(pubkey == nil ? nil : pubkeyPointer.baseAddress, privkey == nil ? nil : privkeyPointer.baseAddress, scalarPointer.baseAddress)
                }
            })
        }
        
        return KeyPair(publicKey: pubkey == nil ? [] : publicKey, privateKey: privkey == nil ? [] : privateKey)
    }
    
    public static func keyExchange(_ pubkey: [UInt8], _ privkey: [UInt8]) throws -> [UInt8] {
        guard pubkey.count == 32, privkey.count == 64 else {
            throw Ed25519Error.invalidKeyLength
        }
        
        var secret = [UInt8](repeating: 0, count: 32)
        pubkey.withUnsafeBufferPointer { (pubkeyPointer) -> Void in
            privkey.withUnsafeBufferPointer({ (privkeyPointer) -> Void in
                secret.withUnsafeMutableBufferPointer({ (secretPointer) -> Void in
                    ed25519_key_exchange(secretPointer.baseAddress, pubkeyPointer.baseAddress, privkeyPointer.baseAddress)
                })
            })
        }
        
        return secret
    }
}
