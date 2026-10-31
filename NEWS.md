# News

What each release says in the Discord server's #general channel: a few
short bullets per version, in plain words for players, saying what they'll
notice, then one line thanking, by their Discord name, everyone whose
feedback or report led to the changes (each name once; no line when nobody
asked). Each release PR writes the new version's section here next to its
CHANGELOG.md section, and after the upload `tools/post_general.py` posts it
under a line with the addon's name and version that points players to
#announcements for the full list. No link or addon card goes with it. This
is the only report that names players. A version with no section here posts
nothing in #general.
This file does not ship in the addon, but its newest sections do, without
the thanks line: `python tools/make_whatsnew.py` writes them into
Core/WhatsNewText.lua for the in-game What's New window. Run it after
writing a section; the release check refuses a tag while it is behind.

The window shows new features only. Write a section's features first, then
a "Fixes and changes:" line with the fixes and other changes under it: those
go to Discord but stay out of the window, and a section of only fixes puts
nothing in it. Say what each feature does in a few plain words, the way you'd
tell a friend: no hype, no questions to the reader, no exclamation marks
outside the thanks line, no dashes as punctuation, no "now you can". The
tool prints a note for a shipped line that reads like an advert.

## 1.6.0

- Tradeskills scans the auction house and keeps track of prices, so you know what your crafts and materials are worth.
- The Profit tab shows which of your crafts make the most gold after the auction house cut.
- Queue your crafts and Tradeskills makes a shopping list of what you still need. The Craft next button makes them one at a time.
- At the auction house, the Sell list prices what you made, and the Auctions view shows when someone sells for less than you.
- If you use TradeSkillMaster or Auctionator, their prices fill in what you haven't scanned.
- With Blackthornes Farmer, both share one window, and the Gather tab sets Farmer goals for the materials you need.
