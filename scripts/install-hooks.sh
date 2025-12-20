#!/bin/bash
# Script to install development dependencies and pre-commit hooks

set -e

echo "Installing Ruby dependencies..."
bundle install

echo "Installing pre-commit..."
if command -v pip3 &> /dev/null; then
    pip3 install pre-commit
elif command -v pip &> /dev/null; then
    pip install pre-commit
else
    echo "Error: pip not found. Please install Python and pip first."
    exit 1
fi

echo "Installing pre-commit hooks..."
pre-commit install

echo "Done! Pre-commit hooks are now installed."
echo "Run 'pre-commit run --all-files' to test all hooks."
