//
//  Item.swift
//  expense-tracker-v1
//
//  Created by Victor Dovgaliuc on 28/6/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
