#!/bin/bash

# SwiftLint Setup Script for Traveling Snails
# This script sets up SwiftLint integration with the Xcode project

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="${PROJECT_DIR}/Traveling Snails.xcodeproj/project.pbxproj"

echo "🐌 Setting up SwiftLint for Traveling Snails..."

# Check if SwiftLint is available via SPM
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not available. Please ensure Xcode is installed."
    exit 1
fi

# Check if Package.swift exists
if [ ! -f "${PROJECT_DIR}/Package.swift" ]; then
    echo "❌ Package.swift not found. SwiftLint SPM dependency is required."
    exit 1
fi

# Resolve SwiftLint via SPM
echo "📦 Resolving SwiftLint dependency..."
cd "${PROJECT_DIR}"
swift package resolve

# Check if SwiftLint is now available
SWIFTLINT_PATH=""
if command -v swiftlint &> /dev/null; then
    SWIFTLINT_PATH="swiftlint"
    echo "✅ SwiftLint found in PATH: $(which swiftlint)"
elif [ -f ".build/checkouts/SwiftLint/swiftlint" ]; then
    SWIFTLINT_PATH=".build/checkouts/SwiftLint/swiftlint"
    echo "✅ SwiftLint found via SPM: ${SWIFTLINT_PATH}"
elif swift package plugin --list | grep -q SwiftLint; then
    echo "✅ SwiftLint available as Swift Package Plugin"
    SWIFTLINT_PATH="swift package plugin --allow-writing-to-directory . swiftlint"
else
    echo "❌ SwiftLint not found. Installing via Homebrew as fallback..."
    if command -v brew &> /dev/null; then
        brew install swiftlint
        SWIFTLINT_PATH="swiftlint"
    else
        echo "❌ Neither SwiftLint nor Homebrew found. Please install SwiftLint manually."
        exit 1
    fi
fi

# Create the SwiftLint run script
SCRIPT_CONTENT="# SwiftLint Script for Traveling Snails
# Automatically added by setup-swiftlint.sh

# Exit early if we're not in a CI environment and swiftlint isn't available
if ! command -v swiftlint >/dev/null 2>&1; then
    # Try to use SwiftLint from SPM build directory
    if [ -f \"\${SRCROOT}/.build/checkouts/SwiftLint/swiftlint\" ]; then
        SWIFTLINT_PATH=\"\${SRCROOT}/.build/checkouts/SwiftLint/swiftlint\"
    elif [ -f \"\${SRCROOT}/.build/release/swiftlint\" ]; then
        SWIFTLINT_PATH=\"\${SRCROOT}/.build/release/swiftlint\"
    else
        echo \"SwiftLint not found. Installing via Homebrew...\"
        if command -v brew >/dev/null 2>&1; then
            brew install swiftlint
            SWIFTLINT_PATH=\"swiftlint\"
        else
            echo \"warning: SwiftLint not found and Homebrew not available. Skipping SwiftLint.\"
            exit 0
        fi
    fi
else
    SWIFTLINT_PATH=\"swiftlint\"
fi

# Only run SwiftLint for the main app target, not tests
if [ \"\${TARGET_NAME}\" = \"Traveling Snails\" ]; then
    echo \"Running SwiftLint for \${TARGET_NAME}...\"
    \${SWIFTLINT_PATH} --config \"\${SRCROOT}/.swiftlint.yml\"
    
    # Check for critical security violations and fail the build if found
    VIOLATIONS=\$(\${SWIFTLINT_PATH} lint --quiet --config \"\${SRCROOT}/.swiftlint.yml\" | grep -E \"(print|Print|sensitive|Sensitive)\" || true)
    if [ ! -z \"\$VIOLATIONS\" ]; then
        echo \"🚨 Security violations detected:\"
        echo \"\$VIOLATIONS\"
        echo \"\"
        echo \"Build failed due to security violations. Please fix the issues above.\"
        exit 1
    fi
else
    echo \"Skipping SwiftLint for \${TARGET_NAME} (test target)\"
fi"

echo "📝 SwiftLint integration instructions:"
echo ""
echo "To complete the setup, please add a 'Run Script' build phase to your Xcode project:"
echo ""
echo "1. Open Traveling Snails.xcodeproj in Xcode"
echo "2. Select the 'Traveling Snails' project in the navigator"
echo "3. Select the 'Traveling Snails' target"
echo "4. Go to 'Build Phases' tab"
echo "5. Click '+' and select 'New Run Script Phase'"
echo "6. Name it 'SwiftLint' and paste this script:"
echo ""
echo "----------------------------------------"
echo "${SCRIPT_CONTENT}"
echo "----------------------------------------"
echo ""
echo "7. Move the 'SwiftLint' phase to run before 'Compile Sources'"
echo "8. In 'Input Files', add: \$(SRCROOT)/.swiftlint.yml"
echo "9. In 'Output Files', add: \$(DERIVED_FILE_DIR)/swiftlint.log"
echo ""

# Create a helper file with the script content
mkdir -p "${PROJECT_DIR}/Scripts"
echo "${SCRIPT_CONTENT}" > "${PROJECT_DIR}/Scripts/swiftlint-build-script.sh"
chmod +x "${PROJECT_DIR}/Scripts/swiftlint-build-script.sh"

echo "✅ SwiftLint script saved to Scripts/swiftlint-build-script.sh"
echo ""

# Test SwiftLint configuration
echo "🧪 Testing SwiftLint configuration..."
if [ -f "${PROJECT_DIR}/.swiftlint.yml" ]; then
    if ${SWIFTLINT_PATH} lint --config "${PROJECT_DIR}/.swiftlint.yml" --quiet "${PROJECT_DIR}/Traveling Snails" > /dev/null 2>&1; then
        echo "✅ SwiftLint configuration is valid"
    else
        echo "⚠️  SwiftLint found issues. Run 'swiftlint lint' to see details."
    fi
else
    echo "❌ .swiftlint.yml not found"
    exit 1
fi

echo ""
echo "🎉 SwiftLint setup complete!"
echo ""
echo "Next steps:"
echo "1. Add the Run Script phase to Xcode (see instructions above)"
echo "2. Run 'swiftlint lint' to see current violations"
echo "3. Fix violations or add exceptions as needed"
echo "4. Build the project to test integration"