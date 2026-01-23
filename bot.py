#!/usr/bin/env python3
"""
XAUUSD Momentum Bot - Binance Edition
Real-time momentum candle detection using Binance XAUUSDT WebSocket
Based on Sekolah Trading momentum candle indicator logic
"""

import json
import time
import threading
import logging
from datetime import datetime, timezone
from collections import defaultdict, deque
import websocket
import requests
from config import *

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/xauusd-bot/logs/bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class CandleData:
    """Store candle OHLC data"""
    def __init__(self):
        self.open = None
        self.high = None
        self.low = None
        self.close = None
        self.timestamp = None
        self.prev_open = None
        
    def update(self, kline):
        """Update candle with Binance kline data"""
        self.open = float(kline['o'])
        self.high = float(kline['h'])
        self.low = float(kline['l'])
        self.close = float(kline['c'])
        self.timestamp = int(kline['t']) // 1000  # Convert ms to seconds

class MomentumBot:
    def __init__(self):
        self.ws = None
        self.candles = {
            '5': CandleData(),
            '15': CandleData()
        }
        self.prev_candles = {
            '5': CandleData(),
            '15': CandleData()
        }
        self.alert_sent = {
            '5': {'time': 0, 'type': None},
            '15': {'time': 0, 'type': None}
        }
        self.running = True
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 10
        self.first_start = True
        
        logger.info("=" * 60)
        logger.info("XAUUSD Momentum Bot - Binance Edition")
        logger.info("=" * 60)
        logger.info(f"Monitoring: XAUUSDT (Binance Futures)")
        logger.info(f"Timeframes: M5, M15")
        logger.info(f"M5 Body Min: {MOMENTUM_PIPS_M5} pips")
        logger.info(f"M15 Body Min: {MOMENTUM_PIPS_M15} pips")
        logger.info(f"Max Wick: {MAX_WICK_PERCENTAGE*100}%")
        logger.info(f"Alert Window: 20-90 seconds before close")
        logger.info("=" * 60)
        
    def send_discord_alert(self, timeframe, candle_type, body_pips, candle, time_left):
        """Send alert to Discord"""
        try:
            emoji = "🟢" if candle_type == "BULLISH" else "🔴"
            
            total_wick = (candle.high - max(candle.open, candle.close)) + \
                        (min(candle.open, candle.close) - candle.low)
            wick_pct = (total_wick / (abs(candle.close - candle.open) + total_wick)) * 100
            
            message = {
                "embeds": [{
                    "title": f"🚨 MOMENTUM DETECTED!",
                    "color": 65280 if candle_type == "BULLISH" else 16711680,
                    "fields": [
                        {"name": "Pair", "value": "XAUUSD (Binance)", "inline": True},
                        {"name": "Timeframe", "value": f"M{timeframe}", "inline": True},
                        {"name": "Type", "value": f"{emoji} **{candle_type}**", "inline": True},
                        {"name": "Body", "value": f"**{body_pips:.1f} pips**", "inline": True},
                        {"name": "Open", "value": f"{candle.open:.2f}", "inline": True},
                        {"name": "Close", "value": f"{candle.close:.2f}", "inline": True},
                        {"name": "High", "value": f"{candle.high:.2f}", "inline": True},
                        {"name": "Low", "value": f"{candle.low:.2f}", "inline": True},
                        {"name": "Wick %", "value": f"{wick_pct:.1f}% ✓", "inline": True},
                        {"name": "⏰ Time Left", "value": f"**{time_left} seconds**", "inline": False}
                    ],
                    "timestamp": datetime.utcnow().isoformat(),
                    "footer": {"text": "Momentum Candle V3 - Sekolah Trading Logic"}
                }]
            }
            
            response = requests.post(DISCORD_WEBHOOK_URL, json=message, timeout=10)
            
            if response.status_code == 204:
                logger.info(f"✅ Discord alert sent: M{timeframe} {candle_type}")
                return True
            else:
                logger.error(f"Discord alert failed: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"Error sending Discord alert: {e}")
            return False
    
    def check_momentum(self, timeframe, candle, prev_candle):
        """Check if candle meets momentum criteria"""
        min_pips = MOMENTUM_PIPS_M5 if timeframe == '5' else MOMENTUM_PIPS_M15
        
        body = abs(candle.close - candle.open)
        body_pips = body / PIP_SIZE_XAUUSD
        
        if body_pips < min_pips:
            return None, 0
        
        upper_wick = candle.high - max(candle.open, candle.close)
        lower_wick = min(candle.open, candle.close) - candle.low
        total_wick = upper_wick + lower_wick
        
        wick_percentage = total_wick / (body + total_wick)
        if wick_percentage > MAX_WICK_PERCENTAGE:
            return None, 0
        
        is_bullish = candle.close > candle.open
        
        is_bearish_engulfing = False
        if prev_candle and prev_candle.open:
            is_bearish_engulfing = (candle.close > candle.open) and (candle.close < prev_candle.open)
        
        is_bearish = (candle.close < candle.open) or is_bearish_engulfing
        
        if is_bullish:
            return "BULLISH", body_pips
        elif is_bearish:
            return "BEARISH", body_pips
        
        return None, 0
    
    def check_alert_window(self, timeframe):
        """Check if in alert window (20-90s before close)"""
        current_time = int(time.time())
        
        interval_seconds = 5 * 60 if timeframe == '5' else 15 * 60
        
        candle = self.candles[timeframe]
        if not candle.timestamp:
            return False, 0
        
        candle_close_time = candle.timestamp + interval_seconds
        time_left = candle_close_time - current_time
        
        in_window = 20 <= time_left <= 90
        
        return in_window, time_left
    
    def process_candle_update(self, timeframe, kline):
        """Process incoming kline data"""
        try:
            candle = self.candles[timeframe]
            prev_candle = self.prev_candles[timeframe]
            
            # Check if new candle
            new_timestamp = int(kline['t']) // 1000
            if candle.timestamp and new_timestamp != candle.timestamp:
                # Save previous
                prev_candle.open = candle.open
                prev_candle.high = candle.high
                prev_candle.low = candle.low
                prev_candle.close = candle.close
                prev_candle.timestamp = candle.timestamp
                
                logger.info(f"📊 M{timeframe} new candle started")
            
            # Update current
            candle.update(kline)
            
            # Check alert window
            in_window, time_left = self.check_alert_window(timeframe)
            
            if not in_window:
                return
            
            # Check momentum
            candle_type, body_pips = self.check_momentum(timeframe, candle, prev_candle)
            
            if not candle_type:
                return
            
            # Check cooldown
            last_alert = self.alert_sent[timeframe]
            time_since_last = time.time() - last_alert['time']
            
            should_send = (
                last_alert['time'] == 0 or
                last_alert['type'] != candle_type or
                time_since_last > ALERT_COOLDOWN
            )
            
            if should_send:
                logger.info(f"🎯 M{timeframe} {candle_type} momentum: {body_pips:.1f} pips (closes in {time_left}s)")
                
                if self.send_discord_alert(timeframe, candle_type, body_pips, candle, time_left):
                    self.alert_sent[timeframe]['time'] = time.time()
                    self.alert_sent[timeframe]['type'] = candle_type
                    
        except Exception as e:
            logger.error(f"Error processing M{timeframe} candle: {e}")
    
    def on_message(self, ws, message):
        """Handle WebSocket messages"""
        try:
            data = json.loads(message)
            
            # Skip subscription confirmation
            if 'result' in data:
                return
            
            # Process kline data
            if 'e' in data and data['e'] == 'kline':
                kline = data['k']
                interval = kline['i']
                
                # Map interval to timeframe
                if interval == '5m':
                    timeframe = '5'
                elif interval == '15m':
                    timeframe = '15'
                else:
                    return
                
                self.process_candle_update(timeframe, kline)
                
        except Exception as e:
            logger.error(f"Error in on_message: {e}")
    
    def on_error(self, ws, error):
        """Handle WebSocket errors"""
        logger.error(f"WebSocket error: {error}")
    
    def on_close(self, ws, close_status_code, close_msg):
        """Handle WebSocket close"""
        logger.warning(f"WebSocket closed: {close_status_code} - {close_msg}")
        
        if self.running:
            logger.info("Attempting to reconnect...")
            time.sleep(5)
            self.connect()
    
    def on_open(self, ws):
        """Handle WebSocket open"""
        logger.info("✅ WebSocket connected to Binance")
        self.reconnect_attempts = 0
        
        # Subscribe to M5 and M15 klines
        subscribe_msg = {
            "method": "SUBSCRIBE",
            "params": [
                "xauusdt@kline_5m",
                "xauusdt@kline_15m"
            ],
            "id": 1
        }
        ws.send(json.dumps(subscribe_msg))
        logger.info("📡 Subscribed to M5 and M15 klines")
        
        # Send startup notification ONLY on first start
        if self.first_start:
            self.first_start = False
            try:
                startup_msg = {
                    "embeds": [{
                        "title": "✅ Bot Started",
                        "description": "XAUUSD Momentum Bot is now monitoring Binance XAUUSDT",
                        "color": 3447003,
                        "fields": [
                            {"name": "Timeframes", "value": "M5, M15", "inline": True},
                            {"name": "M5 Threshold", "value": f"{MOMENTUM_PIPS_M5} pips", "inline": True},
                            {"name": "M15 Threshold", "value": f"{MOMENTUM_PIPS_M15} pips", "inline": True}
                        ],
                        "timestamp": datetime.utcnow().isoformat()
                    }]
                }
                requests.post(DISCORD_WEBHOOK_URL, json=startup_msg, timeout=10)
            except:
                pass
    
    def connect(self):
        """Connect to Binance WebSocket"""
        if self.reconnect_attempts >= self.max_reconnect_attempts:
            logger.error("Max reconnection attempts reached. Exiting.")
            self.running = False
            return
        
        try:
            self.reconnect_attempts += 1
            
            # Binance Futures WebSocket
            ws_url = "wss://fstream.binance.com/ws"
            
            self.ws = websocket.WebSocketApp(
                ws_url,
                on_message=self.on_message,
                on_error=self.on_error,
                on_close=self.on_close,
                on_open=self.on_open
            )
            
            # Run WebSocket
            ws_thread = threading.Thread(target=self.ws.run_forever)
            ws_thread.daemon = True
            ws_thread.start()
            
        except Exception as e:
            logger.error(f"Connection error: {e}")
            if self.running:
                time.sleep(5)
                self.connect()
    
    def run(self):
        """Main run loop"""
        self.connect()
        
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            self.running = False
            if self.ws:
                self.ws.close()

if __name__ == "__main__":
    try:
        bot = MomentumBot()
        bot.run()
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        raise
