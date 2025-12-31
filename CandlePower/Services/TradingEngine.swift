//
//  TradingEngine.swift
//  CandlePower
//
//  Created by Essen Davis on 12/31/25.
//

import Foundation
import Combine

class TradingEngine: ObservableObject {
    @Published var account = TradingAccount()
    @Published var currentPrice: Double = 0
    @Published var marginCalled: Bool = false
    @Published var marginWarningShown: Bool = false
    @Published var gameOver: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let marginWarningThreshold: Double = 1000.0
    
    var totalRealizedPnL: Double {
        account.tradeHistory.reduce(0.0) { $0 + $1.realizedPnL }
    }
    
    // Round price to nearest 0.25 increment
    private func roundToQuarter(_ price: Double) -> Double {
        return round(price * 4.0) / 4.0
    }
    
    // Apply slippage (0.25 or 0.5 unfavorable)
    private func applySlippage(to price: Double, forBuy: Bool) -> Double {
        let slippage = Double.random(in: 0...1) < 0.5 ? 0.25 : 0.5
        // For buy: unfavorable = higher price, for sell: unfavorable = lower price
        let slippagePrice = forBuy ? price + slippage : price - slippage
        return roundToQuarter(slippagePrice)
    }
    
    // Apply commission ($2.50 per contract)
    private func applyCommission(contracts: Int) {
        let commission = Double(contracts) * 2.50
        account.realizedBalance -= commission
    }
    
    func reset() {
        // Reset account (closes positions, resets balance, clears history)
        account.reset()
        // Reset game state
        currentPrice = 0
        marginCalled = false
        marginWarningShown = false
        gameOver = false
    }
    
    func buy(contracts: Int, price: Double, timestamp: Date, contractType: ContractType = .MNQ) {
        // Check margin requirements
        if !account.canOpenPosition(contracts: contracts, contractType: contractType) {
            print("⚠️ Insufficient margin to open \(contracts) \(contractType.rawValue) contracts")
            return
        }
        
        // Check if margin is exceeded and flatten if needed
        if account.isMarginExceeded {
            print("⚠️ Margin exceeded, flattening positions")
            marginCalled = true
            flatten(at: price, timestamp: timestamp)
            return
        }
        
        // First, try to close existing short positions
        var remainingContracts = contracts
        var positionsToRemove: [UUID] = []
        
        for position in account.positions where position.side == .short && remainingContracts > 0 {
            // Apply slippage for closing short (buy to close = higher price = unfavorable)
            let closePrice = applySlippage(to: price, forBuy: true)
            // Apply commission
            let contractsToClose = min(position.contracts, remainingContracts)
            applyCommission(contracts: contractsToClose)
            
            if position.contracts <= remainingContracts {
                // Close entire position
                _ = account.closePosition(position, at: closePrice, timestamp: timestamp)
                remainingContracts -= position.contracts
                positionsToRemove.append(position.id)
            } else {
                // Partial close - we need to split the position
                let closeContracts = remainingContracts
                let keepContracts = position.contracts - closeContracts
                
                // Calculate P&L for the closed portion
                let priceDiff = position.entryPrice - closePrice // For short, profit when price goes down
                let pnl = priceDiff * Double(closeContracts) * position.contractType.pointValue
                account.realizedBalance += pnl
                
                // Record the trade
                let trade = Trade(timestamp: timestamp, side: .short, contracts: -closeContracts, price: closePrice, realizedPnL: pnl)
                account.tradeHistory.append(trade)
                
                // Update the position to keep the remaining contracts
                if let index = account.positions.firstIndex(where: { $0.id == position.id }) {
                    var updatedPositions = account.positions
                    updatedPositions[index].contracts = keepContracts
                    account.positions = updatedPositions
                }
                
                remainingContracts = 0
            }
        }
        
        // Remove fully closed positions
        account.positions.removeAll { positionsToRemove.contains($0.id) }
        
        // If we still have contracts to buy, check margin again and open a long position
        if remainingContracts > 0 {
            if account.canOpenPosition(contracts: remainingContracts, contractType: contractType) {
                // Apply slippage for opening long (buy = higher price = unfavorable)
                let fillPrice = applySlippage(to: price, forBuy: true)
                // Apply commission
                applyCommission(contracts: remainingContracts)
                account.openPosition(side: .long, contracts: remainingContracts, price: fillPrice, timestamp: timestamp, contractType: contractType)
                // Check for margin warning after opening position
                checkMarginWarning()
            } else {
                print("⚠️ Insufficient margin to open remaining \(remainingContracts) \(contractType.rawValue) contracts")
            }
        } else {
            // Check for margin warning even if we just closed positions
            checkMarginWarning()
        }
    }
    
