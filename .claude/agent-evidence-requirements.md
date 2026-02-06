# MANDATORY AGENT EVIDENCE PROTOCOL

## ⚠️ COMPLETION CLAIM REQUIREMENTS

**AGENTS CANNOT claim work is "completed", "fixed", "resolved", "working", or "done" without providing ALL of the following evidence:**

### 1. TEST EXECUTION EVIDENCE (MANDATORY)
```bash
# MUST show actual command output like this:
xcodebuild test -project "Traveling Snails.xcodeproj" \
  -scheme "Traveling Snails" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -only-testing:"Traveling Snails Tests/[TEST_NAME]"

# Output MUST contain:
TEST SUCCEEDED
# And MUST NOT contain:
Expectation failed
timeout
failed
error
```

### 2. PERFORMANCE BASELINE EVIDENCE (MANDATORY)
- **MUST show actual timing results** vs expected baselines
- **AdvancedIntegrationTests.testTripCreationWorkflow**: < 6.0 seconds
- **ErrorStatePersistencePerformanceTests**: < 35.0 seconds  
- **SecurityTestSuite**: < 10.0 seconds
- **LoggerTests**: < 1.0 second

Example:
```
✅ testTripCreationWorkflow: 5.2s (baseline: 6.0s) - PASSED
❌ testTripCreationWorkflow: 13.17s (baseline: 6.0s) - FAILED
```

### 3. COMPILATION EVIDENCE (MANDATORY)
```bash
# MUST show swift build output:
swift build
# Output MUST show:
Build complete!
# And MUST NOT contain:
error:
warning:
concurrency-safe
sending parameter risks
Swift 6 language mode
```

### 4. ZERO TOLERANCE POLICY

**If ANY of the following exist, completion claims are BLOCKED:**
- ❌ Tests timeout or fail
- ❌ Performance baselines violated (even by 0.1 seconds)
- ❌ Any compilation errors or warnings
- ❌ Swift 6 concurrency safety violations
- ❌ Missing evidence requirements

## AGENT RESPONSIBILITIES

### Before Any Completion Claim:
1. **Run actual test commands** (don't assume)
2. **Copy-paste command output** as evidence
3. **Verify performance baselines** are met
4. **Show compilation success** with zero warnings
5. **Provide timestamped evidence** in response

### Acceptable Work Claims:
✅ "Investigating the issue..."
✅ "Making changes to fix..."  
✅ "Testing potential solution..."
✅ "Found the root cause..."

### BLOCKED Completion Claims Without Evidence:
❌ "Fixed"
❌ "Completed" 
❌ "Working"
❌ "Resolved"
❌ "Done"
❌ "Success"
❌ "All tests passing"

## HOOK VALIDATION

The validation hook will now:
- ✅ Block completion claims without evidence
- ✅ Validate performance baselines automatically
- ✅ Check for compilation errors
- ✅ Detect timeout and failure patterns
- ✅ Require specific "TEST SUCCEEDED" patterns

**NO EXCEPTIONS. NO SHORTCUTS. NO ASSUMPTIONS.**