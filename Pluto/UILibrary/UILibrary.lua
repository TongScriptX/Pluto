-- UILibrary.lua
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local UILibrary = {}

-- 默认主题
local DEFAULT_THEME = {
    Primary = Color3.fromRGB(74, 78, 170), -- #4A4EAA
    Background = Color3.fromRGB(28, 37, 38), -- #1C2526
    Accent = Color3.fromRGB(114, 137, 218), -- #7289DA
    Text = Color3.new(1, 1, 1),
    Success = Color3.fromRGB(0, 255, 0),
    Error = Color3.fromRGB(255, 0, 0),
    Font = Enum.Font.Roboto,
    Transparency = 0.7, -- Glassmorphism 增强透明度
    CornerRadius = 8,
    ShadowTransparency = 0.8,
    TextStrokeTransparency = 0.4
}

-- 当前主题
local THEME = DEFAULT_THEME

-- 动画配置
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local TOGGLE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- 通知容器
local notificationContainer = nil

-- 初始化通知容器（右下角）
local function initNotificationContainer(screenGui)
    if not notificationContainer then
        local screenSize = UserInputService:GetPlatform() == Enum.Platform.Windows and Vector2.new(1280, 720) or game:GetService("GuiService"):GetScreenResolution()
        notificationContainer = Instance.new("Frame")
        notificationContainer.Size = UDim2.new(0, 300, 0, 360)
        notificationContainer.Position = UDim2.new(1, -310, 1, -10)
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.Parent = screenGui

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 10)
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.Parent = notificationContainer
    end
end

-- 通知模块
function UILibrary:Notify(options)
    options = options or {}
    local screenGui = Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("UILibrary") or Instance.new("ScreenGui")
    screenGui.Name = "UILibrary"
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false
    initNotificationContainer(screenGui)

    local notification = Instance.new("Frame")
    notification.Size = options.Size or UDim2.new(0, 280, 0, 60)
    notification.BackgroundColor3 = options.BackgroundColor or THEME.Background
    notification.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    notification.Position = UDim2.new(0, 10, 0, 70)
    notification.Parent = notificationContainer
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = notification

    -- 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = options.ShadowTransparency or THEME.ShadowTransparency
    stroke.Parent = notification

    -- Glassmorphism 渐变
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 50, 50)),
        ColorSequenceKeypoint.new(1, THEME.Background)
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, THEME.Transparency)
    })
    gradient.Parent = notification

    -- 图标
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 20, 0, 20)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Image = options.Icon or "rbxassetid://7072706667"
    icon.Parent = notification

    local titleLabel = self:CreateLabel(notification, {
        Text = options.Title or "",
        Size = UDim2.new(1, -40, 0, 20),
        Position = UDim2.new(0, 35, 0, 5),
        TextSize = 16,
        TextColor3 = options.TitleColor or (options.IsWarning and THEME.Error or THEME.Text),
        Font = options.Font or THEME.Font,
        TextScaled = true,
        TextContainer = true
    })

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Size = UDim2.new(1, -40, 0, 20),
        Position = UDim2.new(0, 35, 0, 25),
        TextSize = 14,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        TextScaled = true,
        TextContainer = true
    })

    -- 滑入动画
    if options.EnableAnimation ~= false then
        notification.Position = UDim2.new(0, 10, 0, 130)
        TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, 70) }):Play()
    end

    -- 自动消失
    spawn(function()
        wait(options.Duration or 5)
        if options.EnableAnimation ~= false then
            TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, 130) }):Play()
            wait(0.3)
        end
        notification:Destroy()
    end)

    if options.IsWarning then warn(options.Text) else print(options.Text) end
    return notification
end

-- 创建卡片
function UILibrary:CreateCard(parent, options)
    options = options or {}
    local card = Instance.new("Frame")
    card.Size = options.Size or UDim2.new(1, -20, 0, options.Height or 60)
    card.Position = options.Position or UDim2.new(0, 10, 0, 0)
    card.BackgroundColor3 = options.BackgroundColor or THEME.Background
    card.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    card.ClipsDescendants = true
    card.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = card

    -- 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = options.ShadowTransparency or THEME.ShadowTransparency
    stroke.Parent = card

    -- Glassmorphism 渐变
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 50, 50)),
        ColorSequenceKeypoint.new(1, THEME.Background)
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, THEME.Transparency)
    })
    gradient.Parent = card

    -- 自动布局
    if options.AutoLayout ~= false then
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, options.Spacing or 10)
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
        card.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency + 0.2
        TweenService:Create(card, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency }):Play()
    end

    return card
