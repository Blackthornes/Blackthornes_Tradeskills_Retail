-- Retail's Learn next and disenchanting, outside WoW (Retail only).
--
-- Retail ships no Classic recipe book, Learn next spots or disenchant table
-- (the Retail TOC leaves them out), so what must hold:
--   1. A recipe the profession window shows, not learned, keeps when it goes
--      grey; a trainer's window keeps each line's skill and price; a
--      vendor's window keeps the recipe items it sells (Logic/RecipeSources.lua).
--   2. RecipeBook:GetAll lays them over the recipes the windows showed.
--   3. Learn next lists what a trainer or vendor the game showed teaches,
--      with the spot the game saw them at; grey, unknown-source and known
--      recipes are left out, and one a few points out of reach is locked.
--   4. Disenchanting has no built-in chances: an item gives nothing until
--      your own breaks say, results pool by quality and expansion, and any
--      enchanting trade good the game names counts as a material.

local GLOBALS = { "time", "GetTime", "UnitFactionGroup", "GetRealZoneText", "GetLocale",
    "C_Map", "C_Item", "C_TradeSkillUI", "UnitGUID", "UnitName", "GetNumTrainerServices",
    "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceSkillReq",
    "GetTrainerServiceItemLink", "EXPANSION_NAME10", "CreateFrame" }
local saved = {}
for _, key in ipairs(GLOBALS) do saved[key] = _G[key] end

local failures = 0
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(string.format("  FAIL  %-56s got %s, wanted %s", label, tostring(got), tostring(want)))
    else
        print(string.format("  ok    %-56s %s", label, tostring(got)))
    end
end

local ns = {}
ns.COLORS = setmetatable({}, { __index = function() return "ffffffff" end })
ns.NewModule = function(name) local m = {} ns[name] = m return m end
local printed = {}
ns.Print = function(text) printed[#printed + 1] = text end
ns.PrintRaw, ns.Debug, ns.Warn = function() end, function() end, function() end
ns.RegisterCommand = function() end
ns.RegisterEvent = function() end

local now = 1000000
time = function() return now end
GetTime = function() return now end
UnitFactionGroup = function() return "Alliance" end
GetRealZoneText = function() return "Dornogal" end
GetLocale = function() return "enUS" end
CreateFrame = function()
    local frame = {}
    for _, name in ipairs({ "SetScript", "Show", "Hide", "SetPoint", "SetSize" }) do
        frame[name] = function() end
    end
    return frame
end

local HERE, ELSEWHERE = 2339, 2248
C_Map = {
    GetBestMapForUnit = function() return HERE end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.25 end } end,
    GetMapInfo = function(id) return { name = id == HERE and "Dornogal" or "Isle of Dorn" } end,
}

local npc = "Creature-0-1-2-3-90001-0000"
UnitGUID = function() return npc end
UnitName = function() return npc:find("90001") and "Trainer Tam" or "Vendor Vi" end

-- Item classes: 9 a recipe, 7/12 an enchanting trade good, 4 armour.
local RECIPE_ITEM, DUST, NEW_DUST = 7000, 10940, 219946
local itemInfo = {
    [RECIPE_ITEM] = { "Plans: Bronze Bracers", 9, 0 },
    [NEW_DUST] = { "Storm Dust", 7, 12 },
    [3001] = { "Green Boots", 4, 0, 2, 580, "INVTYPE_FEET", 10 },
    [3002] = { "Green Gloves", 4, 0, 2, 585, "INVTYPE_HAND", 10 },
}
C_Item = {
    GetItemInfoInstant = function(id)
        local info = itemInfo[id]
        if not info then return nil end
        return id, nil, nil, nil, nil, info[2], info[3]
    end,
    GetItemInfo = function(id)
        local info = itemInfo[id]
        if not info then return nil end
        -- name, link, quality, ilvl, minLevel, type, subType, stack, equipLoc,
        -- texture, sellPrice, classID, subclassID, bindType, expansionID
        return info[1], nil, info[4] or 1, info[5] or 1, 1, "x", "y", 1, info[6] or "",
            1, 10, info[2], info[3], 2, info[7]
    end,
}

local unlearned = {}
C_TradeSkillUI = {
    GetRecipeInfo = function(id) return unlearned[id] end,
}

ns.Util = {
    FormatMoney = function(c) return tostring(c) .. "c" end,
    HasFunction = function(path)
        return path == "C_Item.GetItemInfo" or path == "C_Item.GetItemInfoInstant"
    end,
    GetItemLabel = function(id) return "item " .. id end,
    Uncolored = function(text) return text end,
    GetTooltipSellPrice = function() return nil end,
    Round = function(v) return v end,
}

