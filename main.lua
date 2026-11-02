local ok, err = pcall(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local LP = Players.LocalPlayer
    local Cam = workspace.CurrentCamera
    
    -- Banner geometrico preto e branco, sem asset externo 
    local BANNER_IMAGE = "rbxassetid://13836896689"
    local THEME = {
        bg = Color3.fromRGB(15, 15, 20), sidebar = Color3.fromRGB(20, 20, 28),
        panel = Color3.fromRGB(25, 25, 35), text = Color3.fromRGB(240, 240, 240),
        textDim = Color3.fromRGB(130, 130, 140), accent = Color3.fromRGB(0, 190, 255),
        red = Color3.fromRGB(255, 60, 60), off = Color3.fromRGB(45, 45, 55),
    }
    
    local cfg = {
        RapidFire = false, Aimbot = false, CarFly = false, CarGrabActive = false, NoRecoil = false, NoSpread = false,
        Streamproof = false, ESP_Box = false, ESP_Name = false, ESP_Health = false, ESP_Distance = false,
        ESP_Tracer = false, ESP_Skeleton = false, ESP_Head = false, ESP_Vehicles = false, TeamCheckAimbot = false,
        TeamCheckESP = false, WallCheckAimbot = false, WallCheckESP = false, TargetPlayer = nil,
        TargetOnESP = false, FOV = 120, Smooth = 0.25, ThrowPower = 5, GrabDistance = 75,
        GrabFollowSpeed = 16, MenuBind = Enum.KeyCode.Insert, GrabBind = Enum.KeyCode.Y,
        ThrowBind = Enum.UserInputType.MouseButton1, Crosshair_On = false, Crosshair_Thickness = 2,
        Crosshair_Length = 10, Crosshair_Gap = 5, Crosshair_Color = Color3.fromRGB(240, 240, 240),
        Crosshair_Hex = "#00FF88", Crosshair_Outline = true, Crosshair_Dot = false,
    }
    
    -- Perfis: apenas valores simples da configuracao; nunca executa codigo importado.
    local PROFILE_FILE = "CQBER_Menu_Profile.json"
    local profileRefresh = {}
    local profileSaving = false
    local function profileData()
        local data = {}
        for k, v in pairs(cfg) do
            if typeof(v) == "boolean" or typeof(v) == "number" or typeof(v) == "string" then
                data[k] = v
            elseif typeof(v) == "EnumItem" then
                data[k] = tostring(v)
            end
        end
        return data
    end
    local function profileApply(data)
        if type(data) ~= "table" then return false end
        for k, v in pairs(data) do
            local old = cfg[k]
            if old ~= nil then
                if typeof(old) == "boolean" and type(v) == "boolean" then
                    cfg[k] = v
                elseif typeof(old) == "number" and type(v) == "number" and v == v and math.abs(v) < 100000 then
                    cfg[k] = v
                elseif typeof(old) == "string" and type(v) == "string" and #v <= 128 then
                    cfg[k] = v
                elseif typeof(old) == "EnumItem" and type(v) == "string" then
                    local typ, item = v:match("^Enum%.([%w_]+)%.([%w_]+)$")
                    if (typ == "KeyCode" or typ == "UserInputType") and Enum[typ] then
                        local ok, enumVal = pcall(function() return Enum[typ][item] end)
                        if ok and enumVal then cfg[k] = enumVal end
                    end
                end
            end
        end
        for _, refresh in pairs(profileRefresh) do pcall(refresh) end
        return true
    end
    local function profileSave()
        if type(writefile) ~= "function" then return false end
        local ok = pcall(function() writefile(PROFILE_FILE, HttpService:JSONEncode(profileData())) end)
        return ok
    end
    local saveSequence = 0
    local function scheduleProfileSave()
        saveSequence = saveSequence + 1
        local seq = saveSequence
        task.delay(0.8, function()
            if seq == saveSequence then profileSave() end
        end)
    end
    if type(readfile) == "function" then
        pcall(function()
            local saved = HttpService:JSONDecode(readfile(PROFILE_FILE))
            profileApply(saved)
        end)
    end
    local function profileEncode()
        -- Codigo compartilhavel: JSON com prefixo; nao e codigo Lua executavel.
        return "CQBER1:" .. HttpService:JSONEncode(profileData())
    end
    local function profileImport(code)
        if type(code) ~= "string" or #code > 16000 then return false, "Codigo invalido ou grande demais" end
        local json = code:match("^%s*CQBER1:(.*)$")
        if not json then return false, "Codigo precisa comecar com CQBER1:" end
        local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok or type(data) ~= "table" then return false, "Dados invalidos" end
        profileApply(data)
        scheduleProfileSave()
        return true, "Perfil importado"
    end

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
    win.Size = UDim2.fromOffset(920, 530)
    win.Position = UDim2.new(0.5, -600, 0.5, -265)
    win.BackgroundColor3 = THEME.bg
    win.BackgroundTransparency = 0.10
    win.BorderSizePixel = 0
    win.Visible = true
    win.Parent = sg
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 8)
    
    local winStroke = Instance.new("UIStroke")
    winStroke.Color = THEME.accent
    winStroke.Thickness = 1
    winStroke.Transparency = 0.5
    winStroke.Parent = win
    
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 42)
    topBar.BackgroundColor3 = THEME.panel
    topBar.BackgroundTransparency = 0.08
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
    titleLabel.Text = "CQBER // MENU"
    titleLabel.TextColor3 = THEME.text
    titleLabel.TextSize = 16
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
    local normalSize = Vector2.new(920, 530)
    local resizeGrip = Instance.new("TextButton")
    resizeGrip.Name = "ResizeGrip"
    resizeGrip.Size = UDim2.fromOffset(34, 34)
    resizeGrip.AnchorPoint = Vector2.new(1, 1)
    resizeGrip.Position = UDim2.new(1, -2, 1, -2)
    resizeGrip.Text = "◢"
    resizeGrip.Font = Enum.Font.GothamBold
    resizeGrip.TextSize = 25
    resizeGrip.TextColor3 = THEME.accent
    resizeGrip.BackgroundTransparency = 1
    resizeGrip.ZIndex = 30
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
            normalSize = Vector2.new(math.clamp(initialSize.X + d.X, 430, 1600), math.clamp(initialSize.Y + d.Y, 310, 1100))
            if not isMinimized then win.Size = UDim2.fromOffset(normalSize.X, normalSize.Y) end
        end
    end)
    safeConnect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then resizing = false end
    end)
    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            win.Size = UDim2.fromOffset(normalSize.X, 42)
            resizeGrip.Visible = false
            sidebar.Visible = false
            content.Visible = false
            profileFrame.Visible = false
            if win:FindFirstChild("OptionsBottomBar") then win.OptionsBottomBar.Visible = false end
            if win:FindFirstChild("AvatarPreviewPanel") then win.AvatarPreviewPanel.Visible = false end
            minBtn.Text = "+"
        else
            win.Size = UDim2.fromOffset(normalSize.X, normalSize.Y)
            resizeGrip.Visible = true
            sidebar.Visible = true
            content.Visible = true
            profileFrame.Visible = true
            if win:FindFirstChild("OptionsBottomBar") then win.OptionsBottomBar.Visible = true end
            if win:FindFirstChild("AvatarPreviewPanel") then win.AvatarPreviewPanel.Visible = (currentActiveTab == "Jogadores" or currentActiveTab == "Carros") end
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
    sidebar.Size = UDim2.new(0, 150, 1, -92)
    sidebar.Position = UDim2.new(0, 0, 0, 42)
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
    profileFrame.Position = UDim2.new(0, 0, 1, -85)
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
    content.Size = UDim2.new(1, -156, 1, -77)
    content.Position = UDim2.new(0, 150, 0, 42)
    content.BackgroundColor3 = THEME.bg
    content.BackgroundTransparency = 0.28
    content.BorderSizePixel = 0
    content.Parent = win
    

    -- Avatar 3D do jogador, com sobreposicao de ESP demonstrativa.
    local previewPanel = Instance.new("Frame")
    previewPanel.Name = "AvatarPreviewPanel"
    previewPanel.Size = UDim2.new(0, 280, 1, 0)
    previewPanel.Position = UDim2.new(1, 9, 0, 0)
    previewPanel.BackgroundColor3 = Color3.fromRGB(17, 16, 22)
    previewPanel.BackgroundTransparency = 0
    previewPanel.BorderSizePixel = 0
    previewPanel.Parent = win
    -- Janela externa conectada visualmente a janela principal; sem UICorner
    previewPanel.Visible = false
    local previewBorder = Instance.new("UIStroke")
    previewBorder.Color = Color3.fromRGB(220, 145, 184)
    previewBorder.Thickness = 1
    previewBorder.Parent = previewPanel
    local previewTitle = Instance.new("TextLabel")
    previewTitle.Size = UDim2.new(1, 0, 0, 25)
    previewTitle.BackgroundTransparency = 1
    previewTitle.Text = "VISUALIZADOR"
    previewTitle.Font = Enum.Font.Code
    previewTitle.TextSize = 12
    previewTitle.TextColor3 = THEME.accent
    previewTitle.Parent = previewPanel
    local avatarView = Instance.new("ViewportFrame")
    avatarView.Name = "Character3D"
    avatarView.Size = UDim2.new(1, -12, 1, -58)
    avatarView.Position = UDim2.fromOffset(6, 26)
    avatarView.BackgroundColor3 = Color3.fromRGB(9, 9, 15)
    avatarView.BackgroundTransparency = 0
    avatarView.Ambient = Color3.fromRGB(185,185,185)
    avatarView.LightColor = Color3.new(1,1,1)
    avatarView.LightDirection = Vector3.new(-1,-1,-1)
    avatarView.Parent = previewPanel
    local worldModel = Instance.new("WorldModel")
    worldModel.Parent = avatarView
    local previewCamera = Instance.new("Camera")
    previewCamera.Parent = avatarView
    avatarView.CurrentCamera = previewCamera
    local previewLabel = Instance.new("TextLabel")
    previewLabel.Size = UDim2.new(1, -8, 0, 25)
    previewLabel.Position = UDim2.new(0, 4, 1, -29)
    previewLabel.BackgroundTransparency = 1
    previewLabel.Text = LP.DisplayName
    previewLabel.TextSize = 11
    previewLabel.TextColor3 = THEME.textDim
    previewLabel.Font = Enum.Font.Code
    previewLabel.Parent = previewPanel

    -- Previa usa a skin atual do jogador, sem alterar cores ou acessorios.

    local previewCharacter
    local function rebuildPreview()
        worldModel:ClearAllChildren()
        previewCharacter = nil
        local character = LP.Character
        if not character then return end
        local oldArchivable = character.Archivable
        character.Archivable = true
        local okClone, clone = pcall(function() return character:Clone() end)
        character.Archivable = oldArchivable
        if not okClone or not clone then return end
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("Script") or desc:IsA("LocalScript") then desc:Destroy() end
            if desc:IsA("BasePart") then
                desc.Anchored = true
                desc.CanCollide = false
            end
        end
        clone.Parent = worldModel
        clone:PivotTo(CFrame.new())
        previewCharacter = clone
        local boundingCF, size = clone:GetBoundingBox()
        -- Enquadra o corpo inteiro (cabeca ate os pes) dentro do visor quadrado.
        local center = boundingCF.Position
        local halfHeight = math.max(size.Y, 4) / 2
        local halfWidth = math.max(size.X, size.Z) / 2
        previewCamera.FieldOfView = 40
        local halfFov = math.rad(previewCamera.FieldOfView / 2)
        local distance = math.max(halfHeight * 1.25, halfWidth * 1.65) / math.tan(halfFov) * 1.2
        previewCamera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0, -distance), center)
    end
    rebuildPreview()
    safeConnect(LP.CharacterAdded, function()
        task.wait(1)
        if not isUnloaded then rebuildPreview() end
    end)

    -- Quatro marcadores de enquadramento, como na imagem de referencia.
    for _, pos in ipairs({
        UDim2.new(0, 12, 0, 42), UDim2.new(1, -31, 0, 42),
        UDim2.new(0, 12, 1, -64), UDim2.new(1, -31, 1, -64)
    }) do
        local marker = Instance.new("Frame")
        marker.Size = UDim2.fromOffset(19, 19)
        marker.Position = pos
        marker.BackgroundTransparency = 1
        marker.BorderSizePixel = 0
        marker.Parent = previewPanel
        local edge1 = Instance.new("Frame")
        edge1.Size = UDim2.fromOffset(19, 2)
        edge1.BackgroundColor3 = Color3.fromRGB(115, 112, 124)
        edge1.BorderSizePixel = 0
        edge1.Parent = marker
        local edge2 = Instance.new("Frame")
        edge2.Size = UDim2.fromOffset(2, 19)
        edge2.BackgroundColor3 = Color3.fromRGB(115, 112, 124)
        edge2.BorderSizePixel = 0
        edge2.Parent = marker
    end

    local overlay = Instance.new("Frame")
    overlay.Name = "ESPPreviewOverlay"
    overlay.Size = avatarView.Size
    overlay.Position = avatarView.Position
    overlay.BackgroundTransparency = 1
    overlay.Parent = previewPanel
    local boxLine = Instance.new("Frame")
    boxLine.Name = "Box"
    boxLine.Size = UDim2.new(.53, 0, .72, 0)
    boxLine.Position = UDim2.new(.235, 0, .12, 0)
    boxLine.BackgroundTransparency = 1
    boxLine.Parent = overlay
    local boxStroke = Instance.new("UIStroke", boxLine)
    boxStroke.Color = THEME.accent
    boxStroke.Thickness = 1
    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(0, 3, .72, 0)
    healthBar.Position = UDim2.new(.20, 0, .12, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = overlay
    local headRing = Instance.new("Frame")
    headRing.Size = UDim2.fromOffset(30, 30)
    headRing.Position = UDim2.new(.5, -15, .13, 0)
    headRing.BackgroundTransparency = 1
    headRing.Parent = overlay
    Instance.new("UICorner", headRing).CornerRadius = UDim.new(1,0)
    local headStroke = Instance.new("UIStroke", headRing)
    headStroke.Color = THEME.accent
    headStroke.Thickness = 1
    local bones = {}
    local function makeBone(x1,y1,x2,y2)
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.BackgroundColor3 = THEME.accent
        f.AnchorPoint = Vector2.new(.5,.5)
        f.Parent = overlay
        table.insert(bones, {f,x1,y1,x2,y2})
    end
    makeBone(.5,.25,.5,.56)
    makeBone(.36,.36,.64,.36)
    makeBone(.36,.36,.28,.58)
    makeBone(.64,.36,.72,.58)
    makeBone(.5,.56,.39,.82)
    makeBone(.5,.56,.61,.82)
    local function updatePreviewESP()
        boxLine.Visible = cfg.ESP_Box
        healthBar.Visible = cfg.ESP_Health
        headRing.Visible = cfg.ESP_Head
        for _, bone in ipairs(bones) do
            local f,x1,y1,x2,y2 = unpack(bone)
            f.Visible = cfg.ESP_Skeleton
            local w,h = overlay.AbsoluteSize.X,overlay.AbsoluteSize.Y
            local dx,dy = (x2-x1)*w,(y2-y1)*h
            f.Size = UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),1.5)
            f.Position = UDim2.fromOffset((x1+x2)*w/2,(y1+y2)*h/2)
            f.Rotation = math.deg(math.atan2(dy,dx))
        end
        previewLabel.Text = LP.DisplayName .. (cfg.ESP_Name and " [NAME]" or "")
    end
    safeConnect(RunService.Heartbeat, function()
        if not isUnloaded then updatePreviewESP() end
    end)

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
        previewPanel.Visible = (not isMinimized) and (name == "Jogadores")
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
        
        local isOpen = true -- Todas as categorias iniciam expandidas
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
        local channelIcons = {
            ["Aimbot"] = "◎", ["Jogadores"] = "◉", ["Carros"] = "▣",
            ["Crosshair"] = "+", ["Física"] = "⚙", ["Lista"] = "▤",
            ["Chat / Ações"] = "✦", ["Teleporte Jogadores"] = "➤",
            ["Teleporte Carros"] = "➤", ["Privacidade"] = "◈",
            ["Profiles"] = "▤", ["Keybinds / Unload"] = "⚙",
        }
        b.Text = "   " .. (channelIcons[name] or "◇") .. "   " .. name
        b.TextColor3 = THEME.textDim
        b.TextSize = 13
        b.Font = Enum.Font.Gotham
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    
        local sc = Instance.new("ScrollingFrame")
        sc.Size = UDim2.new(1, -12, 1, -14)
        sc.Position = UDim2.new(0, 6, 0, 7)
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
    local catMisc = createAccordionCategory("Misc")
    local catConfig = createAccordionCategory("Configurações")
    
    local aimPage = createSubTab(catCombate, "Aimbot")
    local miscPage = createSubTab(catMisc, "Privacidade")
    local espPlayerPage = createSubTab(catVisual, "Jogadores")
    local crossPage = createSubTab(catVisual, "Crosshair")
    local vehiclesPage = createSubTab(catVeiculos, "Vehicles")
    local vehicleRootLayout = vehiclesPage:FindFirstChildOfClass("UIListLayout")
    if vehicleRootLayout then vehicleRootLayout:Destroy() end
    vehiclesPage.CanvasSize = UDim2.fromScale(0, 0)
    vehiclesPage.ScrollingEnabled = false

    local function vehicleSection(name, pos, size)
        local section = Instance.new("ScrollingFrame")
        section.Name = name
        section.Position = pos
        section.Size = size
        section.BackgroundColor3 = THEME.panel
        section.BackgroundTransparency = 0.16
        section.BorderSizePixel = 0
        section.ScrollBarThickness = 3
        section.ScrollBarImageColor3 = THEME.accent
        section.CanvasSize = UDim2.new(0,0,0,0)
        section.Parent = vehiclesPage
        Instance.new("UICorner", section).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke")
        stroke.Color = THEME.off
        stroke.Thickness = 1
        stroke.Parent = section
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = section
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            section.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 18)
        end)
        return section
    end
    local espCarPage = vehicleSection("ESP Vehicle", UDim2.fromScale(0,0), UDim2.new(.49,-5,.35,-5))
    local carFisicaPage = vehicleSection("Físicas e Lista", UDim2.new(0,0,.35,4), UDim2.new(.49,-5,.65,-8))
    local carListPage = vehicleSection("TP Vehicle", UDim2.new(.51,0,0,0), UDim2.new(.49,-5,1,-5))
    local funChatPage = createSubTab(catDiversao, "Chat / Ações")
    local funTpPage = createSubTab(catDiversao, "Teleporte Jogadores")
    local keybindsPage = createSubTab(catConfig, "Keybinds / Unload")
    local profilesPage = createSubTab(catConfig, "Profiles / Import Export")
    
    -- Rodape discreto, sem botoes de acesso rapido.
    local footer = Instance.new("TextLabel")
    footer.Name = "CopyrightFooter"
    footer.Size = UDim2.new(1, -12, 0, 24)
    footer.Position = UDim2.new(0, 6, 1, -28)
    footer.BackgroundTransparency = 1
    footer.BorderSizePixel = 0
    footer.Font = Enum.Font.Code
    footer.TextSize = 12
    footer.TextColor3 = THEME.textDim
    footer.TextXAlignment = Enum.TextXAlignment.Center
    footer.Text = "© CQBER — Todos os direitos reservados"
    footer.Parent = win

    selectTab("Aimbot")
    local headings = {
        {aimPage, "AIMBOT OPTIONS"}, {miscPage, "MISC / PRIVACIDADE"},
        {espPlayerPage, "ESP OPTIONS"}, {espCarPage, "ESP VEHICLE"},
        {crossPage, "CROSSHAIR OPTIONS"}, {carFisicaPage, "FÍSICAS E LISTA"},
        {carListPage, "TP VEHICLE"}, {funChatPage, "FUN OPTIONS"},
        {funTpPage, "PLAYER TELEPORT OPTIONS"}, {keybindsPage, "MENU SETTINGS"},
        {profilesPage, "PROFILE SETTINGS"},
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
        r.Size = UDim2.new(1, -10, 0, 23)
        r.BackgroundColor3 = THEME.panel
        r.BackgroundTransparency = 0.20
        r.BorderSizePixel = 0
        r.Parent = parent
        local embedStroke = Instance.new("UIStroke")
        embedStroke.Color = THEME.off
        embedStroke.Thickness = 1
        embedStroke.Transparency = 0.10
        embedStroke.Parent = r
        Instance.new("UICorner", r).CornerRadius = UDim.new(0, 5)
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
        b.Size = UDim2.fromOffset(18, 18)
        b.Position = UDim2.new(1, -23, 0.5, -9)
        b.BackgroundColor3 = cfg[key] and THEME.accent or THEME.off
        b.Text = cfg[key] and "✓" or ""
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.TextSize = 15
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Parent = r
        local checkboxStroke = Instance.new("UIStroke")
        checkboxStroke.Color = THEME.accent
        checkboxStroke.Thickness = 1
        checkboxStroke.Parent = b
        local function updateVisuals()
            b.BackgroundColor3 = cfg[key] and THEME.accent or THEME.off
            b.Text = cfg[key] and "✓" or ""
        end

        b.MouseButton1Click:Connect(function()
            cfg[key] = not cfg[key]
            updateVisuals()
            scheduleProfileSave()
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
        r.Size = UDim2.new(1, -10, 0, 44)
        r.BackgroundColor3 = THEME.panel
        r.BackgroundTransparency = 0.20
        r.BorderSizePixel = 0
        r.Parent = parent
        local embedStroke = Instance.new("UIStroke")
        embedStroke.Color = THEME.off
        embedStroke.Thickness = 1
        embedStroke.Transparency = 0.10
        embedStroke.Parent = r
        Instance.new("UICorner", r).CornerRadius = UDim.new(0, 5)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -96, 0, 18)
        l.BackgroundTransparency = 1
        l.TextColor3 = THEME.text
        l.TextSize = 12
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = r
        -- Barra rosa quadrada, arrastavel, com valor separado a direita.
        local bar = Instance.new("Frame")
        bar.Name = "SliderTrack"
        bar.Size = UDim2.new(1, -82, 0, 14)
        bar.Position = UDim2.new(0, 6, 0, 27)
        bar.BackgroundColor3 = Color3.fromRGB(48, 33, 43)
        bar.BorderSizePixel = 0
        bar.Parent = r
        local fill = Instance.new("Frame")
        fill.Name = "SliderFill"
        fill.BackgroundColor3 = THEME.accent
        fill.BorderSizePixel = 0
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.Parent = bar
        local knob = Instance.new("Frame")
        knob.Name = "SliderHandle"
        knob.Size = UDim2.fromOffset(5, 14)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.BackgroundColor3 = Color3.fromRGB(255, 235, 247)
        knob.BorderSizePixel = 0
        knob.Parent = bar
        local valueBox = Instance.new("TextBox")
        valueBox.Name = "SliderValue"
        valueBox.Size = UDim2.new(0, 64, 0, 20)
        valueBox.Position = UDim2.new(1, -68, 0, 24)
        valueBox.BackgroundColor3 = Color3.fromRGB(35, 25, 34)
        valueBox.BorderColor3 = THEME.accent
        valueBox.BorderSizePixel = 1
        valueBox.TextXAlignment = Enum.TextXAlignment.Center
        valueBox.TextColor3 = Color3.fromRGB(255, 235, 247)
        valueBox.TextSize = 11
        valueBox.ZIndex = 8
        valueBox.Font = Enum.Font.Gotham
        valueBox.ClearTextOnFocus = false
        valueBox.Parent = r
        local function setValue(v)
            v = math.clamp(v, mn, mx)
            if isInt then v = math.floor(v + 0.5) else v = math.floor(v * 100 + 0.5) / 100 end
            cfg[key] = v
            local pct = (v - mn) / (mx - mn)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, 0, 0.5, 0)
            local display = isInt and string.format("%d", v) or string.format("%.2f", v)
            l.Text = label
            if not valueBox:IsFocused() then valueBox.Text = display .. "/" .. tostring(mx) end
        end
        setValue(cfg[key] or def)
        profileRefresh[key] = function() setValue(cfg[key]) end
        valueBox.FocusLost:Connect(function()
            local v = tonumber((valueBox.Text:match("^[%d%.,]+") or ""):gsub(",", "."))
            if v then setValue(v); scheduleProfileSave() else valueBox.Text = tostring(cfg[key]) end
        end)
        local draggingSlider = false
        local function updateAt(x)
            if bar.AbsoluteSize.X > 0 then
                setValue(mn + math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1) * (mx - mn))
                scheduleProfileSave()
            end
        end
        for _, obj in ipairs({bar, fill, knob}) do
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
    
    -- Secao Extras integrada diretamente na aba Aimbot.
    local extrasHeading = Instance.new("TextLabel")
    extrasHeading.Name = "AimbotExtrasHeading"
    extrasHeading.Size = UDim2.new(1, -10, 0, 36)
    extrasHeading.BackgroundTransparency = 1
    extrasHeading.BorderSizePixel = 0
    extrasHeading.Font = Enum.Font.GothamBold
    extrasHeading.TextSize = 16
    extrasHeading.TextColor3 = THEME.text
    extrasHeading.TextXAlignment = Enum.TextXAlignment.Left
    extrasHeading.Text = "★ EXTRAS"
    extrasHeading.Parent = aimPage
    -- Extras de armas: comportamento depende de cada Tool e das regras do servidor.
    makeToggle(aimPage, "No Recoil", "NoRecoil")
    makeToggle(aimPage, "No Spread", "NoSpread")
    makeToggle(aimPage, "Rapid Fire", "RapidFire")

    -- Streamspoof local: oculta a interface ao ativar. Nao burla captura externa.
    makeToggle(miscPage, "Streamspoof (ocultar menu)", "Streamproof", function(enabled)
        if enabled then
            win.Visible = false
        else
            win.Visible = true
        end
    end)
    makeButton(miscPage, "Mostrar menu (Insert)", function() win.Visible = true end)

    -- Ajustes de tamanho do GUI em Misc; sincronizados com a alca inferior direita.
    local guiSizeHeading = Instance.new("TextLabel")
    guiSizeHeading.Name = "GuiSizeHeading"
    guiSizeHeading.Size = UDim2.new(1, -10, 0, 30)
    guiSizeHeading.BackgroundTransparency = 1
    guiSizeHeading.Text = "TAMANHO DO MENU"
    guiSizeHeading.TextColor3 = THEME.text
    guiSizeHeading.Font = Enum.Font.GothamBold
    guiSizeHeading.TextSize = 14
    guiSizeHeading.TextXAlignment = Enum.TextXAlignment.Left
    guiSizeHeading.Parent = miscPage

    local function setGuiDimensions(width, height)
        normalSize = Vector2.new(math.clamp(math.floor(width), 430, 1600), math.clamp(math.floor(height), 310, 1100))
        if isMinimized then
            win.Size = UDim2.fromOffset(normalSize.X, 42)
        else
            win.Size = UDim2.fromOffset(normalSize.X, normalSize.Y)
        end
    end
    makeButton(miscPage, "[ + ] Aumentar GUI", function()
        setGuiDimensions(normalSize.X + 100, normalSize.Y + 65)
    end)
    makeButton(miscPage, "[ - ] Diminuir GUI", function()
        setGuiDimensions(normalSize.X - 100, normalSize.Y - 65)
    end)
    makeButton(miscPage, "Tamanho original (740 x 410)", function()
        setGuiDimensions(740, 410)
    end)
    makeButton(miscPage, "Tamanho grande (1200 x 750)", function()
        setGuiDimensions(1200, 750)
    end)
    -- A alca '◢' permanece sempre no canto inferior direito quando expandido.


    local rapidHeld = false
    safeConnect(UIS.InputBegan, function(input, processed)
        if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if rapidHeld then return end
        rapidHeld = true
        task.spawn(function()
            while rapidHeld and not isUnloaded and cfg.RapidFire do
                local char = LP.Character
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then pcall(function() tool:Activate() end) end
                task.wait(0.10)
            end
        end)
    end)
    safeConnect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then rapidHeld = false end
    end)
    
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
    makeSlider(carFisicaPage, "Alcance para Pegar Carro", "GrabDistance", 45, 150, 75, true)
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
    
    -- Cache incremental: evita varrer o Workspace inteiro quando Y e pressionado.
    local vehicleCache = {}
    local cacheReady = false
    local scanBusy = false
    local function scanVehicles()
        if scanBusy then return end
        scanBusy = true
        task.spawn(function()
            local found, seen = {}, {}
            local all = workspace:GetDescendants()
            for i, inst in ipairs(all) do
                if inst:IsA("VehicleSeat") then
                    local model = inst:FindFirstAncestorOfClass("Model")
                    if model and not seen[model] and not (LP.Character and model:IsDescendantOf(LP.Character)) then
                        seen[model] = true
                        table.insert(found, {model = model, seat = inst})
                    end
                end
                if i % 180 == 0 then task.wait() end
            end
            vehicleCache = found
            cacheReady = true
            scanBusy = false
        end)
    end
    scanVehicles()
    task.spawn(function()
        while not isUnloaded do
            task.wait(8)
            if not isUnloaded then scanVehicles() end
        end
    end)
    local function findVehicles()
        local vehicles = {}
        for _, v in ipairs(vehicleCache) do
            if v.model.Parent and v.seat.Parent then
                table.insert(vehicles, v)
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
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -10, 0, 54)
            row.BackgroundColor3 = THEME.off
            row.BorderSizePixel = 0
            row.Parent = vehScroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -8, 0, 22)
            title.Position = UDim2.fromOffset(4, 0)
            title.BackgroundTransparency = 1
            title.Text = string.format("%s [%dm]", data.model.Name, math.floor(data.dist))
            title.TextColor3 = THEME.text
            title.TextSize = 11
            title.Font = Enum.Font.Gotham
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = row
            local function smallButton(label, x, callback)
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(.5, -6, 0, 24)
                b.Position = UDim2.new(x, 4, 0, 26)
                b.BackgroundColor3 = THEME.panel
                b.TextColor3 = THEME.text
                b.Font = Enum.Font.GothamBold
                b.TextSize = 11
                b.Text = label
                b.Parent = row
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
                b.MouseButton1Click:Connect(callback)
            end
            smallButton("IR ATE CARRO", 0, function()
                local currentRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if currentRoot and data.seat.Parent then
                    currentRoot.CFrame = data.seat.CFrame * CFrame.new(0, 3, -7)
                end
            end)
            smallButton("TRAZER CARRO", .5, function()
                local currentRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if not currentRoot or not data.model.Parent or data.seat.Occupant then return end
                pcall(function()
                    data.model:PivotTo(currentRoot.CFrame * CFrame.new(0, 2, -12))
                end)
            end)
        end
    end
    makeButton(carListPage, "Atualizar Lista", function()
        scanVehicles()
        task.delay(.6, refreshVehicleList)
    end)
    
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
        r.Size = UDim2.new(1, -10, 0, 23)
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
                scheduleProfileSave()
                conn:Disconnect()
            end)
            end)
        end)
    end
    
    makeBind(keybindsPage, "Bind Menu", "MenuBind")
    makeBind(keybindsPage, "Bind Car Grab", "GrabBind")
    makeBind(keybindsPage, "Bind Car Throw", "ThrowBind")
    
    -- Profiles: import/export e salvamento local (quando o ambiente permite).
    local function profileText(label, height)
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -10, 0, height or 25)
        t.BackgroundTransparency = 1
        t.TextWrapped = true
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextColor3 = THEME.textDim
        t.Font = Enum.Font.Gotham
        t.TextSize = 12
        t.Text = label
        t.Parent = profilesPage
        return t
    end
    profileText("As opcoes sao salvas automaticamente se o executor oferecer readfile/writefile.", 40)
    local profileStatus = profileText("Pronto para importar ou exportar.", 26)
    local profileBox = Instance.new("TextBox")
    profileBox.Name = "ProfileCode"
    profileBox.Size = UDim2.new(1, -10, 0, 105)
    profileBox.BackgroundColor3 = THEME.off
    profileBox.TextColor3 = THEME.text
    profileBox.PlaceholderColor3 = THEME.textDim
    profileBox.PlaceholderText = "Cole aqui um codigo CQBER1:..."
    profileBox.Text = ""
    profileBox.ClearTextOnFocus = false
    profileBox.MultiLine = true
    profileBox.TextWrapped = true
    profileBox.TextXAlignment = Enum.TextXAlignment.Left
    profileBox.TextYAlignment = Enum.TextYAlignment.Top
    profileBox.TextSize = 11
    profileBox.Font = Enum.Font.Code
    profileBox.Parent = profilesPage
    Instance.new("UICorner", profileBox).CornerRadius = UDim.new(0, 5)
    makeButton(profilesPage, "EXPORTAR PROFILE", function()
        local code = profileEncode()
        profileBox.Text = code
        profileStatus.Text = "Codigo gerado na caixa."
    end)
    makeButton(profilesPage, "IMPORTAR PROFILE", function()
        local ok, msg = profileImport(profileBox.Text)
        profileStatus.Text = msg
    end)
    makeButton(profilesPage, "SALVAR AGORA", function()
        profileStatus.Text = profileSave() and "Opcoes salvas no dispositivo." or "Seu executor nao oferece salvamento de arquivos."
    end)
    profileText("Importar muda as opcoes deste menu; nao executa scripts de terceiros.", 35)

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
                v.Color = (k == "health") and Color3.fromRGB(235, 235, 235) or THEME.accent
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
    
    -- Grab / Throw refeito: fisica horizontal, sem ancorar ou teleportar o carro.
    local grabbedCar, grabConn, grabState = nil, nil, nil

    local function nearestCar(maxDist)
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local range = math.max(tonumber(maxDist) or 45, 75)
        local best, bestScore = nil, math.huge
        local target = LP:GetMouse().Target
        -- Usa apenas a posicao do banco: GetBoundingBox de varios modelos
        -- no mesmo frame causava engasgos ao pressionar Y.
        for _, vehicle in ipairs(findVehicles()) do
            local seat, model = vehicle.seat, vehicle.model
            if seat and seat.Parent and model and model.Parent and not seat.Occupant then
                local part = seat.AssemblyRootPart or seat
                if part and not part.Anchored then
                    local dist = (seat.Position - root.Position).Magnitude
                    if dist <= range + 15 then
                        local score = dist
                        if target and target:IsDescendantOf(model) then score = score - 1000 end
                        if score < bestScore then best, bestScore = model, score end
                    end
                end
            end
        end
        return best
    end

    stopGrab = function()
        if grabConn then grabConn:Disconnect(); grabConn = nil end
        if grabState then
            if grabState.align then grabState.align:Destroy() end
            if grabState.attachment then grabState.attachment:Destroy() end
            if grabState.target then grabState.target:Destroy() end
        end
        grabbedCar, grabState = nil, nil
    end

    local function grabCar()
        if not cfg.CarGrabActive or isUnloaded then return end
        if grabbedCar then stopGrab(); return end -- Y solta; nao troca de carro sem querer
        local model = nearestCar(cfg.GrabDistance)
        if not model then
            if not cacheReady then warn("[CQBER] Carregando lista de carros; tente Y novamente em instantes.")
            else warn("[CQBER] Nenhum carro desocupado proximo.") end
            return
        end
        local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
        local part = seat and (seat.AssemblyRootPart or seat)
        if not part or part.Anchored then
            warn("[cqber] Veiculo ancorado ou sem montagem fisica livre")
            return
        end
        -- Alvo invisivel local; AlignPosition evita ancorar o veiculo.
        local target = Instance.new("Part")
        target.Name = "CQBER_GrabTarget"
        target.Size = Vector3.new(0.2, 0.2, 0.2)
        target.Transparency = 1
        target.Anchored = true
        target.CanCollide = false
        target.CanTouch = false
        target.CanQuery = false
        target.Parent = workspace
        local attachment = Instance.new("Attachment")
        attachment.Name = "CQBER_GrabAttachment"
        attachment.Parent = part
        local align = Instance.new("AlignPosition")
        align.Name = "CQBER_GrabAlign"
        align.Mode = Enum.PositionAlignmentMode.OneAttachment
        align.Attachment0 = attachment
        align.MaxForce = math.clamp(part.AssemblyMass * 15000, 30000, 1500000)
        align.MaxVelocity = 65
        align.Responsiveness = math.clamp(tonumber(cfg.GrabFollowSpeed) or 16, 12, 40)
        align.RigidityEnabled = false
        align.ApplyAtCenterOfMass = true
        align.Parent = part
        grabbedCar = model
        grabState = {part = part, align = align, attachment = attachment, target = target}
        local stuckFor, warned = 0, false
        grabConn = RunService.Heartbeat:Connect(function(dt)
            if isUnloaded or not cfg.CarGrabActive or not model.Parent or not part.Parent then
                stopGrab(); return
            end
            local character = LP.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then stopGrab(); return end
            local look = root.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            -- Segura mais perto do jogador para facilitar o levantamento inicial.
            local destination = root.Position + flat.Unit * 9 + Vector3.new(0, 4.5, 0)
            target.Position = destination
            align.Position = destination
            -- Assistencia apenas na simulacao que o cliente efetivamente controla.
            -- Nao tenta contornar a autoridade fisica do servidor.
            local distance = (part.Position - destination).Magnitude
            if distance > 5 then
                stuckFor = stuckFor + dt
                if stuckFor > 1.2 and not warned then
                    warned = true
                    warn("[CQBER] O carro nao esta acompanhando o Grab. O servidor pode controlar a fisica deste veiculo.")
                end
            else
                stuckFor = 0
                warned = false
            end
        end)
    end

    local function throwCar()
        if not grabbedCar or not grabState or isUnloaded then return end
        local part = grabState.part
        -- Remove a forca de segurar ANTES de arremessar.
        stopGrab()
        if not part or not part.Parent or part.Anchored then return end
        local cam = workspace.CurrentCamera
        local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
        local horizontal = Vector3.new(look.X, 0, look.Z)
        if horizontal.Magnitude < 0.01 then
            local char = LP.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local facing = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
            horizontal = Vector3.new(facing.X, 0, facing.Z)
        end
        horizontal = horizontal.Unit
        local power = math.clamp(tonumber(cfg.ThrowPower) or 5, 0, 10)
        if power <= 0 then return end
        local speed = 80 + power * 45
        -- Mantem a velocidade vertical em zero: arremesso reto, nao para cima.
        local desired = horizontal * speed
        local mass = part.AssemblyMass
        pcall(function()
            part.AssemblyLinearVelocity = desired
            part:ApplyImpulse((desired - part.AssemblyLinearVelocity) * mass)
        end)
        -- Reforca o impulso por alguns frames contra perdas de velocidade locais.
        local elapsed = 0
        local boost
        boost = RunService.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed > 0.35 or not part.Parent or part.Anchored then
                boost:Disconnect(); return
            end
            pcall(function()
                local v = part.AssemblyLinearVelocity
                local flat = Vector3.new(v.X, 0, v.Z)
                local missing = desired - flat
                if missing.Magnitude > 3 then
                    part:ApplyImpulse(missing * mass * math.clamp(dt * 9, 0, 1))
                end
            end)
        end)
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
            win.Visible = false
            return true
        end
        win.Visible = true
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
