# Bubble Budget — Backlog

Deferred items. Nothing here is blocking. Each entry states the change, why it
was deferred, and the acceptance check.

---

## BL-001 — Migrate deprecated `Color.withOpacity()` to `withValues(alpha:)`

**Status:** Deferred (raised 2026-09-02, during the aesthetic-polish handoff)
**Scope:** project-wide sweep across `lib/`
**Risk:** Low — mechanical, behaviour-identical substitution

### Context
The project resolves against Flutter >= 3.44 / Dart 3.47 (see `pubspec.lock`
`sdks:` block). `Color.withOpacity()` has been deprecated since Flutter 3.27 in
favour of `Color.withValues(alpha: ...)`. Every remaining call site therefore
emits a `deprecated_member_use` **info** in `flutter analyze`. These are infos,
not warnings or errors, so the current build is not affected.

### Known call sites — 22, verified by `flutter analyze` on 2026-09-03
| File | Count |
| --- | --- |
| `lib/screens/google_sheets_sync_screen.dart` | 8 |
| `lib/widgets/bubble_canvas.dart` | 6 |
| `lib/screens/reports_screen.dart` | 2 |
| `lib/screens/terms_screen.dart` | 2 |
| `lib/widgets/category_donut_chart.dart` | 2 |
| `lib/widgets/sheet_setup_guide_dialog.dart` | 2 |

Note: the 6 in `bubble_canvas.dart` include 2 added by the Sep 2026 polish pass
(the C3 catch-light and the C4 rim arc). They were written with `withOpacity`
on purpose, to keep the file internally consistent rather than leave it half
migrated. They go with the rest in this sweep.

`lib/screens/welcome_screen.dart` and `lib/screens/privacy_onboarding_screen.dart`
have no occurrences — both were rewritten using const ARGB literals.

### Proposed change
`x.withOpacity(0.24)` -> `x.withValues(alpha: 0.24)`

Note: `withValues` is not a drop-in for `withAlpha`. Leave existing
`withAlpha(int)` calls alone — they are not deprecated.

### Why deferred
Kept out of the aesthetic-polish diff so that visual review and lint cleanup
stay reviewable as separate commits.

### Acceptance
- `grep -rn "withOpacity" lib/` returns nothing
- `flutter analyze` reports `No issues found!`
- `flutter test` — all 31 tests green

---

## BL-002 — Dark theme is under-specified in `AppTheme.darkTheme`

**Status:** Deferred by decision (2026-09-02) — not a defect
**Scope:** `lib/theme/app_theme.dart`

`lightTheme` defines `textTheme`, `cardTheme`, `dialogTheme` and
`inputDecorationTheme`; `darkTheme` defines only `scaffoldBackgroundColor`,
a blue-seeded `colorScheme` and a transparent `appBarTheme`, so dark mode falls
back to Material 3 defaults for those surfaces.

**Decision:** Leave as-is. Verified good on simulator, Android device and
iPhone in both Dark and Soft Light mode. Revisit only if a specific dark-mode
surface is reported as off.

---

## BL-003 — Migrate deprecated `share_plus` static API

**Status:** Deferred (raised 2026-09-03 by `flutter analyze`)
**Scope:** 2 call sites
**Risk:** Low mechanically, but it is a **logic change**, not a styling one — it
must not ride along in an aesthetic commit.

### Context
`share_plus` 13.x deprecated the static `Share` facade in favour of a singleton.
4 analyzer infos across 2 call sites:

- `lib/screens/google_sheets_sync_screen.dart:116` — `Share.share(...)`
- `lib/services/export_service.dart:55` — `Share.shareXFiles(...)`

### Proposed change
```dart
Share.share(text)            -> SharePlus.instance.share(ShareParams(text: text))
Share.shareXFiles([file])    -> SharePlus.instance.share(ShareParams(files: [file]))
```
Check the exact `ShareParams` shape against the resolved `share_plus` version in
`pubspec.lock` before writing — the API moved more than once across 12.x/13.x.

### Why it matters beyond the lint
The CSV export path and the Sheets share path are the two places a user gets
data *out* of the app. When the deprecated facade is eventually removed these
break, and the failure is silent-ish: the share sheet simply never opens.

### Acceptance
- `flutter analyze` reports no `share_plus` deprecations
- Manually verified: CSV export opens the share sheet on both iOS and Android
- `flutter test` — all 31 tests green

---

## BL-004 — Collision impulse applies the wrong normal component

**Status:** Open (found 2026-09-03 while porting the physics for a preview)
**Scope:** one character, `lib/providers/bubble_provider.dart`
**Risk of fixing:** low mechanically, but it changes how the canvas *feels*

### The defect
In `updatePhysics`, the pairwise collision response reads:

```dart
_bubbles[j] = b2.copyWith(
  vx: b2.vx + impulse * nx,
  vy: b2.vy + impulse * nx,   // <-- nx, should be ny
);
```

The second bubble's **vertical** velocity receives the **horizontal** component
of the collision normal. The first bubble (`b1`) is correct.

### Consequences
- Momentum is not conserved: energy is injected or removed depending on the
  collision angle.
- Bubbles kick off-axis. A head-on horizontal collision imparts unwanted
  vertical motion; a vertical collision imparts none.
