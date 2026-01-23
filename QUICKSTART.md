# 🚀 QUICK START - 3 MINUTES TO RUNNING BOT

## Step 1: Get Discord Webhook (1 minute)
1. Open your Discord server
2. Server Settings → Integrations → Webhooks
3. Click "New Webhook"
4. Choose channel (e.g., #trading-alerts)
5. Click "Copy Webhook URL"
6. Save it somewhere

## Step 2: Upload Files to VPS (1 minute)

### Option A: Direct Upload
Upload these files to your VPS:
- `install.sh`
- `bot.py`
- `config.py.template`
- `requirements.txt`

### Option B: From Local Machine
```bash
scp install.sh bot.py config.py.template requirements.txt root@YOUR_VPS_IP:/root/
```

## Step 3: Run Installer (1 minute)
```bash
# SSH to your VPS
ssh root@YOUR_VPS_IP

# Make installer executable
chmod +x install.sh

# Run installer
sudo ./install.sh
```

## Step 4: Answer Questions
The installer will ask:

1. **Discord Webhook URL**: Paste the URL from Step 1
2. **M5 threshold (pips)**: Press Enter for default (40)
3. **M15 threshold (pips)**: Press Enter for default (50)
4. **Max wick %**: Press Enter for default (30)
5. **Start now?**: Type `y` and press Enter

## ✅ DONE!

Your bot is now:
- ✅ Running as systemd service
- ✅ Auto-starts on reboot
- ✅ Auto-restarts if crash
- ✅ Monitoring M5 and M15
- ✅ Sending Discord alerts

## 📊 View Live Logs
```bash
sudo journalctl -u xauusd-bot -f
```

Press Ctrl+C to exit logs (bot keeps running)

## 🎯 What You'll See

Within minutes, you should see in logs:
```
✅ WebSocket connected to Binance
📡 Subscribed to M5 and M15 klines
```

Every 5 minutes:
```
📊 M5 new candle started
```

When momentum detected:
```
🎯 M5 BULLISH momentum: 45.2 pips (closes in 35s)
✅ Discord alert sent: M5 BULLISH
```

## 🔧 Management

Run installer again for menu:
```bash
sudo ./install.sh
```

Options:
- View Status
- View Logs
- Edit Settings
- Test Discord
- Stop/Start/Restart

## ⚠️ Troubleshooting

**No alerts appearing?**
```bash
# Check bot is running
sudo systemctl status xauusd-bot

# Check logs
sudo journalctl -u xauusd-bot -n 50
```

**Discord not working?**
```bash
# Test webhook
sudo ./install.sh
# Choose option 8 (Test Discord Alert)
```

## 💡 Tips

1. **Keep logs open** during first 5-10 minutes to see it working
2. **Test Discord** before leaving it running
3. **M5 candles close** every 5 minutes (e.g., 10:00, 10:05, 10:10)
4. **Alerts appear 20-90 seconds** before candle closes
5. **"New candle" logs** confirm bot is receiving data

## 🎉 That's It!

You now have a professional momentum alert system running 24/7, completely free, with unlimited API calls!

Any momentum candle on XAUUSDT M5/M15 that meets your criteria will trigger a Discord alert.

**Data Source**: Binance XAUUSDT Futures (99% correlation with XAUUSD Forex)

**Happy Trading!** 📈
