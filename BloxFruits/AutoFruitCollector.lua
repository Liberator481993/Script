--[[
Blox Fruits Auto Fruit Collector v1.2.1
Delta Android / Arceus X
Client-side helper: scans Workspace for spawned fruit models, ESP, notifications,
and makes a best-effort touch pickup attempt. Server pickup is not guaranteed.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local CFG = { ScanInterval = 2, MaxDistance = 5000, Cooldown = 10, PickupWait = 0.85, FlightSpeed = 95, ArrivalDistance = 7, FlightTimeout = 30 }
local State = {
    Running = false, ESP = false, Notify = true, Filter = "", HasScanned = false, FlightToken = 0,
    Fruits = {}, LastAttempt = {}, ESPObjects = {}, ListRows = {}, Attempts = 0, Pickups = 0, Alive = true
}
local function safeDestroy(x) if x then pcall(function() x:Destroy() end) end end
local function character() return LocalPlayer.Character end
local function root()
    local c = character()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function fruitPart(obj)
    if obj:IsA("BasePart") then return obj end
    local h = obj:FindFirstChild("Handle", true)
    if h and h:IsA("BasePart") then return h end
    if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
    return obj:FindFirstChildWhichIsA("BasePart", true)
end
local function fruitName(obj)
    return (obj.Name or "Fruit"):gsub("%s*[Ff]ruit%s*$", "")
end
local function isFruit(obj)
    if not obj or not obj.Parent or not obj:IsDescendantOf(Workspace) then return false end
    if not (obj:IsA("Model") or obj:IsA("Tool") or obj:IsA("BasePart")) then return false end

    -- Reject anything belonging to an NPC, shop, dealer or interaction point.
    local current = obj
    while current and current ~= Workspace do
        local name = string.lower(current.Name or "")
        if name:find("shop",1,true) or name:find("dealer",1,true)
            or name:find("vendor",1,true) or name:find("npc",1,true)
            or name:find("remove blox",1,true) or name:find("sick man",1,true) then
            return false
        end
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
            return false
        end
        if current:IsA("ProximityPrompt") or current:IsA("ClickDetector") then return false end
        current = current.Parent
    end

    local n = string.lower(obj.Name or "")
    if n:sub(-5) ~= "fruit" then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and obj:IsDescendantOf(p.Character) then return false end
    end

    -- Avoid treating parts inside a fruit container as separate fruits.
    local parent = obj.Parent
    while parent and parent ~= Workspace do
        if (parent:IsA("Model") or parent:IsA("Tool")) and string.lower(parent.Name):sub(-5) == "fruit" then
            return false
        end
        parent = parent.Parent
    end
    return fruitPart(obj) ~= nil
end
local function notify(title, msg)
    if not State.Notify then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title=title, Text=msg, Duration=4})
    end)
end
local function guiParent()
    local ok, fn = pcall(function() return gethui end)
    if ok and type(fn) == "function" then
        local good, gui = pcall(fn)
        if good and gui then return gui end
    end
    local good, core = pcall(function() return game:GetService("CoreGui") end)
    if good and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local old = guiParent():FindFirstChild("BloxFruitsAutoFruitCollector")
if old then old:Destroy() end
local Gui = Instance.new("ScreenGui")
Gui.Name = "BloxFruitsAutoFruitCollector"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 999
local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(280,440)
Main.Position = UDim2.new(.5,-140,.5,-220)
Main.BackgroundColor3 = Color3.fromRGB(13,16,27)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = Gui
Instance.new("UICorner",Main).CornerRadius = UDim.new(0,14)
local stroke = Instance.new("UIStroke",Main)
stroke.Color = Color3.fromRGB(91,103,255)
stroke.Thickness = 1.4

