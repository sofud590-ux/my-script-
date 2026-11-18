local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

if CoreGui:FindFirstChild("GanoMCMainUI") then
    CoreGui.GanoMCMainUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GanoMCMainUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Nút mở/tắt Menu (Kéo thả được)
local ToggleBtn = Instance.new("TextButton", ScreenGui)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.BorderColor3 = Color3.fromRGB(80, 80, 80)
ToggleBtn.Position = UDim2.new(0, 10, 0, 130)
ToggleBtn.Size = UDim2.new(0, 35, 0, 35)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.Text = "UI"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 13
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)

local tD, tDS, tSP 
ToggleBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
        tD = true tDS = i.Position tSP = ToggleBtn.Position 
    end 
end)
UserInputService.InputChanged:Connect(function(i)
    if tD and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then 
        local d = i.Position - tDS 
        ToggleBtn.Position = UDim2.new(tSP.X.Scale, tSP.X.Offset + d.X, tSP.Y.Scale, tSP.Y.Offset + d.Y)
    end 
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
        tD = false 
    end 
end)

-- Khung Menu Chính
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderColor3 = Color3.fromRGB(50, 50, 50)
MainFrame.Position = UDim2.new(0, 55, 0, 130)
MainFrame.Size = UDim2.new(0, 210, 0, 185)
MainFrame.Visible = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TitleBar = Instance.new("TextLabel", MainFrame)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
TitleBar.Size = UDim2.new(1, 0, 0, 26)
TitleBar.Font = Enum.Font.SourceSansBold
TitleBar.Text = " Gano MC Menu"
TitleBar.TextColor3 = Color3.fromRGB(255, 200, 50)
TitleBar.TextSize = 12
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local CloseBtn = Instance.new("TextButton", TitleBar)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Position = UDim2.new(1, -24, 0, 4)
CloseBtn.Size = UDim2.new(0, 18, 0, 18)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 10
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

local mD, mDS, mSP 
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
        mD = true mDS = i.Position mSP = MainFrame.Position 
    end 
end)
UserInputService.InputChanged:Connect(function(i)
    if mD and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then 
        local d = i.Position - mDS 
        MainFrame.Position = UDim2.new(mSP.X.Scale, mSP.X.Offset + d.X, mSP.Y.Scale, mSP.Y.Offset + d.Y)
    end 
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
        mD = false 
    end 
end)

ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

local ContentFrame = Instance.new("ScrollingFrame", MainFrame)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Position = UDim2.new(0, 5, 0, 32)
ContentFrame.Size = UDim2.new(1, -10, 1, -36)
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 130)
ContentFrame.ScrollBarThickness = 4

local UIListLayout = Instance.new("UIListLayout", ContentFrame)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)

-- 1. Speed (Tốc độ chạy - Tự động giữ liên tục)
local customSpeed = nil
local SpeedBox = Instance.new("TextBox", ContentFrame)
SpeedBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SpeedBox.Size = UDim2.new(1, 0, 0, 26)
SpeedBox.Font = Enum.Font.SourceSans
SpeedBox.PlaceholderText = "Nhập tốc độ chạy..."
SpeedBox.Text = ""
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.TextSize = 11
Instance.new("UICorner", SpeedBox).CornerRadius = UDim.new(0, 4)
SpeedBox.FocusLost:Connect(function(enter) if enter then customSpeed = tonumber(SpeedBox.Text) end end)

task.spawn(function()
    while true do 
        task.wait(1)
        if customSpeed then 
            local char = LocalPlayer.Character 
            local hm = char and char:FindFirstChildOfClass("Humanoid")
            if hm then hm.WalkSpeed = customSpeed end 
        end 
    end
end)

-- 2. Jump (Lực nhảy - Tự động giữ liên tục giống Speed)
local customJump = nil
local JumpBox = Instance.new("TextBox", ContentFrame)
JumpBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
JumpBox.Size = UDim2.new(1, 0, 0, 26)
JumpBox.Font = Enum.Font.SourceSans
JumpBox.PlaceholderText = "Nhập lực nhảy..."
JumpBox.Text = ""
JumpBox.TextColor3 = Color3.fromRGB(255, 255, 255)
JumpBox.TextSize = 11
Instance.new("UICorner", JumpBox).CornerRadius = UDim.new(0, 4)
JumpBox.FocusLost:Connect(function(enter) 
    if enter then 
        customJump = tonumber(JumpBox.Text) 
    end 
end)

task.spawn(function()
    while true do 
        task.wait(1)
        if customJump then 
            local char = LocalPlayer.Character 
            local hm = char and char:FindFirstChildOfClass("Humanoid")
            if hm then 
                hm.UseJumpPower = true 
                hm.JumpPower = customJump 
            end 
        end 
    end
end)

-- 3. InfJump (Nhảy trên không)
local InfJumpBtn = Instance.new("TextButton", ContentFrame)
InfJumpBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
InfJumpBtn.Size = UDim2.new(1, 0, 0, 26)
InfJumpBtn.Font = Enum.Font.SourceSansBold
InfJumpBtn.Text = "Nhảy trên không: TẮT"
InfJumpBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
InfJumpBtn.TextSize = 11
Instance.new("UICorner", InfJumpBtn).CornerRadius = UDim.new(0, 4)

local infJumpEnabled = false 
InfJumpBtn.MouseButton1Click:Connect(function()
    infJumpEnabled = not infJumpEnabled 
    InfJumpBtn.BackgroundColor3 = infJumpEnabled and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(50, 30, 30)
    InfJumpBtn.TextColor3 = infJumpEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    InfJumpBtn.Text = infJumpEnabled and "Nhảy trên không: BẬT" or "Nhảy trên không: TẮT"
end)
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then 
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end 
end)

-- 4. Noclip (Đi xuyên tường)
local NoclipBtn = Instance.new("TextButton", ContentFrame)
NoclipBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
NoclipBtn.Size = UDim2.new(1, 0, 0, 26)
NoclipBtn.Font = Enum.Font.SourceSansBold
NoclipBtn.Text = "Noclip (Xuyên tường): TẮT"
NoclipBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
NoclipBtn.TextSize = 11
Instance.new("UICorner", NoclipBtn).CornerRadius = UDim.new(0, 4)

local noclipEnabled = false 
NoclipBtn.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled 
    NoclipBtn.BackgroundColor3 = noclipEnabled and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(50, 30, 30)
    NoclipBtn.TextColor3 = noclipEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    NoclipBtn.Text = noclipEnabled and "Noclip (Xuyên tường): BẬT" or "Noclip (Xuyên tường): TẮT"
    
    if not noclipEnabled and LocalPlayer.Character then
        for _,p in pairs(LocalPlayer.Character:GetDescendants()) do 
            if p:IsA("BasePart") then p.CanCollide = true end 
        end
    end
end)

RunService.Stepped:Connect(function()
    if noclipEnabled and LocalPlayer.Character then 
        for _,p in pairs(LocalPlayer.Character:GetDescendants()) do 
            if p:IsA("BasePart") then p.CanCollide = false end 
        end 
    end 
end)
