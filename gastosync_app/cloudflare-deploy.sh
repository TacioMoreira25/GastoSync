#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

# Load fnm / Node if installed in ~/.local/share/fnm
if [ -d "$HOME/.local/share/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env)" 2>/dev/null || true
  for dir in "$HOME"/.local/share/fnm/node-versions/*/installation/bin; do
    if [ -d "$dir" ]; then
      export PATH="$dir:$PATH"
    fi
  done
fi

if [ ! -d "build/web" ]; then
  echo "⚙️ Build web não encontrado. Executando cloudflare-build.sh..."
  ./cloudflare-build.sh
fi

echo "🚀 Enviando build/web para o Cloudflare Pages (projeto: gastosync)..."
npx --yes wrangler pages deploy build/web --project-name=gastosync --branch=master --commit-dirty=true
