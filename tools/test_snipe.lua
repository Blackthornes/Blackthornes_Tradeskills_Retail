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

-- 7b. Grey items are never watched, and an average far above the cheapest
--     listing the last scan saw (a book full of silly prices) is not trusted.
C_Item.GetItemQualityByID = function(id) return id == 40 and 0 or 1 end
classes[40] = 7
assert(Snipe:WorthOf(40, "priced") == nil, "a grey item is left out")
assert(Snipe:WorthOf(10, "priced") == 50000, "a white trade good is still watched")
ns.Prices.GetTable = function() return { [10] = { rivalMin = 50 } } end
assert(Snipe:WorthOf(10, "priced") == nil, "an average 1000 times the cheapest is not trusted")
ns.Prices.GetTable = function() return { [10] = { rivalMin = 9000, ignoredLow = 40 } } end
assert(Snipe:WorthOf(10, "priced") == nil, "a lone low listing counts as the cheapest seen")
ns.Prices.GetTable = function() return { [10] = { rivalMin = 20000 } } end
assert(Snipe:WorthOf(10, "priced") == 50000, "an average near the cheapest is trusted")
assert(Snipe.Believable(50000, nil) == true, "no book read, the average stands")
ns.Prices.GetTable = nil

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

-- 9. The bell rings once a find: another search's rows (the player's own,
--    or another addon's) are never taken as ours, and a find already told
--    rings again only when it gets cheaper.
assert(Snipe.IsOurs({ { itemKey = { itemID = 10 } } }, { [10] = 1 }) == true)
assert(Snipe.IsOurs({ { itemKey = { itemID = 10 } }, { itemKey = { itemID = 99 } } }, { [10] = 1 }) == false,
    "a row for an item we did not ask about is someone else's search")
assert(Snipe.IsOurs({}, { [10] = 1 }) == true, "nothing listed is still our answer")
do
    local timers = {}
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    local rows = {}
    local sent = 0
    ns.Util.HasFunction = function() return true end
    C_Item = { GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, 7 end }
    C_AuctionHouse = {
        MakeItemKey = function(id) return { itemID = id } end,
        SearchForItemKeys = function() sent = sent + 1 end,
        GetBrowseResults = function() return rows end,
    }
    ns.AHQueue = { PRIORITY = { scan = 90 }, Request = function(_, req) req.send() end }
    ns.Prices = {
        GetValue = function() return 100000 end,
        GetTable = function() return { [10] = { quantity = 3 } } end,
    }
    ns.Posting = nil
    local rang = 0
    PlaySoundFile = function() rang = rang + 1 end
    settings.snipeCap, settings.snipePct, settings.snipeWatch, settings.snipeSound = 1000000, 70, "priced", true
    Snipe.running = false
    Snipe:Start()
    assert(sent >= 1, "the search went out")
    -- Someone else's search comes in first: ignored, nothing dropped.
    rows = { { itemKey = { itemID = 99 }, minPrice = 5, totalQuantity = 1 } }
    Snipe:OnBrowseResults()
    assert(rang == 0 and #Snipe:Finds() == 0, "another search's rows are not ours")
    -- Ours: a deal, the bell rings once.
    rows = { { itemKey = { itemID = 10 }, minPrice = 400, totalQuantity = 3 } }
    Snipe:OnBrowseResults()
    assert(#Snipe:Finds() == 1 and rang == 1, "a new find rings")
    -- The same find on the next pass: no bell.
    Snipe:Next()
    Snipe:OnBrowseResults()
    assert(#Snipe:Finds() == 1 and rang == 1, "the same find does not ring again")
    -- Cheaper: rings.
    rows = { { itemKey = { itemID = 10 }, minPrice = 300, totalQuantity = 3 } }
    Snipe:Next()
    Snipe:OnBrowseResults()
    assert(rang == 2, "a cheaper price rings")
    Snipe:Stop()
    C_Timer, C_Item, C_AuctionHouse, PlaySoundFile, ns.AHQueue = nil, nil, nil, nil, nil
end

-- 10. The pool looks at what the last scan saw for sale first, then the
--     items worth most, not the oldest item IDs.
do
    local list = Snipe.SortPool({
        { id = 1, worth = 900, listed = false },
        { id = 2, worth = 100, listed = true },
        { id = 3, worth = 500, listed = true },
    })
    assert(list[1].id == 3 and list[2].id == 2 and list[3].id == 1, "listed first, then by worth")
end

print("test_snipe: all passed")