    func sell(contracts: Int, price: Double, timestamp: Date, contractType: ContractType = .MNQ) {
        // Check margin requirements
        if !account.canOpenPosition(contracts: contracts, contractType: contractType) {
            print("⚠️ Insufficient margin to open \(contracts) \(contractType.rawValue) contracts")
            return
        }
        
        // Check if margin is exceeded and flatten if needed
        if account.isMarginExceeded {
            print("⚠️ Margin exceeded, flattening positions")
            marginCalled = true
            flatten(at: price, timestamp: timestamp)
            return
        }
        
        // First, try to close existing long positions
        var remainingContracts = contracts
        var positionsToRemove: [UUID] = []
        
        for position in account.positions where position.side == .long && remainingContracts > 0 {
            // Apply slippage for closing long (sell to close = lower price = unfavorable)
            let closePrice = applySlippage(to: price, forBuy: false)
            // Apply commission
            let contractsToClose = min(position.contracts, remainingContracts)
            applyCommission(contracts: contractsToClose)
            
            if position.contracts <= remainingContracts {
                // Close entire position
                _ = account.closePosition(position, at: closePrice, timestamp: timestamp)
                remainingContracts -= position.contracts
                positionsToRemove.append(position.id)
            } else {
                // Partial close - we need to split the position
                let closeContracts = remainingContracts
                let keepContracts = position.contracts - closeContracts
                
                // Calculate P&L for the closed portion
                let priceDiff = closePrice - position.entryPrice
                let pnl = priceDiff * Double(closeContracts) * position.contractType.pointValue
                account.realizedBalance += pnl
                
                // Record the trade
                let trade = Trade(timestamp: timestamp, side: .long, contracts: -closeContracts, price: closePrice, realizedPnL: pnl)
                account.tradeHistory.append(trade)
                
                // Update the position to keep the remaining contracts
                if let index = account.positions.firstIndex(where: { $0.id == position.id }) {
                    var updatedPositions = account.positions
                    updatedPositions[index].contracts = keepContracts
                    account.positions = updatedPositions
                }
                
                remainingContracts = 0
            }
        }
        
        // Remove fully closed positions
        account.positions.removeAll { positionsToRemove.contains($0.id) }
        
        // If we still have contracts to sell, check margin again and open a short position
        if remainingContracts > 0 {
            if account.canOpenPosition(contracts: remainingContracts, contractType: contractType) {
                // Apply slippage for opening short (sell = lower price = unfavorable)
                let fillPrice = applySlippage(to: price, forBuy: false)
                // Apply commission
                applyCommission(contracts: remainingContracts)
                account.openPosition(side: .short, contracts: remainingContracts, price: fillPrice, timestamp: timestamp, contractType: contractType)
                // Check for margin warning after opening position
                checkMarginWarning()
            } else {
                print("⚠️ Insufficient margin to open remaining \(remainingContracts) \(contractType.rawValue) contracts")
            }
        } else {
            // Check for margin warning even if we just closed positions
            checkMarginWarning()
        }
    }
    
    func flatten(at price: Double, timestamp: Date) {
        // Close all open positions
        let positionsToClose = account.positions
        for position in positionsToClose {
            _ = account.closePosition(position, at: price, timestamp: timestamp)
        }
        // Reset margin warning flag after flattening
        marginWarningShown = false
    }
    
    func updatePrice(_ price: Double) {
        currentPrice = price
        account.updatePositionPrices(currentPrice: price)
        
        // Check for margin warning ($1000 away from margin call)
        checkMarginWarning()
        
        // Check if margin is exceeded after price update and flatten if needed
        if account.isMarginExceeded {
            print("⚠️ Margin exceeded after price update, flattening positions")
            marginCalled = true
            flatten(at: price, timestamp: Date())
        }
    }
    
    private func checkMarginWarning() {
        // Show warning if margin available is <= $1000 and we haven't shown it yet
        // Reset the flag if margin goes back above threshold
        if account.marginAvailable <= marginWarningThreshold {
            if !marginWarningShown {
                marginWarningShown = true
            }
        } else {
            // Reset warning flag when margin is back above threshold
            marginWarningShown = false
        }
    }
}

