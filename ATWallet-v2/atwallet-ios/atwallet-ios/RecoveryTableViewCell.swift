//
//  RecoveryTableViewCell.swift
//  atwallet-ios
//
//  Created by Joshua on 2019/9/3.
//  Copyright © 2019 AuthenTrend. All rights reserved.
//

import UIKit

class RecoveryMainTableViewCell: UITableViewCell {
    
    @IBOutlet var coinTypeTextField: UITextField!
    @IBOutlet var expansionButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

class RecoveryMinorTableViewCell: UITableViewCell {
    
    @IBOutlet var nicknameTextField: UITextField!
    @IBOutlet var yearTextField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

class RecoveryFullTableViewCell: UITableViewCell {
    
    @IBOutlet var coinTypeTextField: UITextField!
    @IBOutlet var nicknameTextField: UITextField!
    @IBOutlet var yearTextField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

class RecoveryPathTableViewCell: UITableViewCell {
    @IBOutlet var purposeTextField: UITextField!
    @IBOutlet var coinTypeTextField: UITextField!
    @IBOutlet var accountTextField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
