local ok, err = xpcall(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local HttpService = game:GetService("HttpService")
    local LP = Players.LocalPlayer
    local Cam = workspace.CurrentCamera
    
    -- Banner geometrico preto e branco, sem asset externo 
    local BANNER_IMAGE = "rbxassetid://8997180365"
    -- CQBER EXTERNAL: interface inspirada na organizacao do Mystic, com acento turquesa.
    local THEME = {
        bg = Color3.fromRGB(11, 15, 19), sidebar = Color3.fromRGB(15, 22, 27),
        panel = Color3.fromRGB(22, 31, 37), text = Color3.fromRGB(235, 246, 247),
        textDim = Color3.fromRGB(145, 165, 174), accent = Color3.fromRGB(48, 224, 200),
        red = Color3.fromRGB(22, 91, 85), off = Color3.fromRGB(43, 61, 68),
    }

    local cfg = {
        RapidFire = false, Aimbot = false, CarFly = false, CarGrabActive = false, NoRecoil = false, NoSpread = false,
        Streamproof = false, ESP_Master = true, ESP_Rainbow = false, ESP_Hex = "#45DBCC", ESP_Box = false, ESP_Name = false, ESP_Health = false, ESP_Distance = false,
        ESP_Tracer = false, ESP_Skeleton = false, ESP_Head = false, ESP_Vehicles = false, TeamCheckAimbot = false,
        TeamCheckESP = false, WallCheckAimbot = false, WallCheckESP = false, TargetPlayer = nil,
        TargetOnESP = false, FOV = 120, Smooth = 0.25, ThrowPower = 5, GrabDistance = 75,
        GrabFollowSpeed = 16, SpeedHack = false, SpeedValue = 32, SpinSpeed = 15, PlayerFly = false, FlySpeed = 55, NoClip = false, InfiniteJump = false, JumpBoost = false, JumpValue = 65, MenuBind = Enum.KeyCode.Insert, GrabBind = Enum.KeyCode.Y,
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
    win.Position = UDim2.new(0.5, -460, 0.5, -265)
    win.BackgroundColor3 = THEME.bg
    win.BackgroundTransparency = 0
    win.BorderSizePixel = 0
    win.Visible = true
    win.Parent = sg
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 16)
    
    -- Wallpaper Roblox Creator Store: Sakura (Decal 8997180365).
    -- Fica atras dos controles, com opacidade baixa para manter legibilidade.
    local wallpaper = Instance.new("ImageLabel")
    wallpaper.Name = "CQBER_Wallpaper"
    wallpaper.Size = UDim2.fromScale(1, 1)
    wallpaper.BackgroundTransparency = 1
    wallpaper.Image = "rbxassetid://8997180365"
    wallpaper.ImageTransparency = 1
    wallpaper.ScaleType = Enum.ScaleType.Crop
    wallpaper.ZIndex = 0
    wallpaper.Parent = win
    Instance.new("UICorner", wallpaper).CornerRadius = UDim.new(0, 8)

    local winStroke = Instance.new("UIStroke")
    winStroke.Color = THEME.accent
    winStroke.Thickness = 1.1
    winStroke.Transparency = 0
    winStroke.Parent = win
    
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 62)
    topBar.BackgroundColor3 = THEME.bg
    topBar.BackgroundTransparency = 0
    topBar.BorderSizePixel = 0
    topBar.Parent = win
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    
    local banner = Instance.new("ImageLabel")
    banner.Size = UDim2.new(1, 0, 1, 0)
    banner.BackgroundTransparency = 1
    banner.Image = ""
    banner.ScaleType = Enum.ScaleType.Crop
    banner.Parent = topBar
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 8)
    
    local topGrad = Instance.new("UIGradient")
    topGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 30, 55)),
        ColorSequenceKeypoint.new(0.5, THEME.accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 15, 32)),
    }
    topGrad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.5, 0.62),
        NumberSequenceKeypoint.new(1, 0.7),
    }
    topGrad.Parent = banner
    topGrad.Enabled = true -- faixa azul escura do CQBER External
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 310, 1, 0)
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "CQBER  EXTERNAL"
    titleLabel.TextColor3 = THEME.accent
    titleLabel.TextSize = 20
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = topBar
    
    -- Busca rapida de opcoes, inspirada nos menus FiveM.
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "FunctionSearch"
    searchBox.Size = UDim2.new(0, 220, 0, 26)
    searchBox.Position = UDim2.new(1, -330, 0.5, -13)
    searchBox.BackgroundColor3 = THEME.bg
    searchBox.BackgroundTransparency = 0.12
    searchBox.BorderSizePixel = 0
    searchBox.PlaceholderText = "⌕  Buscar função..."
    searchBox.PlaceholderColor3 = THEME.textDim
    searchBox.Text = ""
    searchBox.TextColor3 = THEME.text
    searchBox.TextSize = 12
    searchBox.Font = Enum.Font.Gotham
    searchBox.ClearTextOnFocus = false
    searchBox.ZIndex = 12
    searchBox.Parent = topBar
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 9)
    local searchStroke = Instance.new("UIStroke", searchBox)
    searchStroke.Color = THEME.off
    searchStroke.Thickness = 1

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -42, 0.5, -15)
    minBtn.BackgroundColor3 = THEME.panel
    minBtn.Text = "-"
    minBtn.TextColor3 = THEME.text
    minBtn.TextSize = 20
    minBtn.Font = Enum.Font.GothamBold
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 9)
    
    -- Stan: linha divisoria entre cabecalho e conteudo.
    local headerDivider = Instance.new("Frame")
    headerDivider.Name = "CQBER_HeaderDivider"
    headerDivider.Size = UDim2.new(1, -2, 0, 1)
    headerDivider.Position = UDim2.new(0, 1, 0, 61)
    headerDivider.BackgroundColor3 = Color3.fromRGB(37, 67, 70)
    headerDivider.BorderSizePixel = 0
    headerDivider.Parent = win

    local isMinimized = false
    local normalSize = Vector2.new(920, 530)
    local resizeGrip = Instance.new("TextButton")
    resizeGrip.Name = "ResizeGrip"
    resizeGrip.Size = UDim2.fromOffset(34, 34)
    resizeGrip.AnchorPoint = Vector2.new(1, 1)
    resizeGrip.Position = UDim2.new(1, -5, 1, -5)
    resizeGrip.Text = "◢"
    resizeGrip.Font = Enum.Font.GothamBold
    resizeGrip.TextSize = 22
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
            win.Size = UDim2.fromOffset(normalSize.X, 62)
            resizeGrip.Visible = false
            sidebar.Visible = false
            content.Visible = false
            profileFrame.Visible = false
            if win:FindFirstChild("OptionsBottomBar") then win.OptionsBottomBar.Visible = false end
            if win:FindFirstChild("AvatarPreviewPanel") then win.AvatarPreviewPanel.Visible = false end
            if content:FindFirstChild("TeleportPanel") then content.TeleportPanel.Visible = false end
            minBtn.Text = "+"
        else
            win.Size = UDim2.fromOffset(normalSize.X, normalSize.Y)
            resizeGrip.Visible = true
            sidebar.Visible = true
            content.Visible = true
            profileFrame.Visible = true
            if win:FindFirstChild("OptionsBottomBar") then win.OptionsBottomBar.Visible = true end
            if win:FindFirstChild("AvatarPreviewPanel") then win.AvatarPreviewPanel.Visible = false end
            if content:FindFirstChild("TeleportPanel") then content.TeleportPanel.Visible = false end
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
    sidebar.Size = UDim2.new(0, 176, 1, -130)
    sidebar.Position = UDim2.new(0, 0, 0, 62)
    sidebar.BackgroundColor3 = THEME.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ScrollBarThickness = 2
    sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebar.Parent = win
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 9)
    
    local sideLayout = Instance.new("UIListLayout", sidebar)
    sideLayout.Padding = UDim.new(0, 5)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sidebar.CanvasSize = UDim2.new(0, 0, 0, sideLayout.AbsoluteContentSize.Y + 20)
    end)
    local sidePad = Instance.new("UIPadding", sidebar)
    sidePad.PaddingTop = UDim.new(0, 10)
    sidePad.PaddingLeft = UDim.new(0, 8)
    sidePad.PaddingRight = UDim.new(0, 8)
    
    profileFrame = Instance.new("Frame")
    profileFrame.Size = UDim2.new(0, 176, 0, 50)
    profileFrame.Position = UDim2.new(0, 0, 1, -91)
    profileFrame.BackgroundColor3 = THEME.sidebar
    profileFrame.BorderSizePixel = 0
    profileFrame.Parent = win
    Instance.new("UICorner", profileFrame).CornerRadius = UDim.new(0, 9)
    
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
        pfp.Image = ""
    end)
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -55, 0, 16)
    nameLabel.Position = UDim2.new(0, 50, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "CQBER EXTERNAL"
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
    statusLabel.Text = "CQBER EXTERNAL"
    statusLabel.TextColor3 = THEME.accent
    statusLabel.TextSize = 10
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = profileFrame
    
    content = Instance.new("Frame")
    content.Size = UDim2.new(1, -196, 1, -110)
    content.Position = UDim2.new(0, 186, 0, 68)
    content.BackgroundColor3 = THEME.bg
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = win
    

    -- Avatar 3D do jogador, com sobreposicao de ESP demonstrativa.
    local previewPanel = Instance.new("Frame")
    previewPanel.Name = "AvatarPreviewPanel"
    previewPanel.Size = UDim2.fromOffset(340, 505)
    previewPanel.Position = UDim2.new(1, 16, 0, 12)
    previewPanel.BackgroundColor3 = THEME.panel
    previewPanel.BackgroundTransparency = 0
    previewPanel.BorderSizePixel = 0
    previewPanel.Parent = win
    -- Janela externa conectada visualmente a janela principal; sem UICorner
    previewPanel.Visible = false
    local previewBorder = Instance.new("UIStroke")
    previewBorder.Color = THEME.accent
    previewBorder.Thickness = 1
    previewBorder.Parent = previewPanel
    local previewTitle = Instance.new("TextLabel")
    previewTitle.Size = UDim2.new(1, 0, 0, 25)
    previewTitle.BackgroundTransparency = 1
    previewTitle.Text = "ESP  /  PREVIEW"
    previewTitle.Font = Enum.Font.Code
    previewTitle.TextSize = 12
    previewTitle.TextColor3 = THEME.accent
    previewTitle.Parent = previewPanel
    local avatarView = Instance.new("ViewportFrame")
    avatarView.Name = "Character3D"
    avatarView.Size = UDim2.new(1, -12, 1, -58)
    avatarView.Position = UDim2.fromOffset(6, 26)
    avatarView.BackgroundColor3 = THEME.bg
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

    local funTpPage
    local tabPages, tabButtons = {}, {}
    local currentActiveTab = nil
    
    local function selectTab(name)
        searchBox.Text = ""
        for pName, pg in pairs(tabPages) do pg.Visible = false end
        for bName, bt in pairs(tabButtons) do
            bt.BackgroundTransparency = 0
            bt.BackgroundColor3 = THEME.panel
            bt.TextColor3 = THEME.textDim
        end
        if tabPages[name] then
            tabPages[name].Visible = true
            tabButtons[name].BackgroundTransparency = 0
            tabButtons[name].BackgroundColor3 = Color3.fromRGB(23, 64, 66)
            tabButtons[name].TextColor3 = THEME.accent
            currentActiveTab = name
        end
        previewPanel.Visible = (not isMinimized) and name == "Jogadores" -- visualizador externo à direita
        funTpPage.Visible = (not isMinimized) and name == "Jogadores"
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
        subLayout.Padding = UDim.new(0, 4)
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
        b.Size = UDim2.new(1, -6, 0, 26)
        b.BackgroundTransparency = 0
        b.BackgroundColor3 = THEME.panel
        b.BorderSizePixel = 0
        local channelIcons = {
            ["Dashboard"] = "⌂", ["Aimbot"] = "◎", ["Jogadores"] = "◉", ["Carros"] = "▣",
            ["Crosshair"] = "+", ["Física"] = "⚙", ["Lista"] = "▤",
            ["Chat / Ações"] = "✦", ["Teleporte Jogadores"] = "➤",
            ["Teleporte Carros"] = "➤", ["Fun"] = "✦",
            ["Profiles"] = "▤", ["Keybinds / Unload"] = "⚙",
        }
        b.Text = "  " .. (channelIcons[name] or "◇") .. "   " .. name
        b.TextColor3 = THEME.textDim
        b.TextSize = 12
        b.Font = Enum.Font.Gotham
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        local tileBorder = Instance.new("UIStroke", b)
        tileBorder.Color = THEME.off
        tileBorder.Thickness = 1
        tileBorder.Transparency = 0.62
    
        local sc = Instance.new("ScrollingFrame")
        sc.Size = UDim2.new(1, -18, 1, -18)
        sc.Position = UDim2.new(0, 9, 0, 9)
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
    
    local function filterCurrentPage()
        local query = string.lower(searchBox.Text):gsub("^%s+", ""):gsub("%s+$", "")
        local page = currentActiveTab and tabPages[currentActiveTab]
        if not page then return end
        for _, child in ipairs(page:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "SectionHeading" then
                local matched = query == ""
                if not matched then
                    for _, desc in ipairs(child:GetDescendants()) do
                        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and
                            string.find(string.lower(desc.Text), query, 1, true) then
                            matched = true
                            break
                        end
                    end
                end
                child.Visible = matched
            end
        end
    end
    safeConnect(searchBox:GetPropertyChangedSignal("Text"), filterCurrentPage)

    local catPrincipal = createAccordionCategory("Principal")
    local catCombate = createAccordionCategory("Combate")
    local catVisual = createAccordionCategory("Visual (ESP)")
    local catVeiculos = createAccordionCategory("Veículos")
    local catMisc = createAccordionCategory("Utilitários")
    local catDiversao = catMisc -- diversão agrupada em Utilitários
    local catConfig = catMisc -- configurações agrupadas em Utilitários
    
    local principalPage = createSubTab(catPrincipal, "Dashboard")
    local aimPage = createSubTab(catCombate, "Aimbot")
    local miscPage = createSubTab(catMisc, "Fun")
    local espPlayerPage = createSubTab(catVisual, "Jogadores")
    espPlayerPage.Size = UDim2.new(0.66, -14, 1, -18) -- espaço reservado para o visualizador ESP
    local crossPage = createSubTab(catVisual, "Crosshair")
    local vehiclesPage = createSubTab(catVeiculos, "Vehicles")
    local vehicleRootLayout = vehiclesPage:FindFirstChildOfClass("UIListLayout")
    if vehicleRootLayout then vehicleRootLayout:Destroy() end
    vehiclesPage.CanvasSize = UDim2.fromScale(0, 0)
    vehiclesPage.ScrollingEnabled = false
    vehiclesPage.Position = vehiclesPage.Position + UDim2.fromOffset(8, 0)
    vehiclesPage.Size = vehiclesPage.Size - UDim2.fromOffset(16, 0)
    vehiclesPage.ClipsDescendants = false

    local function vehicleSection(name, pos, size)
        local section = Instance.new("ScrollingFrame")
        section.Name = name
        section.Position = pos
        section.Size = size
        section.BackgroundColor3 = THEME.panel
        section.BackgroundTransparency = 1
        section.BorderSizePixel = 0
        section.ScrollBarThickness = 3
        section.ScrollBarImageColor3 = THEME.accent
        section.CanvasSize = UDim2.new(0,0,0,0)
        section.Parent = vehiclesPage
        Instance.new("UICorner", section).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke")
        stroke.Color = THEME.off
        stroke.Thickness = 0
        stroke.Transparency = 1
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
    -- Layout compacto: cards terminam perto do ultimo controle, sem bordas gigantes.
    local espCarPage = vehicleSection("ESP Vehicle", UDim2.new(0, 12, 0, 12), UDim2.new(.5, -24, 0, 115))
    local carFisicaPage = vehicleSection("Físicas e Lista", UDim2.new(0, 12, 0, 140), UDim2.new(.5, -24, 0, 272))
    local carListPage = vehicleSection("TP Vehicle", UDim2.new(.5, 12, 0, 12), UDim2.new(.5, -24, 0, 378))
    local funChatPage = miscPage -- opções de diversão reunidas na aba Fun
    -- Teleporte integrado ao painel Jogadores, ocupando o antigo espaço do preview.
    funTpPage = Instance.new("ScrollingFrame")
    funTpPage.Name = "TeleportPanel"
    funTpPage.Size = UDim2.new(0.32, -12, 1, -18)
    funTpPage.Position = UDim2.new(0.68, 2, 0, 9)
    funTpPage.BackgroundTransparency = 1
    funTpPage.BorderSizePixel = 0
    funTpPage.ScrollBarThickness = 2
    funTpPage.ScrollBarImageColor3 = THEME.accent
    funTpPage.CanvasSize = UDim2.new(0, 0, 0, 0)
    funTpPage.Visible = false
    funTpPage.Parent = content
    local tpPageLayout = Instance.new("UIListLayout", funTpPage)
    tpPageLayout.Padding = UDim.new(0, 8)
    tpPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tpPageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        funTpPage.CanvasSize = UDim2.fromOffset(0, tpPageLayout.AbsoluteContentSize.Y + 16)
    end)
    local keybindsPage = createSubTab(catConfig, "Keybinds / Unload")
    local profilesPage = createSubTab(catConfig, "Profiles / Import Export")
    
    -- Rodape discreto, sem botoes de acesso rapido.
    local footer = Instance.new("TextLabel")
    footer.Name = "CopyrightFooter"
    footer.Size = UDim2.new(1, -20, 0, 30)
    footer.Position = UDim2.new(0, 10, 1, -33)
    footer.BackgroundTransparency = 1
    footer.BorderSizePixel = 0
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 11
    footer.TextColor3 = THEME.textDim
    footer.TextXAlignment = Enum.TextXAlignment.Right
    footer.Text = "CQBER EXTERNAL  •  v2.6.0   |   © 2026 CQBER. Todos os direitos reservados."
    local footerDivider = Instance.new("Frame")
    footerDivider.Name = "CQBER_FooterDivider"
    footerDivider.Size = UDim2.new(1, -2, 0, 1)
    footerDivider.Position = UDim2.new(0, 1, 1, -38)
    footerDivider.BackgroundColor3 = Color3.fromRGB(37, 67, 70)
    footerDivider.BorderSizePixel = 0
    footerDivider.Parent = win
    footer.Parent = win

    selectTab("Dashboard")
    local headings = {
        {aimPage, "AIMBOT OPTIONS"}, {miscPage, "FUN / AÇÕES"},
        {espPlayerPage, "ESP OPTIONS"}, {espCarPage, "ESP VEHICLE"},
        {crossPage, "CROSSHAIR OPTIONS"}, {carFisicaPage, "FÍSICAS E LISTA"},
        {carListPage, "TP VEHICLE"}, {funChatPage, "FUN OPTIONS"},
        {keybindsPage, "MENU SETTINGS"},
        {profilesPage, "PROFILE SETTINGS"},
    }
    for _, item in ipairs(headings) do
        local heading = Instance.new("TextLabel")
        heading.Name = "SectionHeading"
        heading.LayoutOrder = -100
        heading.Size = UDim2.new(1, -10, 0, 42)
        heading.BackgroundTransparency = 1
        heading.Text = "▰  " .. item[2]
        heading.Font = Enum.Font.GothamBold
        heading.TextSize = 13
        heading.TextColor3 = THEME.accent
        heading.TextXAlignment = Enum.TextXAlignment.Left
        heading.Parent = item[1]
    end
    
    -- Mystic: conteudo recuado e moldura que termina logo depois da ultima opcao.
    -- A moldura e filha do titulo (nao participa do UIListLayout), e acompanha
    -- o tamanho real da lista em vez de ocupar toda a altura da pagina.
    for _, item in ipairs(headings) do
        local section = item[1]
        section.BackgroundTransparency = 1
        section.BorderSizePixel = 0
        section.ClipsDescendants = (section ~= espCarPage and section ~= carFisicaPage and section ~= carListPage)
        local oldOutline = section:FindFirstChild("CQBER_EmbedOutline")
        if oldOutline then oldOutline:Destroy() end

        local padding = section:FindFirstChild("MysticContentPadding")
        if not padding then
            padding = Instance.new("UIPadding")
            padding.Name = "MysticContentPadding"
            padding.PaddingLeft = UDim.new(0, 30)
            padding.PaddingRight = UDim.new(0, 30)
            padding.PaddingTop = UDim.new(0, 10)
            padding.Parent = section
        end

        local heading = section:FindFirstChild("SectionHeading")
        local layout = section:FindFirstChildOfClass("UIListLayout")
        if heading and layout then
            heading.Size = UDim2.new(1, -12, 0, 35)
            heading.TextSize = 13
            heading.ZIndex = 3
            local panel = Instance.new("Frame")
            panel.Name = "MysticFittedPanel"
            panel.BackgroundColor3 = THEME.panel
            panel.BackgroundTransparency = 0
            panel.BorderSizePixel = 0
            panel.ZIndex = 1
            panel.Position = UDim2.fromOffset(-12, -3)
            panel.Size = UDim2.new(1, 10, 0, 100)
            panel.Parent = heading
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 7)
            corner.Parent = panel
            local border = Instance.new("UIStroke")
            border.Color = THEME.accent
            border.Transparency = 0.35
            border.Thickness = 1
            border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            border.Parent = panel
            local function fitPanel()
                local height = layout.AbsoluteContentSize.Y + 17
                panel.Size = UDim2.new(1, 10, 0, math.max(65, height))
            end
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitPanel)
            task.defer(fitPanel)
        end
    end

    -- DASHBOARD CQBER EXTERNAL: quatro cards no tema laranja.
    -- Somente indicadores e atalhos para opcoes reais existentes no script.
    do
        local dashboardLayout = principalPage:FindFirstChildOfClass("UIListLayout")
        if dashboardLayout then dashboardLayout:Destroy() end
        principalPage.ScrollingEnabled = false
        principalPage.CanvasSize = UDim2.fromOffset(0, 0)
        principalPage.BackgroundTransparency = 1
        local function dashboardCard(title, x, y)
            local frame = Instance.new("Frame")
            frame.Name = "DashboardCard"
            frame.Position = UDim2.new(x, 7, y, 7)
            frame.Size = UDim2.new(0.485, -16, 0.485, -16)
            frame.BackgroundColor3 = THEME.panel
            frame.BorderSizePixel = 0
            frame.Parent = principalPage
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 9)
            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = THEME.accent
            stroke.Transparency = 0.28
            stroke.Thickness = 1
            local heading = Instance.new("TextLabel")
            heading.Size = UDim2.new(1, -24, 0, 32)
            heading.Position = UDim2.fromOffset(12, 7)
            heading.BackgroundTransparency = 1
            heading.Text = title
            heading.TextColor3 = THEME.text
            heading.Font = Enum.Font.GothamBold
            heading.TextSize = 14
            heading.TextXAlignment = Enum.TextXAlignment.Left
            heading.Parent = frame
            return frame
        end
        local function infoLine(frame, text, y, color)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -26, 0, 23)
            l.Position = UDim2.fromOffset(13, y)
            l.BackgroundTransparency = 1
            l.Text = text
            l.TextColor3 = color or THEME.textDim
            l.TextSize = 12
            l.Font = Enum.Font.Gotham
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextTruncate = Enum.TextTruncate.AtEnd
            l.Parent = frame
            return l
        end
        local function navLine(frame, text, y, pageName)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -24, 0, 26)
            b.Position = UDim2.fromOffset(12, y)
            b.BackgroundColor3 = THEME.off
            b.BorderSizePixel = 0
            b.Text = text
            b.TextColor3 = THEME.text
            b.Font = Enum.Font.Gotham
            b.TextSize = 12
            b.Parent = frame
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
            b.MouseButton1Click:Connect(function() selectTab(pageName) end)
        end
        local a = dashboardCard("◉  Informações", 0, 0)
        infoLine(a, "Nome: " .. LP.Name, 43)
        infoLine(a, "Versão: CQBER External 2026", 67)
        infoLine(a, "Status: Interface carregada", 91, THEME.accent)
        infoLine(a, "User ID: " .. tostring(LP.UserId), 115)
        infoLine(a, "Place ID: " .. tostring(game.PlaceId), 139)
        local b = dashboardCard("ϟ  Ações Rápidas", 0.515, 0)
        navLine(b, "Aimbot / Combate", 44, "Aimbot")
        navLine(b, "Veículos / Grab", 76, "Vehicles")
        navLine(b, "Jogadores / Teleporte", 108, "Jogadores")
        navLine(b, "Atalhos e Unload", 140, "Keybinds / Unload")
        local c = dashboardCard("◉  Sistema de ESP", 0, 0.515)
        navLine(c, "ESP Jogadores", 44, "Jogadores")
        navLine(c, "Crosshair", 76, "Crosshair")
        infoLine(c, "ESP geral: " .. (cfg.ESP_Master and "Ligado" or "Desligado"), 117)
        local d = dashboardCard("⚙  Outros", 0.515, 0.515)
        navLine(d, "Fun / Ações", 44, "Fun")
        navLine(d, "Jogadores / Teleporte", 76, "Jogadores")
        navLine(d, "Perfis / Import Export", 108, "Profiles / Import Export")
        infoLine(d, "Rodograu 2.0  |  by CQBER", 145)
    end

    local function makeToggle(parent, label, key, cb)
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, -10, 0, 23)
        r.BackgroundColor3 = THEME.bg
        r.BackgroundTransparency = 1
        r.BorderSizePixel = 0
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
        -- Switch arredondado, estilo menu FiveM.
        local b = Instance.new("TextButton")
        b.Name = "ToggleSwitch"
        b.Size = UDim2.fromOffset(36, 18)
        b.Position = UDim2.new(1, -42, 0.5, -9)
        b.BackgroundColor3 = cfg[key] and THEME.accent or THEME.off
        b.Text = ""
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Parent = r
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local dot = Instance.new("Frame")
        dot.Name = "SwitchDot"
        dot.Size = UDim2.fromOffset(14, 14)
        dot.Position = cfg[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        dot.BackgroundColor3 = THEME.text
        dot.BorderSizePixel = 0
        dot.Parent = b
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        local function updateVisuals()
            b.BackgroundColor3 = cfg[key] and THEME.accent or THEME.off
            dot.Position = cfg[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        end
        profileRefresh[key] = updateVisuals

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
        r.BackgroundTransparency = 1
        r.BorderSizePixel = 0
        r.Parent = parent
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
        bar.BackgroundColor3 = Color3.fromRGB(37, 37, 37)
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
        knob.BackgroundColor3 = THEME.text
        knob.BorderSizePixel = 0
        knob.Parent = bar
        local valueBox = Instance.new("TextBox")
        valueBox.Name = "SliderValue"
        valueBox.Size = UDim2.new(0, 64, 0, 20)
        valueBox.Position = UDim2.new(1, -68, 0, 24)
        valueBox.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
        valueBox.BorderColor3 = THEME.accent
        valueBox.BorderSizePixel = 1
        valueBox.TextXAlignment = Enum.TextXAlignment.Center
        valueBox.TextColor3 = THEME.text
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
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
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
    makeToggle(aimPage, "Recoil Control", "NoRecoil")
    makeToggle(aimPage, "Spread Control", "NoSpread")
    makeToggle(aimPage, "Rapid Trigger", "RapidFire")

    -- Streamspoof local: oculta a interface ao ativar. Nao burla captura externa.
    makeToggle(keybindsPage, "Streamspoof (ocultar menu)", "Streamproof", function(enabled)
        if enabled then
            win.Visible = false
        else
            win.Visible = true
        end
    end)
    makeButton(keybindsPage, "Mostrar menu (Insert)", function() win.Visible = true end)

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
    guiSizeHeading.Parent = keybindsPage

    local function setGuiDimensions(width, height)
        normalSize = Vector2.new(math.clamp(math.floor(width), 430, 1600), math.clamp(math.floor(height), 310, 1100))
        if isMinimized then
            win.Size = UDim2.fromOffset(normalSize.X, 62)
        else
            win.Size = UDim2.fromOffset(normalSize.X, normalSize.Y)
        end
    end
    makeButton(keybindsPage, "[ + ] Aumentar GUI", function()
        setGuiDimensions(normalSize.X + 100, normalSize.Y + 65)
    end)
    makeButton(keybindsPage, "[ - ] Diminuir GUI", function()
        setGuiDimensions(normalSize.X - 100, normalSize.Y - 65)
    end)
    makeButton(keybindsPage, "Tamanho original (740 x 410)", function()
        setGuiDimensions(740, 410)
    end)
    makeButton(keybindsPage, "Tamanho grande (1200 x 750)", function()
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
    
    makeToggle(espPlayerPage, "Master ESP", "ESP_Master")
    makeToggle(espPlayerPage, "Rainbow ESP", "ESP_Rainbow")
    local espHexRow = Instance.new("Frame")
    espHexRow.Size = UDim2.new(1, -12, 0, 36)
    espHexRow.BackgroundTransparency = 1
    espHexRow.Parent = espPlayerPage
    local espHexLabel = Instance.new("TextLabel")
    espHexLabel.Size = UDim2.new(0.52, 0, 1, 0)
    espHexLabel.BackgroundTransparency = 1
    espHexLabel.Text = "ESP Color (HEX)"
    espHexLabel.TextColor3 = THEME.text
    espHexLabel.TextSize = 13
    espHexLabel.Font = Enum.Font.Gotham
    espHexLabel.TextXAlignment = Enum.TextXAlignment.Left
    espHexLabel.Parent = espHexRow
    local espHexBox = Instance.new("TextBox")
    espHexBox.Size = UDim2.new(0.44, 0, 0, 28)
    espHexBox.Position = UDim2.new(0.56, 0, 0, 4)
    espHexBox.BackgroundColor3 = THEME.off
    espHexBox.TextColor3 = THEME.text
    espHexBox.PlaceholderText = "#45DBCC"
    espHexBox.Text = cfg.ESP_Hex
    espHexBox.TextSize = 13
    espHexBox.Font = Enum.Font.Code
    espHexBox.Parent = espHexRow
    Instance.new("UICorner", espHexBox).CornerRadius = UDim.new(0, 6)
    safeConnect(espHexBox.FocusLost, function()
        local v = espHexBox.Text:upper()
        if not v:match("^#%x%x%x%x%x%x$") then v = cfg.ESP_Hex end
        cfg.ESP_Hex = v
        espHexBox.Text = v
        scheduleProfileSave()
    end)
    table.insert(profileRefresh, function() espHexBox.Text = cfg.ESP_Hex end)
    makeToggle(espPlayerPage, "Box ESP", "ESP_Box")
    makeToggle(espPlayerPage, "Name ESP", "ESP_Name")
    makeToggle(espPlayerPage, "Health ESP", "ESP_Health")
    makeToggle(espPlayerPage, "Distance ESP", "ESP_Distance")
    makeToggle(espPlayerPage, "Tracer ESP", "ESP_Tracer")
    makeToggle(espPlayerPage, "Skeleton ESP", "ESP_Skeleton")
    makeToggle(espPlayerPage, "Team Check", "TeamCheckESP")
    makeToggle(espPlayerPage, "Wall Check", "WallCheckESP")
    
    makeToggle(espCarPage, "Vehicle ESP | Veiculos", "ESP_Vehicles")
    
    makeToggle(crossPage, "Custom Crosshair", "Crosshair_On")
    makeToggle(crossPage, "Center Dot", "Crosshair_Dot")
    makeToggle(crossPage, "Crosshair Outline", "Crosshair_Outline")
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
    
    makeToggle(carFisicaPage, "Vehicle Grab [Y]", "CarGrabActive")
    makeSlider(carFisicaPage, "Throw Power [M1]", "ThrowPower", 0, 10, 5, true)
    makeSlider(carFisicaPage, "Grab Range", "GrabDistance", 45, 150, 75, true)
    makeToggle(carFisicaPage, "Vehicle Superman [WASD]", "CarFly", function(s) toggleCarFly(s) end)
    
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
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
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
    
    -- Speedhack: restaura a velocidade anterior ao desativar.
    local savedWalkSpeeds = setmetatable({}, {__mode = "k"})
    local speedConnection
    local function updateSpeed()
        local character = LP.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        if cfg.SpeedHack then
            if savedWalkSpeeds[humanoid] == nil then
                savedWalkSpeeds[humanoid] = humanoid.WalkSpeed
            end
            humanoid.WalkSpeed = math.clamp(tonumber(cfg.SpeedValue) or 32, 16, 150)
        elseif savedWalkSpeeds[humanoid] ~= nil then
            humanoid.WalkSpeed = savedWalkSpeeds[humanoid]
            savedWalkSpeeds[humanoid] = nil
        end
    end
    makeToggle(funChatPage, "Speed Boost", "SpeedHack", function()
        updateSpeed()
    end)
    makeSlider(funChatPage, "Boost Speed", "SpeedValue", 16, 150, 32, true)
    makeSlider(funChatPage, "Spinbot Speed", "SpinSpeed", 1, 90, 15, true)
    safeConnect(LP.CharacterAdded, function(character)
        task.defer(function()
            local humanoid = character:WaitForChild("Humanoid", 8)
            if humanoid and not isUnloaded then updateSpeed() end
        end)
    end)
    -- Atualiza o WalkSpeed quando o slider mudar e recupera mudancas do jogo.
    speedConnection = RunService.Heartbeat:Connect(function()
        if isUnloaded then return end
        if cfg.SpeedHack then updateSpeed() end
    end)
    table.insert(allConnections, speedConnection)

    -- MOVIMENTO: Fly, Noclip, Pulo Infinito e ajuste de pulo.
    -- Tudo e local, reversivel e encerrado no Unload.
    local movementVelocity, movementGyro, movementRoot
    local noclipOriginal = setmetatable({}, {__mode = "k"})
    local savedJumps = setmetatable({}, {__mode = "k"})
    local function stopPlayerFly()
        if movementVelocity then movementVelocity:Destroy(); movementVelocity = nil end
        if movementGyro then movementGyro:Destroy(); movementGyro = nil end
        movementRoot = nil
    end
    local function restoreNoclip()
        for part, value in pairs(noclipOriginal) do
            if part and part.Parent then pcall(function() part.CanCollide = value end) end
            noclipOriginal[part] = nil
        end
    end
    local function restoreJump()
        for hum, data in pairs(savedJumps) do
            if hum and hum.Parent then
                pcall(function() hum.UseJumpPower = data.usePower; hum.JumpPower = data.power; hum.JumpHeight = data.height end)
            end
            savedJumps[hum] = nil
        end
    end
    makeToggle(funChatPage, "Superman Mode", "PlayerFly", function(on)
        if not on then stopPlayerFly() end
    end)
    makeSlider(funChatPage, "Superman Speed", "FlySpeed", 10, 200, 55, true)
    makeToggle(funChatPage, "Ghost Mode / Noclip", "NoClip", function(on)
        if not on then restoreNoclip() end
    end)
    makeToggle(funChatPage, "Infinite Jump", "InfiniteJump")
    makeToggle(funChatPage, "Super Jump", "JumpBoost", function(on)
        if not on then restoreJump() end
    end)
    makeSlider(funChatPage, "Jump Height", "JumpValue", 50, 180, 65, true)
    safeConnect(UIS.JumpRequest, function()
        if isUnloaded or not cfg.InfiniteJump or UIS:GetFocusedTextBox() then return end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
    safeConnect(RunService.Heartbeat, function()
        if isUnloaded then return end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if cfg.NoClip and char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if noclipOriginal[part] == nil then noclipOriginal[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end
        end
        if cfg.JumpBoost and hum then
            if not savedJumps[hum] then
                savedJumps[hum] = {usePower = hum.UseJumpPower, power = hum.JumpPower, height = hum.JumpHeight}
            end
            hum.UseJumpPower = true
            hum.JumpPower = math.clamp(tonumber(cfg.JumpValue) or 65, 50, 180)
        end
        if cfg.PlayerFly and root and hum and hum.Health > 0 then
            if movementRoot ~= root or not movementVelocity or not movementVelocity.Parent then
                stopPlayerFly()
                movementRoot = root
                movementVelocity = Instance.new("BodyVelocity")
                movementVelocity.Name = "CQBER_PlayerFlyVelocity"
                movementVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
                movementVelocity.P = 12000
                movementVelocity.Parent = root
                movementGyro = Instance.new("BodyGyro")
                movementGyro.Name = "CQBER_PlayerFlyGyro"
                movementGyro.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
                movementGyro.P = 12000
                movementGyro.Parent = root
            end
            local camera = workspace.CurrentCamera
            if camera then
                local cf = camera.CFrame
                local dir = Vector3.zero
                if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
                movementVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * math.clamp(tonumber(cfg.FlySpeed) or 55, 10, 200) or Vector3.zero
                movementGyro.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit)
            end
        elseif movementVelocity then
            stopPlayerFly()
        end
    end)

    local spinToggle = Instance.new("TextButton")
    spinToggle.Size = UDim2.new(1, -10, 0, 26)
    spinToggle.BackgroundColor3 = THEME.off
    spinToggle.Text = "Spinbot [OFF]"
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
            spinToggle.Text = "Spinbot [ON]"
            spinToggle.BackgroundColor3 = THEME.accent
            spinConn = RunService.Heartbeat:Connect(function()
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(math.clamp(tonumber(cfg.SpinSpeed) or 15, 1, 90)), 0) end
            end)
        else
            spinToggle.Text = "Spinbot [OFF]"
            spinToggle.BackgroundColor3 = THEME.off
            if spinConn then spinConn:Disconnect(); spinConn = nil end
        end
    end)
    
    local tpTitle = Instance.new("TextLabel")
    tpTitle.Size = UDim2.new(1, -16, 0, 34)
    tpTitle.BackgroundTransparency = 1
    tpTitle.Text = "➤  PLAYER TELEPORT"
    tpTitle.TextColor3 = THEME.accent
    tpTitle.TextSize = 12
    tpTitle.Font = Enum.Font.GothamBold
    tpTitle.TextXAlignment = Enum.TextXAlignment.Center
    tpTitle.Parent = funTpPage
    local tpScroll = Instance.new("ScrollingFrame")
    tpScroll.Size = UDim2.new(1, -10, 0, 340)
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
        cfg.SpeedHack = false
        updateSpeed()
        cfg.PlayerFly = false
        cfg.NoClip = false
        cfg.JumpBoost = false
        cfg.InfiniteJump = false
        stopPlayerFly()
        restoreNoclip()
        restoreJump()
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
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        
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
    
    makeBind(keybindsPage, "Menu Hotkey", "MenuBind")
    makeBind(keybindsPage, "Grab Key [Y]", "GrabBind")
    makeBind(keybindsPage, "Throw Key [M1]", "ThrowBind")
    
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
    
    local function currentESPColor()
        if cfg.ESP_Rainbow then return Color3.fromHSV((tick() * 0.19) % 1, 0.8, 1) end
        local hex = tostring(cfg.ESP_Hex or "#45DBCC")
        local ok, col = pcall(function() return Color3.fromHex(hex) end)
        return ok and col or THEME.accent
    end
    local function hideESP()
        for _, o in pairs(esp) do
            for k, v in pairs(o) do
                if k == "skeleton" then
                    for _, line in ipairs(v) do line.Visible = false end
                else v.Visible = false end
            end
        end
        for _, data in pairs(espVeh) do if data.box then data.box.Visible = false end end
    end
    local function updESP()
        if not cfg.ESP_Master then hideESP(); return end
        local espColor = currentESPColor()
        for _, o in pairs(esp) do
            for k, v in pairs(o) do
                if k == "skeleton" then
                    for _, line in ipairs(v) do line.Color = espColor end
                elseif k ~= "health" then v.Color = espColor end
            end
        end
        for _, data in pairs(espVeh) do if data.box then data.box.Color = espColor end end
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

    -- Distancia ate a CARROCERIA (nao ate o banco, que pode ficar longe).
    -- Modelos grandes usam o ponto mais proximo da caixa 3D.
    local function vehicleDistance(model, rootPosition)
        local ok, boxCF, boxSize = pcall(function()
            local cf, size = model:GetBoundingBox()
            return cf, size
        end)
        if not ok or not boxCF then return math.huge end
        local localPoint = boxCF:PointToObjectSpace(rootPosition)
        local half = boxSize * 0.5
        local closest = Vector3.new(
            math.clamp(localPoint.X, -half.X, half.X),
            math.clamp(localPoint.Y, -half.Y, half.Y),
            math.clamp(localPoint.Z, -half.Z, half.Z)
        )
        return (boxCF:PointToWorldSpace(closest) - rootPosition).Magnitude
    end

    -- Prioriza o carro realmente apontado. Sem alvo, usa apenas carro
    -- proximo e a frente, evitando pegar outro veiculo por engano.
    local function nearestCar(maxDist)
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local range = math.clamp(tonumber(maxDist) or 75, 15, 150)
        local mouseTarget = LP:GetMouse().Target
        local vehicles = findVehicles()
        -- Mira em qualquer peca da carroceria, nao apenas no banco.
        if mouseTarget then
            local chosen, chosenDistance = nil, math.huge
            for _, vehicle in ipairs(vehicles) do
                local seat, model = vehicle.seat, vehicle.model
                if seat and seat.Parent and model and model.Parent
                    and (not seat.Occupant or cfg.GrabOccupiedCars)
                    and mouseTarget:IsDescendantOf(model) then
                    local part = seat.AssemblyRootPart or seat
                    local dist = (seat.Position - root.Position).Magnitude
                    if part and not part.Anchored and dist <= range + 15 and dist < chosenDistance then
                        chosen, chosenDistance = model, dist
                    end
                end
            end
            if chosen then return chosen end
        end
        -- Sem mira valida: somente o veiculo mais perto, a ate 25 studs,
        -- dentro de um cone na frente do personagem.
        local best, bestDistance = nil, math.huge
        local forward = root.CFrame.LookVector
        for _, vehicle in ipairs(vehicles) do
            local seat, model = vehicle.seat, vehicle.model
            if seat and seat.Parent and model and model.Parent
                and (not seat.Occupant or cfg.GrabOccupiedCars) then
                local part = seat.AssemblyRootPart or seat
                if part and not part.Anchored then
                    local delta = seat.Position - root.Position
                    local horizontal = Vector3.new(delta.X, 0, delta.Z)
                    local dist = horizontal.Magnitude
                    if dist <= math.min(range, 25) and dist < bestDistance
                        and (dist < 5 or forward:Dot(horizontal.Unit) >= 0.35) then
                        best, bestDistance = model, dist
                    end
                end
            end
        end
        return best
    end

    local function grabForce(part)
        local strength = 9
        local mass = math.max(part.AssemblyMass, 1)
        return math.clamp(mass * (12000 + strength * 13000), 100000, 50000000)
    end

    stopGrab = function()
        if grabConn then grabConn:Disconnect(); grabConn = nil end
        if grabState then
            if grabState.orientation then grabState.orientation:Destroy() end
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
            else warn("[CQBER] Nenhum veiculo elegivel no alcance. Verifique ocupantes, ancora e autoridade da fisica.") end
            return
        end
        local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
        local part = seat and (seat.AssemblyRootPart or seat)
        if not part or part.Anchored then
            warn("[cqber] Veiculo ancorado ou sem montagem fisica livre")
            return
        end
        -- Remove qualquer impulso de arremesso anterior que ainda esteja ativo.
        -- Um BodyVelocity antigo pode continuar empurrando o carro para cima ao apertar Y.
        for _, obj in ipairs(part:GetChildren()) do
            if obj.Name == "CQBER_ThrowBoost" then obj:Destroy() end
        end
        pcall(function()
            local v = part.AssemblyLinearVelocity
            part.AssemblyLinearVelocity = Vector3.new(v.X * 0.25, math.min(v.Y, 0), v.Z * 0.25)
            part.AssemblyAngularVelocity = Vector3.zero
        end)
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
        local initialBoxCF, initialSize = model:GetBoundingBox()
        attachment.Position = part.CFrame:PointToObjectSpace(initialBoxCF.Position)
        attachment.Parent = part
        local align = Instance.new("AlignPosition")
        align.Name = "CQBER_GrabAlign"
        align.Mode = Enum.PositionAlignmentMode.OneAttachment
        align.Attachment0 = attachment
        align.MaxForce = grabForce(part)
        align.MaxVelocity = 34
        align.Responsiveness = 13
        align.RigidityEnabled = false
        align.ApplyAtCenterOfMass = true
        align.Parent = part
        -- Mantem o carro nivelado, sem rodar no ar durante o Y.
        local orientation = Instance.new("AlignOrientation")
        orientation.Name = "CQBER_GrabLevel"
        orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
        orientation.Attachment0 = attachment
        orientation.MaxTorque = math.clamp(part.AssemblyMass * 45000, 100000, 50000000)
        orientation.MaxAngularVelocity = 8
        orientation.Responsiveness = 30
        orientation.RigidityEnabled = false
        local initialLook = part.CFrame.LookVector
        local horizontalLook = Vector3.new(initialLook.X, 0, initialLook.Z)
        if horizontalLook.Magnitude < 0.01 then horizontalLook = Vector3.new(0, 0, -1) end
        local levelRotation = CFrame.lookAt(Vector3.zero, horizontalLook.Unit)
        orientation.CFrame = levelRotation
        orientation.Parent = part
        -- Altura fixa e moderada, medida pelo centro real da carroceria.
        local holdHeight = math.clamp(2.7 + initialSize.Y * 0.5, 3.7, 5.8)
        -- O AlignPosition controla a raiz da montagem, NAO o centro da caixa.
        -- Preservar o deslocamento evita o carro mergulhar ou subir sem parar.
        -- O attachment fica no centro da carroceria: nao somar offset da raiz.
        local character = LP.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then target:Destroy(); align:Destroy(); orientation:Destroy(); attachment:Destroy(); return end
        local centerDestination = root.Position + Vector3.new(0, holdHeight, 0)
        -- Nao usa PivotTo: teleporte local pode separar o visual da hitbox
        -- quando a simulacao do veiculo pertence ao servidor.
        -- O AlignPosition move a montagem fisica de verdade em ~0.3 s.
        local destination = centerDestination
        local startPosition = initialBoxCF.Position
        align.Position = startPosition
        target.Position = startPosition
        align.MaxVelocity = 24
        align.Responsiveness = 12
        grabbedCar = model
        grabState = {part = part, align = align, orientation = orientation, attachment = attachment, target = target}
        pcall(function()
            part.AssemblyAngularVelocity = Vector3.zero
        end)
        local stuckFor, warned = 0, false
        local physicsRefresh = 0
        local grabAge = 0
        grabConn = RunService.Heartbeat:Connect(function(dt)
            if isUnloaded or not cfg.CarGrabActive or not model.Parent or not part.Parent then
                stopGrab(); return
            end
            -- Se a montagem mudar (ex.: ocupante/suspensao), reposiciona o attachment
            -- na raiz atual sem soltar o Grab.
            local newRoot = part.AssemblyRootPart
            if newRoot and newRoot ~= part and not newRoot.Anchored and newRoot:IsDescendantOf(model) then
                part = newRoot
                local currentBox = model:GetBoundingBox()
                attachment.Parent = part
                attachment.Position = part.CFrame:PointToObjectSpace(currentBox.Position)
                align.Parent = part
                orientation.Parent = part
                grabState.part = part
            end
            local character = LP.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then stopGrab(); return end
            local look = root.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
            -- Mantem o centro da carroceria a altura constante, sem acumular subida.
            local destination = root.Position + Vector3.new(0, holdHeight, 0)
            local move = root.AssemblyLinearVelocity
            destination = destination + Vector3.new(move.X, 0, move.Z) * 0.08
            grabAge = grabAge + dt
            -- Animacao curta: alvo sai da posicao atual e chega acima da cabeca.
            local alpha = math.clamp(grabAge / 0.30, 0, 1)
            alpha = 1 - (1 - alpha) ^ 3
            local animatedTarget = startPosition:Lerp(destination, alpha)
            target.Position = animatedTarget
            align.Position = animatedTarget
            -- AlignPosition cuida da altura; nao injeta velocidade vertical a cada frame.
            -- Recalcula força caso o modelo/assemblagem mude durante o Grab.
            physicsRefresh = physicsRefresh + dt
            if physicsRefresh >= 0.15 then
                physicsRefresh = 0
                align.MaxForce = grabForce(part)
                orientation.MaxTorque = math.clamp(part.AssemblyMass * 45000, 100000, 50000000)
            end
            -- Velocidade limitada: evita que a correcao de posicao vire um lancamento.
            align.MaxVelocity = grabAge < 0.45 and 24 or 16
            align.Responsiveness = grabAge < 0.45 and 12 or 9
            orientation.CFrame = levelRotation
            -- Amortece subidas excessivas sem forcar teleporte nem alterar hitbox.
            pcall(function()
                part.AssemblyAngularVelocity = Vector3.zero
                local v = part.AssemblyLinearVelocity
                if v.Y > 14 then
                    part.AssemblyLinearVelocity = Vector3.new(v.X, 14, v.Z)
                end
            end)
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
        stopGrab()
        if not part or not part.Parent or part.Anchored then return end
        local power = math.clamp(tonumber(cfg.ThrowPower) or 5, 0, 10)
        if power <= 0 then return end
        -- Arremesso do RXOUL enviado: impulso na direcao da camera
        -- somado a um impulso vertical, com BodyVelocity por 1 segundo.
        local camera = workspace.CurrentCamera
        local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
        local throwVel = look * (power * 150) + Vector3.new(0, power * 100, 0)
        pcall(function()
            part.AssemblyAngularVelocity = Vector3.zero
            part.AssemblyLinearVelocity = throwVel
            local bv = Instance.new("BodyVelocity")
            bv.Name = "CQBER_ThrowBoost"
            bv.MaxForce = Vector3.new(1e8, 1e8, 1e8)
            bv.Velocity = throwVel
            bv.Parent = part
            game:GetService("Debris"):AddItem(bv, 1)
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
    
    print("[cqber] MYSTIC TURQUESA carregado com sucesso.")
end, function(e)
    return debug.traceback(tostring(e), 2)
end)
if not ok then
    warn("[cqber ERRO]", err)
    print("[cqber ERRO]", err)
    pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "CQBER_ErrorDiagnostic"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 999999
        gui.Parent = game:GetService("CoreGui")
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 560, 0, 160)
        label.Position = UDim2.new(0.5, -280, 0.15, 0)
        label.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
        label.BackgroundTransparency = 0.05
        label.TextColor3 = Color3.fromRGB(255, 210, 190)
        label.TextWrapped = true
        label.TextSize = 14
        label.Font = Enum.Font.Code
        label.Text = "CQBER ERRO AO ABRIR\n" .. tostring(err):sub(1, 850)
        label.Parent = gui
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 10)
    end)
end