end

-- 按钮模块
function UILibrary:CreateButton(parent, options)
    options = options or {}
    local button = Instance.new("TextButton")
    button.Size = options.Size or UDim2.new(1, -20, 0, 30)
    button.Position = options.Position or UDim2.new(0, 10, 0, 0)
    button.BackgroundColor3 = options.BackgroundColor or THEME.Primary
    button.BackgroundTransparency = options.BackgroundTransparency or 0
    button.Text = options.Text or ""
    button.TextColor3 = options.TextColor or THEME.Text
    button.TextSize = options.TextSize or 14
    button.Font = options.Font or THEME.Font
    button.TextScaled = options.TextScaled or true
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = button

    -- 图标
    if options.Icon then
        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 20, 0, 20)
        icon.Position = UDim2.new(0, 10, 0, 5)
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

    if options.EnableHoverAnimation ~= false then
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundTransparency = (options.BackgroundTransparency or 0) + 0.1, Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset * 1.05, button.Size.Y.Scale, button.Size.Y.Offset * 1.05) }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or 0, Size = button.Size }):Play()
        end)
    end

    return button
end

-- 悬浮按钮模块
function UILibrary:CreateFloatingButton(parent, options)
    options = options or {}
    local screenSize = UserInputService:GetPlatform() == Enum.Platform.Windows and Vector2.new(1280, 720) or game:GetService("GuiService"):GetScreenResolution()
    
    local button = Instance.new("TextButton")
    button.Size = options.Size or UDim2.new(0, 44, 0, 44)
    button.Position = options.Position or UDim2.new(0, screenSize.X - 54, 0, 10)
    button.BackgroundColor3 = options.BackgroundColor or THEME.Background
    button.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    button.Text = options.Text or "T"
    button.TextColor3 = options.TextColor or THEME.Text
    button.TextSize = options.TextSize or 18
    button.Font = options.Font or THEME.Font
    button.TextScaled = options.TextScaled or true
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or 22)
    corner.Parent = button

    -- 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = options.ShadowTransparency or THEME.ShadowTransparency
    stroke.Parent = button

    -- Glassmorphism 渐变
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 50, 50)),
        ColorSequenceKeypoint.new(1, THEME.Background)
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, THEME.Transparency)
    })
    gradient.Parent = button

    -- 默认回调：切换主窗口显隐
    local mainFrame = options.MainFrame
    if mainFrame then
        button.MouseButton1Click:Connect(function()
            local isVisible = not mainFrame.Visible
            button.Text = isVisible and (options.CloseText or "✕") or (options.Text or "T")
            local targetTransparency = isVisible and (options.MainFrameTransparency or THEME.Transparency) or 1
            local targetSize = isVisible and (options.MainFrameSize or UDim2.new(0, 300, 0, 360)) or
                              UDim2.new(0, mainFrame.Size.X.Offset * 0.95, 0, mainFrame.Size.Y.Offset * 0.95)
            if options.EnableAnimation ~= false then
                if isVisible then
                    mainFrame.Visible = true
                    TweenService:Create(mainFrame, TWEEN_INFO, { BackgroundTransparency = targetTransparency, Size = targetSize }):Play()
                else
                    TweenService:Create(mainFrame, TWEEN_INFO, { BackgroundTransparency = targetTransparency, Size = targetSize }):Play()
                    wait(0.3)
                    mainFrame.Visible = false
                end
                TweenService:Create(button, TWEEN_INFO, { Rotation = isVisible and 45 or 0 }):Play()
            else
                mainFrame.BackgroundTransparency = targetTransparency
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
            TweenService:Create(button, TWEEN_INFO, {
                BackgroundTransparency = (options.BackgroundTransparency or THEME.Transparency) + 0.1,
                Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset * 1.05, button.Size.Y.Scale, button.Size.Y.Offset * 1.05)
            }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency, Size = button.Size }):Play()
        end)
    end

    -- 拖拽支持
    if options.EnableDrag ~= false then
        self:MakeDraggable(button, { PreventOffScreen = options.PreventOffScreen ~= false })
    end

    return button
