#!/bin/bash

# Hot Reload Server pentru CycleApp
# Monitorizează modificările și rebuild automat

set -e

PROJECT_DIR="/Users/mihai/Developer/cycle.app-frontend-swift"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
SIMULATOR="iPhone 17 Pro"
BUNDLE_ID="app.cycle.ios"
PORT=8080

# Culori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           🔥 HOT RELOAD SERVER - CycleApp 🔥                ║"
echo "║                                                              ║"
echo "║  Editează fișiere .swift în VS Code și salvează (⌘+S)       ║"
echo "║  App-ul se va actualiza automat pe simulator!               ║"
echo "║                                                              ║"
echo "║  Server: http://localhost:$PORT                              ║"
echo "║  Press Ctrl+C to stop                                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

cd "$PROJECT_DIR"

# Verifică dacă fswatch e instalat
if ! command -v fswatch &> /dev/null; then
    echo -e "${YELLOW}📦 Installing fswatch...${NC}"
    brew install fswatch
fi

# Pornește simulatorul
echo -e "${BLUE}📱 Starting simulator...${NC}"
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
open -a Simulator

# Build inițial
build_and_run() {
    echo -e "${YELLOW}🔨 Building...${NC}"
    
    if xcodebuild -project CycleApp.xcodeproj \
        -scheme CycleApp \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -quiet \
        build 2>&1; then
        
        # Găsește app-ul (exclude Index.noindex)
        APP_PATH=$(find "$DERIVED_DATA" -name "CycleApp.app" -path "*/Build/Products/*" -not -path "*Index.noindex*" -type d 2>/dev/null | head -1)
        
        if [ -n "$APP_PATH" ]; then
            echo -e "${BLUE}📲 Installing...${NC}"
            xcrun simctl install "$SIMULATOR" "$APP_PATH"
            
            echo -e "${BLUE}🚀 Launching...${NC}"
            xcrun simctl terminate "$SIMULATOR" "$BUNDLE_ID" 2>/dev/null || true
            xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID"
            
            echo -e "${GREEN}✅ Hot reload complete! $(date '+%H:%M:%S')${NC}"
            echo ""
        else
            echo -e "${RED}❌ App not found${NC}"
        fi
    else
        echo -e "${RED}❌ Build failed${NC}"
    fi
}

# Build inițial
build_and_run

# Timestamp pentru debounce
LAST_BUILD=0
DEBOUNCE=2

# Monitorizează fișierele
echo -e "${CYAN}👀 Watching for changes...${NC}"
echo ""

fswatch -o \
    --exclude '\.git' \
    --exclude 'build' \
    --exclude 'DerivedData' \
    --exclude '\.swp' \
    --exclude '\.DS_Store' \
    --include '\.swift$' \
    "$PROJECT_DIR/CycleApp" \
    "$PROJECT_DIR/Packages" \
    | while read -r event; do
        CURRENT=$(date +%s)
        if [ $((CURRENT - LAST_BUILD)) -ge $DEBOUNCE ]; then
            LAST_BUILD=$CURRENT
            echo -e "${YELLOW}📝 Change detected!${NC}"
            build_and_run
        fi
    done
