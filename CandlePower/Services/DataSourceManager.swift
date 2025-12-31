//
//  DataSourceManager.swift
//  CandlePower
//
//  Created by Essen Davis on 12/31/25.
//

import Foundation
import Combine

enum DataSourceType {
    case historical
    case live
}

class DataSourceManager: ObservableObject {
    @Published var candles: [Candle] = []
    @Published var currentCandleIndex: Int = 0
    @Published var isPlaying: Bool = false
    
    private var timer: Timer?
    private var speed: Double = 1.0
    private var cancellables = Set<AnyCancellable>()
    
    var currentCandle: Candle? {
        guard currentCandleIndex < candles.count else { return nil }
        return candles[currentCandleIndex]
    }
    
    func loadHistoricalData(from filename: String) {
        // Try to load from bundle first
        if let url = Bundle.main.url(forResource: filename, withExtension: "json") {
            loadFromJSON(url: url)
        } else {
            // Fallback to generating sample data
            generateSampleNQData()
        }
    }
    
    private func loadFromJSON(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            candles = try decoder.decode([Candle].self, from: data)
        } catch {
            print("Error loading JSON: \(error)")
            generateSampleNQData()
        }
    }
    
    func generateSampleNQData() {
        var generated: [Candle] = []
        
        // Start at 25000 for NQ
        var price = 25000.0
        
        // Create calendar and timezone for ET
        var calendar = Calendar.current
        let etTimeZone = TimeZone(identifier: "America/New_York")!
        calendar.timeZone = etTimeZone
        
        // Start 51 five-minute periods before 9am (51 * 5 = 255 minutes = 4h15m before 9am = 4:45am)
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 4
        components.minute = 45
        components.second = 0
        guard var currentDate = calendar.date(from: components) else {
            print("Error creating start date")
            return
        }
        
        // End at 4:00 PM ET (11 hours 15 minutes = 675 minutes of candles from 4:45am to 4pm)
        let endDate = calendar.date(byAdding: .hour, value: 11, to: currentDate)!
        let finalEndDate = calendar.date(byAdding: .minute, value: 15, to: endDate)!
        
        var candleIndex = 0
        
        while currentDate < finalEndDate {
            // Determine time-based multiplier
            let hour = calendar.component(.hour, from: currentDate)
            let minute = calendar.component(.minute, from: currentDate)
            let timeMultiplier: Double
            
            if hour == 9 && minute == 30 {
                // Exactly 9:30 AM - quadruple movement
                timeMultiplier = 4.0
            } else if (hour == 9 && minute > 30) || (hour == 10) {
                // 9:31 AM - 10:59 AM - double movement (until 11am)
                timeMultiplier = 2.0
            } else if hour >= 14 && hour < 16 {
                // 2:00 PM - 4:00 PM - more movement (1.5x)
                timeMultiplier = 1.5
            } else {
                // Normal movement
                timeMultiplier = 1.0
            }
            
            // Check if this is a 5-minute boundary candle (5th or 6th candle in 5-minute cycle)
            let isFiveMinBoundary = (candleIndex % 5 == 4) || (candleIndex % 5 == 0)
            let fiveMinMultiplier: Double = isFiveMinBoundary ? 2.5 : 1.0
            
            // Check if this is a 15-minute boundary candle (15th or 16th candle in 15-minute cycle)
            let isFifteenMinBoundary = (candleIndex % 15 == 14) || (candleIndex % 15 == 0)
            let fifteenMinMultiplier: Double = isFifteenMinBoundary ? 4.0 : 1.0
            
            // Combine all multipliers
            let totalMultiplier = timeMultiplier * max(fiveMinMultiplier, fifteenMinMultiplier)
            
            // Base volatility with more variability
            let baseVolatility = Double.random(in: 1.0...3.5)
            let volatility = baseVolatility * totalMultiplier
            
            // Add some trend with more variability
            let trend = sin(Double(candleIndex) / 80.0) * Double.random(in: 3.0...8.0)
            
            // Price change with more variability, then round to 0.25 increments
            let randomChange = Double.random(in: -1.5...1.5)
            let change = (randomChange * volatility) + (trend * 0.3)
            
            price = max(24000, min(26000, price + change))
            // Round price to nearest 0.25
            price = round(price * 4.0) / 4.0
            
            // High and low with more variability, rounded to 0.25
            let highRange = Double.random(in: 1.0...5.0) * totalMultiplier
            let lowRange = Double.random(in: 1.0...5.0) * totalMultiplier
            let high = round((price + highRange) * 4.0) / 4.0
            let low = round((price - lowRange) * 4.0) / 4.0
            let close = round((price + Double.random(in: -2.5...2.5) * totalMultiplier) * 4.0) / 4.0
            
            let candle = Candle(
                timestamp: currentDate,
                open: price,
                high: high,
                low: low,
                close: close,
                volume: Double.random(in: 1000...5000)
            )
            generated.append(candle)
            
            // Move to next minute
            currentDate = calendar.date(byAdding: .minute, value: 1, to: currentDate)!
            
            // Update price for next iteration
            price = close
            candleIndex += 1
        }
        
        candles = generated
        print("📊 Generated \(candles.count) candles from 4:45 AM to 4:00 PM ET")
    }
    
    func setSpeed(_ newSpeed: Double) {
        speed = newSpeed
        if isPlaying {
            startPlayback()
        }
    }
    
    func startPlayback() {
        stopPlayback()
        
        // Starting index is 250 (250 1-minute candles = 50 5-minute candles)
        let playbackStartIndex = 250
        
        // If we're at or before the initial setup candles, start from playback start
        if currentCandleIndex < playbackStartIndex {
            currentCandleIndex = playbackStartIndex
        }
        
        isPlaying = true
        print("🎬 Starting playback at index: \(currentCandleIndex), speed: \(speed)x")
        
        // Calculate interval: At speed X, we want X candles per minute
        // So 1 candle every (60 / X) seconds
        let interval = 60.0 / speed
        print("⏱️ Timer interval: \(interval) seconds")
        
        // Use scheduledTimer which automatically adds to current run loop
        // Timer fires on main thread, so @Published updates will work correctly
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                print("❌ Timer callback: self is nil, invalidating")
                timer.invalidate()
                return
            }
            guard self.isPlaying else {
                print("⏸️ Timer callback: isPlaying is false, invalidating")
                timer.invalidate()
                return
            }
            if self.currentCandleIndex < self.candles.count {
                let oldIndex = self.currentCandleIndex
                
                // Check if we've reached 4pm ET (end of trading day) before incrementing
                if let currentCandle = self.currentCandle {
                    let calendar = Calendar.current
                    let etTimeZone = TimeZone(identifier: "America/New_York")!
                    var etCalendar = calendar
                    etCalendar.timeZone = etTimeZone
                    let hour = etCalendar.component(.hour, from: currentCandle.timestamp)
                    let minute = etCalendar.component(.minute, from: currentCandle.timestamp)
                    
                    if hour >= 16 { // 4pm or later
                        print("🏁 Reached 4:00 PM ET, stopping trading day")
                        self.stopPlayback()
                        // Notify that game is over (will be handled by ContentView)
                        NotificationCenter.default.post(name: NSNotification.Name("GameOver"), object: nil)
                        return
                    }
                }
                
                self.currentCandleIndex += 1
                print("⏭️ Timer fired: \(oldIndex) -> \(self.currentCandleIndex)")
            } else {
                print("🏁 Reached end of candles, stopping")
                self.stopPlayback()
            }
        }
        // Ensure timer is retained and fires
        RunLoop.main.add(timer!, forMode: .common)
        print("✅ Timer created and added to run loop")
    }
    
    func stopPlayback() {
        print("🛑 Stopping playback")
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
    
    func pausePlayback() {
        stopPlayback()
    }
    
    func reset() {
        stopPlayback()
        currentCandleIndex = 0
    }
    
    func regenerateData() {
        stopPlayback()
        currentCandleIndex = 0
        generateSampleNQData()
    }
}

