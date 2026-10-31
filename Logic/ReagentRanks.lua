-- Blackthornes Tradeskills -- Logic/ReagentRanks.lua
-- Reagents that come in quality ranks (Retail).
--
-- Since Dragonflight a reagent slot can take any of two or three items: the
-- same herb, ore or cloth at rank 1, 2 or 3, each its own item with its own
-- price. The profession window lists them all in the slot. Tradeskills took
-- only the first, so it priced the craft off rank 1 alone and counted only
-- rank 1 in the bags: twenty rank 2 herbs read as none, and the queue asked
-- for twenty more.
--
-- So a slot keeps every item it takes (`reagent.ranks`, saved on the recipe
-- beside `itemID`, which stays the first so old readers work as before), and
-- this keeps one lookup from any of those items to its group. A craft can
-- mix ranks in a slot, so what is held counts every rank, and buying takes
-- the cheapest (Cost:GetReagentUnitCost). Nothing new is saved: the groups
-- are laid out from the saved recipes the first time one is asked for, and
-- grown as the profession window is read.
--
-- Farmer for Retail keeps ranks the same way, by name, for its goals and
-- prices (its docs/retail-differences.md, section 17).

local _, ns = ...

local ReagentRanks = ns.NewModule("ReagentRanks")

-- [itemID] = { itemID, itemID, ... }, one shared list per group.
local groups

--- Every item a reagent slot takes, in the slot's order, or nil when it
--- takes one item only. Only plain numbers, read inside the caller's pcall.
function ReagentRanks.FromSlot(slot)
    if type(slot) ~= "table" or type(slot.reagents) ~= "table" then return nil end

    local ids, seen = {}, {}
    for _, reagent in ipairs(slot.reagents) do
        local id = type(reagent) == "table" and reagent.itemID
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    if #ids < 2 then return nil end
    return ids
end

--- Put one group in the lookup. Two slots naming the same items (every
--- recipe that takes that herb) share the one list.
local function Add(ranks)
    if type(ranks) ~= "table" or #ranks < 2 then return end

    local list
    for _, id in ipairs(ranks) do
        if groups[id] then list = groups[id] break end
    end
    list = list or {}

    local inList = {}
    for _, id in ipairs(list) do inList[id] = true end
    for _, id in ipairs(ranks) do
        if type(id) == "number" and not inList[id] then
            inList[id] = true
            list[#list + 1] = id
        end
    end

    for _, id in ipairs(list) do groups[id] = list end
end

local function AddRecipes(recipes)
    for _, recipe in pairs(type(recipes) == "table" and recipes or {}) do
        for _, reagent in ipairs(type(recipe) == "table" and recipe.reagents or {}) do
            if type(reagent) == "table" then Add(reagent.ranks) end
        end
    end
end

--- Lay the groups out from every saved recipe, once.
function ReagentRanks:Build()
    groups = {}
    local db = ns.db
    if type(db) ~= "table" then return end

    for _, record in pairs(type(db.characters) == "table" and db.characters or {}) do
        if type(record) == "table" then AddRecipes(record.recipes) end
    end
    AddRecipes(db.seenRecipes)
end

--- A slot read from the profession window: its group joins the lookup.
function ReagentRanks:Note(ranks)
    if not groups then self:Build() end
    Add(ranks)
end

--- Every rank of an item, the item itself among them, or nil when it has
--- no other rank. The list is shared: never change it.
function ReagentRanks:Of(itemID)
    if type(itemID) ~= "number" then return nil end
    if not groups then self:Build() end
    return groups[itemID]
end

--- How many of every rank `count(id)` gives, added up; the item alone when
--- it has no other rank.
function ReagentRanks:Sum(itemID, count)
    local ranks = self:Of(itemID)
    if not ranks then return count(itemID) or 0 end
    local total = 0
    for _, id in ipairs(ranks) do total = total + (count(id) or 0) end
    return total
end

--- Forget the lookup, for the tests and a new save.
function ReagentRanks:Forget()
    groups = nil
end
