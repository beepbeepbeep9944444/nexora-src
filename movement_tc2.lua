
local M = function(NX)

local UI = NX.UI
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CFG, ST = NX.CFG, NX.ST

do
    local c = {
    eb = { slide = 0.25, carry = 0.8, minsp = 30, maxsp = 210, minfall = -1,
           flatten = true, eps = 1.5 },
    px = { speed = 25, gain = 50, dead = 0.1 },
    tb = { sig = 0.0000065, tol = 2, drop = 7, gain = 150 },
    wall = { speed = 6, grace = 0.2 },
    ws = { gain = 51, dead = 0.02, hard = false },
    wc = { speed = 30, push = 8 },
    hb = { upmin = 8, ceileps = 1, carry = 1.05, time = 0.3 },
    lj = { mult = 1.3, min = 18, max = 40, lift = 0, cd = 0.25, hold = 0.35,
           edgevel = 18, edgemax = 1, edgecd = 2 },
    aj = { vel = 18 },
    mj = { vel = 13 },
    jb = { vel = 30 },
    bhop = { floor = 384, jump = 471 },
    wj = { back = 34, up = 30, cd = 0.35, hold = 0.3, needwall = true },
    stats = { minair = 0.12, minpeak = 0.4 },
    }
    for k, v in pairs(c) do CFG[k] = v end
    if type(NX.tune) == "table" then
        for k, v in pairs(NX.tune) do
            if type(v) == "table" and type(CFG[k]) == "table" then
                for kk, vv in pairs(v) do CFG[k][kk] = vv end
            else
                CFG[k] = v
            end
        end
    end
    local s = {
    eb = { prevY = 0, wasG = true, dir = nil, sp = 0, sdir = nil, ssp = 0, untilT = 0, hit = 0 },
    px = { flying = false, lockY = 0, cam = true },
    tb = { active = false, startY = 0, vy = 0 },
    ws = { stuck = false, pos = nil },
    wc = { on = false },
    wall = { lastPos = nil, t = 0, disp = 0, untilT = 0, on = false },
    hb = { untilT = 0, dir = nil, sp = 0, prevVy = 0 },
    lj = { cd = 0, ecd = 0 },
    jm = { wasG = true, prevY = 0 },
    bhop = { on = false },
    wj = { cd = 0 },
    js = { air = false, wasG = true, t0 = 0, p0 = nil, sp0 = 0, peak = 0, last = nil },
    g = { on = true },
    }
    for k, v in pairs(s) do ST[k] = v end
end

local F = {}
local parts, cue = NX.parts, NX.cue
local setHoriz, setY = NX.setHoriz, NX.setY
local impulse, stepImpulse = NX.impulse, NX.stepImpulse

local function onGround(vel)
    local e = CFG.eb.eps
    local was = ST.g.on
    local v = math.abs(vel.Y)
    if was then ST.g.on = v < e * 2 else ST.g.on = v < e end
    return ST.g.on
end
local function active(k)
    local f = F[k]
    if not f or not f.item.value then return false end
    if not f.bind then return true end
    return f.bind.active and true or false
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
            ST.eb.hit = os.clock()
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

local function camDir()
    local ok, cf = pcall(function() return workspace.CurrentCamera.CFrame end)
    if not ok or not cf then ST.px.cam = false return nil end
    ST.px.cam = true
    local look, right = cf.LookVector, cf.RightVector
    local fl = Vector3.new(look.X, 0, look.Z)
    local fr = Vector3.new(right.X, 0, right.Z)
    if fl.Magnitude > 0 then fl = fl.Unit end
    if fr.Magnitude > 0 then fr = fr.Unit end
    local mv = Vector3.new(0, 0, 0)
    if UI:Held('w') then mv = mv + fl end
    if UI:Held('s') then mv = mv - fl end
    if UI:Held('d') then mv = mv + fr end
    if UI:Held('a') then mv = mv - fr end
    if mv.Magnitude > 0 then return mv.Unit end
    return Vector3.new(0, 0, 0)
end

local function moveInput()
    return UI:Held('w') or UI:Held('a') or UI:Held('s') or UI:Held('d')
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

local function wallOn() return ST.wall.on end

local function stepBhop(hum)
    ST.bhop.on = false
    if not active('bhop') then return end
    if not UI:Held('space') then return end
    if not hum or not NX.humAddr(hum) then return end
    local mat = NX.humGet(hum, 'FloorMaterial', "int", CFG.bhop.floor)
    if mat and mat > 0 then
        NX.humSet(hum, 'Jump', "byte", 1, CFG.bhop.jump)
        ST.bhop.on = true
    end
end

local function camLook()
    local ok, cf = pcall(function() return workspace.CurrentCamera.CFrame end)
    if not ok or not cf then return nil end
    local l = cf.LookVector
    local f = Vector3.new(l.X, 0, l.Z)
    if f.Magnitude < 0.1 then return nil end
    return f.Unit
