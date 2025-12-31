//
//  CandleAggregator.swift
//  CandlePower
//
//  Created by Essen Davis on 12/31/25.
//

import Foundation
import Combine

class CandleAggregator: ObservableObject {
    @Published var oneMinuteCandles: [Candle] = []
    @Published var fiveMinuteCandles: [Candle] = []
    @Published var fifteenMinuteCandles: [Candle] = []
    
    private var fiveMinBucket: CandleBucket?
    private var fifteenMinBucket: CandleBucket?
    
    // Get current partial 5-minute candle (if bucket is filling)
    var currentFiveMinuteCandle: Candle? {
        guard let bucket = fiveMinBucket, !bucket.candles.isEmpty, bucket.candles.count < 5 else {
            return nil
        }
        return bucket.aggregate()
    }
    
    // Get current partial 15-minute candle (if bucket is filling)
    var currentFifteenMinuteCandle: Candle? {
        guard let bucket = fifteenMinBucket, !bucket.candles.isEmpty, bucket.candles.count < 15 else {
            return nil
        }
        return bucket.aggregate()
    }
    
    func addCandle(_ candle: Candle) {
        print("➕ addCandle called: timestamp = \(candle.timestamp), price = \(candle.close)")
        // Add to 1-minute candles
        var updatedOneMin = oneMinuteCandles
        updatedOneMin.append(candle)
        oneMinuteCandles = updatedOneMin
        print("📈 1m candles count: \(oneMinuteCandles.count)")
        
        // Handle 5-minute aggregation
        if fiveMinBucket == nil {
            fiveMinBucket = CandleBucket(timeframe: 5)
        }
        
        // Add current candle to bucket
        fiveMinBucket!.addCandle(candle)
        
        // Check if we now have enough candles to close the bucket
        // For 5-minute candles, we need exactly 5 one-minute candles
        if fiveMinBucket!.candles.count == 5 {
            if let aggregated = fiveMinBucket!.aggregate() {
                var updatedFiveMin = fiveMinuteCandles
                updatedFiveMin.append(aggregated)
                fiveMinuteCandles = updatedFiveMin
            }
            // Start new bucket (will be populated with next candle)
            fiveMinBucket = CandleBucket(timeframe: 5)
        }
        
        // Handle 15-minute aggregation
        if fifteenMinBucket == nil {
            fifteenMinBucket = CandleBucket(timeframe: 15)
        }
        
        // Add current candle to bucket
        fifteenMinBucket!.addCandle(candle)
        
        // Check if we now have enough candles to close the bucket
        // For 15-minute candles, we need exactly 15 one-minute candles
        if fifteenMinBucket!.candles.count == 15 {
            if let aggregated = fifteenMinBucket!.aggregate() {
                var updatedFifteenMin = fifteenMinuteCandles
                updatedFifteenMin.append(aggregated)
                fifteenMinuteCandles = updatedFifteenMin
            }
            // Start new bucket (will be populated with next candle)
            fifteenMinBucket = CandleBucket(timeframe: 15)
        }
    }
    
    func reset() {
        oneMinuteCandles.removeAll()
        fiveMinuteCandles.removeAll()
        fifteenMinuteCandles.removeAll()
        fiveMinBucket = nil
        fifteenMinBucket = nil
    }
}

