//
//  Candle.swift
//  CandlePower
//
//  Created by Essen Davis on 12/31/25.
//

import Foundation

struct Candle: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    
    init(id: UUID = UUID(), timestamp: Date, open: Double, high: Double, low: Double, close: Double, volume: Double = 0) {
        self.id = id
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
    
    // Helper to create a candle from a single price point
    static func fromPrice(_ price: Double, at timestamp: Date) -> Candle {
        return Candle(timestamp: timestamp, open: price, high: price, low: price, close: price)
    }
}

// Aggregated candle bucket for building higher timeframes
class CandleBucket {
    var candles: [Candle] = []
    let timeframe: Int // minutes
    
    init(timeframe: Int) {
        self.timeframe = timeframe
    }
    
    func addCandle(_ candle: Candle) {
        candles.append(candle)
    }
    
    func aggregate() -> Candle? {
        guard !candles.isEmpty else { return nil }
        
        let sorted = candles.sorted { $0.timestamp < $1.timestamp }
        let open = sorted.first!.open
        let close = sorted.last!.close
        let high = sorted.map { $0.high }.max()!
        let low = sorted.map { $0.low }.min()!
        let volume = sorted.reduce(0) { $0 + $1.volume }
        let timestamp = sorted.first!.timestamp
        
        return Candle(timestamp: timestamp, open: open, high: high, low: low, close: close, volume: volume)
    }
    
    func shouldClose(at timestamp: Date) -> Bool {
        guard let firstCandle = candles.first else { return false }
        // For 1-minute candles aggregated into higher timeframes,
        // we need exactly 'timeframe' candles (e.g., 5 candles for 5-minute)
        // The time difference will be (timeframe - 1) minutes
        // So check if we have >= timeframe candles OR time span >= timeframe minutes
        if candles.count >= timeframe {
            return true
        }
        let timeDiff = timestamp.timeIntervalSince(firstCandle.timestamp)
        return timeDiff >= Double(timeframe * 60)
    }
}