end

-- 文本标签模块
function UILibrary:CreateLabel(parent, options)
    options = options or {}
    local container = Instance.new("Frame")
    container.Size = options.Size or UDim2.new(1, -10, 0, 20)
    container.Position = options.Position or UDim2.new(0, 5, 0, 5)
    container.BackgroundTransparency = options.TextContainer ~= false and 0.8 or 1
    container.BackgroundColor3 = THEME.Background
    container.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = container

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = options.Text or ""
    label.TextColor3 = options.TextColor or THEME.Text
    label.TextSize = options.TextSize or 14
    label.Font = options.Font or THEME.Font
    label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.TextScaled = options.TextScaled or true
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.TextStrokeTransparency = options.TextStrokeTransparency or THEME.TextStrokeTransparency
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = container

    -- 淡入动画
    if options.EnableAnimation ~= false then
        label.TextTransparency = 1
        container.BackgroundTransparency = options.TextContainer ~= false and 1 or 0.8
        TweenService:Create(label, TWEEN_INFO, { TextTransparency = 0 }):Play()
        if options.TextContainer ~= false then
            TweenService:Create(container, TWEEN_INFO, { BackgroundTransparency = 0.8 }):Play()
        end
    end

    return container
end

-- 输入框模块
function UILibrary:CreateTextBox(parent, options)
    options = options or {}
    local textBox = Instance.new("TextBox")
    textBox.Size = options.Size or UDim2.new(1, -20, 0, 30)
    textBox.Position = options.Position or UDim2.new(0, 10, 0, 5)
    textBox.BackgroundColor3 = options.BackgroundColor or THEME.Background
    textBox.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    textBox.TextColor3 = options.TextColor or THEME.Text
    textBox.TextSize = options.TextSize or 14
    textBox.Font = options.Font or THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.TextWrapped = true
    textBox.TextScaled = options.TextScaled or true
    textBox.TextTruncate = Enum.TextTruncate.None
    textBox.BorderSizePixel = 1
    textBox.BorderColor3 = options.BorderColor or THEME.Background
    textBox.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = textBox

    -- 聚焦动画
    if options.EnableAnimation ~= false then
        textBox.Focused:Connect(function()
            TweenService:Create(textBox, TWEEN_INFO, { BorderColor3 = options.FocusBorderColor or THEME.Accent, Size = UDim2.new(textBox.Size.X.Scale, textBox.Size.X.Offset * 1.05, textBox.Size.Y.Scale, textBox.Y.Offset * 1.05) }):Play()
        end)
        textBox.FocusLost:Connect(function()
            TweenService:Create(textBox, TWEEN_INFO, { BorderColor3 = options.BorderColor or THEME.Background, Size = textBox.Size }):Play()
            if options.OnFocusLost then
                options.OnFocusLost()
            end
        end)
    else
        if options.OnFocusLost then
            textBox.FocusLost:Connect(options.OnFocusLost)
        end
    end

    return textBox
end

