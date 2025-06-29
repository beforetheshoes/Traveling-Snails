# SwiftLint Script for Traveling Snails
# Automatically added by setup-swiftlint.sh

# Exit early if we're not in a CI environment and swiftlint isn't available
if ! command -v swiftlint >/dev/null 2>&1; then
    # Try to use SwiftLint from SPM build directory
    if [ -f "${SRCROOT}/.build/checkouts/SwiftLint/swiftlint" ]; then
        SWIFTLINT_PATH="${SRCROOT}/.build/checkouts/SwiftLint/swiftlint"
    elif [ -f "${SRCROOT}/.build/release/swiftlint" ]; then
        SWIFTLINT_PATH="${SRCROOT}/.build/release/swiftlint"
    else
        echo "SwiftLint not found. Installing via Homebrew..."
        if command -v brew >/dev/null 2>&1; then
            brew install swiftlint
            SWIFTLINT_PATH="swiftlint"
        else
            echo "warning: SwiftLint not found and Homebrew not available. Skipping SwiftLint."
            exit 0
        fi
    fi
else
    SWIFTLINT_PATH="swiftlint"
fi

# Only run SwiftLint for the main app target, not tests
if [ "${TARGET_NAME}" = "Traveling Snails" ]; then
    echo "Running SwiftLint for ${TARGET_NAME}..."
    ${SWIFTLINT_PATH} --config "${SRCROOT}/.swiftlint.yml"
    
    # Check for critical security violations and fail the build if found
    VIOLATIONS=$(${SWIFTLINT_PATH} lint --quiet --config "${SRCROOT}/.swiftlint.yml" | grep -E "(print|Print|sensitive|Sensitive)" || true)
    if [ ! -z "$VIOLATIONS" ]; then
        echo "🚨 Security violations detected:"
        echo "$VIOLATIONS"
        echo ""
        echo "Build failed due to security violations. Please fix the issues above."
        exit 1
    fi
else
    echo "Skipping SwiftLint for ${TARGET_NAME} (test target)"
fi