end

local function stepHeadBounce(root, vel)
    if not active('hb') then
        ST.hb.untilT = 0
        ST.hb.prevVy = vel.Y
        return
    end

    if ST.hb.untilT > os.clock() then
        if ST.hb.dir then
            root.AssemblyLinearVelocity =
                Vector3.new(ST.hb.dir.X * ST.hb.sp, vel.Y, ST.hb.dir.Z * ST.hb.sp)
        end
        ST.hb.prevVy = vel.Y
        return
    end

    if ST.hb.prevVy >= CFG.hb.upmin and math.abs(vel.Y) <= CFG.hb.ceileps then
        local h = Vector3.new(vel.X, 0, vel.Z)
        if h.Magnitude > 0.1 then
            ST.hb.dir = h.Unit
            ST.hb.sp = h.Magnitude * CFG.hb.carry
            ST.hb.untilT = os.clock() + CFG.hb.time
            cue('head bounce')
        end
    end
    ST.hb.prevVy = vel.Y
end

local function pressed(k)
    local f = F[k]
    return f and f.item.value and f.bind and f.bind.key and UI:Clicked(f.bind.key)
end

local function stepJumps(root, vel, grounded)
    local raw = vel.Y
    local prevY = ST.jm.prevY
    local tookOff = (not grounded) and ST.jm.wasG
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
                if CFG.lj.lift > 0 then y = CFG.lj.lift end

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

    if pressed('wj') and os.clock() >= ST.wj.cd then
        if (not CFG.wj.needwall) or wallOn() then
            local cur = root.AssemblyLinearVelocity
            local dir = camLook()
            if not dir then
                local h = Vector3.new(cur.X, 0, cur.Z)
                if h.Magnitude > 0.1 then dir = h.Unit end
            end
            if dir then
                impulse(root, -dir.X * CFG.wj.back, -dir.Z * CFG.wj.back, CFG.wj.hold)
                setY(root, CFG.wj.up)
                ST.wj.cd = os.clock() + CFG.wj.cd
                cue('wall jump')
            end
        end
    end

    if pressed('aj') then
        setY(root, CFG.aj.vel)
        cue('air jump')
    end

    if rising and not didEdge then
        if active('mj') then
            setY(root, CFG.mj.vel)
            cue('mini jump')
        elseif active('jb') then
            setY(root, CFG.jb.vel)
            cue('jump bug')
        end
    end

    ST.jm.wasG = grounded
    ST.jm.prevY = raw
end

local function stepPixelSurf(root)
    if not active('px') then ST.px.flying = false return end
    if not ST.px.flying then
        ST.px.flying = true
        ST.px.lockY = root.Position.Y
    end
    local dir = camDir()
    if not dir then return end
    local mv = dir * CFG.px.speed
    local diff = ST.px.lockY - root.Position.Y
    local yv = diff * CFG.px.gain
    if math.abs(diff) < CFG.px.dead then yv = 0 end
    root.AssemblyLinearVelocity = Vector3.new(mv.X, yv, mv.Z)
end

local function stepTextureBug(root, vel, g)
    ST.tb.vy = vel.Y
    if not active('tb') then ST.tb.active = false return end
    if vel.Y > 0 then ST.tb.active = false return end

    if ST.tb.active then
        if math.abs(root.Position.Y - ST.tb.startY) >= CFG.tb.drop then
            ST.tb.active = false
            return
        end
        local diff = ST.tb.startY - root.Position.Y
        root.AssemblyLinearVelocity = Vector3.new(vel.X, diff * CFG.tb.gain, vel.Z)
        return
    end

    if math.abs(vel.Y - CFG.tb.sig) <= CFG.tb.tol then
        ST.tb.active = true
        ST.tb.startY = root.Position.Y
        cue('texture bug')
    end
end

local function stepWallClimb(root, vel)
    ST.wc.on = false
    if not active('wc') then return end
    if not wallOn() then return end
    local dir = camLook()
    if not dir then return end
    root.AssemblyLinearVelocity =
        Vector3.new(dir.X * CFG.wc.push, CFG.wc.speed, dir.Z * CFG.wc.push)
    ST.wc.on = true
end

local function stepWallStuck(root, vel)
    if not active('ws') then ST.ws.stuck = false ST.ws.pos = nil return end
    if not ST.ws.stuck and not wallOn() then return end
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
        if CFG.ws.hard then pcall(function() root.Position = p end) end
    end
end

