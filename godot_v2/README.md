# Riftforged Godot V2

This directory is the clean Godot 4.7.2 rebuild of the Riftforged mobile/desktop ARPG prototype.

The old `godot/` prototype remains only as a behavioral reference. V2 keeps its own runtime, font path, tests and gameplay architecture.

## Current platform controls

- Mobile: touch joystick + attack button.
- Desktop: WASD/arrow movement + hold left mouse button to repeatedly fire toward the cursor.
- Both paths use the same combat simulation and projectile system.

## Traditional Chinese font path

CI prepares a static Traditional Chinese Noto Sans TTF and Godot imports it as a `FontFile` resource before the project is tested/exported. UI and `Label3D` text share that imported resource, with system fallback disabled so iPhone Safari cannot silently swap fonts.

## Data-driven ARPG foundation

The current V2 gameplay layer deliberately follows general data-oriented ARPG patterns studied from the user's Grim Dawn reference material without copying proprietary code, names, database records or assets.

- `scripts/grim_data.gd`: monster archetype/BIO-style stats, behavior, speed, skill timing, low-health triggers and death behavior.
- `scripts/loot_system.gd`: Master profile -> level gate -> dynamic weighted base item -> weighted prefix/suffix pipeline.
- `scripts/app_grim.gd`: runtime simulation that consumes those records instead of hardcoding one enemy type.

Current original Riftforged enemy archetypes are `裂隙獵犬`, `裂隙衛士`, `裂隙咒徒` and `菁英裂隙獸`. Ranged enemies keep distance and cast dodgeable projectiles, some melee enemies enter a low-health berserk state, champions can explode on death, and monsters can drop color-coded randomized equipment labels onto the ground for proximity pickup.

## CI acceptance gate

Every gameplay change must keep these passing:

- Traditional Chinese font/glyph validation.
- Portrait orthographic camera and upright Sprite3D actors.
- Mobile projectile attack.
- Desktop cursor-targeted projectile attack.
- Data-driven enemy archetypes.
- Hierarchical weighted loot/affix roll.
- Godot import, headless smoke test and Web export.
