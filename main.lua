local ok, err = pcall(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

-- CONFIGURAÇÃO DE IMAGEM DO TOPO (Mude o ID se quiser outra)
local BANNER_IMAGE = "rbxassetid://13836896689" 
-- CONFIGURAÇÃO DE CORES (Estilo Duck/Cyberpunk)
local THEME = {
    bg      = Color3.fromRGB(15, 15, 20),
    sidebar = Color3.fromRGB(20, 20, 28),
    panel   = Color3.fromRGB(25, 25, 35),
    text    = Color3.fromRGB(240, 240, 240),
    textDim = Color3.fromRGB(130, 130, 140),
    accent  = Color3.fromRGB(0, 220, 255), -- Azul ciano
    red     = Color3.fromRGB(255, 60, 60),
    off     = Color3.fromRGB(45, 45, 55),
}

local cfg = {
    Aimbot = false, CarFly = false, CarGrabActive = false,
    NoRecoil = false, NoSpread = false, Streamproof = false,
    ESP_Box = false, ESP_Name = false, ESP_Head = false,
    ESP_Health = false, ESP_Distance = false, ESP_Tracer = false, ESP_Skeleton = false,
    ESP_Vehicles = false, -- NOVO
    TeamCheckAimbot = false, TeamCheckESP = false,
    WallCheckAimbot = false, WallCheckESP = false,
    TargetPlayer = nil, TargetOnESP = false,
    FOV = 120, Smooth = 0.25,
    ThrowPower = 5, GrabDistance = 45, GrabFollowSpeed = 16,
    MenuBind = Enum.KeyCode.Insert, GrabBind = Enum.KeyCode.Y, ThrowBind = Enum.UserInputType.MouseButton1,
    -- Crosshair Configs
    Crosshair_On = false,
    Crosshair_Thickness = 2,
    Crosshair_Gap = 5,
    Crosshair_Color = Color3.fromRGB(0, 255, 136),
    Crosshair_Hex = "#00FF88",
}

local HAS_D = (typeof(Drawing) == "table")
local HAS_M = (typeof(mousemoverel) == "function")

-- ============ OTIMIZAÇÃO DE RAYCAST ============
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local wallCheckCache = {}
local lastWallCheckTime = 0

local function isSameTeam(p)
    if not p or not LP.Team or not p.Team then return false end
    return p.Team == LP.Team
end

local function updateWallChecks()
    local now = tick()
    if now - lastWallCheckTime < 0.15 then return end
    lastWallCheckTime = now
    
    local filter = {Cam}
    if LP.Character then table.insert(filter, LP.Character) end
    rayParams.FilterDescendantsInstances = filter
    local origin = Cam.CFrame.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local head = p.Character:FindFirstChild("Head")
            if head then
                local result = workspace:Raycast(origin, head.Position - origin, rayParams)
                wallCheckCache[p] = (not result) or result.Instance:IsDescendantOf(p.Character)
            else
                wallCheckCache[p] = false
            end
        end
    end
end

-- ============ UI PRINCIPAL ============
local sg = Instance.new("ScreenGui")
sg.Name = "cqberMenu"
sg.ResetOnSpawn = false
sg.Parent = LP:WaitForChild("PlayerGui")

local win = Instance.new("Frame")
win.Size = UDim2.new(0, 620, 0, 460) -- Menu maior
win.Position = UDim2.new(0.5, -310, 0.5, -230)
win.BackgroundColor3 = THEME.bg
win.BorderSizePixel = 0
win.Visible = false
win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)

local winStroke = Instance.new("UIStroke")
winStroke.Color = THEME.accent
winStroke.Thickness = 1
winStroke.Transparency = 0.5
winStroke.Parent = win

-- === BANNER TOPO ===
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 60)
topBar.BackgroundColor3 = THEME.panel
topBar.BorderSizePixel = 0
topBar.Parent = win
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

local banner = Instance.new("ImageLabel")
banner.Size = UDim2.new(1, 0, 1, 0)
banner.BackgroundTransparency = 1
banner.Image = BANNER_IMAGE
banner.ScaleType = Enum.ScaleType.Crop
banner.Parent = topBar
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 8)

