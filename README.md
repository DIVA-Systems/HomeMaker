# HomeMaker

Interior design for **phone and tablet** — sketch walls, place furniture from free Sweet Home 3D libraries, and preview in isometric 3D.

Desktop and web come later.

## What’s included

- Adaptive editor: split catalog + canvas on tablet; bottom-sheet catalog on phone
- 124 curated furniture models (Free Art / CC-BY / CC0) — see `assets/catalog/ATTRIBUTIONS.md`
- Plan save/load on device
- First-run welcome, Apple-inspired light UI (spruce + paper canvas)

## Run

```bash
export PATH="$HOME/Flutter/flutter/bin:$PATH"
cd /Users/kira/DIVA-Systems/homeMaker
flutter pub get
flutter run
```

Prefer an iPad simulator or large Android tablet for the split layout.

## Assets

Curated OBJ icons/models live under `assets/catalog/`. Raw SourceForge ZIPs stay in `tool/.download_cache/` (gitignored).

## License notes

App code: your project license. Furniture models remain under their upstream licenses; keep attributions when redistributing.
# HomeMaker