ns.Config = {
    Get = function() return nil end,
    GetCharacterKey = function() return "me" end,
}
local prices = { [DUST] = 100, [NEW_DUST] = 300 }
ns.Prices = { GetValue = function(_, id) return prices[id] end }
ns.Vendor = {
    GetUnitPrice = function() return nil end,
    IsLimited = function() return false end,
    GetTable = function() return {} end,
}
ns.Inventory = { GetCharacterBagCount = function() return 0 end, GetBagCount = function() return 0 end,
    GetBankCount = function() return 0 end }
ns.Recipes = {
    GetAny = function() return nil end,
    GetAll = function() return {} end,
    GetAccountWide = function() return { [105] = { outputItemID = 5105, knownBy = { "me" } } } end,
    GetShortCharacterName = function(_, key) return key end,
}

ns.db = {
    -- What a Retail profession window showed: no shipped book behind them.
    seenRecipes = {
        [101] = { name = "Bronze Bracers", outputItemID = 5101, skillLineID = 2872, reagents = { { itemID = 1, quantity = 2 } } },
        [102] = { name = "Iron Helm", outputItemID = 5102, skillLineID = 2872, reagents = { { itemID = 1, quantity = 4 } } },
        [103] = { name = "Old Belt", outputItemID = 5103, skillLineID = 2872, reagents = { { itemID = 1, quantity = 1 } } },
        [104] = { name = "Quest Cloak", outputItemID = 5104, skillLineID = 2872, reagents = { { itemID = 1, quantity = 1 } } },
        [105] = { name = "Known Cap", outputItemID = 5105, skillLineID = 2872, reagents = { { itemID = 1, quantity = 1 } } },
        [106] = { name = "Far Plate", outputItemID = 5106, skillLineID = 2872, reagents = { { itemID = 1, quantity = 1 } } },
    },
}

assert(loadfile(lfs_cwd .. "/Logic/Cost.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/RecipeBook.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/VendorPins.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/RecipeSources.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/Waypoints.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/LearnNext.lua"))("Blackthornes_TS", ns)

ns.LevelUp = {
    GetReturns = function() return nil end,
    Compare = function(a, b) return a.name < b.name end,
}

local Sources, Book, LN, Pins = ns.RecipeSources, ns.RecipeBook, ns.LearnNext, ns.VendorPins
check("no Classic book here", ns.RECIPE_BOOK, nil)

print("\nThe profession window")
unlearned[103] = { learned = false, maxTrivialLevel = 40 }
Book:NoteSeen(103, { name = "Old Belt", outputItemID = 5103, skillLineID = 2872,
    reagents = { { itemID = 1, quantity = 1 } }, learned = false })
check("when it goes grey is kept", Sources:Store().greys[103], 40)

print("\nA trainer's window")
local services = {
    { "Blacksmithing", nil, "header" },
    { "Iron Helm", nil, "unavailable", cost = 2500, skill = 60, link = "|Hitem:5102|h" },
    { "Old Belt", nil, "available", cost = 100, skill = 10 },
    -- A line named apart from the recipe, matched by what it makes.
    { "Bracers of Bronze", nil, "available", cost = 300, skill = 20, link = "|Hitem:5101|h" },
    { "Far Plate", nil, "unavailable", cost = 9000, skill = 70 },
}
GetNumTrainerServices = function() return #services end
GetTrainerServiceInfo = function(i) local s = services[i]; return s[1], s[2], s[3] end
GetTrainerServiceCost = function(i) return services[i].cost or 0, services[i].cost ~= nil end
GetTrainerServiceSkillReq = function(i) return "Khaz Algar Blacksmithing", services[i].skill, true end
GetTrainerServiceItemLink = function(i) return services[i].link end
Pins:LearnTrainer()
check("the trainer's lines are kept", Sources:ReadTrainer(), 4)
check("where the trainer stands is kept", Pins:TrainerStore()[90001] and Pins:TrainerStore()[90001].mapID, HERE)

print("\nA vendor's window")
npc = "Creature-0-1-2-3-90002-0000"
check("a recipe item it sells is kept", Sources:FromVendor({ [RECIPE_ITEM] = { price = 700 },
    [NEW_DUST] = { price = 5 } }), 1)
