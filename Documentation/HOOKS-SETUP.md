# Claude Code Hooks Setup

## Purpose
These hooks prevent Claude from claiming tests are passing when they're not, ensuring **deterministic test completion enforcement**.

## Hook Configuration

### 1. Enable Hooks
Add to your Claude Code settings:

```json
{
  "hookConfig": "/Users/ryan/Developer/Swift/Traveling Snails/claude-hooks.json"
}
```

### 2. Hook Functions

#### PreToolUse Hook
- **Triggers**: Before Edit, Write, MultiEdit, commit, push
- **Action**: Blocks file changes if tests are failing
- **Exit Code**: 2 (blocking error)

#### PostToolUse Hook  
- **Triggers**: After Edit, Write, MultiEdit
- **Action**: Verifies tests still pass after code changes
- **Exit Code**: 2 if tests break

#### Stop Hook
- **Triggers**: When Claude attempts to finish
- **Action**: Final verification that all tests pass
- **Exit Code**: 2 if any tests fail

#### Notification Hook
- **Triggers**: When Claude claims success/completion
- **Action**: Verifies actual test results match claims
- **Exit Code**: 2 if tests are failing despite claims

### 3. Validation Script
Run `/Scripts/validate-all-tests.sh` for deterministic test checking:
- Zero tolerance for failing tests
- Complete test suite execution
- Clear pass/fail determination

## How This Prevents the Problem

1. **Cannot edit files** when tests are failing
2. **Cannot commit/push** with broken tests
3. **Cannot claim success** when tests are failing  
4. **Cannot finish tasks** without 100% test pass rate

## Benefits

- **Deterministic**: No ambiguity - tests must pass or Claude is blocked
- **Automatic**: No manual intervention needed
- **Comprehensive**: Covers all scenarios where Claude might claim false success
- **Zero Tolerance**: Any failing test blocks progression

## Testing the Setup

To verify hooks are working:

1. Intentionally break a test
2. Try to edit a file - should be blocked
3. Try to claim success - should be blocked
4. Fix the test - should unblock

This creates an **impossible-to-bypass** system that enforces the "ALL TESTS MUST PASS" requirement.