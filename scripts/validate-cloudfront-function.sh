#!/bin/bash
#
# Validate CloudFront Function code for ES5 compatibility
#
# This script checks that CloudFront Function code:
# - Does not use optional chaining (?.)
# - Does not use nullish coalescing (??)
# - Does not use async/await
# - Does not modify forbidden headers (origin)
# - Is under 9000 bytes
#
# Usage: validate-cloudfront-function.sh <function-code-file>

set -euo pipefail

FUNCTION_CODE_FILE="${1:-}"

if [ -z "$FUNCTION_CODE_FILE" ]; then
  echo "Usage: $0 <function-code-file>"
  exit 1
fi

if [ ! -f "$FUNCTION_CODE_FILE" ]; then
  echo "ERROR: Function code file not found: $FUNCTION_CODE_FILE"
  exit 1
fi

ERRORS=0

echo "🔍 Validating CloudFront Function code: $FUNCTION_CODE_FILE"

# Check for optional chaining
if grep -q "?\\." "$FUNCTION_CODE_FILE"; then
  echo "❌ FAIL: Optional chaining (?.) is not supported in CloudFront Functions (ES5 strict)"
  grep -n "?\\." "$FUNCTION_CODE_FILE" || true
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PASS: No optional chaining found"
fi

# Check for nullish coalescing
if grep -q "??" "$FUNCTION_CODE_FILE"; then
  echo "❌ FAIL: Nullish coalescing (??) is not supported in CloudFront Functions (ES5 strict)"
  grep -n "??" "$FUNCTION_CODE_FILE" || true
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PASS: No nullish coalescing found"
fi

# Check for async/await
if grep -qE "async\s|await\s" "$FUNCTION_CODE_FILE"; then
  echo "❌ FAIL: async/await is not supported in CloudFront Functions (ES5 strict)"
  grep -nE "async\s|await\s" "$FUNCTION_CODE_FILE" || true
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PASS: No async/await found"
fi

# Check for forbidden origin header modification
if grep -qi "headers\.origin\s*=" "$FUNCTION_CODE_FILE"; then
  echo "❌ FAIL: Modifying 'origin' header is forbidden in CloudFront Functions"
  grep -in "headers\.origin\s*=" "$FUNCTION_CODE_FILE" || true
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PASS: No origin header modification found"
fi

# Check file size (CloudFront Functions have a 9000 byte limit for cloudfront-js-2.0)
FILE_SIZE=$(wc -c < "$FUNCTION_CODE_FILE" | tr -d ' ')
if [ "$FILE_SIZE" -gt 9000 ]; then
  echo "❌ FAIL: Function code size ($FILE_SIZE bytes) exceeds CloudFront limit (9000 bytes)"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ PASS: Function code size ($FILE_SIZE bytes) is within limit (9000 bytes)"
fi

# Check that function returns request
if ! grep -q "return request" "$FUNCTION_CODE_FILE"; then
  echo "⚠️  WARNING: Function may not return request object (required)"
else
  echo "✅ PASS: Function returns request object"
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
  echo "✅ All validation checks passed!"
  exit 0
else
  echo "❌ $ERRORS validation check(s) failed"
  exit 1
fi

