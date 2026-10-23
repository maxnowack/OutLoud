# The user downloads, stops and deletes the transcription model in the settings

- Covers: Settings › Models, ModelRow states, the delete warning for the shared cache.
- Build: Debug.

## Preconditions

Setup completed. Network available.

## Steps

1. Open Settings › Models. "Transcription" shows Parakeet v3 with "Delete" and a green check
   mark; there is no cleanup model (ADR 0019).
2. Click "Delete". A dialog "Delete Parakeet v3?" warns that the model lies in the shared
   Hugging Face cache and other apps will have to download it again. Click "Delete": the row
   shows "Download".
3. Click "Download": a progress bar with "x of y" and "Stop" appear. Click "Stop": the row
   returns to "Download"; no `*.incomplete` file stays in
   `~/.cache/huggingface/hub/models--FluidInference--parakeet-tdt-0.6b-v3-coreml/blobs/`.
4. Turn off Wi-Fi: "Download" is disabled. Turn it on again.
5. Click "Download" and wait (483 MB): the row shows the check mark again.

## Assertions

- After step 2, `~/.cache/huggingface/hub/models--FluidInference--parakeet-tdt-0.6b-v3-coreml/`
  is gone, and no other folder in the cache changed.
- After step 5, `swift run outloud models` reports the model installed.

## Screen reader pass

Each row is read as "<model>, downloaded / not downloaded / downloading"; the dialog's warning
is read in full.
