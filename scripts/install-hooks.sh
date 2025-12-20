#!/bin/bash
# Script to install development dependencies and pre-commit hooks

set -e

echo "Installing Ruby dependencies..."
bundle install

echo "Checking for pre-commit..."
if ! command -v pre-commit &> /dev/null; then
    echo ""
    echo "ERROR: pre-commit is not installed."
    echo ""
    echo "Please install it using one of the following methods:"
    echo ""
    if command -v apt-get &> /dev/null; then
        echo "  Option 1 (Recommended): sudo apt-get install pre-commit"
    fi
    if command -v pip3 &> /dev/null; then
        echo "  Option 2: pip3 install --user pre-commit"
    fi
    if command -v pip &> /dev/null; then
        echo "  Option 3: pip install --user pre-commit"
    fi
    echo ""
    exit 1
else
    echo "pre-commit is already installed ($(pre-commit --version))"
fi

echo "Installing pre-commit hooks..."
pre-commit install

echo "Done! Pre-commit hooks are now installed."
echo "Run 'pre-commit run --all-files' to test all hooks."
