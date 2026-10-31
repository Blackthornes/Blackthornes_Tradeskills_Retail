-- Skill by expansion (Retail).
--
-- Each Retail profession has a skill line for every expansion, each with its
-- own skill, and a recipe belongs to one of them. The game names a line's
-- profession by the line above it. Tradeskills knew only the profession
-- lines, so an expansion line was no profession at all (not Enchanting, not
-- anything), and with every profession window shut Retail says 0 of 0 for
-- it, so its skill was lost the moment the window closed.
--
-- Now each line is learned from the window (and from a recipe), kept
-- account wide, and its skill kept per character for when the window is
-- shut. Drives the real Data/Recipes.lua and Logic/SkillUp.lua.

local checks = 0
local function check(label, condition)
    checks = checks + 1
    if not condition then error(("FAILED: %s"):format(label), 2) end
    print(("  ok  %s"):format(label))
end

UnitName = function() return "Bob" end
UnitGUID = function() return "Player-1-A" end
UnitClass = function() return "Mage", "MAGE" end
UnitLevel = function() return 80 end
UnitFactionGroup = function() return "Horde" end
GetRealmName = function() return "Realm" end
time = time or os.time

local KHAZ_ENCHANTING, OUTLAND_ENCHANTING, KHAZ_INSCRIPTION = 2874, 2491, 2878
local windowOpen = true
C_TradeSkillUI = {
    GetAllProfessionTradeSkillLines = function() return { 333 } end,
    GetProfessionInfoBySkillLineID = function(id)
        return { professionName = "Enchanting", skillLevel = 0, maxSkillLevel = 0 }
    end,
    GetChildProfessionInfos = function()
        if not windowOpen then return {} end
        return {
            { professionID = KHAZ_ENCHANTING, parentProfessionID = 333, skillLevel = 64, maxSkillLevel = 100 },
            { professionID = OUTLAND_ENCHANTING, parentProfessionID = 333, skillLevel = 75, maxSkillLevel = 75 },
            { professionID = 7777, parentProfessionID = 333, skillLevel = 0, maxSkillLevel = 0 },
            { professionID = 8888, parentProfessionID = 4242, skillLevel = 5, maxSkillLevel = 10 },
        }
    end,
}

local ns = {}
ns.NewModule = function(name) local m = {}; ns[name] = m; return m end
ns.RegisterCommand = function() end
ns.RegisterEvent = function() end
ns.Warn, ns.Print, ns.PrintRaw, ns.Debug = function() end, function() end, function() end, function() end
ns.COLORS = {}
ns.Util = {
    Count = function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end,
    CopyDeep = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end,
    HasFunction = function(path)
        return path == "C_TradeSkillUI.GetAllProfessionTradeSkillLines"
            or path == "C_TradeSkillUI.GetProfessionInfoBySkillLineID"
    end,
}
ns.Compat = { Get = function() return { tradeskill = { hasAllProfessionLines = true } } end }

assert(loadfile(lfs_cwd .. "/Core/Config.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Data/Recipes.lua"))("Blackthornes_TS", ns)
assert(loadfile(lfs_cwd .. "/Logic/SkillUp.lua"))("Blackthornes_TS", ns)

local SELF = "Player-1-A"
ns.db = { characters = { [SELF] = { name = "Bob", recipes = {} } } }
ns.Config.characterKey = SELF

local Recipes, SkillUp = ns.Recipes, ns.SkillUp

print("\nRetail's two crafts Classic never had")
check("Inscription is a profession", Recipes.EnglishProfessionName({ skillLineID = 773 }) == "Inscription")
check("so is Jewelcrafting", Recipes.EnglishProfessionName({ skillLineID = 755 }) == "Jewelcrafting")

print("\nbefore the window is read")
check("an expansion line is no profession yet", Recipes.SKILL_LINE_PROFESSIONS[KHAZ_ENCHANTING] == nil)

print("\nthe Enchanting window opens")
local read = Recipes:ReadExpansionSkills()
check("three lines with a skill are read", read == 3)
check("Khaz Algar Enchanting is Enchanting", Recipes.IsEnchanting({ skillLineID = KHAZ_ENCHANTING }))
check("so is Outland's", Recipes.SKILL_LINE_PROFESSIONS[OUTLAND_ENCHANTING] == "Enchanting")
check("a line not learned still says what it is", Recipes.SKILL_LINE_PROFESSIONS[7777] == "Enchanting")
check("a line under a profession nobody knows is left alone", Recipes.SKILL_LINE_PROFESSIONS[8888] == nil)
check("the lines are kept for the account", ns.db.expansionSkillLines[KHAZ_ENCHANTING] == 333)
local skill, max = Recipes:SavedLineSkill(KHAZ_ENCHANTING)
check("the skill is kept for the character", skill == 64 and max == 100)
check("a line read as 0 of 0 keeps no skill", Recipes:SavedLineSkill(7777) == nil)

print("\nthe window shuts")
windowOpen = false
check("a shut window changes nothing", Recipes:ReadExpansionSkills() == 0)
SkillUp:ForgetSkillLevels()
check("the skill is still known with the window shut", SkillUp:GetSkillLevel(KHAZ_ENCHANTING) == 64)
check("Outland's too", SkillUp:GetSkillLevel(OUTLAND_ENCHANTING) == 75)

print("\nthe next login")
Recipes.SKILL_LINE_PROFESSIONS[KHAZ_ENCHANTING] = nil
Recipes:LoadExpansionLines()
check("the saved lines are known again", Recipes.SKILL_LINE_PROFESSIONS[KHAZ_ENCHANTING] == "Enchanting")

print("\na recipe names its line and the one above")
check("a line learned from a recipe", Recipes.NoteLineParent(KHAZ_INSCRIPTION, 773))
check("is that profession", Recipes.SKILL_LINE_PROFESSIONS[KHAZ_INSCRIPTION] == "Inscription")
check("a profession line is never its own parent", not Recipes.NoteLineParent(333, 333))
check("Forever's two lines are untouched", Recipes.SKILL_LINE_PROFESSIONS[2940] == "Enchanting")

print(("\nall %d checks passed"):format(checks))
