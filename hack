-----------------------------------------------------------
-- [MOBILE / DELTA COMPAT]
-----------------------------------------------------------
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
-- UI sizes (mobile vs desktop)
local UI_W = isMobile and 340 or 525
local UI_H = isMobile and 480 or 631
local UI_COL_W = isMobile and 158 or 245
local UI_COL2_X = isMobile and 168 or 255
local UI_TAB_H = isMobile and 30 or 26
local UI_TOGGLE_H = isMobile and 28 or 22
local UI_BTN_H = isMobile and 28 or 22
local UI_TEXT = isMobile and 12 or 14
local UI_SMALL = isMobile and 11 or 13

-- common executor shims (Delta / mobile)
pcall(function()
    if typeof(setthreadidentity) ~= "function" and typeof(set_thread_identity) == "function" then
        setthreadidentity = set_thread_identity
    end
end)
setthreadidentity = setthreadidentity or set_thread_identity or function() end
pcall(function() setthreadidentity(8) end)

if typeof(firesignal) ~= "function" then
    firesignal = function(sig, ...)
        if typeof(sig) == "RBXScriptSignal" then
            -- best-effort; many mobile executors lack firesignal
            return
        end
    end
end
if typeof(newcclosure) ~= "function" then
    newcclosure = function(f) return f end
end
if typeof(checkcaller) ~= "function" then
    checkcaller = function() return true end
end
if typeof(getnamecallmethod) ~= "function" then
    getnamecallmethod = function() return "" end
end
if typeof(hookmetamethod) ~= "function" then
    hookmetamethod = function() return function() end end
end
if typeof(cloneref) ~= "function" then
    cloneref = function(x) return x end
end

local function getSafeGuiParent()
    -- Delta mobile often blocks CoreGui; try CoreGui -> PlayerGui
    local ok, cg = pcall(function()
        return cloneref(game:GetService("CoreGui"))
    end)
    if ok and cg then
        local test = Instance.new("Folder")
        local parentOk = pcall(function() test.Parent = cg end)
        if parentOk and test.Parent == cg then
            test:Destroy()
            return cg
        end
        pcall(function() test:Destroy() end)
    end
    local pg = LocalPlayer and (LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5))
    return pg or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local SAFE_GUI_PARENT = getSafeGuiParent()

local nexlib = {accentclr = Color3.fromRGB(255, 255, 255), dropdownframes = {}, colorpickerframes = {}}

local mouseInputs = {[Enum.UserInputType.MouseButton1]='M1',[Enum.UserInputType.MouseButton2]='M2',[Enum.UserInputType.MouseButton3]='M3'}
local ignoredKeys = {Enum.KeyCode.Unknown,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Up,Enum.KeyCode.Left,Enum.KeyCode.Down,Enum.KeyCode.Right,Enum.KeyCode.Slash,Enum.KeyCode.Tab,Enum.KeyCode.Backspace,Enum.KeyCode.Escape,Enum.KeyCode.RightShift}

local function tableContains(tbl, val)
    for k, v in next, tbl do if v == val or k == val then return true end end 
end;

local function makeDraggable(clickObject, dragObject)
    pcall(function()
        local dragging = false;
        local dragInput, dragStart, startPos;
        clickObject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
                dragging = true;
                dragStart = input.Position;
                startPos = dragObject.Position;
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end 
                end)
            end 
        end)
        clickObject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end 
        end)
        UIS.InputChanged:Connect(function(input)
            if input == dragInput and dragging then 
                local delta = input.Position - dragStart;
                dragObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end 
        end)
    end)
end;

local screenGui = Instance.new('ScreenGui')
screenGui.Name = 'nexlib'
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() screenGui.Parent = SAFE_GUI_PARENT end)
if not screenGui.Parent then
    pcall(function()
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end)
end

local cursorGui = Instance.new('ScreenGui')
cursorGui.Name = 'CustomCursorGui'
cursorGui.ResetOnSpawn = false
cursorGui.Parent = screenGui

local customCursor = Instance.new('Frame')
customCursor.Name = 'CursorBox'
customCursor.Size = UDim2.new(0, 6, 0, 6)
customCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
customCursor.BorderSizePixel = 0
customCursor.Visible = false
customCursor.Parent = cursorGui

local notifFolder = Instance.new('Folder')
notifFolder.Name = 'NotificationFolder'
notifFolder.Parent = screenGui;

local activeNotifs = {}
local NOTIF_HEIGHT = 22
local NOTIF_GAP = 6
local NOTIF_MAX = 8
local NOTIF_DURATION = 3
local NOTIF_TOP_OFFSET = 40

local function updateNotifPositions()
    local tweenService = game:GetService("TweenService")
    for i, data in ipairs(activeNotifs) do
        if data.bar and data.bar.Parent then
            local yOffset = NOTIF_TOP_OFFSET + (i - 1) * (NOTIF_HEIGHT + NOTIF_GAP)
            tweenService:Create(data.bar, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0, yOffset)
            }):Play()
        end
    end
end

function nexlib:Notification(title, desc, duration)
    duration = duration or NOTIF_DURATION
    local msg = tostring(title or "")
    if desc and desc ~= "" then
        msg = msg .. "  ·  " .. tostring(desc)
    end

    local tweenService = game:GetService("TweenService")

    while #activeNotifs >= NOTIF_MAX do
        local oldest = table.remove(activeNotifs)
        if oldest and oldest.bar and oldest.bar.Parent then
            local fadeOut = tweenService:Create(oldest.label, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1
            })
            local collapse = tweenService:Create(oldest.bar, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, NOTIF_HEIGHT),
                BackgroundTransparency = 1
            })
            local strokeFade = tweenService:Create(oldest.stroke, TweenInfo.new(0.2), { Transparency = 1 })
            fadeOut:Play()
            collapse:Play()
            strokeFade:Play()
            collapse.Completed:Connect(function()
                pcall(function() if oldest.bar then oldest.bar:Destroy() end end)
                updateNotifPositions()
            end)
        end
    end

    local bar = Instance.new("Frame")
    bar.Name = "Notification"
    bar.Parent = notifFolder
    bar.AnchorPoint = Vector2.new(0.5, 0)
    bar.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
    bar.BorderSizePixel = 0
    bar.Position = UDim2.new(0.5, 0, 0, NOTIF_TOP_OFFSET)
    bar.Size = UDim2.new(0, 0, 0, NOTIF_HEIGHT)
    bar.ClipsDescendants = true
    bar.BackgroundTransparency = 0.05
    bar.ZIndex = 100

    local stroke = Instance.new("UIStroke")
    stroke.Parent = bar
    stroke.Color = nexlib.accentclr
    stroke.Thickness = 1.5
    stroke.Transparency = 0.25

    local accent = Instance.new("Frame")
    accent.Name = "AccentLine"
    accent.Parent = bar
    accent.BackgroundColor3 = nexlib.accentclr
    accent.BorderSizePixel = 0
    accent.Size = UDim2.new(0, 3, 1, 0)
    accent.Position = UDim2.new(0, 0, 0, 0)

    local label = Instance.new("TextLabel")
    label.Parent = bar
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 14, 0, 0)
    label.Size = UDim2.new(1, -28, 1, 0)
    label.Font = Enum.Font.Code
    label.Text = msg
    label.TextColor3 = Color3.fromRGB(230, 230, 230)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextTransparency = 1
    label.TextTruncate = Enum.TextTruncate.None

    local textService = game:GetService("TextService")
    local bounds = textService:GetTextSize(msg, 13, Enum.Font.Code, Vector2.new(2000, NOTIF_HEIGHT))
    local targetW = math.clamp(bounds.X + 48, 200, 480)

    table.insert(activeNotifs, 1, {
        bar = bar,
        label = label,
        stroke = stroke
    })

    updateNotifPositions()

    local expand = tweenService:Create(bar, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, targetW, 0, NOTIF_HEIGHT)
    })
    local fadeIn = tweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 0
    })
    expand:Play()
    task.delay(0.08, function() fadeIn:Play() end)

    task.delay(duration, function()
        for i, data in ipairs(activeNotifs) do
            if data.bar == bar then
                table.remove(activeNotifs, i)
                break
            end
        end

        if not bar or not bar.Parent then
            updateNotifPositions()
            return
        end

        local fadeOut = tweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1
        })
        local collapse = tweenService:Create(bar, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, NOTIF_HEIGHT),
            BackgroundTransparency = 1
        })
        local strokeFade = tweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 1 })
        fadeOut:Play()
        collapse:Play()
        strokeFade:Play()
        collapse.Completed:Connect(function()
            pcall(function() bar:Destroy() end)
            updateNotifPositions()
        end)
    end)
end;

