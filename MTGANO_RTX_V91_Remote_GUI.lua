-- MTGANO RTX V9.1 Shader + Remote Link Loader & Compact UI GUI (Lua)
local env = (getgenv and getgenv()) or _G
for _, key in ipairs({ "__RTX_V5", "__RTX_V6", "__RTX_V7", "__RTX_V8", "__RTX_V9", "__MTGANO_RTX_V91" }) do
	local old = env[key]
	if type(old) == "table" and type(old.Stop) == "function" then
		pcall(old.Stop)
	end
	env[key] = nil
end

local Lighting         = game:GetService("Lighting")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")

local LP       = Players.LocalPlayer
local Terrain  = Workspace:FindFirstChildOfClass("Terrain")
local IS_TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local VERSION = "9.1"
local REMOTE_URL = "https://raw.githubusercontent.com/Elitx67/Rtx67/refs/heads/main/IhatewhenigestalteditAppleintelligenceWontwork"

local CFG = {
	SHADOW_SOFTNESS    = 0.02,
	NEON_SCAN_DIST     = 500,
	NEON_SCAN_INTERVAL = 0.1,
	NEON_MAX_SAMPLES   = 300,
	FOCUS_MAX          = 800,
	FOCUS_SPEED        = 12.0,
	SUN_GLARE_EXTRA    = 1.80,
	INDOOR_EXPOSURE    = 0.60,
	SAVE_FILE          = "MTGANO_RTXV91_Settings.json",
	TOGGLE_KEY         = Enum.KeyCode.RightShift,
	MASTER_KEY         = Enum.KeyCode.RightControl,
}

local C3, V3 = Color3.fromRGB, Vector3.new
local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function smoothstep(a, b, x) local t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t) end
local function damp(cur, target, speed, dt) return lerp(cur, target, 1 - math.exp(-speed * dt)) end
local function setN(o, p, v) if math.abs(o[p] - v) > 0.0005 then o[p] = v end end
local function setC(o, p, v)
	local c = o[p]
	if math.abs(c.R - v.R) + math.abs(c.G - v.G) + math.abs(c.B - v.B) > 0.001 then o[p] = v end
end
local function lerpC3(a, b, t) return Color3.new(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t)) end

