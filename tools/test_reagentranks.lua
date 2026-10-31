-- Reagents with quality ranks, and the Warband bank (Retail).
--
-- A Retail reagent slot takes the same herb at rank 1, 2 or 3, each its own
-- item and price. Tradeskills read only the first, so it priced every craft
-- at rank 1 and counted only rank 1 as held. Now a slot keeps every rank,
-- what is held counts them all (a craft can mix them), and buying takes the
-- cheapest. Selling still counts each item alone.
--
-- The Warband bank is the account's: it counts once, beside the bank of the
-- character playing, never in a saved character's bank, and its tabs are
-- never read as that character's own bank (they sit where the old layout
-- guessed bank bags were).
--
-- Drives the real Logic/ReagentRanks.lua, Data/Inventory.lua and
-- Logic/Cost.lua.

local ns = {}
ns.COLORS = setmetatable({}, {__index = function() return "ffffffff" end})
ns.NewModule = function(name) local m = {}; ns[name] = m; return m end
ns.RegisterCommand = function() end
ns.RegisterEvent = function() end
ns.Print, ns.PrintRaw, ns.Debug, ns.Warn = function() end, function() end, function() end, function() end
ns.L = setmetatable({ Format = string.format }, { __index = function(_, key) return key end })

time = time or os.time
local clock = 0
GetTime = function() return clock end
local function Tick() clock = clock + 10 end
GetMoney = function() return 0 end
GetInventoryItemID = function() return nil end
C_Timer = { NewTimer = function(_, fn) return { Cancel = function() end } end }

-- Retail's bag layout: the character's bank tabs 6 to 11, the Warband
-- bank's tabs 12 to 16. Bank bag 1 is no longer named.
Enum = { BagIndex = {
    Backpack = 0, ReagentBag = 5,
    CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, CharacterBankTab_3 = 8,
    CharacterBankTab_4 = 9, CharacterBankTab_5 = 10, CharacterBankTab_6 = 11,
    AccountBankTab_1 = 12, AccountBankTab_2 = 13, AccountBankTab_3 = 14,
    AccountBankTab_4 = 15, AccountBankTab_5 = 16,
} }

local containers = {}
local bankOpen = false
local function IsCharacterBank(bag) return bag >= 6 and bag <= 11 end
local function IsWarband(bag) return bag >= 12 and bag <= 16 end
local function Shut(bag) return (IsCharacterBank(bag) or IsWarband(bag)) and not bankOpen end

C_Container = {
    GetContainerNumSlots = function(bag)
        if Shut(bag) then return 0 end
        return containers[bag] and 16 or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        if Shut(bag) then return nil end
        local entry = containers[bag] and containers[bag][slot]
        if not entry then return nil end
        return { itemID = entry[1], stackCount = entry[2], isLocked = false }
    end,
}

local function CountIn(itemID, predicate)
    local total = 0
    for bag, slots in pairs(containers) do
        if predicate(bag) then
            for _, entry in ipairs(slots) do
                if entry[1] == itemID then total = total + entry[2] end
            end
        end
    end
    return total
end

-- The client counts the bank while it is open, the Warband bank whenever
-- asked to.
C_Item = {
    GetItemCount = function(itemID, includeBank, _, _, includeWarband)
        local total = CountIn(itemID, function(bag) return bag >= 0 and bag <= 5 end)
        if includeBank and bankOpen then total = total + CountIn(itemID, IsCharacterBank) end
        if includeWarband then total = total + CountIn(itemID, IsWarband) end
        return total
    end,
}

ns.Util = {
    HasFunction = function(path)
        return path == "C_Item.GetItemCount" or path == "GetInventoryItemID"
    end,
    GetItemLabel = function(i) return "item" .. tostring(i) end,
}

local SELF, ALT = "Player-SELF", "Player-ALT"
local HERB1, HERB2, HERB3, CLOTH, POTION = 210796, 210797, 210798, 4306, 9000

local settings = { valueOwnedMaterials = true }
ns.Config = {
    Get = function(_, key) return settings[key] end,
    GetCharacterKey = function() return SELF end,
}

local POTION_RECIPE = { recipeID = 1, name = "Potion", outputItemID = POTION,
    quantityMin = 1, quantityMax = 1,
    reagents = { { itemID = HERB1, quantity = 10, ranks = { HERB1, HERB2, HERB3 } },
                 { itemID = CLOTH, quantity = 2 } } }

ns.db = { characters = {
    [SELF] = { name = "Self", recipes = { [1] = POTION_RECIPE }, inventory = {} },
    [ALT] = { name = "Alt", recipes = {}, inventory = { [HERB2] = 4 }, bank = { [HERB1] = 3 } },
} }

ns.Recipes = {
    GetCharacterRecord = function() return ns.db.characters[SELF] end,
    GetAll = function() return ns.db.characters[SELF].recipes end,
    GetAny = function(_, id) return ns.db.characters[SELF].recipes[id], SELF end,
}
ns.Auctions = { GetPostedCount = function() return 0 end }
ns.Profit = { Resolve = function() return nil, "no" end }
ns.Mail = { GetCount = function() return 0 end }

local auction = { [HERB1] = 300, [HERB2] = 250, [HERB3] = 900, [CLOTH] = 100 }
ns.Prices = { GetValue = function(_, id) return auction[id] end }
ns.Vendor = { GetUnitPrice = function() return nil end, IsLimited = function() return false end }

