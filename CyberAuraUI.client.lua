--[[
	CYBER//AURA v2  -  LocalScript (CLIENT)
	Đặt vào: StarterPlayer > StarterPlayerScripts   (LocalScript)

	- UI cyberpunk (cuộn được, vừa màn hình điện thoại), nút AURA / RightShift để đóng mở
	- AURA ON/OFF
	- CÁNH: bật = 2 cánh, tắt = 1 cánh (cánh cong nhiều lớp, đổi màu được)
	- TẤN CÔNG: cánh phóng lưỡi sáng vào người chơi gần nhất (chỉ là hiệu ứng, KHÔNG gây sát thương)
	- AURA MẠNH: thêm quả cầu, thêm vỏ năng lượng, sóng xung kích, nhiều hạt hơn hẳn
	- Màu: thanh R/G/B + màu có sẵn
	Tất cả là client-side: chỉ mình bạn nhìn thấy.
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris           = game:GetService("Debris")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------
local state = {
	aura     = true,
	twoWings = true,
	attack   = false,
	boost    = false,
	color    = Color3.fromRGB(0, 255, 240),
}

--------------------------------------------------------------------
-- EFFECT CONTAINERS
--------------------------------------------------------------------
local oldFx = workspace:FindFirstChild("CyberAuraFX")
if oldFx then oldFx:Destroy() end
local oldProj = workspace:FindFirstChild("CyberAuraProj")
if oldProj then oldProj:Destroy() end

local fx = Instance.new("Folder")
fx.Name = "CyberAuraFX"

local boostFolder = Instance.new("Folder")
boostFolder.Name = "Boost"

local projFolder = Instance.new("Folder")
projFolder.Name = "CyberAuraProj"
projFolder.Parent = workspace

local colorParts, trails, emitters, lights = {}, {}, {}, {}

local function newPart(size, shape, parent)
	local p = Instance.new("Part")
	p.Anchored   = true
	p.CanCollide = false
	p.CanQuery   = false
	p.CanTouch   = false
	p.CastShadow = false
	p.Material   = Enum.Material.Neon
	p.Color      = state.color
	p.Size       = size
	if shape then p.Shape = shape end
	p.Parent = parent
	table.insert(colorParts, p)
	return p
end

local function addTrail(part, offset, lifetime)
	local a0 = Instance.new("Attachment"); a0.Position = offset;  a0.Parent = part
	local a1 = Instance.new("Attachment"); a1.Position = -offset; a1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = lifetime
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(state.color)
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Parent = part
	table.insert(trails, tr)
	return tr
end

local function addEmitter(parent, base, boost, cfg)
	cfg = cfg or {}
	local e = Instance.new("ParticleEmitter")
	e.Color         = ColorSequence.new(state.color)
	e.LightEmission = 1
	e.Rate          = base
	e.Lifetime      = cfg.life   or NumberRange.new(1, 2)
	e.Speed         = cfg.speed  or NumberRange.new(1, 3)
	e.Acceleration  = cfg.accel  or Vector3.new(0, 3, 0)
	e.SpreadAngle   = cfg.spread or Vector2.new(180, 180)
	e.Rotation      = NumberRange.new(0, 360)
	local sz = cfg.size or 0.7
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sz),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Parent = parent
	table.insert(emitters, { e = e, base = base, boost = boost })
	return e
end

-- Core: part vô hình đi theo thân
local core = Instance.new("Part")
core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch = true, false, false, false
core.Transparency = 1
core.Size = Vector3.new(3.5, 5.5, 3.5)
core.Parent = fx

addEmitter(core, 60, 220, { life = NumberRange.new(1, 2.2), speed = NumberRange.new(1, 4), size = 0.9 })
addEmitter(core, 25, 130, { life = NumberRange.new(1.2, 2.6), speed = NumberRange.new(5, 10), accel = Vector3.new(0, 4, 0), size = 0.5, spread = Vector2.new(25, 25) })

local light = Instance.new("PointLight")
light.Range, light.Brightness, light.Color = 14, 1.5, state.color
light.Parent = core
table.insert(lights, light)

-- Hạt dưới chân (xoáy quanh chân)
local ground = Instance.new("Part")
ground.Anchored, ground.CanCollide, ground.CanQuery, ground.CanTouch = true, false, false, false
ground.Transparency = 1
ground.Size = Vector3.new(7, 0.2, 7)
ground.Parent = fx
addEmitter(ground, 25, 120, { life = NumberRange.new(0.8, 1.6), speed = NumberRange.new(0.5, 2), accel = Vector3.new(0, 7, 0), size = 0.8, spread = Vector2.new(10, 10) })

-- Halo trên đầu
local HALO_N = 20
local halo = {}
for i = 1, HALO_N do
	halo[i] = newPart(Vector3.new(0.22, 0.22, 0.22), nil, fx)
end

-- Quả cầu xoay
local ringDefs = {
	{ tiltX = math.rad(20),  tiltZ = math.rad(0),   speed =  2.2, radius = 3.4, orbs = 4 },
	{ tiltX = math.rad(-25), tiltZ = math.rad(35),  speed = -1.8, radius = 3.8, orbs = 4 },
	{ tiltX = math.rad(15),  tiltZ = math.rad(-40), speed =  1.4, radius = 3.0, orbs = 3 },
	-- chỉ hiện khi AURA MẠNH
	{ tiltX = math.rad(60),  tiltZ = math.rad(10),  speed =  3.2, radius = 5.0, orbs = 5, boost = true },
	{ tiltX = math.rad(-50), tiltZ = math.rad(-30), speed = -2.8, radius = 5.8, orbs = 5, boost = true },
	{ tiltX = math.rad(5),   tiltZ = math.rad(50),  speed =  2.4, radius = 4.4, orbs = 4, boost = true },
}
local orbs = {}
for _, def in ipairs(ringDefs) do
	for j = 1, def.orbs do
		local size = def.boost and 0.65 or 0.5
		local o = newPart(Vector3.new(size, size, size), Enum.PartType.Ball, def.boost and boostFolder or fx)
		addTrail(o, Vector3.new(0, 0.3, 0), 0.6)
		table.insert(orbs, { part = o, ring = def, phase = (j - 1) * (math.pi * 2 / def.orbs), boost = def.boost })
	end
end

-- Vỏ năng lượng (AURA MẠNH)
local shell = newPart(Vector3.new(7, 7, 7), Enum.PartType.Ball, boostFolder)
shell.Transparency = 0.85

--------------------------------------------------------------------
-- CÁNH (cong, nhiều lớp)
--------------------------------------------------------------------
local FEATHER_LEN = { 2.6, 3.4, 4.2, 5.0, 5.6, 5.8, 5.2, 4.0 } -- từ dưới lên trên
local SEG   = 4
local SEG_W = { 0.62, 0.52, 0.38, 0.22 }
local BEND  = math.rad(-9)

local wings = {}
for _, side in ipairs({ 1, -1 }) do
	local folder = Instance.new("Folder")
	folder.Name = side == 1 and "WingRight" or "WingLeft"
	folder.Parent = fx
	local feathers = {}
	for k = 0, #FEATHER_LEN - 1 do
		local f = { ang0 = math.rad(-50 + k * 16), len = FEATHER_LEN[k + 1], segs = {} }
		for s = 1, SEG do
			f.segs[s] = newPart(Vector3.new(1, SEG_W[s], 0.08), nil, folder)
		end
		local tip = f.segs[SEG]
		if k >= 3 then addTrail(tip, Vector3.new(0, 0.12, 0), 0.45) end
		if k >= 5 then
			addEmitter(tip, 6, 22, { life = NumberRange.new(0.6, 1.3), speed = NumberRange.new(0.5, 2), size = 0.5 })
		end
		feathers[#feathers + 1] = f
	end
	wings[side] = { folder = folder, feathers = feathers, vis = 1, rootCF = CFrame.new() }
end

--------------------------------------------------------------------
-- MÀU / BOOST
--------------------------------------------------------------------
local function applyColor(c)
	state.color = c
	for _, p in ipairs(colorParts) do p.Color = c end
	for _, t in ipairs(trails)     do t.Color = ColorSequence.new(c) end
	for _, e in ipairs(emitters)   do e.e.Color = ColorSequence.new(c) end
	for _, l in ipairs(lights)     do l.Color = c end
end

local function setBoost(v)
	state.boost = v
	boostFolder.Parent = v and fx or nil
	for _, e in ipairs(emitters) do e.e.Rate = v and e.boost or e.base end
	light.Brightness = v and 4 or 1.5
	light.Range      = v and 28 or 14
end

--------------------------------------------------------------------
-- HIỆU ỨNG TẠM: sóng xung kích, nổ hạt, lưỡi tấn công
--------------------------------------------------------------------
local function spawnWave(pos, radius, dur, startT)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = state.color
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = startT or 0.35
	p.Size = Vector3.new(0.25, 1, 1)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = projFolder
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.25, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, dur + 0.2)
end

local function burst(pos)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = projFolder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(state.color)
	e.LightEmission = 1
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(10, 24)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = p
	e:Emit(45)
	Debris:AddItem(p, 1.5)
end

local function bez(p0, mid, p2, x)
	local a = 1 - x
	return p0 * (a * a) + mid * (2 * a * x) + p2 * (x * x)
end

local projectiles = {}
local pulse = 0

local function strike()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local targetHRP, bestD = nil, 90
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and pl.Character then
			local h = pl.Character:FindFirstChild("HumanoidRootPart")
			if h then
				local d = (h.Position - hrp.Position).Magnitude
				if d < bestD then bestD, targetHRP = d, h end
			end
		end
	end
	local fallback = hrp.Position + hrp.CFrame.LookVector * 28 -- không có ai => bắn thử phía trước

	pulse = 1
	for side, w in pairs(wings) do
		if w.vis > 0.5 then
			local origin = w.rootCF.Position + Vector3.new(0, 2, 0)
			for i = 1, 4 do
				table.insert(projectiles, {
					part = nil, t = -(i - 1) * 0.07, dur = 0.45, p0 = origin, side = side,
					jitter = Vector3.new(math.random(-100, 100) / 100 * 1.2, math.random(-100, 100) / 100 * 1.2, math.random(-100, 100) / 100 * 1.2),
					target = targetHRP, fallback = fallback,
				})
			end
		end
	end
end

--------------------------------------------------------------------
-- VÒNG LẶP CHÍNH
--------------------------------------------------------------------
local t = 0
local fxVisible = false
local atkCd, waveT = 0, 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local lastChar = nil

RunService.RenderStepped:Connect(function(dt)
	t += dt
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	local shouldShow = state.aura and hrp ~= nil
	if shouldShow ~= fxVisible then
		fxVisible = shouldShow
		fx.Parent = shouldShow and workspace or nil
		if shouldShow and state.boost then boostFolder.Parent = fx end
	end

	-- cập nhật đạn đang bay (kể cả khi aura tắt giữa chừng)
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		pr.t += dt
		if pr.t >= 0 then
			if not pr.part then
				local part = Instance.new("Part")
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
				part.Material = Enum.Material.Neon
				part.Color = state.color
				part.Size = Vector3.new(0.3, 0.3, 2.6)
				part.CFrame = CFrame.new(pr.p0)
				part.Parent = projFolder
				addTrail(part, Vector3.new(0.25, 0, 0), 0.35)
				pr.part = part
			end
			local u = math.min(pr.t / pr.dur, 1)
			local tp = ((pr.target and pr.target.Parent) and pr.target.Position or pr.fallback) + pr.jitter
			local mid = (pr.p0 + tp) / 2 + Vector3.new(pr.side * 4, 5, 0) + pr.jitter * 2
			local pos = bez(pr.p0, mid, tp, u)
			local nxt = bez(pr.p0, mid, tp, math.min(u + 0.03, 1))
			if (nxt - pos).Magnitude > 0.01 then
				pr.part.CFrame = CFrame.lookAt(pos, nxt)
			else
				pr.part.CFrame = CFrame.new(pos)
			end
			if u >= 1 then
				burst(tp)
				spawnWave(tp - Vector3.new(0, 2.5, 0), 6, 0.5, 0.4)
				pr.part:Destroy()
				table.remove(projectiles, i)
			end
		end
	end

	if not shouldShow then return end

	if char ~= lastChar then
		lastChar = char
		rayParams.FilterDescendantsInstances = { char, fx, projFolder }
	end

	local base   = hrp.CFrame
	local center = hrp.Position
	core.CFrame  = CFrame.new(center)

	-- chân
	local hit = workspace:Raycast(center, Vector3.new(0, -12, 0), rayParams)
	local feet = hit and (hit.Position + Vector3.new(0, 0.15, 0)) or (center - Vector3.new(0, 3, 0))
	ground.CFrame = CFrame.new(feet)

	local boost = state.boost
	local spd = boost and 1.6 or 1

	-- Halo
	local haloR = boost and 1.25 or 0.95
	local hc = center + Vector3.new(0, 3.1 + math.sin(t * 2) * 0.12, 0)
	for i, b in ipairs(halo) do
		local a = t * 1.5 * spd + (i / HALO_N) * math.pi * 2
		b.CFrame = CFrame.new(hc + Vector3.new(math.cos(a) * haloR, 0, math.sin(a) * haloR))
	end

	-- Quả cầu
	for _, o in ipairs(orbs) do
		if not o.boost or boost then
			local r = o.ring
			local a = t * r.speed + o.phase
			local ringCF = CFrame.new(center) * CFrame.Angles(r.tiltX, t * 0.25, r.tiltZ)
			o.part.CFrame = CFrame.new(ringCF:PointToWorldSpace(Vector3.new(math.cos(a) * r.radius, 0, math.sin(a) * r.radius)))
		end
	end

	-- Vỏ năng lượng
	if boost then
		local s = 7 + math.sin(t * 5) * 0.6
		shell.Size = Vector3.new(s, s, s)
		shell.CFrame = CFrame.new(center)
	end

	-- Sóng xung kích
	waveT -= dt
	if waveT <= 0 then
		if boost then
			spawnWave(feet, 16, 0.9, 0.35)
			waveT = 0.7
		else
			spawnWave(feet, 8, 1.1, 0.55)
			waveT = 2.6
		end
	end

	-- Tấn công
	if state.attack then
		atkCd -= dt
		if atkCd <= 0 then
			strike()
			atkCd = boost and 0.9 or 1.4
		end
	end
	pulse = math.max(0, pulse - dt * 2.5)

	-- Cánh
	local flapSpeed = (state.attack and 4.2 or 2.4)
	local flap = math.sin(t * flapSpeed)
	for side, w in pairs(wings) do
		local target = (side == 1 or state.twoWings) and 1 or 0
		w.vis += (target - w.vis) * math.min(1, dt * 7)

		if w.vis < 0.03 then
			w.folder.Parent = nil
		else
			w.folder.Parent = fx
			local yaw = -side * math.rad(22 + flap * 12 - pulse * 75)
			local root = base * CFrame.new(side * 0.45, 0.7, 0.55) * CFrame.Angles(0, yaw, 0)
			w.rootCF = root
			local sc = (0.25 + 0.75 * w.vis) * (1 + pulse * 0.25)
			local tr = 0.05 + (1 - w.vis) * 0.95

			for k, f in ipairs(w.feathers) do
				local ang = f.ang0 + flap * math.rad(5 + k * 0.8) * 1 + math.sin(t * flapSpeed - k * 0.35) * math.rad(3)
				local pos = Vector3.zero
				local segLen = (f.len * sc) / SEG
				for s = 1, SEG do
					local theta = side == 1 and ang or (math.pi - ang)
					local dir = Vector3.new(math.cos(theta), math.sin(theta), 0)
					local part = f.segs[s]
					part.Size = Vector3.new(segLen + 0.06, SEG_W[s], 0.08)
					part.CFrame = root * CFrame.new(pos + dir * (segLen / 2)) * CFrame.Angles(0, 0, theta)
					part.Transparency = tr
					pos = pos + dir * segLen
					ang += BEND
				end
			end
		end
	end
end)

--------------------------------------------------------------------
-- UI (cyberpunk)
--------------------------------------------------------------------
local BG      = Color3.fromRGB(10, 9, 22)
local PANEL2  = Color3.fromRGB(20, 17, 40)
local CYAN    = Color3.fromRGB(0, 255, 240)
local MAGENTA = Color3.fromRGB(255, 0, 170)
local YELLOW  = Color3.fromRGB(252, 238, 10)
local DIM     = Color3.fromRGB(120, 120, 160)
local FONT    = Enum.Font.Code

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function neonStroke(parent, thickness)
	local s = make("UIStroke", { Thickness = thickness or 1.5, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
	local g = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CYAN),
			ColorSequenceKeypoint.new(0.5, MAGENTA),
			ColorSequenceKeypoint.new(1, CYAN),
		}),
	}, s)
	return s, g
