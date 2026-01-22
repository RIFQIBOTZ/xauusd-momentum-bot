#!/bin/bash

#############################################
# XAUUSD Momentum Bot - Linux Installer
# Version: 1.0.2 (Twelve Data API)
# Data Source: Twelve Data API
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

INSTALL_DIR="/opt/xauusd-bot"
SERVICE_FILE="/etc/systemd/system/xauusd-bot.service"
LOG_DIR="$INSTALL_DIR/logs"
BACKUP_DIR="$INSTALL_DIR/backups"

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
    echo "║        🤖 XAUUSD MOMENTUM BOT - CONTROL PANEL 🤖         ║"
    echo "║                   Version 1.0.2                           ║"
    echo "║              Based on Sekolah Trading Logic               ║"
    echo "║              Data: Twelve Data API (Real-time)            ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

get_bot_status() {
    if systemctl is-active --quiet xauusd-bot 2>/dev/null; then
        echo -e "${GREEN}● Running${NC}"
    else
        echo -e "${RED}○ Stopped${NC}"
    fi
}

get_uptime() {
    if systemctl is-active --quiet xauusd-bot 2>/dev/null; then
        uptime=$(systemctl show xauusd-bot --property=ActiveEnterTimestamp --value)
        if [ -n "$uptime" ]; then
            start_time=$(date -d "$uptime" +%s)
            current_time=$(date +%s)
            diff=$((current_time - start_time))
            hours=$((diff / 3600))
            minutes=$(((diff % 3600) / 60))
            echo "${hours}h ${minutes}m"
        else
            echo "N/A"
        fi
    else
        echo "Not running"
    fi
}

show_main_menu() {
    print_banner
    
    echo -e "${BOLD}┌───────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│ SYSTEM STATUS                                             │${NC}"
    echo -e "${BOLD}├───────────────────────────────────────────────────────────┤${NC}"
    echo -e "│ Bot Service    : $(get_bot_status) (Uptime: $(get_uptime))              "
    
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo -e "│ Discord Webhook: ${GREEN}✓ Configured${NC}                                 "
        echo -e "│ Twelve Data API: ${GREEN}✓ Configured${NC}                                 "
    else
        echo -e "│ Discord Webhook: ${RED}✗ Not configured${NC}                           "
        echo -e "│ Twelve Data API: ${RED}✗ Not configured${NC}                           "
    fi
    
    echo -e "${BOLD}└───────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    if [ -f "$INSTALL_DIR/config.py" ]; then
        echo -e "${BOLD}┌───────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BOLD}│ CURRENT SETTINGS                                          │${NC}"
        echo -e "${BOLD}├───────────────────────────────────────────────────────────┤${NC}"
        echo -e "│ Symbol         : XAUUSD                                   │"
        echo -e "│ Timeframes     : M5, M15                                  │"
        
        m5_pips=$(grep "MOMENTUM_PIPS_M5" "$INSTALL_DIR/config.py" | grep -o '[0-9]*' | head -1)
        m15_pips=$(grep "MOMENTUM_PIPS_M15" "$INSTALL_DIR/config.py" | grep -o '[0-9]*' | head -1)
        
        echo -e "│ M5 Body Min    : ${m5_pips:-40} pips                                   │"
        echo -e "│ M15 Body Min   : ${m15_pips:-50} pips                                   │"
        echo -e "│ Wick Filter    : 30% max (Sekolah Trading)                │"
        echo -e "│ Data Source    : Twelve Data API                          │"
        echo -e "${BOLD}└───────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ MAIN MENU                                                 ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}║  ${BOLD}[1]${NC} ${GREEN}🚀 Install/Reinstall Bot${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[2]${NC} ${GREEN}▶️  Start Bot${NC}                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[3]${NC} ${YELLOW}⏸️  Stop Bot${NC}                                         ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[4]${NC} ${BLUE}🔄 Restart Bot${NC}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[5]${NC} ${PURPLE}📊 View Live Logs${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[6]${NC} ${PURPLE}📈 Bot Statistics${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[7]${NC} ${BLUE}⚙️  Settings & Configuration${NC}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[8]${NC} ${GREEN}🔔 Test Discord Alert${NC}                                ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[9]${NC} ${RED}🗑️  Uninstall Bot${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[0]${NC} 🚪 Exit                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -n -e "${BOLD}Enter your choice [0-9]: ${NC}"
}