local running = true
local conns, created = {}, {}
local function connect(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local function track(inst) created[#created + 1] = inst; return inst end
local function new(class, props, parent)
	local i = Instance.new(class)
	if props then for k, v in pairs(props) do i[k] = v end end
	if parent then i.Parent = parent end
	return i
end
local function guiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and typeof(h) == "Instance" then return h end
	return LP:WaitForChild("PlayerGui")
end

local QM = { Off = 0, Low = 0.60, Medium = 1.20, High = 2.00, Ultra = 3.50 }
local REFLECT_MULT = { Off = 0, Low = 0.80, Medium = 1.40, High = 2.00, Ultra = 3.00 }
local WATER_MULT   = { Off = 0.50, Low = 1.00, Medium = 1.50, High = 2.00, Ultra = 3.00 }
local GFX = {
	Low    = { Enum.QualityLevel.Level10, Enum.MeshPartDetailLevel.Level03 },
	Medium = { Enum.QualityLevel.Level15, Enum.MeshPartDetailLevel.Level04 },
	High   = { Enum.QualityLevel.Level21, Enum.MeshPartDetailLevel.Level04 },
	Ultra  = { Enum.QualityLevel.Level21, Enum.MeshPartDetailLevel.Level04 },
}

local DEFAULTS = {
	gfx = "Ultra",
	sunrays = "Ultra", shadows = "Ultra", reflections = "Ultra",
	bloom = "Ultra", ssao = "Ultra", dof = "Ultra", neon = "Ultra",
	vignette = "Low", dust = true, bars = false,
	grade = "Cinematic", exposure = 0.05, warmth = 0.15,
	fog = "Medium", clouds = "Ultra", water = "Ultra", skyStyle = "Moonlit",
	weather = "Clear", lockTime = false, clockTime = 14, timeSpeed = 0,
	customFov = false, fov = 70, autoRemote = false,
}
local Settings = {}
for k, v in pairs(DEFAULTS) do Settings[k] = v end
local function qual(key) return QM[Settings[key]] or 1 end

local canFile = (isfile and readfile and writefile) and true or false
if canFile then
	pcall(function()
		if isfile(CFG.SAVE_FILE) then
			local data = HttpService:JSONDecode(readfile(CFG.SAVE_FILE))
			if type(data) == "table" then
				for k, v in pairs(data) do
					if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then
						Settings[k] = v
					end
				end
			end
		end
	end)
end

local function saveSettings()
	if not canFile then return end
	pcall(function()
		writefile(CFG.SAVE_FILE, HttpService:JSONEncode(Settings))
	end)
end

local LIGHTING_PROPS = {
	"Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom",
	"FogEnd", "FogStart", "FogColor", "GlobalShadows", "ShadowSoftness", "EnvironmentSpecularScale",
	"EnvironmentDiffuseScale", "ClockTime",
}
local origLighting = {}
for _, p in ipairs(LIGHTING_PROPS) do pcall(function() origLighting[p] = Lighting[p] end) end
local origTechnology = Lighting.Technology

local WATER_PROPS = { "WaterReflectance", "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed", "WaterColor" }
local origWater = {}
if Terrain then for _, p in ipairs(WATER_PROPS) do pcall(function() origWater[p] = Terrain[p] end) end end
local origFov = (Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView) or 70

local function sweepOld(container)
	if not container then return end
	for _, c in ipairs(container:GetChildren()) do
		local n = c.Name
		if n:match("^RTX_") or n:match("^RTXV%d_") or n:match("^MTGANO_RTX") then
			pcall(function() c:Destroy() end)
		end
	end
end
sweepOld(Lighting); sweepOld(Workspace); sweepOld(Terrain)
pcall(function() sweepOld(guiParent()) end)

local function make(class, name)
	local i = Instance.new(class); i.Name = name; i.Parent = Lighting; track(i); return i
end
local atmo    = make("Atmosphere",            "RTXV9_Atmosphere")
local bloom   = make("BloomEffect",           "RTXV9_Bloom")
local cc      = make("ColorCorrectionEffect", "RTXV9_CC")
local dof     = make("DepthOfFieldEffect",    "RTXV9_DoF")
local sunRays = make("SunRaysEffect",         "RTXV9_SunRays")
local blur    = make("BlurEffect",            "RTXV9_Blur")
local myFx    = { bloom, cc, dof, sunRays, blur }
blur.Size = 0; bloom.Size = 64; bloom.Threshold = 0.80; sunRays.Spread = 0.90

local sky = Lighting:FindFirstChildOfClass("Sky")
if not sky then sky = track(new("Sky", { Name = "RTXV9_Sky", Parent = Lighting })) end
local origSky = { StarCount = sky.StarCount, SunAngularSize = sky.SunAngularSize, MoonAngularSize = sky.MoonAngularSize }

local clouds, cloudsOrig
if Terrain then
	clouds = Terrain:FindFirstChildOfClass("Clouds")
	if clouds then cloudsOrig = { Cover = clouds.Cover, Density = clouds.Density, Color = clouds.Color, Enabled = clouds.Enabled }
	else clouds = track(new("Clouds", { Name = "RTXV9_Clouds" }, Terrain)) end
end

local function fxPart(name, size)
	return track(new("Part", {
		Name = name, Size = size, Transparency = 1, CanCollide = false, CanQuery = false,
		CanTouch = false, CastShadow = false, Anchored = true, Massless = true, Locked = true, Parent = Workspace
	}))
end

local rainPart = fxPart("RTXV9_Rain", V3(150, 1, 150))
local rainEm = new("ParticleEmitter", {
	Rate = 0, Enabled = false, Lifetime = NumberRange.new(0.55, 0.75), Speed = NumberRange.new(130, 160),
	EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(4, 4),
	Orientation = Enum.ParticleOrientation.VelocityParallel, Size = NumberSequence.new(0.20),
	Transparency = NumberSequence.new(0.40), LightInfluence = 0.2, Color = ColorSequence.new(C3(210, 230, 255)),
}, rainPart)
pcall(function() rainEm.Squash = NumberSequence.new(-2.0) end)

local snowPart = fxPart("RTXV9_Snow", V3(150, 1, 150))
local snowEm = new("ParticleEmitter", {
	Rate = 0, Enabled = false, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(6, 12),
	EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(20, 20),
	Size = NumberSequence.new(0.28), Transparency = NumberSequence.new(0.10), LightInfluence = 0.9,
	RotSpeed = NumberRange.new(-80, 80), Rotation = NumberRange.new(0, 360), Color = ColorSequence.new(C3(255, 255, 255)),
}, snowPart)

local dustPart = fxPart("RTXV9_Dust", V3(120, 50, 120))
local dustEm = new("ParticleEmitter", {
	Rate = 0, Enabled = false, Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0.3, 0.8),
	SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.10), LightEmission = 0.6, LightInfluence = 1,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1)
	}),
	Acceleration = V3(0.4, 0.1, 0.2), Color = ColorSequence.new(C3(255, 245, 225)),
}, dustPart)
pcall(function() dustEm.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end)

local state = { enabled = true }
local stash, postOrig = {}, {}
local function neutralize(obj)
	if not state.enabled or obj.Name:match("^RTXV9_") then return end
	if obj:IsA("Atmosphere") then stash[obj] = true; obj.Parent = nil
	elseif obj:IsA("PostEffect") and obj.Enabled then postOrig[obj] = true; obj.Enabled = false end
end
local function sweepGameFx() for _, o in ipairs(Lighting:GetChildren()) do neutralize(o) end end
local function restoreGameFx()
	for obj in pairs(stash) do stash[obj] = nil; pcall(function() obj.Parent = Lighting end) end
	for obj in pairs(postOrig) do postOrig[obj] = nil; pcall(function() obj.Enabled = true end) end
end
connect(Lighting.ChildAdded, function(o) task.defer(function() if running and o.Parent == Lighting then neutralize(o) end end) end)

