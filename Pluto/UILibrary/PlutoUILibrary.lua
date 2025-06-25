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

-- UI 样式常量
local UI_STYLES = {
    CardHeightSingle = 60,
    CardHeightMulti = 90,
    ButtonHeight = 25,
    LabelHeight = 15,
    TabButtonHeight = 30,
    Padding = 5,
    CornerRadius = 6,
    WindowWidth = 400,
    WindowHeight = 300,
    SidebarWidth = 80,
    TitleBarHeight = 30
}

-- 备选字体
local function getAvailableFont()
    local fonts = {Enum.Font.Roboto, Enum.Font.Arial, Enum.Font.SourceSans}
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

-- 验证主题值
for key, value in pairs(THEME) do
    if key ~= "Font" and value == nil then
        warn("[Theme]: Invalid value for " .. key .. ", using default")
        THEME[key] = DEFAULT_THEME[key]
    end
end

-- 动画配置
UILibrary.TWEEN_INFO_UI = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
UILibrary.TWEEN_INFO_BUTTON = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
UILibrary.THEME = THEME
UILibrary.UI_STYLES = UI_STYLES

-- 通知容器
local notificationContainer = nil
local screenGui = nil

-- 初始化通知容器
local function initNotificationContainer()
    if not screenGui or not screenGui.Parent then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "PlutoUILibrary"
        local success, err = pcall(function()
            screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 30)
        end)
        if not success then
            warn("[Notification]: ScreenGui initialization failed: ", err)
            return false
        end
        screenGui.ResetOnSpawn = false
        screenGui.Enabled = true
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.SiblingIndex
        screenGui.DisplayOrder = 10
    end

    if not notificationContainer or not notificationContainer then.Parent then
        notificationContainer = Instance.new("Frame")
        notificationContainer = notificationContainer.Name
        notificationContainer.Size = UDim2.new(0, 180, 0, 240)
        notificationContainer.Position = UDim2.new(1, -190, 1, -300)
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.Parent = screenGui
        notificationContainer.Visible = true
        notificationContainer.ZIndex = 10
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Label = UDim.new(0, UI_STYLES.P)
        layout.VerticalAlignment = Enum.VerticalAlignmentAlignment.Bottom
        layout.Parent = notificationContainer
    end
    return true
end

-- 通知模块
function UILibrary:Notify(options)
    options == nil then options = options or {}
    if not initNotificationContainer() then
        warn("[Notification]: Failed to initialize ScreenGui")
        return nil
    end

    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 180, 0, 40)
    notification.BackgroundColor3 = THEME.Background or DEFAULT_THEME.Background
    notification.BackgroundTransparency = 0.3
    notification.Position = UDim2.new(0, 0, 0, 90)
    notification.Parent = notificationContainer
    notification.Visible = true
    notification.ZIndex = 11
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = notification

    local titleLabel = self:CreateLabel(notification, {
        Text = options.Title or "Notification",
        Position = UDim2.new(0, UI_STYLES.Padding, 0, UI_STYLES.Padding),
        Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.LabelHeight),
        TextSize = 12
    })
    titleLabel.ZIndex = 12

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Position = UDim2.new(0, UI_STYLES.Padding, 0, UI_STYLES.Padding + UI_STYLES.LabelHeight),
        Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.LabelHeight),
        TextSize = 12
    })
    textLabel.ZIndex = 12

    task.wait(0.1)
    local success, err = pcall(function()
        local tween = TweenService:Create(notification, self.TWEEN_INFO_UI, {Position = UDim2.new(0, 0, 0, 50)})
        tween:Play()
    end)
    if not success then
        warn("[Notification]: Animation failed: ", err)
        notification.Position = UDim2.new(0, 0, 0, 50)
    end

    task.spawn(function()
        task.wait(options.Duration or 3)
        if notification.Parent then
            local success, err = pcall(function()
                local tween = TweenService:Create(notification, self.TWEEN_INFO_UI, {Position = UDim2.new(0, 0, 0, 90)})
                tween:Play()
                tween.Completed:Wait()
            end)
            if not success then
                warn("[Notification]: Exit animation failed: ", err)
            end
            notification:Destroy()
        end
    end)

    return notification
