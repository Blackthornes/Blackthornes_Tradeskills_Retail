-- The Retail copy.
--
-- This repo is Tradeskills for Retail WoW, copied from the Forever addon
-- with its history. Forever-only features (Merchant's Favor and its crates,
-- Craftsman's Writs, Legacy perks, sending data to Blackthornes, the
-- recipes and vendor spots Forever added) and Guide Me's Classic routes do
-- not fit Retail, so the TOC leaves them out, and the TOC must never point a
-- tag at the Forever project on CurseForge. Then the addon has to load, log
-- in, open its window on every tab and open Settings with none of them.
--
-- No test here loads the whole addon, so this one brings its own client:
-- every file the TOC lists runs in a private table of globals (so nothing
-- leaks into the other suites), any game call it does not know answers nil,
-- and every error a file, an event, a timer or a window raises is counted.

local ROOT = lfs_cwd or "."

-- Kept in the repo so Forever changes merge cleanly, never loaded here.
-- docs/retail-differences.md lists them with the reason for each.
local RETAIL_LEFT_OUT = {
    ["Data/ForeverVendorSpots.lua"] = true,
    ["Data/ForeverRecipes.lua"] = true,
    ["Data/WaylaidCrates.lua"] = true,
    ["Data/CraftsmansWrits.lua"] = true,
    ["Data/Travel.lua"] = true,
    ["Data/TravelZones.lua"] = true,
    ["Logic/Legacy.lua"] = true,
    ["Logic/Travel.lua"] = true,
    ["Logic/MerchantsFavor.lua"] = true,
    ["Logic/Writs.lua"] = true,
    ["Logic/Contribute.lua"] = true,
    ["UI/FavorsView.lua"] = true,
    ["UI/TravelCard.lua"] = true,
    ["UI/TravelMap.lua"] = true,
    ["UI/DealsFavor.lua"] = true,
    ["UI/DealsWrits.lua"] = true,
    ["UI/Tab_Deals.lua"] = true,
    -- Classic data and Road to 300 (Learn next learns from the game here).
    ["Data/VendorPrices.lua"] = true,
    ["Data/VendorSpots.lua"] = true,
    ["Data/RecipeBook.lua"] = true,
    ["Data/LearnSpots.lua"] = true,
    ["Logic/RoadPlan.lua"] = true,
    ["Logic/Welcome.lua"] = true,
    ["UI/RoadView.lua"] = true,
    ["UI/Welcome.lua"] = true,
}

