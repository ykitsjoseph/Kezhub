# Kezhub

Practical Basketball executor suite — `KezHubMobile.lua`.

```text
load:  paste KezHubMobile.lua into any executor (Wave, Solara, Delta, Synapse-class)
menu:  RightShift (desktop) / H button then the floating PB button (mobile)
```

## v3

- **Auto Shoot** fires on its own: probes `mouse1press` / `mouse1release`, then
  `VirtualUser` hold, then a click tap. Per-frame dynamic meter read finds any
  animating bar and releases where it meets the green segment — no reliance on
  object names or a single colour. Also reads perfect text, power bars, ball
  attributes and a learned release lead.
- **Fallback release** when no meter signal exists, plus a per-shot timeout, so
  the shot never stays held forever.
- **Ball detection** handles BasePart, Model and Tool balls, owner attributes and
  a configurable possession range.
- **Mobile**: auto-fit UI scale, touch drag and sliders, on-screen hide/restore.
- **UI**: sharp-cornered tabbed rectangle window, theme swatches, live signal
  readout (`SIGNAL` + ball / distance / green / text / dynamic-meter line).

## Notes

Syntax-checked with `luac 5.4` and driven against a Roblox API stub with
synthetic horizontal, vertical and delayed-green shot meters, both hold and tap
input paths. In-game behaviour on the live build is still unverified — use the
`TEST SHOT` button on the SHOT page and read the status line if a meter is not
being picked up.