end

-- 辅助函数：应用淡入/淡出动画
function UILibrary:ApplyFadeTweens(target, tweenInfo, isVisible)
    local tweens = {}
    if target:IsA("Frame") or target:IsA("ScrollingFrame") then
        local transparency = isVisible and 0.5 or 1
        if target.Name == "Sidebar" or target.Name == "TitleBar" then
            transparency = isVisible and 0 or 1
        end
        table.insert(tweens, TweenService:Create(target, tweenInfo, {BackgroundTransparency = transparency}))
    elseif target:IsA("TextLabel") or target:IsA("TextButton") then
        table.insert(tweens, TweenService:Create(target, tweenInfo, {TextTransparency = isVisible and 0 or 1}))
    end
    for _, child in ipairs(target:GetDescendants()) do
        if child:IsA("Frame") or child:IsA("ScrollingFrame") then
            local transparency = isVisible and 0.5 or 1
            if child.Name == "Sidebar" or child.Name == "TitleBar" then
                transparency = isVisible and 0 or 1
            end
            table.insert(tweens, TweenService:Create(child, tweenInfo, {BackgroundTransparency = transparency}))
        elseif child:IsA("TextLabel") or child:IsA("TextButton") then
            table.insert(tweens, TweenService:Create(child, tweenInfo, {TextTransparency = isVisible and 0 or 1}))
        end
    end
    return tweens
end

-- 创建卡片
function UILibrary:CreateCard(parent, options)
    if not parent then
        warn("[Card]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, options.IsMultiElement and UI_STYLES.CardHeightMulti or UI_STYLES.CardHeightSingle)
    card.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    card.BackgroundTransparency = 0.3
    card.Position = UDim2.new(0, UI_STYLES.Padding, 0, UI_STYLES.Padding)
    card.Parent = parent
    card.Visible = true
    card.ZIndex = 2
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, UI_STYLES.Padding)
    layout.Parent = card
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingTop = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingBottom = UDim.new(0, UI_STYLES.Padding)
    padding.Parent = card

    TweenService:Create(card, self.TWEEN_INFO_UI, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.3}):Play()

    return card
end

-- 按钮模块
function UILibrary:CreateButton(parent, options)
    if not parent then
        warn("[Button]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local button = Instance.new("TextButton")
    button.Name = "Button_" .. (options.Text or "Unnamed")
    button.Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.ButtonHeight)
    button.BackgroundColor3 = options.BackgroundColor3 or THEME.Primary or DEFAULT_THEME.Primary
    button.BackgroundTransparency = options.BackgroundTransparency or 0.5
    button.Text = options.Text or ""
    button.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    button.TextSize = 12
    button.Font = THEME.Font
    button.Parent = parent
    button.Visible = true
    button.ZIndex = 3
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = button

    if options.Callback then
        button.MouseButton1Click:Connect(function()
            local originalSize = button.Size
            TweenService:Create(button, self.TWEEN_INFO_BUTTON, {Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * 0.95, originalSize.Y.Scale, originalSize.Y.Offset * 0.95)}):Play()
            task.wait(0.1)
            TweenService:Create(button, self.TWEEN_INFO_BUTTON, {Size = originalSize}):Play()
            local success, err = pcall(options.Callback)
            if not success then
                warn("[Button]: Callback failed: ", err)
            end
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = options.BackgroundColor3 or THEME.Primary or DEFAULT_THEME.Primary}):Play()
    end)

    return button
end

