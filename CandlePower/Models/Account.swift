//
//  Account.swift
//  CandlePower
//
//  Created by Essen Davis on 12/31/25.
//

import Foundation
import Combine

class TradingAccount: ObservableObject {
    @Published var realizedBalance: Double = 5000.0
    @Published var positions: [Position] = []
    @Published var tradeHistory: [Trade] = []
    
    private let startingBalance: Double = 5000.0
    
    var realizedGain: Double {
        realizedBalance - startingBalance
    }
    
    var unrealizedPnL: Double {
        positions.reduce(0) { $0 + $1.unrealizedPnL }
    }
    
    var totalBalance: Double {
        realizedBalance + unrealizedPnL
    }
    
    // Calculate weighted average entry price for long positions
    var averageLongEntryPrice: Double? {
        let longPositions = positions.filter { $0.side == .long }
        guard !longPositions.isEmpty else { return nil }
        
        let totalContracts = longPositions.reduce(0) { $0 + $1.contracts }
        guard totalContracts > 0 else { return nil }
        
        let weightedSum = longPositions.reduce(0.0) { $0 + (Double($1.contracts) * $1.entryPrice) }
        return weightedSum / Double(totalContracts)
    }
    
    // Calculate weighted average entry price for short positions
    var averageShortEntryPrice: Double? {
        let shortPositions = positions.filter { $0.side == .short }
        guard !shortPositions.isEmpty else { return nil }
        
        let totalContracts = shortPositions.reduce(0) { $0 + $1.contracts }
        guard totalContracts > 0 else { return nil }
        
        let weightedSum = shortPositions.reduce(0.0) { $0 + (Double($1.contracts) * $1.entryPrice) }
        return weightedSum / Double(totalContracts)
    }
    
    // Total contracts for long positions
    var totalLongContracts: Int {
        positions.filter { $0.side == .long }.reduce(0) { $0 + $1.contracts }
    }
    
    // Total contracts for short positions
    var totalShortContracts: Int {
        positions.filter { $0.side == .short }.reduce(0) { $0 + $1.contracts }
    }
    
    // Unrealized P&L for long positions
    var unrealizedLongPnL: Double {
        positions.filter { $0.side == .long }.reduce(0.0) { $0 + $1.unrealizedPnL }
    }
    
    // Unrealized P&L for short positions
    var unrealizedShortPnL: Double {
        positions.filter { $0.side == .short }.reduce(0.0) { $0 + $1.unrealizedPnL }
    }
    
    // Calculate total margin requirement for all open positions
    var totalMarginRequired: Double {
        positions.reduce(0.0) { $0 + (Double($1.contracts) * $1.contractType.marginRequirement) }
    }
    
    // Calculate available margin (total balance - margin required)
    var marginAvailable: Double {
        totalBalance - totalMarginRequired
    }
    
    // Check if account has sufficient margin for additional contracts
    func canOpenPosition(contracts: Int, contractType: ContractType) -> Bool {
        let additionalMargin = Double(contracts) * contractType.marginRequirement
        return marginAvailable >= additionalMargin
    }
    
    // Check if margin is exceeded and needs flattening
    var isMarginExceeded: Bool {
        totalMarginRequired > totalBalance
    }
    
    func openPosition(side: PositionSide, contracts: Int, price: Double, timestamp: Date, contractType: ContractType = .MNQ) {
        let position = Position(side: side, contracts: contracts, entryPrice: price, entryTime: timestamp, contractType: contractType)
        positions.append(position)
        
        let trade = Trade(timestamp: timestamp, side: side, contracts: contracts, price: price)
        tradeHistory.append(trade)
    }
    
    func closePosition(_ position: Position, at price: Double, timestamp: Date) -> Double {
        guard let index = positions.firstIndex(where: { $0.id == position.id }) else {
            return 0
        }
        
        let pnl = position.unrealizedPnL
        realizedBalance += pnl
        
        let trade = Trade(timestamp: timestamp, side: position.side, contracts: -position.contracts, price: price, realizedPnL: pnl)
        tradeHistory.append(trade)
        
        positions.remove(at: index)
        return pnl
    }
    
    func updatePositionPrices(currentPrice: Double) {
        var updatedPositions = positions
        for index in updatedPositions.indices {
            updatedPositions[index].currentPrice = currentPrice
        }
        positions = updatedPositions
    }
    
    func reset() {
        // Close all positions
        positions.removeAll()
        // Reset balance to $5000
        realizedBalance = 5000.0
        // Clear trade history
        tradeHistory.removeAll()
    }
}

