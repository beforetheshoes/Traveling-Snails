#!/bin/bash

# Traveling Snails Test Runner
# Standard test command that can be reused consistently

cd "/Users/ryan/Developer/Swift/Traveling Snails"

echo "Running Traveling Snails Tests..."
echo "================================="

xcodebuild test -scheme "Traveling Snails" -destination "platform=iOS Simulator,name=iPhone 16" | xcbeautify

echo "Tests completed."