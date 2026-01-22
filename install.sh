#!/bin/bash

#############################################
# XAUUSD Momentum Bot - Full Installer
# Version: 1.0.0
# Author: Based on Sekolah Trading Logic
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Paths
INSTALL_DIR="/opt/xauusd-bot"
SERVICE_FILE="/etc/systemd/system/xauusd-bot.service"
LOG_DIR="$INSTALL_DIR/logs"
BACKUP_DIR="$INSTALL_DIR/backups"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

# Print banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║        🤖 XAUUSD MOMENTUM BOT - CONTROL PANEL 🤖         ║"
    echo "║                     Version 1.0.0                         ║"
    echo "║              Based on Sekolah Trading Logic               ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Get bot status
get_bot_status() {
    if systemctl is-active --quiet xauusd-bot 2>/dev/null; then
        echo -e "${GREEN}● Running${NC}"
    else
        echo -e "${RED}○ Stopped${NC}"
    fi
}

# Get MT5 status
get_mt5_status() {
    if pgrep -f "terminal64.exe" > /dev/null; then
        echo -e "${GREEN}● Connected${NC}"
    else
        echo -e "${RED}○ Disconnected${NC}"
    fi
}

# Get last alert
get_last_alert() {
    if [ -f "$LOG_DIR/bot.log" ]; then
        last_alert=$(grep "MOMENTUM DETECTED" "$LOG_DIR/bot.log" | tail -1 | awk '{print $1, $2}')
        if [ -n "$last_alert" ]; then
            echo "$last_alert"
        else
            echo "No alerts yet"
        fi
    else
        echo "No logs"
    fi
}

# Get uptime
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

# Main menu
show_main_menu() {
    print_banner
    
    echo -e "${BOLD}┌───────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│ SYSTEM STATUS                                             │${NC}"
    echo -e "${BOLD}├───────────────────────────────────────────────────────────┤${NC}"
    echo -e "│ Bot Service    : $(get_bot_status) (Uptime: $(get_uptime))              "
    echo -e "│ MT5 Terminal   : $(get_mt5_status)                            "
    
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo -e "│ Discord Webhook: ${GREEN}✓ Configured${NC}                                 "
    else
        echo -e "│ Discord Webhook: ${RED}✗ Not configured${NC}                           "
    fi
    
    echo -e "│ Last Alert     : $(get_last_alert)                "
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
        echo -e "│ Alert Window   : 20-90s before close                      │"
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
    echo -e "${CYAN}║  ${BOLD}[9]${NC} ${BLUE}🔧 Maintenance & Tools${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[10]${NC} ${RED}🗑️  Uninstall Bot${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║  ${BOLD}[0]${NC} 🚪 Exit                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -n -e "${BOLD}Enter your choice [0-10]: ${NC}"
}

# Progress bar
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

# Install dependencies
install_dependencies() {
    echo -e "\n${BLUE}[1/8]${NC} Updating system..."
    apt update > /dev/null 2>&1
    show_progress 1 8 "System updated"
    
    echo -e "\n${BLUE}[2/8]${NC} Enabling 32-bit architecture..."
    dpkg --add-architecture i386 > /dev/null 2>&1
    show_progress 2 8 "32-bit enabled"
    
    echo -e "\n${BLUE}[3/8]${NC} Installing Wine..."
    mkdir -pm755 /etc/apt/keyrings 2>/dev/null || true
    wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
    wget -q -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/focal/winehq-focal.sources
    apt update > /dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt install -y --install-recommends winehq-stable > /dev/null 2>&1
    show_progress 3 8 "Wine installed"
    
    echo -e "\n${BLUE}[4/8]${NC} Installing Xvfb..."
    apt install -y xvfb > /dev/null 2>&1
    show_progress 4 8 "Xvfb installed"
    
    echo -e "\n${BLUE}[5/8]${NC} Installing Python..."
    apt install -y python3 python3-pip > /dev/null 2>&1
    show_progress 5 8 "Python installed"
    
    echo -e "\n${BLUE}[6/8]${NC} Downloading MetaTrader 5..."
    wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O /tmp/mt5setup.exe
    show_progress 6 8 "MT5 downloaded"
    
    echo -e "\n${BLUE}[7/8]${NC} Installing MetaTrader 5..."
    WINEARCH=win64 WINEPREFIX=~/.wine xvfb-run wine /tmp/mt5setup.exe /auto > /dev/null 2>&1 || true
    show_progress 7 8 "MT5 installed"
    
    echo -e "\n${BLUE}[8/8]${NC} Installing Python packages..."
    pip3 install --quiet MetaTrader5 requests python-dotenv pytz > /dev/null 2>&1
    show_progress 8 8 "Complete!"
    
    echo -e "\n"
}

