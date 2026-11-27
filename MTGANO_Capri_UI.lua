-- Clean UI Hub - Cyberpunk Capri Edition | MTGANO
local plr = game.Players.LocalPlayer
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- ================== ẢNH NỀN TỪ GITHUB ==================
local IMAGE_URL = "https://raw.githubusercontent.com/sofud590-ux/my-script-/main/images%20(1).jpeg"

local CAPRI_IMAGE
if writefile and getcustomasset then
	local ok, asset = pcall(function()
		writefile("mtgano_capri.jpg", game:HttpGet(IMAGE_URL))
		return getcustomasset("mtgano_capri.jpg")
	end)
	if ok then CAPRI_IMAGE = asset end
end
-- =======================================================

-- Bảng màu Cyberpunk Capri
local C_BG        = Color3.fromRGB(10, 10, 15)
local C_PANEL     = Color3.fromRGB(20, 18, 26)
local C_PINK      = Color3.fromRGB(255, 28, 120)
local C_GREEN     = Color3.fromRGB(20, 255, 125)
local C_WHITE     = Color3.fromRGB(248, 248, 252)
local C_MUTED     = Color3.fromRGB(165, 160, 180)

-- Độ trong suốt của các nút: 0 = đặc, 1 = trong suốt hoàn toàn
local BTN_ALPHA   = 0.7

-- Màu ESP theo % HP
local HP_GREEN    = Color3.fromRGB(20, 255, 120)
local HP_YELLOW   = Color3.fromRGB(255, 225, 30)
local HP_RED      = Color3.fromRGB(255, 45, 70)

-- Danh sách UIGradient viền Cyberpunk để xoay đồng bộ
local cyberGradients = {}
local function applyCyberBorder(obj, thickness, transparency, reverse)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1.6
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = obj

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, C_PINK),
		ColorSequenceKeypoint.new(0.35, C_GREEN),
		ColorSequenceKeypoint.new(0.70, C_PINK),
		ColorSequenceKeypoint.new(1.00, C_GREEN),
	})
	grad.Parent = stroke

	table.insert(cyberGradients, { grad = grad, reverse = reverse or false })
	return stroke
end

-- Hàm kéo thả mượt, nhẹ, không nhảy loạn khi chạm đa điểm
local function makeDraggable(frame, dragHandle, smoothFactor)
	dragHandle = dragHandle or frame
	smoothFactor = smoothFactor or 0.22 -- 0.15 - 0.3: càng nhỏ kéo càng đầm/nhẹ

	local dragging = false
	local activeInput = nil
	local dragStart = Vector2.zero
	local startPos = frame.Position
	local targetPos = frame.Position

	dragHandle.InputBegan:Connect(function(input)
		if dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			activeInput = input
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = frame.Position
			targetPos = frame.Position
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging or input ~= activeInput then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local curPos = Vector2.new(input.Position.X, input.Position.Y)
			local delta = curPos - dragStart
			targetPos = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input == activeInput then
			dragging = false
			activeInput = nil
		end
	end)

	RS.RenderStepped:Connect(function(dt)
		if not dragging then return end
		local alpha = math.clamp(1 - (1 - smoothFactor) ^ (dt * 60), 0, 1)
		local curXScale = frame.Position.X.Scale + (targetPos.X.Scale - frame.Position.X.Scale) * alpha
		local curXOffset = frame.Position.X.Offset + (targetPos.X.Offset - frame.Position.X.Offset) * alpha
		local curYScale = frame.Position.Y.Scale + (targetPos.Y.Scale - frame.Position.Y.Scale) * alpha
		local curYOffset = frame.Position.Y.Offset + (targetPos.Y.Offset - frame.Position.Y.Offset) * alpha
		frame.Position = UDim2.new(curXScale, curXOffset, curYScale, curYOffset)
	end)
end

