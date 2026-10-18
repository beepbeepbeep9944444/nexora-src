local Players = game:GetService("Players")

local UI = {
    w = 500, h = 520, x = 0, y = 0, scale = 1,
    title = "nexora", ver = "1.0",

    theme = {
        shadow   = Color3.fromRGB(0, 0, 0),
        panel    = Color3.fromRGB(0, 0, 0),
        side     = Color3.fromRGB(0, 0, 0),
        card     = Color3.fromRGB(0, 0, 0),
        card_hi  = Color3.fromRGB(14, 14, 14),
        border   = Color3.fromRGB(42, 42, 42),
        track    = Color3.fromRGB(26, 26, 26),
        text     = Color3.fromRGB(255, 255, 255),
        dim      = Color3.fromRGB(128, 128, 128),
        head     = Color3.fromRGB(96, 96, 96),
        accent   = Color3.fromRGB(255, 255, 255),
        accent2  = Color3.fromRGB(200, 200, 200),
    },
    hue = 0.72,
    mono = true,

    font = Drawing.Fonts.UI,
    font_bold = Drawing.Fonts.UI,
    font_ind = Drawing.Fonts.System,
    font_ind_bold = Drawing.Fonts.SystemBold,
    font_mono = Drawing.Fonts.Monospace,
    fs = 13, fs_sm = 13, fs_lg = 13,

    _draw = {}, _used = {}, _anim = {}, _groups = {}, _order = {},
    _tab = nil, _open = true, _a = 0, _scroll = { left = 0, right = 0 },
    _drag = nil, _slider = nil, _dd = nil, _listen = nil, _scrollbar = nil, _focus = nil,
    _menu_key = 'rshift', _last = os.clock(), _running = false, _fps = 0,
}

local function rbx_active()
    local ok, v = pcall(function() return isrbxactive() end)
    if not ok then return true end
    return v and true or false
end
local function set_input(v) pcall(function() setrobloxinput(v) end) end

local function lerp(a, b, t) return a + (b - a) * t end
local function lerpc(a, b, t)
    return Color3.new(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t))
end
local function low(s) return tostring(s):lower() end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

local function toHSV(c)
    local r, g, b = c.R, c.G, c.B
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, (mx > 0) and (d / mx) or 0, mx
end