# Install bot
install_bot() {
    print_banner
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║ 🚀 INSTALLING XAUUSD MOMENTUM BOT                        ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check if already installed
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}⚠️  Bot is already installed!${NC}"
        echo ""
        echo -n "Reinstall? This will backup current config (y/N): "
        read -r reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            return
        fi
        
        # Backup
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
    
    # Get Discord webhook
    echo -e "${CYAN}[1/4]${NC} Discord Webhook URL"
    echo -n "Enter webhook URL: "
    read -r discord_webhook
    
    while [ -z "$discord_webhook" ]; do
        echo -e "${RED}✗ Webhook URL cannot be empty!${NC}"
        echo -n "Enter webhook URL: "
        read -r discord_webhook
    done
    
    # Get MT5 credentials
    echo ""
    echo -e "${CYAN}[2/4]${NC} MT5 Account Settings"
    echo -n "MT5 Login: "
    read -r mt5_login
    
    echo -n "MT5 Password: "
    read -rs mt5_password
    echo ""
    
    echo -n "MT5 Server [FOREX.com-Demo]: "
    read -r mt5_server
    mt5_server=${mt5_server:-FOREX.com-Demo}
    
    # Get momentum settings
    echo ""
    echo -e "${CYAN}[3/4]${NC} Momentum Settings"
    echo -n "M5 Body minimum (pips) [40]: "
    read -r m5_pips
    m5_pips=${m5_pips:-40}
    
    echo -n "M15 Body minimum (pips) [50]: "
    read -r m15_pips
    m15_pips=${m15_pips:-50}
    
    # Confirmation
    echo ""
    echo -e "${CYAN}[4/4]${NC} Configuration Summary"
    echo -e "${BOLD}════════════════════════════════════════════${NC}"
    echo -e "Symbol         : XAUUSD"
    echo -e "Timeframes     : M5, M15"
    echo -e "M5 Body Min    : $m5_pips pips"
    echo -e "M15 Body Min   : $m15_pips pips"
    echo -e "Wick Filter    : 30% max"
    echo -e "Alert Window   : 20-90s before close"
    echo -e "MT5 Server     : $mt5_server"
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
    
    # Install dependencies
    install_dependencies
    
    # Create directories
    echo -e "${BLUE}Creating directories...${NC}"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$INSTALL_DIR/utils"
    
    # Create .env file
    cat > "$INSTALL_DIR/.env" << EOF
# Discord Configuration
DISCORD_WEBHOOK_URL=$discord_webhook

# MT5 Configuration
MT5_LOGIN=$mt5_login
MT5_PASSWORD=$mt5_password
MT5_SERVER=$mt5_server
EOF
    
    # Create config.py
    cat > "$INSTALL_DIR/config.py" << 'EOF'
"""
Configuration for XAUUSD Momentum Bot
Based on Sekolah Trading Logic
"""

# Symbol Settings
SYMBOL = "XAUUSD"
TIMEFRAMES = {
    "M5": 5,    # 5 minutes
    "M15": 15   # 15 minutes
}

# Momentum Settings (Body minimum in pips)
MOMENTUM_PIPS_M5 = MOMENTUM_M5_PLACEHOLDER
MOMENTUM_PIPS_M15 = MOMENTUM_M15_PLACEHOLDER

# Pip size for XAUUSD
PIP_SIZE = 0.1  # 1 pip = 0.1 price movement

# Wick Filter (Sekolah Trading standard)
WICK_FILTER_ENABLED = True
MAX_WICK_PERCENTAGE = 0.30  # 30% max wick

# Alert Window (20-90 seconds before candle close)
ALERT_WINDOW_START = 20  # seconds
ALERT_WINDOW_END = 90    # seconds

# Alert Cooldown (prevent spam)
ALERT_COOLDOWN = 60  # seconds

# Check Interval
CHECK_INTERVAL = 5  # check every 5 seconds

# Discord Settings
ENABLE_EMBED = True
ENABLE_ERROR_ALERTS = True
ENABLE_DAILY_SUMMARY = True
DAILY_SUMMARY_HOUR = 0  # UTC hour (0 = midnight)

# Logging
LOG_LEVEL = "INFO"
LOG_TO_FILE = True
LOG_FILE = "logs/bot.log"
ERROR_LOG_FILE = "logs/error.log"