local UIS = game:GetService("UserInputService")
local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(1,0,0,42)
Bar.BackgroundColor3 = Color3.fromRGB(24,29,48)
Bar.BorderSizePixel = 0
Bar.Active = true
Bar.Parent = Main
Instance.new("UICorner",Bar).CornerRadius = UDim.new(0,14)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(11,3)
Title.Size = UDim2.new(1,-82,0,20)
Title.Font = Enum.Font.GothamBold
Title.Text = "СБОРЩИК ФРУКТОВ"
Title.TextColor3 = Color3.fromRGB(239,241,255)
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 3
Title.Parent = Bar
local Sub = Instance.new("TextLabel")
Sub.BackgroundTransparency = 1
Sub.Position = UDim2.fromOffset(12,22)
Sub.Size = UDim2.new(1,-82,0,13)
Sub.Font = Enum.Font.Gotham
Sub.Text = "BLOX FRUITS  •  DELTA / ARCEUS"
Sub.TextColor3 = Color3.fromRGB(146,157,190)
Sub.TextSize = 8
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.ZIndex = 3
Sub.Parent = Bar

local function button(name, label, pos, size, color)
    local b = Instance.new("TextButton")
    b.Name=name; b.Text=label; b.Position=pos; b.Size=size
    b.BackgroundColor3=color; b.BorderSizePixel=0; b.AutoButtonColor=true
    b.Font=Enum.Font.GothamBold; b.TextSize=10; b.TextColor3=Color3.new(1,1,1)
    b.Parent=Main
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    return b
end
local function field(name, placeholder, y, value)
    local f=Instance.new("TextBox")
    f.Name=name; f.Position=UDim2.fromOffset(11,y); f.Size=UDim2.new(1,-22,0,29)
    f.BackgroundColor3=Color3.fromRGB(24,30,48); f.BorderSizePixel=0
    f.ClearTextOnFocus=false; f.Font=Enum.Font.Gotham; f.TextSize=10
    f.PlaceholderText=placeholder; f.PlaceholderColor3=Color3.fromRGB(118,130,160)
    f.Text=value or ""; f.TextColor3=Color3.fromRGB(225,231,250)
    f.TextXAlignment=Enum.TextXAlignment.Left; f.Parent=Main
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    local pad=Instance.new("UIPadding",f); pad.PaddingLeft=UDim.new(0,9)
    return f
end
local Status=Instance.new("TextLabel")
Status.Position=UDim2.fromOffset(11,49); Status.Size=UDim2.new(1,-22,0,39)
Status.BackgroundColor3=Color3.fromRGB(22,28,44); Status.BorderSizePixel=0
Status.Font=Enum.Font.Gotham; Status.Text="Готово. Нажми «СТАРТ» для поиска."
Status.TextColor3=Color3.fromRGB(190,203,235); Status.TextSize=10
Status.TextWrapped=true; Status.TextXAlignment=Enum.TextXAlignment.Left; Status.Parent=Main
Instance.new("UICorner",Status).CornerRadius = UDim.new(0,8)
local function status(s) Status.Text=s end
local Start=button("Start","▶  ЗАПУСТИТЬ",UDim2.fromOffset(11,96),UDim2.new(.5,-16,0,32),Color3.fromRGB(46,125,98))
local Stop=button("Stop","■  СТОП",UDim2.new(.5,5,0,96),UDim2.new(.5,-16,0,32),Color3.fromRGB(129,55,72))
local EspBtn=button("ESP","ПОДСВЕТКА: ВЫКЛ",UDim2.fromOffset(11,135),UDim2.new(.5,-16,0,30),Color3.fromRGB(48,57,87))
local NotifyBtn=button("Notify","ЗВУК/УВЕД.: ВКЛ",UDim2.new(.5,5,0,135),UDim2.new(.5,-16,0,30),Color3.fromRGB(48,57,87))
local Filter=field("FruitFilter","Фильтр по названию (пусто — все)",173,"")
local Distance=field("MaxDistance","Дистанция сбора (studs)",208,tostring(CFG.MaxDistance))
local Interval=field("ScanInterval","Интервал проверки, сек.",243,tostring(CFG.ScanInterval))
local Stats=Instance.new("TextLabel")
Stats.Position=UDim2.fromOffset(11,277); Stats.Size=UDim2.new(1,-22,0,19)
Stats.BackgroundTransparency=1; Stats.Font=Enum.Font.Gotham
Stats.Text="Найдено: 0 | Попыток: 0 | Собрано: 0"
Stats.TextColor3=Color3.fromRGB(153,167,203); Stats.TextSize=9
Stats.TextXAlignment=Enum.TextXAlignment.Left; Stats.Parent=Main
local Footer=Instance.new("TextLabel")
Footer.Position=UDim2.fromOffset(11,296); Footer.Size=UDim2.new(1,-22,0,18)
Footer.BackgroundTransparency=1; Footer.Font=Enum.Font.Gotham
Footer.Text="Перемещение: плавный полёт"
Footer.TextColor3=Color3.fromRGB(105,119,151); Footer.TextSize=8
Footer.TextXAlignment=Enum.TextXAlignment.Left; Footer.Parent=Main
local Min=button("Minimize","—",UDim2.new(1,-61,0,8),UDim2.fromOffset(23,25),Color3.fromRGB(48,56,85))
Min.Parent=Bar; Min.ZIndex=5
local Close=button("Close","×",UDim2.new(1,-32,0,8),UDim2.fromOffset(23,25),Color3.fromRGB(130,49,69))
Close.Parent=Bar; Close.ZIndex=5

