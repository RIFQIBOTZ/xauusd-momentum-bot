#!/bin/bash

#==============================================================================
# XAUUSD Momentum Bot - Complete Installation & Management System
# Version 3.2.0 - 100% Sekolah Trading Logic
#==============================================================================

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

# Paths
INSTALL_DIR="/opt/xauusd-bot"
LOG_DIR="$INSTALL_DIR/logs"
UTILS_DIR="$INSTALL_DIR/utils"
BACKUP_DIR="$INSTALL_DIR/backups"
SERVICE_NAME="xauusd-bot"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
INSTALL_LOG="$INSTALL_DIR/install.log"

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}" 
   exit 1
fi

#==============================================================================
# Utility Functions
#==============================================================================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    [[ -f "$INSTALL_LOG" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$INSTALL_LOG"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    [[ -f "$INSTALL_LOG" ]] && echo "[ERROR] $1" >> "$INSTALL_LOG"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

progress() {
    echo -ne "${CYAN}[$1/10]${NC} $2... "
}

get_bot_status() {
    if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        echo "Running"
    else
        echo "Stopped"
    fi
}

get_bot_uptime() {
    if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        systemctl show $SERVICE_NAME --property=ActiveEnterTimestamp --value | xargs -I {} date -d {} +%s | xargs -I {} echo $(( ($(date +%s) - {}) / 60 )) | xargs -I {} echo "{}m"
    else
        echo "N/A"
    fi
}

check_mt5_running() {
    if pgrep -f "terminal64.exe" > /dev/null; then
        echo "Connected"
    else
        echo "Not Running"
    fi
}

check_zmq_port() {
    if netstat -tuln 2>/dev/null | grep -q ":5555 "; then
        echo "Active"
    else
        echo "Inactive"
    fi
}

get_last_alert() {
    if [[ -f "$LOG_DIR/bot.log" ]]; then
        grep "MOMENTUM" "$LOG_DIR/bot.log" 2>/dev/null | tail -1 | awk '{print $6, $7, $8}' | head -c 50 || echo "None"
    else
        echo "None"
    fi
}

get_today_alerts() {
    if [[ -f "$LOG_DIR/bot.log" ]]; then
        grep "$(date +%Y-%m-%d)" "$LOG_DIR/bot.log" 2>/dev/null | grep -c "MOMENTUM" || echo "0"
    else
        echo "0"
    fi
}

#==============================================================================
# Main Menu
#==============================================================================

show_menu() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     🚀 XAUUSD MOMENTUM BOT - CONTROL PANEL 🚀            ║
║              MT5 + ZeroMQ Real-time System                ║
║              Version 3.2.0                                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    BOT_STATUS=$(get_bot_status)
    BOT_UPTIME=$(get_bot_uptime)
    MT5_STATUS=$(check_mt5_running)
    ZMQ_STATUS=$(check_zmq_port)
    LAST_ALERT=$(get_last_alert)
    TODAY_ALERTS=$(get_today_alerts)

    if [[ "$BOT_STATUS" == "Running" ]]; then
        STATUS_ICON="${GREEN}●${NC}"
    else
        STATUS_ICON="${RED}●${NC}"
    fi

    echo -e "┌───────────────────────────────────────────────────────────┐"
    echo -e "│ ${BOLD}SYSTEM STATUS${NC}                                             │"
    echo -e "├───────────────────────────────────────────────────────────┤"
    echo -e "│ Bot Service    : $STATUS_ICON $BOT_STATUS (Uptime: $BOT_UPTIME)              │"
    echo -e "│ MT5 Terminal   : $MT5_STATUS                              │"
    echo -e "│ ZeroMQ Status  : $ZMQ_STATUS (Port 5555)                    │"
    echo -e "│ Last Alert     : $LAST_ALERT │"
    echo -e "│ Total Alerts   : $TODAY_ALERTS today                                 │"
    echo -e "└───────────────────────────────────────────────────────────┘"
    echo ""

    if [[ -f "$INSTALL_DIR/config.py" ]]; then
        M5_PIPS=$(grep "MOMENTUM_PIPS_M5" "$INSTALL_DIR/config.py" 2>/dev/null | awk -F'= ' '{print $2}' || echo "40")
        M15_PIPS=$(grep "MOMENTUM_PIPS_M15" "$INSTALL_DIR/config.py" 2>/dev/null | awk -F'= ' '{print $2}' || echo "50")
        
        echo -e "┌───────────────────────────────────────────────────────────┐"
        echo -e "│ ${BOLD}CURRENT SETTINGS${NC}                                          │"
        echo -e "├───────────────────────────────────────────────────────────┤"
        echo -e "│ Symbol         : XAUUSD                                   │"
        echo -e "│ Timeframes     : M5, M15                                  │"
        echo -e "│ M5 Body Min    : $M5_PIPS pips                                  │"
        echo -e "│ M15 Body Min   : $M15_PIPS pips                                  │"
        echo -e "│ Wick Filter    : 30% max                                  │"
        echo -e "│ Alert Window   : 20-90s before close                      │"
        echo -e "└───────────────────────────────────────────────────────────┘"
        echo ""
    fi

    echo -e "${BOLD}${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║ MAIN MENU                                                 ║
╠═══════════════════════════════════════════════════════════╣
║                                                           ║
║  [1] 🚀 Install/Reinstall Bot                            ║
║  [2] ▶️  Start Bot                                        ║
║  [3] ⏸️  Stop Bot                                         ║
║  [4] 🔄 Restart Bot                                       ║
║  [5] 📊 View Live Logs                                    ║
║  [6] 📈 Bot Statistics                                    ║
║  [7] ⚙️  Settings & Configuration                         ║
║  [8] 🔔 Test Discord Alert                                ║
║  [9] 🔧 Maintenance & Tools                               ║
║  [10] 🗑️ Uninstall Bot                                    ║
║  [0] 🚪 Exit                                              ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -n "Enter your choice [0-10]: "
}

#==============================================================================
# [1] Installation
#==============================================================================

