local M = function(NX)

NX.gameName = "typical colors 2"
NX.movement = "movement_tc2"

NX.tune = {
}

local UI = NX.UI
local Players = game:GetService("Players")
local SK = { applied = nil, lastClass = nil, ok = false }

local SKIN_OFF = { name_container = 112 }
local STOCK = {
    Flanker = "Bat", Marksman = "Machete", Annihilator = "Broken Sword",
    Trooper = "Crowbar", Brute = "Fists", Arsonist = "Fire Extinguisher",
    Mechanic = "Wrench", Doctor = "Saw", Agent = "Knife",
}
local SKINS = { "None", "Golden", "Bloxy Award", "Golden Frying Pan", "Frying Pan",
                "Bad to the Bone", "tf_Knife" }
local GOLD_BY_CLASS = { Agent = "Golden Knife", Mechanic = "Golden Wrench" }
local GOLD_FALLBACK = "Golden Frying Pan"

NX.onOffsets(function()
    SKIN_OFF.name_container = NX.off('Instance', 'NameContainer', SKIN_OFF.name_container)
end)

local function resolveSkin(name, className)
    if name == "Golden" then
        return (className and GOLD_BY_CLASS[className]) or GOLD_FALLBACK
    end
    return name
end

local function rd(addr)
    local ok, v = pcall(memory_read, "uintptr_t", addr)
    return ok and v or 0
end

local function wr(addr, val)
    return pcall(memory_write, "uintptr_t", addr, val)
end

local function swapNames(a, b)
    if not a or not b then return false end
    local aa, ba = a.Address, b.Address
    if not aa or not ba then return false end
    local pa, pb = rd(aa + SKIN_OFF.name_container), rd(ba + SKIN_OFF.name_container)
    if pa == 0 or pb == 0 then return false end
    wr(aa + SKIN_OFF.name_container, pb)
    wr(ba + SKIN_OFF.name_container, pa)
    return true
end

local function swapForClass(className, stockName, skinName)
    local rs = game:GetService("ReplicatedStorage")
    if not rs then return end
    local hit = false

    local itc = rs:FindFirstChild("ItemToClass")
    if itc then itc = itc:FindFirstChild(className) end
    if itc then
        if swapNames(itc:FindFirstChild(stockName), itc:FindFirstChild(skinName)) then hit = true end
    end

    local pnc = rs:FindFirstChild("ProsNCons")
    if pnc then
        if swapNames(pnc:FindFirstChild(stockName), pnc:FindFirstChild(skinName)) then hit = true end
    end

    local vm = rs:FindFirstChild("Viewmodels")
    if vm then
        local a = vm:FindFirstChild("v_" .. stockName) or vm:FindFirstChild(stockName)
        local b = vm:FindFirstChild("v_" .. skinName) or vm:FindFirstChild(skinName)
        if swapNames(a, b) then hit = true end
    end

    SK.ok = hit
end

local function refreshSkin()
    local want = SK.applied
    if not want then return end
    local plr = Players.LocalPlayer
    if not plr then return end
    local ok, className = pcall(function() return plr:GetAttribute("CurrentClass") end)
    if not ok then return end
    if className == SK.lastClass then return end

    local prev = SK.lastClass
    if prev and STOCK[prev] then
        swapForClass(prev, STOCK[prev], resolveSkin(want, prev))
    end
    if className and STOCK[className] then
        swapForClass(className, STOCK[className], resolveSkin(want, className))
    end
    SK.lastClass = className
end

local function applySkin(name)
    local prev = SK.lastClass
    local cur = SK.applied
    if prev and cur and STOCK[prev] then
        swapForClass(prev, STOCK[prev], resolveSkin(cur, prev))
    end
    SK.lastClass = nil
    if not name or name == "None" then
        SK.applied = nil
        SK.ok = false
        return
    end
    SK.applied = name
    refreshSkin()
end

task.spawn(function()
    while true do
        pcall(refreshSkin)
        task.wait(1)
    end
end)

local vis = UI:Tab("skins", "Skins")
local sk = vis:Section("Melee", "left")
sk:Dropdown("Skin", "None", SKINS, function(v) applySkin(v) end)
sk:Button("Reapply", function()
    SK.lastClass = nil
    refreshSkin()
end)
sk:Button("Reset", function() applySkin("None") end)

end

local ENV = (getfenv and getfenv()) or _G
ENV.NEXORA_GAME = M
return M
