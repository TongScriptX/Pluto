-- PlutoUILibrary.lua
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local UILibrary = {}

-- 默认主题
local DEFAULT_THEME = {
    Primary = Color3.fromRGB(63, 81, 181),
    Background = Color3.fromRGB(30, 30, 30),
    SecondaryBackground = Color3.fromRGB(46, 46, 46),
    Accent = Color3.fromRGB(92, 107, 192),
    Text = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54),
    Font = Enum.Font.Roboto
}

-- 备选字体
local function getAvailableFont()
    local fonts = {Enum.Font.Roboto, Enum.Font.Arial}
    for _, font in ipairs(fonts) do
        local success = pcall(function()
            local label = Instance.new("TextLabel")
            label.Font = font
            label.Text = "Test"
            label:Destroy()
        end)
        if success then
            return font
        end
    end
    return Enum.Font.SourceSans
end

-- 当前主题
local THEME = {
    Primary = DEFAULT_THEME.Primary,
    Background = DEFAULT_THEME.Background,
    SecondaryBackground = DEFAULT_THEME.SecondaryBackground,
    Accent = DEFAULT_THEME.Accent,
    Text = DEFAULT_THEME.Text,
    Success = DEFAULT_THEME.Success,
    Error = DEFAULT_THEME.Error,
    Font = getAvailableFont()
}

-- 动画配置
local TWEEN_INFO_UI = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local TWEEN_INFO_BUTTON = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- 通知容器
local notificationContainer = nil
local screenGui = nil

-- 初始化通知容器
local function initNotificationContainer()
    if not screenGui or not screenGui.Parent then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "UILibrary"
        local success, err = pcall(function()
            screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 15)
        end)
        if not success then
            warn("[Notification]: ScreenGui Initialization Failed: " .. tostring(err))
            return false
        end
        screenGui.ResetOnSpawn = false
        screenGui.Enabled = true
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        print("[Notification]: ScreenGui Created: Parent =", screenGui.Parent and screenGui.Parent.Name or "nil", "Enabled =", screenGui.Enabled)
    end

    if not notificationContainer or not notificationContainer.Parent then
        notificationContainer = Instance.new("Frame")
        notificationContainer.Name = "NotificationContainer"
        notificationContainer.Size = UDim2.new(0, 180, 0, 240)
        notificationContainer.Position = UDim2.new(1, -190, 1, -250)
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.Parent = screenGui
        notificationContainer.Visible = true
        notificationContainer.ZIndex = 3

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 5)
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.Parent = notificationContainer

        print("[Notification]: Container Created: Parent =", notificationContainer.Parent and notificationContainer.Parent.Name or "nil", "Visible =", notificationContainer.Visible)
    end
    return true
end

-- 通知模块
function UILibrary:Notify(options)
    options = options or {}
    if not initNotificationContainer() then
        warn("[Notification]: Failed: Unable to initialize ScreenGui")
        return nil
    end

    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 180, 0, 40)
    notification.BackgroundColor3 = THEME.Background
    notification.BackgroundTransparency = 0.3
    notification.Position = UDim2.new(0, 0, 0, 90)
    notification.Parent = notificationContainer
    notification.Visible = true
    notification.ZIndex = 4
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = notification

    local titleLabel = self:CreateLabel(notification, {
        Text = options.Title or "Notification",
        Position = UDim2.new(0, 5, 0, 5),
        Size = UDim2.new(1, -10, 0, 15),
        TextSize = 12
    })

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Position = UDim2.new(0, 5, 0, 20),
        Size = UDim2.new(1, -10, 0, 15),
        TextSize = 12
    })

    wait(0.1)
    local success, err = pcall(function()
        local tween = TweenService:Create(notification, TWEEN_INFO_UI, { Position = UDim2.new(0, 0, 0, 50) })
        tween:Play()
    end)
    if not success then
        warn("[Notification]: Animation Failed: " .. tostring(err))
        notification.Position = UDim2.new(0, 0, 0, 50)
    end

    spawn(function()
        wait(options.Duration or 3)
        if notification.Parent then
            local success, err = pcall(function()
                local tween = TweenService:Create(notification, TWEEN_INFO_UI, { Position = UDim2.new(0, 0, 0, 90) })
                tween:Play()
                tween.Completed:Wait()
            end)
            if not success then
                warn("[Notification]: Exit Animation Failed: " .. tostring(err))
            end
            notification:Destroy()
            print("[Notification]: Destroyed: Title =", options.Title)
        end
    end)

    print("[Notification]: Created: Title =", options.Title, "Text =", options.Text, "Visible =", notification.Visible)
    return notification