install_bot() {
    clear
    echo -e "${BOLD}${CYAN}=== XAUUSD Bot Installation ===${NC}\n"

    # Backup existing config
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Existing installation detected"
        read -p "Backup current configuration? (y/n): " backup_choice
        if [[ "$backup_choice" == "y" ]]; then
            BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$INSTALL_DIR" config.py .env 2>/dev/null || true
            success "Backup created: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
        fi
        
        # Stop service if running
        if systemctl is-active --quiet $SERVICE_NAME; then
            systemctl stop $SERVICE_NAME
            sleep 2
        fi
    fi

    # Get configuration
    echo -e "\n${BOLD}Configuration:${NC}"
    
    # Discord webhook validation
    while true; do
        read -p "Discord Webhook URL: " WEBHOOK_URL
        
        if [[ -z "$WEBHOOK_URL" ]]; then
            error "Webhook URL cannot be empty"
            continue
        fi
        
        if [[ ! "$WEBHOOK_URL" =~ ^https://discord.com/api/webhooks/ ]]; then
            warn "URL doesn't match Discord webhook format"
            echo "Example: https://discord.com/api/webhooks/1234567890/AbCdEfGhIjKlMnOp"
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        break
    done

    read -p "MT5 Login (optional, press Enter to skip): " MT5_LOGIN
    read -p "MT5 Password (optional): " MT5_PASSWORD
    read -p "MT5 Server (e.g., FBS-Demo): " MT5_SERVER
    MT5_SERVER=${MT5_SERVER:-FBS-Demo}
    
    read -p "M5 Body Minimum (pips) [40]: " M5_PIPS
    M5_PIPS=${M5_PIPS:-40}
    read -p "M15 Body Minimum (pips) [50]: " M15_PIPS
    M15_PIPS=${M15_PIPS:-50}

    # Confirmation
    echo -e "\n${BOLD}Configuration Summary:${NC}"
    echo "Discord Webhook: ${WEBHOOK_URL:0:50}..."
    echo "M5 Threshold: $M5_PIPS pips"
    echo "M15 Threshold: $M15_PIPS pips"
    echo "MT5 Server: $MT5_SERVER"
    echo ""
    read -p "Proceed with installation? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        warn "Installation cancelled"
        read -p "Press Enter to continue..."
        return
    fi

    # Start installation
    mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$UTILS_DIR" "$BACKUP_DIR"
    echo "" > "$INSTALL_LOG"

    # [1/10] System check
    progress 1 "Checking system requirements"
    if command -v python3 &>/dev/null && command -v apt-get &>/dev/null; then
        success "System requirements OK"
    else
        error "System requirements not met"
        return 1
    fi

    # [2/10] Install Wine
    progress 2 "Installing Wine"
    apt-get update -qq >> "$INSTALL_LOG" 2>&1
    dpkg --add-architecture i386 >> "$INSTALL_LOG" 2>&1
    apt-get install -y wine-stable wine64 wget unzip net-tools >> "$INSTALL_LOG" 2>&1
    success "Wine installed"

    # [3/10] Download MT5
    progress 3 "Downloading MT5"
    cd /tmp
    if [[ -f "mt5setup.exe" ]]; then
        warn "MT5 installer already exists, reusing..."
    else
        wget -q --timeout=30 --tries=3 https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O mt5setup.exe || {
            error "Failed to download MT5 from MQL5"
            echo "Please download MT5 manually and save to /tmp/mt5setup.exe"
            echo "Then press Enter to continue..."
            read
            [[ ! -f "/tmp/mt5setup.exe" ]] && return 1
        }
    fi
    success "MT5 downloaded"

    # [4/10] Install MT5
    progress 4 "Installing MT5"
    WINEPREFIX="$HOME/.wine" wine mt5setup.exe /S /quiet >> "$INSTALL_LOG" 2>&1 &
    MT5_PID=$!
    
    # Wait for installation
    echo -n "Installing (waiting 60 seconds)... "
    for i in {1..60}; do
        if ! ps -p $MT5_PID > /dev/null 2>&1; then
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""
    
    # Kill if still running
    kill $MT5_PID 2>/dev/null || true
    success "MT5 installed"

    # [5/10] Install ZeroMQ
    progress 5 "Installing ZeroMQ for MT5"
    install_zeromq_auto
    success "ZeroMQ installed"

    # [6/10] Install Python packages
    progress 6 "Installing Python packages"
    apt-get install -y python3 python3-pip >> "$INSTALL_LOG" 2>&1
    pip3 install -q pyzmq==25.1.2 requests python-dotenv pytz >> "$INSTALL_LOG" 2>&1
    success "Python packages installed"

    # [7/10] Create bot files
    progress 7 "Creating bot files"
    create_bot_files "$WEBHOOK_URL" "$MT5_LOGIN" "$MT5_PASSWORD" "$MT5_SERVER" "$M5_PIPS" "$M15_PIPS"
    success "Bot files created"

    # [8/10] Configure systemd
    progress 8 "Configuring systemd service"
    create_systemd_service
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME >> "$INSTALL_LOG" 2>&1
    success "Systemd configured"

    # [9/10] Set permissions
    progress 9 "Setting permissions"
    chmod +x "$INSTALL_DIR/bot.py"
    chmod 755 "$INSTALL_DIR"
    chmod 644 "$INSTALL_DIR"/*.py "$INSTALL_DIR"/*.md "$INSTALL_DIR"/.env 2>/dev/null || true
    chmod 755 "$UTILS_DIR"/*.py 2>/dev/null || true
    chown -R root:root "$INSTALL_DIR"
    success "Permissions set"

    # [10/10] Complete
    progress 10 "Installation complete"
    success "Done!"

    echo -e "\n${GREEN}${BOLD}✅ Installation Successful!${NC}\n"
    echo -e "${YELLOW}${BOLD}📋 MANUAL STEPS REQUIRED:${NC}"
    echo "1. Start MT5 Terminal:"
    echo "   wine 'C:\Program Files\MetaTrader 5\terminal64.exe' &"
    echo ""
    echo "2. Login to your MT5 account"
    echo ""
    echo "3. Copy EA to MT5 Experts folder:"
    echo "   cp '$INSTALL_DIR/XAUUSD_ZMQ_Server.mq5'"
    echo "   to: ~/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/"
    echo ""
    echo "4. Open MetaEditor (F4), compile XAUUSD_ZMQ_Server.mq5"
    echo ""
    echo "5. Attach EA to XAUUSD chart (any timeframe)"
    echo "   - Set 'InpBrokerUTCOffset' parameter (e.g., +2 for EET, -5 for EST)"
    echo ""
    echo "6. Enable AutoTrading (Ctrl+E)"
    echo ""
    echo "7. Start bot from menu option [2]"
    echo ""
    echo -e "${CYAN}${BOLD}To start using the menu:${NC}"
    echo "cd /opt/xauusd-bot && sudo ./install.sh"
    echo ""
    echo -e "${GREEN}${BOLD}Validation Command:${NC}"
    echo "bash /tmp/validate_install.sh"
    echo ""
    read -p "Press Enter to return to menu..."
}

install_zeromq_auto() {
    echo ""
    echo -e "${CYAN}[5/10] Installing ZeroMQ for MT5 (AUTO-DOWNLOAD)${NC}"
    
    MT5_LIB_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Libraries"
    MT5_INC_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Include/Zmq"
    
    mkdir -p "$MT5_LIB_DIR" "$MT5_INC_DIR"
    
    # Check if already installed
    if [[ -f "$MT5_LIB_DIR/libzmq.dll" ]] && [[ -f "$MT5_INC_DIR/Zmq.mqh" ]]; then
        echo -e "${GREEN}✓ ZeroMQ already installed${NC}"
        return 0
    fi
    
    cd /tmp || return 1
    
    # Download from GitHub
    ZMQ_VERSION="4.3.4"
    ZMQ_URL="https://github.com/dingmaotu/mql-zmq/releases/download/v${ZMQ_VERSION}/mql-zmq-${ZMQ_VERSION}-x64.zip"
    
    echo -n "  Downloading ZeroMQ ${ZMQ_VERSION}... "
    if wget -q "$ZMQ_URL" -O mql-zmq.zip 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    elif curl -sL "$ZMQ_URL" -o mql-zmq.zip 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        error "Could not download ZeroMQ. Check internet connection."
        return 1
    fi
    
    # Extract
    echo -n "  Extracting... "
    if unzip -q -o mql-zmq.zip 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        error "Could not extract ZeroMQ archive"
        return 1
    fi
    
    # Copy DLL (64-bit)
    echo -n "  Installing libzmq.dll... "
    if [[ -f "Library/MT5/x64/libzmq.dll" ]]; then
        cp "Library/MT5/x64/libzmq.dll" "$MT5_LIB_DIR/" && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; return 1; }
    elif [[ -f "libzmq.dll" ]]; then
        cp "libzmq.dll" "$MT5_LIB_DIR/" && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; return 1; }
    else
        echo -e "${RED}NOT FOUND${NC}"
        error "libzmq.dll not found in archive"
        return 1
    fi
    
    # Copy MQH includes
    echo -n "  Installing Zmq.mqh headers... "
    if [[ -d "Include/Mql" ]]; then
        cp Include/Mql/*.mqh "$MT5_INC_DIR/" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; return 1; }
    elif [[ -d "Include" ]]; then
        cp Include/*.mqh "$MT5_INC_DIR/" 2>/dev/null && echo -e "${GREEN}OK${NC}" || { echo -e "${RED}FAILED${NC}"; return 1; }
    else
        echo -e "${RED}NOT FOUND${NC}"
        error "Zmq.mqh not found in archive"
        return 1
    fi
    
    # Verify installation
    if [[ -f "$MT5_LIB_DIR/libzmq.dll" ]] && [[ -f "$MT5_INC_DIR/Zmq.mqh" ]]; then
        rm -f mql-zmq.zip  # Cleanup
        echo -e "${GREEN}✓ ZeroMQ installation verified${NC}"
        return 0
    else
        echo -e "${RED}✗ Installation verification failed${NC}"
        error "ZeroMQ files not found after installation"
        return 1
    fi
}

create_bot_files() {
    local webhook=$1
    local login=$2
    local password=$3
    local server=$4
    local m5_pips=$5
    local m15_pips=$6

    echo "Creating all bot files..."

    # Create .env
    cat > "$INSTALL_DIR/.env" << EOF
# Discord Webhook URL (REQUIRED)
DISCORD_WEBHOOK_URL=$webhook

# MT5 Credentials (optional)
MT5_LOGIN=$login
MT5_PASSWORD=$password
MT5_SERVER=$server

# ZeroMQ Port
ZMQ_PORT=5555
EOF

    # Create config.py
    cat > "$INSTALL_DIR/config.py" << EOF
"""Configuration for XAUUSD Momentum Bot - 100% Sekolah Trading Logic"""

# Symbol Settings
SYMBOL = "XAUUSD"
TIMEFRAMES = {"M5": 5, "M15": 15}

# Momentum Settings (Body minimum in pips) - SEKOLAH TRADING STANDARD
MOMENTUM_PIPS_M5 = $m5_pips
MOMENTUM_PIPS_M15 = $m15_pips

# Pip Size for XAUUSD (CRITICAL: 1 pip = 0.1 price movement)
PIP_SIZE = 0.1

# Wick Filter (Sekolah Trading: 30% maximum)
WICK_FILTER_ENABLED = True
MAX_WICK_PERCENTAGE = 0.30

# Alert Window (20-90 seconds before candle close) - REAL-TIME FORMING CANDLE
ALERT_WINDOW_START = 20
ALERT_WINDOW_END = 90

# Alert Settings
ALERT_COOLDOWN = 60

# Discord Settings
ENABLE_EMBED = True
ENABLE_ERROR_ALERTS = True
ENABLE_DAILY_SUMMARY = True
DAILY_SUMMARY_HOUR = 0

# Logging
LOG_LEVEL = "INFO"
LOG_TO_FILE = True
LOG_FILE = "$LOG_DIR/bot.log"
ERROR_LOG_FILE = "$LOG_DIR/error.log"

# ZeroMQ Settings
ZMQ_ENDPOINT = "tcp://localhost:5555"
EOF

    # Create bot.py (FIXED VERSION)
    cat > "$INSTALL_DIR/bot.py" << 'EOF'
#!/usr/bin/env python3
"""
XAUUSD Momentum Bot - MT5 ZeroMQ Version
100% Sekolah Trading Logic - Real-time
"""

import zmq
import time
import logging
import os
import sys
from datetime import datetime, timezone
from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'utils'))

import config
from discord_handler import send_alert, send_error_alert
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
alerted_candles = set()
stats = StatsTracker()

def check_momentum(timeframe, current_candle, previous_candle):
    """
    100% SEKOLAH TRADING LOGIC
    
    CRITICAL STEPS:
    1. Body = abs(close - open) in pips
    2. Body >= threshold (M5: 40, M15: 50)
    3. Wick filter: totalWick / (body + totalWick) <= 30%
    4. Bullish: close > open
    5. Bearish: close < open OR (close > open AND close < prev_open)
    6. Alert window: 20-90 seconds before candle close
    7. Prevent duplicate alerts per candle
    """
    global alerted_candles
    
    if not current_candle or not previous_candle:
        return
    
    # Get threshold
    threshold = config.MOMENTUM_PIPS_M5 if timeframe == "M5" else config.MOMENTUM_PIPS_M15
    
    # STEP 1: Calculate body (NOT high-low!) - SEKOLAH TRADING
    body = abs(current_candle['close'] - current_candle['open'])
    body_pips = body / config.PIP_SIZE  # 0.1 for XAUUSD
    
    # STEP 2: Check minimum body
    if body_pips < threshold:
        return
    
    # STEP 3: Wick filter (Sekolah Trading: 30% max)
    upper_wick = current_candle['high'] - max(current_candle['open'], current_candle['close'])
    lower_wick = min(current_candle['open'], current_candle['close']) - current_candle['low']
    total_wick = upper_wick + lower_wick
    
    total_range = body + total_wick
    
    if total_range == 0:
        return
    
    wick_ratio = total_wick / total_range
    
    if config.WICK_FILTER_ENABLED and wick_ratio > config.MAX_WICK_PERCENTAGE:
        logger.debug(f"{timeframe}: Body {body_pips:.1f} pips, wick {wick_ratio*100:.1f}% FILTERED")
        return
    
    # STEP 4: Determine bullish or bearish
    is_bullish = current_candle['close'] > current_candle['open']
    
    # Bearish condition: close < open OR (close > open AND close < prev_open) - INCLUDES ENGULFING
    is_red = current_candle['close'] < current_candle['open']
    is_engulfing = (current_candle['close'] > current_candle['open'] and 
                    current_candle['close'] < previous_candle['open'])
    is_bearish = is_red or is_engulfing
    
    if not (is_bullish or is_bearish):
        return
    
    # STEP 5: Alert window check (20-90 seconds before close) - FORMING CANDLE
    now = datetime.now(timezone.utc)
    current_second = int(now.timestamp())
    
    # Calculate candle close time
    tf_seconds = 300 if timeframe == "M5" else 900
    candle_start = (current_second // tf_seconds) * tf_seconds
    candle_close = candle_start + tf_seconds
    seconds_until_close = candle_close - current_second
    
    # Must be in alert window (20-90s before close)
    if not (config.ALERT_WINDOW_START <= seconds_until_close <= config.ALERT_WINDOW_END):
        return
    
    # STEP 6: Prevent duplicate alerts (use candle start time as ID)
    candle_id = f"{timeframe}_{candle_start}"
    
    if candle_id in alerted_candles:
        return  # Already alerted for this candle
    
    # STEP 7: Send alert
    is_engulfing_pattern = (is_bearish and current_candle['close'] > current_candle['open'])
    
    alert_data = {
        'symbol': config.SYMBOL,
        'timeframe': timeframe,
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
        'is_engulfing': is_engulfing_pattern,
        'prev_open': previous_candle['open'],
        'time': datetime.now(timezone.utc),
        'seconds_until_close': seconds_until_close
    }
    
    direction = "BULLISH" if is_bullish else "BEARISH"
    engulfing_flag = " [ENGULFING]" if is_engulfing_pattern else ""
    
    logger.info(f"🚨 {timeframe} MOMENTUM {direction}{engulfing_flag}: "
                f"{body_pips:.1f} pips | "
                f"O:{current_candle['open']:.2f} C:{current_candle['close']:.2f} | "
                f"Wick:{wick_ratio*100:.1f}% | "
                f"Close in {seconds_until_close}s")
    
    # Send Discord alert
    if send_alert(alert_data):
        alerted_candles.add(candle_id)
        stats.add_alert(timeframe, body_pips, is_bullish)
        
        # Clean old candle IDs (keep last 100)
        if len(alerted_candles) > 100:
            alerted_candles.pop()
    else:
        logger.error(f"Failed to send {timeframe} alert to Discord")

def process_zmq_message(message):
    """Process incoming ZeroMQ message from MT5"""
    try:
        parts = message.split("|")
        
        if parts[0] != "CANDLE":
            return
        
        # Parse message
        # Format: CANDLE|M5|broker_time|utc_time|open|high|low|close|PREV|prev_open|prev_high|prev_low|prev_close
        timeframe = parts[1]
        
        current_candle = {
            'time': int(parts[3]),        # Use UTC time (not broker time)
            'broker_time': int(parts[2]), # Keep broker time for reference
            'open': float(parts[4]),
            'high': float(parts[5]),
            'low': float(parts[6]),
            'close': float(parts[7])
        }
        
        previous_candle = {
            'open': float(parts[9]),
            'high': float(parts[10]),
            'low': float(parts[11]),
            'close': float(parts[12])
        }
        
        # Check momentum
        check_momentum(timeframe, current_candle, previous_candle)
        
    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)

def main():
    """Main ZeroMQ subscriber loop"""
    logger.info("=" * 70)
    logger.info("XAUUSD Momentum Bot - MT5 ZeroMQ Real-time")
    logger.info("Based on Sekolah Trading Logic")
    logger.info("=" * 70)
    
    # Setup ZeroMQ subscriber
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect(config.ZMQ_ENDPOINT)
    socket.setsockopt_string(zmq.SUBSCRIBE, "")  # Subscribe to all messages
    
    logger.info(f"Connecting to ZeroMQ: {config.ZMQ_ENDPOINT}")
    
    # CRITICAL: Verify connection by waiting for first message
    logger.info("Verifying ZeroMQ connection (10 second timeout)...")
    socket.setsockopt(zmq.RCVTIMEO, 10000)  # 10 second timeout
    
    try:
        test_message = socket.recv_string()
        logger.info(f"✓ ZeroMQ connection verified!")
        logger.info(f"✓ First message received: {test_message[:60]}...")
        socket.setsockopt(zmq.RCVTIMEO, -1)  # Remove timeout for normal operation
    except zmq.Again:
        logger.error("✗ NO DATA from ZeroMQ after 10 seconds!")
        logger.error("")
        logger.error("TROUBLESHOOTING:")
        logger.error("  1. Is MT5 terminal running?")
        logger.error("     Check: ps aux | grep terminal64")
        logger.error("  2. Is EA attached to XAUUSD chart?")
        logger.error("     Look for smiley face icon on chart")
        logger.error("  3. Is EA running without errors?")
        logger.error("     Check MT5 Experts tab for messages")
        logger.error("  4. Is ZeroMQ port 5555 open?")
        logger.error("     Check: netstat -tuln | grep 5555")
        logger.error("")
        if config.ENABLE_ERROR_ALERTS:
            send_error_alert("ZeroMQ Connection Failed", 
                            "No data received. Check MT5 EA is running and attached to chart.")
        socket.close()
        context.term()
        return
    except Exception as e:
        logger.error(f"✗ Connection test failed: {e}")
        socket.close()
        context.term()
        return
    
    logger.info("✓ Connection test passed - starting monitoring...")
    
    logger.info(f"Symbol: {config.SYMBOL}")
    logger.info(f"Timeframes: M5, M15")
    logger.info(f"M5: {config.MOMENTUM_PIPS_M5} pips, M15: {config.MOMENTUM_PIPS_M15} pips")
    logger.info(f"Wick Filter: {config.MAX_WICK_PERCENTAGE*100}% max")
    logger.info(f"Alert Window: {config.ALERT_WINDOW_START}-{config.ALERT_WINDOW_END}s before close")
    logger.info("=" * 70)
    logger.info("Waiting for MT5 data stream...")
    
    consecutive_errors = 0
    max_errors = 10
    
    try:
        while True:
            try:
                # Receive message (non-blocking with timeout)
                message = socket.recv_string(flags=zmq.NOBLOCK)
                process_zmq_message(message)
                consecutive_errors = 0
                
            except zmq.Again:
                # No message available, sleep briefly
                time.sleep(0.01)
                
            except Exception as e:
                error_logger.error(f"Message processing error: {e}", exc_info=True)
                consecutive_errors += 1
                
                if consecutive_errors >= max_errors:
                    logger.error("Too many consecutive errors. Exiting...")
                    if config.ENABLE_ERROR_ALERTS:
                        send_error_alert("Bot Error", f"Too many errors: {str(e)}")
                    break
                
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
EOF
    chmod +x "$INSTALL_DIR/bot.py"

    # Create utils files
    mkdir -p "$UTILS_DIR"
    
    # discord_handler.py
    cat > "$UTILS_DIR/discord_handler.py" << 'EOF'
"""Discord webhook handler - Complete implementation"""
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
        color = 65280 if data['is_bullish'] else 16711680  # Green/Red
        
        # Engulfing note
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
                {"name": "━━━━━━━━━━━━━━━━━━━━━━━", "value": "", "inline": False},
                {"name": "Body", "value": f"**{data['body_pips']} pips**", "inline": True},
                {"name": "Open", "value": f"{data['open']:.2f}", "inline": True},
                {"name": "Close", "value": f"{data['close']:.2f}", "inline": True},
                {"name": "High", "value": f"{data['high']:.2f}", "inline": True},
                {"name": "Low", "value": f"{data['low']:.2f}", "inline": True},
                {"name": "Wick %", "value": f"{data['wick_pct']:.1f}% ✓", "inline": True},
            ],
            "description": f"**Time:** {data['time'].strftime('%H:%M:%S')} UTC\n**Candle closes in:** {data['seconds_until_close']} seconds{engulfing_note}",
            "footer": {"text": "MT5 Real-time | Sekolah Trading"},
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
    """Send error notification"""
    if not WEBHOOK_URL:
        return False
    
    try:
        color = 65280 if is_recovery else 16711680
        icon = "✅" if is_recovery else "🔴"
        
        embed = {
            "title": f"{icon} {title}",
            "description": message,
            "color": color,
            "timestamp": datetime.utcnow().isoformat(),
            "footer": {"text": "XAUUSD Bot Alert System"}
        }
        
        response = requests.post(WEBHOOK_URL, json={"username": "XAUUSD Bot", "embeds": [embed]}, timeout=10)
        return response.status_code == 204
    except:
        return False
EOF

    # stats.py
    cat > "$UTILS_DIR/stats.py" << 'EOF'
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
        bull = len([a for a in self.alerts if a['is_bullish']])
        bear = total - bull
        pips = [a['pips'] for a in self.alerts]
        
        return {
            'date': self.last_reset.strftime('%Y-%m-%d'),
            'total_alerts': total,
            'bullish': bull,
            'bearish': bear,
            'bullish_pct': (bull / total * 100) if total else 0,
            'bearish_pct': (bear / total * 100) if total else 0,
            'avg_pips': sum(pips) / len(pips) if pips else 0,
            'max_pips': max(pips) if pips else 0,
            'min_pips': min(pips) if pips else 0
        }
EOF

    # __init__.py
    touch "$UTILS_DIR/__init__.py"

    # Create MT5 EA (FIXED VERSION with timezone sync)
    cat > "$INSTALL_DIR/XAUUSD_ZMQ_Server.mq5" << 'EOF'
//+------------------------------------------------------------------+
//|                                    XAUUSD_ZMQ_Server.mq5         |
//|                              Real-time Data Stream via ZeroMQ    |
//|                                   Sekolah Trading Bot Backend    |
//+------------------------------------------------------------------+
#property copyright "XAUUSD Momentum Bot"
#property version   "3.2"
#property strict

#include <Zmq/Zmq.mqh>

// Inputs
input string InpSymbol = "XAUUSD";      // Symbol to monitor
input string InpPort = "5555";          // ZeroMQ Port
input int InpBrokerUTCOffset = 0;       // Broker timezone offset from UTC (hours, e.g., +2, -5)

// ZeroMQ objects
Context context("xauusd_zmq");
Socket publisher(context, ZMQ_PUB);

//+------------------------------------------------------------------+
int OnInit()
{
    // Validate symbol exists
    if(!SymbolSelect(InpSymbol, true))
    {
        Print("ERROR: Symbol ", InpSymbol, " not found");
        return INIT_FAILED;
    }
    
    // Bind ZeroMQ publisher
    string endpoint = "tcp://*:" + InpPort;
    if(!publisher.bind(endpoint))
    {
        Print("ERROR: Failed to bind ZeroMQ to ", endpoint);
        return INIT_FAILED;
    }
    
    Print("✓ ZeroMQ Server started");
    Print("✓ Endpoint: ", endpoint);
    Print("✓ Monitoring: ", InpSymbol);
    Print("✓ Timeframes: M5, M15");
    Print("✓ Broker UTC Offset: ", InpBrokerUTCOffset, " hours");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    publisher.unbind("tcp://*:" + InpPort);
    Print("ZeroMQ Server stopped");
}

//+------------------------------------------------------------------+
void OnTick()
{
    // Update on EVERY TICK for real-time detection
    
    // Send M5 data
    SendCandleData(PERIOD_M5, "M5");
    
    // Send M15 data
    SendCandleData(PERIOD_M15, "M15");
}

//+------------------------------------------------------------------+
void SendCandleData(ENUM_TIMEFRAMES timeframe, string tfString)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    // Get last 2 candles (0=current forming, 1=previous completed)
    int copied = CopyRates(InpSymbol, timeframe, 0, 2, rates);
    if(copied < 2)
    {
        Print("ERROR: Failed to get rates for ", tfString);
        return;
    }
    
    // Current forming candle [0]
    // Previous completed candle [1]
    
    // Calculate UTC time from broker time
    datetime utc_time = rates[0].time - (InpBrokerUTCOffset * 3600);

    // Format: CANDLE|M5|broker_time|utc_time|open|high|low|close|PREV|prev_open|prev_high|prev_low|prev_close
    string message = StringFormat("CANDLE|%s|%d|%d|%.5f|%.5f|%.5f|%.5f|PREV|%.5f|%.5f|%.5f|%.5f",
        tfString,
        (int)rates[0].time,      // Broker time
        (int)utc_time,           // UTC time
        rates[0].open,
        rates[0].high,
        rates[0].low,
        rates[0].close,
        rates[1].open,
        rates[1].high,
        rates[1].low,
        rates[1].close
    );
    
    // Send via ZeroMQ
    ZmqMsg msg(message);
    publisher.send(msg);
}
//+------------------------------------------------------------------+
EOF
    
    # Also copy to MT5 directory if it exists
    MT5_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts"
    if [[ -d "$MT5_DIR" ]]; then
        cp "$INSTALL_DIR/XAUUSD_ZMQ_Server.mq5" "$MT5_DIR/" 2>/dev/null || true
    fi

    success "All bot files created"
}

create_systemd_service() {
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=XAUUSD Momentum Bot (MT5 ZeroMQ Real-time)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PYTHONUNBUFFERED=1"
ExecStart=/usr/bin/python3 $INSTALL_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

#==============================================================================
# [2-4] Service Management
#==============================================================================

start_bot() {
    clear
    echo -e "${BOLD}Starting XAUUSD Bot...${NC}\n"
    
    if ! pgrep -f "terminal64.exe" > /dev/null; then
        warn "MT5 Terminal is not running!"
        echo "Please start MT5 first:"
        echo "  wine ~/.wine/drive_c/Program\\\\ Files/MetaTrader\\\\ 5/terminal64.exe"
        echo ""
        read -p "Start MT5 now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            wine ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/terminal64.exe &
            echo "MT5 started in background. Wait 30 seconds, then retry."
            sleep 2
        fi
        read -p "Press Enter to continue..."
        return
    fi
    
    systemctl start $SERVICE_NAME
    sleep 2
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        success "Bot started successfully!"
        echo -e "\nTailing logs (Ctrl+C to stop):\n"
        timeout 5 journalctl -u $SERVICE_NAME -f || true
    else
        error "Failed to start bot"
        journalctl -u $SERVICE_NAME -n 20
    fi
    
    read -p "Press Enter to continue..."
}

stop_bot() {
    clear
    echo -e "${BOLD}${YELLOW}Stop XAUUSD Bot?${NC}\n"
    read -p "Confirm (y/n): " confirm
    
    if [[ "$confirm" == "y" ]]; then
        systemctl stop $SERVICE_NAME
        sleep 1
        if ! systemctl is-active --quiet $SERVICE_NAME; then
            success "Bot stopped"
        else
            error "Failed to stop bot"
        fi
    else
        warn "Cancelled"
    fi
    
    read -p "Press Enter to continue..."
}

restart_bot() {
    clear
    echo -e "${BOLD}Restarting XAUUSD Bot...${NC}\n"
    systemctl restart $SERVICE_NAME
    sleep 2
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        success "Bot restarted successfully!"
        echo -e "\nTailing logs:\n"
        timeout 5 journalctl -u $SERVICE_NAME -f || true
    else
        error "Failed to restart bot"
    fi
    
    read -p "Press Enter to continue..."
}

#==============================================================================
# [5] View Logs
#==============================================================================

view_logs() {
    clear
    echo -e "${BOLD}${CYAN}Live Logs (Ctrl+C to exit)${NC}\n"
    journalctl -u $SERVICE_NAME -f
}

#==============================================================================
# [6] Statistics
#==============================================================================

show_statistics() {
    clear
    echo -e "${BOLD}${CYAN}=== Bot Statistics ===${NC}\n"
    
    if [[ ! -f "$LOG_DIR/bot.log" ]]; then
        warn "No log file found"
        read -p "Press Enter to continue..."
        return
    fi
    
    TODAY=$(date +%Y-%m-%d)
    TOTAL=$(grep "$TODAY" "$LOG_DIR/bot.log" | grep -c "MOMENTUM" || echo "0")
    M5_COUNT=$(grep "$TODAY" "$LOG_DIR/bot.log" | grep "M5 MOMENTUM" | wc -l || echo "0")
    M15_COUNT=$(grep "$TODAY" "$LOG_DIR/bot.log" | grep "M15 MOMENTUM" | wc -l || echo "0")
    BULLISH=$(grep "$TODAY" "$LOG_DIR/bot.log" | grep "MOMENTUM BULLISH" | wc -l || echo "0")
    BEARISH=$(grep "$TODAY" "$LOG_DIR/bot.log" | grep "MOMENTUM BEARISH" | wc -l || echo "0")
    
    echo "Date: $TODAY"
    echo "─────────────────────────────────────"
    echo "Total Alerts:     $TOTAL"
    echo "M5 Alerts:        $M5_COUNT"
    echo "M15 Alerts:       $M15_COUNT"
    
    if [[ $TOTAL -gt 0 ]]; then
        BULLISH_PCT=$((BULLISH * 100 / TOTAL))
        BEARISH_PCT=$((BEARISH * 100 / TOTAL))
        echo "🟢 Bullish:       $BULLISH ($BULLISH_PCT%)"
        echo "🔴 Bearish:       $BEARISH ($BEARISH_PCT%)"
    else
        echo "🟢 Bullish:       0 (0%)"
        echo "🔴 Bearish:       0 (0%)"
    fi
    
    echo ""
    echo "Last 10 Alerts:"
    echo "─────────────────────────────────────"
    grep "MOMENTUM" "$LOG_DIR/bot.log" | tail -10 | while read line; do
        echo "$line" | cut -c 1-80
    done
    echo ""
    
    read -p "Press Enter to continue..."
}

#==============================================================================
# [7] Settings
#==============================================================================

settings_menu() {
    while true; do
        clear
        echo -e "${BOLD}${CYAN}=== Settings & Configuration ===${NC}\n"
        echo "[1] Change M5 Body Minimum"
        echo "[2] Change M15 Body Minimum"
        echo "[3] Update Discord Webhook URL"
        echo "[4] Update MT5 Credentials"
        echo "[5] View Current Config"
        echo "[6] Reset to Defaults"
        echo "[0] Back to Main Menu"
        echo ""
        read -p "Choice: " choice
        
        case $choice in
            1) change_m5_threshold ;;
            2) change_m15_threshold ;;
            3) change_webhook ;;
            4) change_mt5_credentials ;;
            5) view_config ;;
            6) reset_config ;;
            0) break ;;
        esac
    done
}

change_m5_threshold() {
    read -p "Enter new M5 threshold (pips): " new_val
    if [[ $new_val =~ ^[0-9]+$ ]]; then
        sed -i "s/MOMENTUM_PIPS_M5 = .*/MOMENTUM_PIPS_M5 = $new_val/" "$INSTALL_DIR/config.py"
        success "M5 threshold updated to $new_val pips"
        warn "Restart bot to apply changes"
    else
        error "Invalid number"
    fi
    read -p "Press Enter to continue..."
}

change_m15_threshold() {
    read -p "Enter new M15 threshold (pips): " new_val
    if [[ $new_val =~ ^[0-9]+$ ]]; then
        sed -i "s/MOMENTUM_PIPS_M15 = .*/MOMENTUM_PIPS_M15 = $new_val/" "$INSTALL_DIR/config.py"
        success "M15 threshold updated to $new_val pips"
        warn "Restart bot to apply changes"
    else
        error "Invalid number"
    fi
    read -p "Press Enter to continue..."
}

change_webhook() {
    read -p "Enter new Discord Webhook URL: " new_url
    if [[ -n "$new_url" ]]; then
        sed -i "s|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=$new_url|" "$INSTALL_DIR/.env"
        success "Webhook URL updated"
        warn "Restart bot to apply changes"
    fi
    read -p "Press Enter to continue..."
}

change_mt5_credentials() {
    echo "Current MT5 Login: $(grep MT5_LOGIN "$INSTALL_DIR/.env" | cut -d= -f2)"
    read -p "New MT5 Login (press Enter to keep current): " new_login
    if [[ -n "$new_login" ]]; then
        sed -i "s/MT5_LOGIN=.*/MT5_LOGIN=$new_login/" "$INSTALL_DIR/.env"
    fi
    
    echo "Current MT5 Server: $(grep MT5_SERVER "$INSTALL_DIR/.env" | cut -d= -f2)"
    read -p "New MT5 Server: " new_server
    if [[ -n "$new_server" ]]; then
        sed -i "s/MT5_SERVER=.*/MT5_SERVER=$new_server/" "$INSTALL_DIR/.env"
    fi
    
    success "MT5 credentials updated"
    read -p "Press Enter to continue..."
}

view_config() {
    clear
    echo -e "${BOLD}Current Configuration:${NC}\n"
    cat "$INSTALL_DIR/config.py"
    echo ""
    echo -e "${BOLD}Environment Variables:${NC}\n"
    grep -v "^#" "$INSTALL_DIR/.env" | grep -v "^$"
    echo ""
    read -p "Press Enter to continue..."
}

reset_config() {
    warn "This will reset all settings to defaults"
    read -p "Confirm (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        cat > "$INSTALL_DIR/config.py" << 'EOF'
"""Configuration for XAUUSD Momentum Bot - 100% Sekolah Trading Logic"""

# Symbol Settings
SYMBOL = "XAUUSD"
TIMEFRAMES = {"M5": 5, "M15": 15}

# Momentum Settings (Body minimum in pips) - SEKOLAH TRADING STANDARD
MOMENTUM_PIPS_M5 = 40
MOMENTUM_PIPS_M15 = 50

# Pip Size for XAUUSD (CRITICAL: 1 pip = 0.1 price movement)
PIP_SIZE = 0.1

# Wick Filter (Sekolah Trading: 30% maximum)
WICK_FILTER_ENABLED = True
MAX_WICK_PERCENTAGE = 0.30

# Alert Window (20-90 seconds before candle close) - REAL-TIME FORMING CANDLE
ALERT_WINDOW_START = 20
ALERT_WINDOW_END = 90

# Alert Settings
ALERT_COOLDOWN = 60

# Discord Settings
ENABLE_EMBED = True
ENABLE_ERROR_ALERTS = True
ENABLE_DAILY_SUMMARY = True
DAILY_SUMMARY_HOUR = 0

# Logging
LOG_LEVEL = "INFO"
LOG_TO_FILE = True
LOG_FILE = "/opt/xauusd-bot/logs/bot.log"
ERROR_LOG_FILE = "/opt/xauusd-bot/logs/error.log"

# ZeroMQ Settings
ZMQ_ENDPOINT = "tcp://localhost:5555"
EOF
        success "Settings reset to defaults"
        warn "Restart bot to apply changes"
    fi
    read -p "Press Enter to continue..."
}

#==============================================================================
# [8] Test Discord
#==============================================================================

test_discord() {
    clear
    echo -e "${BOLD}Testing Discord Webhook...${NC}\n"
    
    WEBHOOK=$(grep "DISCORD_WEBHOOK_URL" "$INSTALL_DIR/.env" | cut -d'=' -f2)
    
    if [[ -z "$WEBHOOK" ]] || [[ "$WEBHOOK" == "YOUR_WEBHOOK_HERE" ]]; then
        error "Webhook URL not configured"
        echo "Please update webhook in Settings menu first"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Sending test alert..."
    PAYLOAD='{"username":"XAUUSD Bot","embeds":[{"title":"✅ TEST ALERT - System Working","description":"**Bot Version:** 3.2.0\\n**Time:** '"$(date)"'\\n**Status:** ✅ Operational","color":65280,"footer":{"text":"MT5 Real-time | Sekolah Trading"}}]}'
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK")
    
    if [[ "$RESPONSE" == "204" ]]; then
        success "Discord webhook test successful!"
    else
        error "Discord webhook test failed (HTTP $RESPONSE)"
        echo "Check your webhook URL in .env file"
    fi
    
    read -p "Press Enter to continue..."
}

#==============================================================================
# [9] Maintenance
#==============================================================================

maintenance_menu() {
    while true; do
        clear
        echo -e "${BOLD}${CYAN}=== Maintenance & Tools ===${NC}\n"
        echo "[1] Check MT5 Status"
        echo "[2] Check ZeroMQ Connection"
        echo "[3] Backup Configuration"
        echo "[4] Restore from Backup"
        echo "[5] Clear Logs"
        echo "[6] View Error Logs"
        echo "[7] System Diagnostics"
        echo "[0] Back to Main Menu"
        echo ""
        read -p "Choice: " choice
        
        case $choice in
            1) check_mt5 ;;
            2) check_zmq ;;
            3) backup_config ;;
            4) restore_backup ;;
            5) clear_logs ;;
            6) view_errors ;;
            7) system_diagnostics ;;
            0) break ;;
        esac
    done
}