- Most visible with the scatter-and-settle shuffle, where many collisions
  resolve at once.

### Why it is still open
It sits in `BubbleProvider`, which is out of scope for the aesthetic pass. It is
also **not** a silent fix: the canvas has been tuned by eye against the buggy
behaviour, so correcting it will change the feel of every collision. Worth
fixing deliberately, with a look at the result, not as a drive-by.

### Acceptance
- `vy: b2.vy + impulse * ny`
- Canvas re-checked on device: shuffle, drag-fling and idle settling all still
  feel right, or the damping/elasticity constants retuned until they do

---

## BL-005 — Total header compares spend of all categories against budget of some

**Status:** Open (raised by Shab 2026-09-03)
**Scope:** `_buildTopBar` in `lib/main.dart`
**Priority:** raised, because the header now shows by default

### The defect
```dart
if (provider.totalBudget > 0)
  Text('$spend / $budget')
```

`totalSpend` sums **every** category. `totalBudget` sums only the **budgeted**
ones. The moment a user sets a limit on one category out of six, the header
reads "spend across 6 categories / budget across 1" — two different
populations presented as a ratio.

Out of the box this is harmless, since all six seeded categories start at
`budget_limit = 0.0` and the `else` branch shows spend alone. It only misleads
once budgets are partially set, which is the normal end state for most users.

### Proposed rule (Shab's)
Show the budget comparison only when **every** category has a limit. Otherwise
show total spend alone, with no ratio and no progress bar.

```dart
final allBudgeted = provider.bubbles.isNotEmpty &&
    provider.bubbles.every((b) => b.isBudgeted);
```

### Why it is still open
It changes a display conditional in `main.dart` and was explicitly held back
from the presentational batch. One approval away.

---

## BL-006 — Currency picker: row + bottom-sheet panel

**Status:** Designed and agreed 2026-09-04. Not implemented.
**Reference mock:** `lib/dev/proposed_currency_panel.dart` (dev-only, never shipped)
**Scope:** `settings_screen.dart`, plus a decimals map. Feature, not polish.

### The problem
The picker offers six glyphs — `$ € £ ₹ ¥ A$` — in a `DropdownButton`. That
excludes most of the world, and `¥` is ambiguous between JPY and CNY.

### Agreed design
- The Settings row stays a normal `ListTile` showing the current selection
  (`A$  AUD`) with a chevron. **The panel is not expanded inline** — it opens
  only on tap, exactly as the dropdown did.
- Tapping opens a **bottom sheet**, not a dialog. `AlertDialog` insets leave
  roughly 260 px usable on a 390 pt phone, which fits 3 tiles per row and makes
  the panel tall and cramped; a sheet is full width and fits 5.
- Tiles are grouped under three headers — Americas & Europe, Asia-Pacific,
  Middle East & Africa — with each tile showing the **glyph above its ISO
  code**. The code is what disambiguates `¥` JPY from `CN¥` CNY, the four
  Nordic `kr`, and the several `Rs`.
- 32 currencies. This is deliberately a curated set, not all ~180: a full list
  needs a searchable picker and implies conversion the app does not do.

### MUST ship with this, not after
**A decimals map.** JPY, KRW, VND and IDR have no minor unit. The code calls
`toStringAsFixed(2)` at 16 call sites, so selecting any of them yields
`¥240.00`, `₩5000.00`, `Rp15000.00`. Four of the 32 are affected.

This bug is **already live**: `¥` is in the current six-symbol picker.

### Known caveats, verified in the mock
- **Font coverage.** A test render substituted `Rs` for `₨`, and `₹ ₱ ₫ ৳`
  rendered thin. iOS and Android system fonts should cover these, but verify on
  both devices before shipping the set.
- **Wide symbols eat label width.** `CHF`, `Mex$`, `HK$`, `AED` are 3-4 chars.
  `BubblePainter` clamps labels to `radius * 1.8`, so a small bubble showing
  `Mex$240.00 / Mex$300.00` will ellipsize.
- **Arabic glyphs avoided on purpose.** `SR` and `AED` are used rather than
  `﷼` and `د.إ`, which can render with unexpected directionality inside an
  LTR `Text`.

### Open question
The mock keeps the sheet open on selection so several can be compared. A
shipping version probably closes on tap. One-line difference; decide from use.

---

## BL-007 — Sheets export ignores the currency setting entirely

**Status:** Open (found 2026-09-04 while specifying BL-006)
**Scope:** `lib/constants/apps_script_template.dart`, `lib/services/sync_service.dart`

Two independent defects that together mean synced data is always
dollar-formatted regardless of what the user picked:

1. The Apps Script template hard-codes the number format `"$#,##0.00"` in
   **five** places (lines 21, 51, 65, 79, 97). The spreadsheet renders every
   amount with a dollar sign whatever the app is set to.
2. `sync_service.dart:119` sends `'currency': _settings.currencySymbol` — the
   **glyph**, not an ISO code. So even a corrected template could not choose a
   format, because `₹` does not identify a currency unambiguously.

### Why it matters
Google Sheets sync is one of the app's two headline features, and the export is
where a non-AUD user would most notice the app does not respect their setting.

### Proposed
Store and send an ISO 4217 code (`INR`), and have the template set its number
format from it. This overlaps with the model change sketched in BL-006 — worth
doing together rather than twice.
