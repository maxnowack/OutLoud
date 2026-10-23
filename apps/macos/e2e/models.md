# The user downloads, stops and deletes models in the settings

- Covers: Settings › Models, ModelRow states, the delete warning for the shared cache.
- Build: Debug.

## Preconditions

Setup completed. Network available.

## Steps

1. Open Settings › Models. Each purpose shows its model with "Delete" and a green check mark.
2. Click "Delete" for Qwen 3.5 0.8B. A dialog "Delete Qwen 3.5 0.8B?" warns that the model lies
   in the shared Hugging Face cache and other apps will have to download it again. Click
   "Delete": the row shows "Download".
3. Click "Download": a progress bar with "x of y" and "Stop" appear. Click "Stop": the row
   returns to "Download"; no `*.incomplete` file stays in
   `~/.cache/huggingface/hub/models--unsloth--Qwen3.5-0.8B-GGUF/blobs/`.
4. Click "Download" and wait: the row shows the check mark again.
5. Turn off Wi-Fi and look at a model that is not installed: "Download" is disabled.

## Assertions

- After step 2, `~/.cache/huggingface/hub/models--unsloth--Qwen3.5-0.8B-GGUF/` is gone, and no
  other folder in the cache changed.
- After step 4, `swift run outloud models` reports the model installed.

## Screen reader pass

Each row is read as "<model>, downloaded / not downloaded / downloading"; the dialog's warning
is read in full.