local topGrad = Instance.new("UIGradient")
topGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, THEME.accent),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
}
topGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0.7),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1, 0.7),
}
topGrad.Parent = banner

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 20, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "CQBER // EXTERNAL"
titleLabel.TextColor3 = THEME.text
titleLabel.TextSize = 22
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

-- Drag
local dragging, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = win.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- === SIDEBAR ESQUERDA ===
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, -60)
sidebar.Position = UDim2.new(0, 0, 0, 60)
sidebar.BackgroundColor3 = THEME.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = win

local sideLayout = Instance.new("UIListLayout", sidebar)
sideLayout.Padding = UDim.new(0, 4)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder

local sidePad = Instance.new("UIPadding", sidebar)
sidePad.PaddingTop = UDim.new(0, 10)
sidePad.PaddingLeft = UDim.new(0, 8)
sidePad.PaddingRight = UDim.new(0, 8)

-- Perfil do Jogador (Fundo Esquerdo)
local profileFrame = Instance.new("Frame")
profileFrame.Size = UDim2.new(1, -16, 0, 50)
profileFrame.Position = UDim2.new(0, 8, 1, -60)
profileFrame.BackgroundColor3 = THEME.panel
profileFrame.BorderSizePixel = 0
profileFrame.Parent = win
Instance.new("UICorner", profileFrame).CornerRadius = UDim.new(0, 6)

local pfp = Instance.new("ImageLabel")
pfp.Size = UDim2.new(0, 36, 0, 36)
pfp.Position = UDim2.new(0, 7, 0.5, -18)
pfp.BackgroundColor3 = THEME.bg
pfp.BorderSizePixel = 0
pfp.Parent = profileFrame
Instance.new("UICorner", pfp).CornerRadius = UDim.new(1, 0)

local pfpStroke = Instance.new("UIStroke")
pfpStroke.Color = THEME.accent
pfpStroke.Thickness = 1
pfpStroke.Parent = pfp

pcall(function()
    pfp.Image = Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -55, 0, 16)
nameLabel.Position = UDim2.new(0, 50, 0, 10)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = LP.Name
nameLabel.TextColor3 = THEME.text
nameLabel.TextSize = 12
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
nameLabel.Parent = profileFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -55, 0, 14)
statusLabel.Position = UDim2.new(0, 50, 0, 26)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Online | CQBER V2"
statusLabel.TextColor3 = THEME.accent
statusLabel.TextSize = 10
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = profileFrame

-- === AREA DE CONTEÚDO ===
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -150, 1, -60)
content.Position = UDim2.new(0, 150, 0, 60)
content.BackgroundColor3 = THEME.bg
content.BorderSizePixel = 0
content.Parent = win

local tabPages, tabButtons = {}, {}

local function createTab(name, idx)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 32)
    b.BackgroundColor3 = Color3.fromRGB(0,0,0)
    b.BackgroundTransparency = 1
    b.Text = "  " .. name
    b.TextColor3 = THEME.textDim
    b.TextSize = 13
    b.Font = Enum.Font.Gotham
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = sidebar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)

    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1, -20, 1, -20)
    sc.Position = UDim2.new(0, 10, 0, 10)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 2
    sc.ScrollBarImageColor3 = THEME.accent
    sc.CanvasSize = UDim2.new(0, 0, 0, 0)
    sc.Visible = false
    sc.Parent = content

    local pl = Instance.new("UIListLayout", sc)
    pl.Padding = UDim.new(0, 10)
    pl.SortOrder = Enum.SortOrder.LayoutOrder
    pl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sc.CanvasSize = UDim2.new(0, 0, 0, pl.AbsoluteContentSize.Y + 20)
    end)

    tabPages[name] = sc
    tabButtons[name] = b

    b.MouseButton1Click:Connect(function()
        for _, pg in pairs(tabPages) do pg.Visible = false end
        for _, bt in pairs(tabButtons) do
            bt.BackgroundTransparency = 1
            bt.TextColor3 = THEME.textDim
        end
        sc.Visible = true
        b.BackgroundTransparency = 0
        b.BackgroundColor3 = THEME.panel
        b.TextColor3 = THEME.accent
    end)
    
    if idx == 1 then
        sc.Visible = true
        b.BackgroundTransparency = 0
        b.BackgroundColor3 = THEME.panel
        b.TextColor3 = THEME.accent
    end
    return sc
