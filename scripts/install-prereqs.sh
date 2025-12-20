#!/bin/bash
set -e

echo "=== Puppet Control Repo Prerequisites Installer ==="
echo

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "ERROR: Ruby is not installed. Please install Ruby 3.x first."
    exit 1
fi

RUBY_VERSION=$(ruby -e 'puts "#{RUBY_VERSION.split(".")[0..1].join(".")}"')
GEM_BIN_PATH="$HOME/.local/share/gem/ruby/${RUBY_VERSION}.0/bin"

echo "✓ Found Ruby $(ruby --version | cut -d' ' -f2)"
echo

# Install bundler if not available or wrong version
if ! command -v bundle &> /dev/null || ! bundle --version &> /dev/null; then
    echo "→ Installing bundler..."
    gem install bundler
    echo "✓ Bundler installed"
else
    echo "✓ Bundler already installed ($(bundle --version))"
fi
echo

# Add gem bin directory to PATH if not already there
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

PATH_EXPORT="export PATH=\"\$HOME/.local/share/gem/ruby/${RUBY_VERSION}.0/bin:\$PATH\""

if ! grep -qF "$PATH_EXPORT" "$SHELL_RC" 2>/dev/null; then
    echo "→ Adding gem bin directory to PATH in $SHELL_RC..."
    echo "" >> "$SHELL_RC"
    echo "# Ruby gems bin directory" >> "$SHELL_RC"
    echo "$PATH_EXPORT" >> "$SHELL_RC"
    echo "✓ PATH updated in $SHELL_RC"
else
    echo "✓ PATH already configured in $SHELL_RC"
fi

# Update PATH for current session
export PATH="$GEM_BIN_PATH:$PATH"
echo

# Configure bundler to install locally
echo "→ Configuring bundler to install to vendor/bundle..."
bundle config set --local path 'vendor/bundle'
echo "✓ Bundler configured"
echo

# Install dependencies
echo "→ Installing gem dependencies (this may take a few minutes)..."
bundle install
echo
echo "✓ All dependencies installed successfully!"
echo

# Display next steps
echo "=== Setup Complete ==="
echo
echo "For the current terminal session, run:"
echo "  export PATH=\"$GEM_BIN_PATH:\$PATH\""
echo
echo "Or start a new terminal session to use the updated PATH."
echo
echo "You can now run:"
echo "  bundle exec rake test      # Run all tests"
echo "  bundle exec rake lint_all  # Run linting"
echo "  bundle exec rspec          # Run unit tests"
