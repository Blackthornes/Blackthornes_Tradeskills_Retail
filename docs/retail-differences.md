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


## 3. Auction prices, listing lengths and far-under prices

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

- A price far under the usual one (under the fifth-of-market guard, but
  not under what a vendor pays) asks instead of refusing (the owner,
  2026-10-31, after Peacebloom sat on Ready to sell with no reason given).
  `Posting:GetPriceFloor` returns which floor it is as a third value;
  `Posting:FarUnderUsual` and `AskFarUnder` put up the usual List It / Skip
  box with "This is far under what it usually sells for.", and Yes lists it
  as a typed price is (the guard stood aside). `Request` asks at its three
  `RefusesEarly` points, box or no box. The Sell row says "Far under its
  usual price" and its List button's hover says it asks first
  (`UI/PostPanel.lua`). List Next still passes such a row over. Three new
  lines in each locale file; tested in `tools/test_farunder.lua`.

**Sync rule: Blend.** Keep the flag and the `Util.WHOLE_SILVER_ONLY` checks.
A new Forever price path that leaves commodities in copper gets the same
check, and a Forever test that loads `Core/Util.lua` and expects a
commodity's copper gets the `WHOLE_SILVER_ONLY = false` line.

## 3b. No Forever or sister-addon words on Retail (the words pass)

