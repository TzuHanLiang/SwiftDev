//
//  ATSecurityProtocol.swift
//  ATWalletKit
//
//  Created by Joshua on 2018/11/5.
//  Copyright © 2018 AuthenTrend. All rights reserved.
//

import Foundation

public class ATSecurityProtocol : NSObject {
    
    required override init() {}
    func setupSession(_ device: ATDevice, Callback callback: @escaping (_ complete: Bool, _ error: ATError?) -> ()) {}
    func encode(_ data: Data) -> Data? { return nil }
    func decode(_ data: Data) -> Data? { return nil }
}

