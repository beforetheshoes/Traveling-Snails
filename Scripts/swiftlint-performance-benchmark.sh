#!/bin/bash
# SwiftLint Performance Benchmark Script for Traveling Snails
# Measures and optimizes SwiftLint execution performance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCHMARK_DIR="${PROJECT_ROOT}/benchmark-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BENCHMARK_FILE="${BENCHMARK_DIR}/swiftlint_benchmark_${TIMESTAMP}.json"

echo -e "${BLUE}🔬 SwiftLint Performance Benchmark${NC}"
echo "Project: Traveling Snails"
echo "Timestamp: $(date)"
echo "Results will be saved to: $BENCHMARK_FILE"
echo

# Create benchmark directory
mkdir -p "$BENCHMARK_DIR"

cd "$PROJECT_ROOT"

# Function to time command execution
time_command() {
    local description="$1"
    local command="$2"
    
    echo -e "${YELLOW}⏱️  Benchmarking: $description${NC}"
    
    # Warm up - run once without timing
    eval "$command" > /dev/null 2>&1 || true
    
    # Actual timing runs
    local times=()
    for i in {1..3}; do
        local start_time=$(date +%s.%N)
        eval "$command" > /dev/null 2>&1
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        times+=($duration)
        echo "  Run $i: ${duration}s"
    done
    
    # Calculate average
    local total=0
    for time in "${times[@]}"; do
        total=$(echo "$total + $time" | bc)
    done
    local average=$(echo "scale=3; $total / ${#times[@]}" | bc)
    
    echo -e "  ${GREEN}Average: ${average}s${NC}"
    echo
    
    # Return average for JSON output
    echo "$average"
}

# Function to get file statistics
get_file_stats() {
    local swift_files=$(find . -name "*.swift" -not -path "./.build/*" -not -path "./Pods/*" | wc -l | tr -d ' ')
    local swift_lines=$(find . -name "*.swift" -not -path "./.build/*" -not -path "./Pods/*" -exec wc -l {} + | tail -1 | awk '{print $1}')
    local test_files=$(find . -name "*Tests*.swift" -not -path "./.build/*" | wc -l | tr -d ' ')
    
    echo "📊 Codebase Statistics:"
    echo "  Swift files: $swift_files"
    echo "  Lines of code: $swift_lines"
    echo "  Test files: $test_files"
    echo
    
    # Export for JSON
    SWIFT_FILES=$swift_files
    SWIFT_LINES=$swift_lines
    TEST_FILES=$test_files
}

# Function to measure rule performance
benchmark_rules() {
    echo -e "${BLUE}🔍 Rule Performance Analysis${NC}"
    
    # Security rules
    local security_time=$(time_command "Security Rules Only" "swift run swiftlint lint --enable-rule no_print_statements,no_sensitive_logging,safe_error_messages")
    
    # Modern Swift rules
    local modern_time=$(time_command "Modern Swift Rules Only" "swift run swiftlint lint --enable-rule use_navigation_stack,no_state_object,use_l10n_enum")
    
    # SwiftData rules
    local swiftdata_time=$(time_command "SwiftData Rules Only" "swift run swiftlint lint --enable-rule no_swiftdata_parameter_passing")
    
    # Built-in rules only
    local builtin_time=$(time_command "Built-in Rules Only" "swift run swiftlint lint --disable-rule no_print_statements,no_sensitive_logging,safe_error_messages,use_navigation_stack,no_state_object,use_l10n_enum,no_swiftdata_parameter_passing,no_hardcoded_strings,require_input_validation")
    
    # Export for JSON
    SECURITY_TIME=$security_time
    MODERN_TIME=$modern_time
    SWIFTDATA_TIME=$swiftdata_time
    BUILTIN_TIME=$builtin_time
}

# Function to benchmark different configurations
benchmark_configurations() {
    echo -e "${BLUE}⚙️  Configuration Performance${NC}"
    
    # Full configuration
    local full_time=$(time_command "Full Configuration" "swift run swiftlint lint --config .swiftlint.yml")
    
    # Parallel processing (if available)
    local parallel_time=$(time_command "Parallel Processing" "swift run swiftlint lint --config .swiftlint.yml --parallel")
    
    # Strict mode
    local strict_time=$(time_command "Strict Mode" "swift run swiftlint lint --config .swiftlint.yml --strict")
    
    # Export for JSON
    FULL_TIME=$full_time
    PARALLEL_TIME=$parallel_time
    STRICT_TIME=$strict_time
}