local passed, failed = 0, 0
local function check(label, ok, detail)
    if ok then
        passed = passed + 1
        print(("  ok    %s"):format(label))
    else
        failed = failed + 1
        print(("  FAIL  %s%s"):format(label, detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end

--------------------------------------------------------------------------------
print("")
print("the TOC")

local handle = assert(io.open(ROOT .. "/Blackthornes_TS.toc", "r"))
local toc = handle:read("*a")
handle:close()

check("the TOC is not Forever's", not toc:find("## Interface: 16001", 1, true))
check("the TOC names a Retail interface", toc:find("\n?## Interface: 12%d%d%d%d") ~= nil)
check("the TOC never names Forever's CurseForge project",
    not toc:find("^## X%-Curse%-Project%-ID:%s*1710638") and not toc:find("\n## X%-Curse%-Project%-ID:%s*1710638"))
check("the TOC names Retail's CurseForge project", toc:find("\n## X%-Curse%-Project%-ID:%s*1776347") ~= nil)
check("the save keeps its name", toc:find("\n## SavedVariables: BlackthornesTSDB") ~= nil)

local files = {}
for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua%s*$") and not line:match("^#") then
        files[#files + 1] = line:gsub("%s+$", ""):gsub("\\", "/")
    end
end

for file in pairs(RETAIL_LEFT_OUT) do
    local listed = false
    for _, name in ipairs(files) do if name == file then listed = true end end
    check("the TOC leaves out " .. file, not listed)
    local kept = io.open(ROOT .. "/" .. file, "r")
    check(file .. " stays in the repo for merges", kept ~= nil)
    if kept then kept:close() end
end

local pkg = assert(io.open(ROOT .. "/.pkgmeta", "r"))
local pkgmeta = pkg:read("*a")
pkg:close()
for file in pairs(RETAIL_LEFT_OUT) do
    check(".pkgmeta leaves out " .. file, pkgmeta:find("\n%s*%-%s*" .. file:gsub("%p", "%%%0") .. "%s*\n") ~= nil)
end

--------------------------------------------------------------------------------
-- The pretend client
--------------------------------------------------------------------------------

local errors = {}
local function Record(where, err)
    errors[#errors + 1] = where .. ": " .. tostring(err)
end

-- Any game call or constant the client below does not know: indexing it
-- gives another, calling it answers nil, and words and sums treat it as
-- empty. So a check like `if C_Foo and C_Foo.Bar then` goes on, and a call
-- gets the nil a client without it would give.
local Unknown = {}
setmetatable(Unknown, {
    __index = function() return Unknown end,
    __newindex = function() end,
    __call = function() return nil end,
    __concat = function(a, b)
        return (a == Unknown and "" or tostring(a)) .. (b == Unknown and "" or tostring(b))
    end,
    __tostring = function() return "" end,
    __add = function() return 0 end, __sub = function() return 0 end,
    __mul = function() return 0 end, __div = function() return 0 end,
    __unm = function() return 0 end, __len = function() return 0 end,
})

local framesFor = {}   -- event -> frames registered for it
local frameMethods = {}
local NUMBERS = {
    GetWidth = 100, GetHeight = 20, GetScale = 1, GetEffectiveScale = 1, GetAlpha = 1,
    GetLeft = 0, GetRight = 100, GetTop = 100, GetBottom = 0, GetFrameLevel = 1,
    GetStringHeight = 12, GetNumPoints = 1, GetValue = 0, GetVerticalScroll = 0,
    GetVerticalScrollRange = 0, GetHorizontalScroll = 0, GetHorizontalScrollRange = 0,
    GetNumLines = 0, GetDuration = 0, GetProgress = 0, GetID = 0, GetLineHeight = 12,
    GetNumLetters = 0, GetCursorPosition = 0, GetMaxLetters = 0, GetElapsed = 0,
    GetStartDelay = 0, GetEndDelay = 0, GetOrder = 1, GetLoopState = 0, GetFontObject = nil,
    GetSpacing = 0, GetNumRegions = 0, GetNumChildren = 0, GetUnboundedStringWidth = 0,
}
for name, value in pairs(NUMBERS) do
    frameMethods[name] = function() return value end
end

local function NewFrame(kind, name, parent)
    local frame = { _kind = kind or "Frame", _name = name, _parent = parent, _scripts = {},
        _shown = true, _text = "", _events = {} }
    return setmetatable(frame, frameMethods.meta)
end

function frameMethods:GetObjectType() return self._kind end
function frameMethods:IsObjectType(kind) return self._kind == kind end
function frameMethods:GetName() return self._name end
function frameMethods:GetParent() return self._parent end
function frameMethods:SetParent(parent) self._parent = parent end
function frameMethods:Show() self._shown = true end
function frameMethods:Hide() self._shown = false end
function frameMethods:SetShown(on) self._shown = on and true or false end
function frameMethods:IsShown() return self._shown end
function frameMethods:IsVisible() return self._shown end
function frameMethods:SetText(text) self._text = text ~= nil and tostring(text) or "" end
function frameMethods:SetFormattedText(fmt, ...) self._text = fmt:format(...) end
function frameMethods:GetText() return self._text end
function frameMethods:GetStringWidth() return #(self._text or "") * 6 end
function frameMethods:GetSize() return 100, 20 end
function frameMethods:GetCenter() return 500, 400 end
function frameMethods:GetRect() return 0, 0, 100, 20 end
function frameMethods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function frameMethods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function frameMethods:GetTextColor() return 1, 1, 1, 1 end
function frameMethods:GetVertexColor() return 1, 1, 1, 1 end
function frameMethods:GetBackdropColor() return 0, 0, 0, 1 end
function frameMethods:GetBackdropBorderColor() return 0, 0, 0, 1 end
function frameMethods:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
function frameMethods:GetMinMaxValues() return 0, 1 end
function frameMethods:GetHitRectInsets() return 0, 0, 0, 0 end
function frameMethods:GetFrameStrata() return "MEDIUM" end
function frameMethods:GetChecked() return self._checked or false end
function frameMethods:SetChecked(on) self._checked = on and true or false end
function frameMethods:IsMouseOver() return false end
function frameMethods:IsMouseEnabled() return false end
function frameMethods:IsEnabled() return true end
function frameMethods:IsPlaying() return false end
function frameMethods:IsProtected() return false end
function frameMethods:IsForbidden() return false end
function frameMethods:IsOwned() return false end
function frameMethods:HasFocus() return false end
function frameMethods:GetRegions() end
function frameMethods:GetChildren() end
function frameMethods:SetScript(script, fn) self._scripts[script] = fn end
function frameMethods:GetScript(script) return self._scripts[script] end
function frameMethods:HasScript() return true end
function frameMethods:HookScript(script, fn)
    local old = self._scripts[script]
    self._scripts[script] = old and function(...) old(...); fn(...) end or fn
end
function frameMethods:RegisterEvent(event)
    if not self._events[event] then
        self._events[event] = true
        framesFor[event] = framesFor[event] or {}
        table.insert(framesFor[event], self)
    end
    return true
end
frameMethods.RegisterUnitEvent = frameMethods.RegisterEvent
function frameMethods:UnregisterEvent(event) self._events[event] = nil end
function frameMethods:UnregisterAllEvents() self._events = {} end
function frameMethods:IsEventRegistered(event) return self._events[event] == true end
local function Child(kind)
    return function(self, name) return NewFrame(kind, name, self) end
end
frameMethods.CreateFontString = Child("FontString")
frameMethods.CreateTexture = Child("Texture")
frameMethods.CreateMaskTexture = Child("MaskTexture")
frameMethods.CreateLine = Child("Line")
frameMethods.CreateAnimationGroup = Child("AnimationGroup")
frameMethods.CreateAnimation = Child("Animation")
frameMethods.meta = {
    __index = function(_, key)
        local method = frameMethods[key]
        if method ~= nil then return method end
        -- A method the client has (SetPoint, SetAlpha, ...) does nothing;
        -- a field the addon never set (button.fixedWidth) is nil.
        if type(key) == "string" and key:match("^%u") then return function() return nil end end
        return nil
    end,
}

local timers = {}
local now = 1000

local api = {
    CreateFrame = function(kind, name, parent) return NewFrame(kind, name, parent) end,
    GetTime = function() return now end,
    time = function(t) if t then return os.time(t) end return 1790000000 end,
    date = os.date,
    GetServerTime = function() return 1790000000 end,
    debugprofilestop = function() return os.clock() * 1000 end,
    geterrorhandler = function() return function(err) Record("handler", err) end end,
    seterrorhandler = function() end,
    hooksecurefunc = function() end,
    issecurevariable = function() return true end,
    InCombatLockdown = function() return false end,
    GetLocale = function() return "enUS" end,
    GetCurrentRegion = function() return 1 end,
    GetCurrentRegionName = function() return "US" end,
    GetBuildInfo = function() return "12.0.5", "60000", "Oct 1 2026", 120105 end,
    UnitGUID = function(unit) return unit == "player" and "Player-1-00000001" or nil end,
    UnitName = function(unit) if unit == "player" then return "Tester", nil end end,
    UnitFullName = function(unit) if unit == "player" then return "Tester", "Realm" end end,
    GetRealmName = function() return "Realm" end,
    GetNormalizedRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Alliance", "Alliance" end,
    UnitLevel = function() return 80 end,
    UnitClass = function() return "Mage", "MAGE", 8 end,
    UnitRace = function() return "Human", "Human" end,
    UnitExists = function(unit) return unit == "player" end,
    UnitIsUnit = function(a, b) return a == b end,
    GetMoney = function() return 0 end,
    GetScreenWidth = function() return 1920 end,
    GetScreenHeight = function() return 1080 end,
    GetCursorPosition = function() return 0, 0 end,
    GetFramerate = function() return 60 end,
    IsShiftKeyDown = function() return false end,
    IsControlKeyDown = function() return false end,
    IsAltKeyDown = function() return false end,
    IsInGuild = function() return false end,
    IsInGroup = function() return false end,
    IsInRaid = function() return false end,
    IsInInstance = function() return false, "none" end,
    GetNumGroupMembers = function() return 0 end,
    IsAddOnLoaded = function() return false end,
    GetAddOnMetadata = function() return nil end,
    GetCVar = function() return nil end,
    GetCVarBool = function() return false end,
    SetCVar = function() end,
    PlaySound = function() end,
    PlaySoundFile = function() end,
    C_Timer = {
        After = function(_, fn) timers[#timers + 1] = fn end,
        NewTimer = function(_, fn)
            timers[#timers + 1] = fn
            return { Cancel = function() end, IsCancelled = function() return false end }
        end,
        NewTicker = function()
            return { Cancel = function() end, IsCancelled = function() return false end }
        end,
    },
    C_AddOns = {
        IsAddOnLoaded = function() return false end,
        GetAddOnMetadata = function() return nil end,
        DoesAddOnExist = function() return false end,
        GetAddOnEnableState = function() return 0 end,
    },
    C_CVar = {
        GetCVar = function() return nil end,
        GetCVarBool = function() return false end,
        SetCVar = function() end,
        RegisterCVar = function() end,
    },
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return true end,
        SendAddonMessage = function() return true end,
        IsAddonMessagePrefixRegistered = function() return true end,
    },
    SlashCmdList = {},
    strsplit = function(sep, text, limit)
        local out, start = {}, 1
        while true do
            if limit and #out == limit - 1 then out[#out + 1] = text:sub(start); break end
            local a, b = text:find(sep, start, true)
            if not a then out[#out + 1] = text:sub(start); break end
            out[#out + 1] = text:sub(start, a - 1)
            start = b + 1
        end
        return unpack(out)
    end,
    strtrim = function(text) return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")) end,
    strjoin = function(sep, ...) return table.concat({ ... }, sep) end,
    strmatch = string.match, strfind = string.find, strsub = string.sub, strlen = string.len,
    strlower = string.lower, strupper = string.upper, strrep = string.rep, gsub = string.gsub,
    format = string.format, strbyte = string.byte, strchar = string.char,
    tinsert = table.insert, tremove = table.remove, sort = table.sort,
    floor = math.floor, ceil = math.ceil, max = math.max, min = math.min, abs = math.abs,
    sqrt = math.sqrt, random = math.random, mod = math.fmod,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end,
    CopyTable = function(t)
        local function Copy(src)
            local out = {}
            for k, v in pairs(src) do out[k] = type(v) == "table" and Copy(v) or v end
            return out
        end
        return Copy(t)
    end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    CreateFromMixins = function(...)
        local target = {}
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a, GetRGB = function() return r, g, b end,
            GetRGBA = function() return r, g, b, a end,
            GenerateHexColor = function() return "ffffffff" end }
    end,
}

local STD = {
    "string", "table", "math", "pairs", "ipairs", "type", "tostring", "tonumber", "select",
    "unpack", "next", "pcall", "xpcall", "error", "assert", "setmetatable", "getmetatable",
    "rawget", "rawset", "rawequal", "loadstring", "coroutine", "print", "collectgarbage",
    "os", "bit", "newproxy", "gcinfo", "setfenv", "getfenv",
}

local env = {}
for _, name in ipairs(STD) do env[name] = _G[name] end
for name, value in pairs(api) do env[name] = value end
env._G = env
env.UIParent = NewFrame("Frame", "UIParent")
env.WorldFrame = NewFrame("Frame", "WorldFrame")
env.Minimap = NewFrame("Frame", "Minimap")
env.GameTooltip = NewFrame("GameTooltip", "GameTooltip")
env.ItemRefTooltip = NewFrame("GameTooltip", "ItemRefTooltip")
env.DEFAULT_CHAT_FRAME = NewFrame("Frame", "ChatFrame1")
env.DEFAULT_CHAT_FRAME.AddMessage = function() end
env.ChatFrame1 = env.DEFAULT_CHAT_FRAME
-- The saved variables start empty, as on a first login, and no sister
-- addon is loaded. `rawget(_G, name)` finds nothing for a call the client
-- lacks.
setmetatable(env, { __index = function(_, key)
    if type(key) == "string" and key:match("^Blackthornes") then return nil end
    return Unknown
end })

local ns = {}
local function Run(file)
    local chunk, why = loadfile(ROOT .. "/" .. file)
    if not chunk then Record(file, why); return end
    setfenv(chunk, env)
    local ok, err = pcall(chunk, "Blackthornes_TS", ns)
    if not ok then Record(file, err) end
end

local function Fire(event, ...)
    for _, frame in ipairs(framesFor[event] or {}) do
        local onEvent = frame._events[event] and frame._scripts.OnEvent
        if onEvent then
            local ok, err = pcall(onEvent, frame, event, ...)
            if not ok then Record(event, err) end
        end
    end
end

local function RunTimers(rounds)
    for _ = 1, rounds do
        local due = timers
        timers = {}
        now = now + 10
        for _, fn in ipairs(due) do
            if type(fn) == "function" then
                local ok, err = pcall(fn)
                if not ok then Record("timer", err) end
            end
        end
    end
end

local function Report(label)
    check(label, #errors == 0, #errors > 0 and (#errors .. " error(s)") or nil)
    for i = 1, math.min(#errors, 12) do print("        " .. errors[i]) end
    errors = {}
end

--------------------------------------------------------------------------------
print("")
print("loading as Retail does")

for _, file in ipairs(files) do Run(file) end
Report("every file the TOC lists loads")

check("no Merchant's Favor", ns.MerchantsFavor == nil)
check("no Craftsman's Writs", ns.Writs == nil)
check("no Legacy perks", ns.Legacy == nil)
check("no data sending", ns.Contribute == nil)
check("no Guide Me", ns.Travel == nil)
check("no Forever recipes in the book", not (ns.RECIPE_BOOK and ns.RECIPE_BOOK.RECIPES
    and ns.RECIPE_BOOK.RECIPES[1213481]))
check("no Forever vendor spots", ns.FOREVER_VENDOR_SPOTS == nil and ns.FOREVER_TRAINER_SPOTS == nil)
check("the public global is there", rawget(env, "BlackthornesTS") == ns)

Fire("ADDON_LOADED", "Blackthornes_TS")
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD", true, false)
RunTimers(5)
Report("it loads and logs in")

--------------------------------------------------------------------------------
print("")
print("the window and Settings")

local slash = env.SlashCmdList.BLACKTHORNESTS
check("/bts is there", type(slash) == "function")

local UI = ns.UI
local opened = pcall(function()
    if UI and UI.Toggle then UI:Toggle() end
end)
check("the window opens", opened)
RunTimers(2)

local tabs = {}
for _, tab in ipairs(UI and UI.tabOrder or {}) do
    tabs[#tabs + 1] = tab.key
    local ok, err = pcall(UI.SelectTab, UI, tab.key)
    if not ok then Record("tab " .. tab.key, err) end
    RunTimers(1)
end
check("the window has its tabs", #tabs >= 8, #tabs .. " tabs")
check("no Favors and Writs tab", UI and UI.tabs and UI.tabs.deals == nil)
Report("every tab draws without the left out files")

local typed = pcall(slash, "help all")
check("/bts help all answers", typed)
for _, word in ipairs({ "share data", "arrow check" }) do
    pcall(slash, word)
end
Report("typed commands that once reached a left out file answer")

print(("\nretail: %d passed, %d failed"):format(passed, failed))
assert(failed == 0, failed .. " retail check(s) failed")
