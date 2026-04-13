#!/bin/sh
# Entrypoint for the testing-agent-llm container.
#
# llama-swap reads its YAML from the shared bind-mount
# /var/lib/llm-models/llama-swap.yaml. The backend regenerates this file
# after every CRUD on llm_models (and during initial seed), so normally
# the file exists before this container starts.
#
# However, on a fresh install the user may start `llm` before the backend
# has had a chance to seed — e.g. `docker compose up llm` alone. Write a
# minimal stub in that case so llama-swap has something valid to load.
# The stub routes nothing; as soon as the backend comes up and seeds,
# the watch-config reload will pick up the real config and swap in the
# model entries.

set -e

CONFIG="/var/lib/llm-models/llama-swap.yaml"

if [ ! -f "$CONFIG" ]; then
  echo "[entrypoint] $CONFIG not found — writing empty stub"
  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<'EOF'
healthCheckTimeout: 90
models: {}
EOF
fi

echo "[entrypoint] starting llama-swap with config $CONFIG"
exec /usr/local/bin/llama-swap \
  -config "$CONFIG" \
  -watch-config \
  -listen :8080