-- Nút lục giác xoay nhẹ + chữ MTGANO đứng yên
local spinningHexShapes = {}
local function createHexButton(parent, name, text, sizePx, pos, spinSpeed)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.Size = UDim2.new(0, sizePx, 0, sizePx)
	holder.Position = pos
	holder.BackgroundTransparency = 1
	holder.Active = true
	holder.Parent = parent

	local hexSpinContainer = Instance.new("Frame")
	hexSpinContainer.Name = "HexSpinContainer"
	hexSpinContainer.Size = UDim2.new(1, 0, 1, 0)
	hexSpinContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	hexSpinContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	hexSpinContainer.BackgroundTransparency = 1
	hexSpinContainer.Parent = holder

	local function buildHexShape(targetParent, fillColor, scaleFill, zIdx)
		local group = Instance.new("Frame")
		group.Size = UDim2.new(scaleFill, 0, scaleFill, 0)
		group.AnchorPoint = Vector2.new(0.5, 0.5)
		group.Position = UDim2.new(0.5, 0, 0.5, 0)
		group.BackgroundTransparency = 1
		group.ZIndex = zIdx
		group.Parent = targetParent

		for _, rot in ipairs({ 0, 60, 120 }) do
			local bar = Instance.new("Frame")
			bar.Size = UDim2.new(0.56, 0, 1, 0)
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.new(0.5, 0, 0.5, 0)
			bar.Rotation = rot
			bar.BackgroundColor3 = fillColor
			bar.BorderSizePixel = 0
			bar.ZIndex = zIdx
			bar.Parent = group
		end
		return group
	end

	local borderHex = buildHexShape(hexSpinContainer, Color3.new(1, 1, 1), 1, 1)
	local baseGrad = Instance.new("UIGradient")
	baseGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, C_PINK),
		ColorSequenceKeypoint.new(0.35, C_GREEN),
		ColorSequenceKeypoint.new(0.70, C_PINK),
		ColorSequenceKeypoint.new(1.00, C_GREEN),
	})
	for _, child in ipairs(borderHex:GetChildren()) do
		local g = baseGrad:Clone()
		g.Parent = child
		table.insert(cyberGradients, { grad = g, reverse = false })
	end

	buildHexShape(hexSpinContainer, C_BG, 0.9, 2)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = text
	btn.TextColor3 = C_GREEN
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 10
	btn.ZIndex = 5
	btn.Active = true
	btn.Parent = holder

	table.insert(spinningHexShapes, {
		obj = hexSpinContainer,
		speed = spinSpeed or 28
	})

	return holder, btn
end

-- Xoay viền Cyberpunk + xoay lục giác
RS.RenderStepped:Connect(function(dt)
	for _, item in ipairs(cyberGradients) do
		if item.grad and item.grad.Parent then
			local dir = item.reverse and -1 or 1
			item.grad.Rotation = (item.grad.Rotation + dt * 75 * dir) % 360
		end
	end

	for _, hexItem in ipairs(spinningHexShapes) do
		if hexItem.obj and hexItem.obj.Parent then
			hexItem.obj.Rotation = (hexItem.obj.Rotation + dt * hexItem.speed) % 360
		end
	end
end)

-- Xóa UI cũ nếu chạy lại
local oldGui = game.CoreGui:FindFirstChild("MTGANO_Capri_UI")
if oldGui then
	oldGui:Destroy()
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "MTGANO_Capri_UI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = game.CoreGui

-- Khung chính
local main = Instance.new("Frame", gui)
main.Name = "MainHub"
main.Size = UDim2.new(0, 264, 0, 244)
main.Position = UDim2.new(0.56, 0, 0.14, 0)
main.BackgroundColor3 = C_BG
main.BackgroundTransparency = 0.08
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
applyCyberBorder(main, 2, 0, false)

-- Ảnh CAPRI làm nền
if CAPRI_IMAGE then
	local bg = Instance.new("ImageLabel", main)
	bg.Name = "CapriBackground"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundTransparency = 1
	bg.Image = CAPRI_IMAGE
	bg.ImageTransparency = 0.35
	bg.ScaleType = Enum.ScaleType.Crop
	bg.ZIndex = 0
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 12)
end

-- Header
local header = Instance.new("Frame", main)
header.Name = "Header"
header.Size = UDim2.new(1, -16, 0, 30)
header.Position = UDim2.new(0, 8, 0, 5)
header.BackgroundTransparency = 1
header.Active = true
makeDraggable(main, header, 0.22)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -34, 0, 16)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "MTGANO  //  CAPRI"
title.TextColor3 = C_GREEN
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBlack
title.TextSize = 14

