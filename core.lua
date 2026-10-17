local Players = game:GetService("Players")

local UI = {
    w = 820, h = 540, side_w = 212, x = 0, y = 0, scale = 1,
    title = "nexora",

    theme = {
        shadow   = Color3.fromRGB(0, 0, 0),
        panel    = Color3.fromRGB(14, 15, 20),
        side     = Color3.fromRGB(18, 19, 25),
        card     = Color3.fromRGB(23, 25, 34),
        card_hi  = Color3.fromRGB(28, 31, 41),
        border   = Color3.fromRGB(38, 42, 54),
        track    = Color3.fromRGB(44, 48, 62),
        text     = Color3.fromRGB(230, 232, 239),
        dim      = Color3.fromRGB(138, 143, 158),
        head     = Color3.fromRGB(90, 96, 112),
        accent   = Color3.fromRGB(139, 123, 255),
        accent2  = Color3.fromRGB(236, 130, 210),
    },
    hue = 0.72,

    font = Drawing.Fonts.System,
    font_bold = Drawing.Fonts.SystemBold,
    fs = 13, fs_sm = 11, fs_lg = 16,

    _draw = {}, _used = {}, _anim = {}, _groups = {}, _order = {},
    _tab = nil, _open = true, _a = 0, _scroll = { left = 0, right = 0 },
    _drag = nil, _slider = nil, _dd = nil, _listen = nil, _scrollbar = nil, _focus = nil,
    _menu_key = 'rshift', _last = os.clock(), _running = false,
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
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

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

function UI:_Tx(id, p, text, c, z, size, center, bold, a)
    self._used[id] = true
    local d = self._draw[id]
    if not d then d = Drawing.new('Text') self._draw[id] = d end
    d.Position, d.Text, d.Color = p, text, c
    d.Font, d.Center, d.Outline = bold and self.font_bold or self.font, center or false, false
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
    self.theme.accent = Color3.fromHSV(self.hue, 0.58, 1)
    self.theme.accent2 = Color3.fromHSV((self.hue + 0.12) % 1, 0.62, 1)
end

function UI:Tab(groupName, tabName)
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
        local sec = { title = title, side = side or 'left', items = {} }
        table.insert(tab.sections, sec)
        local s = {}
        local function add(i) table.insert(sec.items, i) return i end
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
        function s:Label(text) return add({ kind = 'label', label = text }) end
        return s
    end
    return api
end

function UI:_Sidebar(click)
    local t, S = self.theme, self.scale
    local x, y, w, h = self.x, self.y, self.side_w * S, self.h * S

    self:_Round('sd', Vector2.new(x, y), Vector2.new(w, h), t.side, 2, 10 * S)
    self:_Grad('sdg', Vector2.new(x, y), Vector2.new(w, 120 * S),
               lerpc(t.side, t.accent, 0.07), t.side, 3, 10)

    self:_Ci('logo', Vector2.new(x + 26 * S, y + 30 * S), 7 * S, t.accent, 6)
    self:_Ci('logo2', Vector2.new(x + 26 * S, y + 30 * S), 3.2 * S, t.side, 7)
    self:_Tx('ttl', Vector2.new(x + 42 * S, y + 22 * S), self.title, t.text, 6, self.fs_lg * S, false, true)
    self:_Sq('sdl', Vector2.new(x + 18 * S, y + 56 * S), Vector2.new(w - 36 * S, 1), t.border, 6)

    local rows, cy = {}, y + 72 * S
    for _, gname in ipairs(self._order) do
        local g = self._groups[gname]
        self:_Tx('g_' .. gname, Vector2.new(x + 20 * S, cy), string.upper(gname), t.head, 6, self.fs_sm * S)
        cy = cy + 17 * S
        for _, tname in ipairs(g.order) do
            table.insert(rows, { tab = g.tabs[tname], name = tname, y = cy })
            cy = cy + 28 * S
        end
        cy = cy + 12 * S
    end

    local selY, selH = y, 0
    for i, r in ipairs(rows) do
        local id = 'r' .. i
        local pos = Vector2.new(x + 12 * S, r.y)
        local size = Vector2.new(w - 24 * S, 26 * S)
        local hov = self:In(pos, size)
        local sel = self._tab == r.tab
        if sel then selY, selH = r.y, size.Y end

        local hv = self:Anim(id .. 'h', (hov and not sel) and 1 or 0, 16)
        if hv > 0.01 then
            self:_Round(id .. 'bg', pos, size, t.card, 4, 6 * S, hv * 0.9)
        else
            self:_Hide(id .. 'bg')
        end

        local col = sel and t.text or lerpc(t.dim, t.text, hv)
        if not sel then
            self:_Ci(id .. 'd', Vector2.new(pos.X + 17 * S, pos.Y + size.Y / 2), 2.4 * S,
                     lerpc(t.head, t.dim, hv), 7)
        end
        self:_Tx(id .. 't', Vector2.new(pos.X + 30 * S, pos.Y + 6 * S), r.name, col, 7, self.fs * S)

        if hov and click then self._tab = r.tab self._dd = nil self._scroll.left = 0 self._scroll.right = 0 click = false end
    end

    local sy = self:Anim('selY', selY, 20)
    local sh = self:Anim('selH', selH, 20)
    if sh > 1 then
        self:_Round('selpill', Vector2.new(x + 12 * S, sy), Vector2.new(w - 24 * S, sh), t.card_hi, 3, 7 * S)
        self:_Sq('selbar', Vector2.new(x + 16 * S, sy + 7 * S), Vector2.new(2 * S, sh - 14 * S), t.accent, 8)
    end

    local fy = y + h - 34 * S
    self:_Sq('fdl', Vector2.new(x + 18 * S, fy - 12 * S), Vector2.new(w - 36 * S, 1), t.border, 6)
    self:_Tx('fa', Vector2.new(x + 20 * S, fy), 'accent', t.dim, 6, self.fs_sm * S)
    local hx, hy = x + 74 * S, fy + 1 * S
    local hw, hh = w - 94 * S, 10 * S
    for i = 1, 24 do
        self:_Sq('hu' .. i, Vector2.new(hx + hw * (i - 1) / 24, hy), Vector2.new(hw / 24 + 1, hh),
                 Color3.fromHSV((i - 1) / 24, 0.58, 1), 6)
    end
    self:_Ci('huk', Vector2.new(hx + hw * self.hue, hy + hh / 2), 5 * S, t.text, 8)
    self:_Ci('huk2', Vector2.new(hx + hw * self.hue, hy + hh / 2), 3.4 * S, t.accent, 9)
    if self:In(Vector2.new(hx, hy - 4), Vector2.new(hw, hh + 8)) and click then
        self._slider = 'hue' click = false
    end
    if self._slider == 'hue' then
        if self:Held('m1') then self:SetAccent(clamp((self:Mouse().X - hx) / hw, 0, 0.999))
        else self._slider = nil end
    end
    return click
end

function UI:_Item(id, item, pos, width, click, rclick, vis)
    local t, S = self.theme, self.scale
    local fs = self.fs * S

    if not vis then
        self:_Hide(id)
        if item.kind == 'toggle' then return 24 * S, click
        elseif item.kind == 'slider' or item.kind == 'dropdown' then return 30 * S, click
        elseif item.kind == 'button' or item.kind == 'textbox' then return 34 * S, click end
        return 19 * S, click
    end

    if item.kind == 'label' then
        self:_Tx(id .. 'l', pos, item.label, t.dim, 14, fs)
        return 19 * S, click

    elseif item.kind == 'toggle' then
        local rowh = 24 * S
        local tw, th = 28 * S, 15 * S
        local tp = Vector2.new(pos.X + width - tw, pos.Y + (rowh - th) / 2 - 2 * S)
        local hov = self:In(tp, Vector2.new(tw, th))
        local on = self:Anim(id .. 'v', item.value and 1 or 0, 16)

        self:_Round(id .. 'tr', tp, Vector2.new(tw, th), lerpc(t.track, t.accent, on), 14, th / 2)
        self:_Ci(id .. 'kn', Vector2.new(tp.X + th / 2 + (tw - th) * on, tp.Y + th / 2),
                 th / 2 - 2.5 * S, Color3.fromRGB(245, 245, 250), 16)
        if on > 0.5 then
            self:_Ci(id .. 'gl', Vector2.new(tp.X + th / 2 + (tw - th) * on, tp.Y + th / 2),
                     th / 2 + 2 * S, t.accent, 13, (on - 0.5) * 0.5)
        else
            self:_Hide(id .. 'gl')
        end

        self:_Tx(id .. 'l', Vector2.new(pos.X, pos.Y + 4 * S), item.label,
                 lerpc(t.dim, t.text, on), 15, fs)

        if hov and click then
            item.value = not item.value
            if item.cb then item.cb(item.value) end
            click = false
        end

        if item.bind then
            local label = (self._listen == id) and '...' or (item.bind.key or '-')
            local cw = math.max(20 * S, #label * 6 * S + 10 * S)
            local ch = 13 * S
            local cp = Vector2.new(tp.X - cw - 8 * S, tp.Y + (th - ch) / 2)
            local chov = self:In(cp, Vector2.new(cw, ch))
            self:_Round(id .. 'cb', cp, Vector2.new(cw, ch), chov and t.accent or t.border, 13, 4 * S)
            self:_Round(id .. 'c', Vector2.new(cp.X + 1, cp.Y + 1), Vector2.new(cw - 2, ch - 2),
                        t.panel, 14, 4 * S)
            self:_Tx(id .. 'ck', Vector2.new(cp.X + cw / 2, cp.Y + ch / 2), label,
                     chov and t.text or t.dim, 16, self.fs_sm * S, true)
            if chov then
                if click then self._listen = id click = false
                elseif rclick then
                    self._dd = { pos = self:Mouse(), w = 76 * S, choices = { 'Hold', 'Toggle', 'Always' },
                                 pick = function(v) item.bind.mode = v item.bind.toggled = false end }
                end
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

    elseif item.kind == 'slider' then
        local rowh = 30 * S
        self:_Tx(id .. 'l', Vector2.new(pos.X, pos.Y + 5 * S), item.label, t.text, 14, fs)
        local vw = 44 * S
        local vp = Vector2.new(pos.X + width - vw, pos.Y + 2 * S)
        self:_Round(id .. 'vb', vp, Vector2.new(vw, 18 * S), t.card, 14, 5 * S)
        self:_Tx(id .. 'v', Vector2.new(vp.X + vw / 2, vp.Y + 9 * S),
                 tostring(item.value) .. item.suffix, t.text, 16, self.fs_sm * S, true)

        local tx = pos.X + width * 0.44
        local tw2 = (pos.X + width - vw - 10 * S) - tx
        local ty = pos.Y + rowh / 2 - 2 * S
        local grabbed = self._slider == id
        local pct = clamp((item.value - item.min) / (item.max - item.min), 0, 1)
        local shown = self:Anim(id .. 'p', pct, 22)

        self:_Round(id .. 'tr', Vector2.new(tx, ty), Vector2.new(tw2, 4 * S), t.track, 14, 2 * S)
        self:_Round(id .. 'fl', Vector2.new(tx, ty), Vector2.new(tw2 * shown, 4 * S), t.accent, 15, 2 * S)
        local kr = self:Anim(id .. 'k', grabbed and 7 or 5.5, 18)
        self:_Ci(id .. 'kg', Vector2.new(tx + tw2 * shown, ty + 2 * S), kr * S + 3 * S, t.accent, 15, 0.25)
        self:_Ci(id .. 'kn', Vector2.new(tx + tw2 * shown, ty + 2 * S), kr * S, Color3.fromRGB(245, 245, 250), 16)

        if self:In(Vector2.new(tx - 6, ty - 9), Vector2.new(tw2 + 12, 22)) and click then
            self._slider = id click = false
        end
        if grabbed then
            if self:Held('m1') then
                local p = clamp((self:Mouse().X - tx) / tw2, 0, 1)
                local v = item.min + (item.max - item.min) * p
                v = math.floor(v / item.step + 0.5) * item.step
                if v ~= item.value then item.value = v if item.cb then item.cb(v) end end
            else
                self._slider = nil
            end
        end
        return rowh, click

    elseif item.kind == 'dropdown' then
        local rowh = 30 * S
        self:_Tx(id .. 'l', Vector2.new(pos.X, pos.Y + 6 * S), item.label, t.text, 14, fs)
        local bw = width * 0.56
        local bp = Vector2.new(pos.X + width - bw, pos.Y + 2 * S)
        local bs = Vector2.new(bw, 21 * S)
        local hov = self:In(bp, bs)
        self:_Round(id .. 'b', bp, bs, hov and t.card_hi or t.card, 14, 5 * S)
        self:_Tx(id .. 'v', Vector2.new(bp.X + 9 * S, bp.Y + 3 * S), tostring(item.value), t.text, 16, fs)
        local ax, ay = bp.X + bw - 13 * S, bp.Y + bs.Y / 2
        self:_Tri(id .. 'ar', Vector2.new(ax - 4 * S, ay - 2 * S), Vector2.new(ax + 4 * S, ay - 2 * S),
                  Vector2.new(ax, ay + 3 * S), t.dim, 16)
        if hov and click then
            self._dd = { pos = Vector2.new(bp.X, bp.Y + bs.Y + 3 * S), w = bw, choices = item.choices,
                         pick = function(v) item.value = v if item.cb then item.cb(v) end end }
            click = false
        end
        return rowh, click

    elseif item.kind == 'button' then
        local rowh = 34 * S
        local bs = Vector2.new(width, 25 * S)
        local hov = self:In(pos, bs)
        local hv = self:Anim(id .. 'h', hov and 1 or 0, 16)
        self:_Round(id .. 'br', pos, bs, lerpc(t.border, t.accent, hv), 13, 5 * S)
        self:_Round(id .. 'b', Vector2.new(pos.X + 1, pos.Y + 1), bs - Vector2.new(2, 2),
                    lerpc(t.card_hi, t.accent, hv * 0.22), 14, 5 * S)
        self:_Tx(id .. 't', Vector2.new(pos.X + width / 2, pos.Y + bs.Y / 2), item.label,
                 lerpc(t.text, Color3.fromRGB(255, 255, 255), hv), 16, fs, true)
        if hov and click then if item.cb then item.cb() end click = false end
        return rowh, click

    elseif item.kind == 'textbox' then
        local rowh = 34 * S
        local bs = Vector2.new(width, 25 * S)
        local hov = self:In(pos, bs)
        local foc = self._focus == id
        self:_Round(id .. 'br', pos, bs, foc and t.accent or t.border, 13, 5 * S)
        self:_Round(id .. 'b', Vector2.new(pos.X + 1, pos.Y + 1), bs - Vector2.new(2, 2),
                    t.panel, 14, 5 * S)
        local shown = item.value
        if shown == '' and not foc then shown = item.placeholder or '' end
        local caret = (foc and math.floor(os.clock() * 2) % 2 == 0) and '|' or ''
        self:_Tx(id .. 't', Vector2.new(pos.X + 9 * S, pos.Y + 5 * S), shown .. caret,
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
    local px = self.x + self.side_w * S + 6 * S
    local py = self.y
    local pw = self.w * S - self.side_w * S - 6 * S
    local ph = self.h * S

    self:_Round('mn', Vector2.new(px, py), Vector2.new(pw, ph), t.panel, 2, 10 * S)
    if not self._tab then return click end

    self:_Tx('ph', Vector2.new(px + 18 * S, py + 18 * S), self._tab.name, t.text, 6, self.fs_lg * S, false, true)
    self:_Tx('pg', Vector2.new(px + 18 * S, py + 36 * S), string.upper(self._tab.group), t.head, 6, self.fs_sm * S)
    self:_Sq('pdl', Vector2.new(px + 18 * S, py + 54 * S), Vector2.new(pw - 36 * S, 1), t.border, 6)
    self:_Round('pacc', Vector2.new(px + 18 * S, py + 54 * S), Vector2.new(46 * S, 1.6 * S), t.accent, 7, 1)

    local pad = 14 * S
    local top = py + 68 * S
    local bottom = py + ph - 12 * S
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

        local iy = sy + 28 * S
        for i, item in ipairs(sec.items) do
            local rowTop = iy
            local vis = rowTop > top - 40 * S and rowTop < bottom
            local ih, c = self:_Item(sid .. 'i' .. i, item,
                Vector2.new(sx + 12 * S, iy), colw - 24 * S, click, rclick, vis)
            click = c
            iy = iy + ih
        end
        local sh = (iy - sy) + 12 * S

        if sy + sh > top - 20 * S and sy < bottom then
            self:_Round(sid .. 'bg', Vector2.new(sx, sy), Vector2.new(colw, sh), t.card, 10, 8 * S)
            self:_Round(sid .. 'br', Vector2.new(sx, sy), Vector2.new(colw, sh), t.border, 9, 8 * S)
            self:_Tx(sid .. 't', Vector2.new(sx + 13 * S, sy + 8 * S), string.upper(sec.title),
                     t.head, 12, self.fs_sm * S)
            self:_Sq(sid .. 'u', Vector2.new(sx + 13 * S, sy + 23 * S), Vector2.new(colw - 26 * S, 1), t.border, 12)
        else
            self:_Hide(sid .. 'bg') self:_Hide(sid .. 'br')
            self:_Hide(sid .. 't') self:_Hide(sid .. 'u')
        end

        cur[side] = sy + sh + 10 * S
        maxb[side] = cur[side] + self._scroll[side]
    end

    for _, side in ipairs({ 'left', 'right' }) do
        local content = maxb[side] - top
        local view = bottom - top
        if content > view then
            local over = content - view
            self._scroll[side] = clamp(self._scroll[side], 0, over)
            local bx = px + pad + (side == 'right' and (colw + pad) or 0) + colw - 3 * S
            local frac = view / content
            local bh = math.max(24 * S, view * frac)
            local bt = top + (view - bh) * (self._scroll[side] / over)
            self:_Round('sb' .. side, Vector2.new(bx, bt), Vector2.new(3 * S, bh), t.track, 20, 1.5 * S)
            if self:In(Vector2.new(bx - 5, bt), Vector2.new(13 * S, bh)) and click then
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

function UI:_Drop(click)
    local d = self._dd
    if not d then self:_Hide('dd') return click end
    local t, S = self.theme, self.scale
    local rh = 20 * S
    local size = Vector2.new(d.w, #d.choices * rh + 8 * S)
    self:_Round('ddbg', d.pos, size, t.card_hi, 60, 6 * S)
    self:_Round('ddbr', d.pos, size, t.border, 59, 6 * S)
    local close = false
    for i, c in ipairs(d.choices) do
        local rp = Vector2.new(d.pos.X + 4 * S, d.pos.Y + 4 * S + (i - 1) * rh)
        local rs = Vector2.new(d.w - 8 * S, rh)
        local hov = self:In(rp, rs)
        if hov then self:_Round('ddh' .. i, rp, rs, t.card, 61, 4 * S) else self:_Hide('ddh' .. i) end
        self:_Tx('ddc' .. i, Vector2.new(rp.X + 8 * S, rp.Y + 3 * S), tostring(c),
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

    local name, tail = 'nexora', ' | v1.0'
    local fs = 14
    local nw = #name * 7.4
    local tw = #tail * 6.4
    local w = nw + tw + 40
    local h = 26
    local x = vp.X - w - 16
    local y = 16

    self:_Round('wmbg', Vector2.new(x, y), Vector2.new(w, h), t.card, 901, 6)
    self:_Round('wmbr', Vector2.new(x, y), Vector2.new(w, h), t.border, 900, 6)
    self:_Ci('wmdot', Vector2.new(x + 17, y + h / 2), 4, t.accent, 903)
    self:_Ci('wmdotg', Vector2.new(x + 17, y + h / 2), 7, t.accent, 902, 0.25)
    self:_Tx('wmn', Vector2.new(x + 28, y + 6), name, t.text, 903, fs, false, true)
    self:_Tx('wmv', Vector2.new(x + 28 + nw, y + 6), tail, t.head, 903, fs)

    self._a = keep
end

function UI:_Shadow()
    local t, S = self.theme, self.scale
    for i = 1, 4 do
        local g = i * 3 * S
        self:_Round('sh' .. i, Vector2.new(self.x - g, self.y - g + 2 * S),
                    Vector2.new(self.w * S + g * 2, self.h * S + g * 2), t.shadow, 1, (10 + i * 3) * S, 0.1)
    end
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

    if self:Held('m1') then
        if self._drag then
            local m = self:Mouse()
            self.x, self.y = m.X - self._drag.X, m.Y - self._drag.Y
        elseif click and self:In(Vector2.new(self.x, self.y),
                                 Vector2.new(self.w * self.scale, 56 * self.scale)) then
            local m = self:Mouse()
            self._drag = Vector2.new(m.X - self.x, m.Y - self.y)
            click = false
        end
    else
        self._drag = nil
    end

    self:_Shadow()
    click = self:_Drop(click)
    click = self:_Sidebar(click)
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


local NX = { UI = UI }
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

NX.placeId = 0
pcall(function() NX.placeId = game.PlaceId end)
NX.gameName = "unknown"
function NX.placeConfig() return "place_" .. tostring(NX.placeId) end

local CFG = {
    stats = { minair = 0.12, minpeak = 0.4 },
    ind = { vel = true, graph = false, binds = true, stats = true, cues = true,
            font = 30, yoff = 425, graph_yoff = 500, stats_yoff = 300,
            cue_time = 1.1, cue_rise = 26, cue_yoff = 0.42 },
}

local ST = {
    imp = { untilT = 0, x = 0, z = 0, ground = false },
    js = { air = false, wasG = true, t0 = 0, p0 = nil, sp0 = 0, peak = 0, last = nil },
    cue = {},
    root = nil,
    graph = {}, disp = 0, last = 0,
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

local function cue(text)
    if not CFG.ind.cues then return end
    local now = os.clock()
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

local function drawIndicators()
    local t = UI.theme
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local _, root = parts()
    local speed = 0
    if root then
        local v = root.AssemblyLinearVelocity
        speed = Vector3.new(v.X, 0, v.Z).Magnitude * (250 / 19)
    end
    ST.disp = ST.disp + (speed - ST.disp) * 0.25

    hud(function()
        if CFG.ind.vel and root then
            local txt = tostring(math.floor(ST.disp + 0.5))
            UI:_Tx('iv_s', Vector2.new(vp.X / 2 + 2, vp.Y - CFG.ind.yoff + 2), txt,
                   Color3.fromRGB(0, 0, 0), 800, CFG.ind.font, true, true, 0.5)
            UI:_Tx('iv', Vector2.new(vp.X / 2, vp.Y - CFG.ind.yoff), txt,
                   t.text, 801, CFG.ind.font, true, true)
        end

        if CFG.ind.graph and root then
            table.insert(ST.graph, ST.disp)
            while #ST.graph > 120 do table.remove(ST.graph, 1) end
            local gw, gh = 320, 46
            local gx = vp.X / 2 - gw / 2
            local gy = vp.Y - CFG.ind.graph_yoff
            for i = 1, #ST.graph - 1 do
                local v1, v2 = ST.graph[i], ST.graph[i + 1]
                local x1 = gx + gw * (i - 1) / 119
                local x2 = gx + gw * i / 119
                local y1 = gy + gh - math.min(v1, 350) / 350 * gh
                local y2 = gy + gh - math.min(v2, 350) / 350 * gh
                local d = UI._draw['ig' .. i]
                if not d then d = Drawing.new('Line') UI._draw['ig' .. i] = d end
                UI._used['ig' .. i] = true
                d.From, d.To = Vector2.new(x1, y1), Vector2.new(x2, y2)
                d.Color, d.Thickness, d.ZIndex = t.accent, 1, 800
                d.Transparency, d.Visible = 1, true
            end
        else
            ST.graph = {}
        end

        if CFG.ind.cues then
            local now = os.clock()
            for i = #ST.cue, 1, -1 do
                if now - ST.cue[i].at > CFG.ind.cue_time then table.remove(ST.cue, i) end
            end
            for i, c in ipairs(ST.cue) do
                local age = (now - c.at) / CFG.ind.cue_time
                local a = 1 - age * age
                local y = vp.Y * CFG.ind.cue_yoff - age * CFG.ind.cue_rise
                       - (#ST.cue - i) * 22
                UI:_Tx('cu' .. i .. 's', Vector2.new(vp.X / 2 + 2, y + 2), c.t,
                       Color3.fromRGB(0, 0, 0), 805, 19, true, true, a * 0.45)
                UI:_Tx('cu' .. i, Vector2.new(vp.X / 2, y), c.t, t.accent, 806, 19, true, true, a)
            end
        end

        if CFG.ind.stats and ST.js.last then
            local L = ST.js.last
            local rows = {
                { 'takeoff', string.format('%.0f', L.take) },
                { 'land', string.format('%.0f', L.land) },
                { 'distance', string.format('%.1f', L.dist) },
                { 'airtime', string.format('%.2fs', L.air) },
                { 'peak', string.format('%.1f', L.peak) },
            }
            local bw, rh = 132, 17
            local bx = 16
            local by = vp.Y - CFG.ind.stats_yoff
            UI:_Round('js_b', Vector2.new(bx, by), Vector2.new(bw, rh * #rows + 28), t.card, 800, 6)
            UI:_Round('js_r', Vector2.new(bx, by), Vector2.new(bw, rh * #rows + 28), t.border, 799, 6)
            UI:_Tx('js_h', Vector2.new(bx + 10, by + 7), 'LAST JUMP', t.head, 802, 11)
            for i, r in ipairs(rows) do
                local ry = by + 24 + (i - 1) * rh
                UI:_Tx('js_k' .. i, Vector2.new(bx + 10, ry), r[1], t.dim, 802, 12)
                UI:_Tx('js_v' .. i, Vector2.new(bx + bw - 10, ry), r[2], t.text, 802, 12)
                local d = UI._draw['js_v' .. i]
                if d then d.Center = false d.Position = Vector2.new(bx + bw - 10 - #r[2] * 6.2, ry) end
            end
        end

        if CFG.ind.binds then
            local shown = {}
            for _, k in ipairs(ST.order) do
                local lf = ST.live[k]
                local live = lf and lf() or (not lf and NX.active(k))
                local a = UI:Anim('ind_' .. k, live and 1 or 0, 14)
                if a > 0.02 then table.insert(shown, { k = k, a = a }) end
            end
            local total = 0
            for _, e in ipairs(shown) do total = total + 52 * e.a end
            local cx = vp.X / 2 - total / 2
            for _, e in ipairs(shown) do
                local x = cx + 26 * e.a
                local y = vp.Y - CFG.ind.yoff + 38
                UI:_Tx('ib_' .. e.k .. 's', Vector2.new(x + 2, y + 2), ST.short[e.k],
                       Color3.fromRGB(0, 0, 0), 800, 22, true, true, 0.5 * e.a)
                UI:_Tx('ib_' .. e.k, Vector2.new(x, y), ST.short[e.k],
                       t.accent, 801, 22, true, true, e.a)
                cx = cx + 52 * e.a
            end
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
                            if e.v ~= nil then
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

local ind = UI:Tab("visuals", "Indicators")
local disp = ind:Section("Display", "left")
disp:Toggle("Velocity indicator", CFG.ind.vel, function(v) CFG.ind.vel = v end)
disp:Toggle("Velocity graph", CFG.ind.graph, function(v) CFG.ind.graph = v end)
disp:Toggle("Keybind indicators", CFG.ind.binds, function(v) CFG.ind.binds = v end)
disp:Toggle("Jump stats", CFG.ind.stats, function(v) CFG.ind.stats = v end)
disp:Toggle("Trick cues", CFG.ind.cues, function(v) CFG.ind.cues = v end)

local style = ind:Section("Style", "right")
style:Slider("Font size", CFG.ind.font, 1, 10, 60, "px", function(v) CFG.ind.font = v end)
style:Slider("Y offset", CFG.ind.yoff, 5, 100, 700, "px", function(v) CFG.ind.yoff = v end)
style:Slider("Graph offset", CFG.ind.graph_yoff, 5, 100, 800, "px", function(v) CFG.ind.graph_yoff = v end)
style:Slider("Stats offset", CFG.ind.stats_yoff, 5, 60, 900, "px", function(v) CFG.ind.stats_yoff = v end)
style:Slider("Cue time", CFG.ind.cue_time, 0.1, 0.3, 4, "s", function(v) CFG.ind.cue_time = v end)

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
local gs = cfgTab:Section("Game", "right")
gs:Label(NX.gameName or 'unknown')
gs:Label("place " .. tostring(NX.placeId or 0))
pgT = gs:Toggle("Per-game config", true)
gs:Button("Save for this game", function()
    saveConfig(NX.placeConfig())
    list.item.choices = configList()
end)
gs:Button("Load for this game", function() loadConfig(NX.placeConfig()) end)

local autoT = cs:Toggle("Auto-load selected", false)
cs:Button("Refresh list", function() list.item.choices = configList() end)


RunService.Stepped:Connect(function()
    for _, fn in ipairs(physicsHooks) do
        local ok, err = pcall(fn)
        if not ok then warn("[nx] " .. tostring(err)) end
    end
end)

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
    if group and UI._groups[group] then
        UI._tab = UI._groups[group].tabs[tab]
    end
    ensureDir()
    pcall(function()
        local pg = NX.placeConfig()
        if isfile(CONFIG_DIR .. "/" .. pg .. ".json") then loadConfig(pg) return end
        if isfile(CONFIG_DIR .. "/autoload.cfg") then
            local n = readfile(CONFIG_DIR .. "/autoload.cfg")
            if n and n ~= "" then loadConfig(n) end
        end
    end)
    UI:Run()
end

return NX
