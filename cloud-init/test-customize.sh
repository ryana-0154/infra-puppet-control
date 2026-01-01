#!/bin/bash
# Quick test of customize.sh (non-interactive)

set -e

echo "Testing customize.sh automation..."

# Test base template
echo "1
testhost
1" | ./customize.sh

if [ -f generated/testhost.yaml ]; then
  echo "✓ Base template generation successful"
  grep -q "testhost" generated/testhost.yaml && echo "✓ Hostname replaced"
  rm generated/testhost.yaml
else
  echo "✗ Failed to generate base template"
  exit 1
fi

echo "All tests passed!"