check_mt5() {
    clear
    echo -e "${BOLD}MT5 Status Check${NC}\n"
    
    if pgrep -f "terminal64.exe" > /dev/null; then
        success "MT5 Terminal is running"
        echo "Process Info:"
        ps aux | grep terminal64.exe | grep -v grep
    else
        error "MT5 Terminal is NOT running"
        echo "Start MT5 with:"
        echo "wine ~/.wine/drive_c/Program\\\\ Files/MetaTrader\\\\ 5/terminal64.exe &"
    fi
    
    # Check MT5 directory
    MT5_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5"
    echo ""
    echo "MT5 Directory: $MT5_DIR"
    if [[ -d "$MT5_DIR" ]]; then
        echo "✓ MT5 directory exists"
        if [[ -f "$MT5_DIR/MQL5/Experts/XAUUSD_ZMQ_Server.mq5" ]]; then
            echo "✓ EA file exists"
        else
            echo "✗ EA file missing"
        fi
    else
        echo "✗ MT5 directory not found"
    fi
    
    read -p "Press Enter to continue..."
}

check_zmq() {
    clear
    echo -e "${BOLD}ZeroMQ Connection Check${NC}\n"
    
    echo "Checking port 5555..."
    if netstat -tuln 2>/dev/null | grep -q ":5555 "; then
        success "Port 5555 is listening"
        netstat -tuln | grep 5555
    else
        error "Port 5555 is NOT listening"
        echo "Possible reasons:"
        echo "1. EA not attached to chart"
        echo "2. EA not compiled"
        echo "3. ZeroMQ not installed"
        echo "4. MT5 not running"
    fi
    
    echo ""
    echo "Checking ZeroMQ files..."
    ZMQ_DLL=$(find ~/.wine -name "libzmq.dll" 2>/dev/null | head -1)
    ZMQ_MQH=$(find ~/.wine -name "Zmq.mqh" 2>/dev/null | head -1)
    
    if [[ -f "$ZMQ_DLL" ]]; then
        echo "✓ libzmq.dll found: $ZMQ_DLL"
    else
        echo "✗ libzmq.dll not found"
    fi
    
    if [[ -f "$ZMQ_MQH" ]]; then
        echo "✓ Zmq.mqh found: $ZMQ_MQH"
    else
        echo "✗ Zmq.mqh not found"
    fi
    
    read -p "Press Enter to continue..."
}

