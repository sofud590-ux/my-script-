-- Khởi tạo dịch vụ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Kiểm tra xem ScreenGui đã tồn tại chưa. Nếu có rồi thì TẬN DỤNG LẠI, tuyệt đối không xóa hay tạo lại từ đầu để giữ nguyên vị trí đang kéo.
local ScreenGui = CoreGui:FindFirstChild("DeathCrushMainUI")
local ToggleBtn, MainFrame, EspToggle

if not ScreenGui then
    -- ==================== SCREEN GUI: MENU CHÍNH (UI) ====================
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DeathCrushMainUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Nút mở/tắt Menu (Tên "ESP", có thể kéo thả di chuyển, viền Rainbow)
    ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name = "ToggleBtn"
    ToggleBtn.Parent = ScreenGui
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    ToggleBtn.BorderColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.BorderSizePixel = 2
    ToggleBtn.Position = UDim2.new(0, 10, 0, 130)
    ToggleBtn.Size = UDim2.new(0, 45, 0, 35)
    ToggleBtn.Font = Enum.Font.SourceSansBold
    ToggleBtn.Text = "ESP"
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.TextSize = 13
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)

    -- Khung Menu chính (Viền Rainbow)
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MainFrame.BackgroundTransparency = 0.2
    MainFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
    MainFrame.BorderSizePixel = 2
    MainFrame.Position = UDim2.new(0, 65, 0, 130)
    MainFrame.Size = UDim2.new(0, 180, 0, 95)
    MainFrame.Visible = true
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    -- Tiêu đề Menu (Dùng để kéo di chuyển Menu chính)
    local TitleBar = Instance.new("TextLabel")
    TitleBar.Parent = MainFrame
    TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
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

    -- ==================== CƠ CHẾ KÉO THẢ CHO NÚT "ESP" ====================
    local draggingToggle, dragInputToggle, dragStartToggle, startPosToggle
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingToggle = true
            dragStartToggle = input.Position
            startPosToggle = ToggleBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingToggle = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInputToggle = input
        end
    end)
    RunService.RenderStepped:Connect(function()
        if draggingToggle and dragInputToggle then
            local delta = dragInputToggle.Position - dragStartToggle
            ToggleBtn.Position = UDim2.new(startPosToggle.X.Scale, startPosToggle.X.Offset + delta.X, startPosToggle.Y.Scale, startPosToggle.Y.Offset + delta.Y)
        end
    end)

    -- ==================== CƠ CHẾ KÉO THẢ CHO MENU CHÍNH ====================
    local draggingMain, dragInputMain, dragStartMain, startPosMain
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingMain = true
            dragStartMain = input.Position
            startPosMain = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingMain = false
                end
            end)
        end
    end)
    RunService.RenderStepped:Connect(function()
        if draggingMain and dragInputMain then
            local delta = dragInputMain.Position - dragStartMain
            MainFrame.Position = UDim2.new(startPosMain.X.Scale, startPosMain.X.Offset + delta.X, startPosMain.Y.Scale, startPosMain.Y.Offset + delta.Y)
        end
    end)

    ToggleBtn.MouseButton1Click:Connect(function() 
        MainFrame.Visible = not MainFrame.Visible 
    end)
    
    CloseBtn.MouseButton1Click:Connect(function() 
        MainFrame.Visible = false 
    end)

    -- Khung chứa bên trong
    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Parent = MainFrame
    Container.BackgroundTransparency = 1
    Container.Position = UDim2.new(0, 6, 0, 30)
    Container.Size = UDim2.new(1, -12, 1, -35)

    -- Nút bật/tắt ESP
    EspToggle = Instance.new("TextButton")
    EspToggle.Name = "EspToggle"
    EspToggle.Parent = Container
    EspToggle.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
    EspToggle.Position = UDim2.new(0, 0, 0, 15)
    EspToggle.Size = UDim2.new(1, 0, 0, 32)
    EspToggle.Font = Enum.Font.SourceSansBold
    EspToggle.Text = "ESP Theo Máu: TẮT"
    EspToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
    EspToggle.TextSize = 12
    Instance.new("UICorner", EspToggle).CornerRadius = UDim.new(0, 4)

    EspToggle.MouseButton1Click:Connect(function()
        if EspToggle.Text:find("TẮT") then
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
else
    -- Nếu UI đã có sẵn, tự động móc nối lại để tiếp tục sử dụng mà không tạo mới đè lên
    ToggleBtn = ScreenGui:FindFirstChild("ToggleBtn")
    MainFrame = ScreenGui:FindFirstChild("MainFrame")
end


-- ==================== VÒNG LẶP XỬ LÝ (VIỀN UI RAINBOW + ESP THÂN THEO MÁU) ====================
RunService.RenderStepped:Connect(function()
    -- Viền nút ESP và Menu chính chạy hiệu ứng Rainbow liên tục
    local rainbowColor = Color3.fromHSV(tick() % 5 / 5, 1, 1)
    if ToggleBtn then ToggleBtn.BorderColor3 = rainbowColor end
    if MainFrame then MainFrame.BorderColor3 = rainbowColor end
    
    local container = MainFrame and MainFrame:FindFirstChild("Container")
    local espToggleBtn = container and container:FindFirstChild("EspToggle")
    local isEspOn = false
    if espToggleBtn and espToggleBtn.Text:find("BẬT") then
        isEspOn = true
    end
    
    if not isEspOn then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            
            -- Đảm bảo không còn sót lại name tag cũ
            local head = char and char:FindFirstChild("Head")
            if head and head:FindFirstChild("DC_NameTag") then
                head.DC_NameTag:Destroy()
            end
            
            if char and humanoid and humanoid.Health > 0 then
                -- Highlight Thân
                local highlight = char:FindFirstChild("DC_Highlight")
                if not highlight then
                    highlight = Instance.new("Highlight")
                    highlight.Name = "DC_Highlight"
                    highlight.Adornee = char
                    highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- Viền sáng trắng cố định
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.Parent = char
                end
                
                -- Tính % máu theo mốc: <=25% Đỏ, <=70% Vàng, >70% Xanh lá
                local maxHealth = humanoid.MaxHealth
                if maxHealth <= 0 then maxHealth = 100 end
                local healthPercent = (humanoid.Health / maxHealth) * 100
                
                local statusColor = Color3.fromRGB(0, 255, 0)
                if healthPercent <= 25 then
                    statusColor = Color3.fromRGB(255, 0, 0)   -- 🔴 Đỏ (<= 25%)
                elseif healthPercent <= 70 then
                    statusColor = Color3.fromRGB(255, 255, 0) -- 🟡 Vàng (25.1% - 70%)
                else
                    statusColor = Color3.fromRGB(0, 255, 0)   -- 🟢 Xanh lá (> 70%)
                end
                
                -- Cập nhật màu cho Thân
                highlight.FillColor = statusColor
            else
                if char and char:FindFirstChild("DC_Highlight") then
                    char.DC_Highlight:Destroy()
                end
            end
        end
    end
end)
