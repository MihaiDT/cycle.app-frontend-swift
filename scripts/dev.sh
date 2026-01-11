#!/bin/bash
# Quick rebuild and install script
# Usage: ./scripts/dev.sh

cd "$(dirname "$0")/.."

echo "🔨 Building..."
xcodebuild -project CycleApp.xcodeproj \
  -scheme CycleApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  build 2>&1 | grep -E "(error:|warning:.*error|BUILD)" | tail -5

if [ $? -eq 0 ]; then
  echo "📱 Installing..."
  APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "CycleApp.app" -path "*/Build/Products/*" -not -path "*Index.noindex*" -type d 2>/dev/null | head -1)
  xcrun simctl terminate "iPhone 17 Pro" app.cycle.ios 2>/dev/null
  xcrun simctl install "iPhone 17 Pro" "$APP_PATH"
  xcrun simctl launch "iPhone 17 Pro" app.cycle.ios
  echo "✅ Done!"
else
  echo "❌ Build failed"
fi