end

local old = playerGui:FindFirstChild("CyberAuraUI")
if old then old:Destroy() end

local gui = make("ScreenGui", {
	Name = "CyberAuraUI", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local gradients = {}

-- Nút đóng/mở UI
local openBtn = make("TextButton", {
	Name = "OpenButton", Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 16, 0.5, -28),
	BackgroundColor3 = BG, Text = "AURA", TextColor3 = CYAN, Font = FONT, TextSize = 14,
	AutoButtonColor = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, openBtn)
do local _, g = neonStroke(openBtn, 2); table.insert(gradients, g) end

-- Panel (chiều cao tự co theo màn hình)
local viewY = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700
local panelH = math.clamp(viewY - 40, 220, 500)

local panel = make("CanvasGroup", {
	Name = "Panel", Size = UDim2.fromOffset(300, panelH), AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 84, 0.5, 0), BackgroundColor3 = BG, BorderSizePixel = 0,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, panel)
do local _, g = neonStroke(panel, 2); table.insert(gradients, g) end
local scale = make("UIScale", { Scale = 1 }, panel)

local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = PANEL2, BorderSizePixel = 0 }, panel)
make("TextLabel", {
	Size = UDim2.new(1, -60, 0, 24), Position = UDim2.fromOffset(14, 5), BackgroundTransparency = 1,
	Text = "CYBER//AURA", TextColor3 = CYAN, Font = FONT, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)
make("TextLabel", {
	Size = UDim2.new(1, -60, 0, 14), Position = UDim2.fromOffset(14, 27), BackgroundTransparency = 1,
	Text = "// client-side  ·  chỉ mình bạn thấy", TextColor3 = MAGENTA, Font = FONT, TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)
local closeBtn = make("TextButton", {
	Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -38, 0, 8), BackgroundColor3 = BG,
	Text = "X", TextColor3 = MAGENTA, Font = FONT, TextSize = 16, AutoButtonColor = false,
}, titleBar)
make("UICorner", { CornerRadius = UDim.new(0, 4) }, closeBtn)
make("UIStroke", { Color = MAGENTA, Thickness = 1.5 }, closeBtn)

local content = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = CYAN,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)
make("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 12),
}, content)
make("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, content)

local order = 0
local function nextOrder() order += 1; return order end

local function makeToggle(textOn, textOff, default, onChange)
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = PANEL2, LayoutOrder = nextOrder(),
	}, content)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, row)
	local label = make("TextLabel", {
		Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
		Text = "", TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local sw = make("TextButton", {
		Size = UDim2.fromOffset(52, 24), Position = UDim2.new(1, -62, 0.5, -12), Text = "",
		BackgroundColor3 = BG, AutoButtonColor = false,
	}, row)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, sw)
	local stroke = make("UIStroke", { Thickness = 1.5, Color = DIM }, sw)
	local knob = make("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = DIM }, sw)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

	local on = default
	local function render(instant)
		label.Text = on and textOn or textOff
		local info = TweenInfo.new(instant and 0 or 0.18, Enum.EasingStyle.Quad)
		local col = on and CYAN or DIM
		TweenService:Create(knob, info, {
			Position = on and UDim2.fromOffset(31, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = col,
		}):Play()
		TweenService:Create(stroke, info, { Color = col }):Play()
	end
	render(true)
	sw.MouseButton1Click:Connect(function()
		on = not on
		render(false)
		onChange(on)
	end)
end

makeToggle("AURA : ON", "AURA : OFF", state.aura, function(v) state.aura = v end)
makeToggle("CÁNH : 2 CÁNH", "CÁNH : 1 CÁNH", state.twoWings, function(v) state.twoWings = v end)
makeToggle("TẤN CÔNG : ON", "TẤN CÔNG : OFF", state.attack, function(v)
	state.attack = v
	atkCd = 0
end)
makeToggle("AURA MẠNH : ON", "AURA MẠNH : OFF", state.boost, function(v) setBoost(v) end)

-- Màu
local colorHeader = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, content)
make("TextLabel", {
	Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = "> MÀU CÁNH / AURA", TextColor3 = YELLOW,
	Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, colorHeader)
local preview = make("Frame", { Size = UDim2.fromOffset(30, 16), Position = UDim2.new(1, -30, 0, 3), BackgroundColor3 = state.color }, colorHeader)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, preview)
make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1 }, preview)

