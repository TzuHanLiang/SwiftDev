//
//  Ed25519SwiftTests.swift
//  Ed25519SwiftTests
//
//  Created by Joshua on 2019/6/18.
//  Copyright © 2019 Joshua Lin. All rights reserved.
//

import XCTest
@testable import Ed25519Swift

class Ed25519SwiftTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testAll() {
        let seed = Ed25519Swift.createSeed()
        guard let keyPair1 = try? Ed25519Swift.createKeyPair(seed) else {
            XCTAssert(false, "Ed25519Swift.createKeyPair failed")
            return
        }
        
        let scalar = Ed25519Swift.createSeed()
        guard let keyPair2 = try? Ed25519Swift.createKeyPair(scalar) else {
            XCTAssert(false, "Ed25519Swift.createKeyPair failed")
            return
        }
        
        let message = Ed25519Swift.createSeed()
        guard let signature = try? Ed25519Swift.sign(message, keyPair1) else {
            XCTAssert(false, "Ed25519Swift.sign failed")
            return
        }
        
        guard (try? Ed25519Swift.verify(signature, message, keyPair1.publicKey)) == true else {
            XCTAssert(false, "Ed25519Swift.verify failed")
            return
        }
        
        guard (try? Ed25519Swift.verify(signature, message, keyPair2.publicKey)) == false else {
            XCTAssert(false, "Ed25519Swift.verify failed")
            return
        }
        
        guard let secret1 = try? Ed25519Swift.keyExchange(keyPair2.publicKey, keyPair1.privateKey) else {
            XCTAssert(false, "Ed25519Swift.keyExchange failed")
            return
        }
        
        guard let secret2 = try? Ed25519Swift.keyExchange(keyPair1.publicKey, keyPair2.privateKey) else {
            XCTAssert(false, "Ed25519Swift.keyExchange failed")
            return
        }
        
        guard secret1.elementsEqual(secret2) else {
            XCTAssert(false, "Shared secrets are different")
            return
        }
    }

}
