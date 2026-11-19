--[[
Blox Fruits Auto Fruit Collector v1.0.1
Delta Android / Arceus X
Client-side helper: scans Workspace for spawned fruit models, ESP, notifications,
and makes a best-effort touch pickup attempt. Server pickup is not guaranteed.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local CFG = { ScanInterval = 1.25, MaxDistance = 250000, Cooldown = 10, PickupWait = 0.85, TeleportHeight = 2.5 }
local State = {
    Running = false, ESP = false, Notify = true, Filter = "",
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
    local n = string.lower(obj.Name or "")
    if n:sub(-5) ~= "fruit" then return false end
    if n:find("dealer",1,true) or n:find("shop",1,true) or n:find("vendor",1,true) or n:find("npc",1,true) then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and obj:IsDescendantOf(p.Character) then return false end
    end
    local a = obj.Parent
    while a and a ~= Workspace do
        if (a:IsA("Model") or a:IsA("Tool")) and string.lower(a.Name):sub(-5) == "fruit" then return false end
        a = a.Parent
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
Main.Size = UDim2.fromOffset(310,580)
Main.Position = UDim2.new(.5,-155,.5,-195)
Main.BackgroundColor3 = Color3.fromRGB(13,16,27)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = Gui
Instance.new("UICorner",Main).CornerRadius = UDim.new(0,14)
local stroke = Instance.new("UIStroke",Main)
stroke.Color = Color3.fromRGB(91,103,255)
stroke.Thickness = 1.4
local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(1,0,0,48)
Bar.BackgroundColor3 = Color3.fromRGB(24,29,48)
Bar.BorderSizePixel = 0
Bar.Active = true
Bar.Parent = Main
Instance.new("UICorner",Bar).CornerRadius = UDim.new(0,14)
local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(14,5)
Title.Size = UDim2.new(1,-88,0,22)
Title.Font = Enum.Font.GothamBold
Title.Text = "FRUIT COLLECTOR"
Title.TextColor3 = Color3.fromRGB(239,241,255)
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Bar
local Sub = Instance.new("TextLabel")
Sub.BackgroundTransparency = 1
Sub.Position = UDim2.fromOffset(15,27)
Sub.Size = UDim2.new(1,-90,0,14)
Sub.Font = Enum.Font.Gotham
Sub.Text = "BLOX FRUITS  •  DELTA / ARCEUS"
Sub.TextColor3 = Color3.fromRGB(146,157,190)
Sub.TextSize = 9
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.Parent = Bar
local function button(name, label, pos, size, color)
    local b = Instance.new("TextButton")
    b.Name=name; b.Text=label; b.Position=pos; b.Size=size
    b.BackgroundColor3=color; b.BorderSizePixel=0; b.AutoButtonColor=true
    b.Font=Enum.Font.GothamBold; b.TextSize=12; b.TextColor3=Color3.new(1,1,1)
    b.Parent=Main
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,9)
    return b
end
local function field(name, placeholder, y, value)
    local f=Instance.new("TextBox")
    f.Name=name; f.Position=UDim2.fromOffset(13,y); f.Size=UDim2.new(1,-26,0,31)
    f.BackgroundColor3=Color3.fromRGB(24,30,48); f.BorderSizePixel=0
    f.ClearTextOnFocus=false; f.Font=Enum.Font.Gotham; f.TextSize=11
    f.PlaceholderText=placeholder; f.PlaceholderColor3=Color3.fromRGB(118,130,160)
    f.Text=value or ""; f.TextColor3=Color3.fromRGB(225,231,250)
    f.TextXAlignment=Enum.TextXAlignment.Left; f.Parent=Main
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    local pad=Instance.new("UIPadding",f); pad.PaddingLeft=UDim.new(0,10)
    return f
end
local Status=Instance.new("TextLabel")
Status.Position=UDim2.fromOffset(13,58); Status.Size=UDim2.new(1,-26,0,38)
Status.BackgroundColor3=Color3.fromRGB(22,28,44); Status.BorderSizePixel=0
Status.Font=Enum.Font.Gotham; Status.Text="Ready. Press START to search."
Status.TextColor3=Color3.fromRGB(190,203,235); Status.TextSize=11
Status.TextWrapped=true; Status.TextXAlignment=Enum.TextXAlignment.Left; Status.Parent=Main
Instance.new("UICorner",Status).CornerRadius=UDim.new(0,8)
local function status(s) Status.Text=s end
local Start=button("Start","▶  START AUTO FARM",UDim2.fromOffset(13,107),UDim2.fromOffset(138,37),Color3.fromRGB(46,125,98))
local Stop=button("Stop","■  STOP",UDim2.fromOffset(159,107),UDim2.fromOffset(138,37),Color3.fromRGB(129,55,72))
local EspBtn=button("ESP","ESP: OFF",UDim2.fromOffset(13,153),UDim2.fromOffset(138,34),Color3.fromRGB(48,57,87))
local NotifyBtn=button("Notify","NOTIFY: ON",UDim2.fromOffset(159,153),UDim2.fromOffset(138,34),Color3.fromRGB(48,57,87))
local Filter=field("FruitFilter","Filter by fruit name (blank = all)",199,"")
local Distance=field("MaxDistance","Max distance",238,tostring(CFG.MaxDistance))
local Interval=field("ScanInterval","Scan interval seconds",277,tostring(CFG.ScanInterval))
local Stats=Instance.new("TextLabel")
Stats.Position=UDim2.fromOffset(13,316); Stats.Size=UDim2.new(1,-26,0,25)
Stats.BackgroundTransparency=1; Stats.Font=Enum.Font.Gotham
Stats.Text="Found: 0 | Attempts: 0 | Pickups: 0"
Stats.TextColor3=Color3.fromRGB(153,167,203); Stats.TextSize=10
Stats.TextXAlignment=Enum.TextXAlignment.Left; Stats.Parent=Main
local Footer=Instance.new("TextLabel")
Footer.Position=UDim2.fromOffset(13,348); Footer.Size=UDim2.new(1,-26,0,25)
Footer.BackgroundTransparency=1; Footer.Font=Enum.Font.Gotham
Footer.Text="Client-side pickup attempt • no guarantee"
Footer.TextColor3=Color3.fromRGB(105,119,151); Footer.TextSize=9
Footer.TextXAlignment=Enum.TextXAlignment.Left; Footer.Parent=Main
local Min=button("Minimize","—",UDim2.new(1,-66,0,10),UDim2.fromOffset(28,27),Color3.fromRGB(48,56,85))
Min.Parent=Bar
local Close=button("Close","×",UDim2.new(1,-32,0,10),UDim2.fromOffset(28,27),Color3.fromRGB(130,49,69))
Close.Parent=Bar

-- Live spawned-fruit mini list
local ListPanel = Instance.new("Frame")
ListPanel.Name = "SpawnedFruitList"
ListPanel.Position = UDim2.fromOffset(13,382)
ListPanel.Size = UDim2.new(1,-26,0,184)
ListPanel.BackgroundColor3 = Color3.fromRGB(18,23,39)
ListPanel.BorderSizePixel = 0
ListPanel.Parent = Main
Instance.new("UICorner",ListPanel).CornerRadius = UDim.new(0,10)
local listStroke = Instance.new("UIStroke",ListPanel)
listStroke.Color = Color3.fromRGB(55,72,111)
listStroke.Transparency = .25
local ListTitle = Instance.new("TextLabel")
ListTitle.BackgroundTransparency = 1
ListTitle.Position = UDim2.fromOffset(10,7)
ListTitle.Size = UDim2.new(1,-20,0,20)
ListTitle.Font = Enum.Font.GothamBold
ListTitle.Text = "SPAWNED FRUITS"
ListTitle.TextColor3 = Color3.fromRGB(224,230,255)
ListTitle.TextSize = 11
ListTitle.TextXAlignment = Enum.TextXAlignment.Left
ListTitle.Parent = ListPanel
local ListCount = Instance.new("TextLabel")
ListCount.BackgroundTransparency = 1
ListCount.Position = UDim2.new(1,-48,0,7)
ListCount.Size = UDim2.fromOffset(38,20)
ListCount.Font = Enum.Font.GothamBold
ListCount.Text = "0"
ListCount.TextColor3 = Color3.fromRGB(112,224,190)
ListCount.TextSize = 11
ListCount.TextXAlignment = Enum.TextXAlignment.Right
ListCount.Parent = ListPanel
local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Name = "FruitRows"
ListScroll.Position = UDim2.fromOffset(7,32)
ListScroll.Size = UDim2.new(1,-14,1,-39)
ListScroll.BackgroundTransparency = 1
ListScroll.BorderSizePixel = 0
ListScroll.ScrollBarThickness = 3
ListScroll.ScrollBarImageColor3 = Color3.fromRGB(105,123,190)
ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ListScroll.Parent = ListPanel
local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0,5)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ListScroll
local EmptyList = Instance.new("TextLabel")
EmptyList.Name = "EmptyHint"
EmptyList.Size = UDim2.new(1,-8,0,48)
EmptyList.BackgroundTransparency = 1
EmptyList.Font = Enum.Font.Gotham
EmptyList.Text = "No fruits detected yet.\nTurn on ESP or Auto Farm to scan."
EmptyList.TextColor3 = Color3.fromRGB(119,132,166)
EmptyList.TextSize = 10
EmptyList.TextWrapped = true
EmptyList.Parent = ListScroll

-- Touch/mouse drag support
do
    local dragging, input, startPos, framePos
    Bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; input=i; startPos=i.Position; framePos=Main.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-startPos
            Main.Position=UDim2.new(framePos.X.Scale,framePos.X.Offset+d.X,framePos.Y.Scale,framePos.Y.Offset+d.Y)
        end
    end)
