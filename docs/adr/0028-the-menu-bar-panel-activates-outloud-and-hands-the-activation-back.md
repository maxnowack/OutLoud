# 0028 – On macOS, the menu bar panel makes Outloud the active app while it is open, so that it takes ← and →, and hands the activation back to the app that had it when it closes; Outloud still never activates an app to paste

- Status: accepted
- Date: 2026-10-30
- Narrows: "Outloud never activates an app" of ADR 0026 and ADR 0027 to the paste

## Context

On 2026-10-30 the user asked to step through the kept results in the menu
bar panel with ← and →, not only with buttons
(`plans/PANEL_QUEUE_AND_RESULTS.md`). macOS sends keys only to the active
app, and the panel is a popover of Outloud, which is not active: the app
the user types in keeps the keys while the panel is open.

ADR 0026 decided that Outloud never activates an app; it rejected
activating the target app for ⌘V and giving the focus back, since a
focus change the user did not make can land a paste in a field they are
not looking at. ADR 0027 kept the rule.

Alternatives:

- Buttons only, no activation — rejected by the user, who wants the arrow
  keys.
- A non-activating panel (`NSPanel` with `.nonactivatingPanel`) instead of
  the popover, which takes keys without activating Outloud — rejected: it
  replaces the popover and its placement under the icon for the arrow keys
  alone.
- Activating Outloud without handing the activation back — rejected: after
  the panel closes, Outloud stays active without a window, and a dictation
  started then finds no text field and is only copied.

## Decision

We activate Outloud when a click on the menu bar icon opens the panel,
unless it is active already, and remember the app that was in front. When
the panel closes, we activate that app again — unless Outloud is no longer
active, since the user went to another app, or a window of Outloud's is
open, such as the history opened from the panel.

Both activations follow the user's own action — the click that opens the
panel, the Escape, click or button that closes it. Outloud never activates
any app without the user's interaction, the principle the user stated on
2026-10-30 when this rule was put to them; this is the one activation of
another app. Outloud still never activates an app to paste: a dictation
that waits is pasted only when its field has the focus, by the rules of
ADR 0026 and ADR 0027.

## Consequences

- Opening the panel counts as leaving the field: a dictation processed in
  sight goes out of sight with its notice, and is pasted once the panel
  has closed and its field has the focus again.
- Escape closes the panel, since it now has the keys.
- An app that does not take the activation back would leave the user
  without a focused window; `apps/macos/e2e/pending-pastes.md` and
  `apps/macos/e2e/browse-results.md` check it with Messages and TextEdit.
- `apps/macos/AGENTS.md` §"Security" forbids every other activation of
  another app.