# Function to benchmark file subsets
benchmark_file_subsets() {
    echo -e "${BLUE}📁 File Subset Performance${NC}"
    
    # Main app files only
    local app_time=$(time_command "Main App Files Only" "find 'Traveling Snails' -name '*.swift' | xargs swift run swiftlint lint --config .swiftlint.yml")
    
    # Test files only
    local test_time=$(time_command "Test Files Only" "find 'Traveling Snails Tests' -name '*.swift' | xargs swift run swiftlint lint --config .swiftlint.yml")
    
    # Single large file
    local large_file=$(find . -name "*.swift" -not -path "./.build/*" -exec wc -l {} + | sort -nr | head -1 | awk '{print $2}')
    local single_time=$(time_command "Largest File ($large_file)" "swift run swiftlint lint --config .swiftlint.yml '$large_file'")
    
    # Export for JSON
    APP_TIME=$app_time
    TEST_TIME=$test_time
    SINGLE_TIME=$single_time
    LARGE_FILE=$large_file
}

# Function to analyze violation patterns
analyze_violations() {
    echo -e "${BLUE}📋 Violation Analysis${NC}"
    
    local violations_json=$(swift run swiftlint lint --config .swiftlint.yml --reporter json 2>/dev/null || echo "[]")
    
    local total_violations=$(echo "$violations_json" | jq 'length' 2>/dev/null || echo "0")
    local error_violations=$(echo "$violations_json" | jq '[.[] | select(.severity == "error")] | length' 2>/dev/null || echo "0")
    local warning_violations=$(echo "$violations_json" | jq '[.[] | select(.severity == "warning")] | length' 2>/dev/null || echo "0")
    local security_violations=$(echo "$violations_json" | jq '[.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages"))] | length' 2>/dev/null || echo "0")
    
    echo "📊 Current Violations:"
    echo "  Total: $total_violations"
    echo "  Errors: $error_violations"
    echo "  Warnings: $warning_violations"
    echo "  Security: $security_violations"
    echo
    
    # Top rule violations
    echo "🔝 Top Rule Violations:"
    echo "$violations_json" | jq -r 'group_by(.rule_id) | sort_by(length) | reverse | .[0:5] | .[] | "\(length) - \(.[0].rule_id)"' 2>/dev/null || echo "  Unable to analyze rule patterns"
    echo
    
    # Save violations for trend analysis
    echo "$violations_json" > "${BENCHMARK_DIR}/violations_${TIMESTAMP}.json"
    
    # Export for JSON
    TOTAL_VIOLATIONS=$total_violations
    ERROR_VIOLATIONS=$error_violations
    WARNING_VIOLATIONS=$warning_violations
    SECURITY_VIOLATIONS=$security_violations
}

# Function to test cache performance
benchmark_cache_performance() {
    echo -e "${BLUE}💾 Cache Performance${NC}"
    
    # Clean build
    swift package clean > /dev/null 2>&1
    local clean_time=$(time_command "Clean Build (no cache)" "swift run swiftlint lint --config .swiftlint.yml")
    
    # Cached build
    local cached_time=$(time_command "Cached Build" "swift run swiftlint lint --config .swiftlint.yml")
    
    # Calculate cache benefit
    local cache_benefit=$(echo "scale=2; ($clean_time - $cached_time) / $clean_time * 100" | bc)
    
    echo -e "${GREEN}Cache Performance Benefit: ${cache_benefit}%${NC}"
    echo
    
    # Export for JSON
    CLEAN_TIME=$clean_time
    CACHED_TIME=$cached_time
    CACHE_BENEFIT=$cache_benefit
}