assert(loadfile(lfs_cwd .. "/Logic/ReagentRanks.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Data/Inventory.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/Cost.lua"))("Blackthornes_TS", ns)

local Inventory, Ranks, Cost = ns.Inventory, ns.ReagentRanks, ns.Cost
Inventory:OnEnable()
Cost:InvalidateIndex()

local failures = 0
local function check(label, got, expected)
    local ok = got == expected
    if not ok then failures = failures + 1 end
    print(("  %-62s %-10s %s"):format(label, tostring(got), ok and "ok" or
        ("FAILED, expected " .. tostring(expected))))
end

--------------------------------------------------------------------------------
print("")
print("a slot read from the profession window")

check("a slot with three ranks keeps all three",
    #(Ranks.FromSlot({ reagents = { { itemID = 1 }, { itemID = 2 }, { itemID = 3 } } }) or {}), 3)
check("a slot with one item has no ranks",
    Ranks.FromSlot({ reagents = { { itemID = 1 } } }), nil)
check("the same item twice is one",
    Ranks.FromSlot({ reagents = { { itemID = 1 }, { itemID = 1 } } }), nil)
check("each rank finds the group from the saved recipes", #(Ranks:Of(HERB3) or {}), 3)
check("an item with no ranks finds none", Ranks:Of(CLOTH), nil)

Ranks:Note({ 500, 501 })
check("a new slot joins the lookup", #(Ranks:Of(501) or {}), 2)
Ranks:Note({ 501, 502 })
check("a slot sharing an item grows its group", #(Ranks:Of(500) or {}), 3)

--------------------------------------------------------------------------------
print("")
print("six rank 1 and eight rank 2 herbs in the bags")

containers = {
    [0] = { { HERB1, 6 }, { HERB2, 8 }, { CLOTH, 5 } },
}
Inventory:InvalidateBagCounts()

check("every rank counts for a craft", Inventory:GetBagCount(HERB1, true), 14)
check("from any rank's ID", Inventory:GetBagCount(HERB3, true), 14)
check("selling still counts the item alone", Inventory:GetBagCount(HERB2), 8)
check("an item with no ranks is the same either way", Inventory:GetBagCount(CLOTH, true), 5)
check("an alt's ranks count together", Inventory:GetAltTotal(HERB1, true), 4)

--------------------------------------------------------------------------------
print("")
print("buying takes the cheapest rank")

local unit, source, pick = Cost:GetReagentUnitCost(HERB1)
check("one costs the cheapest rank's price", unit, 250)
check("bought on the auction house", source, "buy")
check("and that rank is the one to buy", pick, HERB2)
check("BuyRank says the same", Cost:BuyRank(HERB3), HERB2)
check("an item with no ranks buys itself", Cost:BuyRank(CLOTH), CLOTH)

auction[HERB2] = nil
check("a rank nobody prices is passed over", Cost:BuyRank(HERB1), HERB1)
auction[HERB2] = 250

local cost = Cost:GetCraftCost(1)
local herbs = cost.reagents[1]
check("the craft prices ten herbs at the cheapest rank", herbs.lineCost, 2500)
check("the line says which rank is bought", herbs.buyItemID, HERB2)
check("and counts every rank held", herbs.have, 14)
check("so none is short", herbs.shortfall, 0)
check("the craft costs the herbs and the cloth", cost.total, 2500 + 200)

--------------------------------------------------------------------------------
print("")
print("the bank and the Warband bank")

containers[0] = {}
containers[6] = { { CLOTH, 20 } }
containers[12] = { { CLOTH, 7 }, { HERB3, 3 } }
bankOpen = true
Inventory:OnBankOpened()
Tick()

local record = ns.db.characters[SELF]
check("the character's bank holds only its own tabs", record.bank[CLOTH], 20)
check("a Warband tab is never read as the character's bank", record.bank[HERB3], nil)
check("the Warband bank is kept for the account", ns.db.warbandBank[CLOTH], 7)
check("with when it was read", type(ns.db.warbandBankAt), "number")
check("the character's own bank alone", Inventory:GetCharacterBankCount(CLOTH), 20)
check("the Warband bank alone", Inventory:GetWarbandCount(CLOTH), 7)
check("the bank counts both, once", Inventory:GetBankCount(CLOTH), 27)
check("and so does what is owned", Inventory:GetOwnedCount(CLOTH), 27)
check("a Warband herb counts for a craft", Inventory:GetOwnedCount(HERB1, true), 3)

bankOpen = false
Inventory:OnBankClosed()
containers[12] = {}
Inventory:InvalidateBagCounts()
check("a shut bank keeps the last Warband read", Inventory:GetWarbandCount(CLOTH), 7)
check("an alt never counts the Warband bank as its own", Inventory:GetAltTotal(CLOTH), 0)

-- A Warband tab changing while the bank is open is read again.
bankOpen = true
Inventory:OnBankOpened()
containers[12] = { { CLOTH, 2 } }
local reread = false
local old = Inventory.ReadBankSoon
Inventory.ReadBankSoon = function() reread = true end
Inventory:OnBagChanged("BAG_UPDATE", 12)
Inventory.ReadBankSoon = old
check("a Warband tab changing reads the bank again", reread, true)
check("a Warband tab is not a bank container", Inventory.IsBankContainer(12), false)
check("it is a Warband container", Inventory.IsWarbandContainer(12), true)
check("a character tab is a bank container", Inventory.IsBankContainer(6), true)

if failures > 0 then error(("%d check(s) failed"):format(failures)) end
print("")
print("all checks passed")