-- 悬浮按钮模块
function UILibrary:CreateFloatingButton(parent, options)
    if not parent then
        warn("[FloatingButton]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local button = Instance.new("TextButton")
    button.Name = "FloatingButton"
    button.Size = UDim2.new(0, 30, 0, 30)
    button.Position = UDim2.new(1, -40, 1, -80)
    button.BackgroundColor3 = THEME.Primary or DEFAULT_THEME.Primary
    button.BackgroundTransparency = 0.2
    button.Text = options.Text or "T"
    button.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    button.TextSize = 12
    button.Font = THEME.Font
    button.Rotation = 0
    button.Parent = parent
    button.Visible = true
    button.ZIndex = 15
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = button

    local mainFrame = options.MainFrame
    local firstOpenPos = mainFrame and mainFrame.Position or UDim2.new(0.5, -UI_STYLES.WindowWidth / 2, 0.5, -UI_STYLES.WindowHeight / 2)
    local lastKnownPos = firstOpenPos
    if mainFrame then
        button.MouseButton1Click:Connect(function()
            if not button.Active then return end
            button.Active = false
            local isVisible = not mainFrame.Visible
            button.Text = isVisible and "L" or "T"
            mainFrame.Visible = true
            mainFrame.Position = isVisible and (lastKnownPos or firstOpenPos) or firstOpenPos
            mainFrame.ZIndex = isVisible and 5 or 1
            local tweens = self:ApplyFadeTweens(mainFrame, self.TWEEN_INFO_UI, isVisible)
            for _, t in ipairs(tweens) do
                t:Play()
            end
            local tween = TweenService:Create(mainFrame, self.TWEEN_INFO_UI, {
                BackgroundTransparency = isVisible and 0.5 or 1
            })
            tween:Play()
            tween.Completed:Connect(function()
                if not isVisible then
                    mainFrame.Visible = false
                    lastKnownPos = mainFrame.Position
                end
                button.Active = true
            end)
            TweenService:Create(button, self.TWEEN_INFO_BUTTON, {Rotation = isVisible and 45 or 0}):Play()
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = THEME.Primary or DEFAULT_THEME.Primary}):Play()
    end)

    self:MakeDraggable(button)
    return button
end

-- 文本标签模块
function UILibrary:CreateLabel(parent, options)
    if not parent then
        warn("[Label]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local label = Instance.new("TextLabel")
    label.Name = "Label_" .. (options.Text or "Unnamed")
    label.Size = options.Size or UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.LabelHeight)
    label.Position = options.Position or UDim2.new(0, UI_STYLES.Padding, 0, UI_STYLES.Padding)
    label.BackgroundTransparency = 1
    label.Text = options.Text or ""
    label.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    label.TextSize = options.TextSize or 12
    label.Font = THEME.Font
    label.TextWrapped = true
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
    label.Parent = parent
    label.Visible = true
    label.ZIndex = 3
    local success, err = pcall(function()
        TweenService:Create(label, self.TWEEN_INFO_UI, {TextTransparency = 0}):Play()
    end)
    if not success then
        warn("[Label]: Animation failed: ", err)
    end

    return label
end

-- 输入框模块
function UILibrary:CreateTextBox(parent, options)
    if not parent then
        warn("[TextBox]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local textBox = Instance.new("TextBox")
    textBox.Name = "TextBox_" .. (options.PlaceholderText or "Unnamed")
    textBox.Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.ButtonHeight)
    textBox.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    textBox.BackgroundTransparency = 0.3
    textBox.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    textBox.TextSize = 12
    textBox.Font = THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.Text = options.Text or ""
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = 1
    textBox.BorderColor3 = THEME.Background or DEFAULT_THEME.Background
    textBox.Parent = parent
    textBox.Visible = true
    textBox.ZIndex = 3
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = textBox

    textBox.Focused:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_BUTTON, {BorderColor3 = THEME.Primary or DEFAULT_THEME.Primary}):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_BUTTON, {BorderColor3 = THEME.Background or DEFAULT_THEME.Background}):Play()
        if options.OnFocusLost and typeof(options.OnFocusLost) == "function" then
            local success, err = pcall(function()
                options.OnFocusLost(textBox.Text)
            end)
            if not success then
                warn("[TextBox]: OnFocusLost callback failed: ", err)
            end
        end
    end)

    return textBox
end

