# Retail differences

Every place this repo (Tradeskills for Retail) differs from Forever
Tradeskills on purpose, and what a catch-up with Forever does when Forever
changes the same code. A developer note: it never ships (`.pkgmeta` ignores
`docs`). Farmer for Retail keeps the same kind of note in its own repo.

**Read this before every catch-up.** For each Forever commit, check its files
against the list below. A file not listed here is the same as Forever's and
takes Forever's change as it is. A file listed here is a clash only where
Forever's change touches the lines named; then follow that entry's rule and
show the owner both versions.

The rules:

- **Keep Retail:** skip Forever's change to these lines.
- **Blend:** bring Forever's idea over on top of Retail's version (the usual
  pick). Retail's lines stay; Forever's fix or feature is added to them.
- **Forever only:** the file stays in the repo, untouched, so merges stay
  clean, but Retail never loads it. Take Forever's changes to it as they are;
  they do nothing on Retail. A new Forever feature that needs one of these
  is a question for the owner.

Baseline: Forever `main` at `a33a264` (2026-10-31), copied with its whole
history as this repo's first `main`. `git diff a33a264 HEAD` on Retail's
`main` shows every line below.

How to catch up: in a plain, read-only clone of Forever, fetch its `main`
into this repo and `git merge` it on a Retail branch (never squash or
rebase the PR), so the shared history keeps later merges clean. Never push
anything to the Forever repo.

**Keep it current:** every Retail-only PR adds or updates its entry here in
the same PR, and every catch-up PR moves the baseline line.

---

## 1. The TOC and what Retail loads

`Blackthornes_TS.toc`, `.pkgmeta`, `tools/test_retail.lua`
(`RETAIL_LEFT_OUT`). PR: the first Retail PR (the copy).

- `## Interface: 120105`, the number the Retail game reports, the same as
  Farmer for Retail (Forever: 16001).
- `## Notes` no longer says "for WoW: Forever".
- `## X-Curse-Project-ID: 1776347`, Retail's own CurseForge project
  ("Blackthornes Tradeskills Retail"). Never Forever's 1710638.
- The folder (`Blackthornes_TS`) and saves (`BlackthornesTSDB`,
  `BlackthornesTSCharDB`) keep Forever's names. Retail has its own game
  folder, so nothing clashes.
- Not listed in the TOC, and in `.pkgmeta`'s ignore list:
  - Merchant's Favor, Waylaid Crates and the favor goal (Forever's own):
    `Data/WaylaidCrates.lua`, `Logic/MerchantsFavor.lua`,
    `UI/FavorsView.lua` (the drawer's Favors view), `UI/DealsFavor.lua`.
  - Craftsman's and sealed writs (Forever's own): `Data/CraftsmansWrits.lua`,
    `Logic/Writs.lua`, `UI/DealsWrits.lua`.
  - The Favors and Writs tab, which holds only those two views since the
    flips were put away: `UI/Tab_Deals.lua`. `Logic/VendorFlips.lua` stays
    loaded, as on Forever.
  - Legacy perks (`Logic/Legacy.lua`), Forever only.
  - Sending data to Blackthornes (`Logic/Contribute.lua`), the same as
    Farmer for Retail. `Contribute.RECIPIENTS` is unchanged; Retail never
    sends because the file never loads, so never add it to the TOC.
  - What Forever added to the game: `Data/ForeverRecipes.lua` and
    `Data/ForeverVendorSpots.lua`.
  - Guide Me, built on the Classic world's flights and boats:
    `Data/Travel.lua`, `Data/TravelZones.lua`, `Logic/Travel.lua`,
    `UI/TravelCard.lua`, `UI/TravelMap.lua`. Farmer for Retail leaves out
    the same files.
- `tools/check_release.py` refuses a tag while the TOC names 1710638
  (tested in `tools/test_check_release.py`).
- `README.md` says it is the Retail copy and names project 1776347.

**Sync rule: Keep Retail.** Never take Forever's `## Interface`, `## Notes`
or `X-Curse-Project-ID` lines. A Forever commit that adds a file to its TOC:
add it to Retail's TOC in the same place, unless it belongs to one of the
left-out features; then leave it out, add it to `.pkgmeta` and
`RETAIL_LEFT_OUT` in `tools/test_retail.lua`, and ask the owner. The
left-out files themselves are **Forever only**.

## 2. Code that runs without the left-out files

So the addon loads, logs in, draws every tab and opens Settings without
them (checked by `tools/test_retail.lua`, which loads every file the TOC
lists in a pretend client and counts every error).

Already guarded on Forever, unchanged here: `Logic/Cost.lua` (`ns.Legacy`),
`Probe/Probe.lua` (`ns.Legacy`), `Logic/WayArrow.lua`, `UI/WayArrow.lua`
and `Logic/LearnNext.lua` (`ns.Travel`, `ns.TravelCard`),
`UI/PostPanel.lua` (the Favors view shows only with `ns.MerchantsFavor`
and `ns.FavorsView`), `UI/ItemTooltip.lua` (`ns.Writs`,
`ns.MerchantsFavor`), `Logic/AccountLink.lua` (`/bts share data` only with
`ns.Contribute`), `Logic/VendorPins.lua` (the Forever spots `or {}`),
`UI/Main.lua` (a tab in `AUCTION_TABS` that is not there is skipped).