function nexlib:Window(windowTitle)
    local isVisible = true;
    local hasTabs = false;
    local allTabs = {} 
    
    local mainFrame = Instance.new('Frame')
    local S = Instance.new('ImageLabel')
    local T = Instance.new('ImageLabel')
    local containerHolder = Instance.new('Frame')
    local tabHolder = Instance.new('ScrollingFrame')
    local tabLayout = Instance.new('UIListLayout')
    local tabPadding = Instance.new('UIPadding')
    local topBar = Instance.new('Frame')
    local topBarTitle = Instance.new('TextLabel')
    local topBarLine = Instance.new('Frame')
    
    mainFrame.Name = 'MainFrame'
    mainFrame.Parent = screenGui;
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mainFrame.BackgroundTransparency = 0.15 
    mainFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    mainFrame.BorderSizePixel = 0;
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.Size = UDim2.new(0, UI_W, 0, UI_H)
    mainFrame.Visible = false
    mainFrame.ClipsDescendants = true
    
    S.Name = 'OutlineMainFrame1'
    S.Parent = mainFrame; S.BackgroundTransparency = 1; S.Position = UDim2.new(0, 1, 0, 1)
    S.Size = UDim2.new(1, -2, 1, -2) S.Image = 'rbxassetid://2592362371'
    S.ImageColor3 = Color3.fromRGB(60, 60, 60) S.ScaleType = Enum.ScaleType.Slice; S.SliceCenter = Rect.new(2, 2, 62, 62)
    
    T.Name = 'OutlineMainFrame2'
    T.Parent = mainFrame; T.BackgroundTransparency = 1; T.Size = UDim2.new(1, 0, 1, 0)
    T.Image = 'rbxassetid://2592362371' T.ImageColor3 = Color3.fromRGB(0, 0, 0)
    T.ScaleType = Enum.ScaleType.Slice; T.SliceCenter = Rect.new(2, 2, 62, 62)
    
    containerHolder.Name = 'ContainerHolderFrame'
    containerHolder.Parent = mainFrame; containerHolder.AnchorPoint = Vector2.new(0.5, 0)
    containerHolder.BackgroundColor3 = Color3.fromRGB(24, 24, 24) containerHolder.Position = UDim2.new(0.5, 0, 0.071, 10)
    containerHolder.Size = UDim2.new(1, -18, 1, -42)
    containerHolder.BackgroundTransparency = 1
    containerHolder.ClipsDescendants = true
    
    tabHolder.Name = 'TabHolderFrame'
    tabHolder.Parent = containerHolder; tabHolder.BackgroundTransparency = 1;
    tabHolder.Size = UDim2.new(1, 0, 0, 32) tabHolder.Visible = true;
    tabHolder.CanvasSize = UDim2.new(0, 700, 0, 0)
    tabHolder.ScrollBarThickness = 0;
    
    tabLayout.Name = 'TabHolderFrameLayout'
    tabLayout.Parent = tabHolder; tabLayout.FillDirection = Enum.FillDirection.Horizontal;
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder; tabLayout.Padding = UDim.new(0, 4)
    
    tabPadding.Name = 'TabHolderFramePadding'
    tabPadding.Parent = tabHolder; tabPadding.PaddingLeft = UDim.new(0, 5)
    
    topBar.Name = 'TopBar'
    topBar.Parent = mainFrame; topBar.AnchorPoint = Vector2.new(0.5, 0)
    topBar.BackgroundColor3 = Color3.fromRGB(24, 24, 24) topBar.BorderSizePixel = 0;
    topBar.Position = UDim2.new(0.5, 0, 0, 2) topBar.Size = UDim2.new(1, -5, 0, 28)
    
    topBarTitle.Name = 'TopBarTitle'
    topBarTitle.Parent = topBar; topBarTitle.BackgroundTransparency = 1;
    topBarTitle.Position = UDim2.new(0, 7, 0, 5) topBarTitle.Size = UDim2.new(0, 0, 0, 16)
    topBarTitle.Font = Enum.Font.Code; topBarTitle.Text = windowTitle;
    topBarTitle.TextColor3 = Color3.fromRGB(230, 230, 230) topBarTitle.TextSize = isMobile and 14 or 16; topBarTitle.TextXAlignment = Enum.TextXAlignment.Left;
    
    topBarLine.Name = 'TopBarLine'
    topBarLine.Parent = topBar; topBarLine.BackgroundColor3 = nexlib.accentclr;
    topBarLine.BorderSizePixel = 0; topBarLine.Position = UDim2.new(0, 0, 0, 27) topBarLine.Size = UDim2.new(1, 0, 0, 1)
    
    makeDraggable(topBar, mainFrame)

    local lighting = game:GetService("Lighting")
    local blurEffect = lighting:FindFirstChild("ValkUIBlur") or Instance.new("BlurEffect")
    blurEffect.Name = "ValkUIBlur"
    blurEffect.Size = 0
    blurEffect.Parent = lighting

    local function updateUIState()
        mainFrame.Visible = isVisible
        -- custom cursor only on desktop
        customCursor.Visible = isVisible and not isMobile
        pcall(function()
            if not isMobile then
                UIS.MouseBehavior = isVisible and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
            end
        end)
        
        local tweenService = game:GetService("TweenService")
        if isVisible then
            pcall(function()
                tweenService:Create(blurEffect, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = isMobile and 0 or 18}):Play()
            end)
            mainFrame.BackgroundTransparency = 1
            tweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.15}):Play()
        else
            pcall(function()
                tweenService:Create(blurEffect, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
            end)
        end
    end
    
    UIS.InputBegan:Connect(function(input, processed)
        if input.KeyCode == Enum.KeyCode.RightShift then 
            isVisible = not isVisible;
            updateUIState()
        end 
    end)

    pcall(function()
        local old = SAFE_GUI_PARENT:FindFirstChild("ExecutorToggleUI")
        if old then old:Destroy() end
    end)

    local toggleScreenGui = Instance.new("ScreenGui")
    toggleScreenGui.Name = "ExecutorToggleUI"
    toggleScreenGui.ResetOnSpawn = false
    toggleScreenGui.IgnoreGuiInset = true
    toggleScreenGui.DisplayOrder = 1000
    pcall(function() toggleScreenGui.Parent = SAFE_GUI_PARENT end)
    if not toggleScreenGui.Parent then
        pcall(function() toggleScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
    end

    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleFrame"
    toggleButton.Size = UDim2.new(0, isMobile and 80 or 65, 0, isMobile and 44 or 36)
    toggleButton.Position = UDim2.new(0, isMobile and 12 or 20, 0, isMobile and 12 or 20)
    toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleButton.BorderSizePixel = 0
    toggleButton.Active = true
    toggleButton.Draggable = true
    toggleButton.Parent = toggleScreenGui

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = nexlib.accentclr 
    uiStroke.Thickness = 2
    uiStroke.Parent = toggleButton

    local textToggle = Instance.new("TextLabel")
    textToggle.Size = UDim2.new(1, -6, 0, 16)
    textToggle.Position = UDim2.new(0, 3, 0, 2)
    textToggle.BackgroundTransparency = 1
    textToggle.Text = "Toggle"
    textToggle.TextColor3 = Color3.fromRGB(230, 230, 230)
    textToggle.TextSize = 12
    textToggle.Font = Enum.Font.GothamBold
    textToggle.TextXAlignment = Enum.TextXAlignment.Left
    textToggle.Parent = toggleButton

    local textLook = Instance.new("TextLabel")
    textLook.Size = UDim2.new(1, -6, 0, 16)
    textLook.Position = UDim2.new(0, 3, 0, 18)
    textLook.BackgroundTransparency = 1
    textLook.Text = "Look"
    textLook.TextColor3 = Color3.fromRGB(230, 230, 230)
    textLook.TextSize = 12
    textLook.Font = Enum.Font.GothamBold
    textLook.TextXAlignment = Enum.TextXAlignment.Left
    textLook.Parent = toggleButton

    toggleButton.MouseButton1Click:Connect(function()
        isVisible = not isVisible
        updateUIState()
    end)
    
    coroutine.wrap(function()
        while task.wait() do 
            topBarLine.BackgroundColor3 = nexlib.accentclr 
            uiStroke.Color = nexlib.accentclr 
            customCursor.BackgroundColor3 = nexlib.accentclr
            
            if isVisible then
                local mouseLocation = game:GetService("UserInputService"):GetMouseLocation()
                customCursor.Position = UDim2.new(0, mouseLocation.X, 0, mouseLocation.Y)
            end
        end 
    end)()

    local windowFunctions = {}
    
    function windowFunctions:Tab(tabName)
        local sectionZIndex = 50;
        
        local tabBtn = Instance.new('TextButton')
        tabBtn.Name = tabName .. "_TabBtn"
        tabBtn.Parent = tabHolder
        tabBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        tabBtn.BorderSizePixel = 0
        tabBtn.Font = Enum.Font.Code
        tabBtn.Text = tabName
        tabBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        tabBtn.TextSize = UI_TEXT
        tabBtn.AutoButtonColor = false
        
        local textBoundsService = game:GetService("TextService")
        local calculatedSize = textBoundsService:GetTextSize(tabName, UI_TEXT, Enum.Font.Code, Vector2.new(500, 500))
        tabBtn.Size = UDim2.new(0, calculatedSize.X + (isMobile and 22 or 28), 0, UI_TAB_H)
        tabBtn.TextSize = UI_TEXT
        
        local tabTopLine = Instance.new('Frame')
        tabTopLine.Name = "TopLine"
        tabTopLine.Parent = tabBtn
        tabTopLine.BackgroundColor3 = nexlib.accentclr
        tabTopLine.BorderSizePixel = 0
        tabTopLine.Position = UDim2.new(0, 0, 0, 0)
        tabTopLine.Size = UDim2.new(1, 0, 0, 2)
        tabTopLine.Visible = true
        
        local tabOutline = Instance.new('ImageLabel')
        tabOutline.Name = "Outline"
        tabOutline.Parent = tabBtn
        tabOutline.BackgroundTransparency = 1
        tabOutline.Size = UDim2.new(1, 0, 1, 0)
        tabOutline.Image = 'rbxassetid://2592362371'
        tabOutline.ImageColor3 = Color3.fromRGB(45, 45, 45)
        tabOutline.ScaleType = Enum.ScaleType.Slice
        tabOutline.SliceCenter = Rect.new(2, 2, 62, 62)
        
        local sectionHolder1 = Instance.new('ScrollingFrame')
        local shPadding1 = Instance.new('UIPadding')
        local shLayout1 = Instance.new('UIListLayout')
        local sectionHolder2 = Instance.new('ScrollingFrame')
        local shPadding2 = Instance.new('UIPadding')
        local shLayout2 = Instance.new('UIListLayout')
        
        sectionHolder1.Name = tabName .. '_Holder1'
        sectionHolder1.Parent = containerHolder;
        sectionHolder1.Active = true; sectionHolder1.BackgroundTransparency = 1; sectionHolder1.BorderSizePixel = 0;
        sectionHolder1.Position = UDim2.new(0, 1, 0, isMobile and 32 or 35)
        sectionHolder1.Size = UDim2.new(0, UI_COL_W, 1, isMobile and -36 or -40)
        sectionHolder1.Visible = false; sectionHolder1.CanvasSize = UDim2.new(0, 0, 0, 0)
        sectionHolder1.ScrollBarThickness = isMobile and 6 or 4; sectionHolder1.ScrollingEnabled = true;
        
        shPadding1.Parent = sectionHolder1; shPadding1.PaddingTop = UDim.new(0, 5)
        shLayout1.Parent = sectionHolder1; shLayout1.SortOrder = Enum.SortOrder.LayoutOrder; shLayout1.Padding = UDim.new(0, isMobile and 8 or 10)
        
        sectionHolder2.Name = tabName .. '_Holder2'
        sectionHolder2.Parent = containerHolder;
        sectionHolder2.Active = true; sectionHolder2.BackgroundTransparency = 1; sectionHolder2.BorderSizePixel = 0;
        sectionHolder2.Position = UDim2.new(0, UI_COL2_X, 0, isMobile and 32 or 35)
        sectionHolder2.Size = UDim2.new(0, UI_COL_W, 1, isMobile and -36 or -40)
        sectionHolder2.Visible = false; sectionHolder2.CanvasSize = UDim2.new(0, 0, 0, 0)
        sectionHolder2.ScrollBarThickness = isMobile and 6 or 4; sectionHolder2.ScrollingEnabled = true;
        
        shPadding2.Parent = sectionHolder2; shPadding2.PaddingTop = UDim.new(0, 5)
        shLayout2.Parent = sectionHolder2; shLayout2.SortOrder = Enum.SortOrder.LayoutOrder; shLayout2.Padding = UDim.new(0, 10)
        
        table.insert(allTabs, {btn = tabBtn, topLine = tabTopLine, outline = tabOutline, h1 = sectionHolder1, h2 = sectionHolder2})
        
        if hasTabs == false then 
            hasTabs = true;
            sectionHolder1.Visible = true;
            sectionHolder2.Visible = true;
            tabBtn.BackgroundColor3 = Color3.fromRGB(33, 33, 33)
            tabBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
            tabTopLine.Visible = true
            tabOutline.ImageColor3 = Color3.fromRGB(65, 65, 65)
        end;
        
        tabBtn.MouseButton1Click:Connect(function()
            local ts = game:GetService('TweenService')
            for _, t in ipairs(allTabs) do
                if t.btn == tabBtn then
                    ts:Create(t.btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(33, 33, 33), TextColor3 = Color3.fromRGB(230, 230, 230)}):Play()
                    t.topLine.Visible = true
                    t.outline.ImageColor3 = Color3.fromRGB(65, 65, 65)
                    t.h1.Visible = true
                    t.h2.Visible = true
                else
                    ts:Create(t.btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(22, 22, 22), TextColor3 = Color3.fromRGB(150, 150, 150)}):Play()
                    t.topLine.Visible = true
                    t.outline.ImageColor3 = Color3.fromRGB(45, 45, 45)
                    t.h1.Visible = false
                    t.h2.Visible = false
                end
            end
        end)
        
        coroutine.wrap(function()
            while task.wait() do 
                tabTopLine.Visible = true
                tabTopLine.BackgroundColor3 = nexlib.accentclr 
            end 
        end)()
        
        local tabFunctions = {}
        
        function tabFunctions:Section(sectionName, forceSide)
            sectionZIndex = sectionZIndex - 1;
            local targetHolder = nil;
            
            if forceSide == 1 then targetHolder = sectionHolder1
            elseif forceSide == 2 then targetHolder = sectionHolder2
            else
                local count1 = 0; local count2 = 0;
                for s, f in next, sectionHolder1:GetChildren() do if f.Name == 'Section' or f.Name == 'MultiSection' then count1 = count1 + 1 end end;
                for s, f in next, sectionHolder2:GetChildren() do if f.Name == 'Section' or f.Name == 'MultiSection' then count2 = count2 + 1 end end;
                if count1 == 0 and count2 == 0 then targetHolder = sectionHolder1 
                elseif count1 == count2 then targetHolder = sectionHolder1 
                else targetHolder = sectionHolder2 end;
            end
            
            local sectionFrame = Instance.new('Frame')
            local ag = Instance.new('ImageLabel')
            local ah = Instance.new('ImageLabel')
            local titleFrame = Instance.new('Frame')
            local titleLabel = Instance.new('TextLabel')
            local itemHolder = Instance.new('Frame')
            local itemLayout = Instance.new('UIListLayout')
            
            sectionFrame.Name = 'Section'
            sectionFrame.Parent = targetHolder;
            sectionFrame.AnchorPoint = Vector2.new(0.5, 0)
            sectionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            sectionFrame.BorderSizePixel = 0;
            sectionFrame.Size = UDim2.new(1, -2, 0, 24)
            sectionFrame.ZIndex = sectionZIndex;
            
            ag.Name = 'SectionOutline2'
            ag.Parent = sectionFrame; ag.BackgroundTransparency = 1; ag.Size = UDim2.new(1, 0, 1, 0)
            ag.Image = 'rbxassetid://2592362371' ag.ImageColor3 = Color3.fromRGB(0, 0, 0)
            ag.ScaleType = Enum.ScaleType.Slice; ag.SliceCenter = Rect.new(2, 2, 62, 62)
            
            ah.Name = 'SectionOutline1'
            ah.Parent = sectionFrame; ah.BackgroundTransparency = 1; ah.Position = UDim2.new(0, 1, 0, 1)
            ah.Size = UDim2.new(1, -2, 1, -2) ah.Image = 'rbxassetid://2592362371'
            ah.ImageColor3 = Color3.fromRGB(60, 60, 60) ah.ScaleType = Enum.ScaleType.Slice; ah.SliceCenter = Rect.new(2, 2, 62, 62)
            
            titleFrame.Name = 'SectionTitleFrame'
            titleFrame.Parent = sectionFrame; titleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            titleFrame.BorderSizePixel = 0; titleFrame.Position = UDim2.new(0, 10, 0, 0)
            
            titleLabel.Name = 'SectionTitle'
            titleLabel.Parent = titleFrame; titleLabel.BackgroundTransparency = 1; titleLabel.Position = UDim2.new(0, 0, 0, -3)
            titleLabel.Size = UDim2.new(1, 0, 0, 7) titleLabel.Font = Enum.Font.Code; titleLabel.Text = sectionName;
            titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230) titleLabel.TextSize = UI_TEXT;
            
            itemHolder.Name = 'SectionItemHolderFrame'
            itemHolder.Parent = sectionFrame; itemHolder.AnchorPoint = Vector2.new(0.5, 0)
            itemHolder.BackgroundTransparency = 1; itemHolder.Position = UDim2.new(0.5, 0, 0, 15)
            itemHolder.Size = UDim2.new(1, -16, 0, 0)
            
            itemLayout.Parent = itemHolder; itemLayout.SortOrder = Enum.SortOrder.LayoutOrder; itemLayout.Padding = UDim.new(0, 5)
            titleFrame.Size = UDim2.new(0, titleLabel.TextBounds.X + 6, 0, 7)
            
            local function updateSectionSize()
                sectionFrame.Size = UDim2.new(1, -2, 0, itemLayout.AbsoluteContentSize.Y + 24)
                sectionHolder1.CanvasSize = UDim2.new(0, 0, 0, shLayout1.AbsoluteContentSize.Y + 20)
                sectionHolder2.CanvasSize = UDim2.new(0, 0, 0, shLayout2.AbsoluteContentSize.Y + 20)
            end

            local sectionFunctions = {}
            
            function sectionFunctions:Toggle(text, default, callback)
                local tBtn = Instance.new('TextButton')
                local tOutline1 = Instance.new('ImageLabel')
                local tOutline2 = Instance.new('ImageLabel')
                local tBox = Instance.new('Frame')
                local tCheck = Instance.new('Frame')
                local tText = Instance.new('TextLabel')
                
                tBtn.Name = 'Toggle'
                tBtn.Parent = itemHolder
                tBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
                tBtn.BorderSizePixel = 0
                tBtn.Size = UDim2.new(1, 0, 0, UI_TOGGLE_H)
                tBtn.AutoButtonColor = false
                tBtn.Text = ''
                
                tOutline1.Parent = tBtn; tOutline1.BackgroundTransparency = 1; tOutline1.Size = UDim2.new(1, 0, 1, 0)
                tOutline1.Image = 'rbxassetid://2592362371' tOutline1.ImageColor3 = Color3.fromRGB(60, 60, 60)
                tOutline1.ScaleType = Enum.ScaleType.Slice; tOutline1.SliceCenter = Rect.new(2, 2, 62, 62)
                
                tOutline2.Parent = tBtn; tOutline2.BackgroundTransparency = 1; tOutline2.Position = UDim2.new(0, 1, 0, 1)
                tOutline2.Size = UDim2.new(1, -2, 1, -2) tOutline2.Image = 'rbxassetid://2592362371'
                tOutline2.ImageColor3 = Color3.fromRGB(0, 0, 0) tOutline2.ScaleType = Enum.ScaleType.Slice; tOutline2.SliceCenter = Rect.new(2, 2, 62, 62)
                
                tBox.Name = 'Box'
                tBox.Parent = tBtn
                tBox.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
                tBox.BorderSizePixel = 0
                tBox.Position = UDim2.new(0, 6, 0.5, -6)
                tBox.Size = UDim2.new(0, 12, 0, 12)
                
                tCheck.Name = 'Check'
                tCheck.Parent = tBox
                tCheck.BackgroundColor3 = nexlib.accentclr
                tCheck.BorderSizePixel = 0
                tCheck.Position = UDim2.new(0, 2, 0, 2)
                tCheck.Size = UDim2.new(0, 8, 0, 8)
                tCheck.Visible = default or false
                
                tText.Parent = tBtn
                tText.BackgroundTransparency = 1
                tText.Position = UDim2.new(0, 25, 0, 0)
                tText.Size = UDim2.new(1, -25, 1, 0)
                tText.Font = Enum.Font.Code
                tText.Text = text
                tText.TextColor3 = Color3.fromRGB(190, 190, 190)
                tText.TextSize = UI_TEXT
                tText.TextXAlignment = Enum.TextXAlignment.Left
                
                local toggled = default or false
                tBtn.MouseButton1Click:Connect(function()
                    toggled = not toggled
                    tCheck.Visible = toggled
                    pcall(callback, toggled)
                end)
                
                updateSectionSize()
                coroutine.wrap(function()
                    while task.wait() do tCheck.BackgroundColor3 = nexlib.accentclr end
                end)()

                local toggleFuncs = {}
                function toggleFuncs:Set(val)
                    toggled = val
                    tCheck.Visible = toggled
                    pcall(callback, toggled)
                end
                return toggleFuncs
            end

            function sectionFunctions:Button(text, callback)
                local btn = Instance.new('TextButton')
                local ao = Instance.new('ImageLabel')
                local ap = Instance.new('ImageLabel')
                
                btn.Name = 'Button'
                btn.Parent = itemHolder;
                btn.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
                btn.BorderColor3 = nexlib.accentclr;
                btn.BorderSizePixel = 0;
                btn.Size = UDim2.new(1, 0, 0, UI_BTN_H)
                btn.AutoButtonColor = false; btn.Font = Enum.Font.Code;
                btn.TextColor3 = Color3.fromRGB(230, 230, 230)
                btn.TextSize = UI_TEXT; btn.Text = text;
                
                ao.Name = 'ButtonOutline1'
                ao.Parent = btn; ao.BackgroundTransparency = 1; ao.Size = UDim2.new(1, 0, 1, 0)
                ao.Image = 'rbxassetid://2592362371' ao.ImageColor3 = Color3.fromRGB(60, 60, 60)
                ao.ScaleType = Enum.ScaleType.Slice; ao.SliceCenter = Rect.new(2, 2, 62, 62)
                
                ap.Name = 'ButtonOutline2'
                ap.Parent = btn; ap.BackgroundTransparency = 1; ap.Position = UDim2.new(0, 1, 0, 1)
                ap.Size = UDim2.new(1, -2, 1, -2) ap.Image = 'rbxassetid://2592362371'
                ap.ImageColor3 = Color3.fromRGB(0, 0, 0) ap.ScaleType = Enum.ScaleType.Slice; ap.SliceCenter = Rect.new(2, 2, 62, 62)
                
                btn.MouseButton1Click:Connect(function() pcall(callback) end)
                btn.MouseEnter:Connect(function() btn.BorderSizePixel = 1 end)
                btn.MouseLeave:Connect(function() btn.BorderSizePixel = 0 end)
                
                updateSectionSize()
                coroutine.wrap(function()
                    while task.wait() do btn.BorderColor3 = nexlib.accentclr end 
                end)()
            end;
            
            function sectionFunctions:Label(text)
                local labelFunc = {}
                local label = Instance.new('TextLabel')
                
                label.Name = 'Label'
                label.Parent = itemHolder; label.BackgroundTransparency = 1; label.Size = UDim2.new(1, 0, 0, isMobile and 16 or 18)
                label.Font = Enum.Font.Code; label.Text = text; label.TextColor3 = Color3.fromRGB(230, 230, 230)
                label.TextSize = UI_TEXT; label.TextXAlignment = Enum.TextXAlignment.Left;
                
                updateSectionSize()
                
                function labelFunc:Change(newText) label.Text = newText end;
                return labelFunc;
            end;

            function sectionFunctions:Slider(text, min, max, default, callback)
                local holder = Instance.new('Frame')
                holder.Name = 'Slider'
                holder.Parent = itemHolder
                holder.BackgroundTransparency = 1
                holder.Size = UDim2.new(1, 0, 0, isMobile and 36 or 32)

                local title = Instance.new('TextLabel')
                title.Parent = holder
                title.BackgroundTransparency = 1
                title.Size = UDim2.new(0.55, 0, 0, 14)
                title.Font = Enum.Font.Code
                title.Text = text
                title.TextColor3 = Color3.fromRGB(190, 190, 190)
                title.TextSize = UI_SMALL
                title.TextXAlignment = Enum.TextXAlignment.Left

                local valLabel = Instance.new('TextLabel')
                valLabel.Parent = holder
                valLabel.BackgroundTransparency = 1
                valLabel.Position = UDim2.new(0.55, 0, 0, 0)
                valLabel.Size = UDim2.new(0.45, 0, 0, 14)
                valLabel.Font = Enum.Font.Code
                valLabel.Text = tostring(default)
                valLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                valLabel.TextSize = UI_SMALL
                valLabel.TextXAlignment = Enum.TextXAlignment.Right

                local track = Instance.new('Frame')
                track.Parent = holder
                track.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
                track.BorderSizePixel = 0
                track.Position = UDim2.new(0, 0, 0, 18)
                track.Size = UDim2.new(1, 0, 0, 6)

                local fill = Instance.new('Frame')
                fill.Parent = track
                fill.BackgroundColor3 = nexlib.accentclr
                fill.BorderSizePixel = 0
                local pct0 = math.clamp((default - min) / math.max(max - min, 1e-9), 0, 1)
                fill.Size = UDim2.new(pct0, 0, 1, 0)

                local value = default
                local sliding = false
                local function setFromX(x)
                    local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                    value = min + (max - min) * rel
                    if (max - min) > 5 then value = math.floor(value + 0.5) end
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    valLabel.Text = tostring(value)
                    pcall(callback, value)
                end

                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        setFromX(input.Position.X)
                    end
                end)
                game:GetService('UserInputService').InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        setFromX(input.Position.X)
                    end
                end)
                game:GetService('UserInputService').InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)

                updateSectionSize()
                coroutine.wrap(function()
                    while task.wait() do fill.BackgroundColor3 = nexlib.accentclr end
                end)()
            end

            function sectionFunctions:Dropdown(text, options, default, callback)
                local holder = Instance.new('Frame')
                holder.Name = 'Dropdown'
                holder.Parent = itemHolder
                holder.BackgroundTransparency = 1
                holder.Size = UDim2.new(1, 0, 0, isMobile and 48 or 42)
                holder.ClipsDescendants = false

                local title = Instance.new('TextLabel')
                title.Parent = holder
                title.BackgroundTransparency = 1
                title.Size = UDim2.new(1, 0, 0, 14)
                title.Font = Enum.Font.Code
                title.Text = text
                title.TextColor3 = Color3.fromRGB(190, 190, 190)
                title.TextSize = UI_SMALL
                title.TextXAlignment = Enum.TextXAlignment.Left

                local btn = Instance.new('TextButton')
                btn.Parent = holder
                btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
                btn.BorderSizePixel = 0
                btn.Position = UDim2.new(0, 0, 0, 16)
                btn.Size = UDim2.new(1, 0, 0, isMobile and 28 or 22)
                btn.Font = Enum.Font.Code
                btn.Text = "  " .. tostring(default)
                btn.TextColor3 = Color3.fromRGB(230, 230, 230)
                btn.TextSize = UI_TEXT
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.AutoButtonColor = false

                local arrow = Instance.new('TextLabel')
                arrow.Parent = btn
                arrow.BackgroundTransparency = 1
                arrow.Size = UDim2.new(0, 20, 1, 0)
                arrow.Position = UDim2.new(1, -22, 0, 0)
                arrow.Font = Enum.Font.Code
                arrow.Text = "v"
                arrow.TextColor3 = Color3.fromRGB(180, 180, 180)
                arrow.TextSize = 12
                arrow.TextXAlignment = Enum.TextXAlignment.Center

                local listFrame = Instance.new('Frame')
                listFrame.Name = 'DropList'
                listFrame.Parent = holder
                listFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
                listFrame.BorderSizePixel = 0
                listFrame.Position = UDim2.new(0, 0, 0, 40)
                listFrame.Size = UDim2.new(1, 0, 0, 0)
                listFrame.Visible = false
                listFrame.ZIndex = 50
                listFrame.ClipsDescendants = true

                local listStroke = Instance.new('UIStroke')
                listStroke.Parent = listFrame
                listStroke.Color = Color3.fromRGB(50, 50, 50)
                listStroke.Thickness = 1

                local listLayout = Instance.new('UIListLayout')
                listLayout.Parent = listFrame
                listLayout.SortOrder = Enum.SortOrder.LayoutOrder
                listLayout.Padding = UDim.new(0, 0)

                local open = false
                local selected = default
                local optionH = isMobile and 26 or 20

                for i, opt in ipairs(options) do
                    local ob = Instance.new('TextButton')
                    ob.Parent = listFrame
                    ob.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
                    ob.BorderSizePixel = 0
                    ob.Size = UDim2.new(1, 0, 0, optionH)
                    ob.Font = Enum.Font.Code
                    ob.Text = "  " .. tostring(opt)
                    ob.TextColor3 = Color3.fromRGB(210, 210, 210)
                    ob.TextSize = 12
                    ob.TextXAlignment = Enum.TextXAlignment.Left
                    ob.AutoButtonColor = false
                    ob.ZIndex = 51
                    ob.MouseEnter:Connect(function()
                        ob.BackgroundColor3 = Color3.fromRGB(36, 36, 36)
                    end)
                    ob.MouseLeave:Connect(function()
                        ob.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
                    end)
                    ob.MouseButton1Click:Connect(function()
                        selected = opt
                        btn.Text = "  " .. tostring(opt)
                        open = false
                        listFrame.Visible = false
                        listFrame.Size = UDim2.new(1, 0, 0, 0)
                        holder.Size = UDim2.new(1, 0, 0, 42)
                        arrow.Text = "v"
                        updateSectionSize()
                        pcall(callback, selected)
                    end)
                end

                btn.MouseButton1Click:Connect(function()
                    open = not open
                    if open then
                        local h = math.min(#options * optionH, 160)
                        listFrame.Size = UDim2.new(1, 0, 0, h)
                        listFrame.Visible = true
                        holder.Size = UDim2.new(1, 0, 0, 42 + h + 4)
                        arrow.Text = "^"
                    else
                        listFrame.Size = UDim2.new(1, 0, 0, 0)
                        listFrame.Visible = false
                        holder.Size = UDim2.new(1, 0, 0, 42)
                        arrow.Text = "v"
                    end
                    updateSectionSize()
                end)

                updateSectionSize()
            end
            
            return sectionFunctions;
        end;

        return tabFunctions;
    end;
    
    function windowFunctions:Destroy()
        if lighting:FindFirstChild("ValkUIBlur") then
            lighting.ValkUIBlur:Destroy()
        end
        screenGui:Destroy()
    end;

    -- intro removed: show UI immediately
    isVisible = true
    updateUIState()
    
    return windowFunctions;
end;

-----------------------------------------------------------
-- [글로벌 제어 변수]
-----------------------------------------------------------
-- Players / LocalPlayer already defined in mobile compat block
local RunService = game:GetService("RunService")
local UserInputService = UIS
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = Workspace.CurrentCamera

local teamCheckEnabled = true
local function isSameTeam(player)
    if not teamCheckEnabled then return false end
    local myTeam = LocalPlayer:GetAttribute('TeamID')
    local theirTeam = player:GetAttribute('TeamID')
    if myTeam == nil or theirTeam == nil then return false end
    return theirTeam == myTeam
end

local function isEnemyImmune(playerOrChar)
    local char = playerOrChar
    if typeof(playerOrChar) == "Instance" and playerOrChar:IsA("Player") then
        char = playerOrChar.Character
    end
    if not char then return true end
    if char:FindFirstChildOfClass("ForceField") then return true end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:FindFirstChild("Attachment") then return true end
    local immuneAttr = char:GetAttribute("Immune") or char:GetAttribute("Invincible") or char:GetAttribute("IsImmune")
    if immuneAttr == true then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local hImmune = hum:GetAttribute("Immune") or hum:GetAttribute("Invincible")
        if hImmune == true then return true end
    end
    return false
end

local function isEnemyKatanaReflecting(player)
    local char = player and player.Character
    if not char then return false end

    local attrs = {"Reflecting", "IsReflecting", "BulletReflect", "Reflect", "Deflecting", "Parrying"}
    for _, a in ipairs(attrs) do
        local v = char:GetAttribute(a)
        if v == true or v == 1 or v == "true" then return true end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local hv = hum:GetAttribute(a)
            if hv == true or hv == 1 then return true end
        end
    end

    local hasKatana = false
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and string.find(string.lower(tool.Name), "katana", 1, true) then
        hasKatana = true
    end
    for _, ch in ipairs(char:GetChildren()) do
        local n = string.lower(ch.Name)
        if string.find(n, "katana", 1, true) then
            hasKatana = true
        end
        if string.find(n, "reflect", 1, true) or string.find(n, "deflect", 1, true) then
            return true
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local ok, tracks = pcall(function() return hum:GetPlayingAnimationTracks() end)
        if ok and tracks then
            for _, track in ipairs(tracks) do
                local tn = string.lower(tostring(track.Name or ""))
                local aid = ""
                pcall(function()
                    if track.Animation then aid = tostring(track.Animation.AnimationId or "") end
                end)
                local blob = tn .. " " .. string.lower(aid)
                if string.find(blob, "reflect", 1, true) or string.find(blob, "deflect", 1, true)
                    or string.find(blob, "parry", 1, true) or string.find(blob, "block", 1, true) then
                    if hasKatana or string.find(blob, "katana", 1, true) then
                        return true
                    end
                    if string.find(blob, "reflect", 1, true) or string.find(blob, "deflect", 1, true) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local combatReady = true
local projectileEnabled = false
local desyncDistValue = 3
local currentTarget = nil

-- Autofarm rage (same as main ragebot, height 18)
local farmRageEnabled = false
local farmRageHeight = 18

-- TP behind enemy
local behindTPEnabled = false
local behindTPDistance = 3

-- Aimbot
local aimbotEnabled = false
local aimbotSmooth = 0.35 -- 0 = instant, higher = slower
local aimbotFov = 250 -- pixels; 0 = no limit
local aimbotTeamCheck = true
local aimbotWallCheck = true -- only track if visible (no wall)

-- Void spam (Halmu exact: can-act cycle + height lock)
local voidSpamEnabled = false      -- _lII0ll cycle
local heightLockEnabled = false    -- Halmu height lock void spam
local voidAttackTime = 0.10        -- a85b57c99
local voidHideTime = 0.25          -- _4012x732
local lockHeight = 50              -- Halmu lockHeight / void spam studs
local voidCanAct = true            -- _2631x704

local espEnabled = false
local espBoxes = true
local espNames = true
local espHealth = true
local espRank = true

-- Rivals rank from DisplayELO (and common fallbacks)
local function getPlayerElo(player)
    local keys = {
        "DisplayELO", "DisplayElo", "ELO", "Elo", "RankedELO", "RankedElo",
        "MMR", "Rating", "RankScore", "RankedScore",
    }
    for _, k in ipairs(keys) do
        local v = player:GetAttribute(k)
        if typeof(v) == "number" then return v end
        if typeof(v) == "string" then
            local n = tonumber(v)
            if n then return n end
        end
    end
    -- leaderstats fallback
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, name in ipairs({"ELO", "Elo", "Rank", "MMR", "Rating"}) do
            local val = ls:FindFirstChild(name)
            if val and typeof(val.Value) == "number" then return val.Value end
            if val and typeof(val.Value) == "string" then
                local n = tonumber(val.Value)
                if n then return n end
            end
        end
    end
    return nil
end

local function eloToRankName(elo)
    if elo == nil then return "Unranked" end
    elo = tonumber(elo) or 0
    if elo < 0 then return "Unranked" end
    local tiers = {
        {0, "Bronze I"}, {200, "Bronze II"}, {400, "Bronze III"},
        {600, "Silver I"}, {800, "Silver II"}, {1000, "Silver III"},
        {1200, "Gold I"}, {1400, "Gold II"}, {1600, "Gold III"},
        {1800, "Platinum I"}, {2000, "Platinum II"}, {2200, "Platinum III"},
        {2400, "Diamond I"}, {2600, "Diamond II"}, {2800, "Diamond III"},
        {3000, "Onyx I"}, {3200, "Onyx II"}, {3400, "Onyx III"},
        {3600, "Nemesis"},
    }
    local name = "Bronze I"
    for _, t in ipairs(tiers) do
        if elo >= t[1] then name = t[2] else break end
    end
    return name
end

local function getRankDisplay(player)
    -- prefer explicit rank string attribute if present
    for _, k in ipairs({"DisplayRank", "RankName", "Rank"}) do
        local v = player:GetAttribute(k)
        if typeof(v) == "string" and v ~= "" and not tonumber(v) then
            local elo = getPlayerElo(player)
            if elo then return v .. " [" .. math.floor(elo) .. "]" end
            return v
        end
    end
    local elo = getPlayerElo(player)
    if elo == nil then return nil end
    return eloToRankName(elo) .. " [" .. math.floor(elo) .. "]"
end

local function getRageHead(char)
    if not char then return nil end
    return char:FindFirstChild("HitboxHead")
        or char:FindFirstChild("HitboxHeadSmall")
        or char:FindFirstChild("Head")
end

local _rageConn
local _startRagebot = function(on) end

task.spawn(function()
    local ok, err = xpcall(function()
        local PS = LocalPlayer.PlayerScripts
        local _okF, FighterCtrl = pcall(require, PS.Controllers.FighterController)
        local _okE, EnumLib     = pcall(require, ReplicatedStorage.Modules.EnumLibrary)
        local _useItemRemote    = ReplicatedStorage.Remotes.Replication.Fighter.UseItem
        local _ssEnum; pcall(function() _ssEnum = EnumLib:ToEnum("StartShooting") end)

        local function _getEquippedObjId()
            if not (_okF and FighterCtrl) then return nil end
            local lf = FighterCtrl.LocalFighter; if not lf then return nil end
            local item = lf.EquippedItem; if not item then return nil end
            local ok2, id = pcall(function() return item:Get("ObjectID") end)
            if ok2 and id then return id end
            ok2, id = pcall(function() return item.Data and item.Data.ObjectID end)
            return ok2 and id or nil
        end

        local function _buildShotData(originPos, targetPart)
            local targetPos = targetPart.Position
            local lookCF = CFrame.lookAt(originPos, targetPos)
            local lX, lY, lZ = lookCF:ToOrientation()
            local originStruct = {
                [utf8.char(0)] = originPos.X, [utf8.char(1)] = originPos.Y, [utf8.char(2)] = originPos.Z,
                [utf8.char(3)] = lX, [utf8.char(4)] = lY, [utf8.char(5)] = lZ,
            }
            local relCF = targetPart.CFrame:ToObjectSpace(CFrame.new(targetPos))
            local rX, rY, rZ = relCF:ToOrientation()
            return {
                [utf8.char(1)] = {
                    [utf8.char(0)] = originStruct,
                    [utf8.char(1)] = originStruct,
                    [utf8.char(2)] = targetPart,
                    [utf8.char(3)] = {
                        [utf8.char(0)] = relCF.X, [utf8.char(1)] = relCF.Y, [utf8.char(2)] = relCF.Z,
                        [utf8.char(3)] = rX, [utf8.char(4)] = rY, [utf8.char(5)] = rZ,
                    },
                },
            }
        end

        _startRagebot = function(on)
            if _rageConn then _rageConn:Disconnect(); _rageConn = nil end
            if not on then return end

            local _cachedObjId = nil
            _rageConn = RunService.Heartbeat:Connect(function()
                if not (projectileEnabled or farmRageEnabled) or not combatReady then return end
                if not currentTarget or not currentTarget.Parent then return end

                local targetChar = currentTarget:FindFirstAncestorOfClass("Model") or currentTarget.Parent
                local targetPlr = Players:GetPlayerFromCharacter(targetChar)
                if not targetPlr or targetPlr == LocalPlayer then return end
                if isSameTeam(targetPlr) then return end
                if isEnemyImmune(targetPlr) then return end
                if isEnemyKatanaReflecting(targetPlr) then return end

                local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not myHRP then return end

                local objId = _getEquippedObjId()
                if objId then _cachedObjId = objId else objId = _cachedObjId end
                if not objId then return end

                local targetHead = currentTarget
                local origin = targetHead.Position + Vector3.new(0, 0.1, 0)
                local shotData = _buildShotData(origin, targetHead)
                pcall(function()
                    _useItemRemote:FireServer(objId, _ssEnum, shotData, nil)
                end)
            end)
        end
    end, function(err) end)
end)

local RealCFrame = nil
local RealVelocity = nil

local function rageCanTeleport()
    local can = true
    pcall(function()
        local PS = LocalPlayer.PlayerScripts
        local ok, FC = pcall(require, PS.Controllers.FighterController)
        if not ok or not FC or not FC.LocalFighter then return end
        local item = FC.LocalFighter.EquippedItem
        if not item then
            can = false
            return
        end
        local function g(key)
            local ok2, val = pcall(function()
                if item.Get then return item:Get(key) end
                return item[key] or (item.Data and item.Data[key]) or (item.Info and item.Info[key])
            end)
            if ok2 then return val end
            return nil
        end
        local cur = g("CurrentAmmo") or g("Ammo") or g("Bullets") or g("MagazineAmmo")
        local reloading = g("Reloading") or g("IsReloading")
        if item.Info and type(item.Info) == "table" then
            if cur == nil then cur = item.Info.CurrentAmmo or item.Info.Ammo end
            if item.Info.Reloading == true or item.Info.IsReloading == true then
                reloading = true
            end
        end
        if reloading == true then
            can = false
            return
        end
        if typeof(cur) == "number" and cur <= 0 then
            can = false
            return
        end
    end)
    return can
end

RunService.Heartbeat:Connect(function()
    pcall(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local rageOn = projectileEnabled or farmRageEnabled
        if rageOn and combatReady and currentTarget and hrp and rageCanTeleport() and (not voidSpamEnabled or voidCanAct) then
            local tChar = currentTarget:FindFirstAncestorOfClass("Model") or currentTarget.Parent
            local tPlr = Players:GetPlayerFromCharacter(tChar)
            if tPlr and isEnemyKatanaReflecting(tPlr) then return end
            RealCFrame = hrp.CFrame
            RealVelocity = hrp.AssemblyLinearVelocity

            local targetPos = currentTarget.Position
            -- main ragebot height 3; autofarm-only ragebot height 18
            local height = desyncDistValue
            if farmRageEnabled and not projectileEnabled then
                height = farmRageHeight
            end
            local fakePos = targetPos + Vector3.new(0, height, 0)
            hrp.CFrame = CFrame.new(fakePos, targetPos)
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end)
end)

RunService:BindToRenderStep("RestoreDesyncPerfect", 150, function()
    pcall(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and RealCFrame then
            hrp.CFrame = RealCFrame
            if RealVelocity then hrp.AssemblyLinearVelocity = RealVelocity end
            RealCFrame = nil
            RealVelocity = nil
        end
    end)
end)

task.spawn(function()
    while true do
        task.wait(0.01)
        if (projectileEnabled or farmRageEnabled) and combatReady then
            local refPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.zero
            local closestPlayer = nil
            local shortestDistance = math.huge

            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and not isSameTeam(player) then
                    if isEnemyImmune(player) then
                        continue
                    end
                    if isEnemyKatanaReflecting(player) then
                        continue
                    end
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    local hum = player.Character:FindFirstChild("Humanoid")
                    if hrp and hum and hum.Health > 0 then
                        local distance = (Vector3.new(refPos.X, 0, refPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end

            if closestPlayer and closestPlayer.Character then
                currentTarget = getRageHead(closestPlayer.Character)
            else
                currentTarget = nil
            end
        else
            currentTarget = nil
        end
    end
end)

-- Continuously teleport behind closest enemy
RunService.Heartbeat:Connect(function()
    if not behindTPEnabled then return end
    pcall(function()
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end

        local closest, closestDist = nil, math.huge
        local myPos = myHRP.Position
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and not isSameTeam(player) then
                if isEnemyImmune(player) then continue end
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    local d = (hrp.Position - myPos).Magnitude
                    if d < closestDist then
                        closestDist = d
                        closest = hrp
                    end
                end
            end
        end

        if closest then
            -- stand behind enemy (opposite of their look direction)
            local behindPos = closest.Position - closest.CFrame.LookVector * behindTPDistance
            behindPos = Vector3.new(behindPos.X, closest.Position.Y, behindPos.Z)
            -- face enemy back / torso for knife stab
            local lookAt = closest.Position
            local char = closest.Parent
            if char then
                local torso = char:FindFirstChild("UpperTorso")
                    or char:FindFirstChild("Torso")
                    or char:FindFirstChild("HumanoidRootPart")
                local head = char:FindFirstChild("HitboxHead")
                    or char:FindFirstChild("HitboxHeadSmall")
                    or char:FindFirstChild("Head")
                if torso then
                    lookAt = torso.Position
                elseif head then
                    lookAt = head.Position
                end
            end
            -- body faces enemy back
            myHRP.CFrame = CFrame.lookAt(behindPos, lookAt)
            myHRP.AssemblyLinearVelocity = Vector3.zero
            -- camera keeps looking at enemy back as well
            local cam = workspace.CurrentCamera
            if cam then
                local camPos = behindPos + Vector3.new(0, 1.6, 0)
                cam.CFrame = CFrame.lookAt(camPos, lookAt)
            end
        end
    end)
end)

-- Aimbot: track visible enemy heads only (wall check)
local aimbotRayParams = RaycastParams.new()
aimbotRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(fromPos, toPos, targetChar)
    local ignore = {}
    local myChar = LocalPlayer.Character
    if myChar then table.insert(ignore, myChar) end
    if targetChar then table.insert(ignore, targetChar) end
    -- ignore common non-blocking fx
    local cam = workspace.CurrentCamera
    if cam then table.insert(ignore, cam) end

    aimbotRayParams.FilterDescendantsInstances = ignore
    local dir = toPos - fromPos
    local dist = dir.Magnitude
    if dist < 0.5 then return true end
    local result = workspace:Raycast(fromPos, dir.Unit * dist, aimbotRayParams)
    if not result then return true end
    -- hit something that belongs to target = still visible
    if targetChar and result.Instance and result.Instance:IsDescendantOf(targetChar) then
        return true
    end
    return false
end

local function getAimbotTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local screenCenter = cam.ViewportSize / 2
    local origin = cam.CFrame.Position
    local best, bestScore = nil, math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if aimbotTeamCheck and isSameTeam(player) then continue end
        if isEnemyImmune(player) then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local head = getRageHead(char)
        if not head then continue end

        local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
        if not onScreen or screenPos.Z <= 0 then continue end

        local dx = screenPos.X - screenCenter.X
        local dy = screenPos.Y - screenCenter.Y
        local dist2d = math.sqrt(dx * dx + dy * dy)
        if aimbotFov > 0 and dist2d > aimbotFov then continue end

        -- wall check: skip if not visible from camera
        if aimbotWallCheck and not hasLineOfSight(origin, head.Position, char) then
            continue
        end

        local score = dist2d + (screenPos.Z * 0.05)
        if score < bestScore then
            bestScore = score
            best = head
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if not aimbotEnabled then return end
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local target = getAimbotTarget()
        if not target then return end

        -- continuous track while visible
        local goal = CFrame.lookAt(cam.CFrame.Position, target.Position)
        if aimbotSmooth <= 0 then
            cam.CFrame = goal
        else
            local alpha = math.clamp(1 - aimbotSmooth, 0.08, 1)
            cam.CFrame = cam.CFrame:Lerp(goal, alpha)
        end
    end)
end)

-- Halmu voidspam cycle: attack window (can act) -> hide window (cannot act)
-- Only runs when void spam + ragebot (main or farm) is on, same as Halmu (_lII0ll and L555_61)
task.spawn(function()
    while true do
        local rageOn = projectileEnabled or farmRageEnabled
        if voidSpamEnabled and rageOn then
            voidCanAct = true
            local atk = voidAttackTime
            if typeof(atk) ~= "number" or atk < 0.01 then atk = 0.01 end
            task.wait(atk)
            if voidSpamEnabled and (projectileEnabled or farmRageEnabled) then
                voidCanAct = false
                local hide = voidHideTime
                if typeof(hide) ~= "number" or hide < 0.01 then hide = 0.01 end
                task.wait(hide)
            else
                voidCanAct = true
            end
        else
            voidCanAct = true
            task.wait(0.05)
        end
    end
end)

-- Halmu height lock void spam: pin Y to lockHeight every frame
RunService.Heartbeat:Connect(function()
    if not heightLockEnabled then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or (hum and hum.Health <= 0) then return end
        hrp.CFrame = CFrame.new(hrp.Position.X, lockHeight, hrp.Position.Z)
    end)
end)