-- Where the vendor stands (as VendorPins:Learn keeps it), in another zone.
Pins:Store()[90002] = { name = "Vendor Vi", mapID = ELSEWHERE, x = 10, y = 20, side = "", items = {}, at = now }
check("it teaches Bronze Bracers", Sources:Store().vendors[RECIPE_ITEM].t, "bronze bracers")

print("\nLaid over the book")
Book:Invalidate()
check("a trainer's skill", Book:Get(102).skill, 60)
check("a trainer's price", Book:Get(102).trainerCost, 2500)
check("matched by what it makes", Book:Get(101).trainerCost, 300)
check("the recipe item is listed", Book:Get(101).recipeItems and Book:Get(101).recipeItems[1], RECIPE_ITEM)
check("when it goes grey", Book:Get(103).grey, 40)
check("a recipe nobody showed teaching has no skill", Book:Get(104).skill, nil)
local short, lines = Book:LearnFrom(Book:Get(101))
check("Recipes to learn says Trainer first", short, "Trainer")
check("and names the vendor the game showed", lines[2], "Vendor: Vendor Vi, Isle of Dorn")

print("\nLearn next")
local rows = LN:GetRows({ skills = { [2872] = 50 } })
local names = {}
for _, row in ipairs(rows) do names[#names + 1] = row.name end
check("what to learn, the out of reach one last", table.concat(names, ", "), "Bronze Bracers, Iron Helm")
check("grey, known, far off and no-source left out", #rows, 2)
check("one a few points out is locked", rows[2].locked, true)
local place = rows[1].place
check("the trainer comes before the vendor", place.kind, "trainer")
check("at the spot the game saw", place.mapID, HERE)
check("with the zone named", place.zone, "Dornogal")
check("and its price", place.price, 300)

-- Without the trainer, the vendor the game showed.
local bracers = Book:Get(101)
bracers.trainers = nil
local vendor = LN:Place(bracers)
check("else the vendor", vendor and vendor.kind, "vendor")
check("where it stands", vendor and vendor.mapID, ELSEWHERE)
check("selling that recipe item", vendor and vendor.itemID, RECIPE_ITEM)
check("grey once the skill reaches it", LN.Tier(Book:Get(103), 40), "trivial")
check("not before", LN.Tier(Book:Get(103), 39), "unknown")

print("\nDisenchanting")
ns.DisenchantLog = nil
assert(loadfile(lfs_cwd .. "/Logic/Disenchant.lua"))("Blackthornes_TS", ns)
local Disenchant = ns.Disenchant
check("Retail uses your own breaks only", Disenchant.OWN_RESULTS_ONLY, true)
local outcomes, facts = Disenchant:GetOutcomes(3001)
check("nothing until your own breaks say", outcomes and #outcomes, 0)
check("no Enchanting skill named", facts and facts.skill, nil)
check("pooled by quality and expansion", facts and facts.key, "2:any:x10")
check("so no disenchant value yet", Disenchant:GetValue(3001), nil)
check("an enchanting trade good is a material", Disenchant:IsMaterial(NEW_DUST), true)
check("a recipe item is not", Disenchant:IsMaterial(RECIPE_ITEM), false)
EXPANSION_NAME10 = "The War Within"
check("the group in words", Disenchant:DescribeKey("2:any:x10"), "green items, The War Within")

-- Your own breaks: ten of items like it, in the log's own shape.
local log = { bands = { ["2:any:x10"] = { casts = 10, got = { [NEW_DUST] = { times = 10, total = 20, min = 1, max = 3 } } } },
    items = { [3001] = { casts = 10, got = { [NEW_DUST] = { times = 10, total = 20, min = 1, max = 3 } } } } }
ns.DisenchantLog = {
    GetBand = function(_, key) return log.bands[key] end,
    GetItem = function(_, id) return log.items[id] end,
    GetTable = function() return log end,
}
outcomes, facts = Disenchant:GetOutcomes(3002)
check("then items like it take your results", outcomes[1] and outcomes[1].itemID, NEW_DUST)
check("said to be yours", facts.source, "yours")
check("and are priced", Disenchant:GetValue(3002), 600)
local listed = false
for _, material in ipairs(Disenchant:Materials()) do
    if material.itemID == NEW_DUST then listed = true end
end
check("a material your breaks gave joins the list", listed, true)

for _, key in ipairs(GLOBALS) do _G[key] = saved[key] end

print("")
if failures > 0 then error(string.format("%d retail learn check(s) failed", failures)) end
print("  all retail learn checks passed")
print("")
