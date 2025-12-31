//
//  ContentView.swift
//  CandlePower
//
//  Created by Essen Davis on 12/31/25.
//

import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var dataSource = DataSourceManager()
    @StateObject private var aggregator = CandleAggregator()
    @StateObject private var tradingEngine = TradingEngine()
    @State private var selectedTimeframe: Int = 5
    @State private var selectedContractSize: Int = 1
    @State private var speed: Double = 20.0
    @State private var selectedContractType: ContractType = .MNQ
    @State private var showMarginCalledAlert = false
    @State private var showMarginWarningAlert = false
    @State private var showGameOverAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Contract Type and Timeframe Selector - Fixed at top
            HStack {
                // Contract Type Picker
                Picker("Contract", selection: $selectedContractType) {
                    ForEach(ContractType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .font(.caption)
                .frame(width: 100)
                
                Text("Timeframe:")
                    .font(.caption)
                ForEach([1, 5, 15], id: \.self) { tf in
                    Button(action: { selectedTimeframe = tf }) {
                        Text("\(tf)min")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTimeframe == tf ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedTimeframe == tf ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 2)
            
            // Margin Display - Single line below timeframe
            HStack {
                Text("Margin:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("$\(Int(tradingEngine.account.marginAvailable))")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("|")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("$\(Int(tradingEngine.account.totalMarginRequired))")
                    .font(.caption2)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 2)
            
            // Chart View - Takes remaining space
            ChartView(
                selectedTimeframe: selectedTimeframe,
                currentPrice: tradingEngine.currentPrice,
                account: tradingEngine.account,
                aggregator: aggregator
            )
            .id("chart-\(aggregator.oneMinuteCandles.count)-\(aggregator.fiveMinuteCandles.count)-\(aggregator.fifteenMinuteCandles.count)")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Account Info - Fixed at bottom
            AccountInfoView(account: tradingEngine.account)
                .padding(.horizontal)
                .padding(.vertical, 4)
            
            Divider()
            
            // Trading Controls - Fixed at bottom
            VStack(spacing: 8) {
                // Contract Size Selector
                HStack {
                    Text("Contracts:")
                        .font(.caption)
                    ForEach([1, 3, 5, 10, 15], id: \.self) { size in
                        Button(action: { selectedContractSize = size }) {
                            Text("\(size)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedContractSize == size ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedContractSize == size ? .white : .primary)
                                .cornerRadius(6)
                        }
                    }
                }
                
                // Buy/Sell/Flatten Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        if tradingEngine.currentPrice > 0 {
                            tradingEngine.buy(contracts: selectedContractSize, price: tradingEngine.currentPrice, timestamp: dataSource.currentCandle?.timestamp ?? Date(), contractType: selectedContractType)
                        }
                    }) {
                        Text("BUY")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if tradingEngine.currentPrice > 0 {
                            tradingEngine.flatten(at: tradingEngine.currentPrice, timestamp: dataSource.currentCandle?.timestamp ?? Date())
                        }
                    }) {
                        Text("FLATTEN")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if tradingEngine.currentPrice > 0 {
                            tradingEngine.sell(contracts: selectedContractSize, price: tradingEngine.currentPrice, timestamp: dataSource.currentCandle?.timestamp ?? Date(), contractType: selectedContractType)
                        }
                    }) {
                        Text("SELL")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                
                // Speed Control
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speed: \(speed, specifier: "%.1f")x")
                        .font(.caption)
                        .fontWeight(.semibold)
                    HStack {
                        Text("1x")
                            .font(.caption2)
                        Slider(value: $speed, in: 1...50, step: 0.1)
                            .onChange(of: speed) { oldValue, newValue in
                                dataSource.setSpeed(newValue)
                            }
                        Text("50x")
                            .font(.caption2)
                    }
                }
                .padding(.horizontal)
                
                // Playback Controls
                HStack(spacing: 12) {
                    Button(action: { 
                        tradingEngine.reset()
                        dataSource.regenerateData()
                        loadInitialCandles()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        if dataSource.isPlaying {
                            dataSource.pausePlayback()
                        } else {
                            // Start playback
                            let startIndex = dataSource.currentCandleIndex
                            dataSource.startPlayback()
                            // Starting index is 250
                            let playbackStartIndex = 250
                            
                            // Process first candle immediately if we're starting from playback start
                            if startIndex < playbackStartIndex && dataSource.currentCandleIndex >= playbackStartIndex {
                                // We just jumped to playback start, process it
                                if dataSource.currentCandleIndex < dataSource.candles.count {
                                    let candle = dataSource.candles[dataSource.currentCandleIndex]
                                    aggregator.addCandle(candle)
                                    tradingEngine.updatePrice(candle.close)
                                }
                            }
                        }
                    }) {
                        Image(systemName: dataSource.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(dataSource.isPlaying ? Color.orange : Color.blue)
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Candle: \(dataSource.currentCandleIndex + 1)/\(dataSource.candles.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("1m: \(aggregator.oneMinuteCandles.count) | 5m: \(aggregator.fiveMinuteCandles.count) | 15m: \(aggregator.fifteenMinuteCandles.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .onAppear {
            // Reset game state at start
            tradingEngine.reset()
            
            dataSource.loadHistoricalData(from: "nq_dataset")
            dataSource.setSpeed(speed)
            // Load initial 50 candles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                loadInitialCandles()
            }
            
            // Listen for game over notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("GameOver"),
                object: nil,
                queue: .main
            ) { _ in
                handleGameOver()
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("GameOver"), object: nil)
        }
        .onReceive(dataSource.$candles) { newCandles in
            // When candles load, load initial 50
            if !newCandles.isEmpty && dataSource.currentCandleIndex == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    loadInitialCandles()
                }
            }
        }
        .onReceive(tradingEngine.$marginCalled) { marginCalled in
            if marginCalled {
                showMarginCalledAlert = true
                // Reset the flag after showing alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    tradingEngine.marginCalled = false
                }
            }
        }
        .onReceive(tradingEngine.$marginWarningShown) { warningShown in
            if warningShown {
                showMarginWarningAlert = true
            }
        }
        .alert("Margin Called", isPresented: $showMarginCalledAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your positions have been flattened due to insufficient margin.")
        }
        .alert("Margin Warning", isPresented: $showMarginWarningAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Warning: You are within $1,000 of a margin call. Current margin available: $\(Int(tradingEngine.account.marginAvailable))")
        }
        .alert("Game Over", isPresented: $showGameOverAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Trading day ended at 4:00 PM ET\n\nTotal Realized P&L: $\(Int(tradingEngine.totalRealizedPnL))\nFinal Balance: $\(Int(tradingEngine.account.realizedBalance))")
        }
        .onReceive(dataSource.$currentCandleIndex) { index in
            print("📊 onReceive triggered: index = \(index), isPlaying = \(dataSource.isPlaying)")
            // Starting index is 250 (250 1-minute candles = 50 5-minute candles)
            let startIndex = 250
            
            // Process new candles during playback (past initial setup)
            if index >= startIndex && index < dataSource.candles.count {
                let candle = dataSource.candles[index]
                print("🕯️ Processing candle \(index): price = \(candle.close), timestamp = \(candle.timestamp)")
                aggregator.addCandle(candle)
                tradingEngine.updatePrice(candle.close)
                print("✅ Candle added. 1m: \(aggregator.oneMinuteCandles.count), 5m: \(aggregator.fiveMinuteCandles.count), 15m: \(aggregator.fifteenMinuteCandles.count)")
            } else {
                print("⚠️ Index \(index) out of range or before start index")
            }
        }
    }
    
    private func loadInitialCandles() {
        aggregator.reset()
        dataSource.reset()
        
        // Load 250 1-minute candles starting at 9am (creates 50 5-minute candles)
        let initialCandleCount = 250
        let initialCount = min(initialCandleCount, dataSource.candles.count)
        guard initialCount > 0 else { return }
        
        for i in 0..<initialCount {
            let candle = dataSource.candles[i]
            aggregator.addCandle(candle)
            if i == initialCount - 1 {
                tradingEngine.updatePrice(candle.close)
            }
        }
        // Set the current index to 250 so playback starts from the next candle
        dataSource.currentCandleIndex = initialCount
    }
    
    private func handleGameOver() {
        // Flatten all positions at current price
        if tradingEngine.currentPrice > 0 {
            tradingEngine.flatten(at: tradingEngine.currentPrice, timestamp: Date())
        }
        
        // Set game over flag
        tradingEngine.gameOver = true
        
        // Show game over alert
        showGameOverAlert = true
    }
    
}