-----------------------------------------------------------
-- [RIVALS AUTO MATCHMAKING]
-----------------------------------------------------------
local autoMatchEnabled = false
local autoMatchMode = "1v1"
local autoMatchLoop = nil
local collectDropsEnabled = false
local autoRespawnEnabled = false

-- Auto ban (Duels.Vote)
local autoBanEnabled = false
local BAN_WEAPON_LIST = {
    -- Primary
    "Assault Rifle", "Bow", "Burst Rifle", "Crossbow", "Gunblade", "RPG", "Shotgun", "Sniper",
    "Energy Rifle", "Flamethrower", "Grenade Launcher", "Minigun", "Paintball Gun",
    "Distortion", "Permafrost", "Scepter",
    -- Secondary
    "Daggers", "Flare Gun", "Handgun", "Revolver", "Shorty", "Spray", "Uzi",
    "Energy Pistols", "Exogun", "Slingshot", "Warper", "Glass Cannon",
    -- Melee
    "Fists", "Katana", "Knife", "Scythe", "Battle Axe", "Chainsaw", "Riot Shield", "Trowel", "Glast Shard",
    -- Utility
    "Flashbang", "Freeze Ray", "Grenade", "Jump Pad", "Molotov", "Medkit", "Subspace Tripmine", "Warpstone",
}
local banSelected = {
    ["Riot Shield"] = true,
    ["Katana"] = true,
}
local function getBanList()
    local list = {}
    for _, name in ipairs(BAN_WEAPON_LIST) do
        if banSelected[name] then
            table.insert(list, name)
        end
    end
    return list
