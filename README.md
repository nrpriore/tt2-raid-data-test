# Tap Titans 2 – Raid Data

This repository hosts static raid balance data for the Tap Titans 2 raid simulator app.

The goal of this repo is to allow seasonal / balance updates to be delivered to users without requiring an App Store update.

All files are served via GitHub Pages and are intended to be fetched by the app at runtime.

---

## 📄 Data Files

All data files live under a schema/version folder (ex: `v2/data/`) and are plain text (`.txt`) files.

Each file contains delimited data that is parsed by the simulator.

### Files included
- `Skill.txt`
- `Level.txt`
- `Enemy.txt`
- `Area.txt`
- `RaidResearch.txt`
- `TitanResearch.txt`
- `GemstoneResearch.txt`

---

## 🧾 Manifest

The app checks a schema-specific `manifest.json` to determine whether the `dataVersion` has changed and then uses the computed hash per file to determine if any updates are needed.

---

## 🔢 Schema versions (`vN/` pattern)

- **Legacy v1 (root)**: The original release expects the manifest + folders at the repo root (`manifest.json`, `data/`, `config/`). This is deprecated but cannot be moved/removed without breaking that already-released app version.
- **v2+ (versioned folders)**: Any schema changes (ex: max card level increase / new columns) should go in a versioned folder like `v2/`, `v3/`, etc:
  - `vN/manifest.json`
  - `vN/data/*.txt`
  - `vN/config/*.json`

The app code is tied to a schema version and should hardcode the correct manifest URL, e.g. `.../v2/manifest.json`. This avoids “chicken-and-egg” issues between publishing new data vs app store rollout timing.

### Updating hashes + `dataVersion` for v2+

From the repo root:

```powershell
.\helpers\update-manifest.ps1 -FormatVersion 2
```

```bash
./helpers/update-manifest.zsh 2
```

These scripts update only `vN/manifest.json` (not v1/root):
- Recomputes SHA256 hashes for `vN/data/*` + `vN/config/*`
- Updates `csvData.baseUrl` / `config.baseUrl` to match the `vN/` folder
- Bumps `dataVersion` (UTC, minute precision)