end

-- === HELPERS DE COMPONENTES ===
local function makeToggle(parent, label, key, cb)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, -10, 0, 30)
    r.BackgroundTransparency = 1
    r.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -60, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = THEME.text
    l.TextSize = 13
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = r
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 50, 0, 22)
    b.Position = UDim2.new(1, -50, 0.5, -11)
    b.BackgroundColor3 = THEME.off
    b.BorderSizePixel = 0
    b.Text = cfg[key] and "ON" or "OFF"
    b.TextColor3 = cfg[key] and THEME.accent or THEME.textDim
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.Parent = r
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    b.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        b.Text = cfg[key] and "ON" or "OFF"
        b.BackgroundColor3 = cfg[key] and THEME.accent or THEME.off
        b.TextColor3 = cfg[key] and THEME.bg or THEME.textDim
        if cb then
            local result = cb(cfg[key])
            if result == false then
                cfg[key] = false
                b.Text = "OFF"
                b.BackgroundColor3 = THEME.off
                b.TextColor3 = THEME.textDim
            end
        end
    end)
end

local function makeSlider(parent, label, key, mn, mx, def, isInt)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, -10, 0, 42)
    r.BackgroundTransparency = 1
    r.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 16)
    l.BackgroundTransparency = 1
    l.Text = label .. ": " .. tostring(def)
    l.TextColor3 = THEME.text
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = r
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 4)
    bar.Position = UDim2.new(0, 0, 0, 24)
    bar.BackgroundColor3 = THEME.off
    bar.BorderSizePixel = 0
    bar.Parent = r
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((def - mn) / (mx - mn), 0, 1, 0)
    fill.BackgroundColor3 = THEME.accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)
    local dr = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dr = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dr = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dr and i.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = mn + (mx - mn) * pct
            if isInt then v = math.floor(v) end
            fill.Size = UDim2.new(pct, 0, 1, 0)
            l.Text = label .. ": " .. string.format(isInt and "%d" or "%.2f", v)
            cfg[key] = v
        end
    end)
end

-- === CRIAÇÃO DAS ABAS ===
local aimPage = createTab("Combate", 1)
local visPage = createTab("Visual (ESP)", 2)
local carPage = createTab("Veículos", 3)
local crossPage = createTab("Crosshair", 4)
local outPage = createTab("Outros", 5)

-- [ ABA COMBATE ]
makeToggle(aimPage, "Aimbot", "Aimbot")
makeSlider(aimPage, "FOV", "FOV", 20, 400, 120, true)
makeSlider(aimPage, "Suavidade", "Smooth", 0.05, 1, 0.25, false)
makeToggle(aimPage, "Team Check", "TeamCheckAimbot")
makeToggle(aimPage, "Wall Check", "WallCheckAimbot")
makeToggle(aimPage, "No Recoil", "NoRecoil")
makeToggle(aimPage, "No Spread", "NoSpread")

-- [ ABA ESP ]
makeToggle(visPage, "ESP Box", "ESP_Box")
makeToggle(visPage, "ESP Name", "ESP_Name")
makeToggle(visPage, "ESP Health", "ESP_Health")
makeToggle(visPage, "ESP Distance", "ESP_Distance")
makeToggle(visPage, "ESP Tracer", "ESP_Tracer")
makeToggle(visPage, "ESP Skeleton", "ESP_Skeleton")
makeToggle(visPage, "ESP Veículos", "ESP_Vehicles")
makeToggle(visPage, "Team Check", "TeamCheckESP")
makeToggle(visPage, "Wall Check", "WallCheckESP")