# MT5 Settings
MT5_TIMEOUT = 60000  # milliseconds
MT5_PATH = None  # Auto-detect
EOF
    
    # Replace placeholders
    sed -i "s/MOMENTUM_M5_PLACEHOLDER/$m5_pips/" "$INSTALL_DIR/config.py"
    sed -i "s/MOMENTUM_M15_PLACEHOLDER/$m15_pips/" "$INSTALL_DIR/config.py"
    
    # Download bot files from the script itself (embedded)
    create_bot_files
    
    # Create systemd service
    create_systemd_service
    
    # Set permissions
    chmod +x "$INSTALL_DIR"/*.py
    chmod 600 "$INSTALL_DIR/.env"
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║ ✅ INSTALLATION COMPLETE!                                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Installation Directory: $INSTALL_DIR"
    echo -e "Log Directory: $LOG_DIR"
    echo ""
    echo -e "${BOLD}Starting bot...${NC}"
    
    # Start MT5
    start_mt5
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable xauusd-bot > /dev/null 2>&1
    systemctl start xauusd-bot
    
    sleep 3
    
    # Test webhook
    test_discord_webhook
    
    echo ""
    echo -e "${GREEN}✓ Bot is now running!${NC}"
    echo ""
    echo -e "${BOLD}Quick Commands:${NC}"
    echo -e "  View logs    : sudo journalctl -u xauusd-bot -f"
    echo -e "  Check status : sudo systemctl status xauusd-bot"
    echo -e "  Manage       : sudo ./install.sh"
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Create bot files
create_bot_files() {
    echo -e "${BLUE}Creating bot files...${NC}"
    
    # This will be filled with the actual bot code
    # For now, creating placeholder
    
    cat > "$INSTALL_DIR/bot.py" << 'BOTEOF'
#!/usr/bin/env python3
"""
XAUUSD Momentum Bot
Based on Sekolah Trading Logic - Pine Script Translation
"""

import MetaTrader5 as mt5
import time
import logging
from datetime import datetime, timezone
from dotenv import load_dotenv
import os
import sys

# Add utils to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'utils'))

import config
from discord_handler import send_alert, send_error_alert, send_daily_summary
from mt5_handler import MT5Handler
from stats import StatsTracker

# Load environment
load_dotenv()

# Setup logging
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

# Error logger
error_logger = logging.getLogger('error')
error_handler = logging.FileHandler(config.ERROR_LOG_FILE)
error_handler.setLevel(logging.ERROR)
error_logger.addHandler(error_handler)

# Global state
last_alert_time = {}
stats = StatsTracker()
mt5_handler = None


def calculate_body_pips(candle):
    """Calculate body size in pips (Sekolah Trading logic)"""
    body = abs(candle['close'] - candle['open'])
    pips = body / config.PIP_SIZE
    return round(pips, 1)


def calculate_wick_percentage(candle):
    """Calculate wick percentage (Sekolah Trading logic)"""
    # Total wick = upper wick + lower wick
    upper_wick = candle['high'] - max(candle['open'], candle['close'])
    lower_wick = min(candle['open'], candle['close']) - candle['low']
    total_wick = upper_wick + lower_wick
    
    # Body
    body = abs(candle['close'] - candle['open'])
    
    # Total range
    total_range = body + total_wick
    
    if total_range == 0:
        return 100.0  # Doji - filter this
    
    # Wick percentage
    wick_pct = (total_wick / total_range)
    
    return wick_pct


def check_bearish_condition(current_candle, previous_candle):
    """
    Bearish condition (Sekolah Trading):
    - close < open (red candle), OR
    - close > open BUT close < previous open (bearish engulfing pattern)
    """
    is_red_candle = current_candle['close'] < current_candle['open']
    is_engulfing = (current_candle['close'] > current_candle['open'] and 
                    current_candle['close'] < previous_candle['open'])
    
    return is_red_candle or is_engulfing


def get_time_until_close(timeframe_minutes):
    """Calculate seconds until current candle closes"""
    now = datetime.now(timezone.utc)
    current_minute = now.minute
    current_second = now.second
    
    # Calculate minutes into current candle
    minutes_into_candle = current_minute % timeframe_minutes
    
    # Seconds until close
    seconds_until_close = ((timeframe_minutes - minutes_into_candle) * 60) - current_second
    
    return seconds_until_close


def check_momentum(timeframe_str):
    """Check momentum for specific timeframe (Sekolah Trading logic)"""
    global last_alert_time
    
    timeframe_minutes = config.TIMEFRAMES[timeframe_str]
    timeframe_constant = mt5.TIMEFRAME_M5 if timeframe_str == "M5" else mt5.TIMEFRAME_M15
    momentum_threshold = config.MOMENTUM_PIPS_M5 if timeframe_str == "M5" else config.MOMENTUM_PIPS_M15
    
    # Get last 2 candles (0 = current forming, 1 = previous completed)
    rates = mt5.copy_rates_from_pos(config.SYMBOL, timeframe_constant, 0, 2)
    
    if rates is None or len(rates) < 2:
        logger.warning(f"{timeframe_str}: Failed to get candle data")
        return
    
    current_candle = rates[0]
    previous_candle = rates[1]
    
    # Calculate body pips
    body_pips = calculate_body_pips(current_candle)
    
    # Check if body meets minimum threshold
    if body_pips < momentum_threshold:
        return
    
    # Calculate wick percentage
    wick_pct = calculate_wick_percentage(current_candle)
    
    # Check wick filter (Sekolah Trading: max 30%)
    if config.WICK_FILTER_ENABLED and wick_pct > config.MAX_WICK_PERCENTAGE:
        logger.debug(f"{timeframe_str}: Body {body_pips} pips OK, but wick {wick_pct*100:.1f}% > 30% (filtered)")
        return
    
    # Check alert window (20-90 seconds before close)
    seconds_until_close = get_time_until_close(timeframe_minutes)
    
    if not (config.ALERT_WINDOW_START <= seconds_until_close <= config.ALERT_WINDOW_END):
        return
    
    # Determine bullish/bearish
    is_bullish = current_candle['close'] > current_candle['open']
    is_bearish = check_bearish_condition(current_candle, previous_candle)
    
    if not (is_bullish or is_bearish):
        return
    
    # Check cooldown
    cooldown_key = f"{timeframe_str}_{int(current_candle['time'])}"
    current_time = time.time()
    
    if cooldown_key in last_alert_time:
        if current_time - last_alert_time[cooldown_key] < config.ALERT_COOLDOWN:
            return
    
    # Prepare alert data
    alert_data = {
        'symbol': config.SYMBOL,
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
    
    # Send alert
    logger.info(f"🚨 {timeframe_str}: MOMENTUM DETECTED! {body_pips} pips ({'BULLISH' if is_bullish else 'BEARISH'})")
    
    if send_alert(alert_data):
        last_alert_time[cooldown_key] = current_time
        stats.add_alert(timeframe_str, body_pips, is_bullish)


def check_daily_summary():
    """Send daily summary at configured hour"""
    now = datetime.now(timezone.utc)
    
    if now.hour == config.DAILY_SUMMARY_HOUR and now.minute == 0:
        summary = stats.get_daily_summary()
        if summary:
            send_daily_summary(summary)
            stats.reset_daily()


def main():
    """Main loop"""
    global mt5_handler
    
    logger.info("=" * 60)
    logger.info("XAUUSD Momentum Bot Starting...")
    logger.info("Based on Sekolah Trading Logic")
    logger.info("=" * 60)
    
    # Initialize MT5
    mt5_handler = MT5Handler()
    if not mt5_handler.connect():
        logger.error("Failed to connect to MT5. Exiting...")
        if config.ENABLE_ERROR_ALERTS:
            send_error_alert("MT5 Connection Failed", "Could not establish connection to MetaTrader 5")
        return
    
    logger.info(f"Symbol: {config.SYMBOL}")
    logger.info(f"Timeframes: {', '.join(config.TIMEFRAMES.keys())}")
    logger.info(f"M5 Body Min: {config.MOMENTUM_PIPS_M5} pips")
    logger.info(f"M15 Body Min: {config.MOMENTUM_PIPS_M15} pips")
    logger.info(f"Wick Filter: {'ENABLED' if config.WICK_FILTER_ENABLED else 'DISABLED'} (max {config.MAX_WICK_PERCENTAGE*100}%)")
    logger.info(f"Alert Window: {config.ALERT_WINDOW_START}-{config.ALERT_WINDOW_END}s before close")
    logger.info("=" * 60)
    
    consecutive_errors = 0
    max_errors = 5
    
    try:
        while True:
            try:
                # Check connection
                if not mt5_handler.is_connected():
                    logger.warning("MT5 disconnected. Reconnecting...")
                    if mt5_handler.reconnect():
                        logger.info("MT5 reconnected successfully")
                        if config.ENABLE_ERROR_ALERTS:
                            send_error_alert("MT5 Reconnected", "Connection restored successfully", is_recovery=True)
                        consecutive_errors = 0
                    else:
                        consecutive_errors += 1
                        if consecutive_errors >= max_errors:
                            logger.error("Max reconnection attempts reached. Exiting...")
                            if config.ENABLE_ERROR_ALERTS:
                                send_error_alert("MT5 Connection Failed", f"Failed after {max_errors} attempts")
                            break
                        time.sleep(30)
                        continue
                
                # Check momentum for each timeframe
                for tf in config.TIMEFRAMES.keys():
                    check_momentum(tf)
                
                # Check daily summary
                if config.ENABLE_DAILY_SUMMARY:
                    check_daily_summary()
                
                # Reset error counter on successful iteration
                consecutive_errors = 0
                
                time.sleep(config.CHECK_INTERVAL)
                
            except Exception as e:
                error_logger.error(f"Error in main loop: {e}", exc_info=True)
                consecutive_errors += 1
                
                if consecutive_errors >= max_errors:
                    logger.error("Too many consecutive errors. Exiting...")
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
        if mt5_handler:
            mt5_handler.disconnect()
        logger.info("Bot shut down")


if __name__ == "__main__":
    main()
BOTEOF

    # Create utils/discord_handler.py
    cat > "$INSTALL_DIR/utils/discord_handler.py" << 'DISCORDEOF'
"""Discord webhook handler"""

import requests
import logging
import os
from datetime import datetime

logger = logging.getLogger(__name__)

WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL")


def send_alert(data):
    """Send momentum alert to Discord"""
    if not WEBHOOK_URL:
        logger.error("Discord webhook URL not configured")
        return False
    
    try:
        direction = "🟢 BULLISH" if data['is_bullish'] else "🔴 BEARISH"
        color = 65280 if data['is_bullish'] else 16711680
        
        # Add engulfing note
        engulfing_note = ""
        if data['is_engulfing']:
            engulfing_note = f"\n⚠️ Close ({data['close']:.2f}) < Prev Open ({data['prev_open']:.2f}) - Bearish Pattern"
        
        embed = {
            "title": "🚨 MOMENTUM DETECTED!",
            "color": color,
            "fields": [
                {"name": "Pair", "value": data['symbol'], "inline": True},
                {"name": "Timeframe", "value": data['timeframe'], "inline": True},
                {"name": "Type", "value": direction, "inline": True},
                {"name": "━━━━━━━━━━━━━━━━━━━━━━━", "value": ""},
                {"name": "Body", "value": f"**{data['body_pips']} pips** ({data['body_pips']*0.1:.2f})", "inline": True},
                {"name": "Open", "value": f"{data['open']:.2f}", "inline": True},
                {"name": "Close", "value": f"{data['close']:.2f}", "inline": True},
                {"name": "High", "value": f"{data['high']:.2f}", "inline": True},
                {"name": "Low", "value": f"{data['low']:.2f}", "inline": True},
                {"name": "", "value": "", "inline": True},
                {"name": "Upper Wick", "value": f"{data['upper_wick']:.2f}", "inline": True},
                {"name": "Lower Wick", "value": f"{data['lower_wick']:.2f}", "inline": True},
                {"name": "Wick %", "value": f"{data['wick_pct']:.1f}% ✓", "inline": True},
            ],
            "description": f"**Time:** {data['time'].strftime('%Y-%m-%d %H:%M:%S')} UTC\n**Candle closes in:** {data['seconds_until_close']} seconds{engulfing_note}",
            "footer": {"text": "XAUUSD Momentum Bot - Sekolah Trading"},
            "timestamp": data['time'].isoformat()
        }
        
        payload = {
            "username": "XAUUSD Bot",
            "embeds": [embed]
        }
        
        response = requests.post(WEBHOOK_URL, json=payload, timeout=10)
        
        if response.status_code == 204:
            logger.info(f"✅ Alert sent to Discord")
            return True
        else:
            logger.error(f"Discord webhook failed: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"Error sending Discord alert: {e}")
        return False


def send_error_alert(title, message, is_recovery=False):
    """Send error notification to Discord"""
    if not WEBHOOK_URL:
        return False
    
    try:
        color = 65280 if is_recovery else 16711680  # Green if recovery, red if error
        icon = "✅" if is_recovery else "🔴"
        
        embed = {
            "title": f"{icon} {title}",
            "description": message,
            "color": color,
            "timestamp": datetime.utcnow().isoformat(),
            "footer": {"text": "XAUUSD Bot Alert System"}
        }
        
        payload = {
            "username": "XAUUSD Bot",
            "embeds": [embed]
        }
        
        response = requests.post(WEBHOOK_URL, json=payload, timeout=10)
        return response.status_code == 204
        
    except:
        return False


def send_daily_summary(summary):
    """Send daily summary to Discord"""
    if not WEBHOOK_URL:
        return False
    
    try:
        total = summary['total_alerts']
        m5_total = summary['m5_alerts']
        m15_total = summary['m15_alerts']
        
        fields = [
            {"name": "Total Alerts", "value": str(total), "inline": True},
            {"name": "M5 Alerts", "value": str(m5_total), "inline": True},
            {"name": "M15 Alerts", "value": str(m15_total), "inline": True},
            {"name": "━━━━━━━━━━━━━━━━━━━━━━━", "value": ""},
            {"name": "🟢 Bullish", "value": f"{summary['bullish']} ({summary['bullish_pct']:.1f}%)", "inline": True},
            {"name": "🔴 Bearish", "value": f"{summary['bearish']} ({summary['bearish_pct']:.1f}%)", "inline": True},
            {"name": "", "value": "", "inline": True},
            {"name": "Average Pips", "value": f"{summary['avg_pips']:.1f}", "inline": True},
            {"name": "Max Pips", "value": f"{summary['max_pips']:.1f}", "inline": True},
            {"name": "Min Pips", "value": f"{summary['min_pips']:.1f}", "inline": True},
        ]
        
        embed = {
            "title": f"📊 DAILY SUMMARY - {summary['date']}",
            "color": 3447003,
            "fields": fields,
            "footer": {"text": "XAUUSD Momentum Bot"},
            "timestamp": datetime.utcnow().isoformat()
        }
        
        payload = {
            "username": "XAUUSD Bot",
            "embeds": [embed]
        }
        
        response = requests.post(WEBHOOK_URL, json=payload, timeout=10)
        return response.status_code == 204
        
    except Exception as e:
        logger.error(f"Error sending daily summary: {e}")
        return False


def send_test_alert():
    """Send test alert"""
    if not WEBHOOK_URL:
        return False
    
    try:
        embed = {
            "title": "✅ TEST ALERT",
            "description": "Bot installation successful!\n\nConfiguration verified and ready to monitor XAUUSD M5/M15.",
            "color": 65280,
            "fields": [
                {"name": "Symbol", "value": "XAUUSD", "inline": True},
                {"name": "Timeframes", "value": "M5, M15", "inline": True},
                {"name": "Status", "value": "● Running", "inline": True}
            ],
            "footer": {"text": "XAUUSD Momentum Bot"},
            "timestamp": datetime.utcnow().isoformat()
        }
        
        payload = {
            "username": "XAUUSD Bot",
            "embeds": [embed]
        }
        
        response = requests.post(WEBHOOK_URL, json=payload, timeout=10)
        return response.status_code == 204
        
    except:
        return False
DISCORDEOF

    # Create utils/mt5_handler.py
    cat > "$INSTALL_DIR/utils/mt5_handler.py" << 'MT5EOF'
"""MT5 connection handler"""

import MetaTrader5 as mt5
import logging
import os

logger = logging.getLogger(__name__)


class MT5Handler:
    def __init__(self):
        self.connected = False
        self.login = os.getenv("MT5_LOGIN")
        self.password = os.getenv("MT5_PASSWORD")
        self.server = os.getenv("MT5_SERVER")
    
    def connect(self):
        """Initialize MT5 connection"""
        try:
            if not mt5.initialize():
                logger.error(f"MT5 initialization failed: {mt5.last_error()}")
                return False
            
            logger.info(f"MT5 version: {mt5.version()}")
            
            # Login if credentials provided
            if self.login and self.password:
                if not mt5.login(int(self.login), self.password, self.server):
                    logger.error(f"MT5 login failed: {mt5.last_error()}")
                    return False
                logger.info(f"Logged in to {self.server}")
            
            # Verify symbol
            symbol_info = mt5.symbol_info("XAUUSD")
            if symbol_info is None:
                logger.error("XAUUSD symbol not found")
                return False
            
            if not symbol_info.visible:
                if not mt5.symbol_select("XAUUSD", True):
                    logger.error("Failed to select XAUUSD")
                    return False
            
            self.connected = True
            logger.info("MT5 connected successfully")
            return True
            
        except Exception as e:
            logger.error(f"MT5 connection error: {e}")
            return False
    
    def is_connected(self):
        """Check if MT5 is still connected"""
        if not self.connected:
            return False
        
        try:
            # Try to get account info
            account_info = mt5.account_info()
            return account_info is not None
        except:
            return False
    
    def reconnect(self):
        """Attempt to reconnect"""
        logger.info("Attempting to reconnect to MT5...")
        self.disconnect()
        return self.connect()
    
    def disconnect(self):
        """Disconnect from MT5"""
        try:
            mt5.shutdown()
            self.connected = False
            logger.info("MT5 disconnected")
        except:
            pass
MT5EOF

    # Create utils/stats.py
    cat > "$INSTALL_DIR/utils/stats.py" << 'STATSEOF'
"""Statistics tracker"""

from datetime import datetime, timezone
import logging

logger = logging.getLogger(__name__)


class StatsTracker:
    def __init__(self):
        self.reset_daily()
    
    def reset_daily(self):
        """Reset daily statistics"""
        self.alerts = []
        self.last_reset = datetime.now(timezone.utc).date()
    
    def add_alert(self, timeframe, pips, is_bullish):
        """Record an alert"""
        self.alerts.append({
            'timeframe': timeframe,
            'pips': pips,
            'is_bullish': is_bullish,
            'timestamp': datetime.now(timezone.utc)
        })
    
    def get_daily_summary(self):
        """Get daily summary statistics"""
        if not self.alerts:
            return None
        
        total = len(self.alerts)
        m5_alerts = [a for a in self.alerts if a['timeframe'] == 'M5']
        m15_alerts = [a for a in self.alerts if a['timeframe'] == 'M15']
        bullish = [a for a in self.alerts if a['is_bullish']]
        bearish = [a for a in self.alerts if not a['is_bullish']]
        
        all_pips = [a['pips'] for a in self.alerts]
        
        return {
            'date': self.last_reset.strftime('%Y-%m-%d'),
            'total_alerts': total,
            'm5_alerts': len(m5_alerts),
            'm15_alerts': len(m15_alerts),
            'bullish': len(bullish),
            'bearish': len(bearish),
            'bullish_pct': (len(bullish) / total * 100) if total > 0 else 0,
            'bearish_pct': (len(bearish) / total * 100) if total > 0 else 0,
            'avg_pips': sum(all_pips) / len(all_pips) if all_pips else 0,
            'max_pips': max(all_pips) if all_pips else 0,
            'min_pips': min(all_pips) if all_pips else 0
        }
STATSEOF

    # Create __init__.py files
    touch "$INSTALL_DIR/utils/__init__.py"
    
    echo -e "${GREEN}✓${NC} Bot files created"
}

# Create systemd service
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
ExecStartPre=/usr/bin/xvfb-run -a wine "$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
ExecStart=/usr/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "${GREEN}✓${NC} Systemd service created"
}

# Start MT5
start_mt5() {
    echo -e "${BLUE}Starting MT5 terminal...${NC}"
    xvfb-run -a wine "$HOME/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe" &
    sleep 5
    echo -e "${GREEN}✓${NC} MT5 started"
}

# Start bot
start_bot() {
    print_banner
    echo -e "${GREEN}Starting bot...${NC}"
    
    if systemctl is-active --quiet xauusd-bot; then
        echo -e "${YELLOW}Bot is already running${NC}"
        return
    fi
    
    # Start MT5 if not running
    if ! pgrep -f "terminal64.exe" > /dev/null; then
        start_mt5
    fi
    
    systemctl start xauusd-bot
    sleep 2
    
    if systemctl is-active --quiet xauusd-bot; then
        echo -e "${GREEN}✓ Bot started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start bot${NC}"
        echo ""
        echo "Check logs with: sudo journalctl -u xauusd-bot -n 50"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Stop bot
stop_bot() {
    print_banner
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo ""
    echo "Stopping the bot will:"
    echo "  • Stop monitoring XAUUSD"
    echo "  • Disable Discord alerts"
    echo "  • Close MT5 connection"
    echo ""
    echo -n "Continue? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Stopping bot...${NC}"
    systemctl stop xauusd-bot
    
    echo -e "${GREEN}✓ Bot stopped${NC}"
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Restart bot
restart_bot() {
    print_banner
    echo -e "${BLUE}Restarting bot...${NC}"
    
    systemctl restart xauusd-bot
    sleep 2
    
    if systemctl is-active --quiet xauusd-bot; then
        echo -e "${GREEN}✓ Bot restarted successfully${NC}"
    else
        echo -e "${RED}✗ Failed to restart bot${NC}"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# View logs
view_logs() {
    print_banner
    echo -e "${PURPLE}Viewing live logs (Ctrl+C to exit)...${NC}"
    echo ""
    sleep 2
    journalctl -u xauusd-bot -f
}

# Statistics
show_statistics() {
    print_banner
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║ 📈 BOT STATISTICS                                         ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ -f "$LOG_DIR/bot.log" ]; then
        total_alerts=$(grep -c "MOMENTUM DETECTED" "$LOG_DIR/bot.log" 2>/dev/null || echo "0")
        bullish=$(grep "MOMENTUM DETECTED.*BULLISH" "$LOG_DIR/bot.log" | wc -l 2>/dev/null || echo "0")
        bearish=$(grep "MOMENTUM DETECTED.*BEARISH" "$LOG_DIR/bot.log" | wc -l 2>/dev/null || echo "0")
        
        echo -e "${BOLD}Total Alerts Today:${NC} $total_alerts"
        echo -e "  🟢 Bullish: $bullish"
        echo -e "  🔴 Bearish: $bearish"
        echo ""
        
        echo -e "${BOLD}Recent Alerts:${NC}"
        grep "MOMENTUM DETECTED" "$LOG_DIR/bot.log" | tail -5 || echo "No alerts yet"
    else
        echo "No statistics available"
    fi
    
    echo ""
    echo -n "Press Enter to continue..."
    read -r
}

# Settings menu
settings_menu() {
    while true; do
        print_banner
        echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║ ⚙️  SETTINGS & CONFIGURATION                              ║${NC}"
        echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        if [ -f "$INSTALL_DIR/config.py" ]; then
            m5=$(grep "MOMENTUM_PIPS_M5" "$INSTALL_DIR/config.py" | grep -o '[0-9]*' | head -1)
            m15=$(grep "MOMENTUM_PIPS_M15" "$INSTALL_DIR/config.py" | grep -o '[0-9]*' | head -1)
            
            echo "Current Settings:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo -e "${BOLD}[1]${NC} Change M5 Body Minimum      : $m5 pips"
            echo -e "${BOLD}[2]${NC} Change M15 Body Minimum     : $m15 pips"
            echo -e "${BOLD}[3]${NC} Update Discord Webhook"
            echo -e "${BOLD}[4]${NC} Update MT5 Credentials"
            echo -e "${BOLD}[5]${NC} View Current Config"
            echo ""
            echo -e "${BOLD}[0]${NC} Back to Main Menu"
            echo ""
            echo -n "Enter choice [0-5]: "
            read -r choice
            
            case $choice in
                1)
                    echo ""
                    echo -n "Enter new M5 minimum (pips): "
                    read -r new_m5
                    if [[ "$new_m5" =~ ^[0-9]+$ ]]; then
                        sed -i "s/MOMENTUM_PIPS_M5 = [0-9]*/MOMENTUM_PIPS_M5 = $new_m5/" "$INSTALL_DIR/config.py"
                        echo -e "${GREEN}✓ Updated to $new_m5 pips${NC}"
                        echo "Restart bot to apply changes"
                        sleep 2
                    fi
                    ;;
                2)
                    echo ""
                    echo -n "Enter new M15 minimum (pips): "
                    read -r new_m15
                    if [[ "$new_m15" =~ ^[0-9]+$ ]]; then
                        sed -i "s/MOMENTUM_PIPS_M15 = [0-9]*/MOMENTUM_PIPS_M15 = $new_m15/" "$INSTALL_DIR/config.py"
                        echo -e "${GREEN}✓ Updated to $new_m15 pips${NC}"
                        echo "Restart bot to apply changes"
                        sleep 2
                    fi
                    ;;
                3)
                    echo ""
                    echo -n "Enter new Discord Webhook URL: "
                    read -r new_webhook
                    if [ -n "$new_webhook" ]; then
                        sed -i "s|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=$new_webhook|" "$INSTALL_DIR/.env"
                        echo -e "${GREEN}✓ Webhook updated${NC}"
                        sleep 2
                    fi
                    ;;
                4)
                    echo ""
                    echo -n "MT5 Login: "
                    read -r new_login
                    echo -n "MT5 Password: "
                    read -rs new_pass
                    echo ""
                    echo -n "MT5 Server: "
                    read -r new_server
                    
                    sed -i "s/MT5_LOGIN=.*/MT5_LOGIN=$new_login/" "$INSTALL_DIR/.env"
                    sed -i "s/MT5_PASSWORD=.*/MT5_PASSWORD=$new_pass/" "$INSTALL_DIR/.env"
                    sed -i "s/MT5_SERVER=.*/MT5_SERVER=$new_server/" "$INSTALL_DIR/.env"
                    echo -e "${GREEN}✓ MT5 credentials updated${NC}"
                    sleep 2
                    ;;
                5)
                    echo ""
                    cat "$INSTALL_DIR/config.py"
                    echo ""
                    echo -n "Press Enter to continue..."
                    read -r
                    ;;
                0)
                    break
                    ;;
            esac
        fi
    done
}

