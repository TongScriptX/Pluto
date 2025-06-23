-- UILibrary.lua
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local UILibrary = {}

-- 默认主题（参考 Luminosity）
local DEFAULT_THEME = {
    Primary = Color3.fromRGB(63, 81, 181), -- #3F51B5
    Background = Color3.fromRGB(30, 30, 30), -- #1E1E1E
    SecondaryBackground = Color3.fromRGB(46, 46, 46), -- #2E2E2E
    Accent = Color3.fromRGB(92, 107, 192), -- #5C6BC0
    Text = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54),
    Font = Enum.Font.Gotham,
    Transparency = 0.5, -- 半透明
    CardTransparency = 0.3, -- 卡片半透明
    CornerRadius = 6,
    ShadowTransparency = 0.2,
    TextSizeTitle = 18,
    TextSizeBody = 14
}

-- 当前主题
local THEME = DEFAULT_THEME

-- 动画配置
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local TOGGLE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- 通知容器
local notificationContainer = nil
local screenGui = nil

-- 初始化通知容器（右下角）
local function initNotificationContainer()
    if not screenGui or not screenGui.Parent then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "UILibrary"
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
        screenGui.ResetOnSpawn = false
        screenGui.Enabled = true
        print("ScreenGui Created: Parent =", screenGui.Parent and screenGui.Parent.Name or "No parent")
    end

    if not notificationContainer or not notificationContainer.Parent then
        local screenSize = UserInputService:GetPlatform() == Enum.Platform.Windows and Vector2.new(1280, 720) or game:GetService("GuiService"):GetScreenResolution()
        notificationContainer = Instance.new("Frame")
        notificationContainer.Size = UDim2.new(0, 300, 0, 360)
        notificationContainer.Position = UDim2.new(1, -310, 1, -370) -- 右下角
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.Parent = screenGui
        notificationContainer.Visible = true
        notificationContainer.ClipsDescendants = false

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 10)
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.Parent = notificationContainer

        print("Notification Container Created: Parent =", notificationContainer.Parent and notificationContainer.Parent.Name or "No parent")
    end
end

-- 通知模块
function UILibrary:Notify(options)
    options = options or {}
    initNotificationContainer() -- 确保容器存在

    if not screenGui.Parent or not notificationContainer.Parent then
        warn("Notification Failed: ScreenGui or notificationContainer has no parent")
        return nil
    end

    local notification = Instance.new("Frame")
    notification.Size = options.Size or UDim2.new(0, 280, 0, 60)
    notification.BackgroundColor3 = options.BackgroundColor or THEME.Background
    notification.BackgroundTransparency = THEME.CardTransparency
    notification.Position = UDim2.new(0, 10, 0, 70)
    notification.Parent = notificationContainer
    notification.Visible = true
    notification.ClipsDescendants = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    corner.Parent = notification

    -- Material Design 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = THEME.ShadowTransparency
    stroke.Parent = notification

    -- 图标
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Image = options.Icon or "rbxassetid://7072706667"
    icon.Parent = notification
    icon.Visible = true

    local titleLabel = self:CreateLabel(notification, {
        Text = options.Title or "",
        Size = UDim2.new(1, -40, 0, 20),
        Position = UDim2.new(0, 35, 0, 5),
        TextSize = THEME.TextSizeTitle,
        TextColor3 = options.TitleColor or (options.IsWarning and THEME.Error or THEME.Text),
        Font = THEME.Font,
        TextScaled = false,
        TextTransparency = 0
    })

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Size = UDim2.new(1, -40, 0, 20),
        Position = UDim2.new(0, 35, 0, 25),
        TextSize = THEME.TextSizeBody,
        TextColor3 = options.TextColor or THEME.Text,
        Font = THEME.Font,
        TextScaled = false,
        TextTransparency = 0
    })

    -- 滑入动画
    if options.EnableAnimation ~= false and notification.Parent then
        notification.Position = UDim2.new(0, 10, 0, 130)
        wait(0.1) -- 确保 Parent 设置生效
        local success, err = pcall(function()
            local tween = TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, 70) })
            tween:Play()
            print("Notification Animation Started: Position =", notification.Position, "Parent =", notification.Parent and notification.Parent.Name or "No parent")
        end)
        if not success then
            warn("Notification Animation Failed: " .. tostring(err))
            notification.Position = UDim2.new(0, 10, 0, 70) -- 直接设置位置
        end
    end

    -- 自动消失
    spawn(function()
        wait(options.Duration or 5)
        if notification.Parent then
            if options.EnableAnimation ~= false then
                local success, err = pcall(function()
                    local tween = TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, 130) })
                    tween:Play()
                    tween.Completed:Wait()
                    print("Notification Animation Completed: Destroying")
                end)
                if not success then
                    warn("Notification Animation (Exit) Failed: " .. tostring(err))
                end
            end
            notification:Destroy()
            print("Notification Destroyed")
        end
    end)

    if options.IsWarning then
        warn("Notification: " .. options.Text)
    else
        print("Notification Created: Title =", options.Title, "Text =", options.Text, "Parent =", notification.Parent and notification.Parent.Name or "No parent")
    end
    return notification
