#!/bin/bash

#############################################
# XAUUSD Momentum Bot - MT5 ZeroMQ Version
# Version: 3.0.0 (REAL-TIME)
# Data Source: MT5 + ZeroMQ Bridge
# Logic: 100% Sekolah Trading
#############################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

INSTALL_DIR="/opt/xauusd-bot"
SERVICE_FILE="/etc/systemd/system/xauusd-bot.service"
LOG_DIR="$INSTALL_DIR/logs"
MT5_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts"

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     🚀 XAUUSD MOMENTUM BOT - MT5 ZEROMQ VERSION 🚀       ║"
    echo "║                   Version 3.0.0                           ║"
    echo "║          ⚡ TRUE REAL-TIME (<1 SEC DELAY) ⚡              ║"
    echo "║              Based on Sekolah Trading Logic               ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

install_dependencies() {
    echo -e "${BOLD}Installing dependencies...${NC}\n"
    
    echo -e "${BLUE}[1/7]${NC} Updating system..."
    apt update > /dev/null 2>&1
    
    echo -e "${BLUE}[2/7]${NC} Enabling 32-bit architecture..."
    dpkg --add-architecture i386 > /dev/null 2>&1
    
    echo -e "${BLUE}[3/7]${NC} Installing Wine..."
    mkdir -pm755 /etc/apt/keyrings 2>/dev/null || true
    wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    wget -q -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/focal/winehq-focal.sources
    apt update > /dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt install -y --install-recommends winehq-stable > /dev/null 2>&1
    echo -e "${GREEN}✓ Wine installed${NC}"
    
    echo -e "${BLUE}[4/7]${NC} Installing Xvfb..."
    apt install -y xvfb > /dev/null 2>&1
    echo -e "${GREEN}✓ Xvfb installed${NC}"
    
    echo -e "${BLUE}[5/7]${NC} Downloading MetaTrader 5..."
    wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /tmp/mt5setup.exe
    echo -e "${GREEN}✓ MT5 downloaded${NC}"
    
    echo -e "${BLUE}[6/7]${NC} Installing MetaTrader 5..."
    WINEARCH=win64 WINEPREFIX=~/.wine xvfb-run wine /tmp/mt5setup.exe /auto > /dev/null 2>&1 || true
    sleep 5
    echo -e "${GREEN}✓ MT5 installed${NC}"
    
    echo -e "${BLUE}[7/7]${NC} Installing Python packages..."
    apt install -y python3 python3-pip > /dev/null 2>&1
    pip3 install --break-system-packages pyzmq requests python-dotenv pytz > /dev/null 2>&1
    echo -e "${GREEN}✓ Python packages installed${NC}"
    
    echo ""
}

create_zmq_ea() {
    echo -e "${BLUE}Creating ZeroMQ Expert Advisor...${NC}"
    
    mkdir -p "$EA_DIR"
    
    cat > "$EA_DIR/XAUUSD_ZMQ_Server.mq5" << 'EAEOF'
//+------------------------------------------------------------------+
//|                                      XAUUSD_ZMQ_Server.mq5       |
//|                        ZeroMQ Server for XAUUSD Real-time Data   |
//|                                   Sekolah Trading Bot Backend    |
//+------------------------------------------------------------------+
#property copyright "XAUUSD Momentum Bot"
#property version   "3.0"
#property strict

#include <Zmq/Zmq.mqh>

input string ZMQ_PORT = "5555";

Context context("xauusd_zmq");
Socket publisher(context, ZMQ_PUB);

datetime lastM5Time = 0;
datetime lastM15Time = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    string endpoint = "tcp://*:" + ZMQ_PORT;
    
    if(!publisher.bind(endpoint))
    {
        Print("ERROR: Failed to bind ZMQ publisher to ", endpoint);
        return INIT_FAILED;
    }
    
    Print("✓ ZMQ Server started on ", endpoint);
    Print("✓ Streaming XAUUSD real-time data");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    publisher.unbind("tcp://*:" + ZMQ_PORT);
    Print("ZMQ Server stopped");
}

