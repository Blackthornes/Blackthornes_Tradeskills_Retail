-- Retail's auction house takes whole gold and silver for every listing.
--
-- Forever lets stacks (commodities) keep their copper, and only gear has to be
-- whole silver. Retail turns a stack with copper in its price down without a
-- word: the addon said "listing 19x Small Egg at 7g 98s 99c" and then "did not
-- appear in your auctions" (2026-10-31). So on Retail every price is whole
-- silver (Util.WHOLE_SILVER_ONLY), and the listing lengths are 12, 24 and 48
-- hours. Retail only; see docs/retail-differences.md.

local ns = {}
ns.COLORS = setmetatable({}, {__index = function() return "ffffffff" end})
ns.NewModule = function(name) local m = {}; ns[name] = m; return m end
ns.RegisterCommand = function() end
ns.RegisterEvent = function() end
ns.Print, ns.PrintRaw, ns.Debug, ns.Warn = function() end, function() end, function() end, function() end

--------------------------------------------------------------------------------
-- A player with bags
--------------------------------------------------------------------------------

-- bags[bag][slot] = { itemID, stackCount }
local bags = {}
local commodities = {}
local prices = {}

C_Container = {
    GetContainerNumSlots = function(bag) return bags[bag] and #bags[bag] or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local entry = bags[bag] and bags[bag][slot]
        if not entry then return nil end
        return { itemID = entry.itemID, stackCount = entry.stackCount, isLocked = false }
    end,
}

-- MakeLocation only needs something that answers IsValid.
ItemLocation = {
    CreateFromBagAndSlot = function(_, bag, slot)
        return { bag = bag, slot = slot, IsValid = function() return true end }
    end,
}

ns.Util = {
    Clamp = function(v, l, h) return math.max(l, math.min(h, v)) end,
    Count = function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end,
    FormatMoney = function(c) return tostring(c) end,
    FormatAge = function() return "" end,
    GetItemLabel = function(i) return "item" .. tostring(i) end,
    -- Nothing from C_AuctionHouse: the postable count then comes from the bags
    -- and the deposit is unknown, which is the away-from-the-auction-house case
    -- and the one that keeps this test about quantities.
    HasFunction = function() return false end,
}

-- Core/Util.lua builds a worker frame at load time. Nothing here drives it.
CreateFrame = function()
    local frame = {}
    for _, name in ipairs({ "SetScript", "Show", "Hide", "SetPoint", "SetSize" }) do
        frame[name] = function() end
    end
    return frame
end

GetTime = function() return os.clock() end
time = time or os.time

ns.db = {}
ns.Config = {
    Get = function(_, k)
        if k == "undercutCopper" then return 1 end
        if k == "staleAfterSeconds" then return 48 * 3600 end
        if k == "postDuration" then return 2 end
        return nil
    end,
    GetPriceTable = function() return {} end,
}

ns.Scanner = {
    isAuctionHouseOpen = false,
    IsCommodity = function(_, itemID) return commodities[itemID] == true end,
}

ns.Prices = {
    GetValue = function(_, itemID, key)
        local entry = prices[itemID]
        return entry and entry[key] or nil
    end,
}

ns.Inventory = {
    -- The containers the character carries, reagent bag last. Posting walks
    -- whatever this returns rather than keeping a range of its own, which is
    -- how a reagent bag came to be invisible to the sell list.
    GetCarriedBags = function() return { 0, 1, 2, 3, 4, 5 } end,

    GetBagCount = function(_, itemID)
        local total = 0
        for _, slots in pairs(bags) do
            for _, entry in ipairs(slots) do
                if entry.itemID == itemID then total = total + entry.stackCount end
            end
        end
        return total
    end,
}

ns.Recipes = { GetAccountWide = function() return {} end }
ns.Queue = { GetShoppingList = function() return {} end }

-- Nothing here is craftable, so the profit side stays out of the way and the
-- prices are whatever the price table says.
ns.Cost = { FindRecipeForItem = function() return nil end }
ns.Cost.FindAnyRecipeForItem = ns.Cost.FindRecipeForItem

assert(loadfile(lfs_cwd .. "/Core/Util.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/Profit.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/Posting.lua"))("Blackthornes_TS", ns)

local Posting, Profit, Util = ns.Posting, ns.Profit, ns.Util

local failures = 0
local function check(label, got, expected)
    local ok = got == expected
    if not ok then failures = failures + 1 end
    print(("  %-56s %-10s %s"):format(label, tostring(got), ok and "ok" or
        ("FAILED, expected " .. tostring(expected))))
end

local EGG, SWORD = 3685, 2489
commodities[EGG] = true

print("")
print("whole silver on Retail")

check("Retail takes whole silver only", Util.WHOLE_SILVER_ONLY, true)

prices[EGG] = { market = 80000, rival = 79899 }
local price, basis = Profit:ChoosePostPrice(EGG)
check("a stack's undercut loses its copper", price, 79800)
check("and is still an undercut", basis, "undercut")
check("a price Retail takes", Util.IsWholeSilver(price), true)

prices[EGG] = { market = 80000, rival = 79800 }
check("a whole-silver rival is undercut by a silver", (Profit:ChoosePostPrice(EGG)), 79700)

prices[EGG] = { market = 79899 }
check("market value with no rival loses its copper", (Profit:ChoosePostPrice(EGG)), 79800)

prices[EGG] = { market = 40, rival = 30 }
check("under a silver, one silver", (Profit:ChoosePostPrice(EGG)), 100)

prices[SWORD] = { market = 1000, rival = 999 }
check("gear is whole silver as before", Util.IsWholeSilver((Profit:ChoosePostPrice(SWORD))), true)

check("a stack price typed by hand loses its copper", Posting:NormalisePrice(666, true), 600)
check("40s over 6 on a stack is 6s each", Posting:PriceFromTotal(4000, 6, true), 600)
check("gear typed by hand as before", Posting:NormalisePrice(650, false), 600)

print("")
print("listing lengths")

local lengths = {}
for _, option in ipairs(Posting.DURATIONS) do lengths[option.value] = option.text end
check("1 is 12 hours", lengths[1], "12 hours")
check("2 is 24 hours", lengths[2], "24 hours")
check("3 is 48 hours", lengths[3], "48 hours")

print("")
if failures > 0 then
    error(("%d whole-silver check(s) failed"):format(failures), 0)
end
print("PASS -- every Retail listing is whole silver, 12 to 48 hours")
print("")