# Test Discord
test_discord_webhook() {
    echo -e "${BLUE}Testing Discord webhook...${NC}"
    
    python3 << PYEOF
import sys
sys.path.insert(0, '$INSTALL_DIR/utils')
from discord_handler import send_test_alert
if send_test_alert():
    print("${GREEN}✓ Test alert sent to Discord!${NC}")
else:
    print("${RED}✗ Failed to send test alert${NC}")
PYEOF
}

# Maintenance menu
maintenance_menu() {
    while true; do
        print_banner
        echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║ 🔧 MAINTENANCE & TOOLS                                    ║${NC}"
        echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BOLD}[1]${NC} View Bot Status"
        echo -e "${BOLD}[2]${NC} Clear Logs"
        echo -e "${BOLD}[3]${NC} Backup Configuration"
        echo -e "${BOLD}[4]${NC} Check MT5 Connection"
        echo -e "${BOLD}[5]${NC} Restart MT5 Terminal"
        echo ""
        echo -e "${BOLD}[0]${NC} Back to Main Menu"
        echo ""
        echo -n "Enter choice [0-5]: "
        read -r choice
        
        case $choice in
            1)
                systemctl status xauusd-bot
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            2)
                echo ""
                echo -n "Clear all logs? (y/N): "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    > "$LOG_DIR/bot.log"
                    > "$LOG_DIR/error.log"
                    echo -e "${GREEN}✓ Logs cleared${NC}"
                    sleep 2
                fi
                ;;
            3)
                backup_file="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
                tar -czf "$backup_file" -C "$INSTALL_DIR" .env config.py
                echo -e "${GREEN}✓ Backup created: $backup_file${NC}"
                sleep 2
                ;;
            4)
                if pgrep -f "terminal64.exe" > /dev/null; then
                    echo -e "${GREEN}✓ MT5 is running${NC}"
                else
                    echo -e "${RED}✗ MT5 is not running${NC}"
                fi
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            5)
                pkill -f "terminal64.exe"
                sleep 2
                start_mt5
                echo ""
                echo -n "Press Enter to continue..."
                read -r
                ;;
            0)
                break
                ;;
        esac
    done
}

