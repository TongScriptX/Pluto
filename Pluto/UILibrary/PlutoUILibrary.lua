-- PlutoUILibrary.lua
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local UILibrary = {}

-- 默认主题
local DEFAULT_THEME = {
    Primary = Color3.fromRGB(63, 81, 181), -- #3F51B5
    Background = Color3.fromRGB(30, 30, 30), -- #1E1E1E
    SecondaryBackground = Color3.fromRGB(46, 46, 46), -- #2E2E2E
    Accent = Color3.fromRGB(92, 107, 192), -- #5C6BC0
    Text = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54),
    Font = Enum.Font.Roboto -- 使用 Roboto
}

-- 备选字体
local function getAvailableFont()
    local fonts = {Enum.Font.Roboto, Enum.Font.Arial}
    for _, font in ipairs(fonts) do
        local success = pcall(function()
            local label = Instance.new("TextLabel")
            label.Font = font
            label.Text = "Test"
            label.Parent = nil
            label:Destroy()
        end)
        if success then
            return font
        end
    end
    return Enum.Font.SourceSans -- 最终备选
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
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local TOGGLE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- 通知容器
local notificationContainer = nil
local screenGui = nil

-- 初始化通知容器
local function initNotificationContainer()
    if not screenGui or not screenGui.Parent then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "UILibrary"
        local success, err = pcall(function()
            screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
        end)
        if not success or not screenGui.Parent then
            warn("ScreenGui Initialization Failed: " .. tostring(err))
            return false
        end
        screenGui.ResetOnSpawn = false
        screenGui.Enabled = true
        print("ScreenGui Created: Parent =", screenGui.Parent and screenGui.Parent.Name or "No parent")
    end

    if not notificationContainer or not notificationContainer.Parent then
        notificationContainer = Instance.new("Frame")
        notificationContainer.Size = UDim2.new(0, 300, 0, 360)
        notificationContainer.Position = UDim2.new(1, -310, 1, -370) -- 右下角
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.Parent = screenGui
        notificationContainer.Visible = true

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 10)
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.Parent = notificationContainer

        print("Notification Container Created: Parent =", notificationContainer.Parent and notificationContainer.Parent.Name or "No parent")
    end
    return true
end

-- 通知模块
function UILibrary:Notify(options)
    options = options or {}
    if not initNotificationContainer() then
        warn("Notification Failed: Unable to initialize ScreenGui or notificationContainer")
        return nil
    end

    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 280, 0, 60)
    notification.BackgroundColor3 = THEME.Background
    notification.BackgroundTransparency = 0.3
    notification.Position = UDim2.new(0, 10, 0, 130)
    notification.Parent = notificationContainer
    notification.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notification

    local titleLabel = self:CreateLabel(notification, {
        Text = options.Title or "Notification",
        Position = UDim2.new(0, 10, 0, 5)
    })

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Position = UDim2.new(0, 10, 0, 25)
    })

    -- 滑入动画
    wait(0.1)
    local success, err = pcall(function()
        local tween = TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, 70) })
        tween:Play()
    end)
    if not success then
        warn("Notification Animation Failed: " .. tostring(err))
        notification.Position = UDim2.new(0, 10, 0, 70)
    end

    -- 自动消失
    spawn(function()
        wait(options.Duration or 3)
        if notification.Parent then
            local success, err = pcall(function()
                local tween = TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, 130) })
                tween:Play()
                tween.Completed:Wait()
            end)
            if not success then
                warn("Notification Animation (Exit) Failed: " .. tostring(err))
            end
            notification:Destroy()
            print("Notification Destroyed")
        end
    end)

    print("Notification Created: Title =", options.Title, "Text =", options.Text)
    return notification
end

-- 创建卡片
function UILibrary:CreateCard(parent, options)
    options = options or {}
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -20, 0, options.Height or 80)
    card.BackgroundColor3 = THEME.SecondaryBackground
    card.BackgroundTransparency = 0.3
    card.Parent = parent
    card.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = card
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = card

    -- 淡入动画
    card.Position = UDim2.new(0, 0, 0, 10)
    TweenService:Create(card, TWEEN_INFO, { Position = UDim2.new(0, 0, 0, 0) }):Play()

    print("Card Created")
    return card
end

-- 按钮模块
function UILibrary:CreateButton(parent, options)
    options = options or {}
    local button = Instance.new("TextButton")
    button.Size = options.Size or UDim2.new(1, -10, 0, 30)
    button.BackgroundColor3 = options.BackgroundColor3 or THEME.Primary
    button.BackgroundTransparency = options.BackgroundTransparency or 0.5
    button.Text = options.Text or ""
    button.TextColor3 = THEME.Text
    button.TextSize = 14
    button.Font = THEME.Font
    button.Parent = parent
    button.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button

    if options.Callback then
        button.MouseButton1Click:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset * 0.95, button.Size.Y.Scale, button.Size.Y.Offset * 0.95) }):Play()
            wait(0.1)
            TweenService:Create(button, TWEEN_INFO, { Size = button.Size }):Play()
            options.Callback()
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = THEME.Accent }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = options.BackgroundColor3 or THEME.Primary }):Play()
    end)

    print("Button Created")
    return button