local P = {
	Brightness  = { 4.2, 3.2, 1.4, 2.4 },
	Exposure    = { 0.00, 0.20, 0.50, -0.05 },
	Ambient     = { C3(50, 60, 78), C3(100, 70, 50), C3(10, 14, 30), C3(35, 45, 60) },
	Outdoor     = { C3(130, 150, 180), C3(190, 135, 90), C3(25, 32, 65), C3(110, 120, 145) },
	ShiftTop    = { C3(255, 250, 235), C3(255, 160, 80), C3(90, 115, 220), C3(210, 220, 240) },
	ShiftBottom = { C3(135, 155, 175), C3(105, 75, 55), C3(12, 18, 40), C3(105, 115, 135) },
	AtmoDensity = { 0.45, 0.58, 0.35, 0.62 },
	AtmoOffset  = { 0.30, 0.40, 0.12, 0.35 },
	AtmoColor   = { C3(160, 190, 220), C3(255, 140, 70), C3(15, 25, 60), C3(120, 135, 155) },
	AtmoDecay   = { C3(90, 100, 115), C3(140, 80, 50), C3(10, 14, 35), C3(70, 75, 85) },
	AtmoGlare   = { 0.35, 0.85, 0.05, 0.15 },
	AtmoHaze    = { 2.0, 4.5, 0.8, 3.8 },
	Sat         = { 0.38, 0.45, 0.22, 0.20 },
	Contrast    = { 0.30, 0.38, 0.35, 0.32 },
	Tint        = { C3(255, 252, 244), C3(255, 215, 165), C3(170, 190, 255), C3(200, 215, 235) },
	Brightness2 = { 0.02, 0.05, -0.01, 0.00 },
	BloomI      = { 1.20, 2.20, 2.80, 0.90 },
	BloomT      = { 0.82, 0.72, 0.62, 0.88 },
	RaysI       = { 0.35, 0.75, 0.05, 0.05 },
	CloudColor  = { C3(255, 255, 255), C3(255, 165, 110), C3(30, 40, 80), C3(95, 105, 120) },
	FogColor    = { C3(180, 205, 230), C3(240, 170, 130), C3(6, 10, 28), C3(135, 145, 160) },
	FogDist     = { 700, 500, 320, 550 },
}
local W = { d = 1, g = 0, n = 0, r = 0 }
local function bn(t) return t[1] * W.d + t[2] * W.g + t[3] * W.n + t[4] * W.r end
local function bc(t)
	local a, b, c, d = t[1], t[2], t[3], t[4]
	return Color3.new(a.R * W.d + b.R * W.g + c.R * W.n + d.R * W.r,
		a.G * W.d + b.G * W.g + c.G * W.n + d.G * W.r, a.B * W.d + b.B * W.g + c.B * W.n + d.B * W.r)
end

local WEATHER = {
	Clear  = { rain = 0, snow = 0, fog = 0.0, cover = 0.00, dark = 0.00 },
	Cloudy = { rain = 0, snow = 0, fog = 0.20, cover = 0.45, dark = 0.40 },
	Rain   = { rain = 1.5, snow = 0, fog = 0.60, cover = 0.70, dark = 0.65 },
	Storm  = { rain = 2.2, snow = 0, fog = 0.80, cover = 0.85, dark = 0.90 },
	Snow   = { rain = 0, snow = 1.5, fog = 0.55, cover = 0.65, dark = 0.55 },
	Fog    = { rain = 0, snow = 0, fog = 1.3, cover = 0.45, dark = 0.40 },
}
local wx = { rain = 0, snow = 0, fog = 0, cover = 0, dark = 0 }

local SKY = {
	Default = { amt = 0 },
	Golden  = { amt = 0.85, atmo = C3(255, 175, 90), decay = C3(170, 90, 45), top = C3(255, 185, 120), cloud = C3(255, 175, 110), fog = C3(240, 175, 120) },
	Dusk    = { amt = 0.90, atmo = C3(175, 110, 210), decay = C3(95, 45, 110), top = C3(220, 130, 190), cloud = C3(230, 130, 180), fog = C3(165, 105, 155) },
	Moonlit = { amt = 0.95, atmo = C3(55, 85, 180), decay = C3(20, 35, 90), top = C3(135, 160, 255), cloud = C3(55, 75, 130), fog = C3(30, 48, 100) },
	Neon    = { amt = 0.90, atmo = C3(140, 40, 240), decay = C3(20, 215, 255), top = C3(255, 100, 240), cloud = C3(255, 75, 220), fog = C3(80, 40, 190) },
}
local GRADES = {
	Natural   = { sat = 0.10, con = 0.10, bri = 0.01, tint = C3(255, 255, 255), amt = 0.1 },
	Cinematic = { sat = 0.05, con = 0.22, bri = 0.00, tint = C3(255, 220, 185), amt = 0.45 },
	Vivid     = { sat = 0.35, con = 0.20, bri = 0.03, tint = C3(255, 245, 230), amt = 0.25 },
	Noir      = { sat = -1.40, con = 0.45, bri = -0.04, tint = C3(220, 230, 255), amt = 0.25 },
	Teal      = { sat = 0.18, con = 0.25, bri = 0.01, tint = C3(165, 225, 245), amt = 0.50 },
	Vintage   = { sat = -0.05, con = 0.18, bri = 0.03, tint = C3(255, 220, 170), amt = 0.50 },
	Cold      = { sat = 0.05, con = 0.20, bri = 0.00, tint = C3(175, 205, 255), amt = 0.50 },
}