local ListPanel = Instance.new("Frame")
ListPanel.Name = "SpawnedFruitList"
ListPanel.Position = UDim2.fromOffset(11,322)
ListPanel.Size = UDim2.new(1,-22,0,107)
ListPanel.BackgroundColor3 = Color3.fromRGB(18,23,39)
ListPanel.BorderSizePixel = 0
ListPanel.Parent = Main
Instance.new("UICorner",ListPanel).CornerRadius = UDim.new(0,9)
local listStroke = Instance.new("UIStroke",ListPanel)
listStroke.Color = Color3.fromRGB(55,72,111)
listStroke.Transparency = .25
local ListTitle = Instance.new("TextLabel")
ListTitle.BackgroundTransparency = 1
ListTitle.Position = UDim2.fromOffset(9,5)
ListTitle.Size = UDim2.new(1,-18,0,18)
ListTitle.Font = Enum.Font.GothamBold
ListTitle.Text = "НАЙДЕННЫЕ ФРУКТЫ"
ListTitle.TextColor3 = Color3.fromRGB(224,230,255)
ListTitle.TextSize = 10
ListTitle.TextXAlignment = Enum.TextXAlignment.Left
ListTitle.Parent = ListPanel
local ListCount = Instance.new("TextLabel")
ListCount.BackgroundTransparency = 1
ListCount.Position = UDim2.new(1,-38,0,5)
ListCount.Size = UDim2.fromOffset(28,18)
ListCount.Font = Enum.Font.GothamBold
ListCount.Text = "0"
ListCount.TextColor3 = Color3.fromRGB(112,224,190)
ListCount.TextSize = 10
ListCount.TextXAlignment = Enum.TextXAlignment.Right
ListCount.Parent = ListPanel
local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Name = "FruitRows"
ListScroll.Position = UDim2.fromOffset(6,26)
ListScroll.Size = UDim2.new(1,-12,1,-31)
ListScroll.BackgroundTransparency = 1
ListScroll.BorderSizePixel = 0
ListScroll.ScrollBarThickness = 2
ListScroll.ScrollBarImageColor3 = Color3.fromRGB(105,123,190)
ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ListScroll.Parent = ListPanel
local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0,4)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ListScroll
local EmptyList = Instance.new("TextLabel")
EmptyList.Name = "EmptyHint"
EmptyList.Size = UDim2.new(1,-8,0,38)
EmptyList.BackgroundTransparency = 1
EmptyList.Font = Enum.Font.Gotham
EmptyList.Text = "Фрукты пока не найдены."
EmptyList.TextColor3 = Color3.fromRGB(119,132,166)
EmptyList.TextSize = 9
EmptyList.TextWrapped = true
EmptyList.Parent = ListScroll

-- Keep the entire panel inside the visible screen area.
local function clampMain()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local width = Main.AbsoluteSize.X
    local height = Main.AbsoluteSize.Y
    local x = math.clamp(Main.AbsolutePosition.X, 0, math.max(0, viewport.X - width))
    local y = math.clamp(Main.AbsolutePosition.Y, 0, math.max(0, viewport.Y - height))
    Main.Position = UDim2.fromOffset(x,y)
