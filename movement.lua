local M = function(NX)

local UI = NX.UI
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CFG, ST = NX.CFG, NX.ST

do
    local c = {
    eb = { minfall = -5, arrest = -3, dur = 0.7, cd = 0.1, kick = 0.15,
           speed = 700, push = 6, glide = -1, steer = -0.05,
           holdground = true, eps = 1.5 },
    px = { minfall = 6, ratio = 0.3, eps = 0.02, drop = 7,
           hold = 5.0, dead = 0.05 },
    tb = { minfall = 6, ratio = 0.3, eps = 0.02, hold = 0.2,
           step = 0, carry = 1, cd = 0.7 },
    wall = { speed = 6, ratio = 0.5, grace = 0.25, decay = 0.5 },
    ws = { dead = 0.05 },
    wc = { up = 16, hop = 7, push = 2, cd = 0.25, hold = 0.08, max = 8 },
    hb = { vel = 8 },
    lj = { mult = 1.3, min = 18, max = 40, lift = 0, cd = 0.25, hold = 0.35,
           edgevel = 18, edgemax = 1, edgecd = 2 },
    aj = { vel = 18 },
    jm = { dwell = 0.08 },
    mj = { vel = 13 },
    jb = { vel = 22 },
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
    eb = { cd = 0, prevY = 0, sliding = false, until_ = 0, kickUntil = 0,
           oldSpeed = nil, oldAccl = nil },
    px = { active = false, startY = 0, py = nil, t = 0, untilT = 0 },
    tb = { active = false, startY = 0, vy = 0, py = nil, t = 0,
           untilT = 0, dx = 0, dz = 0, cd = 0 },
    ws = { stuck = false, pos = nil },
    wc = { on = false, cd = 0, uses = 0 },
    wall = { lastPos = nil, t = nil, disp = 0, untilT = 0, on = false,
             normal = nil, best = 0, cut = 0 },
    lj = { cd = 0, ecd = 0 },
    jm = { wasG = true, prevY = 0 },
    bhop = { on = false },
    g = { on = true, real = true, firm = true, since = nil },
    }
    for k, v in pairs(s) do ST[k] = v end
end

local F = {}
local parts, cue = NX.parts, NX.cue
local setHoriz, setY = NX.setHoriz, NX.setY
local impulse, stepImpulse = NX.impulse, NX.stepImpulse

local function onGround(vel, hum)
    local now = os.clock()
    local m = NX.floorGrounded(hum)

    if m ~= nil then
        ST.g.real = m
        ST.g.on = m
    else
        ST.g.real = false
        local e = CFG.eb.eps
        local was = ST.g.on
        local v = math.abs(vel.Y)
        if was then ST.g.on = v < e * 2 else ST.g.on = v < e end
    end

    if ST.g.on then
        if not ST.g.since then ST.g.since = now end
    else
        ST.g.since = nil
    end

    if ST.g.real then
        ST.g.firm = true
    elseif ST.g.since and (now - ST.g.since) >= CFG.jm.dwell then
        ST.g.firm = true
    else
        ST.g.firm = false
    end

    return ST.g.on
end
local function active(k)
    local f = F[k]
    if not f or not f.item.value then return false end
    if not f.bind then return true end
    return f.bind.active and true or false
end

local function pressed(k)
    local f = F[k]
    return f and f.item.value and f.bind and f.bind.key and UI:Clicked(f.bind.key)
end

local function camLook()
    local ok, cf = pcall(function() return workspace.CurrentCamera.CFrame end)
    if not ok or not cf then return nil end
    local l = cf.LookVector
    local f = Vector3.new(l.X, 0, l.Z)
    if f.Magnitude < 0.1 then return nil end
    return f.Unit
end

local function ebAttr(char, name, v)
    if type(v) ~= "number" then return end
    pcall(function() char:SetAttribute(name, v) end)
end

local function ebGet(char, name)
    local ok, v = pcall(function() return char:GetAttribute(name) end)
    if ok and type(v) == "number" then return v end
    return nil
end

local function ebRelease(char)
    if not ST.eb.sliding then return end
    ST.eb.sliding = false
    ST.eb.until_ = 0
    if char then
        ebAttr(char, "Speed", ST.eb.oldSpeed or 250)
        ebAttr(char, "Accl", ST.eb.oldAccl or 1)
    end
    ST.eb.oldSpeed, ST.eb.oldAccl = nil, nil
end