end

-- 悬浮按钮模块
function UILibrary:CreateFloatingButton(parent, options)
    options = options or {}
    local screenSize = UserInputService:GetPlatform() == Enum.Platform.Windows and Vector2.new(1280, 720) or game:GetService("GuiService"):GetScreenResolution()

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 40, 0, 40)
    button.Position = UDim2.new(0, screenSize.X - 50, 0, screenSize.Y - 50)
    button.BackgroundColor3 = THEME.Primary
    button.BackgroundTransparency = 0.5
    button.Text = options.Text or "O"
    button.TextColor3 = THEME.Text
    button.TextSize = 14
    button.Font = THEME.Font
    button.Parent = parent
    button.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = button

    local mainFrame = options.MainFrame
    if mainFrame then
        button.MouseButton1Click:Connect(function()
            local isVisible = not mainFrame.Visible
            button.Text = isVisible and "X" or options.Text
            if isVisible then
                mainFrame.Visible = true
                TweenService:Create(mainFrame, TWEEN_INFO, { Size = UDim2.new(0, 600, 0, 360) }):Play()
            else
                TweenService:Create(mainFrame, TWEEN_INFO, { Size = UDim2.new(0, 570, 0, 342) }):Play()
                wait(0.3)
                mainFrame.Visible = false
            end
            TweenService:Create(button, TWEEN_INFO, { Rotation = isVisible and 45 or 0 }):Play()
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = THEME.Accent }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = THEME.Primary }):Play()
    end)

    self:MakeDraggable(button)
    print("Floating Button Created")
    return button
end

-- 文本标签模块
function UILibrary:CreateLabel(parent, options)
    options = options or {}
    local label = Instance.new("TextLabel")
    label.Size = options.Size or UDim2.new(1, -10, 0, 20)
    label.Position = options.Position or UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = options.Text or ""
    label.TextColor3 = THEME.Text
    label.TextSize = 14
    label.Font = THEME.Font
    label.TextWrapped = true
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
    label.Parent = parent
    label.Visible = true

    label.TextTransparency = 1
    TweenService:Create(label, TWEEN_INFO, { TextTransparency = 0 }):Play()

    print("Label Created")
    return label
end

-- 输入框模块
function UILibrary:CreateTextBox(parent, options)
    options = options or {}
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 0, 30)
    textBox.BackgroundColor3 = THEME.SecondaryBackground
    textBox.BackgroundTransparency = 0.3
    textBox.TextColor3 = THEME.Text
    textBox.TextSize = 14
    textBox.Font = THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = 1
    textBox.BorderColor3 = THEME.Background
    textBox.Parent = parent
    textBox.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = textBox

    textBox.Focused:Connect(function()
        TweenService:Create(textBox, TWEEN_INFO, { BorderColor3 = THEME.Primary }):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(textBox, TWEEN_INFO, { BorderColor3 = THEME.Background }):Play()
        if options.OnFocusLost then
            options.OnFocusLost()
        end
    end)

    print("TextBox Created")
    return textBox
end

-- 开关模块
function UILibrary:CreateToggle(parent, options)
    options = options or {}
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, -10, 0, 30)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent
    toggleFrame.Visible = true

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, 0, 1, 0)
    })

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 40, 0, 10)
    track.Position = UDim2.new(0.65, 0, 0, 10)
    track.BackgroundColor3 = options.DefaultState and THEME.Success or THEME.Error
    track.Parent = toggleFrame
    track.Visible = true
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 5)
    trackCorner.Parent = track

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 20, 0, 20)
    thumb.Position = options.DefaultState and UDim2.new(0, 20, 0, -5) or UDim2.new(0, 0, 0, -5)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.Text = ""
    thumb.Parent = track
    thumb.Visible = true
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 10)
    thumbCorner.Parent = thumb

    local state = options.DefaultState or false
    thumb.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0, 20, 0, -5) or UDim2.new(0, 0, 0, -5)
        local targetColor = state and THEME.Success or THEME.Error
        TweenService:Create(thumb, TOGGLE_TWEEN_INFO, { Position = targetPos }):Play()
        TweenService:Create(track, TOGGLE_TWEEN_INFO, { BackgroundColor3 = targetColor }):Play()
        if options.Callback then
            options.Callback(state)
        end
    end)

    print("Toggle Created")
    return toggleFrame, state
end

-- 拖拽模块
function UILibrary:MakeDraggable(gui)
    local dragging = false
    local startPos, startGuiPos

    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = input.Position
            startGuiPos = gui.Position
            TweenService:Create(gui, TWEEN_INFO, { Size = UDim2.new(gui.Size.X.Scale, gui.Size.X.Offset * 1.05, gui.Size.Y.Scale, gui.Size.Y.Offset * 1.05) }):Play()
        end
    end)

    gui.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startPos
            local newPos = UDim2.new(
                startGuiPos.X.Scale, startGuiPos.X.Offset + delta.X,
                startGuiPos.Y.Scale, startGuiPos.Y.Offset + delta.Y
            )
            local screenSize = gui.Parent.AbsoluteSize
            local guiSize = gui.AbsoluteSize
            newPos = UDim2.new(
                0, math.clamp(newPos.X.Offset, 0, screenSize.X - guiSize.X),
                0, math.clamp(newPos.Y.Offset, 0, screenSize.Y - guiSize.Y)
            )
            gui.Position = newPos
        end
    end)

    gui.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            TweenService:Create(gui, TWEEN_INFO, { Size = gui.Size }):Play()
        end
    end)
