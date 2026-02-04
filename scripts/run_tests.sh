#!/bin/bash

# Default values
SCHEME="Lemon"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

# Mode: test or build
MODE="${1:-test}"

# Check if xcpretty is installed for better output formatting
if command -v xcpretty >/dev/null 2>&1; then
    USE_XCPRETTY=true
else
    USE_XCPRETTY=false
    echo "Note: xcpretty not found. Install it with 'gem install xcpretty' for better output formatting."
fi

echo "Running '$MODE' for Scheme: $SCHEME"
echo "Destination: $DESTINATION"

# Build and Test command
if [ "$MODE" = "build" ]; then
    CMD="xcodebuild build -scheme \"$SCHEME\" -destination \"$DESTINATION\""
else
    CMD="xcodebuild test -scheme \"$SCHEME\" -destination \"$DESTINATION\" -resultBundlePath TestResults"
fi

echo "Executing: $CMD"

if [ "$USE_XCPRETTY" = true ]; then
    eval "$CMD" | xcpretty
else
    eval "$CMD"
fi