-- 开关模块（Material Design 风格）
function UILibrary:CreateToggle(parent, options)
    options = options or {}
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = options.Size or UDim2.new(1, -20, 0, 25)
    toggleFrame.Position = options.Position or UDim2.new(0, 10, 0, 0)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, 0, 1, 0),
        TextSize = 14,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        TextScaled = true,
        TextContainer = true,
        EnableAnimation = options.EnableAnimation
    })

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 40, 0, 10)
    track.Position = UDim2.new(0.65, 0, 0, 7.5)
    track.BackgroundColor3 = options.DefaultState and (options.OnColor or THEME.Success) or (options.OffColor or THEME.Error)
    track.Parent = toggleFrame
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 5)
    trackCorner.Parent = track

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 20, 0, 20)
    thumb.Position = options.DefaultState and UDim2.new(0, 20, 0, -5) or UDim2.new(0, 0, 0, -5)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.Text = options.DefaultState and "✔" or "✕"
    thumb.TextColor3 = options.DefaultState and THEME.Success or THEME.Error
    thumb.TextSize = 12
    thumb.Font = THEME.Font
    thumb.Parent = track
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 10)
    thumbCorner.Parent = thumb

    local state = options.DefaultState or false
    thumb.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0, 20, 0, -5) or UDim2.new(0, 0, 0, -5)
        local targetColor = state and (options.OnColor or THEME.Success) or (options.OffColor or THEME.Error)
        if options.EnableAnimation ~= false then
            TweenService:Create(thumb, TOGGLE_TWEEN_INFO, { Position = targetPos }):Play()
            TweenService:Create(track, TOGGLE_TWEEN_INFO, { BackgroundColor3 = targetColor }):Play()
        else
            thumb.Position = targetPos
            track.BackgroundColor3 = targetColor
        end
        thumb.Text = state and "✔" or "✕"
        thumb.TextColor3 = targetColor
        if options.Callback then
            options.Callback(state)
        end
    end)

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
        end
    end)

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
    screenGui.Name = options.ScreenGuiName or "UILibrary"
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = options.ResetOnSpawn or false

    -- 遮罩层
    local mask = nil
    if options.EnableMask ~= false then
        mask = Instance.new("Frame")
        mask.Size = UDim2.new(1, 0, 1, 0)
        mask.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        mask.BackgroundTransparency = 0.7
        mask.Parent = screenGui
    end

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = options.Size or UDim2.new(0, 300, 0, 360)
    mainFrame.Position = options.Position or UDim2.new(0.5, -150, 0, 10)
    mainFrame.BackgroundColor3 = options.BackgroundColor or THEME.Background
    mainFrame.BackgroundTransparency = 1
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or 14)
    corner.Parent = mainFrame

    -- 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = options.ShadowTransparency or THEME.ShadowTransparency
    stroke.Parent = mainFrame

    -- Glassmorphism 渐变
    local gradient = Instance.new("UIGradient")
    gradient.Color = options.GradientColor or ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 50, 50)),
        ColorSequenceKeypoint.new(1, THEME.Background)
    })
    gradient.Transparency = options.GradientTransparency or NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, THEME.Transparency)
    })
    gradient.Parent = mainFrame

    -- 标签栏
    local tabBar = Instance.new("Frame")
    tabBar.Size = options.TabBarSize or UDim2.new(0, 60, 1, -40)
    tabBar.Position = options.TabBarPosition or UDim2.new(0, 10, 0, 40)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, options.TabPadding or 10)
    tabLayout.Parent = tabBar

    -- 内容区域（滚动框架）
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = options.ContentSize or UDim2.new(0, 220, 1, -40)
    contentFrame.Position = options.ContentPosition or UDim2.new(0, 80, 0, 40)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ScrollBarThickness = options.EnableScrolling ~= false and 6 or 0
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.ClipsDescendants = true
    contentFrame.Parent = mainFrame

    -- 自动布局
    if options.AutoLayout ~= false then
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, options.Spacing or 10)
        layout.Parent = contentFrame
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            contentFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)
    end

    local titleLabel = self:CreateLabel(mainFrame, {
        Text = options.Title or "",
        Size = options.TitleSize or UDim2.new(1, -20, 0, 25),
        Position = options.TitlePosition or UDim2.new(0, 10, 0, 10),
        TextSize = 16,
        TextColor3 = options.TitleColor or THEME.Text,
        Font = options.Font or THEME.Font,
        TextScaled = true,
        TextContainer = true,
        EnableAnimation = options.EnableAnimation
    })

    -- 窗口动画
    if options.EnableAnimation ~= false then
        local originalSize = mainFrame.Size
        mainFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * 0.95, originalSize.Y.Scale, originalSize.Y.Offset * 0.95)
        TweenService:Create(mainFrame, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency, Size = originalSize }):Play()
        if mask then
            mask.BackgroundTransparency = 1
            TweenService:Create(mask, TWEEN_INFO, { BackgroundTransparency = 0.7 }):Play()
        end
    else
        mainFrame.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
        if mask then
            mask.BackgroundTransparency = 0.7
        end
    end

    -- 清理
    screenGui.AncestryChanged:Connect(function()
        if not screenGui:IsDescendantOf(game) and mask then
            mask:Destroy()
        end
    end)

    return mainFrame, screenGui, tabBar, contentFrame
end