end

-- 主窗口模块
function UILibrary:CreateWindow(options)
    options = options or {}
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UILibraryWindow"
    local success, err = pcall(function()
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end)
    if not success then
        warn("Window ScreenGui Initialization Failed: " .. tostring(err))
        return nil
    end
    screenGui.ResetOnSpawn = false

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 600, 0, 360)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -180)
    mainFrame.BackgroundColor3 = THEME.Background
    mainFrame.BackgroundTransparency = 0.5
    mainFrame.Parent = screenGui
    mainFrame.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = mainFrame

    -- 侧边栏
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 150, 1, 0)
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(40, 40, 40) -- 深灰
    sidebar.Parent = mainFrame
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 6)
    sidebarCorner.Parent = sidebar

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, 10)
    sidebarLayout.Parent = sidebar
    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 10)
    sidebarPadding.Parent = sidebar

    -- 标题栏
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(0, 450, 0, 40)
    titleBar.Position = UDim2.new(0, 150, 0, 0)
    titleBar.BackgroundColor3 = THEME.Primary
    titleBar.Parent = mainFrame
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 6)
    titleCorner.Parent = titleBar

    local titleLabel = self:CreateLabel(titleBar, {
        Text = "主页",
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    -- 主要页面
    local mainPage = Instance.new("ScrollingFrame")
    mainPage.Size = UDim2.new(0, 450, 0, 320)
    mainPage.Position = UDim2.new(0, 150, 0, 40)
    mainPage.BackgroundColor3 = THEME.SecondaryBackground
    mainPage.BackgroundTransparency = 0.5
    mainPage.ScrollBarThickness = 6
    mainPage.CanvasSize = UDim2.new(0, 0, 0, 0)
    mainPage.Parent = mainFrame
    local pageCorner = Instance.new("UICorner")
    pageCorner.CornerRadius = UDim.new(0, 6)
    pageCorner.Parent = mainPage

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 10)
    pageLayout.Parent = mainPage
    pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        mainPage.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 20)
    end)

    local originalSize = mainFrame.Size
    mainFrame.Size = UDim2.new(0, 570, 0, 342)
    TweenService:Create(mainFrame, TWEEN_INFO, { Size = originalSize }):Play()

    print("Window Created")
    return mainFrame, screenGui, sidebar, titleLabel, mainPage
end

-- 标签页模块
function UILibrary:CreateTab(sidebar, titleLabel, mainPage, options)
    options = options or {}
    local tabButton = self:CreateButton(sidebar, {
        Text = options.Text or "",
        Size = UDim2.new(1, -10, 0, 40),
        BackgroundColor3 = options.Active and THEME.Accent or THEME.Primary,
        BackgroundTransparency = options.Active and 0 or 0.5
    })

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.Position = UDim2.new(options.Active and 0 or 1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 6
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.Visible = options.Active or false
    content.Parent = mainPage

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = content
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end)

    tabButton.MouseButton1Click:Connect(function()
        for _, child in ipairs(mainPage:GetChildren()) do
            if child:IsA("ScrollingFrame") then
                TweenService:Create(child, TWEEN_INFO, { Position = UDim2.new(1, 0, 0, 0) }):Play()
                wait(0.3)
                child.Visible = false
            end
        end
        content.Position = UDim2.new(-1, 0, 0, 0)
        content.Visible = true
        TweenService:Create(content, TWEEN_INFO, { Position = UDim2.new(0, 0, 0, 0) }):Play()
        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                TweenService:Create(btn, TWEEN_INFO, {
                    BackgroundColor3 = btn == tabButton and THEME.Accent or THEME.Primary,
                    BackgroundTransparency = btn == tabButton and 0 or 0.5
                }):Play()
            end
        end
        titleLabel.Text = options.Text
    end)

    print("Tab Created")
    return tabButton, content
end

-- 作者介绍模块
function UILibrary:CreateAuthorInfo(parent, options)
    options = options or {}
    local authorFrame = Instance.new("Frame")
    authorFrame.Size = UDim2.new(1, -20, 0, 60)
    authorFrame.BackgroundColor3 = THEME.SecondaryBackground
    authorFrame.BackgroundTransparency = 0.3
    authorFrame.Parent = parent
    authorFrame.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = authorFrame

    local authorLabel = self:CreateLabel(authorFrame, {
        Text = options.Text or "",
        Size = UDim2.new(1, -10, 0, 20)
    })

    local socialButton = self:CreateButton(authorFrame, {
        Text = options.SocialText or "",
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 5, 0, 30),
        Callback = options.SocialCallback
    })

    print("Author Info Created")
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
end

return UILibrary