end
local function fitMainToScreen()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local scale = math.min(1, (viewport.X - 16) / 280, (viewport.Y - 16) / 440)
    scale = math.max(0.55, scale)
    local uiScale = Main:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    uiScale.Scale = scale
    uiScale.Parent = Main
    task.defer(function()
        if Main.Parent then
            Main.Position = UDim2.fromOffset(
                math.max(0,(viewport.X-Main.AbsoluteSize.X)/2),
                math.max(0,(viewport.Y-Main.AbsoluteSize.Y)/2)
            )
        end
    end)
end
fitMainToScreen()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitMainToScreen)
end

-- Dedicated drag handle avoids fighting the minimize/close buttons.
local DragHandle = Instance.new("TextButton")
DragHandle.Name = "DragHandle"
DragHandle.Text = ""
DragHandle.BackgroundTransparency = 1
DragHandle.BorderSizePixel = 0
DragHandle.Position = UDim2.fromOffset(0,0)
DragHandle.Size = UDim2.new(1,-68,1,0)
DragHandle.Active = true
DragHandle.ZIndex = 2
DragHandle.Parent = Bar
local dragging, dragInput, dragStart, startPosition = false, nil, nil, nil
DragHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPosition = Main.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        local camera = Workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local scale = Main:FindFirstChildOfClass("UIScale")
        local w = Main.AbsoluteSize.X
        local h = Main.AbsoluteSize.Y
        local x = math.clamp(startPosition.X.Offset + delta.X, 0, math.max(0,viewport.X-w))
        local y = math.clamp(startPosition.Y.Offset + delta.Y, 0, math.max(0,viewport.Y-h))
        Main.Position = UDim2.fromOffset(x,y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        dragInput = nil
    end
end)

local function removeESP(obj)
    local e=State.ESPObjects[obj]
    if e then
        if e.Highlight then e.Highlight:Destroy() end
        if e.Billboard then e.Billboard:Destroy() end
        State.ESPObjects[obj]=nil
    end
end
local function addESP(obj)
    if State.ESPObjects[obj] then return end
    local part=fruitPart(obj)
    if not part then return end
    local h=Instance.new("Highlight")
    h.Adornee=obj; h.FillColor=Color3.fromRGB(151,93,255)
    h.OutlineColor=Color3.fromRGB(86,225,255)
    h.FillTransparency=.65; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent=Gui
    local bb=Instance.new("BillboardGui")
    bb.Adornee=part; bb.Size=UDim2.fromOffset(180,28)
    bb.StudsOffset=Vector3.new(0,2.5,0); bb.AlwaysOnTop=true; bb.Parent=Gui
    local label=Instance.new("TextLabel")
    label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1
    label.Font=Enum.Font.GothamBold; label.TextColor3=Color3.fromRGB(220,205,255)
    label.TextStrokeTransparency=.25; label.TextSize=13
    label.Text=fruitName(obj); label.Parent=bb
    State.ESPObjects[obj]={Highlight=h,Billboard=bb,Label=label}
end
local function clearESP()
    for obj in pairs(State.ESPObjects) do removeESP(obj) end
end
local function removeListRow(obj)
    local row = State.ListRows[obj]
    if row then row:Destroy(); State.ListRows[obj] = nil end
