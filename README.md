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
- **Hold Time** slider (50-2000 ms) with a new `TIMED` release mode: hold for an
  exact duration and release, no meter reading required. Tune it against the
  green window, then optionally add `Green Bias` on top of detected greens.
- **Fallback release** when no meter signal exists, plus a per-shot timeout, so
  the shot never stays held forever.
- **Ball detection** handles BasePart, Model and Tool balls, owner attributes and
  a configurable possession range.
- **Mobile**: auto-fit UI scale, touch drag and sliders, on-screen hide/restore.
- **UI**: sharp-cornered tabbed rectangle window, theme swatches, live signal
  readout (`SIGNAL` + ball / distance / green / text / dynamic-meter line).

## Tuning data (SHOT page)

```text
Capture Log      ON  -> every shot writes / prints one line
Dump meter UI    DUMP -> writes the live PlayerGui tree around the meter
Hold Time        ---  -> timed hold, used when Release Mode = TIMED
```

Output:

```text
ollie_pb_capture.txt   ollie_pb_ui.txt     (executor workspace folder)
[PB] ...                                  (executor console, same lines)
```

Shot line format:

```text
#1 dur=90ms reason=signal mode=AUTO fire=AUTO bridge=virtualuser ball=Basketball
   d=1.4m green=1 text=0 dynmove=yes dynhit=x fill=(100,500 210x18) zone=(280,500 30x18)
```

`dur` is press-to-release in ms; `reason` is `signal`, `fallback`, `timeout`,
`detach` or `test-*`; `dynhit` is the exact fill/zone geometry that triggered.
In `TIMED` mode `dur` should read back the Hold Time value, so it doubles as a
sanity check that the configured hold is what actually went out.
A dump of `ollie_pb_ui.txt` taken during a shot identifies the real meter
widgets (names, classes, positions, sizes, colours).

## Notes

Syntax-checked with `luac 5.4` and driven against a Roblox API stub with
synthetic horizontal, vertical and delayed-green shot meters, both hold and tap
input paths, and the capture/dump writers. In-game behaviour on the live build
is still unverified — use `TEST SHOT` and read the status line if a meter is not
being picked up.
