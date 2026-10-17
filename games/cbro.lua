--[[ counter blox module
     CBRO runs source-style movement: humanoid physics with its own air accel.
     everything here is velocity-only on the local character. no offsets are
     hardcoded; anything game specific sits in CFG so it can be corrected
     from the menu instead of needing a rebuild.                         ]]

local M = function(NX)

local UI = NX.UI
local Players = game:GetService("Players")

local CFG, ST = NX.CFG, NX.ST
NX.gameName = "counter blox"

do
    local c = {
        eps     = { ground = 1.5 },
        bhop    = { hold = true },
        eb      = { slide = 0.25, carry = 0.8, minsp = 24, maxsp = 180,
                    minfall = -1, flatten = true },
        lj      = { mult = 1.3, min = 18, max = 40, cd = 0.25, hold = 0.35,
                    edgevel = 18, edgemax = 1, edgecd = 2 },
        aj      = { vel = 18 },
        mj      = { vel = 13 },
        ws      = { gain = 51, dead = 0.02 },
        wall    = { speed = 6, grace = 0.2 },
    }
    for k, v in pairs(c) do CFG[k] = v end

    local s = {
        eb   = { prevY = 0, wasG = true, dir = nil, sp = 0, sdir = nil, ssp = 0, untilT = 0 },
        lj   = { cd = 0, ecd = 0 },
        jm   = { wasG = true, prevY = 0 },
        ws   = { stuck = false, pos = nil },
        wall = { lastPos = nil, t = 0, disp = 0, untilT = 0, on = false },
        bh   = { on = false },
    }
    for k, v in pairs(s) do ST[k] = v end
end

local parts, cue = NX.parts, NX.cue
local setHoriz, setY = NX.setHoriz, NX.setY
local impulse, stepImpulse = NX.impulse, NX.stepImpulse
local active = NX.active

local F = {}

local function pressed(k)
    local f = F[k]
    return f and f.item.value and f.bind and f.bind.key
        and UI:Clicked(f.bind.key) or false
end

local function onGround(vel)
    local e = CFG.eps.ground
    if ST.g == nil then ST.g = true end
    if ST.g then ST.g = math.abs(vel.Y) < e * 2 else ST.g = math.abs(vel.Y) < e end
    return ST.g
end

local function moveInput()
    return UI:Held('w') or UI:Held('a') or UI:Held('s') or UI:Held('d')
end

local function camLook()
    local ok, cf = pcall(function() return workspace.CurrentCamera.CFrame end)
    if not ok or not cf then return nil end
    local l = cf.LookVector
    local f = Vector3.new(l.X, 0, l.Z)
    if f.Magnitude < 0.1 then return nil end
    return f.Unit
end

local function trackWall(root)
    local now = os.clock()
    local p = root.Position
    if ST.wall.lastPos then
        local dt = now - ST.wall.t
        if dt > 0 then
            local d = p - ST.wall.lastPos
            ST.wall.disp = Vector3.new(d.X, 0, d.Z).Magnitude / dt
        end
    end
    ST.wall.lastPos, ST.wall.t = p, now
    if moveInput() and ST.wall.disp <= CFG.wall.speed then
        ST.wall.untilT = now + CFG.wall.grace
    end
    ST.wall.on = now < ST.wall.untilT
end

----------------------------------------------------------------- features --

local function stepBhop(root, vel, g)
    ST.bh.on = false
    if not active('bhop') then return end
    if not UI:Held('space') then return end
    if not g then return end
    local hum = select(3, parts())
    if not hum then return end
    pcall(function() hum.Jump = true end)
    ST.bh.on = true
end

local function stepEdgebug(root, vel, g)
    local horiz = Vector3.new(vel.X, 0, vel.Z)
    local sp = horiz.Magnitude

    if not g and sp > 0.1 then
        ST.eb.dir, ST.eb.sp = horiz.Unit, sp
    end

    if g and not ST.eb.wasG then
        if active('eb') and ST.eb.dir and ST.eb.prevY <= CFG.eb.minfall then
            local target = math.max(ST.eb.sp * CFG.eb.carry, CFG.eb.minsp)
            if target > CFG.eb.maxsp then target = CFG.eb.maxsp end
            ST.eb.sdir, ST.eb.ssp = ST.eb.dir, target
            ST.eb.untilT = os.clock() + CFG.eb.slide
            cue('edge bug')
        end
    end
    ST.eb.wasG = g

    if ST.eb.untilT > os.clock() then
        if active('eb') and ST.eb.sdir then
            if CFG.eb.flatten and vel.Y > 0 then setY(root, 0) end
            setHoriz(root, ST.eb.sdir.X * ST.eb.ssp, ST.eb.sdir.Z * ST.eb.ssp)
        else
            ST.eb.untilT = 0
        end
    end
    ST.eb.prevY = vel.Y
end

