-- Blackthornes Tradeskills -- Logic/RecipeSources.lua
-- Where a recipe is learned on Retail, from what the game shows (Retail
-- only: the Retail TOC loads it, Forever's never does).
--
-- Forever ships Classic's recipe book and Learn next's trainer and vendor
-- spots (Data/RecipeBook.lua, Data/LearnSpots.lua). Retail has twelve
-- expansions of recipes, and none of Classic's spots or skill numbers fit
-- them, so the Retail TOC leaves those out and Learn next learns from the
-- game instead (the port plan, step 7; the owner said go, 2026-10-31):
--
--   * The profession window lists every recipe, learned or not
--     (Recipes:Harvest, RecipeBook:NoteSeen). For one not learned, the game
--     says when it goes grey (`maxTrivialLevel`), kept here in `greys`.
--   * A trainer's window lists what it teaches, each with the skill it
--     needs and its price (GetTrainerServiceInfo, GetTrainerServiceSkillReq,
--     GetTrainerServiceCost, GetTrainerServiceItemLink), kept in `trainers`
--     by the trainer's NPC ID. VendorPins:LearnTrainer already keeps where
--     the trainer stands.
--   * A vendor's window lists the recipe items it sells (Vendor:Scan calls
--     FromVendor), kept in `vendors` by the recipe item; the item's own
--     tooltip says the skill it needs (RecipeBook:LearnSkill), and
--     VendorPins:Learn keeps where the vendor stands.
--
-- RecipeBook:GetAll lays these over the recipes the windows showed
-- (LayOver): the skill, a trainer's price, the recipe items and when it
-- goes grey. LearnNext:Place asks Place for the nearest trainer or vendor
-- the game showed. Matching is by what the window gives: the recipe a
-- trainer's line makes, else its name; a recipe item by the name after its
-- "Plans:" or "Pattern:", as RecipeBook:ForItem does.
--
-- Saved account wide as `recipeSources` (never rename it, nor its fields):
--   trainers[npc ID] = { at, list = { { n = name (lower case), s = skill,
--     c = copper, i = item it makes } } }
--   vendors[recipe item ID] = { t = recipe name (lower case),
--     by = { [npc ID] = { p = copper, at } } }
--   greys[recipe ID] = the skill it goes grey at
-- Game IDs, names and numbers only; nothing about who looked.
--
-- Not yet seen in game.

local _, ns = ...

local RecipeSources = ns.NewModule("RecipeSources")

-- At most this many trainers and recipe items are kept; the oldest seen go
-- first.
RecipeSources.MOST_TRAINERS = 120
RecipeSources.MOST_ITEMS = 1500

-- Moves whenever something kept changes.
RecipeSources.version = 0

-- The game's item class for recipes.
local CLASS_RECIPE = 9

local function Plain(value)
    if type(value) == "string" and value ~= "" then return value .. "" end
    return nil
end

local function Number(value)
    if type(value) == "number" then return value + 0 end
    return nil
end

--- A client call inside a pcall, its first answers or nil.
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

function RecipeSources:Store()
    if not ns.db then return { trainers = {}, vendors = {}, greys = {} } end
    local store = ns.db.recipeSources
    if type(store) ~= "table" then store = {}; ns.db.recipeSources = store end
    if type(store.trainers) ~= "table" then store.trainers = {} end
    if type(store.vendors) ~= "table" then store.vendors = {} end
    if type(store.greys) ~= "table" then store.greys = {} end
    return store
end

local function Changed()
    RecipeSources.version = RecipeSources.version + 1
    if ns.RecipeBook then ns.RecipeBook.merged = nil end
end

local function NpcID()
    local pins = ns.VendorPins
    if not (pins and pins.NpcID) then return nil end
    return pins.NpcID(Read(_G.UnitGUID, "npc"))
end

local function ItemFromLink(link)
    if type(link) ~= "string" then return nil end
    local ok, id = pcall(function() return tonumber(link:match("item:(%d+)")) end)
    return ok and id or nil
end

--- The recipe a recipe item teaches, by its name: "Plans: Copper Chain
--- Belt" teaches Copper Chain Belt. Lower case, or nil.
function RecipeSources.Teaches(itemName)
    if type(itemName) ~= "string" then return nil end
    local taught = itemName:match("^[^:]+:%s*(.+)$")
    return taught and taught:lower() or nil
end