local S = {
	indoor = 0, indoorT = 0, focus = 60, focusT = 60, water = 0, waterT = 0, ssao = 0, ssaoT = 0,
	neonR = 0, neonG = 0, neonB = 0, neonRT = 0, neonGT = 0, neonBT = 0,
}

local function runRemoteLink(callbackStatus)
	local okFetch, body = pcall(function()
		return game:HttpGet(REMOTE_URL)
	end)
	if not okFetch or type(body) ~= "string" or #body == 0 or body:sub(1, 1) == "<" then
		if callbackStatus then callbackStatus("Link Empty/Blocked", false) end
		return false
	end
	local fn, compileErr = loadstring(body)
	if type(fn) ~= "function" then
		if callbackStatus then callbackStatus("Compile Err", false) end
		return false
	end
	local okExec = pcall(fn)
	if not okExec then
		if callbackStatus then callbackStatus("Exec Err", false) end
		return false
	end
	if callbackStatus then callbackStatus("Loaded OK", true) end
	return true
end

local function tween(obj, props, time, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
	tw:Play(); return tw
end

local overlayGui = track(new("ScreenGui", {
	Name = "MTGANO_RTX_Overlay", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}))
pcall(function() overlayGui.Parent = guiParent() end)

local vignette = {}
for _, d in ipairs({
	{ Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.32, 0), 90 },
	{ Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0.32, 0), 270 },
	{ Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), UDim2.new(0.24, 0, 1, 0), 0 },
	{ Vector2.new(1, 0), UDim2.new(1, 0, 0, 0), UDim2.new(0.24, 0, 1, 0), 180 },
}) do
	local f = new("Frame", {
		AnchorPoint = d[1], Position = d[2], Size = d[3],
		BackgroundColor3 = C3(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false
	}, overlayGui)
	new("UIGradient", {
		Rotation = d[4],
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.55), NumberSequenceKeypoint.new(1, 1)
		})
	}, f)
	vignette[#vignette + 1] = f
end

local barTop = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = C3(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, overlayGui)
local barBottom = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = C3(0, 0, 0), BorderSizePixel = 0, ZIndex = 5 }, overlayGui)
local function updateBars()
	local h = (Settings.bars and state.enabled) and 0.12 or 0
	tween(barTop, { Size = UDim2.new(1, 0, h, 0) }, 0.6, Enum.EasingStyle.Quint)
	tween(barBottom, { Size = UDim2.new(1, 0, h, 0) }, 0.6, Enum.EasingStyle.Quint)
end
local function setVignette(i)
	local t = 1 - clamp(i, 0, 0.95)
	for _, f in ipairs(vignette) do
		if math.abs(f.BackgroundTransparency - t) > 0.004 then f.BackgroundTransparency = t end
	end
end