local subTag = Instance.new("TextLabel", header)
subTag.Size = UDim2.new(1, -34, 0, 12)
subTag.Position = UDim2.new(0, 0, 0, 16)
subTag.BackgroundTransparency = 1
subTag.Text = "[CYBERPUNK V1]"
subTag.TextColor3 = C_PINK
subTag.TextXAlignment = Enum.TextXAlignment.Left
subTag.Font = Enum.Font.Code
subTag.TextSize = 10

-- Nút thu nhỏ
local hide = Instance.new("TextButton", header)
hide.Size = UDim2.new(0, 24, 0, 24)
hide.Position = UDim2.new(1, -24, 0, 3)
hide.Text = "-"
hide.BackgroundColor3 = C_PANEL
hide.BackgroundTransparency = BTN_ALPHA
hide.TextColor3 = C_PINK
hide.Font = Enum.Font.GothamBlack
hide.TextSize = 16
hide.BorderSizePixel = 0
Instance.new("UICorner", hide).CornerRadius = UDim.new(0, 7)
applyCyberBorder(hide, 1.5, 0.1, true)

-- Đường kẻ phân cách
local divider = Instance.new("Frame", main)
divider.Size = UDim2.new(0.92, 0, 0, 2)
divider.Position = UDim2.new(0.04, 0, 0, 38)
divider.BackgroundColor3 = Color3.new(1, 1, 1)
divider.BorderSizePixel = 0
local divGrad = Instance.new("UIGradient", divider)
divGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, C_PINK),
	ColorSequenceKeypoint.new(0.5, C_GREEN),
	ColorSequenceKeypoint.new(1, C_PINK),
})

-- Nút lục giác khôi phục
local restoreHolder, restore = createHexButton(gui, "RestoreHexBtn", "MTGANO", 58, UDim2.new(0.62, 0, 0.45, 0), 28)
restoreHolder.Visible = false
makeDraggable(restoreHolder, restore, 0.25)

hide.MouseButton1Click:Connect(function()
	main.Visible = false
	restoreHolder.Visible = true
end)

restore.MouseButton1Click:Connect(function()
	main.Visible = true
	restoreHolder.Visible = false
end)

-- Khu vực nút
local body = Instance.new("Frame", main)
body.Name = "Body"
body.Size = UDim2.new(1, 0, 0, 192)
body.Position = UDim2.new(0, 0, 0, 45)
body.BackgroundTransparency = 1

local layout = Instance.new("UIListLayout", body)
layout.Padding = UDim.new(0, 5)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Speed Box
local speedBox = Instance.new("TextBox", body)
speedBox.LayoutOrder = 1
speedBox.Size = UDim2.new(0.92, 0, 0, 33)
speedBox.PlaceholderText = "SPEED // NHẬP SỐ (VD: 35)"
speedBox.PlaceholderColor3 = C_WHITE
speedBox.Text = ""
speedBox.BackgroundColor3 = C_PANEL
speedBox.BackgroundTransparency = BTN_ALPHA
speedBox.TextStrokeTransparency = 0.4
speedBox.TextColor3 = C_GREEN
speedBox.Font = Enum.Font.GothamBold
speedBox.TextSize = 12
speedBox.ClearTextOnFocus = false
speedBox.BorderSizePixel = 0
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 8)
applyCyberBorder(speedBox, 1.5, 0.2, true)

-- Toggle Creator
local orderCounter = 2
local function toggle(name, accentColor)
	accentColor = accentColor or C_PINK
	local b = Instance.new("TextButton", body)
	b.LayoutOrder = orderCounter
	orderCounter += 1
	b.Size = UDim2.new(0.92, 0, 0, 33)
	b.Text = name .. " : OFF"
	b.BackgroundColor3 = C_PANEL
	b.BackgroundTransparency = BTN_ALPHA
	b.TextStrokeTransparency = 0.4
	b.TextColor3 = C_WHITE
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

	local bStroke = applyCyberBorder(b, 1.4, 0.35, orderCounter % 2 == 0)

	local state = false
	b.MouseButton1Click:Connect(function()
		state = not state
		if state then
			b.Text = name .. " : ON"
			b.TextColor3 = accentColor
			b.BackgroundColor3 = Color3.fromRGB(32, 16, 32)
			bStroke.Transparency = 0
			bStroke.Thickness = 1.9
		else
			b.Text = name .. " : OFF"
			b.TextColor3 = C_WHITE
			b.BackgroundColor3 = C_PANEL
			bStroke.Transparency = 0.35
			bStroke.Thickness = 1.4
		end
	end)

	return function() return state end
