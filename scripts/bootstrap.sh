#!/bin/bash
# bootstrap.sh — Ensures all build-time dependencies are present.
#
# This script is the single source of truth for fetching large binary assets
# (Stockfish WASM, LLM GGUF model) that are intentionally NOT tracked in Git
# because they are too large or change too often.
#
# Two modes:
#   ./scripts/bootstrap.sh          Interactive — asks before downloading the LLM model.
#   ./scripts/bootstrap.sh --check  Non-interactive — fails if assets are missing.
#   ./scripts/bootstrap.sh --fetch  Non-interactive — auto-downloads everything.
#
# The Xcode pre-build phase calls --check so a fresh clone fails fast with a clear
# message telling the developer to run bootstrap.sh. CI can use --fetch for fully
# automated builds.
#
set -euo pipefail

# Determine the project root:
# - In Xcode build context: PROJECT_DIR is set to the directory containing the .xcodeproj.
# - Otherwise: derive it from the script's own location.
if [[ -n "${PROJECT_DIR:-}" ]]; then
    REPO_ROOT="$PROJECT_DIR"
else
    # Script is at chesscoach/scripts/bootstrap.sh
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
ASSETS_DIR="$REPO_ROOT/ChessCoachApp/Assets/stockfish"
MODELS_DIR="$REPO_ROOT/ChessCoachShared/Models"

# ── Model config (must stay in sync with LocalInferenceConfig.swift) ────────────
MODEL_FILE="DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
MODEL_SIZE_MB=1065

# ── Stockfish config ───────────────────────────────────────────────────────────
SF_VERSION="16.1"
SF_BASE_URL="https://cdn.jsdelivr.net/npm/stockfish.js@${SF_VERSION}/src"
SF_FILES=("stockfish.js" "stockfish.wasm")

# ── Helpers ────────────────────────────────────────────────────────────────────
info()  { echo "Bootstrap: $*" >&2; }
warn()  { echo "Bootstrap WARNING: $*" >&2; }
failed(){ echo "Bootstrap ERROR: $*" >&2; exit 1; }

need_space_mb() {
    local required=$1 avail
    avail=$(df -m "$REPO_ROOT" 2>/dev/null | awk 'NR==2 {print $4}') || return 0
    if (( ${avail:-0} < required )); then
        warn "Only ${avail} MB free, need ~${required} MB"
        return 1
    fi
    return 0
}

fetch() {
    local url=$1 dest=$2 size_mb=${3:-}
    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]]; then
        info "$(basename "$dest") already exists — skipping"
        return 0
    fi
    if [[ -n "$size_mb" ]]; then
        need_space_mb "$size_mb" || info "Continuing anyway — download may fail if disk is full"
    fi
    info "Downloading $(basename "$dest")..."
    curl -L --fail --show-error --progress-bar -o "$dest" "$url"
    info "Downloaded: $(basename "$dest")"
}

# ── Bootstrap Stockfish WASM ───────────────────────────────────────────────────
bootstrap_stockfish() {
    mkdir -p "$ASSETS_DIR"
    for file in "${SF_FILES[@]}"; do
        fetch "${SF_BASE_URL}/${file}" "$ASSETS_DIR/${file}"
    done

    # Write a minimal stockfish.wasm.js shim if the real Emscripten file is absent.
    local wasm_js="$ASSETS_DIR/stockfish.wasm.js"
    if [[ ! -f "$wasm_js" ]]; then
        info "Creating stockfish.wasm.js shim"
        cat > "$wasm_js" << 'WASM_SHIM'
// stockfish.wasm.js — minimal shim
// Provides the Module.locateFile() hook expected by stockfish.js so it can
// find stockfish.wasm in the same directory at runtime.
if (typeof Module === 'undefined') var Module = {};
Module.locateFile = function(file) { return file; };
WASM_SHIM
        info "Created stockfish.wasm.js shim"
    fi
}

# ── Bootstrap LLM model ────────────────────────────────────────────────────────
bootstrap_llm() {
    mkdir -p "$MODELS_DIR"
    fetch "$MODEL_URL" "$MODELS_DIR/$MODEL_FILE" "$MODEL_SIZE_MB"
}

# ── Check ──────────────────────────────────────────────────────────────────────
check_assets() {
    local missing=0
    for file in "${SF_FILES[@]}"; do
        if [[ ! -f "$ASSETS_DIR/$file" ]]; then
            warn "Missing Stockfish: $ASSETS_DIR/$file"
            missing=1
        fi
    done
    if [[ ! -f "$ASSETS_DIR/stockfish.wasm.js" ]]; then
        warn "Missing: $ASSETS_DIR/stockfish.wasm.js"
        missing=1
    fi
    if [[ ! -f "$MODELS_DIR/$MODEL_FILE" ]]; then
        warn "Missing LLM model: $MODELS_DIR/$MODEL_FILE"
        missing=1
    fi
    return $missing
}

# ── Main ─────────────────────────────────────────────────────────────────────
MODE="${1:-interactive}"
info "ChessCoach bootstrap — mode: $MODE"
info "Repo root: $REPO_ROOT"

case "$MODE" in
    --check)
        # CI / pre-build phase: fail fast, no downloads.
        if check_assets; then
            info "All assets present"
            exit 0
        else
            echo "" >&2
            echo "=== Bootstrap failed ===" >&2
            echo "One or more build dependencies are missing." >&2
            echo "Run './scripts/bootstrap.sh' to download them." >&2
            echo "" >&2
            exit 1
        fi
        ;;

    --fetch)
        # Fully automated (CI pipelines).
        info "=== Fetching Stockfish WASM ==="
        bootstrap_stockfish
        info "=== Fetching LLM GGUF model (~${MODEL_SIZE_MB} MB) ==="
        bootstrap_llm
        info "=== Done — all assets ready ==="
        ;;

    interactive|"")
        info "=== Stockfish WASM ==="
        bootstrap_stockfish
        info "=== LLM GGUF Model ==="
        info "File: $MODEL_FILE (~${MODEL_SIZE_MB} MB)"
        info "Source: $MODEL_URL"
        if [[ -f "$MODELS_DIR/$MODEL_FILE" ]]; then
            info "Model already exists — skipping download"
        else
            info ""
            info "This will download ~${MODEL_SIZE_MB} MB from HuggingFace."
            read -p "Proceed with LLM download? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
                info "Skipped. The app will use template-based coaching without the LLM."
            else
                bootstrap_llm
            fi
        fi
        info "=== Done ==="
        ;;

    *)
        failed "Unknown argument: $MODE"
        ;;
esac