local rayMain = RaycastParams.new()
rayMain.FilterType = Enum.RaycastFilterType.Exclude
rayMain.IgnoreWater = true
rayMain.RespectCanCollide = true
local function refreshIgnore()
	local list = { rainPart, snowPart, dustPart }
	local cam = Workspace.CurrentCamera
	if cam then list[#list + 1] = cam end
	if LP and LP.Character then list[#list + 1] = LP.Character end
	rayMain.FilterDescendantsInstances = list
end

local function isUnderwater(pos)
	if not Terrain then return false end
	local ok, res = pcall(function()
		local cell = Terrain:WorldToCell(pos)
		local c = Terrain:CellCenterToWorld(cell.X, cell.Y, cell.Z)
		local r = Region3.new(c - V3(2, 2, 2), c + V3(2, 2, 2))
		return Terrain:ReadVoxels(r, 4)[1][1][1] == Enum.Material.Water
	end)
	return ok and res
end

local neonParts = {}
local function trackNeon(o)
	if o:IsA("BasePart") and o.Material == Enum.Material.Neon then
		neonParts[o] = true
	end
end
for _, d in ipairs(Workspace:GetDescendants()) do trackNeon(d) end
connect(Workspace.DescendantAdded, trackNeon)

local function scanNeonBleed()
	if Settings.neon == "Off" then S.neonRT, S.neonGT, S.neonBT = 0, 0, 0; return end
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local pos = cam.CFrame.Position
	local nr, ng, nb, count, maxD = 0, 0, 0, 0, CFG.NEON_SCAN_DIST
	for part in pairs(neonParts) do
		if part.Parent then
			local d = (part.Position - pos).Magnitude
			if d < maxD then
				local w = clamp((1 - d / maxD) * part.Size.Magnitude * 0.18, 0, 0.9)
				local col = part.Color
				nr += col.R * w; ng += col.G * w; nb += col.B * w; count += 1
				if count >= CFG.NEON_MAX_SAMPLES then break end
			end
		else
			neonParts[part] = nil
		end
	end
	local mag, maxInf = math.max(nr, ng, nb), 0.45 * qual("neon")
	if mag > 0.001 then
		local f = maxInf / math.max(mag, maxInf)
		S.neonRT, S.neonGT, S.neonBT = nr * f, ng * f, nb * f
	else
		S.neonRT, S.neonGT, S.neonBT = 0, 0, 0
	end
end

local function sampleWorld(doWater)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local pos, look = cam.CFrame.Position, cam.CFrame.LookVector
	local hit = Workspace:Raycast(pos, look * CFG.FOCUS_MAX, rayMain)
	S.focusT = hit and clamp(hit.Distance, 3, CFG.FOCUS_MAX) or CFG.FOCUS_MAX
	S.indoorT = Workspace:Raycast(pos, V3(0, 100, 0), rayMain) and 1 or 0
	if Settings.ssao ~= "Off" then
		local dh = Workspace:Raycast(pos, V3(0, -4, 0), rayMain)
		S.ssaoT = (dh and (1 - clamp(dh.Distance / 4, 0, 1)) or 0) * 0.35 * qual("ssao")
	else
		S.ssaoT = 0
	end
	if doWater then
		S.waterT = (Settings.water ~= "Off" and isUnderwater(pos)) and 1 or 0
	end
end

local function applyQualityPreset()
	local g = GFX[Settings.gfx] or GFX.Ultra
	pcall(function()
		settings().Rendering.QualityLevel = g[1]
		settings().Rendering.MeshPartDetailLevel = g[2]
	end)
	pcall(function()
		if Settings.shadows == "Off" then
			Lighting.GlobalShadows = false
		else
			Lighting.GlobalShadows = true
			Lighting.ShadowSoftness = CFG.SHADOW_SOFTNESS
		end
	end)
end
applyQualityPreset()

local function updateTimeWeights(t)
	t = t % 24
	local dawn = 1 - smoothstep(4.5, 7.5, math.abs(t - 6.0))
	local dusk = 1 - smoothstep(16.5, 19.5, math.abs(t - 18.0))
	local golden = clamp(dawn + dusk, 0, 1)
	local night = (t < 5.5 or t > 18.5) and 1 or 0
	if t >= 5.5 and t <= 7.5 then night = 1 - smoothstep(5.5, 7.5, t)
	elseif t >= 17.5 and t <= 19.5 then night = smoothstep(17.5, 19.5, t) end
	local day = clamp(1 - night - golden * 0.6, 0, 1)
	local sum = day + golden + night
	W.d, W.g, W.n, W.r = day / sum, golden / sum, night / sum, 0
end

local cycleTime = Lighting.ClockTime
local lastNeonScan = 0
local lastWorldSample = 0
local lastWaterCheck = 0

local function stepFrame(dt)
	if not running then return end
	dt = clamp(dt, 0.001, 0.1)
	local now = os.clock()

	if not state.enabled then
		for _, fx in ipairs(myFx) do fx.Enabled = false end
		setVignette(0)
		return
	end

	for _, fx in ipairs(myFx) do fx.Enabled = true end

	if Settings.lockTime then
		cycleTime = Settings.clockTime
	elseif Settings.timeSpeed and Settings.timeSpeed > 0 then
		cycleTime = (cycleTime + dt * Settings.timeSpeed) % 24
	else
		cycleTime = Lighting.ClockTime
	end
	Lighting.ClockTime = cycleTime
	updateTimeWeights(cycleTime)

	local wTarget = WEATHER[Settings.weather] or WEATHER.Clear
	wx.rain = damp(wx.rain, wTarget.rain, 3.0, dt)
	wx.snow = damp(wx.snow, wTarget.snow, 3.0, dt)
	wx.fog  = damp(wx.fog, wTarget.fog, 2.5, dt)
	wx.cover = damp(wx.cover, wTarget.cover, 2.5, dt)
	wx.dark = damp(wx.dark, wTarget.dark, 2.5, dt)

	if now - lastWorldSample >= 0.08 then
		lastWorldSample = now
		local doW = (now - lastWaterCheck >= 0.25)
		if doW then lastWaterCheck = now end
		sampleWorld(doW)
	end
	if now - lastNeonScan >= CFG.NEON_SCAN_INTERVAL then
		lastNeonScan = now
		scanNeonBleed()
	end

	S.indoor = damp(S.indoor, S.indoorT, 6.0, dt)
	S.focus  = damp(S.focus, S.focusT, CFG.FOCUS_SPEED, dt)
	S.water  = damp(S.water, S.waterT, 8.0, dt)
	S.ssao   = damp(S.ssao, S.ssaoT, 6.0, dt)
	S.neonR  = damp(S.neonR, S.neonRT, 6.0, dt)
	S.neonG  = damp(S.neonG, S.neonGT, 6.0, dt)
	S.neonB  = damp(S.neonB, S.neonBT, 6.0, dt)

	local sk = SKY[Settings.skyStyle] or SKY.Default
	local skAmt = sk.amt or 0

	local bright = bn(P.Brightness) * (1 - wx.dark * 0.45)
	local expVal = bn(P.Exposure) + Settings.exposure - (S.indoor * CFG.INDOOR_EXPOSURE * 0.25) - (wx.dark * 0.25)
	setN(Lighting, "Brightness", bright)
	setN(Lighting, "ExposureCompensation", clamp(expVal, -3, 3))
	setC(Lighting, "Ambient", bc(P.Ambient):Lerp(C3(35, 40, 55), wx.dark * 0.5))
	setC(Lighting, "OutdoorAmbient", bc(P.Outdoor):Lerp(C3(70, 80, 95), wx.dark * 0.5))
	local topCol = bc(P.ShiftTop)
	if skAmt > 0 and sk.top then topCol = lerpC3(topCol, sk.top, skAmt) end
	setC(Lighting, "ColorShift_Top", topCol)
	setC(Lighting, "ColorShift_Bottom", bc(P.ShiftBottom))

	if Settings.fog == "Off" then
		setN(Lighting, "FogEnd", 100000)
	else
		local baseFog = bn(P.FogDist)
		local fogDist = clamp(baseFog * (1 - wx.fog * 0.65), 60, 2500)
		setN(Lighting, "FogEnd", fogDist)
		setN(Lighting, "FogStart", fogDist * 0.25)
		local fCol = bc(P.FogColor)
		if skAmt > 0 and sk.fog then fCol = lerpC3(fCol, sk.fog, skAmt * 0.7) end
		setC(Lighting, "FogColor", fCol)
	end

	local aCol = bc(P.AtmoColor)
	local aDec = bc(P.AtmoDecay)
	if skAmt > 0 and sk.atmo then aCol = lerpC3(aCol, sk.atmo, skAmt) end
	if skAmt > 0 and sk.decay then aDec = lerpC3(aDec, sk.decay, skAmt) end
	setN(atmo, "Density", clamp(bn(P.AtmoDensity) + wx.fog * 0.35, 0, 1))
	setN(atmo, "Offset", bn(P.AtmoOffset))
	setC(atmo, "Color", aCol)
	setC(atmo, "Decay", aDec)
	setN(atmo, "Glare", clamp(bn(P.AtmoGlare) + (Settings.sunrays == "Ultra" and CFG.SUN_GLARE_EXTRA * 0.15 or 0), 0, 10))
	setN(atmo, "Haze", clamp(bn(P.AtmoHaze) + wx.fog * 2.5, 0, 10))

	local gr = GRADES[Settings.grade] or GRADES.Cinematic
	local grAmt = gr.amt or 0.3
	local sat = lerp(bn(P.Sat), gr.sat, grAmt) - S.ssao * 0.15
	local con = lerp(bn(P.Contrast), gr.con, grAmt) + S.ssao * 0.20
	local bri = lerp(bn(P.Brightness2), gr.bri, grAmt) - S.ssao * 0.04
	local tint = lerpC3(bc(P.Tint), gr.tint, grAmt)
	tint = Color3.new(
		clamp(tint.R + Settings.warmth * 0.25 + S.neonR * 0.35, 0, 1.5),
		clamp(tint.G + S.neonG * 0.35, 0, 1.5),
		clamp(tint.B - Settings.warmth * 0.20 + S.neonB * 0.35, 0, 1.5)
	)
	setN(cc, "Saturation", clamp(sat, -2, 2))
	setN(cc, "Contrast", clamp(con, -2, 2))
	setN(cc, "Brightness", clamp(bri, -1, 1))
	setC(cc, "TintColor", tint)

	local bMult = qual("bloom")
	bloom.Enabled = (Settings.bloom ~= "Off")
	setN(bloom, "Intensity", clamp(bn(P.BloomI) * (bMult > 0 and (0.45 + bMult * 0.22) or 0), 0, 5))
	setN(bloom, "Threshold", bn(P.BloomT))

	sunRays.Enabled = (Settings.sunrays ~= "Off")
	setN(sunRays, "Intensity", clamp(bn(P.RaysI) * qual("sunrays") * 0.45 * (1 - wx.dark * 0.7), 0, 1))

	dof.Enabled = (Settings.dof ~= "Off")
	if dof.Enabled then
		setN(dof, "FocusDistance", S.focus)
		setN(dof, "InFocusRadius", 28)
		setN(dof, "FarIntensity", 0.35 * clamp(qual("dof") * 0.35, 0, 1))
		setN(dof, "NearIntensity", 0.15 * clamp(qual("dof") * 0.35, 0, 1))
	end

	local vigMap = { Off = 0, Low = 0.22, Medium = 0.38, High = 0.55, Ultra = 0.72 }
	setVignette((vigMap[Settings.vignette] or 0) + (S.water * 0.35))

	if clouds then
		clouds.Enabled = (Settings.clouds ~= "Off")
		if clouds.Enabled then
			setN(clouds, "Cover", clamp(0.45 + wx.cover * 0.45, 0, 1))
			setN(clouds, "Density", clamp(0.40 + wx.cover * 0.45, 0, 1))
			local cCol = bc(P.CloudColor)
			if skAmt > 0 and sk.cloud then cCol = lerpC3(cCol, sk.cloud, skAmt * 0.75) end
			setC(clouds, "Color", cCol:Lerp(C3(75, 80, 95), wx.dark * 0.6))
		end
	end

	if Terrain and Settings.water ~= "Off" then
		local wm = WATER_MULT[Settings.water] or 1
		setN(Terrain, "WaterWaveSize", clamp(0.18 * wm, 0.05, 1))
		setN(Terrain, "WaterWaveSpeed", clamp(18 * wm * 0.5, 5, 100))
		setN(Terrain, "WaterReflectance", clamp(0.65 * (REFLECT_MULT[Settings.reflections] or 1) * 0.5, 0, 1))
		setN(Terrain, "WaterTransparency", clamp(0.25 + S.water * 0.35, 0, 1))
	end

	local cam = Workspace.CurrentCamera
	if cam then
		local cpos = cam.CFrame.Position
		rainPart.Position = cpos + V3(0, 45, 0)
		snowPart.Position = cpos + V3(0, 40, 0)
		dustPart.Position = cpos + V3(0, 10, 0)

		rainEm.Enabled = wx.rain > 0.15
		rainEm.Rate = math.floor(wx.rain * 260)

		snowEm.Enabled = wx.snow > 0.15
		snowEm.Rate = math.floor(wx.snow * 140)

		dustEm.Enabled = Settings.dust and (wx.rain < 0.15) and (wx.snow < 0.15)
		dustEm.Rate = dustEm.Enabled and 24 or 0

		local targetFov = Settings.customFov and Settings.fov or origFov
		setN(cam, "FieldOfView", targetFov)
	end
end

connect(RunService.RenderStepped, stepFrame)

-- Compact UI GUI
local uiGui = track(new("ScreenGui", {
	Name = "MTGANO_RTX_UI", ResetOnSpawn = false, DisplayOrder = 25,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}))
pcall(function() uiGui.Parent = guiParent() end)

local mainFrame = new("Frame", {
	Name = "MainFrame",
	Size = IS_TOUCH and UDim2.new(0, 210, 0, 240) or UDim2.new(0, 224, 0, 248),
	Position = UDim2.new(0.03, 0, 0.20, 0),
	BackgroundColor3 = C3(16, 18, 26),
	BorderSizePixel = 0,
	Active = true,
}, uiGui)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, mainFrame)
local stroke = new("UIStroke", { Color = C3(0, 220, 255), Thickness = 1.5 }, mainFrame)

local topBar = new("Frame", {
	Name = "TopBar", Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = C3(24, 28, 40), BorderSizePixel = 0,
}, mainFrame)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, topBar)