end
local function updateFruitList()
    local r = root()
    local entries = {}
    for obj in pairs(State.Fruits) do
        if obj and obj.Parent and obj:IsDescendantOf(Workspace) then
            local part = fruitPart(obj)
            if part then
                table.insert(entries,{Object=obj,Distance=r and (part.Position-r.Position).Magnitude or math.huge})
            else
                removeListRow(obj)
            end
        else
            removeListRow(obj)
        end
    end
    table.sort(entries,function(a,b) return a.Distance < b.Distance end)
    local present = {}
    for index,item in ipairs(entries) do
        local obj,distance = item.Object,item.Distance
        present[obj] = true
        local row = State.ListRows[obj]
        if not row then
            row = Instance.new("Frame")
            row.Name = "FruitRow"
            row.Size = UDim2.new(1,-3,0,35)
            row.BackgroundColor3 = Color3.fromRGB(28,36,57)
            row.BorderSizePixel = 0
            row.Parent = ListScroll
            Instance.new("UICorner",row).CornerRadius = UDim.new(0,7)
            local dot = Instance.new("Frame")
            dot.Name = "Dot"; dot.Position = UDim2.fromOffset(8,13)
            dot.Size = UDim2.fromOffset(8,8)
            dot.BackgroundColor3 = Color3.fromRGB(104,229,184)
            dot.BorderSizePixel = 0; dot.Parent = row
            Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)
            local name = Instance.new("TextLabel")
            name.Name = "FruitName"; name.Position = UDim2.fromOffset(23,3)
            name.Size = UDim2.new(1,-100,0,15); name.BackgroundTransparency = 1
            name.Font = Enum.Font.GothamBold; name.TextColor3 = Color3.fromRGB(230,235,255)
            name.TextSize = 10; name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd; name.Parent = row
            local sub = Instance.new("TextLabel")
            sub.Name = "FruitState"; sub.Position = UDim2.fromOffset(23,18)
            sub.Size = UDim2.new(1,-100,0,12); sub.BackgroundTransparency = 1
            sub.Font = Enum.Font.Gotham; sub.TextColor3 = Color3.fromRGB(119,218,184)
            sub.TextSize = 8; sub.TextXAlignment = Enum.TextXAlignment.Left; sub.Parent = row
            local dist = Instance.new("TextLabel")
            dist.Name = "Distance"; dist.AnchorPoint = Vector2.new(1,0)
            dist.Position = UDim2.new(1,-8,0,10); dist.Size = UDim2.fromOffset(68,15)
            dist.BackgroundTransparency = 1; dist.Font = Enum.Font.GothamBold
            dist.TextColor3 = Color3.fromRGB(164,180,220); dist.TextSize = 9
            dist.TextXAlignment = Enum.TextXAlignment.Right; dist.Parent = row
            State.ListRows[obj] = row
        end
        row.LayoutOrder = index
        row.FruitName.Text = "🍈  "..fruitName(obj)
        row.Distance.Text = distance == math.huge and "--" or (tostring(math.floor(distance)).." studs")
        local waiting = State.LastAttempt[obj] and os.clock()-State.LastAttempt[obj] < CFG.Cooldown
        row.FruitState.Text = waiting and "НАЙДЕН • ОЖИДАНИЕ" or "ГОТОВ К СБОРУ"
        row.Dot.BackgroundColor3 = waiting and Color3.fromRGB(255,190,95) or Color3.fromRGB(104,229,184)
    end
    for obj in pairs(State.ListRows) do
        if not present[obj] then removeListRow(obj) end
    end
    ListCount.Text = tostring(#entries)
    EmptyList.Visible = #entries == 0
end
local function scan()
    if State.HasScanned then
        if State.ESP then for obj in pairs(State.Fruits) do if obj and obj.Parent then addESP(obj) end end end
        updateFruitList()
        return State.Fruits
    end
    local found={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if isFruit(obj) then
            local n=string.lower(obj.Name)
            if State.Filter=="" or n:find(string.lower(State.Filter),1,true) or string.lower(fruitName(obj)):find(string.lower(State.Filter),1,true) then
                found[obj]=true
                if not State.Fruits[obj] then
                    State.Fruits[obj]=true
                    notify("ПОЯВИЛСЯ ФРУКТ",fruitName(obj))
                end
                if State.ESP then addESP(obj) end
            end
        end
    end
    for obj in pairs(State.Fruits) do
        if not obj or not obj.Parent or not obj:IsDescendantOf(Workspace) then
            State.Fruits[obj]=nil; State.LastAttempt[obj]=nil; removeESP(obj)
        end
    end
    State.HasScanned = true
    updateFruitList()
    return found
end

-- After the initial world scan, watch newly spawned objects instead of rescanning all Workspace.
Workspace.DescendantAdded:Connect(function(obj)
    task.delay(0.2, function()
        if not State.Alive or not (State.Running or State.ESP) or not isFruit(obj) then return end
        local n = string.lower(obj.Name)
        if State.Filter ~= "" and not n:find(string.lower(State.Filter),1,true)
            and not string.lower(fruitName(obj)):find(string.lower(State.Filter),1,true) then return end
        if not State.Fruits[obj] then
            State.Fruits[obj] = true
            if State.ESP then addESP(obj) end
            notify("ПОЯВИЛСЯ ФРУКТ", fruitName(obj))
            updateFruitList()
        end
    end)
end)

local function nearest()
    local r=root()
    if not r then return nil end
    local target,dist=nil,math.huge
    for obj in pairs(State.Fruits) do
        if obj and obj.Parent and obj:IsDescendantOf(Workspace) then
            local p=fruitPart(obj)
            if p then
                local d=(p.Position-r.Position).Magnitude
                local last=State.LastAttempt[obj] or 0
                if d<=CFG.MaxDistance and d<dist and os.clock()-last>=CFG.Cooldown then target,dist=obj,d end
            end
        end
    end
    return target,dist
end
local function flyToFruit(obj)
    local characterModel = character()
    local humanoid = characterModel and characterModel:FindFirstChildOfClass("Humanoid")
    local r = root()
    local part = obj and fruitPart(obj)
    if not r or not part or not humanoid then return false end

    State.FlightToken = State.FlightToken + 1
    local myToken = State.FlightToken
    local attachment = Instance.new("Attachment")
    attachment.Name = "FruitFlightAttachment"
    attachment.Parent = r

    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "FruitFlightVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.MaxForce = math.huge
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = r

    local orient = Instance.new("AlignOrientation")
    orient.Name = "FruitFlightOrientation"
    orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orient.Attachment0 = attachment
    orient.MaxTorque = math.huge
    orient.Responsiveness = 18
    orient.Parent = r

    local started = os.clock()
    local arrived = false
    local RunService = game:GetService("RunService")
    -- Cruise above both the player's starting point and the fruit. Do not aim
    -- directly at a low target while crossing the sea.
    local cruiseY = math.max(r.Position.Y, part.Position.Y) + 140
    local landingOffset = Vector3.new(0, 8, 0)
    local descending = false
    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

    while State.Alive and State.Running and State.FlightToken == myToken
        and os.clock() - started < CFG.FlightTimeout do
        if not obj or not obj.Parent or not obj:IsDescendantOf(Workspace) then break end
        r = root()
        part = fruitPart(obj)
        if not r or not part then break end

        local targetPosition
        local horizontal = Vector3.new(part.Position.X - r.Position.X, 0, part.Position.Z - r.Position.Z)
        if not descending and horizontal.Magnitude <= 12 then
            descending = true
        end

        if descending then
            -- Only descend once directly above the fruit.
            targetPosition = part.Position + landingOffset
        else
            targetPosition = Vector3.new(part.Position.X, cruiseY, part.Position.Z)
        end

        local offset = targetPosition - r.Position
        local distance = offset.Magnitude
        if descending and distance <= CFG.ArrivalDistance then
            arrived = true
            break
        end

        local direction = distance > 0.01 and offset.Unit or Vector3.zero
        local speed = math.min(CFG.FlightSpeed, math.max(18, distance * 1.25))
        velocity.VectorVelocity = direction * speed
        if direction.Magnitude > 0 then
            orient.CFrame = CFrame.lookAt(r.Position, r.Position + direction)
        end
        RunService.Heartbeat:Wait()
    end

    velocity:Destroy()
    orient:Destroy()
    attachment:Destroy()
    return arrived and State.Running and State.FlightToken == myToken
end

local function attemptPickup(obj)
    local r=root()
    local p=obj and fruitPart(obj)
    if not r or not p then return end
    State.LastAttempt[obj]=os.clock()
    State.Attempts=State.Attempts+1
    status("Лечу к фрукту: "..fruitName(obj).."...")
    local arrived = flyToFruit(obj)
    if not arrived then
        status("Полёт прерван или фрукт слишком далеко.")
        return
    end

    r = root()
    p = fruitPart(obj)
    if not r or not p then return end
    local touch = nil
    pcall(function()
        local env = (type(getgenv) == "function" and getgenv()) or _G
        touch = rawget(env,"firetouchinterest")
    end)
    if type(touch) == "function" then
        pcall(function()
            touch(r,p,0)
            task.wait(.12)
            touch(r,p,1)
        end)
    end
    task.wait(CFG.PickupWait)
    if not obj.Parent or not obj:IsDescendantOf(Workspace) then
        State.Pickups=State.Pickups+1
        State.Fruits[obj]=nil
        removeESP(obj)
        status("Собран фрукт: "..fruitName(obj))
        notify("ФРУКТ СОБРАН",fruitName(obj))
    else
        status("Подлетел, но сервер не подтвердил сбор: "..fruitName(obj))
    end
end
Filter.FocusLost:Connect(function()
    State.Filter=Filter.Text or ""; State.Fruits={}; State.LastAttempt={}; State.HasScanned=false; clearESP()
    status(State.Filter=="" and "Filter cleared." or "Filter: "..State.Filter)
end)
Distance.FocusLost:Connect(function()
    local n=tonumber(Distance.Text)
    if n then CFG.MaxDistance=math.clamp(n,100,1000000); Distance.Text=tostring(CFG.MaxDistance) else Distance.Text=tostring(CFG.MaxDistance) end
end)
Interval.FocusLost:Connect(function()
    local n=tonumber(Interval.Text)
    if n then CFG.ScanInterval=math.clamp(n,.5,10); Interval.Text=tostring(CFG.ScanInterval) else Interval.Text=tostring(CFG.ScanInterval) end
end)
Start.MouseButton1Click:Connect(function()
    State.Running=true; Start.Text="● АВТОСБОР: ВКЛ"; status("Автосбор включён. Ищу фрукты...")
end)
Stop.MouseButton1Click:Connect(function()
    State.Running=false; State.FlightToken=State.FlightToken+1; Start.Text="▶ ЗАПУСТИТЬ СБОР"; status("Автосбор остановлен.")
end)
EspBtn.MouseButton1Click:Connect(function()
    State.ESP=not State.ESP; EspBtn.Text=State.ESP and "ПОДСВЕТКА: ВКЛ" or "ПОДСВЕТКА: ВЫКЛ"
    if not State.ESP then clearESP() else scan() end
end)
NotifyBtn.MouseButton1Click:Connect(function()
    State.Notify=not State.Notify; NotifyBtn.Text=State.Notify and "УВЕДОМЛЕНИЯ: ВКЛ" or "УВЕДОМЛЕНИЯ: ВЫКЛ"
end)
local minimized=false
Min.MouseButton1Click:Connect(function()
    minimized=not minimized
    for _,v in ipairs(Main:GetChildren()) do
        if v~=Bar and not v:IsA("UICorner") and not v:IsA("UIStroke") then v.Visible=not minimized end
    end
    Main.Size=minimized and UDim2.fromOffset(280,42) or UDim2.fromOffset(280,440)
    Min.Text=minimized and "+" or "—"
end)
Close.MouseButton1Click:Connect(function()
    State.Alive=false; State.Running=false; State.FlightToken=State.FlightToken+1; clearESP(); Gui:Destroy()
end)
Gui.Parent=guiParent()
notify("Сборщик фруктов","Загружен. Нажми «ЗАПУСТИТЬ СБОР».")
task.spawn(function()
    local lastScan=0
    while State.Alive and Gui.Parent do
        local now=os.clock()
        if (State.Running or State.ESP) and not State.HasScanned then scan(); lastScan=now end
        if State.Running then
            local obj,d=nearest()
            if obj then status(string.format("Найден %s • %.0f studs",fruitName(obj),d or 0)); attemptPickup(obj)
            else status("Ищу фрукты, появившиеся в мире...") end
        end
        for obj,e in pairs(State.ESPObjects) do
            if not obj or not obj.Parent then removeESP(obj)
            else
                local p=fruitPart(obj)
                if p and e.Billboard then
                    e.Billboard.Adornee=p
                    local r=root()
                    if r then e.Label.Text=string.format("🍈 %s • %dm",fruitName(obj),math.floor((p.Position-r.Position).Magnitude)) end
                end
            end
        end
        local count=0
        for obj in pairs(State.Fruits) do if obj and obj.Parent and obj:IsDescendantOf(Workspace) then count=count+1 end end
        Stats.Text=string.format("Найдено: %d | Попыток: %d | Собрано: %d",count,State.Attempts,State.Pickups)
        updateFruitList()
        task.wait(.5)
    end
    clearESP()
end)
