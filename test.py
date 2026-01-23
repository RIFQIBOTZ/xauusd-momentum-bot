#!/usr/bin/env python3
"""
Test Script - Validate XAUUSD Bot Setup
Tests WebSocket connection and Discord webhook without running full bot
"""

import sys
import json

def test_imports():
    """Test if required packages are available"""
    print("Testing Python imports...")
    try:
        import websocket
        print("  ✓ websocket-client")
    except ImportError:
        print("  ✗ websocket-client - Run: pip install websocket-client")
        return False
    
    try:
        import requests
        print("  ✓ requests")
    except ImportError:
        print("  ✗ requests - Run: pip install requests")
        return False
    
    return True

def test_websocket():
    """Test connection to Bybit WebSocket"""
    print("\nTesting Bybit WebSocket connection...")
    try:
        import websocket
        import ssl
        
        ws = websocket.create_connection(
            "wss://stream.bybit.com/v5/public/linear",
            timeout=10,
            sslopt={"cert_reqs": ssl.CERT_NONE}
        )
        
        # Subscribe to test
        subscribe = {
            "op": "subscribe",
            "args": ["kline.5.XAUUSDT"]
        }
        ws.send(json.dumps(subscribe))
        
        # Wait for response
        result = ws.recv()
        data = json.loads(result)
        
        ws.close()
        
        if 'success' in data and data['success']:
            print("  ✓ WebSocket connection successful")
            print(f"  ✓ Subscription confirmed: {data}")
            return True
        else:
            print(f"  ✗ Subscription failed: {data}")
            return False
            
    except Exception as e:
        print(f"  ✗ WebSocket connection failed: {e}")
        return False

def test_discord(webhook_url):
    """Test Discord webhook"""
    print("\nTesting Discord webhook...")
    
    if not webhook_url or webhook_url == "YOUR_DISCORD_WEBHOOK_URL":
        print("  ⚠ No webhook URL provided - skipping Discord test")
        return True
    
    try:
        import requests
        
        test_message = {
            "embeds": [{
                "title": "✅ Test Alert",
                "description": "XAUUSD Bot test successful!",
                "color": 3447003
            }]
        }
        
        response = requests.post(webhook_url, json=test_message, timeout=10)
        
        if response.status_code == 204:
            print("  ✓ Discord webhook working!")
            return True
        else:
            print(f"  ✗ Discord webhook failed: HTTP {response.status_code}")
            return False
            
    except Exception as e:
        print(f"  ✗ Discord webhook error: {e}")
        return False

def main():
    print("=" * 60)
    print("XAUUSD Momentum Bot - Installation Test")
    print("=" * 60)
    print()
    
    # Test imports
    if not test_imports():
        print("\n❌ Import test failed - install requirements first")
        print("   Run: pip install -r requirements.txt")
        sys.exit(1)
    
    # Test WebSocket
    if not test_websocket():
        print("\n❌ WebSocket test failed - check internet connection")
        sys.exit(1)
    
    # Test Discord (optional)
    webhook = input("\nEnter Discord webhook URL to test (or press Enter to skip): ").strip()
    if webhook:
        test_discord(webhook)
    
    print("\n" + "=" * 60)
    print("✅ ALL TESTS PASSED!")
    print("=" * 60)
    print("\nYour VPS is ready to run the bot.")
    print("Proceed with: sudo ./install.sh")

if __name__ == "__main__":
    main()