//+------------------------------------------------------------------+
void OnTick()
{
    // Get current tick data
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick))
        return;
    
    datetime currentTime = TimeCurrent();
    
    // Check M5 candle
    datetime m5Time = currentTime - (currentTime % 300); // Round to 5-min
    if(m5Time != lastM5Time)
    {
        SendCandleData("M5", m5Time);
        lastM5Time = m5Time;
    }
    
    // Check M15 candle
    datetime m15Time = currentTime - (currentTime % 900); // Round to 15-min
    if(m15Time != lastM15Time)
    {
        SendCandleData("M15", m15Time);
        lastM15Time = m15Time;
    }
    
    // Send current forming candle data every tick
    SendCurrentTick(tick);
}

//+------------------------------------------------------------------+
void SendCandleData(string timeframe, datetime candleTime)
{
    ENUM_TIMEFRAMES tf = (timeframe == "M5") ? PERIOD_M5 : PERIOD_M15;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    if(CopyRates(_Symbol, tf, 0, 2, rates) < 2)
        return;
    
    // Current forming candle (index 0)
    string msg = StringFormat("CANDLE|%s|%d|%.5f|%.5f|%.5f|%.5f|%d",
        timeframe,
        (int)rates[0].time,
        rates[0].open,
        rates[0].high,
        rates[0].low,
        rates[0].close,
        rates[0].tick_volume
    );
    
    // Previous completed candle (index 1)
    msg += StringFormat("|PREV|%.5f|%.5f|%.5f|%.5f",
        rates[1].open,
        rates[1].high,
        rates[1].low,
        rates[1].close
    );
    
    ZmqMsg zmqMsg(msg);
    publisher.send(zmqMsg);
}

//+------------------------------------------------------------------+
void SendCurrentTick(MqlTick &tick)
{
    string msg = StringFormat("TICK|%.5f|%.5f|%d",
        tick.bid,
        tick.ask,
        (int)tick.time
    );
    
    ZmqMsg zmqMsg(msg);
    publisher.send(zmqMsg);
}
//+------------------------------------------------------------------+
EAEOF

    echo -e "${GREEN}✓ ZeroMQ EA created${NC}"
}