# Uninstall
uninstall_bot() {
    print_banner
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ ⚠️  UNINSTALL BOT                                         ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This will remove:${NC}"
    echo "  • Bot installation ($INSTALL_DIR)"
    echo "  • Systemd service"
    echo "  • All logs"
    echo "  • MT5 installation"
    echo ""
    echo -e "${RED}This action cannot be undone!${NC}"
    echo ""
    echo -n "Type 'UNINSTALL' to confirm: "
    read -r confirm
    
    if [ "$confirm" != "UNINSTALL" ]; then
        echo "Cancelled"
        sleep 2
        return
    fi
    
    echo ""
    echo "Uninstalling..."
    
    # Stop service
    systemctl stop xauusd-bot 2>/dev/null || true
    systemctl disable xauusd-bot 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    
    # Stop MT5
    pkill -f "terminal64.exe" 2>/dev/null || true
    
    # Remove files
    rm -rf "$INSTALL_DIR"
    rm -rf ~/.wine
    
    echo -e "${GREEN}✓ Bot uninstalled${NC}"
    echo ""
    echo -n "Press Enter to exit..."
    read -r
    exit 0
}

# Main
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
            9) maintenance_menu ;;
            10) uninstall_bot ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid choice"; sleep 1 ;;
        esac
    done
}

main