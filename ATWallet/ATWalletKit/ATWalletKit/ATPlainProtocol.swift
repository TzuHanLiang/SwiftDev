//
//  ATPlainProtocol.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/5.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public class ATPlainProtocol : ATSecurityProtocol {
        
    required init() {
        
    }
    
    override func setupSession(_ device: ATDevice, Callback callback: @escaping (Bool, ATError?) -> ()) {
        callback(true, nil)
    }
    
    override func encode(_ data: Data) -> Data? {
        return data
    }
    
    override func decode(_ data: Data) -> Data? {
        return data
    }
}
