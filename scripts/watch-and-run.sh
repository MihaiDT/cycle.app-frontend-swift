#!/bin/bash

# Fast Refresh Script pentru CycleApp
# Monitorizează schimbările și reinstalează aplicația pe simulator

PROJECT_DIR="/Users/mihai/Developer/cycle.app-frontend-swift"
SCHEME="CycleApp"
BUNDLE_ID="app.cycle.ios"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"

cd "$PROJECT_DIR"

echo "🔄 Fast Refresh Mode - Watching for changes..."
echo "   Press Ctrl+C to stop"
echo ""

# Funcție pentru build și run
build_and_run() {
    echo "🔨 Building..."
    
    # Build incremental (foarte rapid după primul build)
    if xcodebuild -project CycleApp.xcodeproj \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -configuration Debug \
        build 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -3; then
        
        # Găsește app-ul compilat
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/CycleApp-*/Build/Products/Debug-iphonesimulator -name "CycleApp.app" -type d 2>/dev/null | head -1)
        
        if [ -n "$APP_PATH" ]; then
            echo "📲 Installing & Launching..."
            xcrun simctl install booted "$APP_PATH" 2>/dev/null
            xcrun simctl launch booted "$BUNDLE_ID" 2>/dev/null
            echo "✅ Done! App refreshed."
        fi
    fi
    echo ""
}

# Prima rulare
build_and_run

# Monitorizare fișiere
fswatch -o \
    --exclude ".*\.git.*" \
    --exclude ".*DerivedData.*" \
    --exclude ".*\.build.*" \
    --exclude ".*xcuserdata.*" \
    --include ".*\.swift$" \
    "$PROJECT_DIR/CycleApp" \
    "$PROJECT_DIR/Packages" | while read; do
    echo "📁 Changes detected!"
    build_and_run
done