-- [ ABA VEÍCULOS ]
makeToggle(carPage, "Ativar Grab / Throw", "CarGrabActive")
makeSlider(carPage, "Força do Arremesso", "ThrowPower", 0, 10, 5, true)
makeToggle(carPage, "Car Fly (WASD)", "CarFly", function(s) toggleCarFly(s) end)

local vehLabel = Instance.new("TextLabel")
vehLabel.Size = UDim2.new(1, 0, 0, 20)
vehLabel.BackgroundTransparency = 1
vehLabel.Text = "Veículos Próximos (Clique para TP):"
vehLabel.TextColor3 = THEME.accent
vehLabel.TextSize = 12
vehLabel.Font = Enum.Font.GothamBold
vehLabel.TextXAlignment = Enum.TextXAlignment.Left
vehLabel.Parent = carPage

local vehList = Instance.new("Frame")
vehList.Size = UDim2.new(1, 0, 0, 150)
vehList.BackgroundColor3 = THEME.panel
vehList.BorderSizePixel = 0
vehList.Parent = carPage
Instance.new("UICorner", vehList).CornerRadius = UDim.new(0, 6)

local vehScroll = Instance.new("ScrollingFrame")
vehScroll.Size = UDim2.new(1, 0, 1, 0)
vehScroll.BackgroundTransparency = 1
vehScroll.BorderSizePixel = 0
vehScroll.ScrollBarThickness = 2
vehScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
vehScroll.Parent = vehList

local vLayout = Instance.new("UIListLayout", vehScroll)
vLayout.Padding = UDim.new(0, 4)
vLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    vehScroll.CanvasSize = UDim2.new(0, 0, 0, vLayout.AbsoluteContentSize.Y + 10)
end)

local function refreshVehicleList()
    for _, c in ipairs(vehScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local found = {}
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChildWhichIsA("VehicleSeat") then
            local seat = v:FindFirstChildWhichIsA("VehicleSeat")
            local dist = (seat.Position - hrp.Position).Magnitude
            table.insert(found, {model = v, seat = seat, dist = dist})
        end
    end
    
    table.sort(found, function(a, b) return a.dist < b.dist end)

    for i = 1, math.min(#found, 15) do
        local data = found[i]
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 28)
        btn.BackgroundColor3 = THEME.off
        btn.Text = string.format("  %s [%dm]", data.model.Name, math.floor(data.dist))
        btn.TextColor3 = THEME.text
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = vehScroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        
        btn.MouseButton1Click:Connect(function()
            -- Rodograu 2.0 (Puxa o carro pra ti)
            pcall(function()
                local targetCF = hrp.CFrame + hrp.CFrame.LookVector * 5
                data.model:PivotTo(targetCF)
            end)
        end)
    end
end

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0, 150, 0, 24)
refreshBtn.BackgroundColor3 = THEME.accent
refreshBtn.Text = "Atualizar Lista"
refreshBtn.TextColor3 = THEME.bg
refreshBtn.TextSize = 12
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.Parent = carPage
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 4)
refreshBtn.MouseButton1Click:Connect(refreshVehicleList)

-- [ ABA CROSSHAIR ]
makeToggle(crossPage, "Ativar Crosshair", "Crosshair_On")
makeSlider(crossPage, "Grossura", "Crosshair_Thickness", 1, 5, 2, true)
makeSlider(crossPage, "Espaço (Gap)", "Crosshair_Gap", 0, 20, 5, true)

local hexLabel = Instance.new("TextLabel")
hexLabel.Size = UDim2.new(1, 0, 0, 20)
hexLabel.BackgroundTransparency = 1
hexLabel.Text = "Cor HEX (ex: #00FF88):"
hexLabel.TextColor3 = THEME.text
hexLabel.TextSize = 12
hexLabel.Font = Enum.Font.Gotham
hexLabel.TextXAlignment = Enum.TextXAlignment.Left
hexLabel.Parent = crossPage

