//
//  ATTLSProtocol.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/5.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public class ATTLSProtocol : ATSecurityProtocol {

    required init() {
        // TODO
    }
    
    override func setupSession(_ device: ATDevice, Callback callback: @escaping (Bool, ATError?) -> ()) {
        // TODO
        /*
        device.send(request) { (response, error) in
            // do something
            callback()
        }
        */
    }
    
    override func encode(_ data: Data) -> Data? {
        // TODO
        return nil
    }
    
    override func decode(_ data: Data) -> Data? {
        // TODO
        return nil
    }
}