backup_config() {
    BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$INSTALL_DIR" config.py .env 2>/dev/null
    success "Backup created: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    read -p "Press Enter to continue..."
}

restore_backup() {
    echo "Available backups:"
    ls -la "$BACKUP_DIR/"*.tar.gz 2>/dev/null | nl || {
        warn "No backups found"
        read -p "Press Enter to continue..."
        return
    }
    
    echo ""
    read -p "Backup number to restore (0 to cancel): " backup_num
    
    if [[ $backup_num -gt 0 ]]; then
        backup_file=$(ls "$BACKUP_DIR/"*.tar.gz | sed -n "${backup_num}p")
        if [[ -f "$backup_file" ]]; then
            echo "Restoring from $backup_file..."
            tar -xzf "$backup_file" -C "$INSTALL_DIR"
            success "Configuration restored"
            warn "Restart bot to apply changes"
        else
            error "Backup file not found"
        fi
    fi
    read -p "Press Enter to continue..."
}

clear_logs() {
    warn "This will delete all log files"
    read -p "Confirm (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        rm -f "$LOG_DIR"/*.log 2>/dev/null
        success "Logs cleared"
    fi
    read -p "Press Enter to continue..."
}

view_errors() {
    clear
    echo -e "${BOLD}Error Logs:${NC}\n"
    if [[ -f "$LOG_DIR/error.log" ]]; then
        tail -50 "$LOG_DIR/error.log"
    else
        warn "No error log found"
    fi
    read -p "Press Enter to continue..."
}

