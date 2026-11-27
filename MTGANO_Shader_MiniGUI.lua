-- MTGANO Mini Shader & Compact GUI (Lua)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Cleanup old UI if re-executed
local existingGui = playerGui:FindFirstChild("MTGANO_ShaderMiniGUI")
if existingGui then
	existingGui:Destroy()
end

-- Shader & Lighting state
local state = {
	ShaderEnabled = true,
	BloomEnabled = true,
	WaveLighting = true,
	Exposure = 0.15,
	Saturation = 0.20,
	Contrast = 0.10,
	TintColor = Color3.fromRGB(255, 244, 224),
	Locked = false,
	Minimized = false,
}

local shaderFolder = Instance.new("Folder")
shaderFolder.Name = "MTGANO_ShaderEffects"
shaderFolder.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "MTGANO_Atmosphere"
atmosphere.Density = 0.28
atmosphere.Offset = 0.15
atmosphere.Haze = 0.8
atmosphere.Glare = 0.15
atmosphere.Color = Color3.fromRGB(235, 242, 255)
atmosphere.Decay = Color3.fromRGB(175, 195, 225)
atmosphere.Parent = shaderFolder

local bloom = Instance.new("BloomEffect")
bloom.Name = "MTGANO_Bloom"
bloom.Intensity = 0.45
bloom.Size = 18
bloom.Threshold = 1.15
bloom.Enabled = state.BloomEnabled
bloom.Parent = shaderFolder

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name = "MTGANO_ColorCorrection"
colorCorrection.Brightness = 0.02
colorCorrection.Contrast = state.Contrast
colorCorrection.Saturation = state.Saturation
colorCorrection.TintColor = state.TintColor
colorCorrection.Enabled = state.ShaderEnabled
colorCorrection.Parent = shaderFolder

local sunRays = Instance.new("SunRaysEffect")
sunRays.Name = "MTGANO_SunRays"
sunRays.Intensity = 0.08
sunRays.Spread = 0.65
sunRays.Enabled = state.ShaderEnabled
sunRays.Parent = shaderFolder

local function applyShaderState()
	local active = state.ShaderEnabled
	atmosphere.Parent = active and shaderFolder or nil
	bloom.Enabled = active and state.BloomEnabled
	colorCorrection.Enabled = active
	sunRays.Enabled = active

	colorCorrection.Contrast = active and state.Contrast or 0
	colorCorrection.Saturation = active and state.Saturation or 0
	colorCorrection.TintColor = active and state.TintColor or Color3.new(1, 1, 1)
	Lighting.ExposureCompensation = active and state.Exposure or 0
end

applyShaderState()

-- Subtle dynamic light pulse ("shader wave" feel)
local waveClock = 0
RunService.RenderStepped:Connect(function(dt)
	if not state.ShaderEnabled or not state.WaveLighting then
		return
	end
	waveClock += dt
	local pulse = math.sin(waveClock * 2.2) * 0.04
	Lighting.ExposureCompensation = state.Exposure + pulse
	bloom.Intensity = math.clamp(0.45 + pulse * 2.0, 0.1, 1.2)
end)

-- Compact Draggable & Lockable Mobile GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MTGANO_ShaderMiniGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 186, 0, 168)
mainFrame.Position = UDim2.new(0.04, 0, 0.25, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 225, 255)
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

-- Top bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 28)
topBar.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 10)
topCorner.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -66, 1, 0)
titleLabel.Position = UDim2.new(0, 8, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MTGANO SHADER"
titleLabel.TextColor3 = Color3.fromRGB(235, 245, 255)
titleLabel.TextSize = 11
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(0, 24, 0, 20)
lockBtn.Position = UDim2.new(1, -54, 0.5, -10)
lockBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
lockBtn.Text = "🔓"
lockBtn.TextSize = 11
lockBtn.Font = Enum.Font.GothamBold
lockBtn.Parent = topBar

local lockCorner = Instance.new("UICorner")
lockCorner.CornerRadius = UDim.new(0, 6)
lockCorner.Parent = lockBtn

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 24, 0, 20)
minBtn.Position = UDim2.new(1, -27, 0.5, -10)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.TextSize = 13
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = topBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minBtn

-- Body container
local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "Body"
bodyFrame.Size = UDim2.new(1, -12, 1, -36)
bodyFrame.Position = UDim2.new(0, 6, 0, 32)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bodyFrame

local function makeToggle(labelText, initialValue, orderIdx, onToggle)
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = orderIdx
	btn.Size = UDim2.new(1, 0, 0, 25)
	btn.BackgroundColor3 = initialValue and Color3.fromRGB(22, 110, 130) or Color3.fromRGB(36, 40, 54)
	btn.Text = labelText .. ": " .. (initialValue and "ON" or "OFF")
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamSemibold
	btn.Parent = bodyFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local current = initialValue
	btn.MouseButton1Click:Connect(function()
		current = not current
		btn.Text = labelText .. ": " .. (current and "ON" or "OFF")
		btn.BackgroundColor3 = current and Color3.fromRGB(22, 110, 130) or Color3.fromRGB(36, 40, 54)
		onToggle(current)
	end)
	return btn
end

local function makeCycleButton(labelText, options, orderIdx, onSelect)
	local idx = 1
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = orderIdx
	btn.Size = UDim2.new(1, 0, 0, 25)
	btn.BackgroundColor3 = Color3.fromRGB(36, 40, 54)
	btn.Text = labelText .. ": " .. options[idx].name
	btn.TextColor3 = Color3.fromRGB(220, 240, 255)
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamSemibold
	btn.Parent = bodyFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		idx = (idx % #options) + 1
		btn.Text = labelText .. ": " .. options[idx].name
		onSelect(options[idx])
	end)
end

makeToggle("Shader", state.ShaderEnabled, 1, function(v)
	state.ShaderEnabled = v
	applyShaderState()
end)

makeToggle("Bloom", state.BloomEnabled, 2, function(v)
	state.BloomEnabled = v
	applyShaderState()
end)

makeToggle("Wave Light", state.WaveLighting, 3, function(v)
	state.WaveLighting = v
	applyShaderState()
end)

makeCycleButton("Tone", {
	{ name = "Warm", tint = Color3.fromRGB(255, 244, 224), exp = 0.15, sat = 0.20 },
	{ name = "Crisp", tint = Color3.fromRGB(235, 246, 255), exp = 0.10, sat = 0.30 },
	{ name = "Night", tint = Color3.fromRGB(185, 205, 255), exp = -0.10, sat = 0.10 },
}, 4, function(opt)
	state.TintColor = opt.tint
	state.Exposure = opt.exp
	state.Saturation = opt.sat
	applyShaderState()
end)

-- Lock & Minimize handlers
lockBtn.MouseButton1Click:Connect(function()
	state.Locked = not state.Locked
	lockBtn.Text = state.Locked and "🔒" or "🔓"
	mainStroke.Color = state.Locked and Color3.fromRGB(255, 190, 60) or Color3.fromRGB(0, 225, 255)
end)

minBtn.MouseButton1Click:Connect(function()
	state.Minimized = not state.Minimized
	bodyFrame.Visible = not state.Minimized
	mainFrame.Size = state.Minimized and UDim2.new(0, 186, 0, 28) or UDim2.new(0, 186, 0, 168)
	minBtn.Text = state.Minimized and "+" or "-"
end)

-- Drag support for touch & mouse
local dragging = false
local dragStart = Vector2.zero
local startPos = UDim2.new()

topBar.InputBegan:Connect(function(input)
	if state.Locked then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging or state.Locked then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType.Touch then
		local delta = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType.Touch then
		dragging = false
	end
end)