end

-- 创建卡片
function UILibrary:CreateCard(parent, options)
    options = options or {}
    local card = Instance.new("Frame")
    card.Size = options.Size or UDim2.new(0, 260, 0, options.Height or 80)
    card.BackgroundColor3 = options.BackgroundColor or THEME.SecondaryBackground
    card.BackgroundTransparency = THEME.CardTransparency
    card.ClipsDescendants = false
    card.Parent = parent
    card.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    corner.Parent = card

    -- Material Design 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = THEME.ShadowTransparency
    stroke.Parent = card

    -- 自动布局
    if options.AutoLayout ~= false then
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
    end

    -- 淡入动画
    if options.EnableAnimation ~= false then
        card.Position = UDim2.new(0, 0, 0, 10)
        TweenService:Create(card, TWEEN_INFO, { Position = UDim2.new(0, 0, 0, 0) }):Play()
    end

    print("Card Created:", card.Parent and "Parent exists" or "No parent")
    return card
end

-- 按钮模块
function UILibrary:CreateButton(parent, options)
    options = options or {}
    local button = Instance.new("TextButton")
    button.Size = options.Size or UDim2.new(1, -10, 0, 30)
    button.Position = options.Position or UDim2.new(0, 5, 0, 0)
    button.BackgroundColor3 = options.BackgroundColor or THEME.Primary
    button.BackgroundTransparency = THEME.Transparency
    button.Text = options.Text or ""
    button.TextColor3 = options.TextColor or THEME.Text
    button.TextSize = options.TextSize or THEME.TextSizeBody
    button.Font = options.Font or THEME.Font
    button.TextScaled = false
    button.Parent = parent
    button.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    corner.Parent = button

    -- Material Design 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = THEME.ShadowTransparency
    stroke.Parent = button

    -- 图标
    if options.Icon then
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 20, 0, 20)
        icon.Position = UDim2.new(0, 5, 0, 5)
        icon.BackgroundTransparency = 1
        icon.Image = options.Icon
        icon.Parent = button
        button.TextXAlignment = Enum.TextXAlignment.Right
        button.Text = "  " .. button.Text
    end

    if options.Callback then
        button.MouseButton1Click:Connect(function()
            if options.EnableAnimation ~= false then
                TweenService:Create(button, TWEEN_INFO, { Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset * 0.95, button.Size.Y.Scale, button.Size.Y.Offset * 0.95) }):Play()
                wait(0.1)
                TweenService:Create(button, TWEEN_INFO, { Size = button.Size }):Play()
            end
            options.Callback()
        end)
    end

    -- 悬停动画
    if options.EnableHoverAnimation ~= false then
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = THEME.Accent }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = THEME.Primary }):Play()
        end)
    end

    print("Button Created:", button.Parent and "Parent exists" or "No parent")
    return button
end