local sliders = {}
local function pushColor()
	local c = Color3.fromRGB(sliders.R.value, sliders.G.value, sliders.B.value)
	preview.BackgroundColor3 = c
	applyColor(c)
end

local function makeSlider(key, tint, init)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, content)
	make("TextLabel", {
		Size = UDim2.fromOffset(16, 26), BackgroundTransparency = 1, Text = key, TextColor3 = tint, Font = FONT, TextSize = 14,
	}, row)
	local valueLabel = make("TextLabel", {
		Size = UDim2.fromOffset(32, 26), Position = UDim2.new(1, -32, 0, 0), BackgroundTransparency = 1,
		Text = tostring(init), TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 13,
	}, row)
	local hit = make("TextButton", {
		Size = UDim2.new(1, -60, 0, 26), Position = UDim2.fromOffset(24, 0), BackgroundTransparency = 1, Text = "",
	}, row)
	local track = make("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), BackgroundColor3 = BG, BorderSizePixel = 0 }, hit)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	make("UIStroke", { Color = tint, Thickness = 1, Transparency = 0.5 }, track)
	local fill = make("Frame", { Size = UDim2.fromScale(init / 255, 1), BackgroundColor3 = tint, BorderSizePixel = 0 }, track)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local knob = make("Frame", {
		Size = UDim2.fromOffset(12, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(init / 255, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, knob)

	local s = { value = init }
	sliders[key] = s

	function s.set(v)
		v = math.clamp(math.floor(v + 0.5), 0, 255)
		s.value = v
		valueLabel.Text = tostring(v)
		fill.Size = UDim2.fromScale(v / 255, 1)
		knob.Position = UDim2.new(v / 255, 0, 0.5, 0)
	end

	local dragging = false
	local function fromX(x)
		local a = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		s.set(math.clamp(a, 0, 1) * 255)
		pushColor()
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			content.ScrollingEnabled = false -- tránh cuộn khi đang kéo thanh trượt
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				content.ScrollingEnabled = true
			end
		end
	end)
end

local c0 = state.color
makeSlider("R", Color3.fromRGB(255, 70, 90),  math.floor(c0.R * 255 + 0.5))
makeSlider("G", Color3.fromRGB(70, 255, 120), math.floor(c0.G * 255 + 0.5))
makeSlider("B", Color3.fromRGB(80, 140, 255), math.floor(c0.B * 255 + 0.5))

local presets = {
	Color3.fromRGB(0, 255, 240), Color3.fromRGB(255, 0, 200), Color3.fromRGB(252, 238, 10),
	Color3.fromRGB(255, 40, 40), Color3.fromRGB(60, 255, 60), Color3.fromRGB(255, 255, 255),
}
local presetRow = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, content)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center,
}, presetRow)
for _, c in ipairs(presets) do
	local b = make("TextButton", { Size = UDim2.fromOffset(36, 28), BackgroundColor3 = c, Text = "", AutoButtonColor = false }, presetRow)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
	make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.6 }, b)
	b.MouseButton1Click:Connect(function()
		sliders.R.set(c.R * 255); sliders.G.set(c.G * 255); sliders.B.set(c.B * 255)
		pushColor()
	end)
end

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = nextOrder(), TextWrapped = true,
	Text = "Tấn công chỉ là hiệu ứng, không gây sát thương.\nRightShift = đóng/mở UI", TextColor3 = DIM, Font = FONT, TextSize = 11,
}, content)

-- Đóng / mở
local open = true
local function setOpen(v)
	open = v
	if v then panel.Visible = true end
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(panel, info, { GroupTransparency = v and 0 or 1 }):Play()
	local tw = TweenService:Create(scale, info, { Scale = v and 1 or 0.85 })
	tw.Completed:Connect(function()
		if not open then panel.Visible = false end
	end)
	tw:Play()
end
openBtn.MouseButton1Click:Connect(function() setOpen(not open) end)
closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.RightShift then setOpen(not open) end
end)

-- Kéo panel bằng thanh tiêu đề
do
	local dragging, startMouse, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startMouse, startPos = true, input.Position, panel.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startMouse
			panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

RunService.RenderStepped:Connect(function(dt)
	for _, g in ipairs(gradients) do g.Rotation = (g.Rotation + dt * 90) % 360 end
end)