show_progress() {
    local current=$1
    local total=$2
    local message=$3
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%% - %s" "$percent" "$message"
}

install_dependencies() {
    echo -e "\n${BLUE}[1/4]${NC} Updating system..."
    apt update > /dev/null 2>&1
    show_progress 1 4 "System updated"
    
    echo -e "\n${BLUE}[2/4]${NC} Installing Python..."
    apt install -y python3 python3-pip > /dev/null 2>&1
    show_progress 2 4 "Python installed"
    
    echo -e "\n${BLUE}[3/4]${NC} Upgrading pip..."
    python3 -m pip install --upgrade pip > /dev/null 2>&1
    show_progress 3 4 "Pip upgraded"
    
    echo -e "\n${BLUE}[4/4]${NC} Installing Python packages..."
    pip3 install --break-system-packages requests python-dotenv pytz > /dev/null 2>&1
    show_progress 4 4 "Complete!"
    
    echo -e "\n"
}

install_bot() {
    print_banner
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║ 🚀 INSTALLING XAUUSD MOMENTUM BOT                        ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}⚠️  Bot is already installed!${NC}"
        echo ""
        echo -n "Reinstall? This will backup current config (y/N): "
        read -r reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        
        if [ -f "$INSTALL_DIR/.env" ]; then
            backup_file="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
            mkdir -p "$BACKUP_DIR"
            tar -czf "$backup_file" -C "$INSTALL_DIR" .env config.py 2>/dev/null || true
            echo -e "${GREEN}✓${NC} Backup created: $backup_file"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  CONFIGURATION${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Discord webhook
    echo -e "${CYAN}[1/3]${NC} Discord Webhook URL"
    echo -n "Enter webhook URL: "
    read -r discord_webhook
    
    while [ -z "$discord_webhook" ]; do
        echo -e "${RED}✗ Webhook URL cannot be empty!${NC}"
        echo -n "Enter webhook URL: "
        read -r discord_webhook
    done
    
    # Twelve Data API
    echo ""
    echo -e "${CYAN}[2/3]${NC} Twelve Data API Configuration"
    echo ""
    echo -e "${YELLOW}Get FREE Twelve Data API key:${NC}"
    echo "1. Go to: https://twelvedata.com/register"
    echo "2. Register FREE account (Basic plan)"
    echo "3. Get your API key from dashboard"
    echo "4. Free tier: 8 calls/min, 800/day"
    echo ""
    echo -n "Twelve Data API Key: "
    read -r twelvedata_key
    
    while [ -z "$twelvedata_key" ]; do
        echo -e "${RED}✗ API key cannot be empty!${NC}"
        echo -n "Twelve Data API Key: "
        read -r twelvedata_key
    done
    
    # Momentum settings
    echo ""
    echo -e "${CYAN}[3/3]${NC} Momentum Settings"
    echo -n "M5 Body minimum (pips) [40]: "
    read -r m5_pips
    m5_pips=${m5_pips:-40}
    
    echo -n "M15 Body minimum (pips) [50]: "
    read -r m15_pips
    m15_pips=${m15_pips:-50}
    
    # Confirmation
    echo ""
    echo -e "${CYAN}Configuration Summary${NC}"
    echo -e "${BOLD}════════════════════════════════════════════${NC}"
    echo -e "Data Source    : Twelve Data API (Free tier)"
    echo -e "Symbol         : XAU/USD"
    echo -e "Timeframes     : M5, M15"
    echo -e "M5 Body Min    : $m5_pips pips"
    echo -e "M15 Body Min   : $m15_pips pips"
    echo -e "Wick Filter    : 30% max"
    echo -e "Check Interval : 30 seconds (rate limit safe)"
    echo -e "Discord        : Configured"
    echo -e "${BOLD}════════════════════════════════════════════${NC}"
    echo ""
    echo -n "Proceed with installation? (y/N): "
    read -r proceed
    
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        return
    fi
    
    echo ""
    echo -e "${BOLD}Installing...${NC}"
    echo ""
    
    install_dependencies
    
    echo -e "${BLUE}Creating directories...${NC}"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$INSTALL_DIR/utils"
    
    # Create .env
    cat > "$INSTALL_DIR/.env" << EOF
# Discord Configuration
DISCORD_WEBHOOK_URL=$discord_webhook

# Twelve Data API Configuration
TWELVEDATA_API_KEY=$twelvedata_key
EOF
    
    # Create config.py
    cat > "$INSTALL_DIR/config.py" << 'EOF'
"""
Configuration for XAUUSD Momentum Bot
Based on Sekolah Trading Logic
Data Source: Twelve Data API
"""

# Symbol Settings
SYMBOL = "XAU/USD"  # Twelve Data format
TIMEFRAMES = {
    "M5": "5min",
    "M15": "15min"
}

# Momentum Settings
MOMENTUM_PIPS_M5 = M5_PLACEHOLDER
MOMENTUM_PIPS_M15 = M15_PLACEHOLDER

# Pip size
PIP_SIZE = 0.1

# Wick Filter
WICK_FILTER_ENABLED = True
MAX_WICK_PERCENTAGE = 0.30

# Alert Window
ALERT_WINDOW_START = 20
ALERT_WINDOW_END = 90

# Alert Cooldown
ALERT_COOLDOWN = 60

# Check Interval (30s = 4 calls/min, safe for free tier 8/min)
CHECK_INTERVAL = 30

# Discord
ENABLE_EMBED = True
ENABLE_ERROR_ALERTS = True
ENABLE_DAILY_SUMMARY = True
DAILY_SUMMARY_HOUR = 0

# Logging
LOG_LEVEL = "INFO"
LOG_TO_FILE = True
LOG_FILE = "logs/bot.log"
ERROR_LOG_FILE = "logs/error.log"

# Twelve Data API
TWELVEDATA_API_URL = "https://api.twelvedata.com"
EOF
    
    sed -i "s/M5_PLACEHOLDER/$m5_pips/" "$INSTALL_DIR/config.py"
    sed -i "s/M15_PLACEHOLDER/$m15_pips/" "$INSTALL_DIR/config.py"
    
    create_bot_files
    create_systemd_service
    
    chmod +x "$INSTALL_DIR"/*.py 2>/dev/null || true
    chmod 600 "$INSTALL_DIR/.env"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ ✅ INSTALLATION COMPLETE!                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    systemctl daemon-reload
    systemctl enable xauusd-bot > /dev/null 2>&1
    systemctl start xauusd-bot
    
    sleep 3
    test_discord_webhook
    
    echo ""
    echo -e "${GREEN}✓ Bot is now running!${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

create_bot_files() {
    echo -e "${BLUE}Creating bot files...${NC}"
    
    # Main bot
    cat > "$INSTALL_DIR/bot.py" << 'BOTEOF'
#!/usr/bin/env python3
"""
XAUUSD Momentum Bot - Twelve Data API Version
Data Source: Twelve Data API
"""

import requests
import time
import logging
from datetime import datetime, timezone, timedelta
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

TWELVEDATA_KEY = os.getenv("TWELVEDATA_API_KEY")
TWELVEDATA_URL = config.TWELVEDATA_API_URL


def get_candles(timeframe_str):
    """Get candles from Twelve Data API"""
    try:
        interval = config.TIMEFRAMES[timeframe_str]
        
        url = f"{TWELVEDATA_URL}/time_series"
        params = {
            "symbol": config.SYMBOL,
            "interval": interval,
            "outputsize": 2,
            "apikey": TWELVEDATA_KEY
        }
        
        response = requests.get(url, params=params, timeout=10)
        
        if response.status_code != 200:
            logger.error(f"Twelve Data API error: {response.status_code}")
            return None
        
        data = response.json()
        
        # Check for error in response
        if data.get('status') == 'error':
            logger.error(f"API error: {data.get('message', 'Unknown error')}")
            return None
        
        values = data.get('values', [])
        
        if len(values) < 2:
            return None
        
        # Convert to our format (Twelve Data returns newest first)
        result = []
        for v in reversed(values):  # Reverse to get oldest first
            try:
                result.append({
                    'time': datetime.fromisoformat(v['datetime'].replace(' ', 'T')).timestamp(),
                    'open': float(v['open']),
                    'high': float(v['high']),
                    'low': float(v['low']),
                    'close': float(v['close']),
                    'complete': True  # Twelve Data returns completed candles
                })
            except (KeyError, ValueError) as e:
                logger.error(f"Error parsing candle data: {e}")
                continue
        
        return result if len(result) >= 2 else None
        
    except Exception as e:
        logger.error(f"Error getting candles: {e}")
        return None


def calculate_body_pips(candle):
    """Calculate body in pips"""
    body = abs(candle['close'] - candle['open'])
    pips = body / config.PIP_SIZE
    return round(pips, 1)


def calculate_wick_percentage(candle):
    """Calculate wick percentage"""
    upper_wick = candle['high'] - max(candle['open'], candle['close'])
    lower_wick = min(candle['open'], candle['close']) - candle['low']
    total_wick = upper_wick + lower_wick
    
    body = abs(candle['close'] - candle['open'])
    total_range = body + total_wick
    
    if total_range == 0:
        return 100.0
    
    return (total_wick / total_range)


def check_bearish_condition(current, previous):
    """Check bearish condition"""
    is_red = current['close'] < current['open']
    is_engulfing = (current['close'] > current['open'] and 
                    current['close'] < previous['open'])
    return is_red or is_engulfing


def get_time_until_close(timeframe_str):
    """Get seconds until candle close"""
    now = datetime.now(timezone.utc)
    current_minute = now.minute
    current_second = now.second
    
    # Map timeframe to minutes
    timeframe_minutes = 5 if timeframe_str == "M5" else 15
    
    minutes_into_candle = current_minute % timeframe_minutes
    seconds_until_close = ((timeframe_minutes - minutes_into_candle) * 60) - current_second
    
    return seconds_until_close


def check_momentum(timeframe_str):
    """Check momentum"""
    global last_alert_time
    
    momentum_threshold = config.MOMENTUM_PIPS_M5 if timeframe_str == "M5" else config.MOMENTUM_PIPS_M15
    
    candles = get_candles(timeframe_str)
    if not candles or len(candles) < 2:
        return
    
    current_candle = candles[-1]
    previous_candle = candles[-2]
    
    body_pips = calculate_body_pips(current_candle)
    
    if body_pips < momentum_threshold:
        return
    
    wick_pct = calculate_wick_percentage(current_candle)
    
    if config.WICK_FILTER_ENABLED and wick_pct > config.MAX_WICK_PERCENTAGE:
        logger.debug(f"{timeframe_str}: Body {body_pips} OK, wick {wick_pct*100:.1f}% filtered")
        return
    
    seconds_until_close = get_time_until_close(timeframe_str)
    
    if not (config.ALERT_WINDOW_START <= seconds_until_close <= config.ALERT_WINDOW_END):
        return
    
    is_bullish = current_candle['close'] > current_candle['open']
    is_bearish = check_bearish_condition(current_candle, previous_candle)
    
    if not (is_bullish or is_bearish):
        return
    
    cooldown_key = f"{timeframe_str}_{int(current_candle['time'])}"
    current_time = time.time()
    
    if cooldown_key in last_alert_time:
        if current_time - last_alert_time[cooldown_key] < config.ALERT_COOLDOWN:
            return
    
    alert_data = {
        'symbol': 'XAUUSD',
        'timeframe': timeframe_str,
        'body_pips': body_pips,
        'open': current_candle['open'],
        'high': current_candle['high'],
        'low': current_candle['low'],
        'close': current_candle['close'],
        'upper_wick': current_candle['high'] - max(current_candle['open'], current_candle['close']),
        'lower_wick': min(current_candle['open'], current_candle['close']) - current_candle['low'],
        'wick_pct': wick_pct * 100,
        'is_bullish': is_bullish,
        'is_bearish': is_bearish,
        'is_engulfing': (is_bearish and current_candle['close'] > current_candle['open']),
        'prev_open': previous_candle['open'],
        'time': datetime.fromtimestamp(current_candle['time'], tz=timezone.utc),
        'seconds_until_close': seconds_until_close
    }
    
    logger.info(f"🚨 {timeframe_str}: MOMENTUM! {body_pips} pips ({'BULL' if is_bullish else 'BEAR'})")
    
    if send_alert(alert_data):
        last_alert_time[cooldown_key] = current_time
        stats.add_alert(timeframe_str, body_pips, is_bullish)


def check_daily_summary():
    """Check and send daily summary"""
    now = datetime.now(timezone.utc)
    if now.hour == config.DAILY_SUMMARY_HOUR and now.minute == 0:
        summary = stats.get_daily_summary()
        if summary:
            send_daily_summary(summary)
            stats.reset_daily()


def main():
    """Main loop"""
    logger.info("=" * 60)
    logger.info("XAUUSD Momentum Bot Starting")
    logger.info("Data Source: Twelve Data API")
    logger.info("=" * 60)
    
    if not TWELVEDATA_KEY:
        logger.error("Twelve Data API key not configured!")
        if config.ENABLE_ERROR_ALERTS:
            send_error_alert("Config Error", "Twelve Data API key missing")
        return
    
    # Test connection
    try:
        test_candles = get_candles("M5")
        if not test_candles:
            logger.error("Failed to connect to Twelve Data API")
            if config.ENABLE_ERROR_ALERTS:
                send_error_alert("API Error", "Failed to fetch data from Twelve Data")
            return
        logger.info("✓ Twelve Data API connected")
    except Exception as e:
        logger.error(f"API connection error: {e}")
        return
    
    logger.info(f"Symbol: XAU/USD")
    logger.info(f"Timeframes: M5 (5min), M15 (15min)")
    logger.info(f"M5: {config.MOMENTUM_PIPS_M5} pips, M15: {config.MOMENTUM_PIPS_M15} pips")
    logger.info(f"Wick Filter: {config.MAX_WICK_PERCENTAGE*100}% max")
    logger.info(f"Check Interval: {config.CHECK_INTERVAL}s")
    logger.info("=" * 60)
    
    consecutive_errors = 0
    max_errors = 5
    
    try:
        while True:
            try:
                for tf in config.TIMEFRAMES.keys():
                    check_momentum(tf)
                
                if config.ENABLE_DAILY_SUMMARY:
                    check_daily_summary()
                
                consecutive_errors = 0
                time.sleep(config.CHECK_INTERVAL)
                
            except Exception as e:
                error_logger.error(f"Loop error: {e}", exc_info=True)
                consecutive_errors += 1
                
                if consecutive_errors >= max_errors:
                    logger.error("Too many errors. Exiting...")
                    if config.ENABLE_ERROR_ALERTS:
                        send_error_alert("Bot Error", f"Too many errors: {str(e)}")
                    break
                
                time.sleep(10)
                
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        if config.ENABLE_ERROR_ALERTS:
            send_error_alert("Fatal Error", str(e))
    finally:
        logger.info("Bot shut down")


if __name__ == "__main__":
    main()
BOTEOF

    # Discord handler
    cat > "$INSTALL_DIR/utils/discord_handler.py" << 'DISCORDEOF'
"""Discord webhook handler"""
import requests
import logging
import os
from datetime import datetime

logger = logging.getLogger(__name__)
WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL")

def send_alert(data):
    """Send alert"""
    if not WEBHOOK_URL:
        return False
    
    try:
        direction = "🟢 BULLISH" if data['is_bullish'] else "🔴 BEARISH"
        color = 65280 if data['is_bullish'] else 16711680
        
        engulfing_note = ""
        if data['is_engulfing']:
            engulfing_note = f"\n⚠️ Close ({data['close']:.2f}) < Prev Open ({data['prev_open']:.2f})"
        
        embed = {
            "title": "🚨 MOMENTUM DETECTED!",
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
                {"name": "", "value": "", "inline": True},
                {"name": "Wick %", "value": f"{data['wick_pct']:.1f}% ✓", "inline": True},
            ],
            "description": f"**Time:** {data['time'].strftime('%Y-%m-%d %H:%M:%S')} UTC\n**Closes in:** {data['seconds_until_close']}s{engulfing_note}",
            "footer": {"text": "XAUUSD Bot - Twelve Data API"},
            "timestamp": data['time'].isoformat()
        }
        
        response = requests.post(WEBHOOK_URL, json={"username": "XAUUSD Bot", "embeds": [embed]}, timeout=10)
        return response.status_code == 204
    except:
        return False

def send_error_alert(title, message, is_recovery=False):
    """Send error alert"""
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
    """Send daily summary"""
    if not WEBHOOK_URL:
        return False
    try:
        fields = [
            {"name": "Total", "value": str(summary['total_alerts']), "inline": True},
            {"name": "M5", "value": str(summary['m5_alerts']), "inline": True},
            {"name": "M15", "value": str(summary['m15_alerts']), "inline": True},
            {"name": "🟢 Bull", "value": f"{summary['bullish']} ({summary['bullish_pct']:.1f}%)", "inline": True},
            {"name": "🔴 Bear", "value": f"{summary['bearish']} ({summary['bearish_pct']:.1f}%)", "inline": True},
            {"name": "Avg", "value": f"{summary['avg_pips']:.1f} pips", "inline": True},
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

def send_test_alert():
    """Test alert"""
    if not WEBHOOK_URL:
        return False
    try:
        embed = {
            "title": "✅ TEST ALERT",
            "description": "Bot installation successful!\n\nTwelve Data API connected and ready.",
            "color": 65280,
            "fields": [
                {"name": "Data Source", "value": "Twelve Data API", "inline": True},
                {"name": "Status", "value": "● Running", "inline": True}
            ],
            "timestamp": datetime.utcnow().isoformat()
        }
        response = requests.post(WEBHOOK_URL, json={"username": "XAUUSD Bot", "embeds": [embed]}, timeout=10)
        return response.status_code == 204
    except:
        return False
DISCORDEOF

    # Stats
    cat > "$INSTALL_DIR/utils/stats.py" << 'STATSEOF'
"""Statistics tracker"""
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
        m5 = len([a for a in self.alerts if a['timeframe'] == 'M5'])
        m15 = len([a for a in self.alerts if a['timeframe'] == 'M15'])
        bull = len([a for a in self.alerts if a['is_bullish']])
        bear = total - bull
        pips = [a['pips'] for a in self.alerts]
        
        return {
            'date': self.last_reset.strftime('%Y-%m-%d'),
            'total_alerts': total,
            'm5_alerts': m5,
            'm15_alerts': m15,
            'bullish': bull,
            'bearish': bear,
            'bullish_pct': (bull / total * 100) if total else 0,
            'bearish_pct': (bear / total * 100) if total else 0,
            'avg_pips': sum(pips) / len(pips) if pips else 0,
            'max_pips': max(pips) if pips else 0,
            'min_pips': min(pips) if pips else 0
        }
STATSEOF

    touch "$INSTALL_DIR/utils/__init__.py"
    echo -e "${GREEN}✓${NC} Bot files created"
}

create_systemd_service() {
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=XAUUSD Momentum Bot
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
    echo -e "${GREEN}✓${NC} Service created"
}

start_bot() {
    print_banner
    echo -e "${GREEN}Starting bot...${NC}"
    systemctl start xauusd-bot
    sleep 2
    if systemctl is-active --quiet xauusd-bot; then
        echo -e "${GREEN}✓ Bot started${NC}"
    else
        echo -e "${RED}✗ Failed to start${NC}"
    fi
    echo -n "Press Enter..."
    read -r
}

stop_bot() {
    print_banner
    echo -n "Stop bot? (y/N): "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        systemctl stop xauusd-bot
        echo -e "${GREEN}✓ Stopped${NC}"
    fi
    echo -n "Press Enter..."
    read -r
}

restart_bot() {
    print_banner
    systemctl restart xauusd-bot
    echo -e "${GREEN}✓ Restarted${NC}"
    echo -n "Press Enter..."
    read -r
}

view_logs() {
    print_banner
    echo -e "${PURPLE}Live logs (Ctrl+C to exit)...${NC}"
    sleep 2
    journalctl -u xauusd-bot -f
}

show_statistics() {
    print_banner
    echo -e "${BOLD}BOT STATISTICS${NC}"
    echo ""
    if [ -f "$LOG_DIR/bot.log" ]; then
        total=$(grep -c "MOMENTUM" "$LOG_DIR/bot.log" 2>/dev/null || echo "0")
        echo "Total Alerts: $total"
        echo ""
        grep "MOMENTUM" "$LOG_DIR/bot.log" | tail -10
    else
        echo "No stats"
    fi
    echo -n "Press Enter..."
    read -r
}

settings_menu() {
    while true; do
        print_banner
        echo -e "${BOLD}SETTINGS${NC}"
        echo ""
        echo "[1] Change M5 pips"
        echo "[2] Change M15 pips"
        echo "[3] Update webhook"
        echo "[4] Update API key"
        echo "[0] Back"
        echo -n "Choice: "
        read -r choice
        case $choice in
            1)
                echo -n "New M5 pips: "
                read -r new_m5
                sed -i "s/MOMENTUM_PIPS_M5 = [0-9]*/MOMENTUM_PIPS_M5 = $new_m5/" "$INSTALL_DIR/config.py"
                echo "Updated. Restart bot."
                sleep 2
                ;;
            2)
                echo -n "New M15 pips: "
                read -r new_m15
                sed -i "s/MOMENTUM_PIPS_M15 = [0-9]*/MOMENTUM_PIPS_M15 = $new_m15/" "$INSTALL_DIR/config.py"
                echo "Updated. Restart bot."
                sleep 2
                ;;
            3)
                echo -n "New webhook: "
                read -r new_hook
                sed -i "s|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=$new_hook|" "$INSTALL_DIR/.env"
                echo "Updated."
                sleep 2
                ;;
            4)
                echo -n "New Twelve Data API key: "
                read -r new_key
                sed -i "s|TWELVEDATA_API_KEY=.*|TWELVEDATA_API_KEY=$new_key|" "$INSTALL_DIR/.env"
                echo "Updated. Restart bot."
                sleep 2
                ;;
            0) break ;;
        esac
    done
}