-- 开关模块
function UILibrary:CreateToggle(parent, options)
    if not parent then
        warn("[Toggle]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "Toggle_" .. (options.Text or "Unnamed")
    toggleFrame.Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.ButtonHeight)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent
    toggleFrame.Visible = true
    toggleFrame.ZIndex = 2
    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, 0, 1, 0),
        TextSize = 12
    })
    label.ZIndex = 3

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(0, 30, 0, 8)
    track.Position = UDim2.new(0.65, 0, 0.5, -4)
    track.BackgroundColor3 = options.DefaultState and (THEME.Success or DEFAULT_THEME.Success) or (THEME.Error or DEFAULT_THEME.Error)
    track.Parent = toggleFrame
    track.Visible = true
    track.ZIndex = 3
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
    thumb.ZIndex = 4
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 8)
    thumbCorner.Parent = thumb

    local state = options.DefaultState or false
    thumb.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0, 15, 0, -4) or UDim2.new(0, 0, 0, -4)
        local targetColor = state and (THEME.Success or DEFAULT_THEME.Success) or (THEME.Error or DEFAULT_THEME.Error)
        TweenService:Create(thumb, self.TWEEN_INFO_BUTTON, {Position = targetPos}):Play()
        TweenService:Create(track, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = targetColor}):Play()
        if options.Callback and typeof(options.Callback) == "function" then
            local success, err = pcall(function()
                options.Callback(state)
            end)
            if not success then
                warn("[Toggle]: Callback failed: ", err)
            end
        end
    end)

    return toggleFrame, state
end

-- 拖拽模块
function UILibrary:MakeDraggable(gui)
    if not gui then
        warn("[MakeDraggable]: Failed: GUI is nil")
        return
    end
    local dragging = false
    local startPos, startGuiOffset

    local function isMouseOverGui(input)
        local pos = input.Position
        local guiPos = gui.AbsolutePosition
        local guiSize = gui.AbsoluteSize
        return pos.X >= guiPos.X and pos.X <= guiPos.X + guiSize.X and pos.Y >= guiPos.Y and pos.Y <= guiPos.Y + guiSize.Y
    end

    UserInputService.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isMouseOverGui(input) then
            dragging = true
            startPos = input.Position
            startGuiOffset = gui.AbsolutePosition
            gui.ZIndex = gui.Name == "FloatingButton" and 15 or 5
            print("[MakeDraggable]: Drag started: GUI =", gui.Name, "Position =", tostring(gui.Position))
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startPos
            local newOffset = Vector2.new(startGuiOffset.X + delta.X, startGuiOffset.Y + delta.Y)
            local screenSize = GuiService:GetScreenResolution()
            if screenSize == Vector2.new(0, 0) then
                screenSize = Vector2.new(720, 1280)
            end
            local guiSize = gui.AbsoluteSize
            local maxX = math.max(0, screenSize.X - math.max(guiSize.X, 1))
            local maxY = math.max(0, screenSize.Y - math.max(guiSize.Y, 1))
            newOffset = Vector2.new(
                math.clamp(newOffset.X, 0, maxX),
                math.clamp(newOffset.Y, 0, maxY)
            )
            gui.Position = UDim2.new(0, newOffset.X, 0, newOffset.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            gui.ZIndex = gui.Name == "FloatingButton" and 15 or 5
            print("[MakeDraggable]: Drag ended: GUI =", gui.Name, "Position =", tostring(gui.Position))
        end
    end)
end

