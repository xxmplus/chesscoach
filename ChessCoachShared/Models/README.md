# Local LLM Models

This directory intentionally does **not** contain GGUF model binaries.

ChessCoach keeps only model metadata in source control. Users and developers can choose which GGUF model to use, download it from its upstream repository, and either:

1. let the app download the configured model into the app Documents directory at runtime, or
2. place a local `.gguf` file in this directory for a private/local build.

`.gguf` files are ignored by Git so large model blobs do not enter repository history.

## Default model metadata

The current default model is defined in `ChessCoachShared/LocalInferenceConfig.swift`:

| Field | Value |
|---|---|
| Display name | DeepSeek-R1 Distill (1.5B) |
| Hugging Face repo | `unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF` |
| File name | `DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf` |
| Approximate size | 1065 MB |
| Chat template | `chatml` |

Direct download URL:

```text
https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf
```

Manual download command:

```bash
curl -L \
  -o ChessCoachShared/Models/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf \
  "https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf"
```

After manual download, regenerate/build the project as usual. The local file stays untracked.

## Trying another model

To try another model, update or add a `ModelConfig` in `ChessCoachShared/LocalInferenceConfig.swift` with:

- `repoId`
- `fileName`
- `displayName`
- `bundleSizeMB`
- `estimatedTokensPerSecond`
- `chatTemplate`

Then either let the app download it or manually place the matching `.gguf` file here.

Keep iPhone memory limits in mind. The 1.5B Q4 model is the safe default; 4B+ models may only work comfortably on higher-memory devices.