end

-- 创建卡片
function UILibrary:CreateCard(parent, options)
    if not parent then
        warn("[Card]: Creation Failed: Parent is nil")
        return nil
    end
    options = options or {}
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(1, -10, 0, options.Height or 60)
    card.BackgroundColor3 = THEME.SecondaryBackground
    card.BackgroundTransparency = 1
    card.Parent = parent
    card.Visible = true
    card.ZIndex = 2
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = card
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 5)
    padding.PaddingRight = UDim.new(0, 5)
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 5)
    padding.Parent = card

    card.Position = UDim2.new(0, 5, 0, 5)
    TweenService:Create(card, TWEEN_INFO_UI, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.3 }):Play()

    print("[Card]: Created: Parent =", parent and parent.Name or "nil", "Visible =", card.Visible, "Position =", tostring(card.Position), "Size =", tostring(card.Size))
    return card
end

-- 按钮模块
function UILibrary:CreateButton(parent, options)
    if not parent then
        warn("[Button]: Creation Failed: Parent is nil")
        return nil
    end
    options = options or {}
    local button = Instance.new("TextButton")
    button.Name = "Button_" .. (options.Text or "Unnamed")
    button.Size = options.Size or UDim2.new(1, -10, 0, 25)
    button.BackgroundColor3 = options.BackgroundColor3 or THEME.Primary
    button.BackgroundTransparency = options.BackgroundTransparency or 0.5
    button.Text = options.Text or ""
    button.TextColor3 = THEME.Text
    button.TextSize = 12
    button.Font = THEME.Font
    button.Parent = parent
    button.Visible = true
    button.ZIndex = 2
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    if options.Callback then
        button.MouseButton1Click:Connect(function()
            local originalSize = button.Size
            TweenService:Create(button, TWEEN_INFO_BUTTON, { Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * 0.95, originalSize.Y.Scale, originalSize.Y.Offset * 0.95) }):Play()
            wait(0.1)
            TweenService:Create(button, TWEEN_INFO_BUTTON, { Size = originalSize }):Play()
            options.Callback()
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TWEEN_INFO_BUTTON, { BackgroundColor3 = THEME.Accent }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TWEEN_INFO_BUTTON, { BackgroundColor3 = options.BackgroundColor3 or THEME.Primary }):Play()
    end)

    print("[Button]: Created: Text =", options.Text, "Parent =", parent and parent.Name or "nil", "Visible =", button.Visible, "Position =", tostring(button.Position))
    return button
end

-- 悬浮按钮模块
function UILibrary:CreateFloatingButton(parent, options)
    if not parent then
        warn("[FloatingButton]: Creation Failed: Parent is nil")
        return nil
    end
    options = options or {}
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
        warn("[FloatingButton]: Failed to get screen resolution, using default: 720x1280")
    end
    print("[FloatingButton]: Screen Resolution:", screenSize.X, screenSize.Y)

    local button = Instance.new("TextButton")
    button.Name = "FloatingButton"
    button.Size = UDim2.new(0, 30, 0, 30)
    button.Position = UDim2.new(1, -40, 1, -40)
    button.BackgroundColor3 = THEME.Primary
    button.BackgroundTransparency = 0.5
    button.Text = options.Text or "O"
    button.TextColor3 = THEME.Text
    button.TextSize = 12
    button.Font = THEME.Font
    button.Parent = parent
    button.Visible = true
    button.ZIndex = 2
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = button

    local mainFrame = options.MainFrame
    local originalSize = mainFrame and mainFrame.Size or UDim2.new(0, 400, 0, 300)
    if mainFrame then
        button.MouseButton1Click:Connect(function()
            local isVisible = not mainFrame.Visible
            button.Text = isVisible and "X" or options.Text
            mainFrame.Visible = true -- Ensure visible before tween
            TweenService:Create(mainFrame, TWEEN_INFO_UI, {
                Size = isVisible and originalSize or UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = isVisible and 0.5 or 1
            }):Play()
            if not isVisible then
                mainFrame.Visible = false -- Hide after tween
            end
            TweenService:Create(button, TWEEN_INFO_BUTTON, { Rotation = isVisible and 45 or 0 }):Play()
            print("[FloatingButton]: Clicked: MainFrame Visible =", isVisible)
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TWEEN_INFO_BUTTON, { BackgroundColor3 = THEME.Accent }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TWEEN_INFO_BUTTON, { BackgroundColor3 = THEME.Primary }):Play()
    end)

    self:MakeDraggable(button)
    print("[FloatingButton]: Created: Parent =", parent and parent.Name or "nil", "Visible =", button.Visible, "Position =", tostring(button.Position))
    return button