local hexBox = Instance.new("TextBox")
hexBox.Size = UDim2.new(1, 0, 0, 28)
hexBox.BackgroundColor3 = THEME.off
hexBox.Text = cfg.Crosshair_Hex
hexBox.TextColor3 = THEME.accent
hexBox.TextSize = 14
hexBox.Font = Enum.Font.Code
hexBox.Parent = crossPage
Instance.new("UICorner", hexBox).CornerRadius = UDim.new(0, 4)
hexBox:GetPropertyChangedSignal("Text"):Connect(function()
    if hexBox.Text:match("^#?%x%x%x%x%x%x$") then
        local hex = hexBox.Text
        if not hex:find("#") then hex = "#" .. hex end
        cfg.Crosshair_Hex = hex
        local ok, color = pcall(Color3.fromHex, hex)
        if ok then cfg.Crosshair_Color = color end
    end
end)

-- [ ABA OUTROS ]
makeToggle(outPage, "Streamproof (Invisível p/ Gravador)", "Streamproof", function(s) return setStreamproof(s) end)

-- ============ LÓGICA DO CROSSHAIR ============
local crossLines = {}
if HAS_D then
    for i = 1, 4 do
        crossLines[i] = Drawing.new("Line")
        crossLines[i].Visible = false
        crossLines[i].Thickness = 2
    end
end

local function updateCrosshair()
    if not HAS_D then return end
    if not cfg.Crosshair_On then
        for i = 1, 4 do crossLines[i].Visible = false end
        return
    end
    
    local center = Cam.ViewportSize / 2
    local gap = cfg.Crosshair_Gap
    local len = 10 -- comprimento de cada linha
    local t = cfg.Crosshair_Thickness
    local c = cfg.Crosshair_Color

    -- Top
    crossLines[1].From = Vector2.new(center.X, center.Y - gap)
    crossLines[1].To = Vector2.new(center.X, center.Y - gap - len)
    -- Bottom
    crossLines[2].From = Vector2.new(center.X, center.Y + gap)
    crossLines[2].To = Vector2.new(center.X, center.Y + gap + len)
    -- Left
    crossLines[3].From = Vector2.new(center.X - gap, center.Y)
    crossLines[3].To = Vector2.new(center.X - gap - len, center.Y)
    -- Right
    crossLines[4].From = Vector2.new(center.X + gap, center.Y)
    crossLines[4].To = Vector2.new(center.X + gap + len, center.Y)

    for i = 1, 4 do
        crossLines[i].Color = c
        crossLines[i].Thickness = t
        crossLines[i].Visible = true
    end
end

-- ============ LÓGICA DE ESP ============
local fovCircle = nil
if HAS_D then
    fovCircle = Drawing.new("Circle")
    fovCircle.Color = THEME.accent
    fovCircle.Thickness = 1.5
    fovCircle.Filled = false
    fovCircle.Transparency = 0.8
end

local esp = {}
local espVisTimer = {}

local function drawESP(p)
    if p == LP or esp[p] or not HAS_D then return end
    esp[p] = {
        box = Drawing.new("Square"),
        head = Drawing.new("Circle"),
        health = Drawing.new("Square"),
        name = Drawing.new("Text"),
        dist = Drawing.new("Text"),
        tracer = Drawing.new("Line"),
        skeleton = {},
    }
    for i = 1, 10 do
        local line = Drawing.new("Line")
        table.insert(esp[p].skeleton, line)
    end
    for k, v in pairs(esp[p]) do
        if k == "skeleton" then
            for _, l in ipairs(v) do l.Color = THEME.accent; l.Thickness = 1; l.Transparency = 0.8 end
        else
            v.Color = (k == "health") and Color3.fromRGB(0, 255, 100) or THEME.accent
            if k == "name" or k == "dist" then
                v.Size = 14; v.Center = true; v.Outline = true; v.OutlineColor = THEME.bg
            elseif k == "head" then
                v.Thickness = 1.5; v.Filled = false; v.Radius = 6
            elseif k == "health" then
                v.Thickness = 1; v.Filled = true; v.Transparency = 0.7
            end
        end
    end
end

Players.PlayerAdded:Connect(drawESP)
for _, p in ipairs(Players:GetPlayers()) do drawESP(p) end