new("TextLabel", {
	Size = UDim2.new(1, -74, 1, 0), Position = UDim2.new(0, 8, 0, 0),
	BackgroundTransparency = 1, Text = "MTGANO RTX V" .. VERSION,
	TextColor3 = C3(235, 245, 255), TextSize = 11, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, topBar)

local locked = false
local lockBtn = new("TextButton", {
	Size = UDim2.new(0, 22, 0, 20), Position = UDim2.new(1, -70, 0.5, -10),
	BackgroundColor3 = C3(38, 44, 62), Text = "🔓", TextSize = 11, Font = Enum.Font.GothamBold,
}, topBar)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, lockBtn)

local saveBtn = new("TextButton", {
	Size = UDim2.new(0, 22, 0, 20), Position = UDim2.new(1, -46, 0.5, -10),
	BackgroundColor3 = C3(38, 44, 62), Text = "💾", TextSize = 11, Font = Enum.Font.GothamBold,
}, topBar)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, saveBtn)

local minBtn = new("TextButton", {
	Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -22, 0.5, -10),
	BackgroundColor3 = C3(38, 44, 62), Text = "-", TextColor3 = C3(255, 255, 255),
	TextSize = 13, Font = Enum.Font.GothamBold,
}, topBar)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, minBtn)

local scroll = new("ScrollingFrame", {
	Name = "List",
	Size = UDim2.new(1, -10, 1, -34), Position = UDim2.new(0, 5, 0, 30),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, mainFrame)

new("UIListLayout", {
	Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, scroll)

local orderCounter = 0
local function nextOrder() orderCounter += 1; return orderCounter end

local function addToggle(label, key, onChange)
	local btn = new("TextButton", {
		LayoutOrder = nextOrder(), Size = UDim2.new(1, -4, 0, 24),
		BackgroundColor3 = Settings[key] and C3(22, 108, 132) or C3(34, 38, 52),
		Text = label .. ": " .. (Settings[key] and "ON" or "OFF"),
		TextColor3 = C3(255, 255, 255), TextSize = 10, Font = Enum.Font.GothamSemibold,
	}, scroll)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
	btn.MouseButton1Click:Connect(function()
		Settings[key] = not Settings[key]
		btn.Text = label .. ": " .. (Settings[key] and "ON" or "OFF")
		btn.BackgroundColor3 = Settings[key] and C3(22, 108, 132) or C3(34, 38, 52)
		if onChange then onChange(Settings[key]) end
	end)
	return btn
end

local function addCycle(label, key, list, onChange)
	local idx = 1
	for i, v in ipairs(list) do if v == Settings[key] then idx = i; break end end
	local btn = new("TextButton", {
		LayoutOrder = nextOrder(), Size = UDim2.new(1, -4, 0, 24),
		BackgroundColor3 = C3(34, 38, 52),
		Text = label .. ": " .. tostring(list[idx]),
		TextColor3 = C3(220, 242, 255), TextSize = 10, Font = Enum.Font.GothamSemibold,
	}, scroll)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, btn)
	btn.MouseButton1Click:Connect(function()
		idx = (idx % #list) + 1
		Settings[key] = list[idx]
		btn.Text = label .. ": " .. tostring(list[idx])
		if onChange then onChange(Settings[key]) end
	end)
	return btn
end

local masterBtn = new("TextButton", {
	LayoutOrder = nextOrder(), Size = UDim2.new(1, -4, 0, 24),
	BackgroundColor3 = C3(25, 130, 95),
	Text = "RTX Shader: ON",
	TextColor3 = C3(255, 255, 255), TextSize = 10, Font = Enum.Font.GothamBold,
}, scroll)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, masterBtn)
masterBtn.MouseButton1Click:Connect(function()
	state.enabled = not state.enabled
	masterBtn.Text = "RTX Shader: " .. (state.enabled and "ON" or "OFF")
	masterBtn.BackgroundColor3 = state.enabled and C3(25, 130, 95) or C3(110, 42, 48)
	if state.enabled then sweepGameFx() else restoreGameFx() end
	updateBars()
end)

local remoteBtn = new("TextButton", {
	LayoutOrder = nextOrder(), Size = UDim2.new(1, -4, 0, 24),
	BackgroundColor3 = C3(48, 56, 86),
	Text = "Run Rtx67 Link",
	TextColor3 = C3(235, 245, 255), TextSize = 10, Font = Enum.Font.GothamBold,
}, scroll)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, remoteBtn)
remoteBtn.MouseButton1Click:Connect(function()
	remoteBtn.Text = "Checking..."
	task.spawn(function()
		runRemoteLink(function(msg, ok)
			if remoteBtn then
				remoteBtn.Text = msg
				remoteBtn.BackgroundColor3 = ok and C3(25, 130, 95) or C3(115, 55, 45)
				task.delay(1.5, function()
					if remoteBtn then
						remoteBtn.Text = "Run Rtx67 Link"
						remoteBtn.BackgroundColor3 = C3(48, 56, 86)
					end
				end)
			end
		end)
	end)
end)