-- 标签页模块
function UILibrary:CreateTab(tabBar, contentFrame, options)
    options = options or {}
    local tabButton = self:CreateButton(tabBar, {
        Text = options.Text or "",
        Size = options.Size or UDim2.new(1, -10, 0, 40),
        BackgroundTransparency = options.Active and 0 or (options.BackgroundTransparency or THEME.Transparency),
        BackgroundColor3 = options.BackgroundColor or THEME.Primary,
        TextSize = 14,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        TextScaled = true,
        Icon = options.Icon,
        EnableAnimation = options.EnableAnimation,
        Callback = function()
            for _, child in ipairs(contentFrame:GetChildren()) do
                if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                    if options.EnableAnimation ~= false then
                        TweenService:Create(child, TWEEN_INFO, { Position = UDim2.new(1, 0, 0, 0) }):Play()
                        wait(0.3)
                        child.Visible = false
                    else
                        child.Position = UDim2.new(1, 0, 0, 0)
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
                        TweenService:Create(btn, TWEEN_INFO, { BackgroundTransparency = btn == tabButton and 0 or (options.BackgroundTransparency or THEME.Transparency) }):Play()
                    else
                        btn.BackgroundTransparency = btn == tabButton and 0 or (options.BackgroundTransparency or THEME.Transparency)
                    end
                end
            end
            if options.Callback then
                options.Callback()
            end
        end
    })

    local content = Instance.new("ScrollingFrame")
    content.Size = options.ContentSize or UDim2.new(1, 0, 1, 0)
    content.Position = UDim2.new(options.Active and 0 or 1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = options.EnableScrolling ~= false and 6 or 0
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.Visible = options.Active or false
    content.Parent = contentFrame

    -- 自动布局
    if options.AutoLayout ~= false then
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, options.Spacing or 10)
        layout.Parent = content
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)
    end

    options.ContentFrame = content
    return tabButton, content
end

-- 作者介绍模块
function UILibrary:CreateAuthorInfo(parent, options)
    options = options or {}
    local authorFrame = Instance.new("Frame")
    authorFrame.Size = options.Size or UDim2.new(1, -20, 0, 30)
    authorFrame.Position = options.Position or UDim2.new(0, 10, 0, 0)
    authorFrame.BackgroundColor3 = options.BackgroundColor or THEME.Accent
    authorFrame.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    authorFrame.ClipsDescendants = true
    authorFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = authorFrame

    -- 阴影
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = options.ShadowTransparency or THEME.ShadowTransparency
    stroke.Parent = authorFrame

    local authorLabel = self:CreateLabel(authorFrame, {
        Text = options.AuthorText or "",
        Size = UDim2.new(0.5, 0, 0, 20),
        Position = UDim2.new(0, 10, 0, 5),
        TextSize = 14,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        TextScaled = true,
        TextContainer = true,
        EnableAnimation = options.EnableAnimation
    })

    local socialButton = self:CreateButton(authorFrame, {
        Text = options.SocialText or "",
        Size = UDim2.new(0.5, -10, 0, 20),
        Position = UDim2.new(0.5, 0, 0, 5),
        TextSize = 14,
        TextColor3 = options.TextColor or THEME.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        BackgroundTransparency = options.SocialBackgroundTransparency or 1,
        BackgroundColor3 = options.SocialBackgroundColor or THEME.Primary,
        Font = options.Font or THEME.Font,
        TextScaled = true,
        Icon = options.SocialIcon or "rbxassetid://7072706667",
        EnableAnimation = options.EnableAnimation,
        Callback = options.SocialCallback
    })

    return authorFrame
end

-- 主题切换模块
function UILibrary:SetTheme(newTheme)
    newTheme = newTheme or {}
    THEME = {
        Primary = newTheme.Primary or DEFAULT_THEME.Primary,
        Background = newTheme.Background or DEFAULT_THEME.Background,
        Accent = newTheme.Accent or DEFAULT_THEME.Accent,
        Text = newTheme.Text or DEFAULT_THEME.Text,
        Success = newTheme.Success or DEFAULT_THEME.Success,
        Error = newTheme.Error or DEFAULT_THEME.Error,
        Font = newTheme.Font or DEFAULT_THEME.Font,
        Transparency = newTheme.Transparency or DEFAULT_THEME.Transparency,
        CornerRadius = newTheme.CornerRadius or DEFAULT_THEME.CornerRadius,
        ShadowTransparency = newTheme.ShadowTransparency or DEFAULT_THEME.ShadowTransparency,
        TextStrokeTransparency = newTheme.TextStrokeTransparency or DEFAULT_THEME.TextStrokeTransparency
    }
end

return UILibrary
