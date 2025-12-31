//
//  Position.swift
//  CandlePower
//
//  Created by Essen Davis on 12/31/25.
//

import Foundation

enum PositionSide {
    case long
    case short
}

enum ContractType: String, CaseIterable {
    case NQ = "NQ"
    case MNQ = "MNQ"
    
    var pointValue: Double {
        switch self {
        case .NQ:
            return 20.0  // $20 per point
        case .MNQ:
            return 2.0   // $2 per point
        }
    }
    
    var marginRequirement: Double {
        switch self {
        case .NQ:
            return 500.0  // $500 per contract
        case .MNQ:
            return 50.0   // $50 per contract
        }
    }
}

struct Position: Identifiable {
    let id: UUID
    var side: PositionSide
    var contracts: Int
    var entryPrice: Double
    var currentPrice: Double
    var entryTime: Date
    var contractType: ContractType
    
    var unrealizedPnL: Double {
        let priceDiff = currentPrice - entryPrice
        let multiplier = side == .long ? 1.0 : -1.0
        return priceDiff * Double(contracts) * multiplier * contractType.pointValue
    }
    
    init(id: UUID = UUID(), side: PositionSide, contracts: Int, entryPrice: Double, entryTime: Date, contractType: ContractType = .MNQ) {
        self.id = id
        self.side = side
        self.contracts = contracts
        self.entryPrice = entryPrice
        self.currentPrice = entryPrice
        self.entryTime = entryTime
        self.contractType = contractType
    }
}

struct Trade: Identifiable {
    let id: UUID
    let timestamp: Date
    let side: PositionSide
    let contracts: Int
    let price: Double
    let realizedPnL: Double
    
    init(id: UUID = UUID(), timestamp: Date, side: PositionSide, contracts: Int, price: Double, realizedPnL: Double = 0) {
        self.id = id
        self.timestamp = timestamp
        self.side = side
        self.contracts = contracts
        self.price = price
        self.realizedPnL = realizedPnL
    }
}