Players.PlayerRemoving:Connect(function(p)
    local o = esp[p]
    if o then
        for k, v in pairs(o) do
            if k == "skeleton" then
                for _, l in ipairs(v) do l:Remove() end
            else
                v:Remove()
            end
        end
        esp[p] = nil
    end
    espVisTimer[p] = nil
    wallCheckCache[p] = nil
end)

local function hideAll(o)
    for k, v in pairs(o) do
        if k == "skeleton" then
            for _, l in ipairs(v) do l.Visible = false end
        else
            v.Visible = false
        end
    end
end

local function updESP()
    local myChar = LP.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local screenSize = Cam.ViewportSize
    local now = tick()
    
    if cfg.WallCheckESP then updateWallChecks() end

    for p, o in pairs(esp) do
        local skip = false
        if cfg.TargetOnESP and cfg.TargetPlayer and p ~= cfg.TargetPlayer then skip = true end
        if cfg.TeamCheckESP and isSameTeam(p) then skip = true end

        local c = p.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hd = c and c:FindFirstChild("Head")

        local visible = true
        if cfg.WallCheckESP and c then
            if wallCheckCache[p] == true then espVisTimer[p] = now end
            visible = (now - (espVisTimer[p] or 0)) < 0.2
        end

        if skip or not visible or not (hrp and hum and hd) or hum.Health <= 0 then
            hideAll(o)
        else
            local tp, ton = Cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
            local bp, bon = Cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            if ton and bon then
                local h = math.abs(tp.Y - bp.Y)
                local w = h * 0.6
                local x = (tp.X + bp.X)/2
                local y = (tp.Y + bp.Y)/2
                
                o.box.Size = Vector2.new(w, h)
                o.box.Position = Vector2.new(x - w/2, y - h/2)
                o.box.Visible = cfg.ESP_Box
                
                local ratio = hum.Health / hum.MaxHealth
                o.health.Size = Vector2.new(3, h * ratio)
                o.health.Position = Vector2.new(x - w/2 - 6, y + h/2 - h*ratio)
                o.health.Visible = cfg.ESP_Health
                
                o.name.Text = p.Name
                o.name.Position = Vector2.new(x, y - h/2 - 18)
                o.name.Visible = cfg.ESP_Name
                
                if cfg.ESP_Distance and myHrp then
                    o.dist.Text = "[" .. math.floor((hrp.Position - myHrp.Position).Magnitude) .. "m]"
                    o.dist.Position = Vector2.new(x, y + h/2 + 4)
                    o.dist.Visible = true
                else o.dist.Visible = false end
                
                if cfg.ESP_Tracer then
                    o.tracer.From = Vector2.new(screenSize.X/2, screenSize.Y)
                    o.tracer.To = Vector2.new(x, y + h/2)
                    o.tracer.Visible = true
                else o.tracer.Visible = false end
            else
                o.box.Visible = false; o.health.Visible = false
                o.name.Visible = false; o.dist.Visible = false; o.tracer.Visible = false
            end
            
            local hp, hon = Cam:WorldToViewportPoint(hd.Position)
            if hon and cfg.ESP_Head then
                o.head.Position = Vector2.new(hp.X, hp.Y)
                o.head.Visible = true
            else o.head.Visible = false end
            
            if cfg.ESP_Skeleton then
                local torso = c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
                local la = c:FindFirstChild("Left Arm") or c:FindFirstChild("LeftUpperArm")
                local ra = c:FindFirstChild("Right Arm") or c:FindFirstChild("RightUpperArm")
                local ll = c:FindFirstChild("Left Leg") or c:FindFirstChild("LeftUpperLeg")
                local rl = c:FindFirstChild("Right Leg") or c:FindFirstChild("RightUpperLeg")
                local pairs_ = { {hd, torso}, {torso, la}, {torso, ra}, {torso, ll}, {torso, rl} }
                local idx = 1
                for _, pair in ipairs(pairs_) do
                    local p1, p2 = pair[1], pair[2]
                    if p1 and p2 and idx <= #o.skeleton then
                        local s1, o1 = Cam:WorldToViewportPoint(p1.Position)
                        local s2, o2 = Cam:WorldToViewportPoint(p2.Position)
                        if o1 and o2 then
                            local line = o.skeleton[idx]
                            line.From = Vector2.new(s1.X, s1.Y)
                            line.To = Vector2.new(s2.X, s2.Y)
                            line.Visible = true
                            idx = idx + 1
                        end
                    end
                end
                for i = idx, #o.skeleton do o.skeleton[i].Visible = false end
            else
                for _, l in ipairs(o.skeleton) do l.Visible = false end
            end
        end
    end
