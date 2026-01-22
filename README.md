# 🤖 XAUUSD Momentum Bot

Professional automated trading alert system for XAUUSD (Gold) based on **Sekolah Trading** momentum candle logic.

## 🎯 Features

- ✅ **Real-time monitoring** of XAUUSD M5 and M15 timeframes
- ✅ **Body-based momentum detection** (not total range)
- ✅ **Wick filter** (max 30% - Sekolah Trading standard)
- ✅ **Smart alert window** (20-90 seconds before candle close)
- ✅ **Bearish engulfing pattern detection**
- ✅ **Discord notifications** with detailed candle data
- ✅ **Daily summary reports**
- ✅ **Error notifications** and auto-reconnect
- ✅ **Full menu system** for easy management

## 📊 Logic (Sekolah Trading)

### Momentum Detection:
- **M5**: Body minimum 40 pips (configurable)
- **M15**: Body minimum 50 pips (configurable)
- **Body calculation**: `abs(close - open)` in pips

### Wick Filter:
```
total_wick = upper_wick + lower_wick
wick_percentage = total_wick / (body + total_wick)
Valid if: wick_percentage ≤ 30%
```

### Bearish Condition:
- Red candle: `close < open`, OR
- Bearish engulfing: `close > open` BUT `close < previous_open`

### Alert Window:
- Alert triggers **20-90 seconds** before candle closes
- Prevents false signals from incomplete candles
- 60-second cooldown to prevent spam

## 🚀 Installation

### One-Command Install:
```bash
wget https://raw.githubusercontent.com/yourusername/xauusd-momentum-bot/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### Requirements:
- Ubuntu 20.04+ (VPS)
- Root access
- 2GB RAM minimum
- Forex.com MT5 account (demo or live)
- Discord webhook URL

### Installation Steps:
1. Run installer
2. Enter Discord webhook URL
3. Enter MT5 credentials
4. Configure momentum settings
5. Bot auto-starts!

## 📱 Discord Alerts

### Momentum Alert Example:
```
🚨 MOMENTUM DETECTED!

Pair: XAUUSD
Timeframe: M5
Type: 🟢 BULLISH

Body: 45.2 pips
Open: 2685.30
Close: 2689.82
Wick %: 11.7% ✓

Candle closes in: 35 seconds
```

## ⚙️ Configuration

### Edit Settings:
```bash
sudo ./install.sh
# Select [7] Settings & Configuration
```

### Manual Edit:
```bash
sudo nano /opt/xauusd-bot/config.py
sudo systemctl restart xauusd-bot
```

### Key Settings:
- `MOMENTUM_PIPS_M5`: M5 body minimum (default: 40)
- `MOMENTUM_PIPS_M15`: M15 body minimum (default: 50)
- `MAX_WICK_PERCENTAGE`: Wick filter (default: 0.30)
- `ALERT_COOLDOWN`: Cooldown between alerts (default: 60s)

## 📊 Management Commands
```bash
# View menu
sudo ./install.sh

# Quick commands
sudo systemctl start xauusd-bot     # Start
sudo systemctl stop xauusd-bot      # Stop
sudo systemctl restart xauusd-bot   # Restart
sudo systemctl status xauusd-bot    # Status

# View logs
sudo journalctl -u xauusd-bot -f    # Live logs
tail -f /opt/xauusd-bot/logs/bot.log
```

## 🔧 Troubleshooting

### Bot Not Starting:
```bash
sudo systemctl status xauusd-bot
sudo journalctl -u xauusd-bot -n 50
```

### MT5 Connection Issues:
```bash
ps aux | grep terminal64
sudo ./install.sh → [9] Maintenance → [5] Restart MT5
```

### No Discord Alerts:
```bash
sudo ./install.sh → [8] Test Discord Alert
# Check webhook URL in /opt/xauusd-bot/.env
```

## 📈 Statistics

View statistics via menu:
```bash
sudo ./install.sh → [6] Bot Statistics
```

Daily summary sent to Discord at 00:00 UTC.

## 🗑️ Uninstall
```bash
sudo ./install.sh → [10] Uninstall Bot
# Type 'UNINSTALL' to confirm
```

## 📝 License

MIT License - Free to use and modify

## 🙏 Credits

Based on **Sekolah Trading** momentum candle indicator logic.

## 📞 Support

For issues or questions, open an issue on GitHub.

---

**Happy Trading! 🚀**