end
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
        row.FruitState.Text = waiting and "FOUND • CHECKING" or "AVAILABLE TO COLLECT"
        row.Dot.BackgroundColor3 = waiting and Color3.fromRGB(255,190,95) or Color3.fromRGB(104,229,184)
    end
    for obj in pairs(State.ListRows) do
        if not present[obj] then removeListRow(obj) end
    end
    ListCount.Text = tostring(#entries)
    EmptyList.Visible = #entries == 0
end
local function scan()
    local found={}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if isFruit(obj) then
            local n=string.lower(obj.Name)
            if State.Filter=="" or n:find(string.lower(State.Filter),1,true) or string.lower(fruitName(obj)):find(string.lower(State.Filter),1,true) then
                found[obj]=true
                if not State.Fruits[obj] then
                    State.Fruits[obj]=true
                    notify("FRUIT SPAWNED",fruitName(obj))
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
    updateFruitList()
    return found
end
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
local function attemptPickup(obj)
    local r=root(); local p=obj and fruitPart(obj)
    if not r or not p then return end
    State.LastAttempt[obj]=os.clock(); State.Attempts=State.Attempts+1
    local pos=p.Position+Vector3.new(0,CFG.TeleportHeight,0)
    local ok=pcall(function()
        r.CFrame=CFrame.new(pos)
        r.AssemblyLinearVelocity=Vector3.zero
        r.AssemblyAngularVelocity=Vector3.zero
    end)
    if not ok then status("Teleport failed; check character state."); return end
    status("At "..fruitName(obj).."; trying pickup...")
    local touch=rawget(getgenv and getgenv() or _G,"firetouchinterest")
    if type(touch)=="function" then
        pcall(function() touch(r,p,0); task.wait(.12); touch(r,p,1) end)
    end
    task.wait(CFG.PickupWait)
    if not obj.Parent or not obj:IsDescendantOf(Workspace) then
        State.Pickups=State.Pickups+1; State.Fruits[obj]=nil; removeESP(obj)
        status("Picked up: "..fruitName(obj)); notify("FRUIT COLLECTED",fruitName(obj))
    else
        status("Pickup not confirmed: "..fruitName(obj))
    end
end
Filter.FocusLost:Connect(function()
    State.Filter=Filter.Text or ""; State.Fruits={}; State.LastAttempt={}; clearESP()
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
    State.Running=true; Start.Text="● AUTO FARM: ON"; status("Auto farm enabled. Scanning...")
end)
Stop.MouseButton1Click:Connect(function()
    State.Running=false; Start.Text="▶ START AUTO FARM"; status("Auto farm stopped.")
end)
EspBtn.MouseButton1Click:Connect(function()
    State.ESP=not State.ESP; EspBtn.Text=State.ESP and "ESP: ON" or "ESP: OFF"
    if not State.ESP then clearESP() else scan() end
end)
NotifyBtn.MouseButton1Click:Connect(function()
    State.Notify=not State.Notify; NotifyBtn.Text=State.Notify and "NOTIFY: ON" or "NOTIFY: OFF"
end)
local minimized=false
Min.MouseButton1Click:Connect(function()
    minimized=not minimized
    for _,v in ipairs(Main:GetChildren()) do
        if v~=Bar and not v:IsA("UICorner") and not v:IsA("UIStroke") then v.Visible=not minimized end
    end
    Main.Size=minimized and UDim2.fromOffset(310,48) or UDim2.fromOffset(310,580)
    Min.Text=minimized and "+" or "—"
end)
Close.MouseButton1Click:Connect(function()
    State.Alive=false; State.Running=false; clearESP(); Gui:Destroy()
end)
Gui.Parent=guiParent()
notify("Fruit Collector","Loaded. Press START AUTO FARM.")
task.spawn(function()
    local lastScan=0
    while State.Alive and Gui.Parent do
        local now=os.clock()
        if (State.Running or State.ESP) and now-lastScan>=CFG.ScanInterval then scan(); lastScan=now end
        if State.Running then
            local obj,d=nearest()
            if obj then status(string.format("Found %s • %.0fm",fruitName(obj),d or 0)); attemptPickup(obj)
            else status("Searching for world-spawned fruits...") end
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
        Stats.Text=string.format("Found: %d | Attempts: %d | Pickups: %d",count,State.Attempts,State.Pickups)
        updateFruitList()
        task.wait(.5)
    end
    clearESP()
end)
