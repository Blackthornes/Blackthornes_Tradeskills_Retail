-- The Snipe tab's rows (UI/SnipeView.lua), outside WoW.
--
-- A find once showed its name and nothing under Price or Deal (2026-11-03).
-- What must hold:
--   1. A find's row shows its price under Price and how far under worth
--      under Deal, on one line; the hover has how many and the worth.
--   2. The name is plain (no link brackets), in the item's colour.
--   3. Price and Deal are filled even when the item's name can't be read.
--   4. "Looking for deals..." is hidden once there is a find.


local function noop() end

-- Frames whose methods do nothing unless named here; fields read as nil. Edit
-- boxes keep focus the game's way: only SetFocus, ClearFocus and hiding
-- change it, and losing it runs OnEditFocusLost.
local function NewFrame()
    local f = { scripts = {}, shown = true, text = "", height = 0, width = 0, points = {} }

    setmetatable(f, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return noop end
    end })

    f.SetScript = function(self, n, fn) self.scripts[n] = fn end
    f.GetScript = function(self, n) return self.scripts[n] end
    f.HookScript = function(self, n, fn)
        local old = self.scripts[n]
        self.scripts[n] = function(...) if old then old(...) end fn(...) end
    end
    f.Show = function(self) self.shown = true end
    f.Hide = function(self)
        self.shown = false
        if self.focus then self:ClearFocus() end
    end
    f.SetShown = function(self, v) if v then self:Show() else self:Hide() end end
    f.IsShown = function(self) return self.shown end
    f.IsVisible = function(self) return self.shown end
    f.SetText = function(self, t) self.text = t end
    f.GetText = function(self) return self.text end
    f.SetHeight = function(self, h) self.height = h end
    f.GetHeight = function(self) return self.height end
    f.SetWidth = function(self, w) self.width = w end
    f.GetWidth = function(self) return self.width end
    f.SetSize = function(self, w, h) self.width, self.height = w, h end
    f.GetStringWidth = function(self) return #tostring(self.text or "") * 6 end
    f.CreateTexture = function() return NewFrame() end
    f.CreateFontString = function() return NewFrame() end
    f.SetMinMaxValues = function(self, a, b) self.minv, self.maxv = a, b end
    f.GetMinMaxValues = function(self) return self.minv or 0, self.maxv or 0 end
    f.SetValue = function(self, v) self.value = v end
    f.GetValue = function(self) return self.value or 0 end
    f.IsMouseOver = function() return false end
    f.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end
    f.ClearAllPoints = function(self) self.points = {} end
    f.GetNumPoints = function(self) return #self.points end
    f.SetFocus = function(self) self.focus = true end
    f.HasFocus = function(self) return self.focus == true end
    f.ClearFocus = function(self)
        if self.focus then
            self.focus = false
            if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
        end
    end

    return f
end

CreateFrame = function() return NewFrame() end
UIParent = NewFrame()
GameTooltip = NewFrame()
GameFontNormal = NewFrame()
ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 } }
local itemInfoWorks = true
C_Item = {
    GetItemInfo = function()
        if not itemInfoWorks then error("no item info") end
        return "Stringy Wolf Meat", "|cffffffff|Hitem:2672::|h[Stringy Wolf Meat]|h|r", 1
    end,
    GetItemIconByID = function() return 1 end,
}
local tipLines = {}
GameTooltip.AddLine = function(_, text) tipLines[#tipLines + 1] = text end

local ns = {}
ns.COLORS = setmetatable({}, { __index = function() return "ffffffff" end })
ns.NewModule = function(name) local m = ns[name] or {}; ns[name] = m; return m end
ns.RegisterCommand, ns.RegisterEvent = noop, noop
ns.Print, ns.PrintRaw, ns.Debug, ns.Warn = noop, noop, noop, noop
ns.db = {}
local settings = {}
ns.Config = { Get = function(_, k) return settings[k] end, Set = function(_, k, v) settings[k] = v end }
local function Load(path) assert(loadfile(lfs_cwd .. path))("Blackthornes_TS", ns) end
Load("/Locale/Locale.lua"); Load("/Core/Util.lua"); Load("/UI/Theme.lua"); Load("/UI/Widgets.lua")
ns.PriceEditor = { MoneyBoxes = function() local f = NewFrame(); f.boxes = {}; return f end }

local finds = {}
ns.Snipe = setmetatable({
    Finds = function() return finds end, IsRunning = function() return true end,
    Spent = function() return 0 end, Cap = function() return 1000000 end,
    Percent = function() return 70 end, Watch = function() return "priced" end,
    Deal = function(p, w) return math.floor((1 - p / w) * 100 + 0.5) end, version = 1,
}, { __index = function(_, k) if k:match("^%u") then return noop end end })
Load("/UI/SnipeView.lua")

local passed, failed = 0, 0
local function check(label, got, want)
    local ok = got == want
    if ok then passed = passed + 1 else failed = failed + 1 end
    print(string.format("  %-52s %-24s %s", label, tostring(got), ok and "ok" or
        ("WRONG, wanted " .. tostring(want))))
end
local function Plain(text) return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local SV = ns.SnipeView
SV:Build(NewFrame(), NewFrame(), NewFrame(), {})
SV.list.height = 300
SV:SetShown(true)

-- 4 (no finds yet)
SV:Refresh(true)
check("no finds: the note shows", SV.empty.shown, true)

-- 1, 2, 4
finds[1] = { itemID = 2672, price = 150, worth = 900, qty = 3 }
ns.Snipe.version = 2
SV:Refresh(true)
local row = SV.list.rows[1]
check("name is plain", row.name.text, "Stringy Wolf Meat")
check("price under Price", Plain(row.price.text), "1s 50c")
check("deal under Deal", row.badge.text, "83% under")
check("the note hides", SV.empty.shown, false)
row.scripts.OnEnter(row)
check("hover says how many and the worth", Plain(tipLines[#tipLines]), "3 for sale. 1s 50c each, worth 9s 00c")

-- 3
itemInfoWorks = false
finds[1] = { itemID = 2673, price = 300, worth = 1000, qty = 1 }
ns.Snipe.version = 3
pcall(SV.Refresh, SV, true)
check("price with no item info", Plain(row.price.text), "3s 00c")
check("deal with no item info", row.badge.text, "70% under")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("test_snipeview failed") end