-- 主窗口模块
function UILibrary:CreateUIWindow(options)
    options = options or {}
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
    end
    local windowWidth = math.min(UI_STYLES.WindowWidth, screenSize.X * 0.9)
    local windowHeight = math.min(UI_STYLES.WindowHeight, screenSize.Y * 0.9)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PlutoUILibraryWindow"
    local success, err = pcall(function()
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 30)
    end)
    if not success then
        warn("[Window]: ScreenGui initialization failed: ", err)
        return nil
    end
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 5

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, windowWidth, 0, windowHeight)
    mainFrame.Position = UDim2.new(0.5, -windowWidth / 2, 0.5, -windowHeight / 2)
    mainFrame.BackgroundColor3 = THEME.Background or DEFAULT_THEME.Background
    mainFrame.BackgroundTransparency = 0.5
    mainFrame.Parent = screenGui
    mainFrame.Visible = true
    mainFrame.ZIndex = 5
    mainFrame.ClipsDescendants = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = mainFrame

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, UI_STYLES.SidebarWidth, 1, 0)
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sidebar.BackgroundTransparency = 0
    sidebar.Parent = mainFrame
    sidebar.Visible = true
    sidebar.ZIndex = 6
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    sidebarCorner.Parent = sidebar

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, UI_STYLES.Padding)
    sidebarLayout.Parent = sidebar
    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
    sidebarPadding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
    sidebarPadding.PaddingTop = UDim.new(0, UI_STYLES.Padding)
    sidebarPadding.Parent = sidebar

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(0, windowWidth - UI_STYLES.SidebarWidth, 0, UI_STYLES.TitleBarHeight)
    titleBar.Position = UDim2.new(0, UI_STYLES.SidebarWidth, 0, 0)
    titleBar.BackgroundColor3 = THEME.Primary or DEFAULT_THEME.Primary
    titleBar.BackgroundTransparency = 0
    titleBar.Parent = mainFrame
    titleBar.Visible = true
    titleBar.ZIndex = 6
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    titleCorner.Parent = titleBar

    local titleLabel = self:CreateLabel(titleBar, {
        Text = "Home",
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextSize = 14,
        TextTransparency = 0
    })
    titleLabel.ZIndex = 7

    local mainPage = Instance.new("Frame")
    mainPage.Name = "MainPage"
    mainPage.Size = UDim2.new(0, windowWidth - UI_STYLES.SidebarWidth, 0, windowHeight - UI_STYLES.TitleBarHeight)
    mainPage.Position = UDim2.new(0, UI_STYLES.SidebarWidth, 0, UI_STYLES.TitleBarHeight)
    mainPage.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    mainPage.BackgroundTransparency = 0.5
    mainPage.Parent = mainFrame
    mainPage.Visible = true
    mainPage.ZIndex = 6
    mainPage.ClipsDescendants = true
    local pageCorner = Instance.new("UICorner")
    pageCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    pageCorner.Parent = mainPage

    self:MakeDraggable(titleBar)
    self:MakeDraggable(mainFrame)

    task.delay(0.05, function()
        for _, t in ipairs(self:ApplyFadeTweens(mainFrame, self.TWEEN_INFO_UI, true)) do
            t:Play()
        end
    end)

    return {
        MainFrame = mainFrame,
        ScreenGui = screenGui,
        Sidebar = sidebar,
        TitleLabel = titleLabel,
        MainPage = mainPage
    }
end

-- 标签页模块
function UILibrary:CreateTab(sidebar, titleLabel, mainPage, options)
    if not sidebar or not mainPage or not titleLabel then
        warn("[Tab]: Creation failed: Invalid sidebar, mainPage, or titleLabel")
        return nil, nil
    end
    options = options or {}
    local tabButton = self:CreateButton(sidebar, {
        Text = options.Text or "",
        Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.TabButtonHeight),
        BackgroundColor3 = options.Active and (THEME.Accent or DEFAULT_THEME.Accent) or (THEME.Primary or DEFAULT_THEME.Primary),
        BackgroundTransparency = options.Active and 0 or 0.5
    })
    if not tabButton then
        warn("[Tab]: Creation failed: tabButton is nil")
        return nil, nil
    end
    tabButton.ZIndex = 7

    local content = Instance.new("ScrollingFrame")
    content.Name = "TabContent_" .. (options.Text or "Unnamed")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.Position = UDim2.new(options.Active and 0 or 1, 0, 0, 0)
    content.BackgroundColor3 = THEME.Background or DEFAULT_THEME.Background
    content.BackgroundTransparency = options.Active and 0.5 or 1
    content.ScrollBarThickness = 4
    content.CanvasSize = UDim2.new(0, 0, 0, 100)
    content.ScrollingEnabled = true
    content.Visible = options.Active or false
    content.Parent = mainPage
    content.ZIndex = 6
    content.ClipsDescendants = true
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, UI_STYLES.Padding)
    listLayout.Parent = content
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + UI_STYLES.Padding)
    end)

    tabButton.MouseButton1Click:Connect(function()
        for _, child in ipairs(mainPage:GetChildren()) do
            if child:IsA("ScrollingFrame") and child ~= content then
                child.Visible = false
                child.Position = UDim2.new(1, 0, 0, 0)
                child.BackgroundTransparency = 1
                child.ZIndex = 6
                child.CanvasPosition = Vector2.new(0, 0)
                print("[Tab]: Hid content: Name =", child.Name, "Visible =", child.Visible, "Position =", tostring(child.Position), "ZIndex =", child.ZIndex)
            end
        end
        content.Position = UDim2.new(-1, 0, 0, 0)
        content.Visible = true
        content.ZIndex = 6
        content.Size = UDim2.new(1, 0, 1, 0)
        content.CanvasPosition = Vector2.new(0, 0)
        local tween = TweenService:Create(content, self.TWEEN_INFO_UI, {
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0.5
        })
        tween:Play()
        tween.Completed:Connect(function()
            print("[Tab]: Animation completed: Text =", options.Text, "Content visible =", content.Visible, "Position =", tostring(content.Position), "Size =", tostring(content.Size), "ZIndex =", content.ZIndex)
        end)
        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                TweenService:Create(btn, self.TWEEN_INFO_BUTTON, {
                    BackgroundColor3 = btn == tabButton and (THEME.Accent or DEFAULT_THEME.Accent) or (THEME.Primary or DEFAULT_THEME.Primary),
                    BackgroundTransparency = btn == tabButton and 0 or 0.5
                }):Play()
            end
        end
        titleLabel.Text = options.Text
        print("[Tab]: Switched: Text =", options.Text, "Content visible =", content.Visible, "Position =", tostring(content.Position), "Size =", tostring(content.Size), "ZIndex =", content.ZIndex)
    end)

    return tabButton, content
