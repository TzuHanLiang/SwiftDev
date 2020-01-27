//
//  TransactionTableViewCell.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/9.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit

class TransactionTableViewCell: UITableViewCell {
    
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var addressLabel: UILabel!
    @IBOutlet var amountLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