end

task.spawn(function()
    while true do
        if not autoBanEnabled then
            task.wait(0.25)
            continue
        end
        local list = getBanList()
        if #list == 0 then
            task.wait(0.5)
            continue
        end
        for _, weapon in ipairs(list) do
            if not autoBanEnabled then break end
            pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local duels = remotes and remotes:FindFirstChild("Duels")
                local vote = duels and duels:FindFirstChild("Vote")
                if vote and vote:IsA("RemoteEvent") then
                    vote:FireServer(weapon)
                elseif vote and vote:IsA("RemoteFunction") then
                    vote:InvokeServer(weapon)
                end
            end)
            task.wait(1)
        end
    end
end)
local MATCH_MODES = {
    "Beginner 2v2",
    "1v1", "2v2", "3v3", "4v4", "5v5",
    "Ranked 1v1", "Ranked 2v2", "Ranked 3v3",
}

-- mode -> possible remote payload keys used by Rivals-style queues
local MODE_KEYS = {
    ["Beginner 2v2"] = {"beginner_2v2", "Beginner2v2", "beginner2v2", "2v2_beginner", "casual_beginner_2v2"},
    ["1v1"] = {"1v1", "duel_1v1", "casual_1v1", "1v1s"},
    ["2v2"] = {"2v2", "duel_2v2", "casual_2v2", "2v2s"},
    ["3v3"] = {"3v3", "duel_3v3", "casual_3v3", "3v3s"},
    ["4v4"] = {"4v4", "duel_4v4", "casual_4v4", "4v4s"},
    ["5v5"] = {"5v5", "duel_5v5", "casual_5v5", "5v5s"},
    ["Ranked 1v1"] = {"ranked_1v1", "rank_1v1", "Ranked1v1", "ranked1v1", "1v1_ranked", "Rank 1v1"},
    ["Ranked 2v2"] = {"ranked_2v2", "rank_2v2", "Ranked2v2", "ranked2v2", "2v2_ranked", "Rank 2v2"},
    ["Ranked 3v3"] = {"ranked_3v3", "rank_3v3", "Ranked3v3", "ranked3v3", "3v3_ranked", "Rank 3v3"},
}

