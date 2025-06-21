#!/bin/bash

echo "Running NSUbiquitousKeyValueStore tests..."

cd "/Users/ryan/Developer/Swift/Traveling Snails"

# Try running just the settings tests
xcodebuild test \
  -scheme "Traveling Snails" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -testPlan "NSUbiquitousKeyValueStoreTests" \
  2>&1 | grep -E "(Test Case|FAILED|PASSED|Expectation failed)"