-- 悬浮按钮模块
function UILibrary:CreateFloatingButton(parent, options)
    options = options or {}
    local screenSize = UserInputService:GetPlatform() == Enum.Platform.Windows and Vector2.new(1280, 720) or game:GetService("GuiService"):GetScreenResolution()
    
    local button = Instance.new("TextButton")
    button.Size = options.Size or UDim2.new(0, 40, 0, 40)
    button.Position = options.Position or UDim2.new(0, screenSize.X - 50, 0, screenSize.Y - 50)
    button.BackgroundColor3 = options.BackgroundColor or THEME.Primary
    button.BackgroundTransparency = THEME.Transparency
    button.Text = options.Text or "T"
    button.TextColor3 = options.TextColor or THEME.Text
    button.TextSize = THEME.TextSizeBody
    button.Font = options.Font or THEME.Font
    button.TextScaled = false
    button.Parent = parent
    button.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = button

    -- Material Design 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = THEME.ShadowTransparency
    stroke.Parent = button

    -- 默认回调：切换主窗口显隐
    local mainFrame = options.MainFrame
    if mainFrame then
        button.MouseButton1Click:Connect(function()
            local isVisible = not mainFrame.Visible
            button.Text = isVisible and (options.CloseText or "✕") or (options.Text or "T")
            local targetSize = isVisible and (options.MainFrameSize or UDim2.new(0, 600, 0, 360)) or
                              UDim2.new(0, mainFrame.Size.X.Offset * 0.95, 0, mainFrame.Size.Y.Offset * 0.95)
            if options.EnableAnimation ~= false then
                if isVisible then
                    mainFrame.Visible = true
                    TweenService:Create(mainFrame, TWEEN_INFO, { Size = targetSize }):Play()
                else
                    TweenService:Create(mainFrame, TWEEN_INFO, { Size = targetSize }):Play()
                    wait(0.3)
                    mainFrame.Visible = false
                end
                TweenService:Create(button, TWEEN_INFO, { Rotation = isVisible and 45 or 0 }):Play()
            else
                mainFrame.Size = targetSize
                mainFrame.Visible = isVisible
                button.Rotation = isVisible and 45 or 0
            end
            if options.Callback then
                options.Callback(isVisible)
            end
        end)
    end

    -- 悬停动画
    if options.EnableHoverAnimation ~= false then
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = THEME.Accent }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundColor3 = THEME.Primary }):Play()
        end)
    end

    -- 拖拽支持
    if options.EnableDrag ~= false then
        self:MakeDraggable(button, { PreventOffScreen = options.PreventOffScreen ~= false })
    end

    print("Floating Button Created:", button.Parent and "Parent exists" or "No parent")
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
    label.TextColor3 = options.TextColor or THEME.Text
    label.TextSize = options.TextSize or THEME.TextSizeBody
    label.Font = options.Font or THEME.Font
    label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.TextScaled = false
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = parent
    label.Visible = true

    -- 淡入动画
    if options.EnableAnimation ~= false then
        label.TextTransparency = 1
        TweenService:Create(label, TWEEN_INFO, { TextTransparency = 0 }):Play()
    end

    print("Label Created:", label.Parent and "Parent exists" or "No parent")
    return label
end

-- 输入框模块
function UILibrary:CreateTextBox(parent, options)
    options = options or {}
    local textBox = Instance.new("TextBox")
    textBox.Size = options.Size or UDim2.new(1, -10, 0, 30)
    textBox.Position = options.Position or UDim2.new(0, 5, 0, 25)
    textBox.BackgroundColor3 = options.BackgroundColor or THEME.SecondaryBackground
    textBox.BackgroundTransparency = THEME.CardTransparency
    textBox.TextColor3 = options.TextColor or THEME.Text
    textBox.TextSize = THEME.TextSizeBody
    textBox.Font = options.Font or THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.TextWrapped = true
    textBox.TextScaled = false
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = 1
    textBox.BorderColor3 = THEME.Background
    textBox.ClipsDescendants = true
    textBox.Parent = parent
    textBox.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    corner.Parent = textBox

    -- Material Design 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = THEME.ShadowTransparency
    stroke.Parent = textBox

    -- 聚焦动画
    if options.EnableAnimation ~= false then
        textBox.Focused:Connect(function()
            TweenService:Create(textBox, TWEEN_INFO, { BorderColor3 = THEME.Primary }):Play()
        end)
        textBox.FocusLost:Connect(function()
            TweenService:Create(textBox, TWEEN_INFO, { BorderColor3 = THEME.Background }):Play()
            if options.OnFocusLost then
                options.OnFocusLost()
            end
        end)
    else
        if options.OnFocusLost then
            textBox.FocusLost:Connect(options.OnFocusLost)
        end
    end

    print("TextBox Created:", textBox.Parent and "Parent exists" or "No parent")
    return textBox
end

-- 开关模块（Material Design 风格）
function UILibrary:CreateToggle(parent, options)
    options = options or {}
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = options.Size or UDim2.new(1, -10, 0, 30)
    toggleFrame.Position = options.Position or UDim2.new(0, 5, 0, 0)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent
    toggleFrame.Visible = true

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, 0, 1, 0),
        TextSize = THEME.TextSizeBody,
        TextColor3 = options.TextColor or THEME.Text,
        Font = THEME.Font,
        TextScaled = false,
        EnableAnimation = options.EnableAnimation
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
        if options.EnableAnimation ~= false then
            TweenService:Create(thumb, TOGGLE_TWEEN_INFO, { Position = targetPos }):Play()
            TweenService:Create(track, TOGGLE_TWEEN_INFO, { BackgroundColor3 = targetColor }):Play()
        else
            thumb.Position = targetPos
            track.BackgroundColor3 = targetColor
        end
        if options.Callback then
            options.Callback(state)
        end
    end)

    print("Toggle Created:", toggleFrame.Parent and "Parent exists" or "No parent")
    return toggleFrame, state