local function findQueuePad(mode)
    -- Path used by public Rivals scripts: Lobby > Hub > Extra > Important > Center > Duels
    local ok, pad = pcall(function()
        local lobby = workspace:FindFirstChild("Lobby")
        if not lobby then return nil end
        local hub = lobby:FindFirstChild("Hub") or lobby
        local extra = hub:FindFirstChild("Extra") or hub
        local important = extra:FindFirstChild("Important") or extra
        local center = important:FindFirstChild("Center") or important
        local duels = center:FindFirstChild("Duels")
        if not duels then
            -- fallback: scan for any Duels folder
            for _, d in ipairs(workspace:GetDescendants()) do
                if d.Name == "Duels" and d:IsA("Folder") or d:IsA("Model") then
                    duels = d
                    break
                end
            end
        end
        if not duels then return nil end

        -- Prefer pad index by mode size (1v1 -> pad 1, etc.)
        local sizeMap = {
            ["Beginner 2v2"]=2,
            ["1v1"]=1,["2v2"]=2,["3v3"]=3,["4v4"]=4,["5v5"]=5,
            ["Ranked 1v1"]=1,["Ranked 2v2"]=2,["Ranked 3v3"]=3,
        }
        local prefer = sizeMap[mode] or 1
        local candidates = {}
        for _, child in ipairs(duels:GetChildren()) do
            local n = string.lower(child.Name)
            if string.find(n, "queue", 1, true) or string.find(n, "pad", 1, true) then
                table.insert(candidates, child)
            end
        end
        if #candidates == 0 then return nil end

        local function padBaseOf(model)
            return model:FindFirstChild("PadBase1")
                or model:FindFirstChild("PadBase")
                or model:FindFirstChildWhichIsA("BasePart", true)
        end

        -- try preferred index
        for _, c in ipairs(candidates) do
            if string.find(c.Name, tostring(prefer), 1, true) then
                local base = padBaseOf(c)
                if base then return base end
            end
        end
        -- any pad
        for _, c in ipairs(candidates) do
            local base = padBaseOf(c)
            if base then return base end
        end
        return nil
    end)
    if ok then return pad end
    return nil
