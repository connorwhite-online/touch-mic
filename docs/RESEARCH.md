# Research

External sources behind the design, and an honest split between what was
verified and what was not. Claims made here without a link were read directly
out of Claude Desktop's own `app.asar` or logs on the dev machine.

## Verified

### Claude dictation

- [Claude Code voice dictation docs](https://code.claude.com/docs/en/voice-dictation.md)
  — confirms transcription is tuned for coding vocabulary and that project and
  branch names are added as recognition hints. This is the whole reason the
  device targets Claude rather than system dictation. Also documents
  `voice:pushToTalk` (CLI, default `Space`, rebindable in
  `~/.claude/keybindings.json`) and a true hold mode.
- [Quick Entry support article](https://support.claude.com/en/articles/12626668-use-quick-entry-with-claude-desktop-on-mac)
  — the Quick Entry voice shortcut is a toggle and opens a **new chat**. It is
  not the in-conversation dictation this project wants.
- [voice:pushToTalk multi-binding bug](https://claudeissues.com/issue/59896-bug-voice-pushtotalk-multi-binding-silently-picks-one-key-the-chosen-key-changed)
  — with several keys bound, ≤2.1.140 used the first listed, ≥2.1.141 the last.
- [Request for an in-chat voice shortcut](https://claudeissues.com/issue/48305-feature-request-keyboard-shortcut-for-microphone-in-main-chat-window-claude-desk)
  — confirms no keyboard shortcut exists for the composer mic button, which is
  what forced the Accessibility route.

### Capacitive sensing

- [Adafruit: CircuitPython cap touch](https://learn.adafruit.com/circuitpython-essentials/circuitpython-cap-touch)
  — on SAMD21 the touch sensing is done **in hardware**, no external resistors,
  capacitors or ICs.
- [Pico vs SAMD21 touch implementations](https://diyelectromusic.com/2023/06/12/raspberry-pi-pico-capacitive-touch/)
  — SAMD21 uses the QTouch PTC; ports without that hardware fall back to a
  software method.
- [Capricate (UIST'15)](https://mschmitz.org/publications/schmitz-UIST15-capricate.pdf)
  — overlay thickness dominates sensitivity; 0.2 mm electrodes still give a
  measurable change; **30 kΩ is the practical wire-resistance ceiling** before
  SNR falls. This is the number the foam-vs-ESD-TPU argument rests on.
- [Cap touch inside a printed enclosure](https://community.aisler.net/t/invisible-capacitive-touch-button-inside-a-3d-printed-enclosure/5506)
  — stable touch response through a 1–2 mm printed wall.
- [Microchip single-key touch controllers](https://ww1.microchip.com/downloads/en/DeviceDoc/doc8287.pdf)
  — AT42QT1010 force-releases after ~60 s; 1011 has no timeout; 1012 adds true
  toggle. Relevant if a dedicated front end is ever needed.
- [TI: capacitive drift compensation](https://www.ti.com/lit/pdf/slaa550)
  — baseline tracking is standard practice, not an optimisation. Informs the
  firmware's drift handling.

### SLS TPU

- [Formlabs TPU 90A](https://now.formlabs.com/resources/tpu-90a-sls)
  — **1.0 mm minimum wall**, above the nylon figure because flexible walls
  distort during depowdering; holes ≥1.0 mm; powder-trapping cavities need
  **two escape holes ≥3.5 mm**.
- [SLS TPU design rules](https://3dspro.com/resources/blog/design-rules-for-tpu-powders-in-sls)
  — 1.0–1.5 mm comfortable range; add 0.3–0.5 mm over PA12 figures.
- [Hubs SLS design guide](https://www.hubs.com/knowledge-base/how-design-parts-sls-3d-printing/)
  — escape-hole placement at cavity low points in the cleaning orientation.

### Conductive materials

- [Stretchable silver inks for wearables](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8147316/)
  — TPU is among the easier elastomer substrates thanks to relatively high
  surface energy; ink and substrate surface energies must be comparable or the
  ink delaminates under flex.
- [ACI SS1109](https://www.acimaterials.com/ss1109/) — silver ink formulated for
  TPU, >200% elongation (vendor claim). The fallback if a lined shell is ever
  needed.
- Conductive vs dissipative foam resistance bands, and the ANSI/ESD STM11.12
  volume test — see [`hardware/BOM.md`](../hardware/BOM.md) for links.

## Not verified — treat with suspicion

- **Which XIAO pins support QTouch.** A reseller manual says A0/A6/A7; Seeed's
  wiki does not list them. Single-source.
- **Triboelectric behaviour of SLS TPU.** Searched for directly, nothing found.
  A porous elastomer rubbed in dry air beside a high-impedance sense line is a
  real concern and this is the project's **largest unknown**. Only testable on a
  printed part.
- **Actual resistivity of FDM TPU-ESD.** ESD grades span 10⁶–10⁹ Ω·cm, which is
  the difference between marginal and dead. Cheap to settle, not yet settled.
- **Conductive PLA resistivity** (~15 Ω·cm) is a typical vendor figure from
  general knowledge, not confirmed against the materialize.cc catalogue.
- **Whether Claude Desktop honours `~/.claude/keybindings.json`.** Reports say
  the file is CLI-only. Not tested here, because the Accessibility route
  superseded it.

## Dead ends, recorded so they are not repeated

- **Claude's `dictationShortcut` config key.** Accepts an accelerator, persists
  across restarts, and does nothing — gated behind a GrowthBook flag. Full
  write-up in [`DECISIONS.md`](DECISIONS.md).
- **claude.ai web settings.** Checked; exposes no voice or dictation shortcut.
- **Conductive filament as the electrode.** No conductive SLS powder exists and
  SLS is one powder per build. Catalogue check returned only Conductive PLA
  (FDM, rigid).