# Function to generate optimization recommendations
generate_recommendations() {
    echo -e "${BLUE}💡 Performance Recommendations${NC}"
    
    local recommendations=()
    
    # Check if parallel is beneficial
    if (( $(echo "$PARALLEL_TIME < $FULL_TIME" | bc -l) )); then
        local parallel_benefit=$(echo "scale=1; ($FULL_TIME - $PARALLEL_TIME) / $FULL_TIME * 100" | bc)
        recommendations+=("✅ Use --parallel flag for ${parallel_benefit}% performance improvement")
    fi
    
    # Check caching benefit
    if (( $(echo "$CACHE_BENEFIT > 20" | bc -l) )); then
        recommendations+=("✅ Maintain SPM cache for ${CACHE_BENEFIT}% performance improvement")
    fi
    
    # Check if custom rules are expensive
    if (( $(echo "$BUILTIN_TIME * 2 < $FULL_TIME" | bc -l) )); then
        recommendations+=("⚠️  Custom rules add significant overhead - consider optimization")
    fi
    
    # Check violation count impact
    if [ "$TOTAL_VIOLATIONS" -gt 100 ]; then
        recommendations+=("⚠️  High violation count ($TOTAL_VIOLATIONS) may impact performance")
    fi
    
    # File size recommendations
    if [ "$SWIFT_FILES" -gt 200 ]; then
        recommendations+=("💡 Consider file-level caching for large codebase ($SWIFT_FILES files)")
    fi
    
    # Security focus
    if [ "$SECURITY_VIOLATIONS" -gt 0 ]; then
        recommendations+=("🚨 Address $SECURITY_VIOLATIONS security violations for faster CI")
    fi
    
    if [ ${#recommendations[@]} -eq 0 ]; then
        recommendations+=("✅ Performance is optimal - no recommendations")
    fi
    
    for rec in "${recommendations[@]}"; do
        echo "  $rec"
    done
    echo
    
    # Export for JSON
    RECOMMENDATIONS="${recommendations[*]}"
}

# Function to save benchmark results
save_benchmark_results() {
    echo -e "${BLUE}💾 Saving Benchmark Results${NC}"
    
    cat > "$BENCHMARK_FILE" << EOF
{
  "benchmark_info": {
    "timestamp": "$(date -Iseconds)",
    "project": "Traveling Snails",
    "swiftlint_version": "$(swift run swiftlint version 2>/dev/null || echo 'unknown')",
    "swift_version": "$(swift --version | head -1)"
  },
  "codebase_stats": {
    "swift_files": $SWIFT_FILES,
    "lines_of_code": $SWIFT_LINES,
    "test_files": $TEST_FILES
  },
  "rule_performance": {
    "security_rules": $SECURITY_TIME,
    "modern_swift_rules": $MODERN_TIME,
    "swiftdata_rules": $SWIFTDATA_TIME,
    "builtin_rules": $BUILTIN_TIME
  },
  "configuration_performance": {
    "full_configuration": $FULL_TIME,
    "parallel_processing": $PARALLEL_TIME,
    "strict_mode": $STRICT_TIME
  },
  "file_subset_performance": {
    "app_files": $APP_TIME,
    "test_files": $TEST_TIME,
    "single_file": $SINGLE_TIME,
    "largest_file": "$LARGE_FILE"
  },
  "cache_performance": {
    "clean_build": $CLEAN_TIME,
    "cached_build": $CACHED_TIME,
    "cache_benefit_percent": $CACHE_BENEFIT
  },
  "ci_scenarios": {
    "github_actions_simulation": $GA_TIME,
    "changed_files_only": $CHANGED_FILES_TIME,
    "quick_security_check": $QUICK_SECURITY_TIME
  },
  "violation_analysis": {
    "total_violations": $TOTAL_VIOLATIONS,
    "error_violations": $ERROR_VIOLATIONS,
    "warning_violations": $WARNING_VIOLATIONS,
    "security_violations": $SECURITY_VIOLATIONS
  },
  "trend_analysis": {
    "status": "$TREND_ANALYSIS"
  },
  "recommendations": [
    $(echo "$RECOMMENDATIONS" | sed 's/^/"/; s/$/",/; $s/,$//')
  ]
}
EOF
    
    echo "✅ Results saved to: $BENCHMARK_FILE"
    echo
}

# Function to display performance summary
display_summary() {
    echo -e "${GREEN}📊 Performance Summary${NC}"
    echo "=================================="
    echo "Full Lint Time: ${FULL_TIME}s"
    echo "Parallel Benefit: $(echo "scale=1; ($FULL_TIME - $PARALLEL_TIME) / $FULL_TIME * 100" | bc)%"
    echo "Cache Benefit: ${CACHE_BENEFIT}%"
    echo "Security Rule Overhead: $(echo "scale=1; $SECURITY_TIME / $FULL_TIME * 100" | bc)%"
    echo "Total Violations: $TOTAL_VIOLATIONS"
    echo "Security Issues: $SECURITY_VIOLATIONS"
    echo "=================================="
    echo
}

# Function to benchmark CI-specific scenarios
benchmark_ci_scenarios() {
    echo -e "${BLUE}🔧 CI Scenario Benchmarks${NC}"
    
    # GitHub Actions simulation
    local ga_time=$(time_command "GitHub Actions Simulation" "swift run swiftlint lint --config .swiftlint.yml --parallel --reporter json")
    
    # PR changed files simulation (mock)
    local changed_files_time
    if [ -d ".git" ]; then
        # Simulate checking last 10 changed files
        local changed_files=$(git diff --name-only HEAD~1 HEAD | grep "\.swift$" | head -10 || echo "")
        if [ ! -z "$changed_files" ]; then
            changed_files_time=$(time_command "PR Changed Files (last commit)" "echo '$changed_files' | xargs swift run swiftlint lint --config .swiftlint.yml")
        else
            changed_files_time="0.000"
        fi
    else
        changed_files_time="0.000"
    fi
    
    # Quick security check
    local quick_security_time=$(time_command "Quick Security Check" "swift run swiftlint lint --config .swiftlint.yml --enable-rule no_print_statements,no_sensitive_logging --reporter json")
    
    echo "📊 CI Performance Results:"
    echo "  GitHub Actions workflow: ${ga_time}s"
    echo "  Changed files only: ${changed_files_time}s"
    echo "  Quick security check: ${quick_security_time}s"
    echo
    
    # Export for JSON
    GA_TIME=$ga_time
    CHANGED_FILES_TIME=$changed_files_time
    QUICK_SECURITY_TIME=$quick_security_time
}

# Function to generate trend analysis
generate_trend_analysis() {
    echo -e "${BLUE}📈 Performance Trend Analysis${NC}"
    
    # Look for previous benchmark files
    local previous_benchmarks=$(find "$BENCHMARK_DIR" -name "swiftlint_benchmark_*.json" | sort | tail -5)
    
    if [ ! -z "$previous_benchmarks" ]; then
        echo "📊 Recent Benchmark Trends:"
        echo "$previous_benchmarks" | while read benchmark_file; do
            local timestamp=$(echo "$benchmark_file" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
            local full_time=$(jq -r '.configuration_performance.full_configuration' "$benchmark_file" 2>/dev/null || echo "unknown")
            local violations=$(jq -r '.violation_analysis.total_violations' "$benchmark_file" 2>/dev/null || echo "unknown")
            echo "  $timestamp: ${full_time}s (${violations} violations)"
        done
        echo
        
        # Calculate performance trend
        local latest_benchmark=$(echo "$previous_benchmarks" | tail -1)
        local oldest_benchmark=$(echo "$previous_benchmarks" | head -1)
        
        if [ "$latest_benchmark" != "$oldest_benchmark" ]; then
            local latest_time=$(jq -r '.configuration_performance.full_configuration' "$latest_benchmark" 2>/dev/null || echo "0")
            local oldest_time=$(jq -r '.configuration_performance.full_configuration' "$oldest_benchmark" 2>/dev/null || echo "0")
            
            if [ "$oldest_time" != "0" ] && [ "$latest_time" != "0" ]; then
                local trend=$(echo "scale=1; ($latest_time - $oldest_time) / $oldest_time * 100" | bc 2>/dev/null || echo "0")
                if (( $(echo "$trend > 0" | bc -l) )); then
                    echo "📈 Performance trend: ${trend}% slower over time (investigate optimization)"
                elif (( $(echo "$trend < 0" | bc -l) )); then
                    local improvement=$(echo "scale=1; -1 * $trend" | bc)
                    echo "📉 Performance trend: ${improvement}% faster over time (good!)"
                else
                    echo "📊 Performance trend: Stable"
                fi
                echo
            fi
        fi
        
        TREND_ANALYSIS="Available"
    else
        echo "📊 No previous benchmarks found for trend analysis"
        echo
        TREND_ANALYSIS="None"
    fi
}

# Function to generate CI optimization suggestions
generate_ci_optimizations() {
    echo -e "${BLUE}🚀 CI Optimization Suggestions${NC}"
    
    cat > "${PROJECT_ROOT}/ci-optimization-suggestions.md" << EOF
# CI Optimization Suggestions for SwiftLint

Generated: $(date)
Based on: $BENCHMARK_FILE

## Performance Results

- **Full Lint Time**: ${FULL_TIME}s
- **Parallel Processing**: ${PARALLEL_TIME}s ($(echo "scale=1; ($FULL_TIME - $PARALLEL_TIME) / $FULL_TIME * 100" | bc)% improvement)
- **Cache Benefit**: ${CACHE_BENEFIT}%

## Recommended CI Configuration

\`\`\`yaml
# Optimized GitHub Actions SwiftLint configuration
- name: Cache SwiftLint Build
  uses: actions/cache@v4
  with:
    path: .build
    key: swiftlint-\${{ runner.os }}-\${{ hashFiles('Package.swift', 'Package.resolved') }}

- name: Run SwiftLint (Optimized)
  run: |
    # Use parallel processing for better performance
    swift run swiftlint lint --config .swiftlint.yml --parallel --reporter json > violations.json
    
    # Fast-fail on security violations
    SECURITY_COUNT=\$(jq '[.[] | select(.rule_id | test("print_statements|sensitive_logging|safe_error_messages"))] | length' violations.json)
    if [ "\$SECURITY_COUNT" -gt 0 ]; then
      echo "🚨 Security violations detected"
      exit 1
    fi
\`\`\`

## File-Level Optimization

For large PRs, consider checking only changed files:

\`\`\`bash
# Check only changed files in PR
CHANGED_FILES=\$(git diff --name-only origin/main...HEAD | grep '\\.swift\$' || true)
if [ ! -z "\$CHANGED_FILES" ]; then
  echo "\$CHANGED_FILES" | xargs swift run swiftlint lint --config .swiftlint.yml
fi
\`\`\`

## Rule-Specific Performance

- Security rules: ${SECURITY_TIME}s ($(echo "scale=1; $SECURITY_TIME / $FULL_TIME * 100" | bc)% of total)
- Modern Swift rules: ${MODERN_TIME}s ($(echo "scale=1; $MODERN_TIME / $FULL_TIME * 100" | bc)% of total)
- Built-in rules: ${BUILTIN_TIME}s ($(echo "scale=1; $BUILTIN_TIME / $FULL_TIME * 100" | bc)% of total)

## Recommendations

$RECOMMENDATIONS

EOF
    
    echo "✅ CI optimization suggestions saved to: ci-optimization-suggestions.md"
    echo
}

# Main execution
main() {
    echo -e "${GREEN}Starting comprehensive SwiftLint performance benchmark...${NC}"
    echo
    
    # Verify SwiftLint is available
    if ! command -v swift >/dev/null 2>&1; then
        echo -e "${RED}❌ Swift command not found${NC}"
        exit 1
    fi
    
    # Verify project structure
    if [ ! -f ".swiftlint.yml" ]; then
        echo -e "${RED}❌ .swiftlint.yml not found${NC}"
        exit 1
    fi
    
    # Install bc for calculations if not available
    if ! command -v bc >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Installing bc for calculations...${NC}"
        if command -v brew >/dev/null 2>&1; then
            brew install bc
        else
            echo -e "${RED}❌ bc not available and cannot install automatically${NC}"
            exit 1
        fi
    fi
    
    # Run benchmarks
    get_file_stats
    benchmark_rules
    benchmark_configurations  
    benchmark_file_subsets
    analyze_violations
    benchmark_cache_performance
    benchmark_ci_scenarios
    generate_trend_analysis
    generate_recommendations
    save_benchmark_results
    display_summary
    generate_ci_optimizations
    
    echo -e "${GREEN}🎉 Benchmark completed successfully!${NC}"
    echo "📁 Results available in: $BENCHMARK_DIR"
    echo "📖 CI suggestions in: ci-optimization-suggestions.md"
}

# Run main function
main "$@"