//
//  Item.swift
//  snap-battle
//
//  Created by Pedro Kosciuk Lima on 14/07/26.
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
