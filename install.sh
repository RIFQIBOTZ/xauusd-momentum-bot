#!/bin/bash

#==============================================================================
# XAUUSD Momentum Bot - Complete Installation & Management System
# Version 3.0.0 - Production Ready
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
║              Version 3.0.0                                ║
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
            cp -r "$INSTALL_DIR" "$BACKUP_DIR/$BACKUP_NAME"
            success "Backup created: $BACKUP_DIR/$BACKUP_NAME"
        fi
    fi

    # Get configuration
    echo -e "\n${BOLD}Configuration:${NC}"
    read -p "Discord Webhook URL: " WEBHOOK_URL
    
    if [[ ! "$WEBHOOK_URL" =~ ^https://discord.com/api/webhooks/ ]]; then
        error "Invalid Discord webhook URL"
        read -p "Press Enter to continue..."
        return
    fi

    read -p "MT5 Login (optional, press Enter to skip): " MT5_LOGIN
    read -p "MT5 Password (optional): " MT5_PASSWORD
    read -p "MT5 Server (e.g., FBS-Demo): " MT5_SERVER
    read -p "M5 Body Minimum (pips) [40]: " M5_PIPS
    M5_PIPS=${M5_PIPS:-40}
    read -p "M15 Body Minimum (pips) [50]: " M15_PIPS
    M15_PIPS=${M15_PIPS:-50}

    # Confirmation
    echo -e "\n${BOLD}Configuration Summary:${NC}"
    echo "Discord Webhook: ${WEBHOOK_URL:0:50}..."
    echo "M5 Threshold: $M5_PIPS pips"
    echo "M15 Threshold: $M15_PIPS pips"
    echo ""
    read -p "Proceed with installation? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        warn "Installation cancelled"
        read -p "Press Enter to continue..."
        return
    fi

    # Start installation
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$UTILS_DIR"
    mkdir -p "$BACKUP_DIR"
    
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
    apt-get install -y wine-stable wine64 wget unzip netstat-nat >> "$INSTALL_LOG" 2>&1
    success "Wine installed"

    # [3/10] Download MT5
    progress 3 "Downloading MT5"
    cd /tmp
    wget -q https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O mt5setup.exe
    success "MT5 downloaded"

    # [4/10] Install MT5
    progress 4 "Installing MT5"
    WINEPREFIX="$HOME/.wine" wine mt5setup.exe /auto >> "$INSTALL_LOG" 2>&1 &
    sleep 30
    pkill -f mt5setup.exe
    success "MT5 installed"

    # [5/10] Install ZeroMQ
    progress 5 "Installing ZeroMQ for MT5"
    cd /tmp
    wget -q https://github.com/dingmaotu/mql-zmq/releases/download/v4.3.4/mql-zmq-4.3.4-x64.zip -O zmq.zip
    unzip -q -o zmq.zip
    
    MT5_DIR="$HOME/.wine/drive_c/Program Files/MetaTrader 5"
    LIBS_DIR="$MT5_DIR/MQL5/Libraries"
    INCLUDE_DIR="$MT5_DIR/MQL5/Include/Zmq"
    
    mkdir -p "$LIBS_DIR"
    mkdir -p "$INCLUDE_DIR"
    
    cp Library/MT5/x64/libzmq.dll "$LIBS_DIR/" 2>/dev/null || true
    cp Include/Mql/*.mqh "$INCLUDE_DIR/" 2>/dev/null || true
    
    if [[ -f "$LIBS_DIR/libzmq.dll" ]]; then
        success "ZeroMQ installed"
    else
        warn "ZeroMQ installation needs manual verification"
    fi

    # [6/10] Install Python packages
    progress 6 "Installing Python packages"
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
    chown -R root:root "$INSTALL_DIR"
    success "Permissions set"

    # [10/10] Complete
    progress 10 "Installation complete"
    success "Done!"

    echo -e "\n${GREEN}${BOLD}Installation Successful!${NC}\n"
    echo -e "${YELLOW}${BOLD}MANUAL STEPS REQUIRED:${NC}"
    echo "1. Start MT5 Terminal: wine ~/.wine/drive_c/Program\\ Files/MetaTrader\\ 5/terminal64.exe"
    echo "2. Login to your MT5 account"
    echo "3. Copy XAUUSD_ZMQ_Server.mq5 to MT5 Experts folder"
    echo "4. Compile the EA in MetaEditor"
    echo "5. Attach EA to XAUUSD chart (any timeframe)"
    echo "6. Enable AutoTrading (Ctrl+E)"
    echo "7. Start bot: systemctl start $SERVICE_NAME"
    echo ""
    echo "EA Location: $MT5_DIR/MQL5/Experts/XAUUSD_ZMQ_Server.mq5"
    echo ""
    read -p "Press Enter to continue..."
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
    cat > "$INSTALL_DIR/.env" << 'EOF'
DISCORD_WEBHOOK_URL=WEBHOOK_PLACEHOLDER
MT5_LOGIN=LOGIN_PLACEHOLDER
MT5_PASSWORD=PASSWORD_PLACEHOLDER
MT5_SERVER=SERVER_PLACEHOLDER
ZMQ_PORT=5555
EOF
    
    sed -i "s|WEBHOOK_PLACEHOLDER|$webhook|" "$INSTALL_DIR/.env"
    sed -i "s|LOGIN_PLACEHOLDER|$login|" "$INSTALL_DIR/.env"
    sed -i "s|PASSWORD_PLACEHOLDER|$password|" "$INSTALL_DIR/.env"
    sed -i "s|SERVER_PLACEHOLDER|$server|" "$INSTALL_DIR/.env"

    # Create config.py
    cat > "$INSTALL_DIR/config.py" << EOF
"""Configuration for XAUUSD Momentum Bot"""

# Symbol Settings
SYMBOL = "XAUUSD"
TIMEFRAMES = {"M5": 5, "M15": 15}

# Momentum Settings (Body minimum in pips)
MOMENTUM_PIPS_M5 = $m5_pips
MOMENTUM_PIPS_M15 = $m15_pips

# Pip Size
PIP_SIZE = 0.1  # For XAUUSD, 1 pip = 0.1 price movement

# Wick Filter (Sekolah Trading standard)
WICK_FILTER_ENABLED = True
MAX_WICK_PERCENTAGE = 0.30  # 30% maximum wick

# Alert Window (20-90 seconds before candle close)
ALERT_WINDOW_START = 20  # seconds
ALERT_WINDOW_END = 90    # seconds

# Alert Settings
ALERT_COOLDOWN = 60  # seconds between alerts (additional safety)

# Discord Settings
ENABLE_EMBED = True
ENABLE_ERROR_ALERTS = True
ENABLE_DAILY_SUMMARY = True
DAILY_SUMMARY_HOUR = 0  # UTC hour for daily summary

# Logging
LOG_LEVEL = "INFO"
LOG_TO_FILE = True
LOG_FILE = "$LOG_DIR/bot.log"
ERROR_LOG_FILE = "$LOG_DIR/error.log"

# ZeroMQ Settings
ZMQ_ENDPOINT = "tcp://localhost:5555"
EOF

    # Create bot.py
    wget -q https://gist.githubusercontent.com/PLACEHOLDER/bot.py -O "$INSTALL_DIR/bot.py" 2>/dev/null || create_bot_py_inline
    
    # Create utils
    mkdir -p "$UTILS_DIR"
    create_utils_files
    
    # Create MT5 EA
    create_mt5_ea
    
    success "All files created"
}

create_bot_py_inline() {
    cat > "$INSTALL_DIR/bot.py" << 'EOFPY'
#!/usr/bin/env python3
import zmq, time, logging, os, sys
from datetime import datetime, timezone
from dotenv import load_dotenv

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'utils'))
import config
from discord_handler import send_alert
from stats import StatsTracker

load_dotenv()
os.makedirs(os.path.dirname(config.LOG_FILE), exist_ok=True)

logging.basicConfig(level=getattr(logging, config.LOG_LEVEL),
    format='[%(asctime)s] %(levelname)s: %(message)s',
    handlers=[logging.StreamHandler(), logging.FileHandler(config.LOG_FILE)])

logger = logging.getLogger(__name__)
alerted_candles = set()
stats = StatsTracker()

def check_momentum(tf, curr, prev):
    global alerted_candles
    if not curr or not prev: return
    
    threshold = config.MOMENTUM_PIPS_M5 if tf == "M5" else config.MOMENTUM_PIPS_M15
    body = abs(curr['close'] - curr['open'])
    body_pips = body / config.PIP_SIZE
    
    if body_pips < threshold: return
    
    upper_wick = curr['high'] - max(curr['open'], curr['close'])
    lower_wick = min(curr['open'], curr['close']) - curr['low']
    total_wick = upper_wick + lower_wick
    total_range = body + total_wick
    
    if total_range == 0: return
    wick_ratio = total_wick / total_range
    if config.WICK_FILTER_ENABLED and wick_ratio > config.MAX_WICK_PERCENTAGE: return
    
    is_bullish = curr['close'] > curr['open']
    is_red = curr['close'] < curr['open']
    is_engulfing = (curr['close'] > curr['open'] and curr['close'] < prev['open'])
    is_bearish = is_red or is_engulfing
    
    if not (is_bullish or is_bearish): return
    
    now = datetime.now(timezone.utc)
    current_second = int(now.timestamp())
    tf_seconds = 300 if tf == "M5" else 900
    candle_start = (current_second // tf_seconds) * tf_seconds
    candle_close = candle_start + tf_seconds
    seconds_until_close = candle_close - current_second
    
    if not (config.ALERT_WINDOW_START <= seconds_until_close <= config.ALERT_WINDOW_END): return
    
    candle_id = f"{tf}_{candle_start}"
    if candle_id in alerted_candles: return
    
    alert_data = {
        'symbol': config.SYMBOL, 'timeframe': tf, 'body_pips': round(body_pips, 1),
        'open': curr['open'], 'high': curr['high'], 'low': curr['low'], 'close': curr['close'],
        'upper_wick': upper_wick, 'lower_wick': lower_wick, 'wick_pct': round(wick_ratio * 100, 1),
        'is_bullish': is_bullish, 'is_bearish': is_bearish,
        'is_engulfing': is_engulfing, 'prev_open': prev['open'],
        'time': now, 'seconds_until_close': seconds_until_close
    }
    
    logger.info(f"🚨 {tf} {'BULLISH' if is_bullish else 'BEARISH'}: {body_pips:.1f} pips")
    
    if send_alert(alert_data):
        alerted_candles.add(candle_id)
        stats.add_alert(tf, body_pips, is_bullish)
        if len(alerted_candles) > 100: alerted_candles.pop()

def process_zmq_message(msg):
    try:
        parts = msg.split("|")
        if parts[0] != "CANDLE": return
        tf = parts[1]
        curr = {'time': int(parts[2]), 'open': float(parts[3]), 'high': float(parts[4]),
                'low': float(parts[5]), 'close': float(parts[6])}
        prev = {'open': float(parts[8]), 'high': float(parts[9]),
                'low': float(parts[10]), 'close': float(parts[11])}
        check_momentum(tf, curr, prev)
    except Exception as e:
        logger.error(f"Error: {e}")

def main():
    logger.info("="*70)
    logger.info("XAUUSD Momentum Bot - MT5 ZeroMQ Real-time")
    logger.info("="*70)
    
    context = zmq.Context()
    socket = context.socket(zmq.SUB)
    socket.connect(config.ZMQ_ENDPOINT)
    socket.setsockopt_string(zmq.SUBSCRIBE, "")
    
    logger.info(f"✓ Connected: {config.ZMQ_ENDPOINT}")
    logger.info(f"M5: {config.MOMENTUM_PIPS_M5} pips, M15: {config.MOMENTUM_PIPS_M15} pips")
    
    try:
        while True:
            try:
                msg = socket.recv_string(flags=zmq.NOBLOCK)
                process_zmq_message(msg)
            except zmq.Again:
                time.sleep(0.01)
    except KeyboardInterrupt:
        logger.info("Bot stopped")
    finally:
        socket.close()
        context.term()

if __name__ == "__main__":
    main()
EOFPY
    chmod +x "$INSTALL_DIR/bot.py"
}

create_utils_files() {
    # discord_handler.py
    cat > "$UTILS_DIR/discord_handler.py" << 'EOFPY'
import requests, logging, os
from datetime import datetime

logger = logging.getLogger(__name__)
WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL")

def send_alert(data):
    if not WEBHOOK_URL: return False
    try:
        direction = "🟢 BULLISH" if data['is_bullish'] else "🔴 BEARISH"
        color = 65280 if data['is_bullish'] else 16711680
        engulfing = f"\n⚠️ Engulfing: Close {data['close']:.2f} < Prev Open {data['prev_open']:.2f}" if data['is_engulfing'] else ""
        
        embed = {
            "title": "🚨 MOMENTUM DETECTED!",
            "color": color,
            "fields": [
                {"name": "Pair", "value": data['symbol'], "inline": True},
                {"name": "TF", "value": data['timeframe'], "inline": True},
                {"name": "Type", "value": direction, "inline": True},
                {"name": "Body", "value": f"**{data['body_pips']} pips**", "inline": True},
                {"name": "Open", "value": f"{data['open']:.2f}", "inline": True},
                {"name": "Close", "value": f"{data['close']:.2f}", "inline": True},
            ],
            "description": f"**Time:** {data['time'].strftime('%H:%M:%S')} UTC\n**Closes in:** {data['seconds_until_close']}s{engulfing}",
            "footer": {"text": "MT5 Real-time | Sekolah Trading"}
        }
        
        r = requests.post(WEBHOOK_URL, json={"username": "XAUUSD Bot", "embeds": [embed]}, timeout=10)
        return r.status_code == 204
    except: return False
EOFPY

    # stats.py
    cat > "$UTILS_DIR/stats.py" << 'EOFPY'
from datetime import datetime, timezone

class StatsTracker:
    def __init__(self):
        self.alerts = []
        self.last_reset = datetime.now(timezone.utc).date()
    
    def add_alert(self, tf, pips, is_bull):
        self.alerts.append({'timeframe': tf, 'pips': pips, 'is_bullish': is_bull, 'timestamp': datetime.now(timezone.utc)})
EOFPY

    # __init__.py
    touch "$UTILS_DIR/__init__.py"
}

create_mt5_ea() {
    MT5_EXPERTS="$HOME/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts"
    mkdir -p "$MT5_EXPERTS"
    
    cat > "$MT5_EXPERTS/XAUUSD_ZMQ_Server.mq5" << 'EOFMQL'
//+------------------------------------------------------------------+
#property copyright "XAUUSD Momentum Bot"
#property version   "3.0"
#include <Zmq/Zmq.mqh>

input string InpSymbol = "XAUUSD";
input string InpPort = "5555";

Context context("xauusd_zmq");
Socket publisher(context, ZMQ_PUB);

int OnInit() {
    if(!SymbolSelect(InpSymbol, true)) {
        Print("ERROR: Symbol not found");
        return INIT_FAILED;
    }
    if(!publisher.bind("tcp://*:" + InpPort)) {
        Print("ERROR: ZeroMQ bind failed");
        return INIT_FAILED;
    }
    Print("✓ ZMQ Server started on port ", InpPort);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    publisher.unbind("tcp://*:" + InpPort);
}

void OnTick() {
    SendCandleData(PERIOD_M5, "M5");
    SendCandleData(PERIOD_M15, "M15");
}

void SendCandleData(ENUM_TIMEFRAMES tf, string tfStr) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(InpSymbol, tf, 0, 2, rates) < 2) return;
    
    string msg = StringFormat("CANDLE|%s|%d|%.5f|%.5f|%.5f|%.5f|PREV|%.5f|%.5f|%.5f|%.5f",
        tfStr, (int)rates[0].time, rates[0].open, rates[0].high, rates[0].low, rates[0].close,
        rates[1].open, rates[1].high, rates[1].low, rates[1].close);
    
    ZmqMsg zmsg(msg);
    publisher.send(zmsg);
}
//+------------------------------------------------------------------+
EOFMQL
    
    success "MT5 EA created at: $MT5_EXPERTS/XAUUSD_ZMQ_Server.mq5"
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
        echo "Please start MT5 first, then retry"
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
        success "Bot stopped"
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
    read -p "Press Enter to continue..."
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
    echo "🟢 Bullish:       $BULLISH ($(( TOTAL > 0 ? BULLISH * 100 / TOTAL : 0 ))%)"
    echo "🔴 Bearish:       $BEARISH ($(( TOTAL > 0 ? BEARISH * 100 / TOTAL : 0 ))%)"
    echo ""
    echo "Last 10 Alerts:"
    echo "─────────────────────────────────────"
    grep "MOMENTUM" "$LOG_DIR/bot.log" | tail -10
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
        echo "[4] View Current Config"
        echo "[5] Reset to Defaults"
        echo "[0] Back to Main Menu"
        echo ""
        read -p "Choice: " choice
        
        case $choice in
            1) change_m5_threshold ;;
            2) change_m15_threshold ;;
            3) change_webhook ;;
            4) view_config ;;
            5) reset_config ;;
            0) break ;;
        esac
    done
}

change_m5_threshold() {
    read -p "Enter new M5 threshold (pips): " new_val
    sed -i "s/MOMENTUM_PIPS_M5 = .*/MOMENTUM_PIPS_M5 = $new_val/" "$INSTALL_DIR/config.py"
    success "M5 threshold updated to $new_val pips"
    warn "Restart bot to apply changes"
    read -p "Press Enter to continue..."
}

change_m15_threshold() {
    read -p "Enter new M15 threshold (pips): " new_val
    sed -i "s/MOMENTUM_PIPS_M15 = .*/MOMENTUM_PIPS_M15 = $new_val/" "$INSTALL_DIR/config.py"
    success "M15 threshold updated to $new_val pips"
    warn "Restart bot to apply changes"
    read -p "Press Enter to continue..."
}

change_webhook() {
    read -p "Enter new Discord Webhook URL: " new_url
    sed -i "s|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL=$new_url|" "$INSTALL_DIR/.env"
    success "Webhook URL updated"
    warn "Restart bot to apply changes"
    read -p "Press Enter to continue..."
}

view_config() {
    clear
    echo -e "${BOLD}Current Configuration:${NC}\n"
    cat "$INSTALL_DIR/config.py"
    echo ""
    read -p "Press Enter to continue..."
}

reset_config() {
    warn "This will reset all settings to defaults"
    read -p "Confirm (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        sed -i "s/MOMENTUM_PIPS_M5 = .*/MOMENTUM_PIPS_M5 = 40/" "$INSTALL_DIR/config.py"
        sed -i "s/MOMENTUM_PIPS_M15 = .*/MOMENTUM_PIPS_M15 = 50/" "$INSTALL_DIR/config.py"
        success "Settings reset to defaults"
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
    
    if [[ -z "$WEBHOOK" ]]; then
        error "Webhook URL not configured"
        read -p "Press Enter to continue..."
        return
    fi
    
    PAYLOAD='{"username":"XAUUSD Bot","content":"✅ Test Alert - System Working!"}'
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK")
    
    if [[ "$RESPONSE" == "204" ]]; then
        success "Discord webhook test successful!"
    else
        error "Discord webhook test failed (HTTP $RESPONSE)"
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
        echo "[4] Clear Logs"
        echo "[5] View Error Logs"
        echo "[6] System Diagnostics"
        echo "[0] Back to Main Menu"
        echo ""
        read -p "Choice: " choice
        
        case $choice in
            1) check_mt5 ;;
            2) check_zmq ;;
            3) backup_config ;;
            4) clear_logs ;;
            5) view_errors ;;
            6) system_diagnostics ;;
            0) break ;;
        esac
    done
}

check_mt5() {
    clear
    echo -e "${BOLD}MT5 Status Check${NC}\n"
    
    if pgrep -f "terminal64.exe" > /dev/null; then
        success "MT5 Terminal is running"
        ps aux | grep terminal64.exe | grep -v grep
    else
        error "MT5 Terminal is NOT running"
    fi
    
    read -p "Press Enter to continue..."
}

check_zmq() {
    clear
    echo -e "${BOLD}ZeroMQ Connection Check${NC}\n"
    
    if netstat -tuln | grep -q ":5555 "; then
        success "Port 5555 is listening"
        netstat -tuln | grep 5555
    else
        error "Port 5555 is NOT listening"
    fi
    
    read -p "Press Enter to continue..."
}

backup_config() {
    BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$INSTALL_DIR" config.py .env
    success "Backup created: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    read -p "Press Enter to continue..."
}

clear_logs() {
    warn "This will delete all log files"
    read -p "Confirm (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        rm -f "$LOG_DIR"/*.log
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
    echo "Python Version: $(python3 --version)"
    echo "Wine Version:   $(wine --version 2>/dev/null || echo 'Not installed')"
    echo ""
    echo "Disk Usage:"
    df -h "$INSTALL_DIR" 2>/dev/null || echo "N/A"
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