Changed here, so a Settings row shows only where its feature loads:

- `UI/Tab_Settings.lua`: the "Guide Me:" row and its `Refresh` line only
  `if ns.Travel`; the "Crate Costs:" tooltip row and its `Refresh` line
  only `if ns.MerchantsFavor`. The About page's data-sending box was
  already only `if ns.Contribute`.

**Sync rule: Blend.** Take Forever's change, and keep each guard. A new
Forever row, command or call into one of the left-out modules gets the same
`if ns.X` guard here.

## 2b. Goblin Gold in Settings (asked 2026-10-31)

A player searching Settings for "goblin" found only the sound row
("Goblin Gold:" under SOUNDS on the General page) and ticked it, and no
bar came up: the bar is "Gold Tracker:" under GOBLIN GOLD on the Look
page. In `UI/Tab_Settings.lua` the sound row is now "Goblin Gold Sound:"
(a new key in every `Locale/*.lua`; the old "Goblin Gold:" lines are
gone), and `AlsoFindBy(goldRow, L["Goblin Gold"])` lets the search find
Gold Tracker by its heading. Forever has the same trap.

**Sync rule: Blend.** Keep the new label and the `AlsoFindBy` line; take
Forever's other changes to these rows.


## 3. Auction prices and listing lengths

`Core/Util.lua`, `Logic/Profit.lua`, `Logic/Posting.lua`,
`Logic/SellOut.lua`, `UI/PostPanel.lua` (a comment), the five locale files
(`L["48 hours"]`), `tools/test_wholesilver.lua`, and one line in each of
`tools/test_altpricing.lua`, `test_crafttime.lua`, `test_derivedprice.lua`,
`test_disenchantrows.lua`, `test_fastlisting.lua`, `test_overcutting.lua`,
`test_ownprice.lua`, `test_profitways.lua`, `test_quantity.lua`,
`test_silverstep.lua`, `test_uncontested.lua`, `test_vendorpile.lua` and
`test_vendorvalue.lua` (`ns.Util.WHOLE_SILVER_ONLY = false`, so they keep
testing Forever's copper rules). `tools/test_sellout.lua` uses Retail's
lengths. PR: "Fix auction posting" (2026-10-31).

- Retail's auction house takes whole gold and silver for every listing,
  stacks (commodities) too, and quietly turns a stack priced with copper
  down: the addon said "listing..." and then "did not appear in your
  auctions". Forever lets stacks keep copper. `Util.WHOLE_SILVER_ONLY =
  true` (Retail only) makes every place that left a commodity's copper
  alone round it to whole silver: `Profit`'s `RoundForSale`, market value,
  the undercut (a 1c undercut becomes the silver below), Undercut by 0c,
  Highest, Overcutting, and `Posting:NormalisePrice` and the last check in
  `Posting:Post`.
- Listing lengths are Retail's 12, 24 and 48 hours (`Posting.DURATIONS`,
  `SellOut.SECONDS`, `SellOut.LABELS`). The values the game takes, 1, 2 and
  3, are the same, so saved `postDuration` picks keep working.

**Sync rule: Blend.** Keep the flag and the `Util.WHOLE_SILVER_ONLY` checks.
A new Forever price path that leaves commodities in copper gets the same
check, and a Forever test that loads `Core/Util.lua` and expects a
commodity's copper gets the `WHOLE_SILVER_ONLY = false` line.

## 4. Still Forever's, for later steps

Not changed in the copy, on purpose (no new player features yet). Each is
its own step in the port plan, on the owner's yes:

- Forever and sister words players read: `NEWS.md`,
  `Core/WhatsNewText.lua` (written from NEWS.md, still Forever's notes),
  `CHANGELOG.md`, and the sister note and About page
  (`Core/SisterNote.lua`, `UI/About.lua`), which still name every sister.
  Farmer for Retail lists only Retail sisters through
  `SisterNote.ON_RETAIL`; bring that over in the words pass and name only
  the addons that ship for Retail.
- Classic data that may not fit Retail: the recipe book
  (`Data/RecipeBook.lua`), Learn next's trainer and vendor spots
  (`Data/LearnSpots.lua`, `Data/VendorSpots.lua`), vendor prices
  (`Data/VendorPrices.lua`), Road to 300 and its Welcome card
  (`Logic/RoadPlan.lua`, `Logic/Welcome.lua`, `UI/RoadView.lua`,
  `UI/Welcome.lua`), Classic disenchant results. They still load.
- Reagent quality ranks, skill by expansion and the Warband bank.
- The release workflow (`.github/workflows/release.yml`) is Forever's. It
  runs only on a `vX.Y.Z` tag, which the owner pushes, and uploads only with
  the `CF_API_KEY` secret. The Discord steps do nothing without their
  secrets, which stay unset for Retail.