end

local function tryFireMatchRemote(mode)
    local keys = MODE_KEYS[mode] or {mode}
    local remotesRoot = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesRoot then return false end

    local function tryFire(obj, arg)
        if not obj then return false end
        local ok = false
        if obj:IsA("RemoteEvent") then
            ok = pcall(function() obj:FireServer(arg) end)
            if not ok then ok = pcall(function() obj:FireServer() end) end
            if not ok and type(arg) == "string" then
                ok = pcall(function() obj:FireServer({Mode = arg}) end)
                if not ok then ok = pcall(function() obj:FireServer({mode = arg}) end) end
                if not ok then ok = pcall(function() obj:FireServer({GameMode = arg}) end) end
            end
        elseif obj:IsA("RemoteFunction") then
            ok = pcall(function() obj:InvokeServer(arg) end)
            if not ok then ok = pcall(function() obj:InvokeServer() end) end
            if not ok and type(arg) == "string" then
                ok = pcall(function() obj:InvokeServer({Mode = arg}) end)
            end
        end
        return ok
    end

    -- Rivals-specific: Duels / Arcade
    local duels = remotesRoot:FindFirstChild("Duels")
    local arcade = remotesRoot:FindFirstChild("Arcade")
    if duels then
        for _, n in ipairs({"Queue", "JoinQueue", "Join", "Matchmake", "StartQueue", "QueueFor", "EnterQueue", "FindMatch", "JoinMatch", "Play"}) do
            local r = duels:FindFirstChild(n)
            if r then
                for _, key in ipairs(keys) do
                    if tryFire(r, key) then return true end
                end
                if tryFire(r, nil) then return true end
            end
        end
        for _, child in ipairs(duels:GetChildren()) do
            local ln = string.lower(child.Name)
            if string.find(ln, "queue", 1, true) or string.find(ln, "match", 1, true) or string.find(ln, "join", 1, true) then
                for _, key in ipairs(keys) do
                    if tryFire(child, key) then return true end
                end
            end
        end
    end
    if arcade then
        local join = arcade:FindFirstChild("Join")
        if join then
            for _, key in ipairs(keys) do
                if tryFire(join, key) then return true end
            end
            if tryFire(join, nil) then return true end
        end
    end

    local folders = {
        remotesRoot:FindFirstChild("Matchmaking"),
        remotesRoot:FindFirstChild("Queue"),
        remotesRoot:FindFirstChild("Play"),
        remotesRoot,
    }
    local nameCandidates = {
        "Queue", "JoinQueue", "Matchmake", "Matchmaking", "Join", "StartQueue",
        "QueueFor", "EnterQueue", "Play", "FindMatch", "JoinMatch",
    }
    for _, folder in ipairs(folders) do
        if folder then
            for _, name in ipairs(nameCandidates) do
                local remote = folder:FindFirstChild(name)
                if remote then
                    for _, key in ipairs(keys) do
                        if tryFire(remote, key) then return true end
                    end
                end
            end
            for _, child in ipairs(folder:GetChildren()) do
                local n = string.lower(child.Name)
                if string.find(n, "queue", 1, true) or string.find(n, "match", 1, true) or string.find(n, "play", 1, true) then
                    for _, key in ipairs(keys) do
                        if tryFire(child, key) then return true end
                    end
                end
            end
        end
    end
    return false
end

local function teleportToPad(mode)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local pad = findQueuePad(mode)
    if not pad then return false end
    return pcall(function()
        hrp.CFrame = pad.CFrame + Vector3.new(0, 4, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
end

local function doMatchAttempt()
    if not autoMatchEnabled then return end
    -- Random queue only (no lobby pad teleport)
    -- Uses Duels / Arcade / Matchmaking remotes with selected Game Mode
    local fired = tryFireMatchRemote(autoMatchMode)

    -- Extra Rivals random-queue patterns
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then return end
        local keys = MODE_KEYS[autoMatchMode] or {autoMatchMode}

        local function fireAny(obj, arg)
            if not obj then return end
            if obj:IsA("RemoteEvent") then
                pcall(function() obj:FireServer(arg) end)
                pcall(function() obj:FireServer() end)
                if type(arg) == "string" then
                    pcall(function() obj:FireServer({Mode = arg}) end)
                    pcall(function() obj:FireServer({mode = arg}) end)
                    pcall(function() obj:FireServer({GameMode = arg}) end)
                    pcall(function() obj:FireServer({gameMode = arg}) end)
                    pcall(function() obj:FireServer({Queue = arg}) end)
                end
            elseif obj:IsA("RemoteFunction") then
                pcall(function() obj:InvokeServer(arg) end)
                pcall(function() obj:InvokeServer() end)
            end
        end

        -- Duels random queue
        local duels = remotes:FindFirstChild("Duels")
        if duels then
            for _, name in ipairs({"Queue", "JoinQueue", "Join", "Matchmake", "FindMatch", "Play", "StartMatch", "RandomQueue"}) do
                local r = duels:FindFirstChild(name)
                if r then
                    for _, k in ipairs(keys) do fireAny(r, k) end
                    fireAny(r, nil)
                end
            end
        end

        -- Arcade random join
        local arcade = remotes:FindFirstChild("Arcade")
        if arcade then
            local join = arcade:FindFirstChild("Join")
            if join then
                for _, k in ipairs(keys) do fireAny(join, k) end
                fireAny(join, nil)
            end
        end
    end)

    return fired
end

local function startAutoMatch()
    if autoMatchLoop then return end
    autoMatchLoop = task.spawn(function()
        while autoMatchEnabled do
            pcall(doMatchAttempt)
            task.wait(2.5)
        end
        autoMatchLoop = nil
    end)
end

local function stopAutoMatch()
    autoMatchEnabled = false
    autoMatchLoop = nil
end

-- Auto Respawn (Rivals: Duels.RespawnNow + UI buttons)
task.spawn(function()
    while true do
        task.wait(1.5)
        if not autoRespawnEnabled then continue end
        pcall(function()
            -- Rivals duel respawn remote (works even when alive in some modes)
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local duels = remotes and remotes:FindFirstChild("Duels")
            local respawn = duels and duels:FindFirstChild("RespawnNow")
            if respawn then
                if respawn:IsA("RemoteEvent") then
                    pcall(function() respawn:FireServer() end)
                elseif respawn:IsA("RemoteFunction") then
                    pcall(function() respawn:InvokeServer() end)
                end
            end

            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                pcall(function()
                    local gui = LocalPlayer:FindFirstChild("PlayerGui")
                    if gui then
                        for _, d in ipairs(gui:GetDescendants()) do
                            if d:IsA("TextButton") or d:IsA("ImageButton") then
                                local t = string.lower(d.Text or d.Name or "")
                                if string.find(t, "respawn", 1, true) or string.find(t, "play again", 1, true) then
                                    pcall(function() firesignal(d.MouseButton1Click) end)
                                    pcall(function() d:Activate() end)
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end
end)

-- Collect drops (nearby collectibles / pickups)
task.spawn(function()
    while true do
        task.wait(0.35)
        if not collectDropsEnabled then continue end
        pcall(function()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local keywords = {"drop", "loot", "pickup", "collect", "orb", "coin", "crate", "chest", "reward"}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("Model") then
                    local n = string.lower(obj.Name)
                    local hit = false
                    for _, k in ipairs(keywords) do
                        if string.find(n, k, 1, true) then hit = true break end
                    end
                    if hit then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part and (part.Position - hrp.Position).Magnitude < 80 then
                            hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 2, 0))
                            task.wait(0.05)
                        end
                    end
                end
            end
        end)
    end
end)

-- [FAST FIRE / FAST MELEE] (Rivals ItemLibrary patch)
-----------------------------------------------------------
local fastFireEnabled = false
local fastMeleeEnabled = false
local _origItemStats = {} -- name -> { key = original value }

local FAST_GUN_EXCEPTIONS = {
    ["Sniper"] = true,
    ["Crossbow"] = true,
    ["Bow"] = true,
    ["RPG"] = true,
}

local function getItemLibraryItems()
    local ok, lib = pcall(function()
        return require(ReplicatedStorage.Modules.ItemLibrary)
    end)
    if ok and type(lib) == "table" then
        if type(lib.Items) == "table" then return lib.Items end
        return lib
    end
    return nil
end

local function saveOrig(name, data, key)
    if data[key] == nil then return end
    _origItemStats[name] = _origItemStats[name] or {}
    if _origItemStats[name][key] == nil then
        _origItemStats[name][key] = data[key]
    end
end

local function applyFastWeapons()
    local items = getItemLibraryItems()
    if not items then return end
    for name, data in pairs(items) do
        if typeof(data) ~= "table" then continue end

        if fastFireEnabled and not FAST_GUN_EXCEPTIONS[name] then
            for _, key in ipairs({"ShootSpread", "ShootAccuracy", "ShootRecoil", "ShootCooldown", "ShootBurstCooldown"}) do
                if data[key] ~= nil then
                    saveOrig(name, data, key)
                    if key == "ShootSpread" or key == "ShootAccuracy" or key == "ShootRecoil" then
                        data[key] = 0
                    else
                        data[key] = 0.001
                    end
                end
            end
        end

        if fastMeleeEnabled then
            for _, key in ipairs({"AttackCooldown", "SwingCooldown", "MeleeCooldown", "Cooldown", "RecoveryTime", "ResetTime"}) do
                if data[key] ~= nil then
                    saveOrig(name, data, key)
                    data[key] = 0.001
                end
            end
        end
    end
end

local function restoreFastWeapons()
    local items = getItemLibraryItems()
    if not items then return end
    for name, saved in pairs(_origItemStats) do
        local data = items[name]
        if typeof(data) == "table" then
            for key, val in pairs(saved) do
                data[key] = val
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        if fastFireEnabled or fastMeleeEnabled then
            pcall(applyFastWeapons)
        end
    end
end)


-----------------------------------------------------------
-- [UNLOCK ALL COSMETICS] (Skin/Charm/Dance/Wrap — no Finishers)
-----------------------------------------------------------
local unlockAllEnabled = false
local unlockAllStarted = false