local function stepEdgebug(root, vel, hum, char)
    if not char then return end

    local now = os.clock()
    local prevY = ST.eb.prevY
    ST.eb.prevY = vel.Y

    if ST.eb.sliding then
        if now >= ST.eb.until_ or not active('eb') then
            ebRelease(char)
        else
            ebAttr(char, "Speed", CFG.eb.speed)
            if now < ST.eb.kickUntil then
                ebAttr(char, "Accl", CFG.eb.push)
            elseif UI:Held('w') or UI:Held('a') or UI:Held('s') or UI:Held('d') then
                ebAttr(char, "Accl", CFG.eb.steer)
            else
                ebAttr(char, "Accl", CFG.eb.glide)
            end
        end
        return
    end

    if not active('eb') then return end
    if now < ST.eb.cd then return end

    if prevY < CFG.eb.minfall and vel.Y > CFG.eb.arrest then
        ST.eb.oldSpeed = ebGet(char, "Speed") or 250
        ST.eb.oldAccl = ebGet(char, "Accl") or 1
        ST.eb.sliding = true
        ST.eb.until_ = now + CFG.eb.dur
        ST.eb.kickUntil = now + CFG.eb.kick
        ST.eb.cd = ST.eb.until_ + CFG.eb.cd
        ebAttr(char, "Speed", CFG.eb.speed)
        ebAttr(char, "Accl", CFG.eb.push)
        cue('edge bug')
    end
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

local function trackWall(root)
    local now = os.clock()
    local p = root.Position
    local last = ST.wall.lastPos
    local dt = (ST.wall.t and ST.wall.t > 0) and (now - ST.wall.t) or 0
    ST.wall.lastPos, ST.wall.t = p, now

    local want = camDir()
    local moving = want and want.Magnitude > 0.1

    if not last or dt <= 0 or dt > 0.1 or not moving then
        ST.wall.on = now < ST.wall.untilT
        if not ST.wall.on then ST.wall.normal = nil end
        return
    end

    local d = p - last
    local sp = Vector3.new(d.X, 0, d.Z).Magnitude / dt
    ST.wall.disp = sp

    local b = ST.wall.best or 0
    if sp > b then
        b = sp
    else
        local decay = dt * CFG.wall.decay
        if decay > 1 then decay = 1 end
        b = b + (sp - b) * decay
    end
    ST.wall.best = b

    local cut = b * CFG.wall.ratio
    if cut < CFG.wall.speed then cut = CFG.wall.speed end
    ST.wall.cut = cut

    if sp <= cut then
        ST.wall.untilT = now + CFG.wall.grace
        ST.wall.normal = Vector3.new(-want.X, 0, -want.Z)
    end

    ST.wall.on = now < ST.wall.untilT
    if not ST.wall.on then ST.wall.normal = nil end
end

local function wallOn() return ST.wall.on end

local function wallNormal()
    if not ST.wall.on then return nil end
    local n = ST.wall.normal
    if n and n.Magnitude > 0.1 then return n.Unit end
    return nil
end

local function stepBhop(hum)
    ST.bhop.on = false
    if ST.eb.sliding and CFG.eb.holdground then return end
    if not active('bhop') then return end
    if not UI:Held('space') then return end
    if not hum then return end
    if not NX.humAddr(hum) then return end

    local mat = NX.humGet(hum, 'FloorMaterial', "int", 384)
    if mat and mat > 0 then
        NX.humSet(hum, 'Jump', "byte", 1, 471)
        ST.bhop.on = true
    end
end

local function stepJumps(root, vel, grounded)
    local raw = vel.Y
    local prevY = ST.jm.prevY
    local firm = ST.g.firm
    local tookOff = (not firm) and ST.jm.wasG
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

    if pressed('aj') then
        setY(root, CFG.aj.vel)
        cue('air jump')
    end

    if rising and not didEdge then
        if active('mj') then
            setY(root, CFG.mj.vel)
            cue('mini jump')
        end
        if active('hb') then
            setY(root, CFG.hb.vel)
            cue('head bounce')
        end
        if active('jb') then
            setY(root, CFG.jb.vel)
            cue('jump bug')
        end
    end

    ST.jm.wasG = firm
    ST.jm.prevY = raw
end

local function stepPixelSurf(root, vel, g)
    local now = os.clock()
    local py = root.Position.Y
    local dt = now - (ST.px.t or now)
    local fell = (ST.px.py or py) - py
    ST.px.py, ST.px.t = py, now

    if not active('px') then ST.px.active = false return end

    if ST.px.active then
        if now >= ST.px.untilT then ST.px.active = false return end
        if math.abs(py - ST.px.startY) >= CFG.px.drop then ST.px.active = false return end
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
        if math.abs(py - ST.px.startY) > CFG.px.dead then
            pcall(function()
                local p = root.Position
                root.Position = Vector3.new(p.X, ST.px.startY, p.Z)
            end)
        end
        return
    end

    if g or dt <= 0 then return end
    if vel.Y > -CFG.px.minfall then return end

    local expect = -vel.Y * dt
    if expect < CFG.px.eps then return end

    if fell <= expect * CFG.px.ratio then
        ST.px.active = true
        ST.px.startY = py
        ST.px.untilT = now + CFG.px.hold
        cue('pixel surf')
    end
end