end

-- 拖拽模块
function UILibrary:MakeDraggable(gui, options)
    options = options or {}
    local dragging = false
    local startPos, startGuiPos

    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = input.Position
            startGuiPos = gui.Position
            if options.EnableAnimation ~= false then
                TweenService:Create(gui, TWEEN_INFO, { Size = UDim2.new(gui.Size.X.Scale, gui.Size.X.Offset * 1.05, gui.Size.Y.Scale, gui.Size.Y.Offset * 1.05) }):Play()
            end
        end)
    end

    gui.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startPos
            local newPos = UDim2.new(
                startGuiPos.X.Scale, startGuiPos.X.Offset + delta.X,
                startGuiPos.Y.Scale, startGuiPos.Y.Offset + delta.Y
            )
            if options.PreventOffScreen then
                local screenSize = gui.Parent.AbsoluteSize
                local guiSize = gui.AbsoluteSize
                newPos = UDim2.new(
                    0, math.clamp(newPos.X.Offset, 0, screenSize.X - guiSize.X),
                    0, math.clamp(newPos.Y.Offset, 0, screenSize.Y - guiSize.Y)
                )
            end
            gui.Position = newPos
        end
    end)

    gui.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if options.EnableAnimation ~= false then
                TweenService:Create(gui, TWEEN_INFO, { Size = gui.Size }):Play()
            end
        end
    end)
end

-- 主窗口模块
function UILibrary:CreateWindow(options)
    options = options or {}
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = options.ScreenGuiName or "UILibraryWindow"
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = options.Size or UDim2.new(0, 600, 0, 360)
    mainFrame.Position = options.Position or UDim2.new(0.5, -300, 0.5, -180)
    mainFrame.BackgroundColor3 = options.BackgroundColor or THEME.Background
    mainFrame.BackgroundTransparency = THEME.Transparency
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    mainFrame.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    corner.Parent = mainFrame

    -- Material Design 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = THEME.ShadowTransparency
    stroke.Parent = mainFrame

    -- 标签栏（顶部，控制右侧）
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(0, 290, 0, 40)
    tabBar.Position = UDim2.new(0, 305, 0, 5)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 10)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Parent = tabBar

    -- 左侧功能区域
    local leftFrame = Instance.new("ScrollingFrame")
    leftFrame.Size = UDim2.new(0, 290, 0, 300)
    leftFrame.Position = UDim2.new(0, 5, 0, 50)
    leftFrame.BackgroundColor3 = THEME.Background
    leftFrame.BackgroundTransparency = THEME.Transparency
    leftFrame.ScrollBarThickness = 6
    leftFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    leftFrame.ClipsDescendants = true
    leftFrame.Parent = mainFrame
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    leftCorner.Parent = leftFrame

    local leftLayout = Instance.new("UIListLayout")
    leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
    leftLayout.Padding = UDim.new(0, 10)
    leftLayout.Parent = leftFrame
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        leftFrame.CanvasSize = UDim2.new(0, 0, 0, leftLayout.AbsoluteContentSize.Y + 20)
    end)

    -- 右侧设置区域
    local rightFrame = Instance.new("ScrollingFrame")
    rightFrame.Size = UDim2.new(0, 290, 0, 300)
    rightFrame.Position = UDim2.new(0, 305, 0, 50)
    rightFrame.BackgroundColor3 = THEME.SecondaryBackground
    rightFrame.BackgroundTransparency = THEME.Transparency
    rightFrame.ScrollBarThickness = 6
    rightFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    rightFrame.ClipsDescendants = true
    rightFrame.Parent = mainFrame
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    rightCorner.Parent = rightFrame

    -- 窗口动画
    if options.EnableAnimation ~= false then
        local originalSize = mainFrame.Size
        mainFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * 0.95, originalSize.Y.Scale, originalSize.Y)
        TweenService:Create(mainFrame, TWEEN_INFO, { Size = originalSize }):Play()
    end

    print("Window Created:", mainFrame)
    return mainFrame, screenGui, tabBar, leftFrame, rightFrame
end

