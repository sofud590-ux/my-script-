--[[
	CYBER//AURA v3 (MULTIPLAYER)  -  LocalScript
	Đặt vào: StarterPlayer > StarterPlayerScripts   (LocalScript)
	Cần thêm Script server: CyberAuraServer (ServerScriptService)

	- Mỗi người chơi có một "rig" (aura + cánh) vẽ ở máy mình.
	- Khi bạn bấm nút, trạng thái được gửi lên server, server báo cho người khác => họ thấy aura/cánh của bạn.
	- Tấn công chỉ là hiệu ứng, KHÔNG gây sát thương.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Debris            = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CULL_DIST = 250 -- người chơi xa hơn khoảng này thì không vẽ hiệu ứng

--------------------------------------------------------------------
-- REMOTE
--------------------------------------------------------------------
local remote = ReplicatedStorage:WaitForChild("CyberAuraEvent", 10)
if not remote then
	warn("[CyberAura] Không thấy CyberAuraEvent. Hãy thêm Script CyberAuraServer vào ServerScriptService. Đang chạy chế độ chỉ mình bạn thấy.")
end

--------------------------------------------------------------------
-- CONTAINERS
--------------------------------------------------------------------
for _, n in ipairs({ "CyberAuraFX", "CyberAuraProj" }) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
local rigsRoot = Instance.new("Folder"); rigsRoot.Name = "CyberAuraFX";   rigsRoot.Parent = workspace
local projFolder = Instance.new("Folder"); projFolder.Name = "CyberAuraProj"; projFolder.Parent = workspace

--------------------------------------------------------------------
-- HÀM DÙNG CHUNG (hiệu ứng tạm)
--------------------------------------------------------------------
local function mkTrail(part, offset, lifetime, color)
	local a0 = Instance.new("Attachment"); a0.Position = offset;  a0.Parent = part
	local a1 = Instance.new("Attachment"); a1.Position = -offset; a1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = lifetime
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(color)
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.Parent = part
	return tr
end

local function spawnWave(pos, radius, dur, startT, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
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

local function burst(pos, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	p.Parent = projFolder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
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

local function copyState(s)
	return { aura = s.aura, twoWings = s.twoWings, attack = s.attack, boost = s.boost, swords = s.swords, fly = s.fly, color = s.color }
end

--------------------------------------------------------------------
-- RIG: aura + cánh của MỘT người chơi
--------------------------------------------------------------------
local FEATHER_LEN = { 2.6, 3.4, 4.2, 5.0, 5.6, 5.8, 5.2, 4.0 }
local SEG   = 4
local SEG_W = { 0.62, 0.52, 0.38, 0.22 }
local BEND  = math.rad(-9)
local HALO_N = 20
local SWORD_N = 6

local ringDefs = {
	{ tiltX = math.rad(20),  tiltZ = math.rad(0),   speed =  2.2, radius = 3.4, orbs = 4 },
	{ tiltX = math.rad(-25), tiltZ = math.rad(35),  speed = -1.8, radius = 3.8, orbs = 4 },
	{ tiltX = math.rad(15),  tiltZ = math.rad(-40), speed =  1.4, radius = 3.0, orbs = 3 },
	{ tiltX = math.rad(60),  tiltZ = math.rad(10),  speed =  3.2, radius = 5.0, orbs = 5, boost = true },
	{ tiltX = math.rad(-50), tiltZ = math.rad(-30), speed = -2.8, radius = 5.8, orbs = 5, boost = true },
	{ tiltX = math.rad(5),   tiltZ = math.rad(50),  speed =  2.4, radius = 4.4, orbs = 4, boost = true },
}

local Rig = {}
Rig.__index = Rig

function Rig:newPart(size, shape, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = self.state.color
	p.Size = size
	if shape then p.Shape = shape end
	p.Parent = parent
	table.insert(self.colorParts, p)
	return p
end

function Rig:addTrail(part, offset, lifetime)
	local tr = mkTrail(part, offset, lifetime, self.state.color)
	table.insert(self.trails, tr)
	return tr
end

function Rig:addEmitter(parent, base, boost, cfg)
	cfg = cfg or {}
	local e = Instance.new("ParticleEmitter")
	e.Color         = ColorSequence.new(self.state.color)
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
	table.insert(self.emitters, { e = e, base = base, boost = boost })
	return e
end

function Rig.new(owner, st)
	local self = setmetatable({}, Rig)
	self.owner   = owner
	self.isLocal = owner == player
	self.state   = copyState(st)
	self.t, self.atkCd, self.waveT, self.pulse = 0, 0, 0, 0
	self.flapPhase, self.flapAmp, self.flapFreq, self.lean = 0, 0.12, 1.8, 0
	self.projectiles = {}
	self.fxVisible = false
	self.lastChar = nil
	self.colorParts, self.trails, self.emitters, self.lights = {}, {}, {}, {}
	self.orbs, self.halo, self.wings = {}, {}, {}
	self.rayParams = RaycastParams.new()
	self.rayParams.FilterType = Enum.RaycastFilterType.Exclude

	self.fx = Instance.new("Folder")
	self.fx.Name = "Rig_" .. owner.UserId
	self.boostFolder = Instance.new("Folder")
	self.boostFolder.Name = "Boost"

	-- core vô hình
	local core = Instance.new("Part")
	core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch = true, false, false, false
	core.Transparency = 1
	core.Size = Vector3.new(3.5, 5.5, 3.5)
	core.Parent = self.fx
	self.core = core
	self:addEmitter(core, 60, 220, { life = NumberRange.new(1, 2.2), speed = NumberRange.new(1, 4), size = 0.9 })
	self:addEmitter(core, 25, 130, { life = NumberRange.new(1.2, 2.6), speed = NumberRange.new(5, 10), accel = Vector3.new(0, 4, 0), size = 0.5, spread = Vector2.new(25, 25) })
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color = 14, 1.5, self.state.color
	light.Parent = core
	self.light = light
	table.insert(self.lights, light)

	-- hạt dưới chân
	local ground = Instance.new("Part")
	ground.Anchored, ground.CanCollide, ground.CanQuery, ground.CanTouch = true, false, false, false
	ground.Transparency = 1
	ground.Size = Vector3.new(7, 0.2, 7)
	ground.Parent = self.fx
	self.ground = ground
	self:addEmitter(ground, 25, 120, { life = NumberRange.new(0.8, 1.6), speed = NumberRange.new(0.5, 2), accel = Vector3.new(0, 7, 0), size = 0.8, spread = Vector2.new(10, 10) })

	-- halo
	for i = 1, HALO_N do
		self.halo[i] = self:newPart(Vector3.new(0.22, 0.22, 0.22), nil, self.fx)
	end

	-- quả cầu
	for _, def in ipairs(ringDefs) do
		for j = 1, def.orbs do
			local size = def.boost and 0.65 or 0.5
			local o = self:newPart(Vector3.new(size, size, size), Enum.PartType.Ball, def.boost and self.boostFolder or self.fx)
			self:addTrail(o, Vector3.new(0, 0.3, 0), 0.6)
			table.insert(self.orbs, { part = o, ring = def, phase = (j - 1) * (math.pi * 2 / def.orbs), boost = def.boost })
		end
	end

	-- vỏ năng lượng
	self.shell = self:newPart(Vector3.new(7, 7, 7), Enum.PartType.Ball, self.boostFolder)
	self.shell.Transparency = 0.85

	-- cánh
	for _, side in ipairs({ 1, -1 }) do
		local folder = Instance.new("Folder")
		folder.Name = side == 1 and "WingRight" or "WingLeft"
		folder.Parent = self.fx
		local feathers = {}
		for k = 0, #FEATHER_LEN - 1 do
			local f = { ang0 = math.rad(-50 + k * 16), len = FEATHER_LEN[k + 1], segs = {} }
			for s = 1, SEG do
				f.segs[s] = self:newPart(Vector3.new(1, SEG_W[s], 0.08), nil, folder)
			end
			local tip = f.segs[SEG]
			if k >= 3 then self:addTrail(tip, Vector3.new(0, 0.12, 0), 0.45) end
			if k >= 5 then
				self:addEmitter(tip, 6, 22, { life = NumberRange.new(0.6, 1.3), speed = NumberRange.new(0.5, 2), size = 0.5 })
			end
			feathers[#feathers + 1] = f
		end
		self.wings[side] = { folder = folder, feathers = feathers, vis = 1, rootCF = CFrame.new() }
	end

	-- kiếm bay quanh người
	self.swords = {}
	self.swordFolder = Instance.new("Folder")
	self.swordFolder.Name = "Swords"
	for i = 1, SWORD_N do
		local blade = self:newPart(Vector3.new(0.12, 0.45, 3), nil, self.swordFolder)
		local guard = self:newPart(Vector3.new(0.16, 1.1, 0.22), nil, self.swordFolder)
		local hilt = Instance.new("Part")
		hilt.Anchored, hilt.CanCollide, hilt.CanQuery, hilt.CanTouch, hilt.CastShadow = true, false, false, false, false
		hilt.Material = Enum.Material.Metal
		hilt.Color = Color3.fromRGB(25, 25, 35)
		hilt.Size = Vector3.new(0.2, 0.2, 0.9)
		hilt.Parent = self.swordFolder
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.25, -1.5);  a0.Parent = blade
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.25, -1.5); a1.Parent = blade
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.5
		tr.LightEmission = 1
		tr.Color = ColorSequence.new(self.state.color)
		tr.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		tr.Parent = blade
		table.insert(self.trails, tr)
		table.insert(self.swords, { blade = blade, guard = guard, hilt = hilt, phase = (i - 1) * math.pi * 2 / SWORD_N, fly = nil })
	end

	self:applyColor(self.state.color)
	self:applyBoost(self.state.boost)
	return self
end

function Rig:applyColor(c)
	self.state.color = c
	for _, p in ipairs(self.colorParts) do p.Color = c end
	for _, t in ipairs(self.trails)     do t.Color = ColorSequence.new(c) end
	for _, e in ipairs(self.emitters)   do e.e.Color = ColorSequence.new(c) end
	for _, l in ipairs(self.lights)     do l.Color = c end
end

function Rig:applyBoost(v)
	self.state.boost = v
	self.boostFolder.Parent = v and self.fx or nil
	for _, e in ipairs(self.emitters) do e.e.Rate = v and e.boost or e.base end
	self.light.Brightness = v and 4 or 1.5
	self.light.Range      = v and 28 or 14
end

function Rig:setState(s)
	local old = self.state
	if s.color ~= old.color then self:applyColor(s.color) end
	if s.boost ~= old.boost then self:applyBoost(s.boost) end
	if s.attack and not old.attack then self.atkCd = 0 end
	old.aura, old.twoWings, old.attack, old.swords, old.fly = s.aura, s.twoWings, s.attack, s.swords, s.fly
end

function Rig:strike(hrp)
	local targetHRP, bestD = nil, 90
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= self.owner and pl.Character then
			local h = pl.Character:FindFirstChild("HumanoidRootPart")
			if h then
				local d = (h.Position - hrp.Position).Magnitude
				if d < bestD then bestD, targetHRP = d, h end
			end
		end
	end
	local fallback = hrp.Position + hrp.CFrame.LookVector * 28

	if self.state.swords then
		for i, sw in ipairs(self.swords) do
			if not sw.fly then
				sw.fly = {
					t = -(i - 1) * 0.08, dur = 0.5, target = targetHRP, fallback = fallback,
					jitter = Vector3.new(math.random(-100, 100) / 100 * 1.5, math.random(-100, 100) / 100 * 1.5, math.random(-100, 100) / 100 * 1.5),
				}
			end
		end
	end

	self.pulse = 1
	for side, w in pairs(self.wings) do
		if w.vis > 0.5 then
			local origin = w.rootCF.Position + Vector3.new(0, 2, 0)
			for i = 1, 4 do
				table.insert(self.projectiles, {
					part = nil, t = -(i - 1) * 0.07, dur = 0.45, p0 = origin, side = side,
					jitter = Vector3.new(math.random(-100, 100) / 100 * 1.2, math.random(-100, 100) / 100 * 1.2, math.random(-100, 100) / 100 * 1.2),
					target = targetHRP, fallback = fallback,
				})
			end
		end
	end
end

function Rig:updateProjectiles(dt)
	local color = self.state.color
	for i = #self.projectiles, 1, -1 do
		local pr = self.projectiles[i]
		pr.t += dt
		if pr.t >= 0 then
			if not pr.part then
				local part = Instance.new("Part")
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
				part.Material = Enum.Material.Neon
				part.Color = color
				part.Size = Vector3.new(0.3, 0.3, 2.6)
				part.CFrame = CFrame.new(pr.p0)
				part.Parent = projFolder
				mkTrail(part, Vector3.new(0.25, 0, 0), 0.35, color)
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
				burst(tp, color)
				spawnWave(tp - Vector3.new(0, 2.5, 0), 6, 0.5, 0.4, color)
				pr.part:Destroy()
				table.remove(self.projectiles, i)
			end
		end
	end
end

function Rig:update(dt)
	self.t += dt
	local t  = self.t
	local st = self.state
	local char = self.owner.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	local shouldShow = st.aura and hrp ~= nil
	if shouldShow and not self.isLocal then
		local cam = workspace.CurrentCamera
		if cam and (hrp.Position - cam.CFrame.Position).Magnitude > CULL_DIST then shouldShow = false end
	end
	if shouldShow ~= self.fxVisible then
		self.fxVisible = shouldShow
		self.fx.Parent = shouldShow and rigsRoot or nil
	end

	self:updateProjectiles(dt)
	if not shouldShow then return end

	if char ~= self.lastChar then
		self.lastChar = char
		self.rayParams.FilterDescendantsInstances = { char, rigsRoot, projFolder }
	end

	local base   = hrp.CFrame
	local center = hrp.Position
	self.core.CFrame = CFrame.new(center)

	local hit = workspace:Raycast(center, Vector3.new(0, -12, 0), self.rayParams)
	local feet = hit and (hit.Position + Vector3.new(0, 0.15, 0)) or (center - Vector3.new(0, 3, 0))
	self.ground.CFrame = CFrame.new(feet)

	local boost = st.boost
	local spd = boost and 1.6 or 1

	-- halo
	local haloR = boost and 1.25 or 0.95
	local hc = center + Vector3.new(0, 3.1 + math.sin(t * 2) * 0.12, 0)
	for i, b in ipairs(self.halo) do
		local a = t * 1.5 * spd + (i / HALO_N) * math.pi * 2
		b.CFrame = CFrame.new(hc + Vector3.new(math.cos(a) * haloR, 0, math.sin(a) * haloR))
	end

	-- quả cầu
	for _, o in ipairs(self.orbs) do
		if not o.boost or boost then
			local r = o.ring
			local a = t * r.speed + o.phase
			local ringCF = CFrame.new(center) * CFrame.Angles(r.tiltX, t * 0.25, r.tiltZ)
			o.part.CFrame = CFrame.new(ringCF:PointToWorldSpace(Vector3.new(math.cos(a) * r.radius, 0, math.sin(a) * r.radius)))
		end
	end

	-- vỏ năng lượng
	if boost then
		local s = 7 + math.sin(t * 5) * 0.6
		self.shell.Size = Vector3.new(s, s, s)
		self.shell.CFrame = CFrame.new(center)
	end

	-- sóng xung kích
	self.waveT -= dt
	if self.waveT <= 0 then
		if boost then
			spawnWave(feet, 16, 0.9, 0.35, st.color)
			self.waveT = 0.7
		else
			spawnWave(feet, 8, 1.1, 0.55, st.color)
			self.waveT = 2.6
		end
	end

	-- tấn công
	if st.attack then
		self.atkCd -= dt
		if self.atkCd <= 0 then
			self:strike(hrp)
			self.atkCd = boost and 0.9 or 1.4
		end
	end
	self.pulse = math.max(0, self.pulse - dt * 2.5)
	local pulse = self.pulse

	-- kiếm
	if (self.swordFolder.Parent ~= nil) ~= st.swords then
		self.swordFolder.Parent = st.swords and self.fx or nil
	end
	if st.swords then
		local r = boost and 5.2 or 4.2
		for _, sw in ipairs(self.swords) do
			local a = t * 1.6 * spd + sw.phase
			local orbitPos = center + Vector3.new(math.cos(a) * r, 0.6 + math.sin(t * 2 + sw.phase * 2) * 0.7, math.sin(a) * r)
			local cf = nil
			local fly = sw.fly
			if fly then
				fly.t += dt
				if fly.t >= 0 then
					local s = fly.t / fly.dur
					if s >= 2 then
						sw.fly = nil
					else
						local tp = ((fly.target and fly.target.Parent) and fly.target.Position or fly.fallback) + fly.jitter
						if s >= 1 and not fly.hit then
							fly.hit = true
							burst(tp, st.color)
							spawnWave(tp - Vector3.new(0, 2.5, 0), 5, 0.45, 0.4, st.color)
						end
						local f = s < 1 and s or (2 - s)
						local mid = (orbitPos + tp) / 2 + Vector3.new(0, 4, 0)
						local pos = bez(orbitPos, mid, tp, f)
						local dirv = tp - pos
						if dirv.Magnitude < 0.05 then dirv = Vector3.new(0, 0, -1) end
						cf = CFrame.lookAt(pos, pos + dirv) * CFrame.Angles(0, 0, s * 12)
					end
				end
			end
			if not cf then
				local tangent = Vector3.new(-math.sin(a), 0.25, math.cos(a))
				cf = CFrame.lookAt(orbitPos, orbitPos + tangent)
			end
			sw.blade.CFrame = cf * CFrame.new(0, 0, -1.5)
			sw.guard.CFrame = cf
			sw.hilt.CFrame = cf * CFrame.new(0, 0, 0.6)
		end
	end

	-- cánh
	-- chuyển động -> nhịp đập cánh + độ nghiêng người (giống chim)
	local vel = hrp.AssemblyLinearVelocity
	local speedN = vel.Magnitude
	local hv = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local fwd = vel:Dot(base.LookVector)
	local tAmp, tFreq, tLean
	if st.fly then
		local k = math.clamp(speedN / 60, 0, 1)
		tAmp  = math.rad(38 + 22 * k)
		tFreq = 5 + 4 * k
		tLean = -math.rad(12 + 63 * math.clamp(fwd / 60, 0, 1))
	else
		local k = math.clamp(hv / 16, 0, 1) -- đi bộ / chạy
		tAmp  = math.rad(7 + 20 * k)
		tFreq = 1.8 + 6 * k
		tLean = 0
	end
	if st.attack then tFreq += 1.5 end
	local sm = math.min(1, dt * 5)
	self.flapAmp  += (tAmp - self.flapAmp) * sm
	self.flapFreq += (tFreq - self.flapFreq) * sm
	self.lean     += (tLean - self.lean) * math.min(1, dt * 4)
	self.flapPhase += dt * self.flapFreq
	local wingBase = base * CFrame.Angles(self.lean, 0, 0)
	local flapN = math.sin(self.flapPhase)
	local flapAng = flapN * self.flapAmp
	for side, w in pairs(self.wings) do
		local target = (side == 1 or st.twoWings) and 1 or 0
		w.vis += (target - w.vis) * math.min(1, dt * 7)

		if w.vis < 0.03 then
			w.folder.Parent = nil
		else
			w.folder.Parent = self.fx
			local yaw = -side * (math.rad(st.fly and 8 or 22) + flapN * math.rad(5) - pulse * math.rad(75))
			local root = wingBase * CFrame.new(side * 0.45, 0.7, 0.55) * CFrame.Angles(0, 0, side * (flapAng + math.rad(18))) * CFrame.Angles(0, yaw, 0)
			w.rootCF = root
			local sc = (0.25 + 0.75 * w.vis) * (1 + pulse * 0.25)
			local tr = 0.05 + (1 - w.vis) * 0.95

			for k, f in ipairs(w.feathers) do
				local ang = f.ang0 + math.sin(self.flapPhase - k * 0.4) * math.rad(5) * math.clamp(self.flapAmp / 0.5, 0.3, 1.5)
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
end

function Rig:destroy()
	for _, pr in ipairs(self.projectiles) do
		if pr.part then pr.part:Destroy() end
	end
	self.projectiles = {}
	self.swordFolder:Destroy()
	self.fx:Destroy()
end

--------------------------------------------------------------------
-- QUẢN LÝ RIG + ĐỒNG BỘ
--------------------------------------------------------------------
local rigs = {}        -- [userId] = Rig
local pending = {}     -- [userId] = state (người chơi chưa load xong)

local localState = {
	aura = true, twoWings = true, attack = false, boost = false, swords = true, fly = false,
	color = Color3.fromRGB(0, 255, 240),
}
local localRig = Rig.new(player, localState)
rigs[player.UserId] = localRig

local function applyRemote(userId, st)
	if userId == player.UserId then return end
	local pl = Players:GetPlayerByUserId(userId)
	if not pl then pending[userId] = st; return end
	if rigs[userId] then
		rigs[userId]:setState(st)
	else
		rigs[userId] = Rig.new(pl, st)
	end
end

local function removeRemote(userId)
	pending[userId] = nil
	if userId == player.UserId then return end
	local r = rigs[userId]
	if r then r:destroy(); rigs[userId] = nil end
end

if remote then
	remote.OnClientEvent:Connect(function(kind, a, b)
		if kind == "state" then
			applyRemote(a, b)
		elseif kind == "remove" then
			removeRemote(a)
		elseif kind == "sync" then
			for _, e in ipairs(a) do applyRemote(e.userId, e.state) end
		end
	end)
	remote:FireServer("hello")
	remote:FireServer("state", copyState(localState))
end

Players.PlayerAdded:Connect(function(pl)
	local st = pending[pl.UserId]
	if st then
		pending[pl.UserId] = nil
		applyRemote(pl.UserId, st)
	end
	-- gửi lại trạng thái của mình để người mới thấy ngay
	if remote then remote:FireServer("state", copyState(localState)) end
end)
Players.PlayerRemoving:Connect(function(pl) removeRemote(pl.UserId) end)

-- gửi trạng thái lên server (giới hạn tốc độ, luôn gửi bản mới nhất)
local lastSend, sendQueued = 0, false
local function sendState()
	if not remote then return end
	local now = os.clock()
	if now - lastSend >= 0.12 then
		lastSend = now
		remote:FireServer("state", copyState(localState))
	elseif not sendQueued then
		sendQueued = true
		task.delay(0.12 - (now - lastSend) + 0.01, function()
			sendQueued = false
			lastSend = os.clock()
			remote:FireServer("state", copyState(localState))
		end)
	end
end

local function setLocal(key, value)
	localState[key] = value
	localRig:setState(localState)
	sendState()
end

--------------------------------------------------------------------
-- BAY (di chuyển thật trên máy bạn; nhân vật nghiêng người như chim)
--------------------------------------------------------------------
local flySpeed = 40
local FLY_MIN, FLY_MAX, FLY_STEP = 10, 200, 10
local held = { up = false, down = false }
local flight = nil

local controls = nil
task.spawn(function()
	local ok, mod = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and mod then controls = mod:GetControls() end
end)

local function stopFlight()
	if not flight then return end
	local f = flight
	flight = nil
	pcall(function()
		if f.lv then f.lv:Destroy() end
		if f.ao then f.ao:Destroy() end
		if f.att then f.att:Destroy() end
		if f.root and f.root.Parent and f.rootC0 then f.root.C0 = f.rootC0 end
		if f.hum and f.hum.Parent then
			f.hum.PlatformStand = false
			f.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function startFlight(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	local att = Instance.new("Attachment"); att.Name = "CyberFlyAtt"; att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent = hrp
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = math.huge
	ao.Responsiveness = 25
	ao.CFrame = hrp.CFrame
	ao.Parent = hrp
	local lower = char:FindFirstChild("LowerTorso")
	local root = (lower and lower:FindFirstChild("Root")) or hrp:FindFirstChild("RootJoint")
	flight = { char = char, hrp = hrp, hum = hum, att = att, lv = lv, ao = ao, root = root, rootC0 = root and root.C0, vel = Vector3.zero }
	hum.PlatformStand = true
end

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	if localState.fly and char and char:FindFirstChild("HumanoidRootPart") then
		if not flight or flight.char ~= char then
			stopFlight()
			startFlight(char)
		end
	elseif flight then
		stopFlight()
	end
	if not flight then return end

	local f = flight
	local cam = workspace.CurrentCamera
	local dir
	if controls then
		dir = cam.CFrame:VectorToWorldSpace(controls:GetMoveVector())
	else
		dir = f.hum.MoveDirection
	end
	dir += Vector3.new(0, (held.up and 1 or 0) - (held.down and 1 or 0), 0)
	if dir.Magnitude > 1 then dir = dir.Unit end

	local target = dir * flySpeed
	if dir.Magnitude < 0.05 then
		target = Vector3.new(0, math.sin(os.clock() * 2) * 1.5, 0) -- lơ lửng nhẹ
	end
	f.vel = f.vel:Lerp(target, math.min(1, dt * 5))
	f.lv.VectorVelocity = f.vel

	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		f.ao.CFrame = CFrame.lookAt(f.hrp.Position, f.hrp.Position + flat)
	end
	if f.root and f.rootC0 then
		f.root.C0 = CFrame.Angles(localRig.lean, 0, 0) * f.rootC0
	end
end)

RunService.RenderStepped:Connect(function(dt)
	for userId, rig in pairs(rigs) do
		if rig.owner.Parent == nil then
			rig:destroy()
			rigs[userId] = nil
		else
			rig:update(dt)
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
local FONT    = Enum.Font.GothamMedium

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

local openBtn = make("TextButton", {
	Name = "OpenButton", Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 16, 0.5, -28),
	BackgroundColor3 = BG, Text = "AURA", TextColor3 = CYAN, Font = FONT, TextSize = 14,
	AutoButtonColor = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, openBtn)
do local _, g = neonStroke(openBtn, 2); table.insert(gradients, g) end

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
	Text = remote and "// multiplayer  ·  mọi người cùng thấy" or "// chưa có server script  ·  chỉ mình bạn thấy",
	TextColor3 = MAGENTA, Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
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
	return function(v) on = v; render(false) end -- để code khác đổi trạng thái công tắc
end

local setFly, flySet
flySet = makeToggle("BAY : ON", "BAY : OFF", localState.fly, function(v) setFly(v) end)
makeToggle("AURA : ON", "AURA : OFF", localState.aura, function(v) setLocal("aura", v) end)
makeToggle("CÁNH : 2 CÁNH", "CÁNH : 1 CÁNH", localState.twoWings, function(v) setLocal("twoWings", v) end)
makeToggle("TẤN CÔNG : ON", "TẤN CÔNG : OFF", localState.attack, function(v) setLocal("attack", v) end)
makeToggle("KIẾM BAY : ON", "KIẾM BAY : OFF", localState.swords, function(v) setLocal("swords", v) end)
makeToggle("AURA MẠNH : ON", "AURA MẠNH : OFF", localState.boost, function(v) setLocal("boost", v) end)

local colorHeader = make("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, content)
make("TextLabel", {
	Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = "> MÀU CÁNH / AURA", TextColor3 = YELLOW,
	Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
}, colorHeader)
local preview = make("Frame", { Size = UDim2.fromOffset(30, 16), Position = UDim2.new(1, -30, 0, 3), BackgroundColor3 = localState.color }, colorHeader)
make("UICorner", { CornerRadius = UDim.new(0, 3) }, preview)
make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1 }, preview)

local sliders = {}
local function pushColor()
	local c = Color3.fromRGB(sliders.R.value, sliders.G.value, sliders.B.value)
	preview.BackgroundColor3 = c
	setLocal("color", c)
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
			content.ScrollingEnabled = false
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

local c0 = localState.color
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

-- HUD bay (bên phải màn hình)
local hud = make("Frame", {
	Size = UDim2.fromOffset(88, 270), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.42, 0),
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, hud)

local function hudBtn(text, ord, color)
	local b = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = BG, Text = text, TextColor3 = color,
		Font = FONT, TextSize = 13, AutoButtonColor = false, LayoutOrder = ord,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	make("UIStroke", { Color = color, Thickness = 1.5 }, b)
	return b
end

local flyBtn     = hudBtn("BAY : OFF", 1, DIM)
local speedLabel = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "TỐC ĐỘ 40", TextColor3 = YELLOW,
	Font = FONT, TextSize = 12, LayoutOrder = 2,
}, hud)
local fasterBtn = hudBtn("TĂNG +", 3, CYAN)
local slowerBtn = hudBtn("GIẢM -", 4, MAGENTA)
local upBtn     = hudBtn("LÊN", 5, CYAN)
local downBtn   = hudBtn("XUỐNG", 6, MAGENTA)

local function updateFlyUI()
	local on = localState.fly
	flyBtn.Text = on and "BAY : ON" or "BAY : OFF"
	flyBtn.TextColor3 = on and CYAN or DIM
	flyBtn.UIStroke.Color = on and CYAN or DIM
	flySet(on)
	speedLabel.Text = "TỐC ĐỘ " .. flySpeed
end

setFly = function(v)
	setLocal("fly", v)
	updateFlyUI()
end

flyBtn.MouseButton1Click:Connect(function() setFly(not localState.fly) end)
fasterBtn.MouseButton1Click:Connect(function() flySpeed = math.min(FLY_MAX, flySpeed + FLY_STEP); updateFlyUI() end)
slowerBtn.MouseButton1Click:Connect(function() flySpeed = math.max(FLY_MIN, flySpeed - FLY_STEP); updateFlyUI() end)

local function holdButton(btn, key)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			held[key] = true
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			held[key] = false
		end
	end)
end
holdButton(upBtn, "up")
holdButton(downBtn, "down")

-- phím tắt (máy tính): F bật/tắt bay, E lên, Q xuống
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then setFly(not localState.fly)
	elseif input.KeyCode == Enum.KeyCode.E then held.up = true
	elseif input.KeyCode == Enum.KeyCode.Q then held.down = true end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E then held.up = false
	elseif input.KeyCode == Enum.KeyCode.Q then held.down = false end
end)

-- chết / respawn thì tự tắt bay
player.CharacterRemoving:Connect(function()
	stopFlight()
	if localState.fly then setFly(false) end
end)

updateFlyUI()

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
