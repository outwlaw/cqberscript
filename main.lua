local ok, err = pcall(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local LP = Players.LocalPlayer
    local Cam = workspace.CurrentCamera
    
    local BANNER_IMAGE = "rbxassetid://13836896689" 
    local THEME = {
        bg = Color3.fromRGB(15, 15, 20), sidebar = Color3.fromRGB(20, 20, 28),
        panel = Color3.fromRGB(25, 25, 35), text = Color3.fromRGB(240, 240, 240),
        textDim = Color3.fromRGB(130, 130, 140), accent = Color3.fromRGB(0, 220, 255),
        red = Color3.fromRGB(255, 60, 60), off = Color3.fromRGB(45, 45, 55),
    }
    
    local cfg = {
        Aimbot = false, CarFly = false, CarGrabActive = false, NoRecoil = false, NoSpread = false,
        Streamproof = false, ESP_Box = false, ESP_Name = false, ESP_Health = false, ESP_Distance = false,
        ESP_Tracer = false, ESP_Skeleton = false, ESP_Head = false, ESP_Vehicles = false, TeamCheckAimbot = false,
        TeamCheckESP = false, WallCheckAimbot = false, WallCheckESP = false, TargetPlayer = nil,
        TargetOnESP = false, FOV = 120, Smooth = 0.25, ThrowPower = 5, GrabDistance = 45,
        GrabFollowSpeed = 16, MenuBind = Enum.KeyCode.Insert, GrabBind = Enum.KeyCode.Y,
        ThrowBind = Enum.UserInputType.MouseButton1, Crosshair_On = false, Crosshair_Thickness = 2,
        Crosshair_Length = 10, Crosshair_Gap = 5, Crosshair_Color = Color3.fromRGB(0, 255, 136),
        Crosshair_Hex = "#00FF88", Crosshair_Outline = true, Crosshair_Dot = false,
    }
    
    local HAS_D = (typeof(Drawing) == "table")
    local HAS_M = (typeof(mousemoverel) == "function")
    local isUnloaded = false
    -- Referencias compartilhadas entre callbacks e inicializacao posterior
    local sidebar, content, profileFrame
    local crossLines, outlineLines, crossDot, fovCircle
    local esp, espVeh
    local flyConn, flyVel, spinConn
    local stopGrab
    local allConnections = {}
    
    local function safeConnect(event, func)
        local conn = event:Connect(func)
        table.insert(allConnections, conn)
        return conn
    end
    
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
                else wallCheckCache[p] = false end
            end
        end
    end
    
    -- ============ UI PRINCIPAL ============
    local sg = Instance.new("ScreenGui")
    sg.Name = "cqberMenu"
    sg.ResetOnSpawn = false
    local playerGui = LP:WaitForChild("PlayerGui")
    local oldGui = playerGui:FindFirstChild("cqberMenu")
    if oldGui then oldGui:Destroy() end
    sg.Parent = playerGui
    
    local win = Instance.new("Frame")
    win.Size = UDim2.fromOffset(620, 460)
    win.Position = UDim2.new(0.5, -310, 0.5, -230)
    win.BackgroundColor3 = THEME.bg
    win.BorderSizePixel = 0
    win.Visible = true
    win.Parent = sg
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)
    
    local openButton = Instance.new("TextButton")
    openButton.Name = "OpenMenu"
    openButton.Size = UDim2.fromOffset(62, 62)
    openButton.Position = UDim2.fromOffset(12, 100)
    openButton.Text = "CQBER"
    openButton.TextSize = 12
    openButton.Font = Enum.Font.GothamBold
    openButton.TextColor3 = THEME.text
    openButton.BackgroundColor3 = THEME.panel
    openButton.Parent = sg
    Instance.new("UICorner", openButton).CornerRadius = UDim.new(1, 0)
    local orbStroke = Instance.new("UIStroke", openButton)
    orbStroke.Color = THEME.accent
    orbStroke.Thickness = 2
    local orbDragging, orbStart, orbPos, orbMoved = false, nil, nil, false
    safeConnect(openButton.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            orbDragging = true; orbMoved = false; orbStart = input.Position; orbPos = openButton.Position
        end
    end)
    safeConnect(UIS.InputChanged, function(input)
        if orbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - orbStart
            if delta.Magnitude > 6 then orbMoved = true end
            openButton.Position = UDim2.new(orbPos.X.Scale, orbPos.X.Offset + delta.X, orbPos.Y.Scale, orbPos.Y.Offset + delta.Y)
        end
    end)
    safeConnect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then orbDragging = false end
    end)
    openButton.MouseButton1Click:Connect(function()
        if not orbMoved then win.Visible = not win.Visible end
    end)

    local winStroke = Instance.new("UIStroke")
    winStroke.Color = THEME.accent
    winStroke.Thickness = 1
    winStroke.Transparency = 0.5
    winStroke.Parent = win
    
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
    
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -40, 0.5, -15)
    minBtn.BackgroundColor3 = THEME.red
    minBtn.Text = "-"
    minBtn.TextColor3 = THEME.text
    minBtn.TextSize = 20
    minBtn.Font = Enum.Font.GothamBold
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)
    
    local isMinimized = false
    local normalSize = Vector2.new(620, 460)
    local resizeGrip = Instance.new("TextButton")
    resizeGrip.Name = "ResizeGrip"
    resizeGrip.Size = UDim2.fromOffset(24, 24)
    resizeGrip.AnchorPoint = Vector2.new(1, 1)
    resizeGrip.Position = UDim2.new(1, -3, 1, -3)
    resizeGrip.Text = "◢"
    resizeGrip.TextSize = 18
    resizeGrip.TextColor3 = THEME.accent
    resizeGrip.BackgroundTransparency = 1
    resizeGrip.ZIndex = 10
    resizeGrip.Parent = win
    local resizing, resizeStart, initialSize = false, nil, nil
    safeConnect(resizeGrip.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true; resizeStart = input.Position; initialSize = win.AbsoluteSize
        end
    end)
    safeConnect(UIS.InputChanged, function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - resizeStart
            normalSize = Vector2.new(math.clamp(initialSize.X + d.X, 430, 1050), math.clamp(initialSize.Y + d.Y, 310, 800))
            if not isMinimized then win.Size = UDim2.fromOffset(normalSize.X, normalSize.Y) end
        end
    end)
    safeConnect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then resizing = false end
    end)
    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            win.Size = UDim2.fromOffset(normalSize.X, 60)
            resizeGrip.Visible = false
            sidebar.Visible = false
            content.Visible = false
            profileFrame.Visible = false
            minBtn.Text = "+"
        else
            win.Size = UDim2.fromOffset(normalSize.X, normalSize.Y)
            resizeGrip.Visible = true
            sidebar.Visible = true
            content.Visible = true
            profileFrame.Visible = true
            minBtn.Text = "-"
        end
    end)
    
    local dragging, dragStart, startPos
    safeConnect(topBar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    safeConnect(UIS.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    
    sidebar = Instance.new("ScrollingFrame")
    sidebar.Size = UDim2.new(0, 150, 1, -60)
    sidebar.Position = UDim2.new(0, 0, 0, 60)
    sidebar.BackgroundColor3 = THEME.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 2
    sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebar.Parent = win
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 0)
    
    local sideLayout = Instance.new("UIListLayout", sidebar)
    sideLayout.Padding = UDim.new(0, 2)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sidebar.CanvasSize = UDim2.new(0, 0, 0, sideLayout.AbsoluteContentSize.Y + 20)
    end)
    local sidePad = Instance.new("UIPadding", sidebar)
    sidePad.PaddingTop = UDim.new(0, 10)
    sidePad.PaddingLeft = UDim.new(0, 8)
    sidePad.PaddingRight = UDim.new(0, 8)
    
    profileFrame = Instance.new("Frame")
    profileFrame.Size = UDim2.new(0, 150, 0, 50)
    profileFrame.Position = UDim2.new(0, 0, 1, -50)
    profileFrame.BackgroundColor3 = THEME.sidebar
    profileFrame.BorderSizePixel = 0
    profileFrame.Parent = win
    Instance.new("UICorner", profileFrame).CornerRadius = UDim.new(0, 0)
    
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
    
    content = Instance.new("Frame")
    content.Size = UDim2.new(1, -150, 1, -60)
    content.Position = UDim2.new(0, 150, 0, 60)
    content.BackgroundColor3 = THEME.bg
    content.BorderSizePixel = 0
    content.Parent = win
    
    local tabPages, tabButtons = {}, {}
    local currentActiveTab = nil
    
    local function selectTab(name)
        for pName, pg in pairs(tabPages) do pg.Visible = false end
        for bName, bt in pairs(tabButtons) do
            bt.BackgroundTransparency = 1
            bt.TextColor3 = THEME.textDim
        end
        if tabPages[name] then
            tabPages[name].Visible = true
            tabButtons[name].BackgroundTransparency = 0
            tabButtons[name].BackgroundColor3 = THEME.panel
            tabButtons[name].TextColor3 = THEME.accent
            currentActiveTab = name
        end
    end
    
    local function createAccordionCategory(categoryName)
        local catFrame = Instance.new("Frame")
        catFrame.Size = UDim2.new(1, 0, 0, 26)
        catFrame.BackgroundTransparency = 1
        catFrame.Parent = sidebar
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = "> " .. categoryName
        btn.TextColor3 = THEME.text
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = catFrame
        local pad = Instance.new("UIPadding", btn)
        pad.PaddingLeft = UDim.new(0, 4)
        
        local subContainer = Instance.new("Frame")
        subContainer.Size = UDim2.new(1, 0, 0, 0)
        subContainer.BackgroundTransparency = 1
        subContainer.Parent = sidebar
        local subLayout = Instance.new("UIListLayout", subContainer)
        subLayout.Padding = UDim.new(0, 2)
        subLayout.SortOrder = Enum.SortOrder.LayoutOrder
        subLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            subContainer.Size = UDim2.new(1, 0, 0, subLayout.AbsoluteContentSize.Y)
        end)
        local subPad = Instance.new("UIPadding", subContainer)
        subPad.PaddingLeft = UDim.new(0, 10)
        
        local isOpen = (categoryName == "Combate" or categoryName == "Visual (ESP)")
        subContainer.Visible = isOpen
        btn.Text = (isOpen and "v " or "> ") .. categoryName
        btn.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            subContainer.Visible = isOpen
            btn.Text = (isOpen and "v " or "> ") .. categoryName
        end)
        return subContainer
    end
    
    local function createSubTab(parent, name)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 26)
        b.BackgroundTransparency = 1
        b.Text = name
        b.TextColor3 = THEME.textDim
        b.TextSize = 13
        b.Font = Enum.Font.Gotham
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = parent
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
        pl.Padding = UDim.new(0, 6)
        pl.SortOrder = Enum.SortOrder.LayoutOrder
        pl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            sc.CanvasSize = UDim2.new(0, 0, 0, pl.AbsoluteContentSize.Y + 20)
        end)
    
        tabPages[name] = sc
        tabButtons[name] = b
        b.MouseButton1Click:Connect(function() selectTab(name) end)
        return sc
    end
    
    local catCombate = createAccordionCategory("Combate")
    local catVisual = createAccordionCategory("Visual (ESP)")
    local catVeiculos = createAccordionCategory("Veículos")
    local catDiversao = createAccordionCategory("Diversão")
    local catConfig = createAccordionCategory("Configurações")
    
    local aimPage = createSubTab(catCombate, "Aimbot")
    local armPage = createSubTab(catCombate, "Armas")
    local espPlayerPage = createSubTab(catVisual, "Jogadores")
    local espCarPage = createSubTab(catVisual, "Carros")
    local crossPage = createSubTab(catVisual, "Crosshair")
    local carFisicaPage = createSubTab(catVeiculos, "Física")
    local carListPage = createSubTab(catVeiculos, "Lista")
    local funChatPage = createSubTab(catDiversao, "Chat / Ações")
    local funTpPage = createSubTab(catDiversao, "Teleporte Jogadores")
    local keybindsPage = createSubTab(catConfig, "Keybinds / Unload")
    
    selectTab("Aimbot")
    local headings = {
        {aimPage, "AIMBOT OPTIONS"}, {armPage, "WEAPON OPTIONS"},
        {espPlayerPage, "ESP OPTIONS"}, {espCarPage, "VEHICLE ESP OPTIONS"},
        {crossPage, "CROSSHAIR OPTIONS"}, {carFisicaPage, "VEHICLE PHYSICS"},
        {carListPage, "VEHICLE TELEPORT"}, {funChatPage, "FUN OPTIONS"},
        {funTpPage, "PLAYER TELEPORT OPTIONS"}, {keybindsPage, "MENU SETTINGS"},
    }
    for _, item in ipairs(headings) do
        local heading = Instance.new("TextLabel")
        heading.Name = "SectionHeading"
        heading.LayoutOrder = -100
        heading.Size = UDim2.new(1, -10, 0, 42)
        heading.BackgroundTransparency = 1
        heading.Text = item[2]
        heading.Font = Enum.Font.GothamBold
        heading.TextSize = 17
        heading.TextColor3 = THEME.accent
        heading.TextXAlignment = Enum.TextXAlignment.Left
        heading.Parent = item[1]
    end
    
    local function makeToggle(parent, label, key, cb)
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, -10, 0, 26)
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
        b.Size = UDim2.new(0, 36, 0, 18)
        b.Position = UDim2.new(1, -36, 0.5, -9)
        b.BackgroundColor3 = cfg[key] and THEME.accent or THEME.off
        b.Text = ""
        b.AutoButtonColor = false
        b.Parent = r
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 14, 0, 14)
        dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dot.Parent = b
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        
        local function updateVisuals()
            local goalColor = cfg[key] and THEME.accent or THEME.off
            local goalPos = cfg[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = goalColor}):Play()
            TweenService:Create(dot, TweenInfo.new(0.2), {Position = goalPos}):Play()
        end
        dot.Position = cfg[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        
        b.MouseButton1Click:Connect(function()
            cfg[key] = not cfg[key]
            updateVisuals()
            if cb then
                local result = cb(cfg[key])
                if result == false then
                    cfg[key] = false
                    updateVisuals()
                end
            end
        end)
    end
    
    local function makeSlider(parent, label, key, mn, mx, def, isInt)
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, -10, 0, 51)
        r.BackgroundTransparency = 1
        r.Parent = parent
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -96, 0, 18)
        l.BackgroundTransparency = 1
        l.TextColor3 = THEME.text
        l.TextSize = 12
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = r
        local valueBox = Instance.new("TextBox")
        valueBox.Size = UDim2.fromOffset(85, 23)
        valueBox.Position = UDim2.new(1, -85, 0, 0)
        valueBox.BackgroundColor3 = THEME.off
        valueBox.TextColor3 = THEME.accent
        valueBox.TextSize = 12
        valueBox.Font = Enum.Font.Code
        valueBox.ClearTextOnFocus = false
        valueBox.Parent = r
        Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 4)
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -12, 0, 5)
        bar.Position = UDim2.new(0, 6, 0, 36)
        bar.BackgroundColor3 = THEME.off
        bar.BorderSizePixel = 0
        bar.Parent = r
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = THEME.accent
        fill.BorderSizePixel = 0
        fill.Parent = bar
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(14, 14)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = Color3.fromRGB(245, 245, 255)
        knob.BorderSizePixel = 0
        knob.Parent = bar
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local function setValue(v)
            v = math.clamp(v, mn, mx)
            if isInt then v = math.floor(v + 0.5) else v = math.floor(v * 100 + 0.5) / 100 end
            cfg[key] = v
            local pct = (v - mn) / (mx - mn)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, 0, 0.5, 0)
            local display = isInt and string.format("%d", v) or string.format("%.2f", v)
            l.Text = label .. ": " .. display
            if not valueBox:IsFocused() then valueBox.Text = display end
        end
        setValue(cfg[key] or def)
        valueBox.FocusLost:Connect(function()
            local v = tonumber((valueBox.Text:gsub(",", ".")))
            if v then setValue(v) else valueBox.Text = tostring(cfg[key]) end
        end)
        local draggingSlider = false
        local function updateAt(x)
            if bar.AbsoluteSize.X > 0 then
                setValue(mn + math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1) * (mx - mn))
            end
        end
        for _, obj in ipairs({bar, knob}) do
            obj.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    draggingSlider = true
                    updateAt(input.Position.X)
                end
            end)
        end
        safeConnect(UIS.InputChanged, function(input)
            if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateAt(input.Position.X) end
        end)
        safeConnect(UIS.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingSlider = false end
        end)
    end

    local function makeButton(parent, text, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 28)
        b.BackgroundColor3 = THEME.off
        b.Text = text
        b.TextColor3 = THEME.text
        b.TextSize = 12
        b.Font = Enum.Font.GothamBold
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        b.MouseButton1Click:Connect(callback)
    end
    
    makeToggle(aimPage, "Aimbot", "Aimbot")
    makeSlider(aimPage, "FOV", "FOV", 20, 400, 120, true)
    makeSlider(aimPage, "Smooth", "Smooth", 0.05, 1, 0.25, false)
    makeToggle(aimPage, "Team Check", "TeamCheckAimbot")
    makeToggle(aimPage, "Wall Check", "WallCheckAimbot")
    
    makeToggle(armPage, "No Recoil", "NoRecoil")
    makeToggle(armPage, "No Spread", "NoSpread")
    
    makeToggle(espPlayerPage, "ESP Box", "ESP_Box")
    makeToggle(espPlayerPage, "ESP Name", "ESP_Name")
    makeToggle(espPlayerPage, "ESP Health", "ESP_Health")
    makeToggle(espPlayerPage, "ESP Distance", "ESP_Distance")
    makeToggle(espPlayerPage, "ESP Tracer", "ESP_Tracer")
    makeToggle(espPlayerPage, "ESP Skeleton", "ESP_Skeleton")
    makeToggle(espPlayerPage, "Team Check", "TeamCheckESP")
    makeToggle(espPlayerPage, "Wall Check", "WallCheckESP")
    
    makeToggle(espCarPage, "ESP Veículos", "ESP_Vehicles")
    
    makeToggle(crossPage, "Ativar Crosshair", "Crosshair_On")
    makeToggle(crossPage, "Modo Ponto ( . )", "Crosshair_Dot")
    makeToggle(crossPage, "Contorno Preto", "Crosshair_Outline")
    makeSlider(crossPage, "Grossura", "Crosshair_Thickness", 1, 5, 2, true)
    makeSlider(crossPage, "Tamanho (Pontas)", "Crosshair_Length", 1, 20, 10, true)
    makeSlider(crossPage, "Espaço (Gap)", "Crosshair_Gap", 0, 20, 5, true)
    
    local hexBox = Instance.new("TextBox")
    hexBox.Size = UDim2.new(1, -10, 0, 26)
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
            local okC, color = pcall(Color3.fromHex, hex)
            if okC then cfg.Crosshair_Color = color end
        end
    end)
    
    makeToggle(carFisicaPage, "Ativar Grab / Throw", "CarGrabActive")
    makeSlider(carFisicaPage, "Força do Arremesso", "ThrowPower", 0, 10, 5, true)
    makeToggle(carFisicaPage, "Car Fly (WASD)", "CarFly", function(s) toggleCarFly(s) end)
    
    local vehScroll = Instance.new("ScrollingFrame")
    vehScroll.Size = UDim2.new(1, -10, 0, 200)
    vehScroll.BackgroundColor3 = THEME.panel
    vehScroll.BorderSizePixel = 0
    vehScroll.ScrollBarThickness = 2
    vehScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    vehScroll.Parent = carListPage
    Instance.new("UICorner", vehScroll).CornerRadius = UDim.new(0, 4)
    local vLayout = Instance.new("UIListLayout", vehScroll)
    vLayout.Padding = UDim.new(0, 4)
    vLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        vehScroll.CanvasSize = UDim2.new(0, 0, 0, vLayout.AbsoluteContentSize.Y + 10)
    end)
    
    local function findVehicles()
        local vehicles, seen = {}, {}
        for _, inst in ipairs(workspace:GetDescendants()) do
            if inst:IsA("VehicleSeat") then
                local model = inst:FindFirstAncestorOfClass("Model")
                if model and not seen[model] and not (LP.Character and model:IsDescendantOf(LP.Character)) then
                    seen[model] = true
                    table.insert(vehicles, {model = model, seat = inst})
                end
            end
        end
        return vehicles
    end

    local function refreshVehicleList()
        for _, c in ipairs(vehScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local found = {}
        for _, vehicle in ipairs(findVehicles()) do
            local dist = (vehicle.seat.Position - hrp.Position).Magnitude
            table.insert(found, {model = vehicle.model, seat = vehicle.seat, dist = dist})
        end
        table.sort(found, function(a, b) return a.dist < b.dist end)
        for i = 1, math.min(#found, 15) do
            local data = found[i]
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -10, 0, 26)
            btn.BackgroundColor3 = THEME.off
            btn.Text = string.format("  %s [%dm]", data.model.Name, math.floor(data.dist))
            btn.TextColor3 = THEME.text
            btn.TextSize = 11
            btn.Font = Enum.Font.Gotham
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.Parent = vehScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            btn.MouseButton1Click:Connect(function()
                pcall(function()
                    local currentRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if not currentRoot or not data.model.Parent then return end
                    if data.seat.Occupant then
                        warn("[cqber] TP: veiculo ocupado; o servidor pode bloquear o movimento")
                        return
                    end
                    local targetCF = currentRoot.CFrame * CFrame.new(0, 2, -12)
                    data.model:PivotTo(targetCF)
                end)
            end)
        end
    end
    makeButton(carListPage, "Atualizar Lista", refreshVehicleList)
    
    local function sendChat(cmd)
        local chat = game:GetService("TextChatService")
        if chat.ChatVersion == Enum.ChatVersion.TextChatService then
            chat.ChatInputBarConfiguration.TargetTextChannel:SendAsync(cmd)
        else
            game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents"):FindFirstChild("SayMessageRequest"):FireServer(cmd, "All")
        end
    end
    
    makeButton(funChatPage, "Dar /e dance", function() sendChat("/e dance") end)
    makeButton(funChatPage, "Dar /e dance2", function() sendChat("/e dance2") end)
    makeButton(funChatPage, "Dar /e dance3", function() sendChat("/e dance3") end)
    makeButton(funChatPage, "Dar /e point", function() sendChat("/e point") end)
    makeButton(funChatPage, "Dar /e wave", function() sendChat("/e wave") end)
    makeButton(funChatPage, "Dar /e laugh", function() sendChat("/e laugh") end)
    
    local spinToggle = Instance.new("TextButton")
    spinToggle.Size = UDim2.new(1, -10, 0, 26)
    spinToggle.BackgroundColor3 = THEME.off
    spinToggle.Text = "SPIN (Girar)"
    spinToggle.TextColor3 = THEME.text
    spinToggle.TextSize = 12
    spinToggle.Font = Enum.Font.GothamBold
    spinToggle.Parent = funChatPage
    Instance.new("UICorner", spinToggle).CornerRadius = UDim.new(0, 4)
    local isSpinning = false
    spinConn = nil
    spinToggle.MouseButton1Click:Connect(function()
        isSpinning = not isSpinning
        if isSpinning then
            spinToggle.Text = "UNSPIN (Parar)"
            spinToggle.BackgroundColor3 = THEME.accent
            spinConn = RunService.Heartbeat:Connect(function()
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(15), 0) end
            end)
        else
            spinToggle.Text = "SPIN (Girar)"
            spinToggle.BackgroundColor3 = THEME.off
            if spinConn then spinConn:Disconnect(); spinConn = nil end
        end
    end)
    
    local tpScroll = Instance.new("ScrollingFrame")
    tpScroll.Size = UDim2.new(1, -10, 0, 200)
    tpScroll.BackgroundColor3 = THEME.panel
    tpScroll.BorderSizePixel = 0
    tpScroll.ScrollBarThickness = 2
    tpScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    tpScroll.Parent = funTpPage
    Instance.new("UICorner", tpScroll).CornerRadius = UDim.new(0, 4)
    local tpLayout = Instance.new("UIListLayout", tpScroll)
    tpLayout.Padding = UDim.new(0, 4)
    tpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        tpScroll.CanvasSize = UDim2.new(0, 0, 0, tpLayout.AbsoluteContentSize.Y + 10)
    end)
    
    local function refreshTpList()
        for _, child in ipairs(tpScroll:GetChildren()) do
            if child:IsA("GuiObject") and child.Name == "PlayerTeleportRow" then
                child:Destroy()
            end
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP then
                local row = Instance.new("Frame")
                row.Name = "PlayerTeleportRow"
                row.Size = UDim2.new(1, -10, 0, 54)
                row.BackgroundColor3 = THEME.off
                row.BorderSizePixel = 0
                row.Parent = tpScroll
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

                local name = Instance.new("TextLabel")
                name.Size = UDim2.new(1, -12, 0, 22)
                name.Position = UDim2.fromOffset(6, 1)
                name.BackgroundTransparency = 1
                name.Text = player.DisplayName .. " (@" .. player.Name .. ")"
                name.TextColor3 = THEME.text
                name.TextSize = 11
                name.Font = Enum.Font.Gotham
                name.TextXAlignment = Enum.TextXAlignment.Left
                name.TextTruncate = Enum.TextTruncate.AtEnd
                name.Parent = row

                local function actionButton(label, xScale, callback)
                    local button = Instance.new("TextButton")
                    button.Size = UDim2.new(0.5, -9, 0, 24)
                    button.Position = UDim2.new(xScale, xScale == 0 and 5 or 4, 0, 26)
                    button.BackgroundColor3 = THEME.panel
                    button.TextColor3 = THEME.accent
                    button.TextSize = 11
                    button.Font = Enum.Font.GothamBold
                    button.Text = label
                    button.Parent = row
                    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
                    button.MouseButton1Click:Connect(callback)
                end

                actionButton("Ir até", 0, function()
                    local myChar = LP.Character
                    local targetRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if not (myChar and targetRoot) then
                        warn("[cqber] Jogador sem personagem carregado:", player.Name)
                        return
                    end
                    local destination = targetRoot.CFrame * CFrame.new(0, 0, 4)
                    local okTp, tpErr = pcall(function() myChar:PivotTo(destination) end)
                    if not okTp then warn("[cqber] Falha ao ir até jogador:", tpErr) end
                end)

                actionButton("Trazer", 0.5, function()
                    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if not (myRoot and player.Character) then return end
                    local okTp, tpErr = pcall(function()
                        player.Character:PivotTo(myRoot.CFrame * CFrame.new(0, 0, -4))
                    end)
                    if not okTp then warn("[cqber] Falha ao tentar trazer jogador:", tpErr) end
                    -- Em jogos comuns, o servidor nao aceita TP local de outro jogador.
                end)
            end
        end
    end

    makeButton(funTpPage, "Atualizar Jogadores", refreshTpList)
    refreshTpList()
    Players.PlayerAdded:Connect(function() task.wait(0.5); refreshTpList() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshTpList() end)
    
    -- [ ABA CONFIGURAÇÕES ]
    local function unloadScript()
        isUnloaded = true
        for _, conn in ipairs(allConnections) do pcall(function() conn:Disconnect() end) end
        if sg then sg:Destroy() end
        if stopGrab then pcall(function() stopGrab(true) end) end
        for _, obj in pairs(esp or {}) do
            for k, v in pairs(obj) do
                if k == "skeleton" then
                    for _, l in ipairs(v) do pcall(function() l:Remove() end) end
                else pcall(function() v:Remove() end) end
            end
        end
        for _, data in pairs(espVeh or {}) do if data.box then pcall(function() data.box:Remove() end) end end
        if crossLines then for _, l in ipairs(crossLines) do pcall(function() l:Remove() end) end end
        if outlineLines then for _, l in ipairs(outlineLines) do pcall(function() l:Remove() end) end end
        if fovCircle then pcall(function() fovCircle:Remove() end) end
        if crossDot then pcall(function() crossDot:Remove() end) end
        if spinConn then spinConn:Disconnect() end
        if flyConn then flyConn:Disconnect() end
        if flyVel then flyVel:Destroy() end
        print("[cqber] Script Unloaded.")
    end
    
    makeButton(keybindsPage, "UNLOAD SCRIPT", unloadScript)
    makeToggle(keybindsPage, "Streamproof (Ocultar)", "Streamproof", function(s) return setStreamproof(s) end)
    
    local function makeBind(parent, label, key)
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, -10, 0, 26)
        r.BackgroundTransparency = 1
        r.Parent = parent
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -70, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = THEME.text
        l.TextSize = 13
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = r
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 60, 0, 22)
        b.Position = UDim2.new(1, -60, 0.5, -11)
        b.BackgroundColor3 = THEME.off
        b.Text = "Definir"
        b.TextColor3 = THEME.textDim
        b.TextSize = 11
        b.Font = Enum.Font.GothamBold
        b.Parent = r
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        
        b.MouseButton1Click:Connect(function()
            b.Text = "Aperte..."
            local conn
            task.defer(function()
            conn = UIS.InputBegan:Connect(function(i, gp)
                if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then return end
                local v = i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode or i.UserInputType
                if v == Enum.KeyCode.Escape then
                    b.Text = "Definir"
                    conn:Disconnect()
                    return
                end
                cfg[key] = v
                b.Text = tostring(v):gsub("Enum.", "")
                conn:Disconnect()
            end)
            end)
        end)
    end
    
    makeBind(keybindsPage, "Bind Menu", "MenuBind")
    makeBind(keybindsPage, "Bind Car Grab", "GrabBind")
    makeBind(keybindsPage, "Bind Car Throw", "ThrowBind")
    
    -- ============ CROSSHAIR, ESP, AIMBOT ============
    crossLines, outlineLines = {}, {}
    if HAS_D then
        for i = 1, 4 do
            local line = Drawing.new("Line"); line.Visible = false; table.insert(crossLines, line)
            local oLine = Drawing.new("Line"); oLine.Color = Color3.fromRGB(0, 0, 0); oLine.Visible = false; table.insert(outlineLines, oLine)
        end
    end
    crossDot = nil
    if HAS_D then
        crossDot = Drawing.new("Circle")
        crossDot.Filled = true
        crossDot.Visible = false
    end
    
    local function updateCrosshair()
        if not HAS_D or isUnloaded then return end
        if not cfg.Crosshair_On then
            for i = 1, 4 do crossLines[i].Visible = false; outlineLines[i].Visible = false end
            if crossDot then crossDot.Visible = false end
            return
        end
        local center = Cam.ViewportSize / 2
        local gap, len, c, out, thick = cfg.Crosshair_Gap, cfg.Crosshair_Length, cfg.Crosshair_Color, cfg.Crosshair_Outline, cfg.Crosshair_Thickness
    
        if cfg.Crosshair_Dot then
            if crossDot then
                crossDot.Position = center; crossDot.Radius = thick + 1; crossDot.Color = c; crossDot.Visible = true
            end
            for i = 1, 4 do crossLines[i].Visible = false; outlineLines[i].Visible = false end
        else
            if crossDot then crossDot.Visible = false end
            local positions = {
                {Vector2.new(center.X, center.Y - gap), Vector2.new(center.X, center.Y - gap - len)},
                {Vector2.new(center.X, center.Y + gap), Vector2.new(center.X, center.Y + gap + len)},
                {Vector2.new(center.X - gap, center.Y), Vector2.new(center.X - gap - len, center.Y)},
                {Vector2.new(center.X + gap, center.Y), Vector2.new(center.X + gap + len, center.Y)},
            }
            for i = 1, 4 do
                local pos = positions[i]
                if out then
                    outlineLines[i].From = pos[1]; outlineLines[i].To = pos[2]
                    outlineLines[i].Thickness = thick + 2; outlineLines[i].Visible = true
                else outlineLines[i].Visible = false end
                crossLines[i].From = pos[1]; crossLines[i].To = pos[2]
                crossLines[i].Color = c; crossLines[i].Thickness = thick; crossLines[i].Visible = true
            end
        end
    end
    
    fovCircle = nil
    if HAS_D then
        fovCircle = Drawing.new("Circle")
        fovCircle.Color = THEME.accent; fovCircle.Thickness = 1.5; fovCircle.Filled = false; fovCircle.Transparency = 0.8
    end
    
    esp, espVeh = {}, {}
    local espVisTimer = {}
    local function drawESP(p)
        if p == LP or esp[p] or not HAS_D then return end
        esp[p] = {
            box = Drawing.new("Square"), head = Drawing.new("Circle"), health = Drawing.new("Square"),
            name = Drawing.new("Text"), dist = Drawing.new("Text"), tracer = Drawing.new("Line"), skeleton = {},
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
                elseif k == "head" then v.Thickness = 1.5; v.Filled = false; v.Radius = 6
                elseif k == "health" then v.Thickness = 1; v.Filled = true; v.Transparency = 0.7 end
            end
        end
    end
    
    local function drawVehESP(model)
        if espVeh[model] or not HAS_D then return end
        local box = Drawing.new("Square"); box.Color = THEME.accent; box.Thickness = 1; box.Filled = false
        espVeh[model] = { box = box }
    end
    
    for _, v in ipairs(findVehicles()) do drawVehESP(v.model) end
    safeConnect(workspace.DescendantAdded, function(inst)
        if inst:IsA("VehicleSeat") then
            task.defer(function()
                if isUnloaded then return end
                local model = inst:FindFirstAncestorOfClass("Model")
                if model then drawVehESP(model) end
            end)
        end
    end)
    
    safeConnect(Players.PlayerAdded, drawESP)
    for _, p in ipairs(Players:GetPlayers()) do drawESP(p) end
    
    safeConnect(Players.PlayerRemoving, function(p)
        local o = esp[p]
        if o then
            for k, v in pairs(o) do
                if k == "skeleton" then for _, l in ipairs(v) do l:Remove() end
                else v:Remove() end
            end
            esp[p] = nil
        end
        espVisTimer[p] = nil; wallCheckCache[p] = nil
    end)
    
    local function hideAll(o)
        for k, v in pairs(o) do
            if k == "skeleton" then for _, l in ipairs(v) do l.Visible = false end
            else v.Visible = false end
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
                    local h = math.abs(tp.Y - bp.Y); local w = h * 0.6
                    local x = (tp.X + bp.X)/2; local y = (tp.Y + bp.Y)/2
                    o.box.Size = Vector2.new(w, h); o.box.Position = Vector2.new(x - w/2, y - h/2); o.box.Visible = cfg.ESP_Box
                    local ratio = hum.Health / hum.MaxHealth
                    o.health.Size = Vector2.new(3, h * ratio); o.health.Position = Vector2.new(x - w/2 - 6, y + h/2 - h*ratio); o.health.Visible = cfg.ESP_Health
                    o.name.Text = p.Name; o.name.Position = Vector2.new(x, y - h/2 - 18); o.name.Visible = cfg.ESP_Name
                    if cfg.ESP_Distance and myHrp then
                        o.dist.Text = "[" .. math.floor((hrp.Position - myHrp.Position).Magnitude) .. "m]"
                        o.dist.Position = Vector2.new(x, y + h/2 + 4); o.dist.Visible = true
                    else o.dist.Visible = false end
                    if cfg.ESP_Tracer then
                        o.tracer.From = Vector2.new(screenSize.X/2, screenSize.Y); o.tracer.To = Vector2.new(x, y + h/2); o.tracer.Visible = true
                    else o.tracer.Visible = false end
                else
                    o.box.Visible = false; o.health.Visible = false; o.name.Visible = false; o.dist.Visible = false; o.tracer.Visible = false
                end
                local hp, hon = Cam:WorldToViewportPoint(hd.Position)
                if hon and cfg.ESP_Head then
                    o.head.Position = Vector2.new(hp.X, hp.Y); o.head.Visible = true
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
                                local line = o.skeleton[idx]; line.From = Vector2.new(s1.X, s1.Y); line.To = Vector2.new(s2.X, s2.Y); line.Visible = true; idx = idx + 1
                            end
                        end
                    end
                    for i = idx, #o.skeleton do o.skeleton[i].Visible = false end
                else for _, l in ipairs(o.skeleton) do l.Visible = false end end
            end
        end
    
        for model, data in pairs(espVeh) do
            if cfg.ESP_Vehicles and model.Parent and model:FindFirstChildWhichIsA("VehicleSeat", true) then
                local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
                local pos, on = Cam:WorldToViewportPoint(seat.Position)
                if on then
                    data.box.Size = Vector2.new(40, 20); data.box.Position = Vector2.new(pos.X - 20, pos.Y - 10); data.box.Visible = true
                else data.box.Visible = false end
            else data.box.Visible = false end
            if not model.Parent then
                pcall(function() data.box:Remove() end)
                espVeh[model] = nil
            end
        end
    end
    
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
        if not cfg.Aimbot or isUnloaded then return end
        local t = closest()
        if not t then return end
        if HAS_M then
            local tp = Cam:WorldToViewportPoint(t.Position)
            local mp = UIS:GetMouseLocation()
            local d = Vector2.new(tp.X, tp.Y) - mp
            if d.Magnitude > 1 then mousemoverel(d.X * cfg.Smooth, d.Y * cfg.Smooth) end
        else
            Cam.CFrame = Cam.CFrame:Lerp(CFrame.new(Cam.CFrame.Position, t.Position), cfg.Smooth)
        end
    end
    
    pcall(function()
        if not hookmetamethod then return end
        local mt = getrawmetatable(game); local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local m = getnamecallmethod()
            if cfg.NoRecoil and (m == "Fire" or m == "Shoot") and not checkcaller() then
                if self:IsA("Tool") and self:FindFirstChild("Recoil") then return end
            end
            if cfg.NoSpread and m == "Fire" and self:IsA("Tool") then
                local s = Cam:FindFirstChild("Spread") or Cam:FindFirstChild("WeaponSpread")
                if s and s:IsA("NumberValue") then s.Value = 0 end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)
    
    -- Grab / Throw: preserva o estado original e usa a montagem fisica do veiculo.
    local grabbedCar, grabConn, grabState = nil, nil, nil
    local grabOffset = CFrame.new(0, 5, -12)

    local function nearestCar(maxDist)
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local best, distance = nil, tonumber(maxDist) or 45
        for _, vehicle in ipairs(findVehicles()) do
            local seat = vehicle.seat
            if seat and seat.Parent and seat:IsA("BasePart") then
                local d = (seat.Position - root.Position).Magnitude
                if d < distance then
                    best, distance = vehicle.model, d
                end
            end
        end
        return best
    end

    stopGrab = function(restore)
        if grabConn then grabConn:Disconnect(); grabConn = nil end
        if grabState and restore ~= false then
            for part, props in pairs(grabState.parts) do
                if part.Parent then
                    pcall(function()
                        part.Anchored = props.anchored
                        part.CanCollide = props.collide
                    end)
                end
            end
        end
        grabbedCar, grabState = nil, nil
    end

    local function grabCar()
        if not cfg.CarGrabActive or isUnloaded then return end
        if grabbedCar then stopGrab(true) end
        local model = nearestCar(cfg.GrabDistance)
        if not model then
            warn("[cqber] Nenhum veiculo proximo encontrado")
            return
        end
        local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
        if not seat then return end
        local occupied = seat.Occupant ~= nil
        if occupied then
            warn("[cqber] Veiculo ocupado: o servidor pode impedir o Grab/Throw")
        end
        local parts = {}
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("BasePart") then
                parts[obj] = {anchored = obj.Anchored, collide = obj.CanCollide}
                -- So muda colisao/ancoragem em carros desocupados.
                if not occupied then
                    obj.Anchored = true
                    obj.CanCollide = false
                end
            end
        end
        grabbedCar = model
        grabState = {parts = parts, occupied = occupied, seat = seat}
        local last = model:GetPivot()
        local lastT = os.clock()
        grabConn = RunService.Heartbeat:Connect(function()
            if isUnloaded or not cfg.CarGrabActive or not model.Parent then
                stopGrab(true)
                return
            end
            local char = LP.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then stopGrab(true); return end
            local now = os.clock()
            local dt = math.clamp(now - lastT, 0, 0.1)
            lastT = now
            local target = root.CFrame * grabOffset
            local alpha = 1 - math.exp(-math.max(1, cfg.GrabFollowSpeed) * dt)
            last = last:Lerp(target, alpha)
            local success, errMove = pcall(function() model:PivotTo(last) end)
            if not success then
                warn("[cqber] Falha no Grab:", errMove)
                stopGrab(true)
            end
        end)
    end

    local function throwCar()
        if not grabbedCar or not grabState or isUnloaded then return end
        local model, state = grabbedCar, grabState
        local power = math.clamp(tonumber(cfg.ThrowPower) or 0, 0, 10)
        if grabConn then grabConn:Disconnect(); grabConn = nil end
        grabbedCar, grabState = nil, nil

        local camera = workspace.CurrentCamera
        local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
        flat = flat.Unit
        local direction = (flat + Vector3.new(0, 0.8, 0)).Unit

        -- Primeiro desloca o modelo ainda segurado; em seguida libera a fisica.
        -- Em veiculos controlados pelo servidor o PivotTo pode ser revertido.
        if power > 0 and model.Parent then
            local shift = flat * (8 + power * 3) + Vector3.new(0, 5 + power * 2, 0)
            local okMove, moveErr = pcall(function()
                model:PivotTo(model:GetPivot() + shift)
            end)
            if not okMove then warn("[cqber] TP local do carro falhou:", moveErr) end
        end

        for part, props in pairs(state.parts) do
            if part.Parent then
                pcall(function()
                    part.Anchored = props.anchored
                    part.CanCollide = props.collide
                end)
            end
        end
        if power <= 0 then return end

        local roots, seen = {}, {}
        for part, props in pairs(state.parts) do
            if part.Parent and not props.anchored then
                local root = part.AssemblyRootPart or part
                if root and not root.Anchored and not seen[root] then
                    seen[root] = true
                    table.insert(roots, root)
                end
            end
        end
        local speed = 45 + power * 23
        local velocity = direction * speed + Vector3.new(0, 15 + power * 8, 0)
        local moved = 0
        for _, root in ipairs(roots) do
            if pcall(function()
                root.AssemblyLinearVelocity = velocity
                root:ApplyImpulse(velocity * root.AssemblyMass)
                root.AssemblyAngularVelocity = Vector3.new(4, 9, 5) * (power / 5)
            end) then moved = moved + 1 end
        end
        if moved == 0 then
            warn("[cqber] Carro sem partes fisicas livres ou controlado pelo servidor")
        end
    end

    flyConn, flyVel = nil, nil
    function toggleCarFly(s)
        if isUnloaded then return end
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        if flyVel then flyVel:Destroy(); flyVel = nil end
        if not s then return end
        local c = LP.Character; local hum = c and c:FindFirstChildOfClass("Humanoid")
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
        flyVel = Instance.new("BodyVelocity"); flyVel.Velocity = Vector3.zero; flyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5); flyVel.Parent = rp
        flyConn = RunService.Heartbeat:Connect(function()
            if not cfg.CarFly or not rp or not rp.Parent or isUnloaded then return end
            local dir = Vector3.zero; local cf = Cam.CFrame
            if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
            flyVel.Velocity = dir.Magnitude > 0 and dir.Unit * 50 or Vector3.zero
        end)
    end
    
    function setStreamproof(state)
        if state then
            warn("[cqber] Streamproof nao e garantido por scripts locais; opcao desativada")
            return false
        end
        return true
    end

    local bindCapture = nil
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
        for _, gui in ipairs(guis) do
            if gui:IsDescendantOf(sg) then return true end
        end
        return false
    end
    
    safeConnect(UIS.InputBegan, function(input, gp)
        if bindCapture or UIS:GetFocusedTextBox() or isUnloaded then return end
        if matches(input, cfg.MenuBind) then
            if not gp then win.Visible = not win.Visible end
        elseif matches(input, cfg.GrabBind) then
            if cfg.CarGrabActive then grabCar() end
        elseif matches(input, cfg.ThrowBind) then
            if cfg.CarGrabActive and not gp then
                if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseOverUI() then return end
                throwCar()
            end
        end
    end)
    
    safeConnect(RunService.RenderStepped, function()
        if isUnloaded then return end
        if fovCircle then
            if cfg.FOV > 0 and cfg.Aimbot then
                fovCircle.Visible = true; fovCircle.Position = UIS:GetMouseLocation(); fovCircle.Radius = cfg.FOV
            else fovCircle.Visible = false end
        end
        updateCrosshair()
        updESP()
        runAim()
    end)
    
    print("[cqber] Menu carregado e atualizado com sucesso.")
end)
if not ok then
    warn("[cqber ERRO]", err)
    print("[cqber ERRO]", err)
end