end

-- ============ LÓGICA DO AIMBOT ============
local function closest()
    local best, bd = nil, cfg.FOV
    local mp = UIS:GetMouseLocation()
    
    if cfg.WallCheckAimbot then updateWallChecks() end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        if cfg.TargetPlayer and p ~= cfg.TargetPlayer then continue end
        if not cfg.TargetPlayer and cfg.TeamCheckAimbot and isSameTeam(p) then continue end

        local c = p.Character
        local part = c and c:FindFirstChild("Head")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not (part and hum and hum.Health > 0) then continue end
        if cfg.WallCheckAimbot and wallCheckCache[p] ~= true then continue end

        local sp, on = Cam:WorldToViewportPoint(part.Position)
        if on then
            local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
            if d < bd then bd = d; best = part end
        end
    end
    return best
end

local function runAim()
    if not cfg.Aimbot then return end
    local t = closest()
    if not t then return end
    if HAS_M then
        local tp = Cam:WorldToViewportPoint(t.Position)
        local mp = UIS:GetMouseLocation()
        local d = Vector2.new(tp.X, tp.Y) - mp
        if d.Magnitude > 1 then
            local s = d * cfg.Smooth
            mousemoverel(s.X, s.Y)
        end
    else
        local cf = Cam.CFrame
        Cam.CFrame = cf:Lerp(CFrame.new(cf.Position, t.Position), cfg.Smooth)
    end
end

-- ============ LÓGICA DE CARRO ============
local grabbedCar, grabConn, grabState = nil, nil, nil
local grabOffset = CFrame.new(0, 3, -10)

local function nearestCar(maxDist)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, distance = nil, maxDist
    
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") and v:FindFirstChildWhichIsA("VehicleSeat") then
            local seat = v:FindFirstChildWhichIsA("VehicleSeat")
            local d = (seat.Position - root.Position).Magnitude
            if d < distance then best, distance = v, d end
        end
    end
    return best
end

local function stopGrab(restore)
    if grabConn then grabConn:Disconnect(); grabConn = nil end
    if grabState and restore ~= false then
        for part, props in pairs(grabState.parts) do
            if part.Parent then
                part.Anchored = props.anchored
                part.CanCollide = props.collide
            end
        end
    end
    grabbedCar, grabState = nil, nil
end

local function grabCar()
    if not cfg.CarGrabActive then return end
    if grabbedCar then stopGrab(true) end
    local model = nearestCar(cfg.GrabDistance)
    if not model then return end

    local seat = model:FindFirstChildWhichIsA("VehicleSeat")
    local occupied = seat and seat.Occupant ~= nil
    if occupied and seat then
        pcall(function() seat:Sit(nil) end)
        task.wait(0.1)
        occupied = seat.Occupant ~= nil
    end

    local parts = {}
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BasePart") then
            parts[obj] = {anchored = obj.Anchored, collide = obj.CanCollide}
            if not occupied then
                obj.Anchored = true
                obj.CanCollide = false
            end
        end
    end

    grabbedCar = model
    grabState = {parts = parts, occupied = occupied, seat = seat}

    local last = model:GetPivot()
    local lastT = tick()
    local frameCount = 0
    grabConn = RunService.Heartbeat:Connect(function()
        frameCount = frameCount + 1
        if frameCount % 4 ~= 0 then return end
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not cfg.CarGrabActive or not model.Parent or not root then stopGrab(true) return end
        
        local now = tick()
        local dt = math.min((now - lastT) * 4, 0.1)
        lastT = now
        local target = root.CFrame * grabOffset
        local alpha = 1 - math.exp(-cfg.GrabFollowSpeed * dt)
        last = last:Lerp(target, alpha)
        pcall(function() model:PivotTo(last) end)
    end)