Retail players never read about Forever, Classic, last names or the sister
addons that have no Retail version yet (the owner approved the words,
2026-10-31; the same approach as Farmer for Retail's section 13).

- `Core/SisterNote.lua`: Farmer for Retail's copy, with `Note.ON_RETAIL =
  { Blackthornes_Farmer = true, Blackthornes_TS = true }` and
  `Note:Listed()`, so the login chat line and the About page name only the
  Retail addons. Add a folder when a sister ships for Retail.
  `tools/test_sisternote.lua` is Farmer for Retail's plus a Tradeskills check.
- `UI/About.lua`: Farmer for Retail's copy (the list reads `Sisters:Listed()`),
  its third `THANKS` paragraph "Tradeskills is new on Retail...".
- `UI/RecipeBookView.lua` (Recipes to learn's note) and
  `UI/Tab_Disenchanting.lua` (the chances note) no longer name Classic.
- `UI/Tab_Settings.lua`: the Keep What Other Addons Need hover names only
  Farmer goals; Your Other Account no longer asks for a last name;
  "Upgrade Arrows:" and "Keep Upgrades for Alts:" show only while
  Blackthornes Equipment is loaded (`HasEquipment`), their `Refresh` lines
  guarded.
- `UI/QueueMailPanel.lua`: `QueueMailPanel.ASKS_LAST_NAME = false`, so the
  mailbox never asks for a last name (Retail has none; the record never has
  `surname`, so it asked on every mail).
- The same keys in every `Locale/*.lua`.
- `NEWS.md` starts fresh: only Retail sections (Forever's are in git
  history), so `Core/WhatsNewText.lua` holds no Forever lines. `CHANGELOG.md`
  keeps Forever's history under Retail's sections, as Farmer for Retail does.
  The first Retail version is 1.6.0 (`ns.RELEASED_VERSION`).

**Sync rule: Blend.** Take Forever's changes to these files and keep these
lines. A new Forever string that names Forever, Classic, last names or a
sister addon gets Retail words, shown to the owner first. In a catch-up,
`NEWS.md`, `CHANGELOG.md`, `Core/WhatsNewText.lua` and `RELEASED_VERSION`
keep Retail's: never take Forever's sections or version.

## 3c. Reagent quality ranks, skill by expansion, the Warband bank

Step 2 of the port plan (the owner said go, 2026-10-31). No new words for
players.

- **Quality ranks.** A Retail reagent slot takes the same herb at rank 1,
  2 or 3, each its own item. `Data/Recipes.lua` (Harvest) keeps every item
  of a slot in `reagent.ranks` beside `itemID` (still the first, so old
  readers work; never rename `ranks`), and `Logic/RecipeBook.lua`
  (`NoteSeen`) keeps them too. `Logic/ReagentRanks.lua` (Retail's own file,
  in the TOC before `Logic/Cost.lua`) lays out a lookup from any rank to its
  group from the saved recipes; nothing new is saved.
  - Counting: `Data/Inventory.lua`'s `GetBagCount`, `GetBankCount`,
    `GetMailCount`, `GetTotalCount`, `GetOwnedCount`,
    `GetCharacterBagCount`, `GetAltCounts` and `GetAltTotal` take a second
    argument `anyRank`; given, every rank counts. Left out, the item alone
    (selling, posting). The reagent readers pass it: `Logic/Cost.lua`
    (`GetCraftCost`, `GetShortfall`), `Logic/Queue.lua` (`HeldBy`,
    `InMailFor` and `BoughtBeyondMail` over every rank, sub-craft sizing,
    the cash view, the shopping list), `Logic/Profit.lua`
    (`GetCraftableCount`).
  - Buying: `Cost:GetReagentUnitCost` prices a reagent at its cheapest
    rank and returns that rank third (`Cost:BuyRank`); the old body is
    `Cost:OneRankUnitCost`. A craft line carries `buyItemID`; the queue's
    `BuyMore` buys it. A shopping list row is the cheapest rank's
    (`itemID`), with `listedItemID` for the rank the recipe lists first
    (its buys and alt offers; the Queue tab's x removes by it).
    `Cost:FindRecipeForItem` finds a recipe that makes any rank.
  - Holding back: `Queue:GetReservedItems` holds every rank; the mail batch
    (`QueueMail:GetMailBatch`) takes any rank.
- **Skill by expansion.** Each profession has a skill line per expansion.
  `Data/Recipes.lua`: Inscription (773) and Jewelcrafting (755) join
  `SKILL_LINE_PROFESSIONS`; `Recipes.NoteLineParent` learns an expansion
  line's profession from a recipe (`GetTradeSkillLineForRecipe`'s third
  answer) or the window (`Recipes:ReadExpansionSkills`,
  `GetChildProfessionInfos`, from `OnTradeSkillUpdate`) and adds it to
  `SKILL_LINE_PROFESSIONS`; kept account wide in
  `expansionSkillLines[line] = profession line` and laid in at login
  (`LoadExpansionLines`). Each line's skill is kept per character in
  `expansionSkills[line] = { skill, max, at }` (never rename either),
  since a shut window says 0 of 0. `SkillUp:GetSkillLevel` and the Level
  Up tab's `ProfessionInfo` fall back to it (`Recipes:SavedLineSkill`).
  The Profit and Level Up pickers already list recipes by their line, so
  each expansion is its own entry there, named by the game.
- **Warband bank.** `Data/Inventory.lua` reads the bank by the client's
  named tabs: the character's (`CharacterBankTab_1` to 6) for its own
  bank, the Warband bank's (`AccountBankTab_1` to 5) apart, kept account
  wide in `warbandBank` and `warbandBankAt` (never rename them;
  `SnapshotWarband`, `GetWarbandCount`, `IsWarbandContainer`). Before, the
  old guessed range (6 to 12) took Warband tab 1 for the character's bank.
  `GetBankCount` is the character's bank (`GetCharacterBankCount`) plus the
  Warband bank, for the character playing only; a saved character's bank
  never holds it, so the account's stock is counted once.
- Tested in `tools/test_reagentranks.lua` and `tools/test_expansionlines.lua`.
- Not yet: the queue saying "put it in your Warband bank" instead of a
  mail, mailing mixed ranks to an alt (mail still takes the listed rank),
  a Warband row in the Bank view, crafting from the Warband bank in "can
  craft now". Each needs new words, so it waits on the owner. Nothing here
  has been seen in game.

**Sync rule: Keep Retail** for these lines; Blend Forever's changes around
them. A Forever reader that counts a reagent passes `anyRank`; one that
buys one uses `Cost:BuyRank`.

## 4. Still Forever's, for later steps

Not changed in the copy, on purpose (no new player features yet). Each is
its own step in the port plan, on the owner's yes:

- Classic data that may not fit Retail: the recipe book
  (`Data/RecipeBook.lua`), Learn next's trainer and vendor spots
  (`Data/LearnSpots.lua`, `Data/VendorSpots.lua`), vendor prices
  (`Data/VendorPrices.lua`), Road to 300 and its Welcome card
  (`Logic/RoadPlan.lua`, `Logic/Welcome.lua`, `UI/RoadView.lua`,
  `UI/Welcome.lua`), Classic disenchant results. They still load.
- The release workflow (`.github/workflows/release.yml`) is Forever's. It
  runs only on a `vX.Y.Z` tag, which the owner pushes, and uploads only with
  the `CF_API_KEY` secret. The Discord steps do nothing without their
  secrets, which stay unset for Retail.
