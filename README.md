# CandlePower - Day Trading Game

A realistic day trading simulator built with SwiftUI for iOS, featuring real-time OHLC candle data, position management, margin requirements, and comprehensive trading mechanics.

## Features

### Trading Engine
- **Real-time Candle Aggregation**: Automatically aggregates 1-minute candles into 5-minute and 15-minute timeframes
- **Position Management**: Open long/short positions with contract size selection (1, 3, 5, 10, 15 contracts)
- **Margin Management**: 
  - MNQ contracts: $50 margin per contract
  - NQ contracts: $500 margin per contract
  - Automatic margin call warnings at $1,000 remaining
  - Auto-flatten positions when margin is exceeded
- **Slippage & Commissions**: 
  - Realistic slippage (0.25 or 0.5 points unfavorable)
  - $2.50 commission per contract
- **Price Precision**: All prices move in 0.25 increments

### Trading Day Simulation
- **Trading Hours**: 9:00 AM - 4:00 PM ET
- **Initial Setup**: 50 5-minute candles (250 1-minute candles) displayed before game starts
- **Time-based Volatility**:
  - 9:30 AM: 4x price movement
  - 9:31 AM - 10:59 AM: 2x price movement
  - 2:00 PM - 4:00 PM: 1.5x price movement
- **Boundary Candles**: Enhanced movement at 5-minute and 15-minute candle boundaries
- **Auto Game Over**: Positions automatically flattened at 4:00 PM ET with final P&L summary

### Chart Features
- **Interactive Charts**: Swift Charts with candlestick visualization
- **Pinch-to-Zoom**: Zoom horizontally and vertically on the chart
- **Auto-Spacing**: Default horizontal zoom ensures candles don't overlap with 2px gaps
- **Price Range**: Default vertical range of $200 above and below current price
- **Position Visualization**: 
  - Horizontal lines showing average entry prices for long/short positions
  - Real-time unrealized P&L displayed in position boxes
  - Current price indicator

### Account Management
- **Starting Balance**: $5,000
- **Real-time P&L**: 
  - Realized gain/loss tracking
  - Unrealized P&L updates with price movements
- **Position Tracking**: Weighted average entry prices for multiple positions
- **Trade History**: Complete record of all executed trades

### Controls
- **Speed Control**: Adjustable playback speed from 1x to 50x (default: 20x)
- **Timeframe Selection**: Switch between 1-minute, 5-minute, and 15-minute candles
- **Contract Type**: Choose between MNQ and NQ contracts
- **Trading Actions**: 
  - Buy (long) positions
  - Sell (short) positions
  - Flatten all positions
- **Reset**: Reset game state, balance, and positions

## Project Structure

```
CandlePower/
├── Models/
│   ├── Account.swift          # Trading account with balance, positions, and P&L
│   ├── Candle.swift           # OHLC candle data model and aggregation
│   └── Position.swift         # Position and trade models
├── Services/
│   ├── CandleAggregator.swift # Real-time candle aggregation (1m → 5m, 15m)
│   ├── DataSourceManager.swift # Data loading and playback control
│   └── TradingEngine.swift    # Core trading logic (buy, sell, margin checks)
├── ContentView.swift          # Main UI and chart display
├── CandlePowerApp.swift       # App entry point
└── nq_dataset.json           # Sample NQ price data
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+

## Getting Started

1. Clone the repository:
```bash
git clone https://github.com/essen48183/CandlePower.git
```

2. Open `CandlePower.xcodeproj` in Xcode

3. Build and run on your iOS device or simulator

## Usage

1. **Start the Game**: The app loads 50 5-minute candles of historical data
2. **Adjust Settings**: 
   - Select timeframe (1m, 5m, 15m)
   - Choose contract type (MNQ/NQ)
   - Set playback speed
3. **Trade**: 
   - Select contract size
   - Click BUY to open long positions
   - Click SELL to open short positions
   - Click FLATTEN to close all positions
4. **Monitor**: 
   - Watch your realized and unrealized P&L
   - Monitor margin requirements
   - Track position entry prices on the chart
5. **Game Over**: At 4:00 PM ET, all positions are automatically closed and final results are displayed

## Trading Mechanics

### Margin Requirements
- **MNQ**: $50 per contract
- **NQ**: $500 per contract
- Margin warnings appear when available margin drops below $1,000
- Positions are automatically flattened if margin is exceeded

### Slippage
- Random slippage of 0.25 or 0.5 points
- Always unfavorable (higher price for buys, lower price for sells)

### Commissions
- $2.50 per contract on all orders (opening and closing)

### Price Movement
- All prices move in 0.25 point increments
- Enhanced volatility at timeframe boundaries (5m and 15m candles)

## License

This project is private and proprietary.

## Author

Essen Davis

