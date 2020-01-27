//
//  DeviceTableViewCell.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/8/21.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit

class DeviceTableViewCell: UITableViewCell {
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var signalLabel: UILabel!
    @IBOutlet var typeImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