-- 标签页模块（仅控制右侧）
function UILibrary:CreateTab(tabBar, rightFrame, options)
    options = options or {}
    local tabButton = self:CreateButton(tabBar, {
        Text = options.Text or "",
        Size = UDim2.new(0, 100, 0, 30),
        BackgroundTransparency = options.Active and 0 or 0.2,
        BackgroundColor3 = THEME.Primary,
        TextSize = THEME.TextSizeBody,
        TextColor3 = THEME.Text,
        Font = THEME.Font,
        TextScaled = false,
        Icon = options.Icon,
        EnableAnimation = options.EnableAnimation,
        Callback = function()
            for _, child in ipairs(rightFrame:GetChildren()) do
                if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                    if options.EnableAnimation ~= false then
                        TweenService:Create(child, TWEEN_INFO, { Position = UDim2.new(1, 0, 0, 0) }):Play()
                        wait(0.3)
                        child.Visible = false
                    else
                        child.Visible = false
                    end
                end
            end
            local content = options.ContentFrame
            content.Position = UDim2.new(-1, 0, 0, 0)
            content.Visible = true
            if options.EnableAnimation ~= false then
                TweenService:Create(content, TWEEN_INFO, { Position = UDim2.new(0, 0, 0, 0) }):Play()
            else
                content.Position = UDim2.new(0, 0, 0, 0)
            end
            for _, btn in ipairs(tabBar:GetChildren()) do
                if btn:IsA("TextButton") then
                    if options.EnableAnimation ~= false then
                        TweenService:Create(btn, TWEEN_INFO, { BackgroundTransparency = btn == tabButton and 0 or 0.2 }):Play()
                    else
                        btn.BackgroundTransparency = btn == tabButton and 0 or 0.2
                    end
                end
            end
            if options.Callback then
                options.Callback()
            end
        end
    })

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.Position = UDim2.new(options.Active and 0 or 1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 6
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.Visible = options.Active or false
    content.Parent = rightFrame

    -- 自动布局（垂直）
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = content
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end)

    options.ContentFrame = content
    print("Tab Created:", tabButton.Parent and "Parent exists" or "No parent")
    return tabButton, content
end

-- 作者介绍模块
function UILibrary:CreateAuthorInfo(parent, options)
    options = options or {}
    local authorFrame = Instance.new("Frame")
    authorFrame.Size = options.Size or UDim2.new(0, 260, 0, 30)
    authorFrame.BackgroundColor3 = THEME.SecondaryBackground
    authorFrame.BackgroundTransparency = THEME.CardTransparency
    authorFrame.ClipsDescendants = false
    authorFrame.Parent = parent
    authorFrame.Visible = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, THEME.CornerRadius)
    corner.Parent = authorFrame

    -- Material Design 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = THEME.ShadowTransparency
    stroke.Parent = authorFrame

    local authorLabel = self:CreateLabel(authorFrame, {
        Text = options.AuthorText or "",
        Size = UDim2.new(0.5, 0, 0, 20),
        Position = UDim2.new(0, 5, 0, 5),
        TextSize = THEME.TextSizeBody,
        TextColor3 = THEME.Text,
        Font = THEME.Font,
        TextScaled = false,
        EnableAnimation = options.EnableAnimation
    })

    local socialButton = self:CreateButton(authorFrame, {
        Text = options.SocialText or "",
        Size = UDim2.new(0.5, -5, 0, 20),
        Position = UDim2.new(0.5, 0, 0, 5),
        TextSize = THEME.TextSizeBody,
        TextColor3 = THEME.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        BackgroundColor3 = THEME.Primary,
        Font = THEME.Font,
        TextScaled = false,
        Icon = options.SocialIcon or "rbxassetid://7072706667",
        EnableAnimation = options.EnableAnimation,
        Callback = options.SocialCallback
    })

    print("Author Info Created:", authorFrame.Parent and "Parent exists" or "No parent")
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
        Font = newTheme.Font or DEFAULT_THEME.Font,
        Transparency = newTheme.Transparency or DEFAULT_THEME.Transparency,
        CardTransparency = newTheme.CardTransparency or DEFAULT_THEME.CardTransparency,
        CornerRadius = newTheme.CornerRadius or DEFAULT_THEME.CornerRadius,
        ShadowTransparency = newTheme.ShadowTransparency or DEFAULT_THEME.ShadowTransparency,
        TextSizeTitle = newTheme.TextSizeTitle or DEFAULT_THEME.TextSizeTitle,
        TextSizeBody = newTheme.TextSizeBody or DEFAULT_THEME.TextSizeBody
    }
end

return UILibrary
