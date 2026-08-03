English Version | [中文版](Development-Notes)

# Development Notes

Practical notes for contributors, focused on **test-font reproducibility**. For architecture and the test system overview, see [[Development | EN:Development]].

---

## 1. Test fonts are pinned — they do not come from your system

- The single source of truth is `scripts/font-manifest.json`: immutable download URL, SHA-256, version, and license for every font.
- `python3 scripts/download_fonts.py --all` fetches them into `test/fonts/` (gitignored); fonts are **never installed into the system font library**.
- `regression_test.py` points `OSFONTDIR` at `test/fonts/` so luaotfload can find them.
- Regression comparison is **pixel-exact with zero tolerance**: with pinned fonts, macOS and CI (Linux) render byte-identically, so any pixel diff is a real regression.

## 2. ⚠️ If your machine has the same font installed, its version must match the manifest

This is the easiest pitfall to hit and the most confusing to diagnose.

**Mechanism**: fonts referenced **by name** in test .tex files (e.g. `\setmainfont{Source Han Serif SC}`) are resolved by luaotfload's name index, which prefers a copy installed on your system (e.g. `~/Library/Fonts/SourceHanSerif.ttc`) over the pinned file in `test/fonts/`. If the versions differ, baselines saved on your machine will not match CI.

**Real case (2026-08)**: a dev machine had Source Han Serif 2.002 installed while the manifest pins 2.003. Adobe changed the outlines of 91 URO glyphs between the two versions (including 大, 天, 女). Baselines re-saved under 2.002 made CI fail with ~0.005% pixel diffs on pages containing those glyphs.

**Symptoms**: CI fails with tiny diffs (<0.01%); diff images look identical to the eye; differing pixels cluster on stroke edges of a few CJK glyphs.

**Diagnose**:

```bash
luaotfload-tool --find="Source Han Serif SC"   # which file the name resolves to
```

and compare the `name` table version strings of the system copy vs `test/fonts/SourceHanSerifSC-Regular.otf` (fontTools).

**Fix**: upgrade/replace the locally installed font to the manifest version (currently **Source Han Serif 2.003R**; the Super OTC is `01_SourceHanSerif.ttc.zip` in the [adobe-fonts 2.003R release](https://github.com/adobe-fonts/source-han-serif/releases/tag/2.003R)), then run `luaotfload-tool --update`. Machines without a system copy are unaffected.

> Cases referencing fonts **by filename** (e.g. `hori.tex` with `\setmainfont{SourceHanSerifSC-Regular.otf}`) are immune — file lookup only hits the pinned copy.

## 3. Updating baselines (save)

- `save` accepts explicit files and routes each to its own suite (basic / past_issue / complete):

  ```bash
  python3 test/regression_test.py save test/regression_test/complete/tex/font.tex
  ```

- **Before saving, understand where the diff comes from**: an intended effect of your change, or environment drift (font versions!). Only the former should be saved.
- Re-run the full check afterwards: `python3 test/regression_test.py check --all`.
- **CI only runs the basic suite** — past_issue and complete baselines are only guarded by local `--all` runs.

## 4. Test order (mandatory)

```bash
texlua test/run_all.lua                      # 1. unit tests (first)
python3 test/regression_test.py check --all  # 2. visual regression
python3 test/clreq_test.py                   # 3. clreq metric assertions
python3 test/geometry_test.py                # 4. geometry self-check (baseline-free)
```

Update unit tests together with any change that affects their results; never skip unit tests and run regression directly.

## 5. Font licensing baseline

- Tests and examples only use fonts with **verifiable origin and license** (OFL, Arphic PL, CC0, government open licenses), always pinned via the manifest.
- Example PDFs embed font subsets and are distributed with the repo — **check embedded fonts with `pdffonts`** before committing.
- Adding a font: add a manifest entry (immutable URL, SHA-256, license); never copy files by hand. See `ai_must_read/docs/font-metrics.md` for license assessments.