struct AccountInfoView: View {
    @ObservedObject var account: TradingAccount
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Realized:")
                    .font(.caption)
                Spacer()
                Text("$\(account.realizedGain, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(account.realizedGain >= 0 ? .green : .red)
            }
            
            HStack {
                Text("Unrealized:")
                    .font(.caption)
                Spacer()
                Text("$\(account.unrealizedPnL, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(account.unrealizedPnL >= 0 ? .green : .red)
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("Total:")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("$\(account.totalBalance, specifier: "%.2f")")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            Divider()
            Text("Open Positions:")
                .font(.caption)
                .fontWeight(.semibold)
            
            if account.positions.isEmpty {
                Text("No open positions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                if let longPrice = account.averageLongEntryPrice {
                    HStack {
                        Text("LONG")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                        Text("\(account.totalLongContracts) @ \(longPrice, specifier: "%.2f")")
                            .font(.caption2)
                        Spacer()
                    }
                }
                
                if let shortPrice = account.averageShortEntryPrice {
                    HStack {
                        Text("SHORT")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                        Text("\(account.totalShortContracts) @ \(shortPrice, specifier: "%.2f")")
                            .font(.caption2)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct ChartView: View {
    let selectedTimeframe: Int
    let currentPrice: Double
    @ObservedObject var account: TradingAccount
    @ObservedObject var aggregator: CandleAggregator
    
    @State private var baseYZoom: Double = 1.0
    @State private var baseXZoom: Double = 1.0
    @State private var yOffset: Double = 0.0
    @GestureState private var magnification: CGFloat = 1.0
    @State private var chartWidth: CGFloat = 400.0 // Default estimated width
    @State private var hasUserZoomed: Bool = false // Track if user has manually zoomed
    
    private var yZoom: Double {
        baseYZoom * Double(magnification)
    }
    
    private var xZoom: Double {
        baseXZoom * Double(magnification)
    }
    
    // Calculate default xZoom to fit candles with 2px gap between them
    private func calculateDefaultXZoom(force: Bool = false) {
        // Only recalculate if user hasn't manually zoomed, or if forced (e.g., timeframe change)
        guard !hasUserZoomed || force else { return }
        
        let candleCount = allCandles.count
        guard candleCount > 0 else { return }
        
        // Candle body width is 6px, gap is 2px, so each candle takes 8px
        let pixelsPerCandle: CGFloat = 8.0
        let totalPixelsNeeded = CGFloat(candleCount) * pixelsPerCandle
        
        // Calculate zoom needed to fit all candles with gaps
        // If we need more pixels than available, we need to zoom in (higher xZoom)
        // xZoom = totalPixelsNeeded / availableWidth
        let availableWidth = max(chartWidth - 60, 100) // Account for padding/axis
        let requiredZoom = totalPixelsNeeded / availableWidth
        
        // Set baseXZoom to fit all candles with gaps
        baseXZoom = max(1.0, Double(requiredZoom))
    }
    
    private var allCandles: [Candle] {
        switch selectedTimeframe {
        case 1:
            return aggregator.oneMinuteCandles
        case 5:
            var candles = aggregator.fiveMinuteCandles
            // Add current partial candle if bucket is filling
            if let partial = aggregator.currentFiveMinuteCandle {
                candles.append(partial)
            }
            return candles
        case 15:
            var candles = aggregator.fifteenMinuteCandles
            // Add current partial candle if bucket is filling
            if let partial = aggregator.currentFifteenMinuteCandle {
                candles.append(partial)
            }
            return candles
        default:
            return aggregator.oneMinuteCandles
        }
    }
    
    private var candles: [Candle] {
        // Apply xZoom to limit visible candles (zoom in = show fewer candles)
        let baseCount = allCandles.count
        guard baseCount > 0 else { return [] }
        let visibleCount = max(1, Int(Double(baseCount) / xZoom))
        let startIndex = max(0, baseCount - visibleCount)
        return Array(allCandles[startIndex...])
    }
    
    
    private var yRange: ClosedRange<Double> {
        if currentPrice > 0 {
            let baseRange = 200.0 // 200 dollars above and below
            let center = currentPrice + yOffset
            let range = baseRange / yZoom
            return (center - range)...(center + range)
        } else if !candles.isEmpty {
            let prices = candles.flatMap { [$0.high, $0.low, $0.open, $0.close] }
            let minPrice = prices.min() ?? 0
            let maxPrice = prices.max() ?? 0
            let center = (minPrice + maxPrice) / 2
            let range = 200.0 / yZoom
            return (center - range)...(center + range)
        } else {
            return 0...100
        }
    }
    
    var body: some View {
        let _ = print("🎨 ChartView body called - candles count: \(candles.count), timeframe: \(selectedTimeframe)")
        return GeometryReader { geometry in
            Chart {
            ForEach(candles) { candle in
                // Upper wick
                RectangleMark(
                    x: .value("Time", candle.timestamp, unit: .minute),
                    yStart: .value("High", max(candle.open, candle.close)),
                    yEnd: .value("High", candle.high),
                    width: .fixed(1)
                )
                .foregroundStyle(candle.close >= candle.open ? Color.green : Color.red)
                
                // Candlestick body
                BarMark(
                    x: .value("Time", candle.timestamp, unit: .minute),
                    yStart: .value("Open", min(candle.open, candle.close)),
                    yEnd: .value("Close", max(candle.open, candle.close)),
                    width: .fixed(6)
                )
                .foregroundStyle(candle.close >= candle.open ? Color.green : Color.red)
                
                // Lower wick
                RectangleMark(
                    x: .value("Time", candle.timestamp, unit: .minute),
                    yStart: .value("Low", min(candle.open, candle.close)),
                    yEnd: .value("Low", candle.low),
                    width: .fixed(1)
                )
                .foregroundStyle(candle.close >= candle.open ? Color.green : Color.red)
            }
            
            // Current price line
            if currentPrice > 0 {
                RuleMark(y: .value("Price", currentPrice))
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .trailing, alignment: .center) {
                        Text("\(currentPrice, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .animation(.easeInOut(duration: 0.2), value: currentPrice)
                    }
            }
            
            // Average long entry price line
            if let longEntry = account.averageLongEntryPrice {
                RuleMark(y: .value("Long Entry", longEntry))
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        HStack(spacing: 4) {
                            Text("LONG")
                                .font(.caption2)
                                .fontWeight(.bold)
                            Text("$\(Int(account.unrealizedLongPnL))")
                                .font(.caption)
                        }
                        .padding(4)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
            }
            
            // Average short entry price line
            if let shortEntry = account.averageShortEntryPrice {
                RuleMark(y: .value("Short Entry", shortEntry))
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        HStack(spacing: 4) {
                            Text("SHORT")
                                .font(.caption2)
                                .fontWeight(.bold)
                            Text("$\(Int(account.unrealizedShortPnL))")
                                .font(.caption)
                        }
                        .padding(4)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYScale(domain: yRange)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentPrice)
        .gesture(
            MagnificationGesture()
                .updating($magnification) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { value in
                    // Mark that user has manually zoomed
                    hasUserZoomed = true
                    // Apply the magnification to base zoom values
                    baseYZoom *= Double(value)
                    baseXZoom *= Double(value)
                    // Clamp values
                    baseYZoom = max(0.1, min(10.0, baseYZoom))
                    baseXZoom = max(0.1, min(10.0, baseXZoom))
                }
        )
        .onChange(of: currentPrice) { oldValue, newValue in
            // Keep Y-axis centered on current price
            if newValue > 0 {
                yOffset = 0
            }
        }
        .onAppear {
            // Set initial chart width and calculate default zoom
            chartWidth = geometry.size.width
            calculateDefaultXZoom()
        }
        .onChange(of: geometry.size.width) { oldValue, newValue in
            // Update chart width when size changes
            chartWidth = newValue
            calculateDefaultXZoom()
        }
        .onChange(of: selectedTimeframe) { oldValue, newValue in
            // Reset user zoom flag and recalculate default zoom when timeframe changes
            hasUserZoomed = false
            calculateDefaultXZoom(force: true)
        }
        .onChange(of: allCandles.count) { oldValue, newValue in
            // Only recalculate when candle count changes if user hasn't zoomed
            if newValue > 0 && !hasUserZoomed {
                calculateDefaultXZoom()
            }
        }
        .padding()
        }
    }
}

#Preview {
    ContentView()
}