end

local function throwCar()
    if not grabbedCar or not grabState then return end
    local model = grabbedCar
    local power = math.clamp(tonumber(cfg.ThrowPower) or 0, 0, 10)
    local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)

    pcall(function()
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Anchored = false
                obj.CanCollide = true
            end
        end
    end)

    stopGrab(false)
    if not root or not root.Parent or power == 0 then return end

    task.delay(0.05, function()
        if not root or not root.Parent then return end
        pcall(function()
            local dir = workspace.CurrentCamera.CFrame.LookVector
            local speed = 18 + 12 * power
            local upward = 6 + 6 * power
            root.AssemblyLinearVelocity = dir * speed + Vector3.new(0, upward, 0)
            root.AssemblyAngularVelocity = Vector3.new(math.random(-4,4), math.random(-4,4), math.random(-4,4))
        end)
    end)
end

local flyConn, flyVel
function toggleCarFly(s)
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyVel then flyVel:Destroy(); flyVel = nil end
    if not s then return end
    local c = LP.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local v = nil
    for _, o in ipairs(workspace:GetChildren()) do
        if o:IsA("Model") and o:FindFirstChildWhichIsA("VehicleSeat") then
            if o:FindFirstChildWhichIsA("VehicleSeat").Occupant == hum then v = o; break end
        end
    end
    if not v then return end
    
    local rp = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
    if not rp then return end
    flyVel = Instance.new("BodyVelocity")
    flyVel.Velocity = Vector3.zero
    flyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyVel.Parent = rp
    
    flyConn = RunService.Heartbeat:Connect(function()
        if not cfg.CarFly or not rp or not rp.Parent then return end
        local dir = Vector3.zero
        local cf = Cam.CFrame
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
        flyVel.Velocity = dir.Magnitude > 0 and dir.Unit * 50 or Vector3.zero
    end)
end

-- ============ STREAMPROOF E BINDS ============
local spBackupParent = nil
function setStreamproof(state)
    if not state then
        if spBackupParent then pcall(function() sg.Parent = spBackupParent end); spBackupParent = nil end
        return true
    end
    if typeof(setrenderproperty) == "function" and pcall(setrenderproperty, sg, "Streamproof", true) then return true end
    if typeof(protect_gui) == "function" and pcall(protect_gui, sg) then return true end
    if typeof(protectgui) == "function" and pcall(protectgui, sg) then return true end
    spBackupParent = sg.Parent
    local hui = nil
    pcall(function() if gethui then hui = gethui() end end)
    if pcall(function() sg.Parent = hui or CoreGui end) then return true end
    return false
end

local function matches(input, binding)
    if not binding then return false end
    if typeof(binding) == "EnumItem" and binding.EnumType == Enum.KeyCode then
        return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == binding
    end
    return input.UserInputType == binding
end

local function mouseOverUI()
    local pos = UIS:GetMouseLocation()
    local guis = LP.PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
    return #guis > 0
end

UIS.InputBegan:Connect(function(input, gp)
    if bindCapture or UIS:GetFocusedTextBox() then return end
    if matches(input, cfg.MenuBind) then
        if not gp then win.Visible = not win.Visible end
    elseif matches(input, cfg.GrabBind) then
        if cfg.CarGrabActive then grabCar() end
    elseif matches(input, cfg.ThrowBind) then
        if cfg.CarGrabActive then
            if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseOverUI() then return end
            throwCar()
        end
    end
end)

-- ============ LOOP GERAL ============
RunService.RenderStepped:Connect(function()
    if fovCircle then
        if cfg.FOV > 0 and cfg.Aimbot then
            fovCircle.Visible = true
            fovCircle.Position = UIS:GetMouseLocation()
            fovCircle.Radius = cfg.FOV
        else
            fovCircle.Visible = false
        end
    end
    
    updateCrosshair()
    updESP()
    runAim()
end)

print("[cqber] carregado. Insert abre.")

end)
if not ok then
    warn("[cqber ERRO]", err)
    print("[cqber ERRO]", err)
end