local function startUnlockAll()
    if unlockAllStarted then return end
    unlockAllStarted = true
    task.spawn(function()
        local ok, err = pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local HttpService = game:GetService("HttpService")
            local player = LocalPlayer
            local playerScripts = player:WaitForChild("PlayerScripts", 10)
            if not playerScripts then return end
            local controllers = playerScripts:WaitForChild("Controllers", 10)
            local modules = RS:WaitForChild("Modules", 10)

            local EnumLibrary = nil
            pcall(function()
                EnumLibrary = require(modules:WaitForChild("EnumLibrary", 10))
                if EnumLibrary and EnumLibrary.WaitForEnumBuilder then
                    EnumLibrary:WaitForEnumBuilder()
                end
            end)

            local CosmeticLibrary = require(modules:WaitForChild("CosmeticLibrary", 10))
            local ItemLibrary = require(modules:WaitForChild("ItemLibrary", 10))
            local DataController = require(controllers:WaitForChild("PlayerDataController", 10))

            local equipped, favorites = {}, {}
            local constructingWeapon, viewingProfile = nil, nil
            local lastUsedWeapon = nil

            local function isAllowedCosmetic(cosmetic, name)
                if not cosmetic then return false end
                local t = tostring(cosmetic.Type or "")
                local n = string.lower(tostring(name or ""))
                if t == "Finisher" or n:find("finisher", 1, true) then return false end
                if t == "Skin" or t == "Charm" or t == "Dance" or t == "Emote" or t == "Wrap" or t == "Wrapping" then
                    return true
                end
                if n:find("charm", 1, true) or n:find("dance", 1, true) or n:find("emote", 1, true) or n:find("wrap", 1, true) then
                    return true
                end
                return false
            end

            local function cloneCosmetic(name, cosmeticType, options)
                local base = CosmeticLibrary.Cosmetics[name]
                if not base then return nil end
                local data = {}
                for key, value in pairs(base) do data[key] = value end
                data.Name = name
                data.Type = data.Type or cosmeticType
                data.Seed = data.Seed or math.random(1, 1000000)
                if EnumLibrary then
                    local success, enumId = pcall(function() return EnumLibrary:ToEnum(name) end)
                    if success and enumId then
                        data.Enum = enumId
                        data.ObjectID = data.ObjectID or enumId
                    end
                end
                if options then
                    if options.inverted ~= nil then data.Inverted = options.inverted end
                    if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
                end
                return data
            end

            local saveFile = "unlockall/config.json"
            local function saveConfig()
                if not writefile then return end
                pcall(function()
                    local config = {equipped = {}, favorites = favorites}
                    for weapon, cosmetics in pairs(equipped) do
                        config.equipped[weapon] = {}
                        for cosmeticType, cosmeticData in pairs(cosmetics) do
                            if cosmeticData and cosmeticData.Name then
                                config.equipped[weapon][cosmeticType] = {
                                    name = cosmeticData.Name,
                                    seed = cosmeticData.Seed,
                                    inverted = cosmeticData.Inverted,
                                }
                            end
                        end
                    end
                    if makefolder then makefolder("unlockall") end
                    writefile(saveFile, HttpService:JSONEncode(config))
                end)
            end

            local function loadConfig()
                if not readfile or not isfile or not isfile(saveFile) then return end
                pcall(function()
                    local config = HttpService:JSONDecode(readfile(saveFile))
                    if config.equipped then
                        for weapon, cosmetics in pairs(config.equipped) do
                            equipped[weapon] = {}
                            for cosmeticType, cosmeticData in pairs(cosmetics) do
                                local cloned = cloneCosmetic(cosmeticData.name, cosmeticType, {inverted = cosmeticData.inverted})
                                if cloned then
                                    cloned.Seed = cosmeticData.seed
                                    equipped[weapon][cosmeticType] = cloned
                                end
                            end
                        end
                    end
                    favorites = config.favorites or {}
                end)
            end

            local originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
            CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
                if type(name) == "string" and name:find("MISSING_") then
                    return originalOwnsCosmetic(self, inventory, name, weapon)
                end
                local cosmetic = CosmeticLibrary.Cosmetics[name]
                if isAllowedCosmetic(cosmetic, name) then return true end
                return originalOwnsCosmetic(self, inventory, name, weapon)
            end

            pcall(function()
                CosmeticLibrary.OwnsCosmeticNormally = function(self, inventory, name, weapon)
                    local cosmetic = CosmeticLibrary.Cosmetics[name]
                    if isAllowedCosmetic(cosmetic, name) then return true end
                    return false
                end
                CosmeticLibrary.OwnsCosmeticUniversally = CosmeticLibrary.OwnsCosmeticNormally
                CosmeticLibrary.OwnsCosmeticForWeapon = CosmeticLibrary.OwnsCosmeticNormally
            end)

            local originalGet = DataController.Get
            DataController.Get = function(self, key)
                local data = originalGet(self, key)
                if key == "CosmeticInventory" then
                    local proxy = {}
                    if data then
                        for k, v in pairs(data) do
                            local cosmetic = CosmeticLibrary.Cosmetics[k]
                            if isAllowedCosmetic(cosmetic, k) then proxy[k] = v end
                        end
                    end
                    return setmetatable(proxy, {
                        __index = function(_, k)
                            local cosmetic = CosmeticLibrary.Cosmetics[k]
                            if isAllowedCosmetic(cosmetic, k) then return true end
                            return nil
                        end,
                    })
                end
                if key == "FavoritedCosmetics" then
                    local result = data and table.clone(data) or {}
                    for weapon, favs in pairs(favorites) do
                        result[weapon] = result[weapon] or {}
                        for name, isFav in pairs(favs) do
                            local cosmetic = CosmeticLibrary.Cosmetics[name]
                            if isAllowedCosmetic(cosmetic, name) then
                                result[weapon][name] = isFav
                            end
                        end
                    end
                    return result
                end
                return data
            end

            local originalGetWeaponData = DataController.GetWeaponData
            DataController.GetWeaponData = function(self, weaponName)
                local data = originalGetWeaponData(self, weaponName)
                if not data then return nil end
                local merged = {}
                for key, value in pairs(data) do merged[key] = value end
                merged.Name = weaponName
                if equipped[weaponName] then
                    for cosmeticType, cosmeticData in pairs(equipped[weaponName]) do
                        merged[cosmeticType] = cosmeticData
                    end
                end
                return merged
            end

            local FighterController
            pcall(function()
                FighterController = require(controllers:WaitForChild("FighterController", 10))
            end)

            if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
                local remotes = RS:FindFirstChild("Remotes")
                local dataRemotes = remotes and remotes:FindFirstChild("Data")
                local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
                local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
                local useItemRemote = nil
                pcall(function()
                    useItemRemote = remotes.Replication.Fighter.UseItem
                end)

                if equipRemote then
                    local oldNamecall
                    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                        if getnamecallmethod() ~= "FireServer" then
                            return oldNamecall(self, ...)
                        end
                        local args = {...}
                        if useItemRemote and self == useItemRemote and FighterController then
                            pcall(function()
                                local objectID = args[1]
                                local fighter = FighterController:GetFighter(player)
                                if fighter and fighter.Items then
                                    for _, item in pairs(fighter.Items) do
                                        if item:Get("ObjectID") == objectID then
                                            lastUsedWeapon = item.Name
                                            break
                                        end
                                    end
                                end
                            end)
                        end
                        if self == equipRemote then
                            local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                            local cosmetic = CosmeticLibrary.Cosmetics[cosmeticName]
                            if not isAllowedCosmetic(cosmetic, cosmeticName) and cosmeticType ~= "Skin" and cosmeticType ~= "Charm"
                                and cosmeticType ~= "Dance" and cosmeticType ~= "Emote" and cosmeticType ~= "Wrap" and cosmeticType ~= "Wrapping" then
                                return oldNamecall(self, ...)
                            end
                            if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                                local inventory = DataController:Get("CosmeticInventory")
                                if inventory and rawget(inventory, cosmeticName) then
                                    return oldNamecall(self, ...)
                                end
                            end
                            equipped[weaponName] = equipped[weaponName] or {}
                            if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                                equipped[weaponName][cosmeticType] = nil
                                if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                            else
                                local cloned = cloneCosmetic(cosmeticName, cosmeticType, {
                                    inverted = options.IsInverted,
                                    favoritesOnly = options.OnlyUseFavorites,
                                })
                                if cloned then equipped[weaponName][cosmeticType] = cloned end
                            end
                            task.defer(function()
                                pcall(function() DataController.CurrentData:Replicate("WeaponInventory") end)
                                task.wait(0.2)
                                saveConfig()
                            end)
                            return
                        end
                        if self == favoriteRemote then
                            local cosmetic = CosmeticLibrary.Cosmetics[args[2]]
                            if isAllowedCosmetic(cosmetic, args[2]) then
                                favorites[args[1]] = favorites[args[1]] or {}
                                favorites[args[1]][args[2]] = args[3] or nil
                                saveConfig()
                                task.spawn(function()
                                    pcall(function() DataController.CurrentData:Replicate("FavoritedCosmetics") end)
                                end)
                            end
                            return
                        end
                        return oldNamecall(self, ...)
                    end)
                end
            end

            local ClientItem
            pcall(function()
                ClientItem = require(player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
            end)

            if ClientItem and ClientItem._CreateViewModel then
                local originalCreateViewModel = ClientItem._CreateViewModel
                ClientItem._CreateViewModel = function(self, viewmodelRef)
                    local weaponName = self.Name
                    local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
                    constructingWeapon = (weaponPlayer == player) and weaponName or nil
                    if weaponPlayer == player and equipped[weaponName] and viewmodelRef then
                        local cos = equipped[weaponName]
                        pcall(function()
                            local dataKey = self:ToEnum("Data")
                            local data = viewmodelRef[dataKey] or viewmodelRef.Data
                            if data then
                                if cos.Skin then
                                    local skinKey = self:ToEnum("Skin")
                                    data[skinKey] = cos.Skin
                                    data.Skin = cos.Skin
                                end
                                if cos.Charm then
                                    local charmKey = self:ToEnum("Charm")
                                    data[charmKey] = cos.Charm
                                    data.Charm = cos.Charm
                                end
                                if cos.Wrap then
                                    local wrapKey = self:ToEnum("Wrap")
                                    data[wrapKey] = cos.Wrap
                                    data.Wrap = cos.Wrap
                                end
                            end
                        end)
                    end
                    local result = originalCreateViewModel(self, viewmodelRef)
                    constructingWeapon = nil
                    return result
                end
            end

            pcall(function()
                local EmoteController = require(controllers:WaitForChild("EmoteController", 10))
                if EmoteController and EmoteController.GetEmotes then
                    local originalGetEmotes = EmoteController.GetEmotes
                    EmoteController.GetEmotes = function(self)
                        local emotes = originalGetEmotes(self)
                        for name, cosmetic in pairs(CosmeticLibrary.Cosmetics) do
                            if isAllowedCosmetic(cosmetic, name) and (cosmetic.Type == "Dance" or cosmetic.Type == "Emote") then
                                if not emotes[name] then
                                    emotes[name] = {
                                        Name = name,
                                        Type = cosmetic.Type,
                                        ObjectID = cosmetic.ObjectID,
                                        Enum = cosmetic.Enum,
                                    }
                                end
                            end
                        end
                        return emotes
                    end
                end
            end)

            pcall(function()
                local ViewProfile = require(player.PlayerScripts.Modules.Pages.ViewProfile)
                if ViewProfile and ViewProfile.Fetch then
                    local originalFetch = ViewProfile.Fetch
                    ViewProfile.Fetch = function(self, targetPlayer)
                        viewingProfile = targetPlayer
                        return originalFetch(self, targetPlayer)
                    end
                end
            end)

            loadConfig()
            pcall(function()
                nexlib:Notification("unlock all", "skins/charms/dances/wraps unlocked", 3)
            end)
        end)
        if not ok then
            pcall(function()
                nexlib:Notification("unlock all", "failed: " .. tostring(err), 3)
            end)
        end
    end)
end

-----------------------------------------------------------
-- [UI]
-----------------------------------------------------------
local MyGuiWindow = nexlib:Window("hackerblox / 저 옾챗 10월5일까지 정지당함")

local Tabs = {
    ["main"] = MyGuiWindow:Tab("main"),
    ["autofarm"] = MyGuiWindow:Tab("autofarm"),
    ["settings"] = MyGuiWindow:Tab("settings"),
}

local RagebotGroup = Tabs["main"]:Section("ragebot", 1)
RagebotGroup:Toggle("enabled", false, function(v) 
    projectileEnabled = v
    pcall(function() _startRagebot(v or farmRageEnabled) end)
    nexlib:Notification("ragebot", v and "on" or "off", 1.5)
end)
RagebotGroup:Toggle("aimbot", false, function(v)
    aimbotEnabled = v
    nexlib:Notification("aimbot", v and "on" or "off", 1.5)
end)
RagebotGroup:Toggle("wall check", true, function(v)
    aimbotWallCheck = v
    nexlib:Notification("wall check", v and "on" or "off", 1.5)
end)
RagebotGroup:Slider("aim smooth", 0, 90, math.floor(aimbotSmooth * 100), function(v)
    aimbotSmooth = v / 100
end)
RagebotGroup:Slider("aim fov", 0, 500, aimbotFov, function(v)
    aimbotFov = v
end)
RagebotGroup:Toggle("void spam", false, function(v)
    -- Halmu: voidspam cycle + height lock together
    voidSpamEnabled = v
    heightLockEnabled = v
    if not v then
        voidCanAct = true
    end
    nexlib:Notification("void spam", v and "on" or "off", 1.5)
end)
RagebotGroup:Slider("hide", 1, 100, math.floor(voidHideTime * 100), function(v)
    voidHideTime = v / 100
end)
RagebotGroup:Slider("attack", 1, 100, math.floor(voidAttackTime * 100), function(v)
    voidAttackTime = v / 100
end)
RagebotGroup:Slider("void spam studs", 50, 500000, lockHeight, function(v)
    lockHeight = v
end)

local BehindGroup = Tabs["main"]:Section("behind tp", 1)
BehindGroup:Toggle("tp behind", false, function(v)
    behindTPEnabled = v
    nexlib:Notification("tp behind", v and "on" or "off", 1.5)
end)
BehindGroup:Slider("distance", 1, 15, behindTPDistance, function(v)
    behindTPDistance = v
end)

local TeamGroup = Tabs["main"]:Section("team check", 1)
TeamGroup:Toggle("team check", true, function(v)
    teamCheckEnabled = v
    nexlib:Notification("team check", v and "on" or "off", 1.5)
end)

