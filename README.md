# Kezhub

Blade Ball executor suite — `KezHubMobile.lua`.

```text
load:  paste KezHubMobile.lua into any executor (Wave, Solara, Delta, Synapse-class)
menu:  RightShift (desktop) / H button then the floating BB button (mobile)
```

## Auto Parry

- **Ball tracking** finds the live ball by name (`ball`, `bladeball`, `orb`, any
  name containing `ball`, or a `Model` with a ball-like `Handle`), skipping your
  own character. Velocity is sampled per-instance, so closing speed and time to
  impact come from real motion rather than distance alone.
- **Prediction** fires when the ball is inside `Parry Range` *and* its ETA is
  under `Parry Lead` (default 120 ms before impact). Turn prediction off to
  parry on distance only. `Incoming Only` ignores balls that are moving away,
  with a forced parry under 5 studs as a safety net.
- **Parry Method** decides how the parry is sent:
  - `AUTO` — remote if one is found, then the parry key, then a click
  - `REMOTE` — fires the discovered parry `RemoteEvent` / `RemoteFunction`
  - `KEY` — sends the parry key (default `Q`)
  - `CLICK` — clicks the viewport centre
- **Test parry** button proves the input bridge works before you trust it, and
  the status row shows `SIGNAL // method // count` plus a live
  `distance / eta / speed` line.

## Combat / Move / Visual

- **Combat** — auto aim (with strength), auto curve toward the ball's lead
  point, auto dodge out of the ball path, auto ability key on a cooldown,
  auto clash in close range, and auto return after a configurable delay.
- **Move** — walk speed and jump power sliders, infinite jump.
- **Visual** — ball ESP highlight plus a distance tag, parry flash, watermark,
  FPS and ping counters.
- **Theme** — six accent swatches, UI scale, window transparency, rebindable
  menu key, config save / load / factory reset, kill switch.

The window keeps the original sharp-cornered tabbed rectangle layout, mobile
auto-fit scale, touch drag, and hide/restore button.

## Debugging (VISUAL page)

```text
Capture Log  ON   -> every parry writes one line (file + console)
Dump scan    DUMP -> writes remotes, ball candidates and GUI hints
```

Output:

```text
ollie_bb_capture.txt   parry log
ollie_bb_scan.txt      remotes / balls / gui dump
ollie_bb.json          saved config
[BB] ...               same lines in the executor console
```

Parry line format:

```text
#1 parry reason=eta method=remote eta=109ms dist=10.4m speed=100 ball=Ball
```

`reason` is `eta`, `spam`, `clash`, `return` or `test`; `method` is `remote`,
`key`, `click`, `vu` or `none`. If `method=none`, no input bridge is available —
check `ollie_bb_scan.txt` for the real remote name and use `Find remote`.

## Notes

Syntax-checked with `luac 5.4` and driven against a Roblox API stub with a
synthetic incoming ball at 100 studs/s. Verified in the harness: parry fires at
the 120 ms lead over the remote path, the `KEY` path fires with the remote absent,
capture and scan files are written, and all page buttons exist. Live behaviour
in the real game is unverified — remote names and the parry key are heuristics,
so use `Test parry` and `Dump scan` first if nothing registers.