local function stepTextureBug(root, vel, g)
    local now = os.clock()
    local py = root.Position.Y
    local dt = now - (ST.tb.t or now)
    local fell = (ST.tb.py or py) - py
    ST.tb.py, ST.tb.t, ST.tb.vy = py, now, vel.Y

    if not active('tb') then ST.tb.active = false return end

    if ST.tb.active then
        if now >= ST.tb.untilT then ST.tb.active = false return end
        setHoriz(root, ST.tb.dx, ST.tb.dz)
        setY(root, CFG.tb.step)
        return
    end

    if g or dt <= 0 then return end
    if now < (ST.tb.cd or 0) then return end
    if vel.Y > -CFG.tb.minfall then return end

    local expect = -vel.Y * dt
    if expect < CFG.tb.eps then return end

    if fell <= expect * CFG.tb.ratio then
        local h = Vector3.new(vel.X, 0, vel.Z)
        local sp = h.Magnitude * CFG.tb.carry
        local dir = (h.Magnitude > 0.1) and h.Unit or nil
        ST.tb.dx = dir and dir.X * sp or 0
        ST.tb.dz = dir and dir.Z * sp or 0
        ST.tb.active = true
        ST.tb.startY = py
        ST.tb.untilT = now + CFG.tb.hold
        ST.tb.cd = ST.tb.untilT + CFG.tb.cd
        cue('texture bug')
    end
end

local function stepWallClimb(root, vel)
    ST.wc.on = false
    if ST.g.on then ST.wc.uses = 0 end
    if not active('wc') then return end
    if not wallOn() then ST.wc.uses = 0 return end

    local now = os.clock()
    if now < ST.wc.cd then return end
    if ST.wc.uses >= CFG.wc.max then return end

    local n = wallNormal()
    local into = n and Vector3.new(-n.X, 0, -n.Z) or camLook()
    if not into then return end

    local up = (ST.wc.uses == 0) and CFG.wc.up or CFG.wc.hop
    setY(root, up)
    impulse(root, into.X * CFG.wc.push, into.Z * CFG.wc.push, CFG.wc.hold)
    ST.wc.cd = now + CFG.wc.cd
    ST.wc.uses = ST.wc.uses + 1
    ST.wc.on = true
    cue('wall climb')
end

local function stepWallStuck(root, vel)
    if not active('ws') then ST.ws.stuck = false ST.ws.pos = nil return end
    if not ST.ws.stuck and not wallOn() then return end
    if not ST.ws.stuck then
        ST.ws.stuck = true
        ST.ws.pos = root.Position
    end
    local p = ST.ws.pos
    if not p then ST.ws.pos = root.Position return end

    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    local here = root.Position
    local dx, dy, dz = p.X - here.X, p.Y - here.Y, p.Z - here.Z
    if (dx * dx + dy * dy + dz * dz) > (CFG.ws.dead * CFG.ws.dead) then
        pcall(function() root.Position = p end)
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
    elseif g and ST.js.air then

        ST.js.air = false
    end
    ST.js.wasG = g
end

local function resetState(root)
    if ST.root == root then return end
    ST.root = root
    ST.eb.cd, ST.eb.prevY, ST.eb.sliding, ST.eb.until_ = 0, 0, false, 0
    ST.tb.active = false
    ST.ws.stuck, ST.ws.pos = false, nil
    ST.px.active = false
    ST.px.py, ST.px.untilT = nil, 0
    ST.wc.on, ST.wc.cd, ST.wc.uses = false, 0, 0
    ST.jm.wasG, ST.jm.prevY = true, 0
    ST.js.air, ST.js.p0 = false, nil
    ST.wall.lastPos, ST.wall.untilT, ST.wall.on = nil, 0, false
    ST.wall.normal, ST.wall.t, ST.wall.best = nil, nil, 0
    ST.tb.py, ST.tb.untilT, ST.tb.cd = nil, 0, 0
    ST.lj.cd, ST.lj.ecd = 0, 0
    ST.imp.untilT = 0
end

local SHORT = { eb = 'eb', px = 'px', tb = 'tb', ws = 'ws', wc = 'wc', wall = 'wall', hb = 'hb',
                lj = 'lj', aj = 'aj', mj = 'mj', jb = 'jb', bhop = 'bhop' }
local ORDER = { 'wall', 'eb', 'px', 'tb', 'ws', 'wc', 'hb', 'lj', 'aj', 'mj', 'jb' }
local IND = { bhop = function() return ST.bhop.on end,
              px = function() return ST.px.active end,
              tb = function() return ST.tb.active end,
              wc = function() return ST.wc.on end,
              wall = function() return ST.wall.on end }

local function stepRender()
    local char, root, hum = parts()
    resetState(root)
    if not char then
        ST.tb.active = false
        ST.bhop.on = false
        ST.eb.sliding = false
        ST.eb.oldSpeed, ST.eb.oldAccl = nil, nil
        return
    end
    local vel = root.AssemblyLinearVelocity
    local g = onGround(vel, hum)
    stepBhop(hum)
    stepStats(root, vel, g)
    stepJumps(root, vel, g)
    stepImpulse(root, g)
    stepEdgebug(root, vel, hum, char)
    stepPixelSurf(root, vel, g)
    stepTextureBug(root, vel, g)
end

local function stepPhysics()
    local char, root = parts()
    if not char then
        ST.px.active, ST.ws.stuck, ST.wc.on = false, false, false
        return
    end
    local vel = root.AssemblyLinearVelocity
    trackWall(root)
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
local bhT = main:Toggle("Bunny hop", false)
F.bhop = { item = bhT.item }

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
