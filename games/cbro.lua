local M = function(NX)

NX.gameName = "counter blox"
NX.skins = true

NX.tune = {
}

local UI = NX.UI
local CFG = NX.CFG

CFG.ns = { floor = 0.001, rate = 0.5 }
local RS = game:GetService("ReplicatedStorage")

local SKIN_OFF = { name_container = 112 }

local KNIVES = { "None",
    "Karambit", "M9 Bayonet", "Bayonet", "Butterfly Knife",
    "Gut Knife", "Falchion Knife", "Falchion Classic", "Huntsman Knife",
    "Bearded Axe", "Cleaver", "Sickle", "Sickle Classic",
}

local ST = { ["T Knife"] = nil, ["CT Knife"] = nil }

NX.onOffsets(function()
    SKIN_OFF.name_container = NX.off('Instance', 'NameContainer', SKIN_OFF.name_container)
end)

local function rd(addr)
    local ok, v = pcall(memory_read, "uintptr_t", addr)
    return ok and v or 0
end

local function wr(addr, val)
    return pcall(memory_write, "uintptr_t", addr, val)
end

local function swapNames(a, b)
    if not a or not b or a == b then return false end
    local aa, ba = a.Address, b.Address
    if not aa or not ba then return false end
    local pa, pb = rd(aa + SKIN_OFF.name_container), rd(ba + SKIN_OFF.name_container)
    if pa == 0 or pb == 0 or pa == pb then return false end
    wr(aa + SKIN_OFF.name_container, pb)
    wr(ba + SKIN_OFF.name_container, pa)
    return true
end

local function swapKnife(stock, target)
    local vm = RS:FindFirstChild("Viewmodels")
    if not vm then return false end
    return swapNames(vm:FindFirstChild("v_" .. stock), vm:FindFirstChild("v_" .. target))
end

local function applyKnife(stock, name)
    local cur = ST[stock]
    if cur then
        swapKnife(stock, cur)
        ST[stock] = nil
    end
    if not name or name == "None" then return end
    if swapKnife(stock, name) then ST[stock] = name end
end

local SPREAD = { "Stand", "Crouch", "Move", "Jump", "InitialJump",
                 "Land", "Ladder" }
local RECOIL = { "Recoil", "Fire", "RecoveryTime" }

local NS = { spread = false, recoil = false, saved = {} }

local function spreadFolders()
    local out = {}
    local w = RS:FindFirstChild("Weapons")
    if not w then return out end
    for _, gun in ipairs(w:GetChildren()) do
        local sp = gun:FindFirstChild("Spread")
        if sp then out[#out + 1] = sp end
    end
    return out
end

local function flatten(keys)
    local floor = CFG.ns.floor
    if floor < 0.001 then floor = 0.001 end
    local n = 0
    for _, sp in ipairs(spreadFolders()) do
        for _, key in ipairs(keys) do
            local v = sp:FindFirstChild(key)
            if v then
                local cur = v.Value
                if type(cur) == "number" and cur > floor then
                    if NS.saved[v] == nil then NS.saved[v] = cur end
                    if pcall(function() v.Value = floor end) then n = n + 1 end
                end
            end
        end
    end
    return n
end

local function restoreKeys(keys)
    local want = {}
    for _, k in ipairs(keys) do want[k] = true end
    for v, old in pairs(NS.saved) do
        if want[v.Name] then
            pcall(function() v.Value = old end)
            NS.saved[v] = nil
        end
    end
end

local function applySpread()
    local n = 0
    if NS.spread then n = n + flatten(SPREAD) end
    if NS.recoil then n = n + flatten(RECOIL) end
    return n
end

task.spawn(function()
    while true do
        if NS.spread or NS.recoil then pcall(applySpread) end
        task.wait(CFG.ns.rate)
    end
end)

local tab = UI:Tab("skins", "Skins")

local kn = tab:Section("Knives", "left")
kn:Dropdown("T knife", "None", KNIVES, function(v) applyKnife("T Knife", v) end)
kn:Dropdown("CT knife", "None", KNIVES, function(v) applyKnife("CT Knife", v) end)
kn:Button("Reset", function()
    applyKnife("T Knife", "None")
    applyKnife("CT Knife", "None")
end)

local cb = UI:Tab("combat", "Combat")
local ns = cb:Section("Weapon", "left")
ns:Toggle("No spread", false, function(v)
    NS.spread = v
    if v then flatten(SPREAD) else restoreKeys(SPREAD) end
end)
ns:Toggle("No recoil", false, function(v)
    NS.recoil = v
    if v then flatten(RECOIL) else restoreKeys(RECOIL) end
end)

end

local ENV = (getfenv and getfenv()) or _G
ENV.NEXORA_GAME = M
return M