local MatchGroup = Tabs["autofarm"]:Section("auto queue", 1)
MatchGroup:Toggle("enabled", false, function(v)
    autoMatchEnabled = v
    if v then
        startAutoMatch()
        nexlib:Notification("auto queue", autoMatchMode .. " on", 1.5)
    else
        stopAutoMatch()
        nexlib:Notification("auto queue", "off", 1.5)
    end
end)
MatchGroup:Dropdown("Game Mode", MATCH_MODES, autoMatchMode, function(v)
    autoMatchMode = v
    nexlib:Notification("Game Mode", autoMatchMode, 1.2)
end)
MatchGroup:Toggle("collect drops", false, function(v)
    collectDropsEnabled = v
    nexlib:Notification("collect drops", v and "on" or "off", 1.5)
end)
MatchGroup:Toggle("Auto Respawn", false, function(v)
    autoRespawnEnabled = v
    nexlib:Notification("Auto Respawn", v and "on" or "off", 1.5)
end)

local FarmRageGroup = Tabs["autofarm"]:Section("ragebot", 1)
FarmRageGroup:Toggle("enabled", false, function(v)
    farmRageEnabled = v
    pcall(function() _startRagebot(v or projectileEnabled) end)
    nexlib:Notification("farm ragebot", v and "height 18 on" or "off", 1.5)
end)
FarmRageGroup:Label("same as main · tp height 18")

local AutoBanGroup = Tabs["autofarm"]:Section("auto ban", 2)
AutoBanGroup:Toggle("enabled", false, function(v)
    autoBanEnabled = v
    nexlib:Notification("auto ban", v and "on" or "off", 1.5)
end)
AutoBanGroup:Label("select weapons to ban")
for _, weaponName in ipairs(BAN_WEAPON_LIST) do
    local defaultOn = banSelected[weaponName] == true
    AutoBanGroup:Toggle(weaponName, defaultOn, function(v)
        banSelected[weaponName] = v
        if v then
            nexlib:Notification("ban list", weaponName .. " +", 1.0)
        else
            nexlib:Notification("ban list", weaponName .. " -", 1.0)
        end
    end)
end

local CosmeticGroup = Tabs["main"]:Section("cosmetics", 1)
CosmeticGroup:Toggle("unlock all", false, function(v)
    unlockAllEnabled = v
    if v then
        startUnlockAll()
        nexlib:Notification("unlock all", "on", 1.5)
    else
        nexlib:Notification("unlock all", "off (reload to fully reset)", 2)
    end
end)

local WeaponModGroup = Tabs["main"]:Section("weapon mods", 1)
WeaponModGroup:Toggle("fast fire", false, function(v)
    fastFireEnabled = v
    if v then
        pcall(applyFastWeapons)
        nexlib:Notification("fast fire", "on", 1.5)
    else
        if not fastMeleeEnabled then
            pcall(restoreFastWeapons)
        else
            pcall(applyFastWeapons)
        end
        nexlib:Notification("fast fire", "off", 1.5)
    end
end)
WeaponModGroup:Toggle("fast melee", false, function(v)
    fastMeleeEnabled = v
    if v then
        pcall(applyFastWeapons)
        nexlib:Notification("fast melee", "on", 1.5)
    else
        if not fastFireEnabled then
            pcall(restoreFastWeapons)
        else
            pcall(applyFastWeapons)
        end
        nexlib:Notification("fast melee", "off", 1.5)
    end
end)

local MobileSettingGroup = Tabs["main"]:Section("mobile setting", 1)
MobileSettingGroup:Toggle("mobile on", false, function(v)
    local mainFrame = screenGui:FindFirstChild("MainFrame", true)
    if mainFrame then
        mainFrame.ClipsDescendants = true
        local container = mainFrame:FindFirstChild("ContainerHolderFrame")
        if container then
            container.ClipsDescendants = true
            container.Size = UDim2.new(1, -18, 1, -42)
        end
        local tweenService = game:GetService("TweenService")
        local targetSize = v and UDim2.new(0, UI_W, 0, math.floor(UI_H * 0.75)) or UDim2.new(0, UI_W, 0, UI_H)
        tweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = targetSize
        }):Play()
    end
    nexlib:Notification("mobile on", v and "on" or "off", 1.5)
end)

local EspGroup = Tabs["main"]:Section("esp", 2)
EspGroup:Toggle("ESP Active", false, function(v)
    espEnabled = v
    nexlib:Notification("ESP Active", v and "on" or "off", 1.5)
end)
EspGroup:Toggle("Box Display", true, function(v)
    espBoxes = v
    nexlib:Notification("Box Display", v and "on" or "off", 1.5)
end)
EspGroup:Toggle("Name Display", true, function(v)
    espNames = v
    nexlib:Notification("Name Display", v and "on" or "off", 1.5)
end)
EspGroup:Toggle("Health Display", true, function(v)
    espHealth = v
    nexlib:Notification("Health Display", v and "on" or "off", 1.5)
end)
EspGroup:Toggle("Rank Display", true, function(v)
    espRank = v
    nexlib:Notification("Rank Display", v and "on" or "off", 1.5)
end)

local MenuGroup = Tabs["main"]:Section("menu", 2)
MenuGroup:Label("Press [RightShift] to Toggle UI")
MenuGroup:Button("Unload UI", function()
    nexlib:Notification("Shutting Down", "Goodbye!", 1.5)
    task.wait(1.5)
    MyGuiWindow:Destroy()
end)

local SettingsGroup = Tabs["settings"]:Section("script", 1)
SettingsGroup:Label("fully disable this script")
SettingsGroup:Button("unload script", function()
    nexlib:Notification("script", "unloading...", 1.2)

    -- stop all features
    autoMatchEnabled = false
    autoMatchLoop = nil
    collectDropsEnabled = false
    autoRespawnEnabled = false
    autoBanEnabled = false
    fastFireEnabled = false
    fastMeleeEnabled = false
    pcall(restoreFastWeapons)
    projectileEnabled = false
    farmRageEnabled = false
    pcall(function() _startRagebot(false) end)
    aimbotEnabled = false
    behindTPEnabled = false

    voidSpamEnabled = false
    heightLockEnabled = false
    voidCanAct = true
    espEnabled = false

    -- destroy ESP drawings
    pcall(function()
        if espGui then espGui:Destroy() end
    end)

    -- destroy toggle button UI
    pcall(function()
        local parent = SAFE_GUI_PARENT
        if parent and parent:FindFirstChild("ExecutorToggleUI") then
            parent.ExecutorToggleUI:Destroy()
        end
        local cg = game:GetService("CoreGui")
        if cg:FindFirstChild("ExecutorToggleUI") then
            cg.ExecutorToggleUI:Destroy()
        end
    end)

    -- destroy main UI / blur
    pcall(function()
        MyGuiWindow:Destroy()
    end)

    -- destroy nexlib screen gui if still present
    pcall(function()
        if screenGui then screenGui:Destroy() end
        local parent = SAFE_GUI_PARENT
        if parent and parent:FindFirstChild("nexlib") then
            parent.nexlib:Destroy()
        end
        local cg = game:GetService("CoreGui")
        if cg:FindFirstChild("nexlib") then
            cg.nexlib:Destroy()
        end
    end)
end)

-----------------------------------------------------------
-- [ESP]
-----------------------------------------------------------
local espGui = Instance.new("ScreenGui")
espGui.Name = "HalmuESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 40
pcall(function() espGui.Parent = SAFE_GUI_PARENT end)
if not espGui.Parent then
    pcall(function() espGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
end

local cache = {}
local function createEsp(player)
    if cache[player] then return end

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = espGui
    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1
    boxStroke.Color = Color3.fromRGB(255, 70, 70)
    boxStroke.Parent = box

    local name = Instance.new("TextLabel")
    name.Name = "Name"
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.Code
    name.TextSize = 13
    name.TextColor3 = Color3.fromRGB(255, 255, 255)
    name.TextStrokeTransparency = 0
    name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.Size = UDim2.new(0, 160, 0, 16)
    name.Visible = false
    name.Parent = espGui

    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    healthBg.BackgroundTransparency = 0.35
    healthBg.BorderSizePixel = 0
    healthBg.Visible = false
    healthBg.Parent = espGui

    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Visible = false
    healthBar.Parent = espGui

    local rank = Instance.new("TextLabel")
    rank.Name = "Rank"
    rank.BackgroundTransparency = 1
    rank.Font = Enum.Font.Code
    rank.TextSize = 12
    rank.TextColor3 = Color3.fromRGB(255, 220, 120)
    rank.TextStrokeTransparency = 0
    rank.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    rank.TextXAlignment = Enum.TextXAlignment.Center
    rank.Size = UDim2.new(0, 180, 0, 14)
    rank.Visible = false
    rank.Parent = espGui

    cache[player] = {
        Box = box,
        BoxStroke = boxStroke,
        Name = name,
        HealthBg = healthBg,
        HealthBar = healthBar,
        Rank = rank,
    }
end

local function removeEsp(player)
    if cache[player] then
        for k, d in pairs(cache[player]) do
            if typeof(d) == "Instance" then
                pcall(function() d:Destroy() end)
            end
        end
        cache[player] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createEsp(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then createEsp(p) end
end)
Players.PlayerRemoving:Connect(removeEsp)

RunService.RenderStepped:Connect(function()
    Camera = workspace.CurrentCamera or Camera
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for player, drawings in pairs(cache) do
        local box, name, healthBg, healthBar = drawings.Box, drawings.Name, drawings.HealthBg, drawings.HealthBar
        local rankLabel = drawings.Rank
        local boxStroke = drawings.BoxStroke
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HitboxHead") or hrp)

        local function hideAll()
            box.Visible = false
            name.Visible = false
            healthBg.Visible = false
            healthBar.Visible = false
            if rankLabel then rankLabel.Visible = false end
        end

        if espEnabled and hrp and hum and head and hum.Health > 0 then
            local topPos = head.Position + Vector3.new(0, 0.6, 0)
            local bottomPos = hrp.Position - Vector3.new(0, 3, 0)
            local top, onTop = Camera:WorldToViewportPoint(topPos)
            local bottom, onBot = Camera:WorldToViewportPoint(bottomPos)
            local mid, onMid = Camera:WorldToViewportPoint(hrp.Position)

            if (onMid or onTop or onBot) and mid.Z > 0 then
                local height = math.abs(top.Y - bottom.Y)
                if height < 8 then height = 40 end
                local width = height * 0.55
                local boxX = mid.X - width / 2
                local boxY = top.Y

                if espBoxes then
                    box.Size = UDim2.fromOffset(width, height)
                    box.Position = UDim2.fromOffset(boxX, boxY)
                    local col = isSameTeam(player) and Color3.fromRGB(80, 160, 255) or Color3.fromRGB(255, 70, 70)
                    if boxStroke then boxStroke.Color = col end
                    box.Visible = true
                else
                    box.Visible = false
                end

                if espNames then
                    local distStr = ""
                    if myHrp then
                        distStr = " [" .. math.floor((hrp.Position - myHrp.Position).Magnitude) .. "m]"
                    end
                    name.Text = (player.DisplayName or player.Name) .. distStr
                    name.Position = UDim2.fromOffset(mid.X - 80, boxY - 16)
                    name.TextColor3 = isSameTeam(player) and Color3.fromRGB(120, 180, 255) or Color3.fromRGB(255, 255, 255)
                    name.Visible = true
                else
                    name.Visible = false
                end

                if espHealth then
                    local healthRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    healthBg.Size = UDim2.fromOffset(3, height)
                    healthBg.Position = UDim2.fromOffset(boxX - 6, boxY)
                    healthBg.Visible = true
                    local barH = math.max(height * healthRatio, 1)
                    healthBar.Size = UDim2.fromOffset(3, barH)
                    healthBar.Position = UDim2.fromOffset(boxX - 6, boxY + (height - barH))
                    healthBar.BackgroundColor3 = Color3.fromHSV(healthRatio * 0.33, 1, 1)
                    healthBar.Visible = true
                else
                    healthBg.Visible = false
                    healthBar.Visible = false
                end

                if espRank and rankLabel then
                    local rankText = getRankDisplay(player)
                    if rankText then
                        rankLabel.Text = rankText
                        rankLabel.Position = UDim2.fromOffset(mid.X - 90, boxY + height + 2)
                        rankLabel.TextColor3 = isSameTeam(player) and Color3.fromRGB(140, 190, 255) or Color3.fromRGB(255, 220, 120)
                        rankLabel.Visible = true
                    else
                        rankLabel.Visible = false
                    end
                elseif rankLabel then
                    rankLabel.Visible = false
                end
            else
                hideAll()
            end
        else
            hideAll()
        end
    end
end)
