# testing-agent-llm — llama.cpp + llama-swap container.
#
# Strategy: take the upstream llama.cpp server image (which already ships
# `llama-server` on PATH plus all the runtime libs llama.cpp needs) and
# layer the static `llama-swap` binary on top. llama-swap proxies
# OpenAI-compatible requests to the right per-model llama-server instance,
# spawning them on demand based on the YAML config we mount in.
#
# The YAML lives in the SHARED bind-mount /var/lib/llm-models alongside the
# GGUF files. The backend regenerates it after every CRUD on llm_models, and
# llama-swap (started with -watch-config) reloads on file change without
# requiring a container restart.

FROM ghcr.io/ggml-org/llama.cpp:server

# Pin llama-swap to a specific tagged release. Bump this and the URL together
# whenever upgrading. The static binary has no dynamic linker requirements.
ARG LLAMA_SWAP_VERSION=199
# Docker BuildKit automatically populates TARGETARCH with the build target's
# architecture (amd64, arm64, ...). Declaring the ARG without a default lets
# `docker build` on an arm64 host produce an arm64 image with the matching
# llama-swap binary, and the same Dockerfile still cross-builds for amd64 on
# CI via --platform=linux/amd64.
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/llama-swap.tar.gz \
      "https://github.com/mostlygeek/llama-swap/releases/download/v${LLAMA_SWAP_VERSION}/llama-swap_${LLAMA_SWAP_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && tar -xzf /tmp/llama-swap.tar.gz -C /usr/local/bin llama-swap \
 && chmod +x /usr/local/bin/llama-swap \
 && rm /tmp/llama-swap.tar.gz \
 && /usr/local/bin/llama-swap --version || /usr/local/bin/llama-swap -version || true

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

# llama.cpp's image sets ENTRYPOINT to llama-server; override it.
ENTRYPOINT ["/entrypoint.sh"]