end

-- 文本标签模块
function UILibrary:CreateLabel(parent, options)
    if not parent then
        warn("[Label]: Creation Failed: Parent is nil")
        return nil
    end
    options = options or {}
    local label = Instance.new("TextLabel")
    label.Name = "Label_" .. (options.Text or "Unnamed")
    label.Size = options.Size or UDim2.new(1, -10, 0, 15)
    label.Position = options.Position or UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = options.Text or ""
    label.TextColor3 = THEME.Text
    label.TextSize = options.TextSize or 12
    label.Font = THEME.Font
    label.TextWrapped = true
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
    label.Parent = parent
    label.Visible = true
    label.ZIndex = 2

    local success, err = pcall(function()
        TweenService:Create(label, TWEEN_INFO_UI, { TextTransparency = 0 }):Play()
    end)
    if not success then
        warn("[Label]: Animation Failed: " .. tostring(err))
    end

    print("[Label]: Created: Text =", options.Text, "Parent =", parent and parent.Name or "nil", "Visible =", label.Visible, "Position =", tostring(label.Position))
    return label
end

-- 输入框模块
function UILibrary:CreateTextBox(parent, options)
    if not parent then
        warn("[TextBox]: Creation Failed: Parent is nil")
        return nil
    end

    options = options or {}
    local textBox = Instance.new("TextBox")
    textBox.Name = "TextBox_" .. (options.PlaceholderText or "Unnamed")
    textBox.Size = UDim2.new(1, -10, 0, 25)
    textBox.BackgroundColor3 = THEME.SecondaryBackground
    textBox.BackgroundTransparency = 0.3
    textBox.TextColor3 = THEME.Text
    textBox.TextSize = 12
    textBox.Font = THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = 1
    textBox.BorderColor3 = THEME.Background
    textBox.Parent = parent
    textBox.Visible = true
    textBox.ZIndex = 2

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = textBox

    textBox.Focused:Connect(function()
        TweenService:Create(textBox, TWEEN_INFO_BUTTON, { BorderColor3 = THEME.Primary }):Play()
    end)

    textBox.FocusLost:Connect(function()
        TweenService:Create(textBox, TWEEN_INFO_BUTTON, { BorderColor3 = THEME.Background }):Play()
        if options.OnFocusLost then
            options.OnFocusLost()
        end
    end)

    print("[TextBox]: Created: Placeholder =", options.PlaceholderText, "Parent =", parent and parent.Name or "nil", "Visible =", textBox.Visible)
    return textBox
end