addCycle("Quality", "gfx", { "Low", "Medium", "High", "Ultra" }, function() applyQualityPreset() end)
addCycle("Grade", "grade", { "Natural", "Cinematic", "Vivid", "Noir", "Teal", "Vintage", "Cold" })
addCycle("Sky", "skyStyle", { "Default", "Golden", "Dusk", "Moonlit", "Neon" })
addCycle("Weather", "weather", { "Clear", "Cloudy", "Rain", "Storm", "Snow", "Fog" })
addCycle("Bloom", "bloom", { "Off", "Low", "Medium", "High", "Ultra" })
addCycle("DoF", "dof", { "Off", "Low", "Medium", "High", "Ultra" })
addCycle("Vignette", "vignette", { "Off", "Low", "Medium", "High", "Ultra" })
addToggle("Cine Bars", "bars", function() updateBars() end)
addToggle("Custom FOV", "customFov", nil)

lockBtn.MouseButton1Click:Connect(function()
	locked = not locked
	lockBtn.Text = locked and "🔒" or "🔓"
	stroke.Color = locked and C3(255, 190, 60) or C3(0, 220, 255)
end)

saveBtn.MouseButton1Click:Connect(function()
	saveSettings()
	saveBtn.Text = "✓"
	task.delay(0.8, function() if saveBtn then saveBtn.Text = "💾" end end)
end)

