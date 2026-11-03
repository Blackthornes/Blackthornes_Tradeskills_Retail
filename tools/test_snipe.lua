-- The Snipe tab's logic (2026-11-03).
--
-- What must hold:
--   1. A deal is a price at or under worth times Snipe Below.
--   2. Snipe Below stays between 10 and 95; the cap and watch read the setting.
--   3. Start refuses without a Spending Cap and never starts by itself.
--   4. A buy that reaches the cap stops the session and clears the finds.
--   5. The auction house closing stops a session.
--   6. The wheel (BuyNext) does nothing when not running.
--   7. Retail: Priced Items leaves gear out; trade goods stay in.
--   8. Retail: a listing whose stack status is not known yet goes to the
--      game's own search, never a stack purchase.

local ns = {}
ns.NewModule = function(name) local m = {}; ns[name] = m; return m end
ns.Util = {}
ns.Print = function() end
local said = {}
ns.Notice = { Show = function(_, text) said[#said + 1] = text end }
local handlers = {}
ns.RegisterEvent = function(_, event, fn) handlers[event] = fn; return true end
local settings = {}
ns.Config = { Get = function(_, k) return settings[k] end }

assert(loadfile(lfs_cwd .. "/Logic/Snipe.lua"))("Blackthornes_TS", ns)
local Snipe = ns.Snipe
Snipe:Init()

-- 1. Deals.
assert(Snipe.IsDeal(70, 100, 70) == true, "at the line is a deal")
assert(Snipe.IsDeal(71, 100, 70) == false, "over the line is not")
assert(Snipe.IsDeal(10, 0, 70) == false, "no worth, no deal")
assert(Snipe.Deal(50, 100) == 50, "half price is 50 under")

-- 2. Settings.
assert(Snipe:Percent() == 70, "default 70")
settings.snipePct = 3
assert(Snipe:Percent() == 10, "floor 10")
settings.snipePct = 200
assert(Snipe:Percent() == 95, "ceiling 95")
settings.snipeCap = 5000
assert(Snipe:Cap() == 5000)
assert(Snipe:Watch() == "priced")
settings.snipeWatch = "disenchant"
assert(Snipe:Watch() == "disenchant")
assert(Snipe:Enabled() == false)
settings.snipeTab = true
assert(Snipe:Enabled() == true)

-- 3. No cap, no start.
settings.snipeCap = 0
Snipe:Start()
assert(not Snipe:IsRunning(), "refuses without a cap")
assert(said[#said] == "Set a Spending Cap first.", "says why")

-- 6. Wheel does nothing when stopped.
Snipe:BuyNext()
assert(not Snipe:IsRunning())

-- 4. Cap reached.
settings.snipeCap = 1000
Snipe.running, Snipe.spent = true, 0
Snipe.finds = { { itemID = 1 }, { itemID = 2 } }
Snipe.pending = { itemID = 1, count = 1, total = 1000, phase = "buying" }
Snipe:Bought()
assert(Snipe:Spent() == 1000, "spent counts")
assert(not Snipe:IsRunning(), "cap stops the session")
assert(#Snipe:Finds() == 0, "finds cleared")
assert(said[#said] == "You've reached your Spending Cap. Snipe stopped.")

-- 5. Auction house closing.
Snipe.running = true
handlers.AUCTION_HOUSE_CLOSED()
assert(not Snipe:IsRunning(), "closing the auction house stops")

-- 7. Priced Items skips gear on Retail.
local classes = { [10] = 7, [20] = 4, [30] = 2 }
C_Item = { GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, classes[id] end }
ns.Prices = { GetValue = function() return 50000 end }
assert(Snipe:WorthOf(10, "priced") == 50000, "a trade good is watched")
assert(Snipe:WorthOf(20, "priced") == nil, "armour is left out")
assert(Snipe:WorthOf(30, "priced") == nil, "a weapon is left out")

-- 8. Not known yet goes to the game's search.
local searched, started = nil, false
ns.UI = { SearchAuctionHouse = function(_, id) searched = id end }
ns.Util.HasFunction = function(name) return true end
local status = 0
C_AuctionHouse = {
    GetItemCommodityStatus = function() return status end,
    StartCommoditiesPurchase = function() started = true end,
}
settings.snipeCap = 1000000
Snipe.running, Snipe.spent, Snipe.pending = true, 0, nil
Snipe:Buy({ itemID = 10, price = 100, qty = 5, worth = 1000, kind = "priced" })
assert(searched == 10 and not started, "unknown status opens the game's search")
searched = nil
status = 2
Snipe:Buy({ itemID = 10, price = 100, qty = 5, worth = 1000, kind = "priced" })
assert(started and searched == nil, "a commodity starts a stack purchase")
C_Item, C_AuctionHouse = nil, nil
Snipe.running, Snipe.pending = false, nil

-- The Watch box's options carry `text`, the words Widgets.CreateDropdown
-- shows; written as `label` the box and its menu opened empty.
do
    local file = assert(io.open(lfs_cwd .. "/UI/SnipeView.lua", "r"))
    local source = file:read("*a")
    file:close()
    assert(source:find('value = "priced", text = L%["Priced Items"%]'), "Watch shows Priced Items")
    assert(source:find('value = "disenchant", text = L%["To Disenchant"%]'), "Watch shows To Disenchant")
    assert(not source:find('value = "%w+", label = L%['), "dropdown options use text, not label")
end

print("test_snipe: all passed")