install_bot() {
    print_banner
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║ 🚀 INSTALLING MT5 ZEROMQ BOT                            ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get config
    echo -e "${CYAN}[1/4]${NC} Discord Configuration"
    echo -n "Discord Webhook URL: "
    read -r discord_webhook
    
    while [ -z "$discord_webhook" ]; do
        echo -e "${RED}✗ Webhook required${NC}"
        echo -n "Discord Webhook URL: "
        read -r discord_webhook
    done
    
    echo ""
    echo -e "${CYAN}[2/4]${NC} MT5 Account (FBS Demo recommended)"
    echo -n "MT5 Login: "
    read -r mt5_login
    echo -n "MT5 Password: "
    read -rs mt5_password
    echo ""
    echo -n "MT5 Server [FBS-Demo]: "
    read -r mt5_server
    mt5_server=${mt5_server:-FBS-Demo}
    
    echo ""
    echo -e "${CYAN}[3/4]${NC} Momentum Settings"
    echo -n "M5 Body minimum (pips) [40]: "
    read -r m5_pips
    m5_pips=${m5_pips:-40}
    
    echo -n "M15 Body minimum (pips) [50]: "
    read -r m15_pips
    m15_pips=${m15_pips:-50}
    
    echo ""
    echo -e "${CYAN}[4/4]${NC} Configuration Summary"
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "Data Source    : MT5 ZeroMQ (Real-time)"
    echo -e "Symbol         : XAUUSD"
    echo -e "Timeframes     : M5, M15"
    echo -e "M5 Body Min    : $m5_pips pips"
    echo -e "M15 Body Min   : $m15_pips pips"
    echo -e "Wick Filter    : 30% max"
    echo -e "Alert Window   : 20-90s before close"
    echo -e "MT5 Server     : $mt5_server"
    echo -e "${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
    echo -n "Proceed? (y/N): "
    read -r proceed
    
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return
    fi
    
    echo ""
    install_dependencies
    create_zmq_ea
    
    echo -e "${BLUE}Creating bot files...${NC}"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$INSTALL_DIR/utils"
    
    # Create .env
    cat > "$INSTALL_DIR/.env" << EOF
DISCORD_WEBHOOK_URL=$discord_webhook
MT5_LOGIN=$mt5_login
MT5_PASSWORD=$mt5_password
MT5_SERVER=$mt5_server
ZMQ_PORT=5555
EOF
    
    # Create config
    cat > "$INSTALL_DIR/config.py" << EOF
SYMBOL = "XAUUSD"
TIMEFRAMES = {"M5": 5, "M15": 15}

MOMENTUM_PIPS_M5 = $m5_pips
MOMENTUM_PIPS_M15 = $m15_pips

PIP_SIZE = 0.1
WICK_FILTER_ENABLED = True
MAX_WICK_PERCENTAGE = 0.30

ALERT_WINDOW_START = 20
ALERT_WINDOW_END = 90
ALERT_COOLDOWN = 60
CHECK_INTERVAL = 0.1

ENABLE_EMBED = True
ENABLE_ERROR_ALERTS = True
ENABLE_DAILY_SUMMARY = True
DAILY_SUMMARY_HOUR = 0

LOG_LEVEL = "INFO"
LOG_TO_FILE = True
LOG_FILE = "logs/bot.log"
ERROR_LOG_FILE = "logs/error.log"

ZMQ_ENDPOINT = "tcp://localhost:5555"
EOF
    
    create_bot_files
    create_systemd_service
    
    chmod 600 "$INSTALL_DIR/.env"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ ✅ INSTALLATION COMPLETE!                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT - MANUAL STEPS REQUIRED:${NC}"
    echo ""
    echo -e "${BOLD}1. Start MT5 Terminal:${NC}"
    echo "   xvfb-run wine \"$MT5_DIR/terminal64.exe\" &"
    echo ""
    echo -e "${BOLD}2. In MT5:${NC}"
    echo "   - Login with your credentials"
    echo "   - Tools → Options → Expert Advisors"
    echo "   - Enable: Allow DLL imports"
    echo "   - Enable: Allow WebRequest"
    echo "   - Open XAUUSD chart (M5 or M15)"
    echo "   - Drag 'XAUUSD_ZMQ_Server' EA to chart"
    echo "   - Click 'OK' on EA settings"
    echo ""
    echo -e "${BOLD}3. Start Bot:${NC}"
    echo "   systemctl start xauusd-bot"
    echo ""
    echo -n "Press Enter when MT5 EA is running..."
    read -r
    
    systemctl daemon-reload
    systemctl enable xauusd-bot
    
    echo ""
    echo -e "${GREEN}✓ Bot service enabled${NC}"
    echo "Start with: systemctl start xauusd-bot"
    echo ""
}

create_bot_files() {
    # Main bot
    cat > "$INSTALL_DIR/bot.py" << 'BOTEOF'
#!/usr/bin/env python3
"""
XAUUSD Momentum Bot - MT5 ZeroMQ Version
100% Real-time, 100% Sekolah Trading Logic
"""

import zmq
import time
import logging
from datetime import datetime, timezone
from dotenv import load_dotenv
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'utils'))

import config
from discord_handler import send_alert, send_error_alert, send_daily_summary
from stats import StatsTracker

load_dotenv()

os.makedirs(os.path.dirname(config.LOG_FILE), exist_ok=True)
os.makedirs(os.path.dirname(config.ERROR_LOG_FILE), exist_ok=True)

logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL),
    format='[%(asctime)s] %(levelname)s: %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(config.LOG_FILE)
    ]
)

logger = logging.getLogger(__name__)
error_logger = logging.getLogger('error')
error_handler = logging.FileHandler(config.ERROR_LOG_FILE)
error_handler.setLevel(logging.ERROR)
error_logger.addHandler(error_handler)

last_alert_time = {}
stats = StatsTracker()

# Candle storage
candles = {
    "M5": {"current": None, "previous": None, "start_time": None},
    "M15": {"current": None, "previous": None, "start_time": None}
}


def calculate_body_pips(candle):
    """Body = abs(close - open) in pips"""
    body = abs(candle['close'] - candle['open'])
    return round(body / config.PIP_SIZE, 1)