-- 开关模块
function UILibrary:CreateToggle(parent, options)
    if not parent then
        warn("[Toggle]: Creation Failed: Parent is nil")
        return nil
    end
    options = options or {}
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "Toggle_" .. (options.Text or "Unnamed")
    toggleFrame.Size = UDim2.new(1, -10, 0, 25)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent
    toggleFrame.Visible = true
    toggleFrame.ZIndex = 2

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, 0, 1, 0),
        TextSize = 12
    })

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 30, 0, 8)
    track.Position = UDim2.new(0.65, 0, 0.5, -4)
    track.BackgroundColor3 = options.DefaultState and THEME.Success or THEME.Error
    track.Parent = toggleFrame
    track.Visible = true
    track.ZIndex = 2
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 4)
    trackCorner.Parent = track

    local thumb = Instance.new("TextButton")
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 15, 0, 15)
    thumb.Position = options.DefaultState and UDim2.new(0, 15, 0, -4) or UDim2.new(0, 0, 0, -4)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.Text = ""
    thumb.Parent = track
    thumb.Visible = true
    thumb.ZIndex = 2
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 8)
    thumbCorner.Parent = thumb

    local state = options.DefaultState or false
    thumb.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0, 15, 0, -4) or UDim2.new(0, 0, 0, -4)
        local targetColor = state and THEME.Success or THEME.Error
        TweenService:Create(thumb, TWEEN_INFO_BUTTON, { Position = targetPos }):Play()
        TweenService:Create(track, TWEEN_INFO_BUTTON, { BackgroundColor3 = targetColor }):Play()
        if options.Callback then
            options.Callback(state)
        end
    end)

    print("[Toggle]: Created: Text =", options.Text, "Parent =", parent and parent.Name or "nil", "Visible =", toggleFrame.Visible)
    return toggleFrame, state
end

-- 拖拽模块
function UILibrary:MakeDraggable(gui)
    if not gui then
        warn("[MakeDraggable]: Failed: GUI is nil")
        return
    end
    local dragging = false
    local startPos, startGuiPos

    local function isMouseOverGui(input)
        local pos = input.Position
        local guiPos = gui.AbsolutePosition
        local guiSize = gui.AbsoluteSize
        return pos.X >= guiPos.X and pos.X <= guiPos.X + guiSize.X and pos.Y >= guiPos.Y and pos.Y <= guiPos.Y + guiSize.Y
    end

    gui.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isMouseOverGui(input) then
            dragging = true
            startPos = input.Position
            startGuiPos = gui.Position
            print("[MakeDraggable]: Drag Started: GUI =", gui.Name, "Input =", input.UserInputType.Name)
        end
    end)

    gui.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startPos
            local newPos = UDim2.new(
                startGuiPos.X.Scale, startGuiPos.X.Offset + delta.X,
                startGuiPos.Y.Scale, startGuiPos.Y.Offset + delta.Y
            )
            local screenSize = GuiService:GetScreenResolution()
            if screenSize == Vector2.new(0, 0) then
                screenSize = Vector2.new(720, 1280)
                warn("[MakeDraggable]: Invalid screenSize, using default: 720x1280")
            end
            local guiSize = gui.AbsoluteSize
            local maxX = math.max(0, screenSize.X - math.max(guiSize.X, 1))
            local maxY = math.max(0, screenSize.Y - math.max(guiSize.Y, 1))
            newPos = UDim2.new(
                0, math.clamp(newPos.X.Offset, 0, maxX),
                0, math.clamp(newPos.Y.Offset, 0, maxY)
            )
            gui.Position = newPos
        end
    end)

    gui.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            print("[MakeDraggable]: Drag Ended: GUI =", gui.Name)
        end
    end)

    print("[MakeDraggable]: Applied: GUI =", gui.Name)
end