end

local infJump = toggle("Infinite Jump", C_GREEN)
local noclip = toggle("Noclip", C_PINK)
local aimlock = toggle("ClickLock (Turn Only)", C_PINK)
local espToggle = toggle("ESP HP", C_GREEN)

-- Speed
RS.RenderStepped:Connect(function()
	local char = plr.Character
	local spd = tonumber(speedBox.Text)
	if char and spd then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = spd
		end
	end
end)

-- Infinite Jump
UIS.JumpRequest:Connect(function()
	if infJump() and plr.Character then
		local hum = plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

-- Noclip
RS.Stepped:Connect(function()
	if noclip() and plr.Character then
		for _, v in ipairs(plr.Character:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end
	end
end)

-- AimLock
local function getNearest()
	local closest, dist = nil, math.huge
	if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then return end
	local myPos = plr.Character.HumanoidRootPart.Position
	for _, p in ipairs(game.Players:GetPlayers()) do
		if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local d = (myPos - p.Character.HumanoidRootPart.Position).Magnitude
			if d < dist then
				dist = d
				closest = p.Character.HumanoidRootPart
			end
		end
	end
	return closest
end

RS.RenderStepped:Connect(function()
	if aimlock() and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
		local target = getNearest()
		if target then
			local hrp = plr.Character.HumanoidRootPart
			local look = CFrame.new(hrp.Position, Vector3.new(target.Position.X, hrp.Position.Y, target.Position.Z))
			hrp.CFrame = look
		end
	end
end)

-- Màu theo % HP
local function getHpColor(hpPercent)
	if hpPercent <= 30 then
		return HP_RED
	elseif hpPercent <= 70 then
		return HP_YELLOW
	else
		return HP_GREEN
	end
end

-- ESP
local espFolder = Instance.new("Folder", gui)
espFolder.Name = "CapriESP"

local NAME_SHOW_DIST = 80

RS.RenderStepped:Connect(function()
	local myHRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local isOn = espToggle()

	for _, p in ipairs(game.Players:GetPlayers()) do
		local char = p.Character
		local pHRP = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if p ~= plr and isOn and myHRP and pHRP and hum and hum.Health > 0 then
			local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
			local hpPercent = math.clamp((hum.Health / maxHp) * 100, 0, 100)
			local hpColor = getHpColor(hpPercent)
			local dist = (myHRP.Position - pHRP.Position).Magnitude

			local hl = char:FindFirstChild("MTGANO_Highlight")
			if not hl then
				hl = Instance.new("Highlight")
				hl.Name = "MTGANO_Highlight"
				hl.FillTransparency = 0.55
				hl.OutlineTransparency = 0.1
				hl.Parent = char
			end
			hl.Adornee = char
			hl.FillColor = hpColor
			hl.OutlineColor = hpColor

			local bill = espFolder:FindFirstChild(p.Name)
			if not bill then
				bill = Instance.new("BillboardGui", espFolder)
				bill.Name = p.Name
				bill.Size = UDim2.new(0, 86, 0, 14)
				bill.StudsOffset = Vector3.new(0, 2.3, 0)
				bill.AlwaysOnTop = true
				bill.Adornee = pHRP

				local txt = Instance.new("TextLabel", bill)
				txt.Name = "TextLabel"
				txt.Size = UDim2.new(1, 0, 1, 0)
				txt.BackgroundTransparency = 1
				txt.TextStrokeColor3 = C_BG
				txt.Font = Enum.Font.GothamBold
				txt.TextSize = 11
			else
				bill.Adornee = pHRP
			end

			local txt = bill:FindFirstChild("TextLabel")
			if txt then
				txt.TextColor3 = hpColor
				if dist <= NAME_SHOW_DIST then
					txt.Text = p.Name .. " [" .. math.floor(dist) .. "m]"
					txt.TextTransparency = 0
					txt.TextStrokeTransparency = 0.2
				else
					txt.Text = ""
					txt.TextTransparency = 1
					txt.TextStrokeTransparency = 1
				end
			end
		else
			if char then
				local oldHl = char:FindFirstChild("MTGANO_Highlight")
				if oldHl then
					oldHl:Destroy()
				end
			end
			local existing = espFolder:FindFirstChild(p.Name)
			if existing then
				existing:Destroy()
			end
		end
	end
end)