def calculate_wick_percentage(candle):
    """Wick filter: totalWick / (body + totalWick) <= 0.3"""
    upper_wick = candle['high'] - max(candle['open'], candle['close'])
    lower_wick = min(candle['open'], candle['close']) - candle['low']
    total_wick = upper_wick + lower_wick
    
    body = abs(candle['close'] - candle['open'])
    total_range = body + total_wick
    
    if total_range == 0:
        return 1.0
    
    return total_wick / total_range


def check_bearish_condition(current, previous):
    """Bearish: close < open OR (close > open AND close < open[1])"""
    is_red = current['close'] < current['open']
    is_engulfing = (current['close'] > current['open'] and 
                    current['close'] < previous['open'])
    return is_red or is_engulfing


def get_time_until_close(timeframe_str):
    """Seconds until current candle closes"""
    now = datetime.now(timezone.utc)
    current_second = int(now.timestamp())
    
    tf_seconds = config.TIMEFRAMES[timeframe_str] * 60
    candle_start = (current_second // tf_seconds) * tf_seconds
    candle_close = candle_start + tf_seconds
    
    return candle_close - current_second


def check_momentum(timeframe_str, current_candle, previous_candle):
    """
    100% SEKOLAH TRADING LOGIC
    
    1. Body = abs(close - open) >= threshold pips
    2. Wick filter: totalWick / (body + totalWick) <= 30%
    3. Bullish: close > open
    4. Bearish: close < open OR (close > open AND close < open[1])
    5. Alert window: 20-90s before close
    6. barstate.isconfirmed = false (forming candle)
    """
    global last_alert_time
    
    if not current_candle or not previous_candle:
        return
    
    momentum_threshold = config.MOMENTUM_PIPS_M5 if timeframe_str == "M5" else config.MOMENTUM_PIPS_M15
    
    # STEP 1: Body check
    body = abs(current_candle['close'] - current_candle['open'])
    body_pips = body / config.PIP_SIZE
    
    if body_pips < momentum_threshold:
        return
    
    # STEP 2: Wick filter
    upper_wick = current_candle['high'] - max(current_candle['open'], current_candle['close'])
    lower_wick = min(current_candle['open'], current_candle['close']) - current_candle['low']
    total_wick = upper_wick + lower_wick
    total_range = body + total_wick
    
    if total_range == 0:
        return
    
    wick_ratio = total_wick / total_range
    
    if config.WICK_FILTER_ENABLED and wick_ratio > config.MAX_WICK_PERCENTAGE:
        logger.debug(f"{timeframe_str}: Body {body_pips:.1f} pips, wick {wick_ratio*100:.1f}% FILTERED")
        return
    
    # STEP 3: Bullish/Bearish
    is_bullish = current_candle['close'] > current_candle['open']
    is_bearish = check_bearish_condition(current_candle, previous_candle)
    
    if not (is_bullish or is_bearish):
        return
    
    # STEP 4: Alert window (20-90s before close)
    seconds_until_close = get_time_until_close(timeframe_str)
    
    if not (config.ALERT_WINDOW_START <= seconds_until_close <= config.ALERT_WINDOW_END):
        return
    
    # STEP 5: Prevent duplicate alerts
    candle_id = f"{timeframe_str}_{current_candle['time']}"
    
    if candle_id in last_alert_time:
        return
    
    # STEP 6: Send alert
    is_engulfing = (is_bearish and current_candle['close'] > current_candle['open'])
    
    alert_data = {
        'symbol': 'XAUUSD',
        'timeframe': timeframe_str,
        'body_pips': round(body_pips, 1),
        'open': current_candle['open'],
        'high': current_candle['high'],
        'low': current_candle['low'],
        'close': current_candle['close'],
        'upper_wick': upper_wick,
        'lower_wick': lower_wick,
        'wick_pct': round(wick_ratio * 100, 1),
        'is_bullish': is_bullish,
        'is_bearish': is_bearish,
        'is_engulfing': is_engulfing,
        'prev_open': previous_candle['open'],
        'time': datetime.now(timezone.utc),
        'seconds_until_close': seconds_until_close
    }
    
    direction = "BULLISH" if is_bullish else "BEARISH"
    engulfing_flag = " [ENGULFING]" if is_engulfing else ""
    
    logger.info(f"🚨 {timeframe_str} MOMENTUM {direction}{engulfing_flag}: "
                f"{body_pips:.1f} pips | "
                f"Wick:{wick_ratio*100:.1f}% | "
                f"Close in {seconds_until_close}s")
    
    if send_alert(alert_data):
        last_alert_time[candle_id] = time.time()
        stats.add_alert(timeframe_str, body_pips, is_bullish)


def process_candle_message(parts):
    """Process CANDLE message from MT5 ZeroMQ"""
    try:
        # Format: CANDLE|M5|time|open|high|low|close|volume|PREV|prev_open|prev_high|prev_low|prev_close
        timeframe = parts[1]
        
        if timeframe not in candles:
            return
        
        current = {
            'time': int(parts[2]),
            'open': float(parts[3]),
            'high': float(parts[4]),
            'low': float(parts[5]),
            'close': float(parts[6])
        }
        
        previous = {
            'open': float(parts[8]),
            'high': float(parts[9]),
            'low': float(parts[10]),
            'close': float(parts[11])
        }
        
        candles[timeframe]['current'] = current
        candles[timeframe]['previous'] = previous
        
        # Check momentum on forming candle
        check_momentum(timeframe, current, previous)
        
    except Exception as e:
        logger.error(f"Error processing candle: {e}")


def main():
    """Main ZeroMQ subscriber loop"""
    logger.info("=" * 70)
    logger.info("XAUUSD Momentum Bot (MT5 ZeroMQ)")
    logger.info("TRUE REAL-TIME - Sekolah Trading Logic")
    logger.info("=" * 70)
    
    # Setup ZeroMQ
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect(config.ZMQ_ENDPOINT)
    socket.setsockopt_string(zmq.SUBSCRIBE, "")
    
    logger.info(f"✓ Connected to ZeroMQ: {config.ZMQ_ENDPOINT}")
    logger.info(f"Symbol: XAUUSD")
    logger.info(f"Timeframes: M5, M15")
    logger.info(f"M5: {config.MOMENTUM_PIPS_M5} pips, M15: {config.MOMENTUM_PIPS_M15} pips")
    logger.info(f"Wick Filter: {config.MAX_WICK_PERCENTAGE*100}% max")
    logger.info(f"Alert Window: {config.ALERT_WINDOW_START}-{config.ALERT_WINDOW_END}s")
    logger.info("=" * 70)
    logger.info("Waiting for MT5 data...")
    
    try:
        while True:
            try:
                # Receive message
                message = socket.recv_string(flags=zmq.NOBLOCK)
                parts = message.split("|")
                
                if parts[0] == "CANDLE":
                    process_candle_message(parts)
                    
            except zmq.Again:
                time.sleep(0.01)
            except Exception as e:
                logger.error(f"Message error: {e}")
                time.sleep(0.1)
                
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        if config.ENABLE_ERROR_ALERTS:
            send_error_alert("Fatal Error", str(e))
    finally:
        socket.close()
        context.term()
        logger.info("Bot shut down")


if __name__ == "__main__":
    main()
BOTEOF

    # Discord handler (same as before)
    cat > "$INSTALL_DIR/utils/discord_handler.py" << 'DISCORDEOF'
import requests
import logging
import os
from datetime import datetime

logger = logging.getLogger(__name__)
WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL")

def send_alert(data):
    if not WEBHOOK_URL:
        return False
    try:
        direction = "🟢 BULLISH" if data['is_bullish'] else "🔴 BEARISH"
        color = 65280 if data['is_bullish'] else 16711680
        
        engulfing_note = ""
        if data['is_engulfing']:
            engulfing_note = f"\n⚠️ Bearish Engulfing: Close ({data['close']:.2f}) < Prev Open ({data['prev_open']:.2f})"
        
        embed = {
            "title": "🚨 MOMENTUM DETECTED! (REAL-TIME)",
            "color": color,
            "fields": [
                {"name": "Pair", "value": data['symbol'], "inline": True},
                {"name": "Timeframe", "value": data['timeframe'], "inline": True},
                {"name": "Type", "value": direction, "inline": True},
                {"name": "━━━━━━━━━━━━━━━━━━━━━━━", "value": ""},
                {"name": "Body", "value": f"**{data['body_pips']} pips**", "inline": True},
                {"name": "Open", "value": f"{data['open']:.2f}", "inline": True},
                {"name": "Close", "value": f"{data['close']:.2f}", "inline": True},
                {"name": "High", "value": f"{data['high']:.2f}", "inline": True},
                {"name": "Low", "value": f"{data['low']:.2f}", "inline": True},
                {"name": "Wick %", "value": f"{data['wick_pct']:.1f}% ✓", "inline": True},
            ],
            "description": f"**Time:** {data['time'].strftime('%H:%M:%S')} UTC\n**Closes in:** {data['seconds_until_close']}s{engulfing_note}",
            "footer": {"text": "MT5 Real-time | Sekolah Trading"},
            "timestamp": data['time'].isoformat()
        }
        
        response = requests.post(WEBHOOK_URL, json={"username": "XAUUSD Bot", "embeds": [embed]}, timeout=10)
        return response.status_code == 204
    except:
        return False

def send_error_alert(title, message, is_recovery=False):
    if not WEBHOOK_URL:
        return False
    try:
        color = 65280 if is_recovery else 16711680
        icon = "✅" if is_recovery else "🔴"
        embed = {
            "title": f"{icon} {title}",
            "description": message,
            "color": color,
            "timestamp": datetime.utcnow().isoformat()
        }
        response = requests.post(WEBHOOK_URL, json={"username": "XAUUSD Bot", "embeds": [embed]}, timeout=10)
        return response.status_code == 204
    except:
        return False

def send_daily_summary(summary):
    if not WEBHOOK_URL:
        return False
    try:
        fields = [
            {"name": "Total", "value": str(summary['total_alerts']), "inline": True},
            {"name": "🟢 Bull", "value": f"{summary['bullish']}", "inline": True},
            {"name": "🔴 Bear", "value": f"{summary['bearish']}", "inline": True},
            {"name": "Avg Pips", "value": f"{summary['avg_pips']:.1f}", "inline": True},
        ]
        embed = {
            "title": f"📊 DAILY SUMMARY - {summary['date']}",
            "color": 3447003,
            "fields": fields,
            "timestamp": datetime.utcnow().isoformat()
        }
        response = requests.post(WEBHOOK_URL, json={"username": "XAUUSD Bot", "embeds": [embed]}, timeout=10)
        return response.status_code == 204
    except:
        return False
DISCORDEOF

    # Stats tracker
    cat > "$INSTALL_DIR/utils/stats.py" << 'STATSEOF'
from datetime import datetime, timezone

class StatsTracker:
    def __init__(self):
        self.reset_daily()
    
    def reset_daily(self):
        self.alerts = []
        self.last_reset = datetime.now(timezone.utc).date()
    
    def add_alert(self, timeframe, pips, is_bullish):
        self.alerts.append({
            'timeframe': timeframe,
            'pips': pips,
            'is_bullish': is_bullish,
            'timestamp': datetime.now(timezone.utc)
        })
    
    def get_daily_summary(self):
        if not self.alerts:
            return None
        
        total = len(self.alerts)
        bull = len([a for a in self.alerts if a['is_bullish']])
        bear = total - bull
        pips = [a['pips'] for a in self.alerts]
        
        return {
            'date': self.last_reset.strftime('%Y-%m-%d'),
            'total_alerts': total,
            'bullish': bull,
            'bearish': bear,
            'avg_pips': sum(pips) / len(pips) if pips else 0,
            'max_pips': max(pips) if pips else 0
        }
STATSEOF

    touch "$INSTALL_DIR/utils/__init__.py"
}

create_systemd_service() {
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=XAUUSD Momentum Bot (MT5 ZeroMQ)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PYTHONUNBUFFERED=1"
ExecStart=/usr/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

main() {
    check_root
    print_banner
    install_bot
}

main