local function stepJumps(root, vel, g)
    local raw = vel.Y
    local prevY = ST.jm.prevY
    local tookOff = (not g) and ST.jm.wasG
    local rising = raw > 10 and prevY <= 1
    local didEdge = false

    if active('lj') and tookOff and os.clock() >= ST.lj.cd then
        local now = os.clock()
        local isEdge = raw <= CFG.lj.edgemax
        if (not isEdge) or now >= ST.lj.ecd then
            local cur = root.AssemblyLinearVelocity
            local dir = camLook()
            if not dir then
                local h = Vector3.new(cur.X, 0, cur.Z)
                if h.Magnitude > 0.1 then dir = h.Unit end
            end
            if dir then
                local y = cur.Y
                if isEdge then
                    y = CFG.lj.edgevel
                    ST.lj.ecd = now + CFG.lj.edgecd
                    didEdge = true
                end
                local sp = Vector3.new(cur.X, 0, cur.Z).Magnitude * CFG.lj.mult
                if sp < CFG.lj.min then sp = CFG.lj.min end
                if sp > CFG.lj.max then sp = CFG.lj.max end
                impulse(root, dir.X * sp, dir.Z * sp, CFG.lj.hold)
                setY(root, y)
                ST.lj.cd = now + CFG.lj.cd
                cue(isEdge and 'edge jump' or 'long jump')
            end
        end
    end

    if pressed('aj') then
        setY(root, CFG.aj.vel)
        cue('air jump')
    end

    if rising and not didEdge and active('mj') then
        setY(root, CFG.mj.vel)
        cue('mini jump')
    end

    ST.jm.wasG = g
    ST.jm.prevY = raw
end

local function stepWallStuck(root)
    if not active('ws') then ST.ws.stuck = false ST.ws.pos = nil return end
    if not ST.ws.stuck and not ST.wall.on then return end
    if not ST.ws.stuck then
        ST.ws.stuck = true
        ST.ws.pos = root.Position
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        return
    end
    local p = ST.ws.pos
    if not p then ST.ws.pos = root.Position return end
    local here = root.Position
    local dx, dy, dz = p.X - here.X, p.Y - here.Y, p.Z - here.Z
    local drift = math.sqrt(dx * dx + dy * dy + dz * dz)
    if drift < CFG.ws.dead then
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    else
        root.AssemblyLinearVelocity =
            Vector3.new(dx * CFG.ws.gain, dy * CFG.ws.gain, dz * CFG.ws.gain)
    end
end

local function stepStats(root, vel, g)
    local now = os.clock()
    local sp = Vector3.new(vel.X, 0, vel.Z).Magnitude * (250 / 19)

    if (not g) and ST.js.wasG then
        ST.js.air, ST.js.t0, ST.js.p0, ST.js.sp0, ST.js.peak = true, now, root.Position, sp, 0
    elseif (not g) and ST.js.air and ST.js.p0 then
        local h = root.Position.Y - ST.js.p0.Y
        if h > ST.js.peak then ST.js.peak = h end
    elseif g and ST.js.air and ST.js.p0 then
        ST.js.air = false
        if (now - ST.js.t0) >= CFG.stats.minair and ST.js.peak >= CFG.stats.minpeak then
            local d = root.Position - ST.js.p0
            ST.js.last = {
                take = ST.js.sp0, land = sp,
                dist = Vector3.new(d.X, 0, d.Z).Magnitude,
                air = now - ST.js.t0, peak = ST.js.peak, at = now,
            }
        end
    end
    ST.js.wasG = g
end

local function resetState(root)
    if ST.root == root then return end
    ST.root = root
    ST.eb.untilT, ST.eb.dir, ST.eb.wasG, ST.eb.prevY = 0, nil, true, 0
    ST.jm.wasG, ST.jm.prevY = true, 0
    ST.ws.stuck, ST.ws.pos = false, nil
    ST.js.air, ST.js.p0 = false, nil
    ST.wall.lastPos, ST.wall.untilT, ST.wall.on = nil, 0, false
    ST.lj.cd, ST.lj.ecd, ST.imp.untilT = 0, 0, 0
end

local function stepRender()
    local char, root = parts()
    if not char then return end
    resetState(root)
    local vel = root.AssemblyLinearVelocity
    local g = onGround(vel)
    stepBhop(root, vel, g)
    stepStats(root, vel, g)
    stepJumps(root, vel, g)
    stepEdgebug(root, vel, g)
end

local function stepPhysics()
    local char, root = parts()
    if not char then
        ST.ws.stuck, ST.wall.on = false, false
        return
    end
    local vel = root.AssemblyLinearVelocity
    trackWall(root)
    stepImpulse(root, onGround(vel))
    stepWallStuck(root)
end

--------------------------------------------------------------------- menu --

local mv = NX.tab("movement", "Movement")
local main = mv:Section("Main", "left")

local ebT = main:Toggle("Edge bug", true)
F.eb = { item = ebT.item, bind = ebT:AddKeybind('lshift', 'Hold') }
local ljT = main:Toggle("Long jump", true)
F.lj = { item = ljT.item, bind = ljT:AddKeybind('g', 'Hold') }
local ajT = main:Toggle("Air jump", true)
F.aj = { item = ajT.item, bind = ajT:AddKeybind('z', 'Hold') }
local mjT = main:Toggle("Mini jump", true)
F.mj = { item = mjT.item, bind = mjT:AddKeybind('n', 'Hold') }
local wsT = main:Toggle("Wall stuck", true)
F.ws = { item = wsT.item, bind = wsT:AddKeybind('v', 'Toggle') }
local bhT = main:Toggle("Bunny hop", false)
F.bhop = { item = bhT.item }

local SHORT = { eb = 'eb', lj = 'lj', aj = 'aj', mj = 'mj', ws = 'ws',
                bhop = 'bhop', wall = 'wall' }
local ORDER = { 'wall', 'bhop', 'eb', 'lj', 'aj', 'mj', 'ws' }
local IND = {
    wall = function() return ST.wall.on end,
    bhop = function() return ST.bh.on end,
}

for _, k in ipairs(ORDER) do
    local f = F[k]
    NX.register(k, SHORT[k], f and f.item or { value = true },
                f and f.bind or nil, IND[k])
end

NX.onRender(stepRender)
NX.onPhysics(stepPhysics)

end

local ENV = (getfenv and getfenv()) or _G
ENV.NEXORA_MODULE = M
return M
