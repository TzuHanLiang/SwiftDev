//
//  ATError.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/12.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public enum ATError : Int {
    case none
    case unknown
    case ok
    
    // ATSession
    case failToConnect
    case failToEncode
    case failToDecode
    case disconnection
    case failToSetupSession
    
    // ATDevice
    case overlength
    case failToSend
    case failToReceive
    case timeout
    
    // ATCommand
    case incorrectSW
    case commandError
    case incorrectResponse
    case invalidParameter
    
    // ATHDWallet
    case failToUpdateWalletInfo
    case loginRequired
    case failToCreateWallet
    case noWalletExisted
    
    // ATCryptocurrencyWallet
    case failToUpdateWalletKeyInfo
    case failToInitWallet
    case uninitialized
    case inSync
    case failToSync
    case failToPrepareForSign
    case failToSign
    case failToPublish
    
    public var description: String {
        get {
            switch self {
            case .none:
                return ""
            case .unknown:
                return NSLocalizedString("unknown", comment: "")
            case .ok:
                return NSLocalizedString("ok", comment: "")
            case .failToConnect:
                return NSLocalizedString("failed_to_connect_to_atwallet", comment: "")
            case .failToEncode:
                return NSLocalizedString("failed_to_encode_data", comment: "")
            case .failToDecode:
                return NSLocalizedString("failed_to_decode_data", comment: "")
            case .disconnection:
                return NSLocalizedString("disconnected", comment: "")
            case .failToSetupSession:
                return NSLocalizedString("failed_to_setup_session", comment: "")
            case .overlength:
                return NSLocalizedString("overlength", comment: "")
            case .failToSend:
                return NSLocalizedString("failed_to_send_data", comment: "")
            case .failToReceive:
                return NSLocalizedString("failed_to_receive_data", comment: "")
            case .timeout:
                return NSLocalizedString("timeout", comment: "")
            case .incorrectSW:
                return NSLocalizedString("incorrect_sw", comment: "")
            case .commandError:
                return NSLocalizedString("command_error", comment: "")
            case .incorrectResponse:
                return NSLocalizedString("incorrect_response", comment: "")
            case .invalidParameter:
                return NSLocalizedString("invalid_parameter", comment: "")
            case .failToUpdateWalletInfo:
                return NSLocalizedString("failed_to_update_wallet_info", comment: "")
            case .loginRequired:
                return NSLocalizedString("login_required", comment: "")
            case .failToCreateWallet:
                return NSLocalizedString("failed_to_create_wallet", comment: "")
            case .noWalletExisted:
                return NSLocalizedString("no_wallet_existed", comment: "")
            case .failToUpdateWalletKeyInfo:
                return NSLocalizedString("failed_to_update_wallet_key_info", comment: "")
            case .failToInitWallet:
                return NSLocalizedString("failed_to_init_wallet", comment: "")
            case .uninitialized:
                return NSLocalizedString("uninitialized", comment: "")
            case .inSync:
                return NSLocalizedString("in_sync", comment: "")
            case .failToSync:
                return NSLocalizedString("failed_to_sync", comment: "")
            case .failToPrepareForSign:
                return NSLocalizedString("failed_to_prepare_for_signing_transaction", comment: "")
            case .failToSign:
                return NSLocalizedString("failed_to_sign_transaction", comment: "")
            case .failToPublish:
                return NSLocalizedString("failed_to_publish_transaction", comment: "")
            }
        }
    }
    
}

