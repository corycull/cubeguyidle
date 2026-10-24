# Cube Guy Idle — Modes 1–5 vertical slice

A Godot 4.3 Android idle game: capture, breed, buy and trade increasingly unhinged cubes.
This build covers the first five modes from the game plan.

| Mode | What you do |
| --- | --- |
| 1. The Ranch | Put cubes in pens to generate Squares. Pen mates buff or annoy each other through their traits. |
| 2. The Wilds | Send a 3-cube team through 20 zones. Find wild cubes and capture them with 5 tools (Net, Box, Lasso, Sad Trombone, Tax Audit). Wild Bosses appear every 5th zone. |
| 3. Nesting Boxes | Breed pairs. Children average their parents' stats, inherit traits (Dominant, Recessive or Chaotic), and can mutate. |
| 4. Gym of Corners | Train one stat at a time up to each cube's hidden Potential. |
| 5. Trading Post | Sell to Barry, Madame Hexahedra and The Collector, with haggling and tells. Buy rocks from A Child. Shop at Gary's Cube Emporium. |

Also included:
- 75 traits: the 50-trait base pool plus 5 exclusive traits for each mode, awarded as gold gift eggs at milestones.
- Procedural cube art: 7 sizes, 8 materials, 6 patterns, 0–12 eyes, mouths, edges, legs, wheels, wings, and trait cosmetics such as hats, halos, ghosts and drips.
- 9 one-time upgrades plus 5 infinite CGU upgrades.
- Random events: Cube IRS audits, Owes Money, Escape Artist, Kleptomaniac, and others.
- Offline progress (24-hour cap, 72 hours with a Workaholic cube), autosave, and a Codex.

## Install on your phone

1. Copy `CubeGuyIdle.apk` to your Android phone (Android 5.0+, 64-bit or 32-bit ARM).
2. Open it. Android will ask you to allow installs from that app (Files, Chrome, etc.). Allow it.
3. Tap **Install**.

The APK is signed with a test key that is not in this repo (signing keys stay out of public git).
Android only lets an update install over an existing copy if it's signed with the same key, so keep that file to ship test updates.
**Make your own private key before any Play Store release.** This one is not secret.

## Open and edit the project

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. In Godot's Project Manager, click **Import** and select this folder's `project.godot`.
3. Press **F5** to run. The window is phone-shaped (portrait), and mouse clicks act as taps.

### Code map

| File | Role |
| --- | --- |
| `scripts/trait_db.gd` | All 75 traits: rarity, inheritance, description, effect values |
| `scripts/cube_lib.gd` | Genetics: wild cube generation, breeding, rarity, value |
| `scripts/game_state.gd` | All rules and state: economy, modes, events, milestones, save/load, offline |
| `scripts/main.gd` | The whole UI, built in code: screens, popups, toasts, reveals |
| `scripts/cube_view.gd` | Procedural cube and egg drawing |

Most balance numbers live as constants at the top of `game_state.gd`: `ZONES`, `TOOLS`, `UPGRADES`, `MILESTONES` and `TRADERS`.

## Build your own APK

1. Install Android Studio (for the Android SDK) and JDK 17.
2. In Godot, open **Editor > Manage Export Templates** and download the 4.3 templates.
3. Open **Editor > Editor Settings > Export > Android** and set the Android SDK path, the Java SDK path, and a debug keystore.
4. Open **Project > Export**. The **Android** preset is already set up (package `com.cubeguy.idle`). Turn on **Package > Signed** and add your release keystore, or export unsigned and sign it yourself.
5. Click **Export Project**.

## Automatic builds (GitHub Actions)

`.github/workflows/android.yml` runs on every push to `main` and every pull request:

1. Boots the game and runs a 3-hour playtest bot. The build fails on any script error or broken state.
2. Exports the APK and signs it.
3. Attaches the APK to the run. Download it from the **Actions** tab, under the run's **Artifacts**.

To publish a release, push a version tag. The APK is attached to a new GitHub Release:

```
git tag v0.2.0
git push origin v0.2.0
```

**Signing:** add these three repository secrets under **Settings > Secrets and variables > Actions**:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_ALIAS`.
Without them, builds are signed with a throwaway key and named `-unofficial`. Those install fine but can't update a copy signed with your real key.

## Tests

Two test scenes are excluded from the APK:

- `tests/sim.tscn`: a bot plays 30 fast-forwarded hours and checks for broken state, save/load and offline progress.
  Run: `godot --headless --path . res://tests/sim.tscn`
- `tests/ui.tscn`: opens every screen and popup and saves screenshots to the user data folder.
  Run: `godot --path . --resolution 720x1280 res://tests/ui.tscn` (add `-- --fresh` for a new game).

**Warning:** both tests overwrite your local save file.

Pacing from the bot, which plays every 20 seconds. Real players will be slower.

| Time | Progress |
| --- | --- |
| ~10 min | Gym and Trading Post unlocked |
| ~2 h | Zone 8, ~60 cubes, first Mythic cubes |
| ~12 h | Zone 12, ~800 Squares/sec |
| ~30 h | Zone 14. Ranch Gold/Mastery and Wilds 15–20 still ahead |

## Differences from the game plan doc

- Some trait effects were made concrete for this slice, since Vibes, Lore and shows don't exist yet:
  - Picky Eater: −10% training.
  - Haunted: +5% Squares, plus a 3am moan event.
  - Ego Death: −50% Charisma instead of "can't enter shows".
  - Dramatic: random ±25% trade prices.
  - Barn Burner: doubles output at :00–:10 each hour.
  - Deal of a Lifetime: triple payout once a day.
  - Accidentally Immortal: can't be released, but traders accept it. Otherwise immortal cubes clog the barn and soft-lock the game.
- The Trading Post unlocks at Zone 5 (about 10 minutes in) rather than hour 2.
- Gary restocks every 4 hours or on demand for Squares.
- Not in this slice: modes 6–30, prestige layers, Vibes/Lore currencies, the Glue Factory (release refunds a little instead), and seasons.
