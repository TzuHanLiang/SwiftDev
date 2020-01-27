//
//  CryptocurrencyTableViewCell.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/4.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit

class CryptocurrencyTableViewCell: UITableViewCell {
    
    @IBOutlet var iconImageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var exchangeRateLabel: UILabel!
    @IBOutlet var currencyAmountLabel: UILabel!
    @IBOutlet var cryptocurrencyAmountLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