local function snap(v, step)
    v = math.floor(v / step + 0.5) * step
    local s = tostring(step)

    local dot = s:find(".", 1, true)
    local dec = dot and (#s - dot) or 0
    if dec > 6 then dec = 6 end
    local m = 10 ^ dec
    return math.floor(v * m + 0.5) / m
end

local KEYS = {
    m1 = 0x01, m2 = 0x02, backspace = 0x08, tab = 0x09, enter = 0x0D, shift = 0x10, ctrl = 0x11,
    alt = 0x12, esc = 0x1B, space = 0x20, ['end'] = 0x23, home = 0x24,
    left = 0x25, up = 0x26, right = 0x27, down = 0x28, insert = 0x2D,
    delete = 0x2E, lshift = 0xA0, rshift = 0xA1, lctrl = 0xA2, rctrl = 0xA3,
    lalt = 0xA4, ralt = 0xA5,
}
for i = 0, 9 do KEYS[tostring(i)] = 0x30 + i end
for i = 0, 25 do KEYS[string.char(97 + i)] = 0x41 + i end
for i = 1, 12 do KEYS['f' .. i] = 0x6F + i end

UI._in = {}
for n, id in pairs(KEYS) do UI._in[n] = { id = id, held = false, click = false } end

function UI:Held(k) local s = self._in[k] return s and s.held or false end
function UI:Clicked(k) local s = self._in[k] return s and s.click or false end

function UI:_Poll()
    local active = rbx_active()
    for _, s in pairs(self._in) do
        local down = active and iskeypressed(s.id) and true or false
        s.click = down and not s.held
        s.held = down
    end
end

function UI:Mouse()
    local p = Players.LocalPlayer
    local m = p and p:GetMouse()
    if m then return Vector2.new(m.X, m.Y) end
    return Vector2.new(0, 0)
end

function UI:In(p, s)
    local m = self:Mouse()
    return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
end

function UI:Anim(id, target, speed)
    local cur = self._anim[id]
    if cur == nil then cur = target end
    cur = cur + (target - cur) * clamp(self._dt * (speed or 14), 0, 1)
    self._anim[id] = cur
    return cur
end

function UI:_Sq(id, p, s, c, z, filled, a)
    self._used[id] = true
    local d = self._draw[id]
    if not d then d = Drawing.new('Square') self._draw[id] = d end
    d.Position, d.Size, d.Color = p, s, c
    d.Filled = filled ~= false
    if filled == false then pcall(function() d.Thickness = 1 end) end
    d.ZIndex, d.Transparency, d.Visible = z, (a or 1) * self._a, true
end

function UI:_Ci(id, c, r, col, z, a, filled)
    self._used[id] = true
    local d = self._draw[id]
    if not d then d = Drawing.new('Circle') self._draw[id] = d end
    d.Position, d.Radius, d.Color = c, math.max(r, 0.1), col
    d.Filled, d.NumSides = filled ~= false, 28
    d.ZIndex, d.Transparency, d.Visible = z, (a or 1) * self._a, true
end

function UI:_Tx(id, p, text, c, z, size, center, bold, a, face)
    self._used[id] = true
    local d = self._draw[id]
    if not d then d = Drawing.new('Text') self._draw[id] = d end
    d.Position, d.Text, d.Color = p, text, c
    d.Font = face or (bold and self.font_bold or self.font)
    d.Center, d.Outline = center or false, false
    pcall(function() d.FontSize = size end)
    pcall(function() d.Size = size end)
    d.ZIndex, d.Transparency, d.Visible = z, (a or 1) * self._a, true
end

function UI:_Tri(id, a1, b1, c1, col, z, a)
    self._used[id] = true
    local d = self._draw[id]
    if not d then d = Drawing.new('Triangle') self._draw[id] = d end
    d.PointA, d.PointB, d.PointC, d.Color, d.Filled = a1, b1, c1, col, true
    d.ZIndex, d.Transparency, d.Visible = z, (a or 1) * self._a, true
end

function UI:_Round(id, p, s, c, z, r, a)
    if s.X <= 0 or s.Y <= 0 then self:_Hide(id) return end
    r = math.min(r, s.X / 2, s.Y / 2)
    self:_Sq(id .. 'a', Vector2.new(p.X + r, p.Y), Vector2.new(s.X - r * 2, s.Y), c, z, true, a)
    self:_Sq(id .. 'b', Vector2.new(p.X, p.Y + r), Vector2.new(s.X, s.Y - r * 2), c, z, true, a)
    self:_Ci(id .. 'c1', Vector2.new(p.X + r, p.Y + r), r, c, z, a)
    self:_Ci(id .. 'c2', Vector2.new(p.X + s.X - r, p.Y + r), r, c, z, a)
    self:_Ci(id .. 'c3', Vector2.new(p.X + r, p.Y + s.Y - r), r, c, z, a)
    self:_Ci(id .. 'c4', Vector2.new(p.X + s.X - r, p.Y + s.Y - r), r, c, z, a)
end

function UI:_Hide(prefix)
    for id, d in pairs(self._draw) do
        if id:sub(1, #prefix) == prefix and id:sub(1, 2) ~= 'wm' then d.Visible = false end
    end
end

function UI:_Grad(id, p, s, c1, c2, z, bands, a)
    bands = bands or 14
    for i = 1, bands do
        local t = (i - 1) / (bands - 1)
        self:_Sq(id .. i, Vector2.new(p.X, p.Y + s.Y * (i - 1) / bands),
                 Vector2.new(s.X, s.Y / bands + 1), lerpc(c1, c2, t), z, true, a)
    end
end

function UI:SetAccent(h)
    self.hue = h % 1
    if self.mono then return end
    self.theme.accent = Color3.fromHSV(self.hue, 0.58, 1)
    self.theme.accent2 = Color3.fromHSV((self.hue + 0.12) % 1, 0.62, 1)
end

function UI:Tab(groupName, tabName)
    groupName, tabName = low(groupName), low(tabName)
    if not self._groups[groupName] then
        self._groups[groupName] = { name = groupName, tabs = {}, order = {} }
        table.insert(self._order, groupName)
    end
    local g = self._groups[groupName]
    local tab = { name = tabName, group = groupName, sections = {} }
    g.tabs[tabName] = tab
    table.insert(g.order, tabName)
    if not self._tab then self._tab = tab end

    local api = {}
    function api:Section(title, side)
        local sec = { title = low(title), side = side or 'left', items = {} }
        table.insert(tab.sections, sec)
        local s = {}
        local function add(i)
            if i.label then i.label = low(i.label) end
            table.insert(sec.items, i)
            return i
        end
        function s:Toggle(label, value, cb)
            local item = add({ kind = 'toggle', label = label, value = value or false, cb = cb })
            local h = { item = item }
            function h:Set(v) item.value = v if cb then cb(v) end end
            function h:AddKeybind(key, mode)
                item.bind = { key = key, mode = mode or 'Hold', toggled = false, active = false }
                return item.bind
            end
            return h
        end
        function s:Slider(label, value, step, min, max, suffix, cb)
            local item = add({ kind = 'slider', label = label, value = value, step = step,
                               min = min, max = max, suffix = suffix or '', cb = cb })
            return { item = item, Set = function(_, v) item.value = v if cb then cb(v) end end }
        end
        function s:Dropdown(label, value, choices, cb)
            local item = add({ kind = 'dropdown', label = label, value = value, choices = choices, cb = cb })
            return { item = item, Set = function(_, v) item.value = v if cb then cb(v) end end }
        end
        function s:Button(label, cb) return add({ kind = 'button', label = label, cb = cb }) end
        function s:Textbox(value, placeholder, cb)
            local item = add({ kind = 'textbox', value = value or '', placeholder = placeholder, cb = cb })
            return { item = item, Set = function(_, v) item.value = v if cb then cb(v) end end,
                     Get = function() return item.value end }
        end
        function s:Colour(label, value, cb)
            local h, sa, va = toHSV(value)
            local item = add({ kind = 'colour', label = label, value = value,
                               h = h, s = sa, v = va, cb = cb })
            return { item = item, Set = function(_, v)
                item.value = v
                item.h, item.s, item.v = toHSV(v)
                if cb then cb(v) end
            end }
        end
        function s:Label(text) return add({ kind = 'label', label = text }) end
        return s
    end
    return api
end

function UI:_Tabs(click)
    local t, S = self.theme, self.scale
    local x, y, w = self.x, self.y, self.w * S
    local hh = 30 * S

    self:_Tx('ttl', Vector2.new(x + 10 * S, y + 8 * S), self.title, t.text, 6, self.fs * S)

    local flat = {}
    for _, gname in ipairs(self._order) do
        local g = self._groups[gname]
        if g then
            for _, tname in ipairs(g.order) do
                table.insert(flat, { tab = g.tabs[tname], name = tname })
            end
        end
    end

    local gap = 14 * S
    local total = 0
    for _, f in ipairs(flat) do total = total + #f.name * 6 * S + gap end
    local tx = x + w - total - 2 * S

    for i, f in ipairs(flat) do
        local tw = #f.name * 6 * S
        local pos = Vector2.new(tx, y + 8 * S)
        local size = Vector2.new(tw + gap, 14 * S)
        local hov = self:In(Vector2.new(pos.X - gap / 2, y), Vector2.new(size.X, hh))
        local sel = self._tab == f.tab

        self:_Tx('tb' .. i, pos, f.name, sel and t.text or (hov and t.dim or t.head), 7, self.fs * S)
        if sel then
            self:_Sq('tbu' .. i, Vector2.new(pos.X - 1, y + hh - 4 * S),
                     Vector2.new(tw + 2 * S, 1), t.accent, 8)
        else
            self:_Hide('tbu' .. i)
        end

        if hov and click then
            self._tab = f.tab
            self._dd = nil
            self._scroll.left, self._scroll.right = 0, 0
            click = false
        end
        tx = tx + tw + gap
    end

    self:_Sq('hdl', Vector2.new(x, y + hh), Vector2.new(w, 1), t.border, 6)
    return click
end

function UI:_Item(id, item, pos, width, click, rclick, vis)
    local t, S = self.theme, self.scale
    local fs = self.fs * S

    if not vis then
        self:_Hide(id)
        if item.kind == 'toggle' or item.kind == 'colour' then return 17 * S, click
        elseif item.kind == 'slider' or item.kind == 'dropdown' then return 30 * S, click
        elseif item.kind == 'textbox' then return 24 * S, click
        elseif item.kind == 'button' then return 17 * S, click end
        return 16 * S, click
    end

    if item.kind == 'label' then
        self:_Tx(id .. 'l', pos, item.label, t.dim, 14, fs)
        return 16 * S, click

    elseif item.kind == 'toggle' then
        local rowh = 17 * S
        local bx = 9 * S
        local bp = Vector2.new(pos.X, pos.Y + 3 * S)
        local hov = self:In(Vector2.new(pos.X, pos.Y), Vector2.new(width, rowh))
        local on = item.value

        self:_Sq(id .. 'br', bp, Vector2.new(bx, bx), hov and t.dim or t.border, 14, false)
        if on then
            self:_Sq(id .. 'f', Vector2.new(bp.X + 2, bp.Y + 2),
                     Vector2.new(bx - 4, bx - 4), t.accent, 15)
        else
            self:_Hide(id .. 'f')
        end

        self:_Tx(id .. 'l', Vector2.new(pos.X + 15 * S, pos.Y + 1 * S), item.label,
                 on and t.text or t.dim, 15, fs)

        if hov and click and not item.bind then
            item.value = not item.value
            if item.cb then item.cb(item.value) end
            click = false
        end

        if item.bind then
            local label = '[' .. ((self._listen == id) and '...' or (item.bind.key or 'none')) .. ']'
            local lw = #label * 6 * S
            local cp = Vector2.new(pos.X + width - lw, pos.Y + 1 * S)
            local chov = self:In(Vector2.new(cp.X - 4 * S, pos.Y), Vector2.new(lw + 8 * S, rowh))
            self:_Tx(id .. 'ck', cp, label, chov and t.text or t.head, 15, fs)

            if chov then
                if click then self._listen = id click = false
                elseif rclick then
                    self._dd = { pos = self:Mouse(), w = 70 * S, choices = { 'hold', 'toggle', 'always' },
                                 pick = function(v)
                                     item.bind.mode = v:sub(1, 1):upper() .. v:sub(2)
                                     item.bind.toggled = false
                                 end }
                end
            elseif hov and click then
                item.value = not item.value
                if item.cb then item.cb(item.value) end
                click = false
            end

            if self._listen == id then
                for n, s in pairs(self._in) do
                    if s.click and n ~= 'm1' then
                        item.bind.key = (n ~= 'esc') and n or nil
                        self._listen = nil
                        break
                    end
                end
            end
        end
        return rowh, click

    elseif item.kind == 'colour' then
        local rowh = 17 * S
        local sw, sh = 18 * S, 9 * S
        local sp = Vector2.new(pos.X + width - sw, pos.Y + 3 * S)
        local hov = self:In(Vector2.new(pos.X, pos.Y), Vector2.new(width, rowh))
        self:_Tx(id .. 'l', Vector2.new(pos.X, pos.Y + 1 * S), item.label,
                 hov and t.text or t.dim, 15, fs)
        self:_Sq(id .. 'sw', sp, Vector2.new(sw, sh), item.value, 15)
        self:_Sq(id .. 'so', sp, Vector2.new(sw, sh), hov and t.text or t.border, 16, false)
        if self:In(sp, Vector2.new(sw, sh)) and click then
            self._cp = { item = item, pos = Vector2.new(sp.X + sw - 108 * S, sp.Y + sh + 3 * S) }
            click = false
        end
        return rowh, click

    elseif item.kind == 'slider' then
        local rowh = 30 * S
        local bh = 11 * S
        local bp = Vector2.new(pos.X, pos.Y + 14 * S)
        local bs = Vector2.new(width, bh)
        local grabbed = self._slider == id
        local pct = clamp((item.value - item.min) / (item.max - item.min), 0, 1)
        local shown = self:Anim(id .. 'p', pct, 22)

        self:_Tx(id .. 'l', Vector2.new(pos.X, pos.Y), item.label, t.dim, 14, fs)
        self:_Sq(id .. 'tr', bp, bs, t.track, 14)
        self:_Sq(id .. 'fl', bp, Vector2.new(bs.X * shown, bh), t.accent, 15)
        self:_Sq(id .. 'br', bp, bs, t.border, 16, false)
        self:_Tx(id .. 'v', Vector2.new(bp.X + bs.X / 2, bp.Y + bs.Y / 2),
                 tostring(item.value) .. item.suffix,
                 shown > 0.5 and t.panel or t.text, 17, fs, true)

        if self:In(bp, bs) and click then self._slider = id click = false end
        if grabbed then
            if self:Held('m1') then
                local p = clamp((self:Mouse().X - bp.X) / bs.X, 0, 1)
                local v = item.min + (item.max - item.min) * p
                v = snap(v, item.step)
                if v ~= item.value then item.value = v if item.cb then item.cb(v) end end
            else
                self._slider = nil
            end
        end
        return rowh, click

    elseif item.kind == 'dropdown' then
        local rowh = 30 * S
        local bp = Vector2.new(pos.X, pos.Y + 13 * S)
        local bs = Vector2.new(width, 15 * S)
        local hov = self:In(bp, bs)
        self:_Tx(id .. 'l', Vector2.new(pos.X, pos.Y), item.label, t.dim, 14, fs)
        self:_Sq(id .. 'b', bp, bs, t.card_hi, 14)
        self:_Sq(id .. 'br', bp, bs, hov and t.dim or t.border, 15, false)
        self:_Tx(id .. 'v', Vector2.new(bp.X + 5 * S, bp.Y + (bs.Y - fs) / 2),
                 low(item.value), t.text, 16, fs)
        local ax, ay = bp.X + bs.X - 9 * S, bp.Y + bs.Y / 2
        self:_Tri(id .. 'ar', Vector2.new(ax - 3 * S, ay - 1.5 * S),
                  Vector2.new(ax + 3 * S, ay - 1.5 * S), Vector2.new(ax, ay + 2.5 * S), t.dim, 16)
        if hov and click then
            self._dd = { pos = Vector2.new(bp.X, bp.Y + bs.Y + 1), w = bs.X, choices = item.choices,
                         pick = function(v) item.value = v if item.cb then item.cb(v) end end }
            click = false
        end
        return rowh, click

    elseif item.kind == 'button' then
        local rowh = 17 * S
        local hov = self:In(Vector2.new(pos.X, pos.Y), Vector2.new(width, rowh))
        self:_Tx(id .. 't', Vector2.new(pos.X, pos.Y + 1 * S), item.label,
                 hov and t.text or t.dim, 15, fs)
        if hov then
            self:_Sq(id .. 'u', Vector2.new(pos.X, pos.Y + 14 * S),
                     Vector2.new(#item.label * 6 * S, 1), t.accent, 15)
        else
            self:_Hide(id .. 'u')
        end
        if hov and click then if item.cb then item.cb() end click = false end
        return rowh, click

    elseif item.kind == 'textbox' then
        local rowh = 24 * S
        local bs = Vector2.new(width, 17 * S)
        local hov = self:In(pos, bs)
        local foc = self._focus == id
        self:_Sq(id .. 'b', pos, bs, t.card_hi, 14)
        self:_Sq(id .. 'br', pos, bs, foc and t.accent or (hov and t.dim or t.border), 15, false)
        local shown = item.value
        if shown == '' and not foc then shown = item.placeholder or '' end
        local caret = (foc and math.floor(os.clock() * 2) % 2 == 0) and '|' or ''
        self:_Tx(id .. 't', Vector2.new(pos.X + 5 * S, pos.Y + 2 * S), shown .. caret,
                 (item.value ~= '' or foc) and t.text or t.head, 16, fs)
        if click then
            if hov then self._focus = id click = false
            elseif foc then self._focus = nil end
        end
        if foc then
            local shift = self:Held('lshift') or self:Held('rshift')
            for n, st in pairs(self._in) do
                if st.click then
                    if n == 'backspace' or n == 'delete' then
                        item.value = item.value:sub(1, -2)
                    elseif n == 'enter' then
                        self._focus = nil
                        if item.cb then item.cb(item.value) end
                    elseif n == 'space' then
                        item.value = item.value .. ' '
                    elseif n == 'minus' then
                        item.value = item.value .. (shift and '_' or '-')
                    elseif #n == 1 then
                        item.value = item.value .. (shift and n:upper() or n)
                    end
                end
            end
        end
        return rowh, click
    end
    return 0, click
end

function UI:_Panel(click, rclick)
    local t, S = self.theme, self.scale
    local px, py = self.x, self.y
    local pw, ph = self.w * S, self.h * S

    self:_Sq('mn', Vector2.new(px, py), Vector2.new(pw, ph), t.panel, 2)
    self:_Sq('mnb', Vector2.new(px, py), Vector2.new(pw, ph), t.border, 3, false)
    if not self._tab then return click end

    local pad = 9 * S
    local top = py + 40 * S
    local bottom = py + ph - 8 * S
    local colw = (pw - pad * 3) / 2
    local cur = { left = top - self._scroll.left, right = top - self._scroll.right }
    local maxb = { left = top, right = top }
    local n = 0

    for _, sec in ipairs(self._tab.sections) do
        n = n + 1
        local side = (sec.side == 'right') and 'right' or 'left'
        local sx = px + pad + (side == 'right' and (colw + pad) or 0)
        local sy = cur[side]
        local sid = 'pn' .. n

        local iy = sy + 22 * S
        for i, item in ipairs(sec.items) do
            local vis = iy > top - 40 * S and iy < bottom
            local ih, c = self:_Item(sid .. 'i' .. i, item,
                Vector2.new(sx + 8 * S, iy), colw - 16 * S, click, rclick, vis)
            click = c
            iy = iy + ih
        end
        local sh = (iy - sy) + 8 * S

        if sy + sh > top - 20 * S and sy < bottom then
            self:_Sq(sid .. 'bg', Vector2.new(sx, sy), Vector2.new(colw, sh), t.card, 10)
            self:_Sq(sid .. 'br', Vector2.new(sx, sy), Vector2.new(colw, sh), t.border, 11, false)
            self:_Tx(sid .. 't', Vector2.new(sx + 8 * S, sy + 4 * S), sec.title, t.text, 12, self.fs * S)
        else
            self:_Hide(sid .. 'bg') self:_Hide(sid .. 'br') self:_Hide(sid .. 't')
        end

        cur[side] = sy + sh + 8 * S
        maxb[side] = cur[side] + self._scroll[side]
    end

    for _, side in ipairs({ 'left', 'right' }) do
        local content = maxb[side] - top
        local view = bottom - top
        if content > view then
            local over = content - view
            self._scroll[side] = clamp(self._scroll[side], 0, over)
            local bx = px + pad + (side == 'right' and (colw + pad) or 0) + colw - 2 * S
            local frac = view / content
            local bh = math.max(20 * S, view * frac)
            local bt = top + (view - bh) * (self._scroll[side] / over)
            self:_Sq('sb' .. side, Vector2.new(bx, bt), Vector2.new(2 * S, bh), t.border, 20)
            if self:In(Vector2.new(bx - 5, bt), Vector2.new(12 * S, bh)) and click then
                self._scrollbar = { side = side, grab = self:Mouse().Y - bt, over = over, view = view, bh = bh, top = top }
                click = false
            end
        else
            self._scroll[side] = 0
            self:_Hide('sb' .. side)
        end
    end

    if self._scrollbar then
        if self:Held('m1') then
            local s = self._scrollbar
            local bt = clamp(self:Mouse().Y - s.grab, s.top, s.top + s.view - s.bh)
            self._scroll[s.side] = ((bt - s.top) / (s.view - s.bh)) * s.over
        else
            self._scrollbar = nil
        end
    end
    return click
end

function UI:_Picker(click)
    local c = self._cp
    if not c then self:_Hide('cp') return click end
    local t, S = self.theme, self.scale
    local it = c.item
    local sq = 90 * S
    local strip = 12 * S
    local pad = 5 * S
    local w = pad * 3 + sq + strip
    local h = pad * 2 + sq
    local p = c.pos

    self:_Sq('cpbg', p, Vector2.new(w, h), t.panel, 70)
    self:_Sq('cpbr', p, Vector2.new(w, h), t.border, 71, false)

    local sv = Vector2.new(p.X + pad, p.Y + pad)
    local cells = 12
    for a = 1, cells do
        for b = 1, cells do
            self:_Sq('cps' .. a .. '_' .. b,
                     Vector2.new(sv.X + (a - 1) * sq / cells, sv.Y + (b - 1) * sq / cells),
                     Vector2.new(sq / cells + 1, sq / cells + 1),
                     Color3.fromHSV(it.h, (a - 0.5) / cells, 1 - (b - 0.5) / cells), 72)
        end
    end
    self:_Ci('cpk', Vector2.new(sv.X + it.s * sq, sv.Y + (1 - it.v) * sq), 3 * S,
             Color3.fromRGB(255, 255, 255), 74, 1, false)

    local hx = p.X + pad * 2 + sq
    for i = 1, 24 do
        self:_Sq('cph' .. i, Vector2.new(hx, sv.Y + (i - 1) * sq / 24),
                 Vector2.new(strip, sq / 24 + 1), Color3.fromHSV((i - 0.5) / 24, 1, 1), 72)
    end
    self:_Sq('cphk', Vector2.new(hx - 2 * S, sv.Y + it.h * sq - 1),
             Vector2.new(strip + 4 * S, 2), Color3.fromRGB(255, 255, 255), 74)

    local function commit()
        it.value = Color3.fromHSV(it.h, it.s, it.v)
        if it.cb then it.cb(it.value) end
    end

    if self:Held('m1') then
        if self._cpdrag == 'sv' or (click and self:In(sv, Vector2.new(sq, sq))) then
            self._cpdrag = 'sv'
            local m = self:Mouse()
            it.s = clamp((m.X - sv.X) / sq, 0, 1)
            it.v = 1 - clamp((m.Y - sv.Y) / sq, 0, 1)
            commit()
            click = false
        elseif self._cpdrag == 'hue' or (click and self:In(Vector2.new(hx, sv.Y), Vector2.new(strip, sq))) then
            self._cpdrag = 'hue'
            local m = self:Mouse()
            it.h = clamp((m.Y - sv.Y) / sq, 0, 0.999)
            commit()
            click = false
        end
    else
        self._cpdrag = nil
    end

    if click and not self:In(p, Vector2.new(w, h)) then
        self._cp = nil
        self:_Hide('cp')
    end
    return click
end

function UI:_Drop(click)
    local d = self._dd
    if not d then self:_Hide('dd') return click end
    local t, S = self.theme, self.scale
    local rh = 15 * S
    local size = Vector2.new(d.w, #d.choices * rh + 4 * S)
    self:_Sq('ddbg', d.pos, size, t.card_hi, 60)
    self:_Sq('ddbr', d.pos, size, t.border, 61, false)
    local close = false
    for i, c in ipairs(d.choices) do
        local rp = Vector2.new(d.pos.X + 2 * S, d.pos.Y + 2 * S + (i - 1) * rh)
        local rs = Vector2.new(d.w - 4 * S, rh)
        local hov = self:In(rp, rs)
        self:_Tx('ddc' .. i, Vector2.new(rp.X + 3 * S, rp.Y + 1 * S), low(c),
                 hov and t.text or t.dim, 62, self.fs * S)
        if hov and click then d.pick(c) close = true click = false end
    end
    if click and not self:In(d.pos, size) then close = true end
    if close then self._dd = nil self:_Hide('dd') end
    return click
end

function UI:_Binds()
    for _, gname in ipairs(self._order) do
        local g = self._groups[gname]
        for _, tname in ipairs(g.order) do
            for _, sec in ipairs(g.tabs[tname].sections) do
                for _, item in ipairs(sec.items) do
                    local b = item.bind
                    if b then
                        if not item.value or not b.key then
                            b.active, b.toggled = false, false
                        elseif b.mode == 'Always' then
                            b.active = true
                        elseif b.mode == 'Toggle' then
                            if self:Clicked(b.key) then b.toggled = not b.toggled end
                            b.active = b.toggled
                        else
                            b.active = self:Held(b.key)
                        end
                    end
                end
            end
        end
    end
end

function UI:_Sweep()
    for id, d in pairs(self._draw) do
        if not self._used[id] then d.Visible = false end
    end
    self._used = {}
end

function UI:_Watermark()
    local t = self.theme
    local keep = self._a
    self._a = 1

    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)

    local dt = self._dt or 0
    if dt > 0 then
        local inst = 1 / dt
        self._fps = (self._fps > 0) and (self._fps + (inst - self._fps) * 0.08) or inst
    end

    local fs = 14
    local function wide(s) return #s * fs * 0.5 end

    local name = self.title
    local segs = { tostring(math.floor(self._fps + 0.5)) .. ' fps', 'v' .. self.ver }

    local pad, gap, r = 7, 9, 5
    local h = 25
    local chipW = wide(name) + 14
    local w = pad + chipW + gap
    for _, s in ipairs(segs) do w = w + wide(s) + gap end
    w = w - gap + pad

    local x = vp.X - w - 16
    local y = 16

    self:_Round('wmbr', Vector2.new(x - 1, y - 1), Vector2.new(w + 2, h + 2), t.border, 900, r + 1)
    self:_Round('wmbg', Vector2.new(x, y), Vector2.new(w, h), t.panel, 901, r)

    local ty = y + h / 2 - fs / 2
    local cx = x + pad

    self:_Round('wmchip', Vector2.new(cx, y + 4), Vector2.new(chipW, h - 8), t.card_hi, 902, 3)
    self:_Tx('wmn', Vector2.new(cx + (chipW - wide(name)) / 2, ty), name,
             t.text, 903, fs, false, false, nil, self.font_ind)
    cx = cx + chipW

    for i, s in ipairs(segs) do
        self:_Sq('wmsep' .. i, Vector2.new(cx + gap / 2, y + 6), Vector2.new(1, h - 12), t.border, 903)
        cx = cx + gap
        self:_Tx('wms' .. i, Vector2.new(cx, ty), s,
                 (i == 1) and t.text or t.dim, 903, fs, false, false, nil, self.font_ind)
        cx = cx + wide(s)
    end

    self._a = keep
end
function UI:Step()
    local now = os.clock()
    self._dt = now - self._last
    self._last = now
    self:_Poll()
    set_input(not self._open)
    if self:Clicked(self._menu_key) then self._open = not self._open self._dd = nil end

    self:_Binds()
    self._a = self:Anim('alpha', self._open and 1 or 0, 13)
    if self._a <= 0.02 then
        self:_Watermark()
        return
    end
    self:_Watermark()

    local click, rclick = self:Clicked('m1'), self:Clicked('m2')

    click = self:_Picker(click)
    click = self:_Drop(click)
    click = self:_Tabs(click)

    if self:Held('m1') then
        if self._drag then
            local m = self:Mouse()
            self.x, self.y = m.X - self._drag.X, m.Y - self._drag.Y
        elseif click and self:In(Vector2.new(self.x, self.y),
                                 Vector2.new(self.w * self.scale, 30 * self.scale)) then
            local m = self:Mouse()
            self._drag = Vector2.new(m.X - self.x, m.Y - self.y)
            click = false
        end
    else
        self._drag = nil
    end

    click = self:_Panel(click, rclick)
end

function UI:Center()
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    self.x = vp.X / 2 - (self.w * self.scale) / 2
    self.y = vp.Y / 2 - (self.h * self.scale) / 2
end

function UI:Unload()
    for _, d in pairs(self._draw) do pcall(function() d:Remove() end) end
    self._draw = {}
    set_input(true)
end

function UI:Run()
    self:SetAccent(self.hue)
    self:Center()
    self._running = true
    while self._running do
        local ok, err = pcall(function() self:Step() end)
        if not ok then warn('[ui] ' .. tostring(err)) end
        task.wait()
    end
    self:Unload()
end

function UI:Stop() self._running = false end

local ENV0 = (getfenv and getfenv()) or _G
if ENV0.NEXORA_CORE and ENV0.NEXORA_CORE.stop then
    pcall(ENV0.NEXORA_CORE.stop)
end

local NX = { UI = UI }
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

NX.placeId = 0
pcall(function() NX.placeId = game.PlaceId end)
NX.gameName = "unknown"
function NX.placeConfig() return "place_" .. tostring(NX.placeId) end

local CFG = {
    ind = {

        vel = true, prespeed = true, binds = true, graph = false,
        cues = true, keys = true, cue_size = 19,

        key_pos_x = 0.5, key_pos_y = 0.88,
        key_size = 22, key_gap = 1.1, key_rows = 1.1,

        bind_pos  = 0.70,
        bind_size = 22,
        spacing   = 4,
        det_max   = 0.75,
        det_hold  = 0.25,

        vel_pos  = 0.62,
        vel_size = 30,
        vel_max  = 520,

        anim = true,

        graph_yoff = 500, graph_rate = 0.06, graph_marks = true,
        cue_time = 1.1, cue_rise = 26, cue_yoff = 0.42,
    },
}

local ST = {
    imp = { untilT = 0, x = 0, z = 0, ground = false },
    js = { air = false, wasG = true, t0 = 0, p0 = nil, sp0 = 0, peak = 0, last = nil },
    cue = {},
    root = nil,
    graph = {}, gmark = {}, gn = 0, gt = 0, disp = 0, last = 0,
    ix = { lbl = {}, va = 0, vy = 0, vc = 0, pre = 0, prea = 0 },
    order = {}, short = {}, live = {}, feats = {},
}

NX.CFG, NX.ST = CFG, ST
local CONFIG_DIR = "nexora_configs"
NX.CONFIG_DIR = CONFIG_DIR

local function parts()
    local plr = Players.LocalPlayer
    local char = plr and plr.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return nil end
    return char, root, hum
end

local function bodyVel(root)
    local ok, bv = pcall(function()
        return root:FindFirstChild("BodyVelocity") or root:FindFirstChildOfClass("BodyVelocity")
    end)
    if ok then return bv end
    return nil
end

local function setHoriz(root, x, z)
    local bv = bodyVel(root)
    if bv then
        pcall(function() bv.Velocity = Vector3.new(x, 0, z) end)
    end
    local cur = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(x, cur.Y, z)
end

local function setY(root, y)
    local cur = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(cur.X, y, cur.Z)
end

local function impulse(root, x, z, secs, holdToGround)
    ST.imp.x, ST.imp.z = x, z
    ST.imp.untilT = os.clock() + (secs or 0.3)
    ST.imp.ground = holdToGround and true or false
    setHoriz(root, x, z)
end

local function stepImpulse(root, grounded)
    if ST.imp.untilT <= os.clock() then return false end
    if ST.imp.ground and grounded then
        ST.imp.untilT = 0
        return false
    end
    setHoriz(root, ST.imp.x, ST.imp.z)
    return true
end

local function initials(s)
    local out = ''
    for w in tostring(s):gmatch('%a+') do out = out .. w:sub(1, 1) end
    return out:lower()
end

local function cue(text)
    local now = os.clock()
    if CFG.ind.graph then
        table.insert(ST.gmark, { n = ST.gn, label = initials(text) })
        if #ST.gmark > 16 then table.remove(ST.gmark, 1) end
    end
    if not CFG.ind.cues then return end
    local lastc = ST.cue[#ST.cue]
    if lastc and lastc.t == text and now - lastc.at < 0.15 then return end
    table.insert(ST.cue, { t = text, at = now })
    if #ST.cue > 6 then table.remove(ST.cue, 1) end
end

NX.parts, NX.cue = parts, cue
NX.bodyVel, NX.setHoriz, NX.setY = bodyVel, setHoriz, setY
NX.impulse, NX.stepImpulse = impulse, stepImpulse

local renderHooks, physicsHooks = {}, {}
function NX.onRender(fn) table.insert(renderHooks, fn) end
function NX.onPhysics(fn) table.insert(physicsHooks, fn) end

function NX.register(key, short, item, bind, live)
    ST.feats[key] = { item = item, bind = bind }
    ST.short[key] = short or key
    if live then ST.live[key] = live end
    table.insert(ST.order, key)
end

function NX.active(key)
    local f = ST.feats[key]
    if not f or not f.item or not f.item.value then return false end
    if not f.bind then return true end
    return f.bind.active and true or false
end

function NX.tab(group, name) return UI:Tab(group, name) end

local function hud(fn)
    local keep = UI._a
    UI._a = 1
    fn()
    UI._a = keep
end

local IC = {
    main     = Color3.fromRGB(255, 255, 255),
    key_up   = Color3.fromRGB(110, 110, 110),
    key_down = Color3.fromRGB(255, 255, 255),
    cue      = Color3.fromRGB(126, 249, 164),
    success = Color3.fromRGB(126, 249, 164),
    dim     = Color3.fromRGB(150, 150, 150),
    shadow  = Color3.fromRGB(0, 0, 0),
    v1 = Color3.fromRGB(255, 255, 255),
    v2 = Color3.fromRGB(126, 249, 164),
    v3 = Color3.fromRGB(255, 112, 112),
}
NX.IC = IC

local A = {
    alpha = 22.0, pos = 20.0, det = 9.0,
    remove_mul = 2.35, spawn_base = 90.0, spawn_step = 8.0, delay = 0.02,
    v_alpha = 26.0, v_pos = 22.0, v_col = 20.0, v_gap = 6.0, v_off = 12.0,
}

local function approach(cur, target, speed, dt)
    if not CFG.ind.anim then return target end
    return cur + (target - cur) * clamp(dt * speed, 0, 1)
end

local function ramp(pct)
    pct = clamp(pct, 0, 1) * 2
    if pct <= 1 then return lerpc(IC.v1, IC.v2, pct) end
    return lerpc(IC.v2, IC.v3, pct - 1)
end

local function tw(s, size) return #tostring(s) * size * 0.54 end

local function shadowTx(id, pos, text, col, z, size, a)
    UI:_Tx(id .. '_s', Vector2.new(pos.X + 1.5, pos.Y + 1.5), text, IC.shadow, z, size,
           true, true, a * 0.55, UI.font_ind_bold)
    UI:_Tx(id, pos, text, col, z + 1, size, true, true, a, UI.font_ind_bold)
end

local function drawIndicators()
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local dt = UI._dt or 0.016
    local now = os.clock()
    local _, root = parts()

    local speed = 0
    if root then
        local v = root.AssemblyLinearVelocity
        speed = Vector3.new(v.X, 0, v.Z).Magnitude * (250 / 19)
    end
    ST.disp = ST.disp + (speed - ST.disp) * 0.25

    hud(function()

        local ix = ST.ix
        if CFG.ind.vel and root then
            ix.va = approach(ix.va, 1, A.v_alpha, dt)
            local ty = vp.Y * CFG.ind.vel_pos
            ix.vy = (ix.vy == 0) and ty or approach(ix.vy, ty, A.v_pos, dt)

            local target = clamp(ST.disp / math.max(CFG.ind.vel_max, 1), 0, 1)
            ix.vc = approach(ix.vc, target, A.v_col, dt)

            local size = CFG.ind.vel_size
            local main = tostring(math.floor(ST.disp + 0.5))

            local extra = ''
            if CFG.ind.prespeed then
                if ST.js.air and ST.js.sp0 and ST.js.sp0 > 1 then
                    ix.pre = ST.js.sp0
                    ix.prea = approach(ix.prea, 1, A.v_alpha, dt)
                else
                    ix.prea = approach(ix.prea, 0, A.v_alpha * 0.82, dt)
                end
                if ix.prea > 0.01 then
                    extra = '(' .. tostring(math.floor(ix.pre + 0.5)) .. ')'
                end
            else
                ix.prea = 0
            end

            local esize = size
            local mw = tw(main, size)
            local ew = (extra ~= '') and tw(extra, esize) or 0
            local gap = (ew > 0) and A.v_gap or 0
            local left = vp.X / 2 - (mw + gap + ew) / 2

            shadowTx('iv', Vector2.new(left + mw / 2, ix.vy), main,
                     ramp(ix.vc), 800, size, ix.va)

            if ew > 0 then
                shadowTx('ivp', Vector2.new(left + mw + gap + ew / 2, ix.vy), extra,
                         IC.dim, 800, esize, ix.va * ix.prea)
            else
                UI:_Hide('ivp')
            end
        else
            ix.va = approach(ix.va, 0, A.v_alpha * 0.82, dt)
            if ix.va < 0.01 then UI:_Hide('iv') UI:_Hide('ivp') end
        end

        if CFG.ind.graph and root then
            local N = 90
            local rate = math.max(CFG.ind.graph_rate, 0.01)
            if now - ST.gt >= rate then
                ST.gt = now
                ST.gn = ST.gn + 1
                table.insert(ST.graph, ST.disp)
                while #ST.graph > N do table.remove(ST.graph, 1) end
            end

            local gw, gh = 320, 46
            local gx = vp.X / 2 - gw / 2
            local gy = vp.Y - CFG.ind.graph_yoff
            local step = gw / (N - 1)

            local frac = clamp((now - ST.gt) / rate, 0, 1)
            if not CFG.ind.anim then frac = 0 end
            local base = gx + gw - (#ST.graph - 1) * step - frac * step

            for i = 1, #ST.graph - 1 do
                local v1, v2 = ST.graph[i], ST.graph[i + 1]
                local y1 = gy + gh - math.min(v1, 350) / 350 * gh
                local y2 = gy + gh - math.min(v2, 350) / 350 * gh
                local d = UI._draw['ig' .. i]
                if not d then d = Drawing.new('Line') UI._draw['ig' .. i] = d end
                UI._used['ig' .. i] = true
                d.From = Vector2.new(base + (i - 1) * step, y1)
                d.To = Vector2.new(base + i * step, y2)
                d.Color, d.Thickness, d.ZIndex = ramp(ST.ix.vc), 1, 800
                d.Transparency, d.Visible = 1, true
            end

            if CFG.ind.graph_marks then
                for mi = #ST.gmark, 1, -1 do
                    local m = ST.gmark[mi]
                    local off = ST.gn - m.n
                    if off >= #ST.graph or #ST.graph < 2 then
                        table.remove(ST.gmark, mi)
                    else
                        local idx = #ST.graph - off
                        local mx = base + (idx - 1) * step
                        local v = ST.graph[idx] or 0
                        local my = gy + gh - math.min(v, 350) / 350 * gh
                        local id = 'gm' .. (m.n % 32)
                        local d = UI._draw[id]
                        if not d then d = Drawing.new('Line') UI._draw[id] = d end
                        UI._used[id] = true
                        d.From, d.To = Vector2.new(mx, my), Vector2.new(mx, gy + gh)
                        d.Color, d.Thickness, d.ZIndex = IC.dim, 1, 799
                        d.Transparency, d.Visible = 0.5, true
                        UI:_Tx(id .. 't', Vector2.new(mx, my - 9), m.label,
                               IC.cue, 802, 13, true, true, 0.9, UI.font_ind_bold)
                    end
                end
            end
        else
            ST.graph, ST.gmark = {}, {}
        end

        if CFG.ind.cues then
            for i = #ST.cue, 1, -1 do
                if now - ST.cue[i].at > CFG.ind.cue_time then table.remove(ST.cue, i) end
            end
            for i, c in ipairs(ST.cue) do
                local age = now - c.at
                local a = 1 - (age / CFG.ind.cue_time)
                local y = vp.Y * CFG.ind.cue_yoff - age * CFG.ind.cue_rise
                          - (#ST.cue - i) * 22
                shadowTx('cu' .. i, Vector2.new(vp.X / 2, y), low(c.t), IC.cue, 805,
                         CFG.ind.cue_size, a)
            end
        end

        if CFG.ind.keys then
            local ks = CFG.ind.key_size
            local cw = ks * CFG.ind.key_gap
            local crouch = UI:Held('ctrl') or UI:Held('lctrl') or UI:Held('rctrl')
                           or UI:Held('c')
            local grid = {
                { { 'c', crouch }, { 'w', UI:Held('w') }, { 'j', UI:Held('space') } },
                { { 'a', UI:Held('a') }, { 's', UI:Held('s') }, { 'd', UI:Held('d') } },
            }

            local gw = cw * 3
            local gx = vp.X * CFG.ind.key_pos_x - gw / 2 + cw / 2
            local gy = vp.Y * CFG.ind.key_pos_y

            for r = 1, 2 do
                for c = 1, 3 do
                    local cell = grid[r][c]
                    local id = 'kp' .. r .. c
                    local px = gx + (c - 1) * cw
                    local py = gy + (r - 1) * ks * CFG.ind.key_rows
                    local lit = UI:Anim(id, cell[2] and 1 or 0, 30)
                    local glyph = cell[2] and cell[1] or '_'

                    UI:_Tx(id .. '_s', Vector2.new(px + 1.5, py + 1.5), glyph,
                           IC.shadow, 800, ks, true, true, 0.55, UI.font_mono)
                    UI:_Tx(id, Vector2.new(px, py), glyph,
                           lerpc(IC.key_up, IC.key_down, lit), 801, ks,
                           true, true, nil, UI.font_mono)
                end
            end
        else
            UI:_Hide('kp')
        end

        if not CFG.ind.binds then
            for _, s in pairs(ST.ix.lbl) do s.a = 0 end
            UI:_Hide('ib_')
            return
        end

        local size = CFG.ind.bind_size
        local rows, idx = {}, 0
        for _, k in ipairs(ST.order) do
            local f = ST.feats[k]
            if f and f.item and f.item.value then
                local lf = ST.live[k]
                local live = (lf and lf()) and true or false
                local act = (not f.bind) or (f.bind.active and true or false)

                if act or live then
                    idx = idx + 1
                    table.insert(rows, { k = k, label = low(ST.short[k] or k),
                                         act = act, live = live, i = idx })
                end
            end
        end

        local seen = {}
        for _, r in ipairs(rows) do
            seen[r.k] = true
            local s = ST.ix.lbl[r.k]
            if not s then
                s = { a = 0, x = nil, det = 0, born = now, held = 0 }
                ST.ix.lbl[r.k] = s
            end
            s.row = r
        end
        for k, s in pairs(ST.ix.lbl) do
            if not seen[k] then s.row = nil end
        end

        local order = {}
        for _, r in ipairs(rows) do table.insert(order, r.k) end
        for k, s in pairs(ST.ix.lbl) do
            if not s.row and s.a > 0.01 then table.insert(order, k) end
        end

        local total = 0
        for _, k in ipairs(order) do
            local s = ST.ix.lbl[k]
            local lbl = (s.row and s.row.label) or low(ST.short[k] or k)
            total = total + (tw(lbl, size) + CFG.ind.spacing) * s.a
        end

        local x = vp.X / 2 - total / 2
        local y = vp.Y * CFG.ind.bind_pos

        for n, k in ipairs(order) do
            local s = ST.ix.lbl[k]
            local r = s.row
            local lbl = (r and r.label) or low(ST.short[k] or k)
            local w = tw(lbl, size)

            if r then
                local target = (now - s.born >= A.delay) and 1 or 0
                s.a = approach(s.a, target, A.alpha, dt)
            else
                s.a = approach(s.a, 0, A.alpha * A.remove_mul, dt)
            end

            if r and r.live then
                s.det, s.held = 1, now
            elseif now - (s.held or 0) > CFG.ind.det_hold then
                s.det = approach(s.det or 0, 0, A.det, dt)
            end

            local tx = x + w / 2
            if s.x == nil then

                s.x = tx + A.spawn_base + A.spawn_step * n
            end
            s.x = approach(s.x, tx, A.pos, dt)

            if s.a > 0.01 then
                local base = (r and r.act) and IC.main or IC.dim
                local col = lerpc(base, IC.success, (s.det or 0) * CFG.ind.det_max)
                shadowTx('ib_' .. k, Vector2.new(s.x, y), lbl, col, 803, size, s.a)
            else
                UI:_Hide('ib_' .. k)
                if not r then ST.ix.lbl[k] = nil end
            end

            x = x + (w + CFG.ind.spacing) * s.a
        end
    end)
end

local function ensureDir()
    pcall(function() if not isfolder(CONFIG_DIR) then makefolder(CONFIG_DIR) end end)
end

local function configList()
    ensureDir()
    local names = {}
    local ok, files = pcall(listfiles, CONFIG_DIR)
    if ok and files then
        for _, f in ipairs(files) do
            if f:sub(-5) == ".json" then
                local n = f:match("[\\/]([^\\/]+)%.json$")
                if n then table.insert(names, n) end
            end
        end
    end
    if #names == 0 then names = { "default" } end
    return names
end

local function collect()
    local out = {}
    for _, gname in ipairs(UI._order) do
        local g = UI._groups[gname]
        for _, tname in ipairs(g.order) do
            for _, sec in ipairs(g.tabs[tname].sections) do
                for _, item in ipairs(sec.items) do
                    if item.label and item.kind ~= 'button' then
                        local key = tname .. "." .. sec.title .. "." .. item.label
                        local e = { v = item.value }
                        if item.kind == 'colour' then
                            e.v = nil
                            e.c = { item.h, item.s, item.v }
                        end
                        if item.bind then e.k = item.bind.key e.m = item.bind.mode end
                        out[key] = e
                    end
                end
            end
        end
    end
    out["__hue"] = { v = UI.hue }
    return out
end

local function apply(data)
    for _, gname in ipairs(UI._order) do
        local g = UI._groups[gname]
        for _, tname in ipairs(g.order) do
            for _, sec in ipairs(g.tabs[tname].sections) do
                for _, item in ipairs(sec.items) do
                    if item.label and item.kind ~= 'button' then
                        local key = tname .. "." .. sec.title .. "." .. item.label
                        local e = data[key]
                        if e then
                            if item.kind == 'colour' and type(e.c) == 'table' then
                                item.h, item.s, item.v = e.c[1], e.c[2], e.c[3]
                                item.value = Color3.fromHSV(item.h, item.s, item.v)
                                if item.cb then pcall(item.cb, item.value) end
                            elseif e.v ~= nil then
                                item.value = e.v
                                if item.cb then pcall(item.cb, e.v) end
                            end
                            if item.bind then
                                if e.k ~= nil then item.bind.key = e.k end
                                if e.m then item.bind.mode = e.m end
                            end
                        end
                    end
                end
            end
        end
    end
    if data["__hue"] and data["__hue"].v then UI:SetAccent(data["__hue"].v) end
end

local function saveConfig(name)
    if not name or name == "" then return end
    ensureDir()
    pcall(function()
        writefile(CONFIG_DIR .. "/" .. name .. ".json", HttpService:JSONEncode(collect()))
    end)
end

local function loadConfig(name)
    if not name or name == "" then return end
    local path = CONFIG_DIR .. "/" .. name .. ".json"
    local ok, raw = pcall(readfile, path)
    if not ok or not raw then return end
    local good, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if good and type(data) == "table" then apply(data) end
end

local function deleteConfig(name)
    if not name or name == "" then return end
    pcall(function() delfile(CONFIG_DIR .. "/" .. name .. ".json") end)
end

NX.saveConfig, NX.loadConfig = saveConfig, loadConfig
NX.configList = configList

local OFF_URL   = "https://offsets.imtheo.lol/offsets.json"
local OFF_CACHE = CONFIG_DIR .. "/offsets.json"
local OFFSETS   = {}
local OFFMETA   = { source = "none", version = "?", dumped = "?", count = 0 }
local offHooks  = {}

local function parseOffsets(txt)
    if type(txt) ~= "string" then return nil end
    local body = txt:match('"Offsets"%s*:%s*(%b{})')
    if not body then return nil end
    local groups, n = {}, 0
    for name, blob in body:gmatch('"([%w_]+)"%s*:%s*(%b{})') do
        local g = {}
        for k, v in blob:gmatch('"([%w_]+)"%s*:%s*"?(%-?[%w]+)"?') do
            local num = tonumber(v)
            if num then g[k] = num n = n + 1 end
        end
        groups[name] = g
    end
    if n == 0 then return nil end
    return groups, n
end

local function applyOffsets(txt, src)
    local g, n = parseOffsets(txt)
    if not g then return false end
    OFFSETS = g
    OFFMETA.source  = src
    OFFMETA.count   = n
    OFFMETA.version = txt:match('"Roblox Version"%s*:%s*"([^"]+)"') or "?"
    OFFMETA.dumped  = txt:match('"Dumped At"%s*:%s*"([^"]+)"') or "?"
    return true
end

function NX.off(group, name, fallback)
    local g = OFFSETS[group]
    local v = g and g[name]
    if type(v) == "number" then return v end
    return fallback
end

function NX.offsetMeta() return OFFMETA end

function NX.onOffsets(fn)
    table.insert(offHooks, fn)
    if OFFMETA.source ~= "none" then pcall(fn) end
end

local function fireOffsets()
    for _, fn in ipairs(offHooks) do
        local ok, err = pcall(fn)
        if not ok then warn("[nx] offsets hook - " .. tostring(err)) end
    end
end

function NX.refreshOffsets()
    local body
    if httpget then
        local ok, r = pcall(httpget, OFF_URL .. "?t=" .. tostring(tick()))
        if ok then body = r end
    end
    if type(body) ~= "string" or #body < 256 then
        local ok, r = pcall(function() return game:HttpGet(OFF_URL, true) end)
        if ok then body = r end
    end

    if applyOffsets(body, "live") then
        pcall(function() ensureDir() writefile(OFF_CACHE, body) end)
        fireOffsets()
        return true, OFFMETA.count .. " offsets, roblox " .. OFFMETA.version
    end

    local cached
    pcall(function() if isfile(OFF_CACHE) then cached = readfile(OFF_CACHE) end end)
    if applyOffsets(cached, "cache") then
        fireOffsets()
        return true, "host down, using cache (roblox " .. OFFMETA.version .. ")"
    end

    return false, "no response and no cache"
end

pcall(function()
    if isfile(OFF_CACHE) then applyOffsets(readfile(OFF_CACHE), "cache") end
end)

local function humAddr(hum)
    if not hum then return nil end
    local ok, a = pcall(function() return hum.Address end)
    if not ok or not a or a == 0 then return nil end
    return a
end
NX.humAddr = humAddr

function NX.humGet(hum, field, kind, fb)
    local a = humAddr(hum)
    if not a then return nil end
    local ok, v = pcall(memory_read, kind or "float", a + NX.off('Humanoid', field, fb))
    if ok and type(v) == "number" then return v end
    return nil
end

function NX.humSet(hum, field, kind, value, fb)
    local a = humAddr(hum)
    if not a then return false end
    return (pcall(memory_write, kind or "float", a + NX.off('Humanoid', field, fb), value))
end

local probe = { trusted = false, air = false, solid = false }
NX.groundProbe = probe

function NX.floorGrounded(hum)
    local m = NX.humGet(hum, 'FloorMaterial', "int", 384)
    if m == nil then return nil end
    if m > 0 then probe.solid = true else probe.air = true end
    probe.trusted = probe.solid and probe.air
    if not probe.trusted then return nil end
    return m > 0
end

local ind = UI:Tab("visuals", "Visuals")

local disp = ind:Section("Indicators", "left")
disp:Toggle("Velocity", CFG.ind.vel, function(v) CFG.ind.vel = v end)
disp:Toggle("Takeoff speed", CFG.ind.prespeed, function(v) CFG.ind.prespeed = v end)
disp:Toggle("Keybinds", CFG.ind.binds, function(v) CFG.ind.binds = v end)
disp:Toggle("Keystrokes", CFG.ind.keys, function(v) CFG.ind.keys = v end)
disp:Toggle("Trick cues", CFG.ind.cues, function(v) CFG.ind.cues = v end)
disp:Toggle("Velocity graph", CFG.ind.graph, function(v) CFG.ind.graph = v end)
disp:Toggle("Graph markers", CFG.ind.graph_marks, function(v) CFG.ind.graph_marks = v end)
disp:Toggle("Animations", CFG.ind.anim, function(v) CFG.ind.anim = v end)

local vstyle = ind:Section("Velocity", "right")
vstyle:Slider("Size", CFG.ind.vel_size, 1, 12, 64, "px", function(v) CFG.ind.vel_size = v end)
vstyle:Slider("Height", CFG.ind.vel_pos, 0.01, 0.1, 0.95, "", function(v) CFG.ind.vel_pos = v end)
vstyle:Slider("Colour top", CFG.ind.vel_max, 10, 100, 1200, "", function(v) CFG.ind.vel_max = v end)
vstyle:Colour("Slow", NX.IC.v1, function(c) NX.IC.v1 = c end)
vstyle:Colour("Mid", NX.IC.v2, function(c) NX.IC.v2 = c end)
vstyle:Colour("Fast", NX.IC.v3, function(c) NX.IC.v3 = c end)

local bstyle = ind:Section("Keybinds", "left")
bstyle:Slider("Size", CFG.ind.bind_size, 1, 10, 48, "px", function(v) CFG.ind.bind_size = v end)
bstyle:Slider("Height", CFG.ind.bind_pos, 0.01, 0.1, 0.95, "", function(v) CFG.ind.bind_pos = v end)
bstyle:Colour("Active", NX.IC.main, function(c) NX.IC.main = c end)
bstyle:Colour("Detected", NX.IC.success, function(c) NX.IC.success = c end)

local kstyle = ind:Section("Keystrokes", "right")
kstyle:Slider("Size", CFG.ind.key_size, 1, 8, 48, "px", function(v) CFG.ind.key_size = v end)
kstyle:Slider("X", CFG.ind.key_pos_x, 0.01, 0.02, 0.98, "", function(v) CFG.ind.key_pos_x = v end)
kstyle:Slider("Y", CFG.ind.key_pos_y, 0.01, 0.02, 0.96, "", function(v) CFG.ind.key_pos_y = v end)
kstyle:Colour("Down", NX.IC.key_down, function(c) NX.IC.key_down = c end)

local ostyle = ind:Section("Cues", "left")
ostyle:Slider("Time", CFG.ind.cue_time, 0.1, 0.3, 4, "s", function(v) CFG.ind.cue_time = v end)
ostyle:Slider("Height", CFG.ind.cue_yoff, 0.01, 0.05, 0.95, "", function(v) CFG.ind.cue_yoff = v end)
ostyle:Colour("Colour", NX.IC.cue, function(c) NX.IC.cue = c end)
ostyle:Slider("Graph rate", CFG.ind.graph_rate, 0.01, 0.01, 0.3, "s", function(v) CFG.ind.graph_rate = v end)

local pgT
local cfgTab = UI:Tab("misc", "Config")
local cs = cfgTab:Section("Config", "left")
local nameBox = cs:Textbox("default", "config name")
local picked = configList()[1]
local list = cs:Dropdown("Load config", picked, configList(), function(v) picked = v end)
cs:Button("Save config", function()
    saveConfig(nameBox:Get())
    list.item.choices = configList()
end)
cs:Button("Load selected", function() loadConfig(picked) end)
cs:Button("Delete selected", function()
    deleteConfig(picked)
    list.item.choices = configList()
    picked = list.item.choices[1]
    list:Set(picked)
end)
local th = cfgTab:Section("Theme", "right")
th:Colour("Accent", UI.theme.accent, function(c) UI.theme.accent = c end)
th:Colour("Text", UI.theme.text, function(c) UI.theme.text = c end)
th:Colour("Dim text", UI.theme.dim, function(c) UI.theme.dim = c end)
th:Colour("Background", UI.theme.panel, function(c)
    UI.theme.panel, UI.theme.side, UI.theme.card = c, c, c
end)
th:Colour("Border", UI.theme.border, function(c) UI.theme.border = c end)

local gs = cfgTab:Section("Game", "right")
local gameLbl = gs:Label(NX.gameName or 'unknown')
gs:Label("place " .. tostring(NX.placeId or 0))
pgT = gs:Toggle("Per-game config", true)
gs:Button("Save for this game", function()
    saveConfig(NX.placeConfig())
    list.item.choices = configList()
end)
gs:Button("Load for this game", function() loadConfig(NX.placeConfig()) end)

local autoT = cs:Toggle("Auto-load selected", false, function(v)
    if v then
        pcall(function() writefile(CONFIG_DIR .. "/autoload.cfg", picked or "default") end)
    else
        pcall(function() delfile(CONFIG_DIR .. "/autoload.cfg") end)
    end
end)
cs:Button("Refresh list", function() list.item.choices = configList() end)

local offs = cfgTab:Section("Offsets", "right")
local offL1 = offs:Label("not loaded")
local offL2 = offs:Label("")
local function offStatus()
    if OFFMETA.source == "none" then
        offL1.label = "not loaded"
        offL2.label = "hit update"
    else
        offL1.label = OFFMETA.source .. " - " .. tostring(OFFMETA.count) .. " offsets"
        offL2.label = "roblox " .. tostring(OFFMETA.version)
    end
end
offStatus()
local offAuto = offs:Toggle("Update on load", true)
offs:Button("Update now", function()
    local ok, msg = NX.refreshOffsets()
    offStatus()
    if notify then
        pcall(notify, ok and ("offsets: " .. msg) or ("offsets failed - " .. msg), "nexora", 4)
    end
end)
NX.offStatus = offStatus

NX.perGame = function() return pgT and pgT.item.value end
NX.pickConfig = function(n) if n then picked = n list:Set(n) end return picked end

local steppedConn = RunService.Stepped:Connect(function()
    for _, fn in ipairs(physicsHooks) do
        local ok, err = pcall(fn)
        if not ok then warn("[nx] " .. tostring(err)) end
    end
end)

function NX.stop()
    renderHooks, physicsHooks = {}, {}
    pcall(function() if steppedConn then steppedConn:Disconnect() end end)
    steppedConn = nil
    pcall(function() UI:Stop() end)
    pcall(function() UI:Unload() end)
end

local baseStep = UI.Step
UI.Step = function(self)
    baseStep(self)
    for _, fn in ipairs(renderHooks) do
        local ok, err = pcall(fn)
        if not ok then warn("[nx] " .. tostring(err)) end
    end
    local iok, ierr = pcall(drawIndicators)
    if not iok then warn("[nx] " .. tostring(ierr)) end
    self:_Sweep()
end

function NX.start(group, tab)
    UI._order = { "visuals", "movement", "misc" }

    if gameLbl then gameLbl.label = tostring(NX.gameName or 'unknown'):lower() end

    group = group and tostring(group):lower()
    tab = tab and tostring(tab):lower()
    if group and UI._groups[group] then
        UI._tab = UI._groups[group].tabs[tab] or UI._tab
    end
    ensureDir()

    pcall(function()
        local pg = NX.placeConfig()
        if NX.perGame() and isfile(CONFIG_DIR .. "/" .. pg .. ".json") then
            loadConfig(pg)
            return
        end
        if isfile(CONFIG_DIR .. "/autoload.cfg") then
            local n = readfile(CONFIG_DIR .. "/autoload.cfg")
            if n and n ~= "" then loadConfig(n) NX.pickConfig(n) end
        end
    end)

    if offAuto and offAuto.item.value then
        local ok, msg = NX.refreshOffsets()
        offStatus()
        print("[nexora] offsets " .. (ok and msg or ("failed - " .. tostring(msg))))
    end

    UI:Run()
end

local ENV = (getfenv and getfenv()) or _G
ENV.NEXORA_CORE = NX
return NX