-- 主窗口模块
function UILibrary:CreateWindow(options)
    options = options or {}
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
        warn("[Window]: Failed to get screen resolution, using default: 720x1280")
    end
    local windowWidth = math.min(400, screenSize.X * 0.9)
    local windowHeight = math.min(300, screenSize.Y * 0.9)
    print("[Window]: Screen Resolution:", screenSize.X, screenSize.Y, "Window Size:", windowWidth, "x", windowHeight)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UILibraryWindow"
    local success, err = pcall(function()
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 15)
    end)
    if not success then
        warn("[Window]: ScreenGui Initialization Failed: " .. tostring(err))
        return nil, nil, nil, nil, nil
    end
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    print("[Window]: ScreenGui Created: Parent =", screenGui.Parent and screenGui.Parent.Name or "nil", "Enabled =", screenGui.Enabled)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, windowWidth, 0, windowHeight)
    mainFrame.Position = UDim2.new(0.5, -windowWidth / 2, 0.5, -windowHeight / 2)
    mainFrame.BackgroundColor3 = THEME.Background
    mainFrame.BackgroundTransparency = 0.5
    mainFrame.Parent = screenGui
    mainFrame.Visible = true
    mainFrame.ZIndex = 1
    mainFrame.ClipsDescendants = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = mainFrame

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 80, 1, 0)
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sidebar.Parent = mainFrame
    sidebar.Visible = true
    sidebar.ZIndex = 2
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 6)
    sidebarCorner.Parent = sidebar

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, 5)
    sidebarLayout.Parent = sidebar
    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingLeft = UDim.new(0, 5)
    sidebarPadding.PaddingRight = UDim.new(0, 5)
    sidebarPadding.PaddingTop = UDim.new(0, 5)
    sidebarPadding.Parent = sidebar

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(0, windowWidth - 80, 0, 30)
    titleBar.Position = UDim2.new(0, 80, 0, 0)
    titleBar.BackgroundColor3 = THEME.Primary
    titleBar.Parent = mainFrame
    titleBar.Visible = true
    titleBar.ZIndex = 2
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 6)
    titleCorner.Parent = titleBar

    local titleLabel = self:CreateLabel(titleBar, {
        Text = "Home",
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextSize = 14
    })
    if not titleLabel then
        warn("[Window]: TitleLabel Creation Failed")
        titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Label_Home"
        titleLabel.Size = UDim2.new(1, 0, 1, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "Home"
        titleLabel.TextColor3 = THEME.Text
        titleLabel.TextSize = 14
        titleLabel.Font = THEME.Font
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.Parent = titleBar
        titleLabel.Visible = true
        titleLabel.ZIndex = 2
    end

    local mainPage = Instance.new("ScrollingFrame")
    mainPage.Name = "MainPage"
    mainPage.Size = UDim2.new(0, windowWidth - 80, 0, windowHeight - 30)
    mainPage.Position = UDim2.new(0, 80, 0, 30)
    mainPage.BackgroundColor3 = THEME.SecondaryBackground
    mainPage.BackgroundTransparency = 0.5
    mainPage.ScrollBarThickness = 4
    mainPage.CanvasSize = UDim2.new(0, 0, 0, 100)
    mainPage.Parent = mainFrame
    mainPage.Visible = true
    mainPage.ZIndex = 2
    local pageCorner = Instance.new("UICorner")
    pageCorner.CornerRadius = UDim.new(0, 6)
    pageCorner.Parent = mainPage

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 5)
    pageLayout.Parent = mainPage
    pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        mainPage.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 10)
    end)

    local originalSize = mainFrame.Size
    mainFrame.Size = UDim2.new(0, windowWidth - 20, 0, windowHeight - 15)
    TweenService:Create(mainFrame, TWEEN_INFO_UI, { Size = originalSize }):Play()

    if not mainFrame or not screenGui or not sidebar or not titleLabel or not mainPage then
        warn("[Window]: Incomplete Return Values: mainFrame =", mainFrame, "screenGui =", screenGui, "sidebar =", sidebar, "titleLabel =", titleLabel, "mainPage =", mainPage)
        return nil, nil, nil, nil, nil
    end

    print("[Window]: Created: mainFrame =", mainFrame.Name, "Visible =", mainFrame.Visible, "Size =", tostring(mainFrame.Size), "Position =", tostring(mainFrame.Position))
    print("[Sidebar]: Created: Visible =", sidebar.Visible, "Position =", tostring(sidebar.Position), "ZIndex =", sidebar.ZIndex)
    print("[TitleBar]: Created: Visible =", titleBar.Visible, "Position =", tostring(titleBar.Position), "Size =", tostring(titleBar.Size))
    print("[MainPage]: Created: Visible =", mainPage.Visible, "Position =", mainPage.Position, "ZIndex =", mainPage.Position)
    return mainFrame, screenGui, sidebar, titleLabel, mainPage
end