system_diagnostics() {
    clear
    echo -e "${BOLD}System Diagnostics${NC}\n"
    echo "Bot Status:     $(get_bot_status)"
    echo "MT5 Running:    $(check_mt5_running)"
    echo "ZeroMQ Port:    $(check_zmq_port)"
    echo "Python Version: $(python3 --version 2>/dev/null)"
    echo "Wine Version:   $(wine --version 2>/dev/null || echo 'Not found')"
    echo ""
    echo "Disk Usage:"
    df -h "$INSTALL_DIR" 2>/dev/null || echo "N/A"
    echo ""
    echo "Memory Usage:"
    free -h
    echo ""
    read -p "Press Enter to continue..."
}

#==============================================================================
# [10] Uninstall
#==============================================================================

uninstall_bot() {
    clear
    echo -e "${BOLD}${RED}=== UNINSTALL BOT ===${NC}\n"
    warn "This will remove all bot files and configuration"
    echo ""
    read -p "Type 'UNINSTALL' to confirm: " confirm
    
    if [[ "$confirm" != "UNINSTALL" ]]; then
        warn "Uninstall cancelled"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Stopping service..."
    systemctl stop $SERVICE_NAME 2>/dev/null || true
    systemctl disable $SERVICE_NAME 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    
    echo "Removing files..."
    rm -rf "$INSTALL_DIR"
    
    success "Bot uninstalled successfully"
    echo ""
    read -p "Press Enter to exit..."
    exit 0
}

#==============================================================================
# Main Loop
#==============================================================================

main() {
    # Create install log directory
    mkdir -p "$(dirname "$INSTALL_LOG")"
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1) install_bot ;;
            2) start_bot ;;
            3) stop_bot ;;
            4) restart_bot ;;
            5) view_logs ;;
            6) show_statistics ;;
            7) settings_menu ;;
            8) test_discord ;;
            9) maintenance_menu ;;
            10) uninstall_bot ;;
            0) 
                clear
                echo -e "${CYAN}${BOLD}"
                echo "═══════════════════════════════════════"
                echo "  Thank you for using XAUUSD Bot!"
                echo "  Stay profitable! 🚀"
                echo "═══════════════════════════════════════"
                echo -e "${NC}"
                exit 0
                ;;
            *) 
                error "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Run main
main