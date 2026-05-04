#!/bin/sh
set -e

# Symlink all nix store binaries into PATH
find /nix/store -maxdepth 3 -path "*/bin/*" -type f -exec ln -sf {} /usr/local/bin/ \;

# Install all provider wheels
pip install --no-cache-dir --no-deps /opt/ai-contained-*/wheel/*.whl
