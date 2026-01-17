#!/bin/bash

# Rebuild and reinstall morphy MCP server
# This script clears the cached snapshots, reactivates the package,
# and creates wrapper scripts that bypass the noisy pub global run

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
PUB_BIN="$HOME/.pub-cache/bin"

echo "🔄 Rebuilding morphy..."

# Deactivate if currently active
echo "📦 Deactivating current installation..."
dart pub global deactivate zikzak_morphy 2>/dev/null || true

# Clear the global package cache for this package
CACHE_DIR="$HOME/.pub-cache/global_packages/zikzak_morphy"
if [ -d "$CACHE_DIR" ]; then
    echo "🗑️  Clearing global package cache..."
    rm -rf "$CACHE_DIR"
fi

# Clear the .dart_tool snapshots (this is where JIT snapshots are cached)
SNAPSHOT_DIR="$PACKAGE_DIR/.dart_tool/pub/bin/zikzak_morphy"
if [ -d "$SNAPSHOT_DIR" ]; then
    echo "🗑️  Clearing JIT snapshots..."
    rm -rf "$SNAPSHOT_DIR"
fi

# Also clear any other cached bin snapshots
DART_TOOL_BIN="$PACKAGE_DIR/.dart_tool/pub/bin"
if [ -d "$DART_TOOL_BIN" ]; then
    echo "🗑️  Clearing all bin snapshots..."
    rm -rf "$DART_TOOL_BIN"
fi

# Clear build cache
BUILD_CACHE="$PACKAGE_DIR/.dart_tool/build_cache"
if [ -d "$BUILD_CACHE" ]; then
    echo "🗑️  Clearing build cache..."
    rm -rf "$BUILD_CACHE"
fi

# Clear any .dill and .snap files in .dart_tool
find "$PACKAGE_DIR/.dart_tool" -type f \( -name "*.dill" -o -name "*.snap" \) -delete 2>/dev/null || true

# Get dependencies
echo "📥 Getting dependencies..."
cd "$PACKAGE_DIR"
dart pub get

# Create the pub bin directory if it doesn't exist
mkdir -p "$PUB_BIN"

# Create custom wrapper scripts that use dart run directly
# This avoids the noisy "Downloading packages" output from dart pub global run

echo "📝 Creating wrapper scripts..."

# Create morphy wrapper
cat > "$PUB_BIN/morphy" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Morphy CLI wrapper - runs dart directly to avoid pub noise
exec dart run "PACKAGE_DIR_PLACEHOLDER/bin/morphy.dart" "$@"
WRAPPER_EOF

# Replace placeholder with actual path
sed -i.bak "s|PACKAGE_DIR_PLACEHOLDER|$PACKAGE_DIR|g" "$PUB_BIN/morphy"
rm -f "$PUB_BIN/morphy.bak"
chmod +x "$PUB_BIN/morphy"

# Create morphy_mcp_server wrapper
cat > "$PUB_BIN/morphy_mcp_server" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Morphy MCP Server wrapper - runs dart directly to avoid pub noise
exec dart run "PACKAGE_DIR_PLACEHOLDER/bin/morphy_mcp_server.dart" "$@"
WRAPPER_EOF

# Replace placeholder with actual path
sed -i.bak "s|PACKAGE_DIR_PLACEHOLDER|$PACKAGE_DIR|g" "$PUB_BIN/morphy_mcp_server"
rm -f "$PUB_BIN/morphy_mcp_server.bak"
chmod +x "$PUB_BIN/morphy_mcp_server"

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "Installed executables:"
echo "  • morphy"
echo "  • morphy_mcp_server"
echo ""
echo "To verify:"
echo "  morphy --version"
echo "  morphy analyze --help"
echo "  morphy from-json --help"