local function stepStats(root, vel, g)
    local now = os.clock()
    local sp = Vector3.new(vel.X, 0, vel.Z).Magnitude * (250 / 19)

    if (not g) and ST.js.wasG then
        ST.js.air = true
        ST.js.t0 = now
        ST.js.p0 = root.Position
        ST.js.sp0 = sp
        ST.js.peak = 0
    elseif (not g) and ST.js.air and ST.js.p0 then
        local h = root.Position.Y - ST.js.p0.Y
        if h > ST.js.peak then ST.js.peak = h end
    elseif g and ST.js.air and ST.js.p0 then
        ST.js.air = false
        if (now - ST.js.t0) < CFG.stats.minair or ST.js.peak < CFG.stats.minpeak then
            return
        end
        local d = root.Position - ST.js.p0
        ST.js.last = {
            take = ST.js.sp0,
            land = sp,
            dist = Vector3.new(d.X, 0, d.Z).Magnitude,
            air = now - ST.js.t0,
            peak = ST.js.peak,
            at = now,
        }
    end
    ST.js.wasG = g
end

local function resetState(root)
    if ST.root == root then return end
    ST.root = root
    ST.eb.untilT, ST.eb.dir, ST.eb.wasG, ST.eb.prevY = 0, nil, true, 0
    ST.hb.untilT, ST.hb.dir, ST.hb.prevVy = 0, nil, 0
    ST.tb.active = false
    ST.ws.stuck, ST.ws.pos = false, nil
    ST.px.flying = false
    ST.wc.on = false
    ST.jm.wasG, ST.jm.prevY = true, 0
    ST.js.air, ST.js.p0 = false, nil
    ST.wall.lastPos, ST.wall.untilT, ST.wall.on = nil, 0, false
    ST.lj.cd, ST.lj.ecd, ST.wj.cd = 0, 0, 0
    ST.imp.untilT = 0
end

local function stepRender()
    local char, root, hum = parts()
    resetState(root)
    if not char then
        ST.tb.active = false
        ST.bhop.on = false
        return
    end
    local vel = root.AssemblyLinearVelocity
    local g = onGround(vel)
    stepBhop(hum)
    stepStats(root, vel, g)
    stepJumps(root, vel, g)
    stepImpulse(root, g)
    stepEdgebug(root, vel, g)
    stepTextureBug(root, vel, g)
    stepHeadBounce(root, vel)
end

local function stepPhysics()
    local char, root = parts()
    if not char then
        ST.px.flying, ST.ws.stuck, ST.wc.on = false, false, false
        return
    end
    local vel = root.AssemblyLinearVelocity
    trackWall(root)
    stepPixelSurf(root)
    stepWallClimb(root, vel)
    stepWallStuck(root, vel)
end

local mv = UI:Tab("movement", "Movement")
local main = mv:Section("Main", "left")

local ebT = main:Toggle("Edge bug", true)
F.eb = { item = ebT.item, bind = ebT:AddKeybind('lshift', 'Hold') }
local pxT = main:Toggle("Pixel surf", true)
F.px = { item = pxT.item, bind = pxT:AddKeybind('c', 'Toggle') }
local tbT = main:Toggle("Texture bug", true)
F.tb = { item = tbT.item, bind = tbT:AddKeybind('x', 'Hold') }
local wsT = main:Toggle("Wall stuck", true)
F.ws = { item = wsT.item, bind = wsT:AddKeybind('v', 'Toggle') }
local wcT = main:Toggle("Wall climb", true)
F.wc = { item = wcT.item, bind = wcT:AddKeybind('f', 'Hold') }
local hbT = main:Toggle("Head bounce", true)
F.hb = { item = hbT.item, bind = hbT:AddKeybind('h', 'Hold') }
local ljT = main:Toggle("Long jump", true)
F.lj = { item = ljT.item, bind = ljT:AddKeybind('g', 'Hold') }
local ajT = main:Toggle("Air jump", true)
F.aj = { item = ajT.item, bind = ajT:AddKeybind('z', 'Hold') }
local mjT = main:Toggle("Mini jump", true)
F.mj = { item = mjT.item, bind = mjT:AddKeybind('n', 'Hold') }
local jbT = main:Toggle("Jump bug", true)
F.jb = { item = jbT.item, bind = jbT:AddKeybind('j', 'Hold') }
local wjT = main:Toggle("Wall jump", true)
F.wj = { item = wjT.item, bind = wjT:AddKeybind('r', 'Hold') }
local bhT = main:Toggle("Bunny hop", false)
F.bhop = { item = bhT.item }

local SHORT = { eb = 'eb', px = 'px', tb = 'tb', ws = 'ws', wc = 'wc', wall = 'wall', hb = 'hb',
                lj = 'lj', aj = 'aj', mj = 'mj', jb = 'jb', bhop = 'bhop', wj = 'wj' }
local ORDER = { 'wall', 'eb', 'px', 'tb', 'ws', 'wc', 'hb', 'lj', 'wj', 'aj', 'mj', 'jb' }
local IND = { bhop = function() return ST.bhop.on end,
              wc = function() return ST.wc.on end,
              wall = function() return ST.wall.on end }

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