-- 标签页模块
function UILibrary:CreateTab(sidebar, titleLabel, mainPage, options)
    if not sidebar or not mainPage or not titleLabel then
        warn("[Tab]: Creation Failed: Invalid sidebar, mainPage, or titleLabel")
        return nil, nil
    end
    options = options or {}
    local tabButton = self:CreateButton(sidebar, {
        Text = options.Text or "",
        Size = UDim2.new(1, -10, 0, 30),
        BackgroundColor3 = options.Active and THEME.Accent or THEME.Primary,
        BackgroundTransparency = options.Active and 0 or 0.5
    })
    if not tabButton then
        warn("[Tab]: Creation Failed: tabButton is nil")
        return nil, nil
    local content = Instance.new("ScrollingFrame")
    content.Name = "TabContent_" .. (options.Text or "Unnamed")
    content.Size = UDim2.new(1, -10, 0, 0)
    content.Position = UDim2.new(options.Active and 0 or 1, 0, 0, 0)
    content.BackgroundColor3 = THEME.BackgroundTransparency
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 4
    content.CanvasSize = UDim2.new(0, 0, 0, 100)
    content.Visible = options.Active or false
    content.Parent = mainPage
    content.ZIndex = 2

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = content
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)

    tabButton.MouseButton1Click:Connect(function()
        for _, child in ipairs(mainPage:GetChildren()) do
            if child:IsA("ScrollingFrame") then
                TweenService:Create(child, TWEEN_INFO_UI, { Position = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }):Play()
                wait(0.3)
                child.Visible = false
            end
        end
        content.Position = UDim2.new(-1, 0, 0, 0)
        content.Visible = true
        TweenService:Create(content, TWEEN_INFO_UI, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.5 }):Play()
        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                TweenService:Create(btn, TWEEN_INFO_BUTTON, {
                    BackgroundColor3 = btn == tabButton and THEME.Accent or THEME.Primary,
                    BackgroundTransparency = btn == tabButton and 0 or 0.5
                }):Play()
            end
        end
        titleLabel.Text = options.Text
        print("[Tab]: Switched: Text =", options.Text, "Content Visible =", content.Visible)
    end)

    print("[Tab]: Created: Text =", options.Text, "Content Visible =", content.Visible, "Parent =", content.Parent and content.Parent.Name or "nil")
    return tabButton, content
end

-- 作者介绍模块
function UILibrary:CreateAuthorInfo(parent, options)
    if not parent then
        warn("[AuthorInfo]: Creation Failed: Parent is nil")
        return nil
    end
    options = options or {}
    local authorFrame = Instance.new("Frame")
    authorFrame.Name = "AuthorFrame"
    authorFrame.Size = UDim2.new(1, -10, 0, 50)
    authorFrame.BackgroundColor3 = THEME.SecondaryBackground
    authorFrame.BackgroundTransparency = 0.3
    authorFrame.Parent = parent
    authorFrame.Visible = true
    authorFrame.ZIndex = 2
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = authorFrame

    local authorLabel = self:CreateLabel(authorFrame, {
        Text = options.Text or "",
        Size = UDim2.new(1, -10, 0, 15),
        TextSize = 12
    })

    local socialButton = self:CreateButton(authorFrame, {
        Text = options.SocialText or "",
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 5, 0, 20),
        Callback = options.SocialCallback
    })

    print("[AuthorInfo]: Created: Parent =", parent and parent.Name or "nil", "Visible =", authorFrame.Visible)
    return authorFrame
end

-- 主题切换模块
function UILibrary:SetTheme(newTheme)
    newTheme = newTheme or {}
    THEME = {
        Primary = newTheme.Primary or DEFAULT_THEME.Primary,
        Background = newTheme.Background or DEFAULT_THEME.Background,
        SecondaryBackground = newTheme.SecondaryBackground or DEFAULT_THEME.SecondaryBackground,
        Accent = newTheme.Accent or DEFAULT_THEME.Accent,
        Text = newTheme.Text or DEFAULT_THEME.Text,
        Success = newTheme.Success or DEFAULT_THEME.Success,
        Error = newTheme.Error or DEFAULT_THEME.Error,
        Font = newTheme.Font or getAvailableFont()
    }
    print("[Theme]: Set: Primary =", tostring(THEME.Primary))
end

return UILibrary