local function Trim(map, most, ageOf)
    local ids = {}
    for id, record in pairs(map) do ids[#ids + 1] = { id, ageOf(record) or 0 } end
    if #ids <= most then return end
    table.sort(ids, function(a, b) return a[2] < b[2] end)
    for index = 1, #ids - most do map[ids[index][1]] = nil end
end

--------------------------------------------------------------------------------
-- What the windows show
--------------------------------------------------------------------------------

--- A recipe a profession window showed and the character has not learned:
--- keep when it goes grey, when the game says. Called by RecipeBook:NoteSeen.
function RecipeSources:NoteUnlearned(recipeID)
    if type(recipeID) ~= "number" then return end
    local trade = rawget(_G, "C_TradeSkillUI")
    local info = trade and Read(trade.GetRecipeInfo, recipeID)
    if type(info) ~= "table" then return end
    local ok, grey = pcall(function() return Number(info.maxTrivialLevel) end)
    grey = ok and grey or nil
    if not grey or grey <= 0 then return end
    local greys = self:Store().greys
    if greys[recipeID] ~= grey then
        greys[recipeID] = grey
        Changed()
    end
end

--- Read the trainer window that is open: every line it teaches, with the
--- skill it needs and its price. Kept for that trainer, replacing the last.
-- @return how many lines were kept, or nil when nothing could be read
function RecipeSources:ReadTrainer()
    local count = Number(Read(_G.GetNumTrainerServices))
    if not count or count <= 0 then return nil end
    local npcID = NpcID()
    if not npcID then return nil end

    local list = {}
    for index = 1, count do
        local name, _, kind = Read(_G.GetTrainerServiceInfo, index)
        name, kind = Plain(name), Plain(kind)
        if name and kind ~= "header" then
            local cost, isProfession = Read(_G.GetTrainerServiceCost, index)
            local _, skill = Read(_G.GetTrainerServiceSkillReq, index)
            skill = Number(skill)
            if isProfession or skill then
                list[#list + 1] = {
                    n = name:lower(),
                    s = skill and skill > 0 and skill or nil,
                    c = Number(cost) or 0,
                    i = ItemFromLink(Plain(Read(_G.GetTrainerServiceItemLink, index))),
                }
            end
        end
    end
    if #list == 0 then return 0 end

    local trainers = self:Store().trainers
    trainers[npcID] = { at = time(), list = list }
    Trim(trainers, self.MOST_TRAINERS, function(record) return type(record) == "table" and record.at end)
    Changed()
    return #list
end

--- From a vendor window (Vendor:Scan): the recipe items it sells for gold.
-- @param items  Vendor.merchantItems: { [itemID] = { price, extendedCost } }
-- @return how many recipe items were kept
function RecipeSources:FromVendor(items)
    if type(items) ~= "table" then return 0 end
    local npcID = NpcID()
    if not npcID then return 0 end
    local item = rawget(_G, "C_Item")
    if type(item) ~= "table" then return 0 end

    local vendors, kept = self:Store().vendors, 0
    for itemID, sold in pairs(items) do
        if type(itemID) == "number" and type(sold) == "table" and not sold.extendedCost then
            local classID = select(6, Read(item.GetItemInfoInstant, itemID))
            if classID == CLASS_RECIPE then
                local taught = RecipeSources.Teaches(Plain(Read(item.GetItemInfo, itemID)))
                local record = vendors[itemID]
                if type(record) ~= "table" then record = { by = {} }; vendors[itemID] = record end
                if type(record.by) ~= "table" then record.by = {} end
                record.t = taught or record.t
                record.by[npcID] = { p = Number(sold.price) or 0, at = time() }
                kept = kept + 1
                -- The skill it needs, from its own tooltip.
                if ns.RecipeBook and ns.RecipeBook.LearnSkill then
                    pcall(ns.RecipeBook.LearnSkill, ns.RecipeBook, itemID)
                end
            end
        end
    end
    if kept > 0 then
        Trim(vendors, self.MOST_ITEMS, function(record)
            local newest = 0
            for _, by in pairs(type(record) == "table" and type(record.by) == "table" and record.by or {}) do
                if type(by) == "table" and (by.at or 0) > newest then newest = by.at end
            end
            return newest
        end)
        Changed()
    end
    return kept
end

--------------------------------------------------------------------------------
-- Laid over the book
--------------------------------------------------------------------------------

--- Lay what the game showed over the merged book (RecipeBook:GetAll): a
--- trainer's skill and price, the recipe items vendors sell, and when an
--- unlearned recipe goes grey. A skill a recipe item's tooltip gave is laid
--- on after this, by RecipeBook:GetAll, and wins.
function RecipeSources:LayOver(merged)
    if type(merged) ~= "table" then return end
    local store = self:Store()

    local byName, byOutput = {}, {}
    for _, record in pairs(merged) do
        if record.name then
            local key = record.name:lower()
            byName[key] = byName[key] or {}
            table.insert(byName[key], record)
        end
        if record.outputItemID then
            byOutput[record.outputItemID] = byOutput[record.outputItemID] or {}
            table.insert(byOutput[record.outputItemID], record)
        end
    end

    -- The one record a line names: by what it makes when only one recipe
    -- makes that, else by name when only one is called that, else the one
    -- of those that also makes it.
    local function Find(name, itemID)
        local made = itemID and byOutput[itemID]
        if made and #made == 1 then return made[1] end
        local named = name and byName[name]
        if named and #named == 1 then return named[1] end
        for _, record in ipairs(named or {}) do
            if itemID and record.outputItemID == itemID then return record end
        end
        return nil
    end

    for npcID, trainer in pairs(store.trainers) do
        if type(trainer) == "table" and type(trainer.list) == "table" then
            for _, line in ipairs(trainer.list) do
                local record = type(line) == "table" and Find(line.n, line.i)
                if record then
                    record.trainers = record.trainers or {}
                    record.trainers[npcID] = line.c or 0
                    if not record.trainerCost or (line.c or 0) < record.trainerCost then
                        record.trainerCost = line.c or 0
                    end
                    if line.s then record.skill = line.s end
                end
            end
        end
    end

    for itemID, vendor in pairs(store.vendors) do
        local record = type(vendor) == "table" and Find(vendor.t, nil)
        if record then
            local items = record.recipeItems or {}
            local listed = false
            for _, id in ipairs(items) do if id == itemID then listed = true end end
            if not listed then
                -- A copy: the shipped book's lists are never changed.
                local copy = {}
                for index, id in ipairs(items) do copy[index] = id end
                copy[#copy + 1] = itemID
                table.sort(copy)
                record.recipeItems = copy
            end
        end
    end

    for recipeID, grey in pairs(store.greys) do
        local record = merged[recipeID]
        if record and type(grey) == "number" then record.grey = record.grey or grey end
    end
end

--------------------------------------------------------------------------------
-- Where to go
--------------------------------------------------------------------------------

local function OnSide(spotSide, side)
    return not side or not spotSide or spotSide == "" or spotSide == side
end

local function PlayerMap()
    local map = rawget(_G, "C_Map")
    return map and Number(Read(map.GetBestMapForUnit, "player")) or nil
end

--- The vendors the game showed selling a recipe item, on the player's
--- side: { { npcID, name, zone, mapID, x, y, price, at } }.
function RecipeSources:VendorsOf(itemID, side)
    local vendor = self:Store().vendors[itemID]
    local pins = ns.VendorPins
    local found = {}
    if not (type(vendor) == "table" and type(vendor.by) == "table" and pins and pins.Store) then return found end
    local spots = pins:Store()
    for npcID, sold in pairs(vendor.by) do
        local spot = spots[npcID]
        if type(spot) == "table" and spot.name and OnSide(spot.side, side) then
            found[#found + 1] = {
                npcID = npcID, name = spot.name, mapID = spot.mapID, x = spot.x, y = spot.y,
                zone = pins.ZoneName and pins.ZoneName({ mapID = spot.mapID }) or nil,
                price = type(sold) == "table" and sold.p or nil, at = type(sold) == "table" and sold.at or 0,
            }
        end
    end
    table.sort(found, function(a, b) return (a.at or 0) > (b.at or 0) end)
    return found
end

--- The trainer or vendor the game showed teaching a recipe, on the
--- player's side: one on the map the character is on first, else the one
--- seen last. A trainer before a vendor.
--
-- @return { kind = "trainer" | "vendor", name, zone, mapID, x, y, price,
--   itemID } or nil
function RecipeSources:Place(record, side)
    if type(record) ~= "table" then return nil end
    local pins = ns.VendorPins
    if not pins then return nil end
    local here = PlayerMap()

    local function Better(best, place)
        if not best then return place end
        local bestHere, placeHere = here and best.mapID == here, here and place.mapID == here
        if placeHere ~= bestHere then return placeHere and place or best end
        return (place.at or 0) > (best.at or 0) and place or best
    end

    local trainer
    local spots = pins.TrainerStore and pins:TrainerStore() or {}
    for npcID, cost in pairs(record.trainers or {}) do
        local spot = spots[npcID]
        if type(spot) == "table" and spot.name and spot.mapID and OnSide(spot.side, side) then
            trainer = Better(trainer, {
                kind = "trainer", name = spot.name, mapID = spot.mapID, x = spot.x, y = spot.y,
                zone = pins.ZoneName and pins.ZoneName({ mapID = spot.mapID }) or nil,
                price = cost, at = spot.at or 0,
            })
        end
    end
    if trainer then return trainer end

    local vendor
    for _, itemID in ipairs(record.recipeItems or {}) do
        for _, found in ipairs(self:VendorsOf(itemID, side)) do
            if found.mapID then
                found.kind, found.itemID = "vendor", itemID
                vendor = Better(vendor, found)
            end
        end
    end
    return vendor
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function RecipeSources:ReadTrainerSoon()
    if self.trainerTimer then return end
    local after = rawget(_G, "C_Timer") and C_Timer.After
    if type(after) ~= "function" then
        self:ReadTrainer()
        return
    end
    -- The list fires a few times while it fills; read it once it settles.
    self.trainerTimer = true
    after(0.3, function()
        self.trainerTimer = nil
        pcall(self.ReadTrainer, self)
    end)
end

function RecipeSources:OnEnable()
    if not ns.RegisterEvent then return end
    ns.RegisterEvent(self, "TRAINER_SHOW", function() RecipeSources:ReadTrainerSoon() end)
    ns.RegisterEvent(self, "TRAINER_UPDATE", function() RecipeSources:ReadTrainerSoon() end)
end
