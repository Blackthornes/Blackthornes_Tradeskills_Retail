-- Core/WhatsNewText.lua
-- Written by tools/make_whatsnew.py from NEWS.md. Never edit it by hand:
-- change NEWS.md and run the tool. UI/WhatsNew.lua shows it.

local _, ns = ...

ns.WHATS_NEW = {
    { version = "1.6.0", lines = {
        "Tradeskills scans the auction house and keeps track of prices, so you know what your crafts and materials are worth.",
        "The Profit tab shows which of your crafts make the most gold after the auction house cut.",
        "Queue your crafts and Tradeskills makes a shopping list of what you still need. The Craft next button makes them one at a time.",
        "At the auction house, the Sell list prices what you made, and the Auctions view shows when someone sells for less than you.",
        "If you use TradeSkillMaster or Auctionator, their prices fill in what you haven't scanned.",
        "With Blackthornes Farmer, both share one window, and the Gather tab sets Farmer goals for the materials you need.",
    } },
}
