local M = function(NX)

NX.gameName = "counter blox"
NX.skins = true

NX.tune = {
}

local UI = NX.UI
local cue = NX.cue
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
    if not name or name == "None" then
        cue(stock:lower() .. " reset")
        return
    end
    if swapKnife(stock, name) then
        ST[stock] = name
        cue(stock:lower() .. " " .. name:lower())
    else
        cue(stock:lower() .. " failed")
    end
end

local tab = UI:Tab("visuals", "Skins")

local kn = tab:Section("Knives", "left")
kn:Dropdown("T knife", "None", KNIVES, function(v) applyKnife("T Knife", v) end)
kn:Dropdown("CT knife", "None", KNIVES, function(v) applyKnife("CT Knife", v) end)
kn:Button("Reset", function()
    applyKnife("T Knife", "None")
    applyKnife("CT Knife", "None")
end)

end

local ENV = (getfenv and getfenv()) or _G
ENV.NEXORA_GAME = M
return M