end

-- 作者介绍模块
function UILibrary:CreateAuthorInfo(parent, options)
    if not parent then
        warn("[AuthorInfo]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local authorFrame = self:CreateCard(parent, {IsMultiElement = true})
    local authorLabel = self:CreateLabel(authorFrame, {
        Text = options.Text or "",
        Size = UDim2.new(1, -2 * UI_STYLES.Padding, 0, UI_STYLES.LabelHeight),
        TextSize = 12
    })
    authorLabel.ZIndex = 3

    local socialButton = self:CreateButton(authorFrame, {
        Text = options.SocialText or "",
        Callback = options.SocialCallback
    })
    socialButton.ZIndex = 3

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
    for key, value in pairs(THEME) do
        if key ~= "Font" and value == nil then
            warn("[SetTheme]: Invalid value for ", key, ", using default")
            THEME[key] = DEFAULT_THEME[key]
        end
    end

    local function updateElement(element)
        if element:IsA("Frame") or element:IsA("ScrollingFrame") then
            if element.Name == "MainFrame" then
                element.BackgroundColor3 = THEME.Background
            elseif element.Name == "Sidebar" then
                element.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            elseif element.Name == "TitleBar" then
                element.BackgroundColor3 = THEME.Primary
            elseif element.Name == "MainPage" or element.Name:match("^TabContent_") then
                element.BackgroundColor3 = THEME.SecondaryBackground
            elseif element.Name == "Card" or element.Name == "AuthorFrame" then
                element.BackgroundColor3 = THEME.SecondaryBackground
            elseif element.Name == "Notification" then
                element.BackgroundColor3 = THEME.Background
            end
        elseif element:IsA("TextButton") then
            if element.Name == "FloatingButton" then
                element.BackgroundColor3 = THEME.Primary
                element.TextColor3 = THEME.Text
                element.Font = THEME.Font
            elseif element.Name:match("^Button_") then
                local isActive = element.BackgroundTransparency == 0
                element.BackgroundColor3 = isActive and THEME.Accent or THEME.Primary
                element.TextColor3 = THEME.Text
                element.Font = THEME.Font
            end
        elseif element:IsA("TextLabel") then
            element.TextColor3 = THEME.Text
            element.Font = THEME.Font
        elseif element:IsA("TextBox") then
            element.BackgroundColor3 = THEME.SecondaryBackground
            element.TextColor3 = THEME.Text
            element.Font = THEME.Font
            element.BorderColor3 = THEME.Background
        end
    end

    for _, gui in ipairs(Players.LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "PlutoUILibraryWindow" or gui.Name == "PlutoUILibrary" then
            for _, element in ipairs(gui:GetDescendants()) do
                updateElement(element)
            end
            updateElement(gui)
        end
    end
end

return UILibrary
