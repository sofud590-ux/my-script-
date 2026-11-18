-- Khởi tạo dịch vụ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Xóa UI cũ nếu có để tránh trùng lặp
if CoreGui:FindFirstChild("DeathCrushMainUI") then
    CoreGui.DeathCrushMainUI:Destroy()
end

-- ==================== SCREEN GUI: MENU CHÍNH (UI) ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeathCrushMainUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Nút mở/tắt Menu
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.BorderColor3 = Color3.fromRGB(80, 80, 80)
ToggleBtn.Position = UDim2.new(0, 10, 0, 130)
ToggleBtn.Size = UDim2.new(0, 35, 0, 35)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.Text = "UI"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 13
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)

-- Khung Menu
local MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BackgroundTransparency = 0.2
MainFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
MainFrame.Position = UDim2.new(0, 55, 0, 130)
MainFrame.Size = UDim2.new(0, 180, 0, 95)
MainFrame.Visible = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- Tiêu đề Menu (Dùng để kéo di chuyển)
local TitleBar = Instance.new("TextLabel")
TitleBar.Parent = MainFrame
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
TitleBar.Size = UDim2.new(1, 0, 0, 25)
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.Text = " DeathCrush Menu"
TitleBar.TextColor3 = Color3.fromRGB(200, 200, 200)
TitleBar.TextSize = 12
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = TitleBar
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Position = UDim2.new(1, -22, 0, 3)
CloseBtn.Size = UDim2.new(0, 18, 0, 18)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 10
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

-- Cơ chế kéo thả mượt mà cho Menu
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
RunService.RenderStepped:Connect(function()
    if dragging and dragInput then
        local delta = dragInput.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- Khung chứa bên trong
local Container = Instance.new("Frame")
Container.Parent = MainFrame
Container.BackgroundTransparency = 1
Container.Position = UDim2.new(0, 6, 0, 30)
Container.Size = UDim2.new(1, -12, 1, -35)

-- Nút bật/tắt ESP
local EspToggle = Instance.new("TextButton")
EspToggle.Parent = Container
EspToggle.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
EspToggle.Position = UDim2.new(0, 0, 0, 15)
EspToggle.Size = UDim2.new(1, 0, 0, 32)
EspToggle.Font = Enum.Font.SourceSansBold
EspToggle.Text = "ESP Theo Máu: TẮT"
EspToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
EspToggle.TextSize = 12
Instance.new("UICorner", EspToggle).CornerRadius = UDim.new(0, 4)

local espEnabled = false
EspToggle.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        EspToggle.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
        EspToggle.TextColor3 = Color3.fromRGB(100, 255, 100)
        EspToggle.Text = "ESP Theo Máu: BẬT"
    else
        EspToggle.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
        EspToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
        EspToggle.Text = "ESP Theo Máu: TẮT"
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("DC_Highlight") then
                player.Character.DC_Highlight:Destroy()
            end
        end
    end
end)


-- ==================== VÒNG LẶP ESP ĐỔI MÀU THEO MÁU (ĐÃ TỐI ƯU) ====================
RunService.RenderStepped:Connect(function()
    if not espEnabled then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            
            if char and humanoid and humanoid.Health > 0 then
                local highlight = char:FindFirstChild("DC_Highlight")
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "DC_Highlight"
                    highlight.Adornee = char
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.Parent = char
                end
                
                -- Đảm bảo MaxHealth không bị bằng 0 để tránh lỗi chia cho 0
                local maxHealth = humanoid.MaxHealth
                if maxHealth <= 0 then maxHealth = 100 end
                
                local healthPercent = humanoid.Health / maxHealth
                
                -- Cập nhật màu sắc dựa trên tỷ lệ máu thực tế
                if healthPercent > 0.65 then
                    highlight.FillColor = Color3.fromRGB(0, 255, 0)   -- Xanh lá (> 65%)
                elseif healthPercent > 0.35 then
                    highlight.FillColor = Color3.fromRGB(255, 255, 0) -- Vàng (35% - 65%)
                else
                    highlight.FillColor = Color3.fromRGB(255, 0, 0)   -- Đỏ (< 35%)
                end
            else
                if char and char:FindFirstChild("DC_Highlight") then
                    char.DC_Highlight:Destroy()
                end
            end
        end
    end
end)