test_discord_webhook() {
    python3 << PYEOF
import sys
sys.path.insert(0, '$INSTALL_DIR/utils')
from discord_handler import send_test_alert
if send_test_alert():
    print("✓ Test alert sent!")
else:
    print("✗ Failed")
PYEOF
}

uninstall_bot() {
    print_banner
    echo -e "${RED}UNINSTALL${NC}"
    echo -n "Type UNINSTALL to confirm: "
    read -r confirm
    if [ "$confirm" = "UNINSTALL" ]; then
        systemctl stop xauusd-bot 2>/dev/null || true
        systemctl disable xauusd-bot 2>/dev/null || true
        rm -f "$SERVICE_FILE"
        rm -rf "$INSTALL_DIR"
        systemctl daemon-reload
        echo -e "${GREEN}✓ Uninstalled${NC}"
    fi
    echo -n "Press Enter..."
    read -r
    exit 0
}

main() {
    check_root
    while true; do
        show_main_menu
        read -r choice
        case $choice in
            1) install_bot ;;
            2) start_bot ;;
            3) stop_bot ;;
            4) restart_bot ;;
            5) view_logs ;;
            6) show_statistics ;;
            7) settings_menu ;;
            8) test_discord_webhook; echo ""; echo -n "Press Enter..."; read -r ;;
            9) uninstall_bot ;;
            0) exit 0 ;;
        esac
    done
}

main