local minimized = false
local fullSize = mainFrame.Size
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	scroll.Visible = not minimized
	mainFrame.Size = minimized and UDim2.new(0, fullSize.X.Offset, 0, 28) or fullSize
	minBtn.Text = minimized and "+" or "-"
end)

local dragging = false
local dragStart = Vector2.zero
local startPos = UDim2.new()

topBar.InputBegan:Connect(function(input)
	if locked then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging or locked then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType.Touch then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType.Touch then
		dragging = false
	end
end)

connect(UserInputService.InputBegan, function(input, gp)
	if gp then return end
	if input.KeyCode == CFG.TOGGLE_KEY then
		mainFrame.Visible = not mainFrame.Visible
	elseif input.KeyCode == CFG.MASTER_KEY then
		masterBtn:Activate()
	end
end)

local function stopAll()
	if not running then return end
	running = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	for _, inst in ipairs(created) do pcall(function() inst:Destroy() end) end
	restoreGameFx()
	pcall(function()
		for k, v in pairs(origLighting) do Lighting[k] = v end
		Lighting.Technology = origTechnology
		if Terrain then
			for k, v in pairs(origWater) do Terrain[k] = v end
		end
		if sky then
			sky.StarCount = origSky.StarCount
			sky.SunAngularSize = origSky.SunAngularSize
			sky.MoonAngularSize = origSky.MoonAngularSize
		end
		if clouds and cloudsOrig then
			for k, v in pairs(cloudsOrig) do clouds[k] = v end
		end
		if Workspace.CurrentCamera then
			Workspace.CurrentCamera.FieldOfView = origFov
		end
	end)
end

env.__MTGANO_RTX_V91 = { Stop = stopAll }
sweepGameFx()
refreshIgnore()
if Settings.autoRemote then
	task.spawn(function() runRemoteLink() end)
end
