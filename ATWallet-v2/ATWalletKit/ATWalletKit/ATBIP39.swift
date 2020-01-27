//
//  ATBIP39.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/12/4.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation


class ATBIP39Abstraction : NSObject {
    
    required override init() {}
    
    func encodeEntropy(Entropy entropy: [UInt8], WordList wordList: [String]) -> String? { return nil }
    
    func deriveSeed(Mnemonic mnemonic: String, Passphrase passphrase: String?) -> Data? { return nil }
    
    func verifyMnemonic(Mnemonic mnemonic: String, WordList wordList: [String]) -> Bool { return false }
}

public class ATBIP39 : NSObject {
    
    let impl: ATBIP39Abstraction
    
    public enum MnemonicLength : Int, CaseIterable {
        case w12 = 12
        case w15 = 15
        case w18 = 18
        case w21 = 21
        case w24 = 24
        
        var entropyBytes: Int {
            get {
                switch self {
                case .w12:
                    return 128 / 8
                case .w15:
                    return 160 / 8
                case .w18:
                    return 192 / 8
                case .w21:
                    return 224 / 8
                case .w24:
                    return 256 / 8
                }
            }
        }
    }
    
    public enum Language : String, CaseIterable {
        case english = "en"
        case fransh = "fr"
        case italian = "it"
        case japanese = "ja"
        case korean = "ko"
        case spanish = "es"
        case simplifiedChinese = "zh-Hans"
        case traditionalChinese = "zh-Hant"
        
        public var description: String {
            get {
                switch self {
                case .english:
                    return "English"
                case .fransh:
                    return "Français"
                case .italian:
                    return "Italiano"
                case .japanese:
                    return "日本語"
                case .korean:
                    return "한국어"
                case .spanish:
                    return "Español"
                case .simplifiedChinese:
                    return "简体中文"
                case .traditionalChinese:
                    return "繁體中文"
                }
            }
        }
    }
    
    public override init() {
        self.impl = BRBIP39()
    }
    
    public func generateMnemonic(Length length: MnemonicLength, Language language: Language) -> [String]? {
        guard let bundle = Bundle(identifier: "com.authentrend.atwalletkit") else { return nil }
        guard let path = bundle.path(forResource: "BIP39Words", ofType: "plist", inDirectory: nil, forLocalization: language.rawValue) else { return nil }
        guard let wordList = NSArray(contentsOfFile: path) as? [String] else { return nil }
        var entropy = [UInt8](repeating: 0, count: length.entropyBytes)
        guard SecRandomCopyBytes(kSecRandomDefault, entropy.count, &entropy) == 0 else { return nil }
        guard let mnemonic = self.impl.encodeEntropy(Entropy: entropy, WordList: wordList) else { return nil }
        return mnemonic.trimmingCharacters(in: .illegalCharacters).trimmingCharacters(in: .newlines).trimmingCharacters(in: .controlCharacters).components(separatedBy: " ")
    }
    
    public func mnemonicIsValid(Mnemonic mnemonic: [String], Language language: Language?) -> Bool {
        if MnemonicLength.init(rawValue: mnemonic.count) == nil { return false }
        
        var mnemonicString: String = ""
        mnemonic.forEach { (str) in
            if mnemonicString.count > 0 {
                mnemonicString.append(" ")
            }
            mnemonicString.append(str)
        }
        
        guard let bundle = Bundle(identifier: "com.authentrend.atwalletkit") else { return false }
        
        var valid: Bool? = false
        if language != nil {
            guard let path = bundle.path(forResource: "BIP39Words", ofType: "plist", inDirectory: nil, forLocalization: language!.rawValue) else { return false }
            guard let wordList = NSArray(contentsOfFile: path) as? [String] else { return false }
            valid = self.impl.verifyMnemonic(Mnemonic: mnemonicString, WordList: wordList)
        }
        else {
            Language.allCases.forEach { (language: ATBIP39.Language) in
                guard let path = bundle.path(forResource: "BIP39Words", ofType: "plist", inDirectory: nil, forLocalization: language.rawValue) else { return }
                guard let wordList = NSArray(contentsOfFile: path) as? [String] else { return }
                if self.impl.verifyMnemonic(Mnemonic: mnemonicString, WordList: wordList) {
                    valid = true
                    return
                }
            }
        }
        
        return valid!
    }
    
    func deriveSeedFromMnemonic(Mnemonic mnemonic: [String], Passphrase passphrase: String?) -> Data? {
        var mnemonicString: String = ""
        mnemonic.forEach { (str) in
            if mnemonicString.count > 0 {
                mnemonicString.append(" ")
            }
            mnemonicString.append(str)
        }
        
        return self.impl.deriveSeed(Mnemonic: mnemonicString, Passphrase: passphrase)
    }
    
}
