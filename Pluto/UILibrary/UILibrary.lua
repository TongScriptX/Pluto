-- UILibrary.lua
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local UILibrary = {}

-- 默认主题（用户可覆盖）
local DEFAULT_THEME = {
    Primary = Color3.fromRGB(40, 38, 89), -- #282659
    Background = Color3.fromRGB(28, 37, 38), -- #1C2526
    Accent = Color3.fromRGB(114, 137, 218), -- #7289DA
    Text = Color3.new(1, 1, 1),
    Success = Color3.fromRGB(0, 255, 0),
    Error = Color3.fromRGB(255, 0, 0),
    Font = Enum.Font.SourceSans,
    Transparency = 0.6,
    CornerRadius = 8
}

-- 当前主题
local THEME = DEFAULT_THEME

-- 动画配置
local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- 通知容器
local notificationContainer = nil

-- 初始化通知容器
local function initNotificationContainer(screenGui)
    if not notificationContainer then
        notificationContainer = Instance.new("Frame")
        notificationContainer.Size = UDim2.new(0, 300, 0, 360)
        notificationContainer.Position = UDim2.new(0.5, -150, 0, 10)
        notificationContainer.BackgroundTransparency = 1
        notificationContainer.Parent = screenGui

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 5)
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
    notification.Size = options.Size or UDim2.new(1, -20, 0, 60)
    notification.BackgroundColor3 = options.BackgroundColor or THEME.Background
    notification.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    notification.Position = UDim2.new(0, 10, 0, -70)
    notification.Parent = notificationContainer
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = notification

    local titleLabel = self:CreateLabel(notification, {
        Text = options.Title or "",
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 5, 0, 5),
        TextSize = options.TitleSize or 12,
        TextColor3 = options.TitleColor or (options.IsWarning and THEME.Error or THEME.Text),
        Font = options.Font or THEME.Font
    })

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 5, 0, 25),
        TextSize = options.TextSize or 11,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font
    })

    -- 滑入动画
    if options.EnableAnimation ~= false then
        TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, 0) }):Play()
    else
        notification.Position = UDim2.new(0, 10, 0, 0)
    end

    -- 自动消失
    spawn(function()
        wait(options.Duration or 5)
        if options.EnableAnimation ~= false then
            TweenService:Create(notification, TWEEN_INFO, { Position = UDim2.new(0, 10, 0, -70) }):Play()
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
    card.Size = options.Size or UDim2.new(1, -10, 0, 60)
    card.Position = options.Position or UDim2.new(0, 5, 0, 0)
    card.BackgroundColor3 = options.BackgroundColor or THEME.Background
    card.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    card.ClipsDescendants = true
    card.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = card

    -- 淡入动画
    if options.EnableAnimation ~= false then
        card.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency + 0.2
        TweenService:Create(card, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency }):Play()
    end

    -- 点击缩放
    if options.EnableInteractionAnimation ~= false then
        card.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(card, TWEEN_INFO, { Size = UDim2.new(card.Size.X.Scale, card.Size.X.Offset - 2, card.Size.Y.Scale, card.Size.Y.Offset - 2) }):Play()
            end
        end)
        card.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(card, TWEEN_INFO, { Size = card.Size }):Play()
            end
        end)
    end

    return card
end

-- 按钮模块
function UILibrary:CreateButton(parent, options)
    options = options or {}
    local button = Instance.new("TextButton")
    button.Size = options.Size or UDim2.new(0, 100, 0, 30)
    button.Position = options.Position or UDim2.new(0, 0, 0, 0)
    button.BackgroundColor3 = options.BackgroundColor or THEME.Primary
    button.BackgroundTransparency = options.BackgroundTransparency or 0
    button.Text = options.Text or ""
    button.TextColor3 = options.TextColor or THEME.Text
    button.TextSize = options.TextSize or 14
    button.Font = options.Font or THEME.Font
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = button

    if options.Callback then
        button.MouseButton1Click:Connect(function()
            if options.EnableAnimation ~= false then
                TweenService:Create(button, TWEEN_INFO, { Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset, button.Size.Y.Scale, button.Size.Y.Offset - 2) }):Play()
                wait(0.1)
                TweenService:Create(button, TWEEN_INFO, { Size = button.Size }):Play()
            end
            options.Callback()
        end)
    end

    if options.EnableHoverAnimation ~= false then
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundTransparency = (options.BackgroundTransparency or 0) + 0.1, Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset + 2, button.Size.Y.Scale, button.Size.Y.Offset + 2) }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or 0, Size = button.Size }):Play()
        end)
    end

    return button
end

-- 文本标签模块
function UILibrary:CreateLabel(parent, options)
    options = options or {}
    local label = Instance.new("TextLabel")
    label.Size = options.Size or UDim2.new(1, -10, 0, 15)
    label.Position = options.Position or UDim2.new(0, 5, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = options.Text or ""
    label.TextColor3 = options.TextColor or THEME.Text
    label.TextSize = options.TextSize or 12
    label.Font = options.Font or THEME.Font
    label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = parent

    -- 淡入动画
    if options.EnableAnimation ~= false then
        label.TextTransparency = 1
        TweenService:Create(label, TWEEN_INFO, { TextTransparency = 0 }):Play()
    end

    return label
end

-- 输入框模块
function UILibrary:CreateTextBox(parent, options)
    options = options or {}
    local textBox = Instance.new("TextBox")
    textBox.Size = options.Size or UDim2.new(1, -10, 0, 30)
    textBox.Position = options.Position or UDim2.new(0, 5, 0, 5)
    textBox.BackgroundColor3 = options.BackgroundColor or THEME.Background
    textBox.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    textBox.TextColor3 = options.TextColor or THEME.Text
    textBox.TextSize = options.TextSize or 12
    textBox.Font = options.Font or THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.TextWrapped = true
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
            TweenService:Create(textBox, TWEEN_INFO, { BorderColor3 = options.FocusBorderColor or THEME.Accent, Size = UDim2.new(textBox.Size.X.Scale, textBox.Size.X.Offset + 2, textBox.Size.Y.Scale, textBox.Size.Y.Offset + 2) }):Play()
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

-- 开关模块
function UILibrary:CreateToggle(parent, options)
    options = options or {}
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = options.Size or UDim2.new(0, 90, 0, 25)
    toggleFrame.Position = options.Position or UDim2.new(0, 0, 0, 0)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, 0, 1, 0),
        TextSize = options.TextSize or 11,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        EnableAnimation = options.EnableAnimation
    })

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 40, 0, 20)
    toggle.Position = UDim2.new(0.65, 0, 0, 2.5)
    toggle.BackgroundColor3 = options.DefaultState and (options.OnColor or THEME.Success) or (options.OffColor or THEME.Error)
    toggle.Text = options.DefaultState and (options.OnText or "") or (options.OffText or "")
    toggle.TextColor3 = options.TextColor or THEME.Text
    toggle.TextSize = options.TextSize or 11
    toggle.Font = options.Font or THEME.Font
    toggle.Parent = toggleFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or 6)
    corner.Parent = toggle

    local state = options.DefaultState or false
    toggle.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0.65, 0, 0, 2.5) or UDim2.new(0.65, -10, 0, 2.5)
        if options.EnableAnimation ~= false then
            TweenService:Create(toggle, TWEEN_INFO, { BackgroundColor3 = state and (options.OnColor or THEME.Success) or (options.OffColor or THEME.Error), Position = targetPos }):Play()
        else
            toggle.BackgroundColor3 = state and (options.OnColor or THEME.Success) or (options.OffColor or THEME.Error)
            toggle.Position = targetPos
        end
        toggle.Text = state and (options.OnText or "") or (options.OffText or "")
        if options.Callback then
            options.Callback(state)
        end
    end)

    return toggleFrame, state
end

-- 滑块模块
function UILibrary:CreateSlider(parent, options)
    options = options or {}
    local min, max = options.Min or 0, options.Max or 100
    local defaultValue = math.clamp(options.DefaultValue or min, min, max)

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = options.Size or UDim2.new(1, -10, 0, 30)
    sliderFrame.Position = options.Position or UDim2.new(0, 5, 0, 0)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent

    local label = self:CreateLabel(sliderFrame, {
        Text = options.Text or "",
        Size = UDim2.new(1, 0, 0, 15),
        TextSize = options.TextSize or 11,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        EnableAnimation = options.EnableAnimation
    })

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -10, 0, 5)
    sliderBar.Position = UDim2.new(0, 5, 0, 20)
    sliderBar.BackgroundColor3 = options.BarColor or Color3.fromRGB(200, 200, 200)
    sliderBar.Parent = sliderFrame
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, options.CornerRadius or 3)
    barCorner.Parent = sliderBar

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 10, 0, 10)
    sliderButton.Position = UDim2.new((defaultValue - min) / (max - min), -5, 0, 17.5)
    sliderButton.BackgroundColor3 = options.ButtonColor or THEME.Primary
    sliderButton.Text = ""
    sliderButton.Parent = sliderFrame
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, options.CornerRadius or 5)
    buttonCorner.Parent = sliderButton

    local value = defaultValue
    local dragging = false

    local function updateSlider(input)
        local delta = input.Position.X - sliderFrame.AbsolutePosition.X
        local maxWidth = sliderFrame.AbsoluteSize.X - 10
        local newPos = math.clamp(delta, 0, maxWidth)
        value = min + (newPos / maxWidth) * (max - min)
        value = math.round(value)
        if options.EnableAnimation ~= false then
            TweenService:Create(sliderButton, TWEEN_INFO, { Position = UDim2.new(newPos / maxWidth, -5, 0, 17.5) }):Play()
        else
            sliderButton.Position = UDim2.new(newPos / maxWidth, -5, 0, 17.5)
        end
        label.Text = options.TextFormat and options.TextFormat(value) or tostring(value)
        if options.Callback then
            options.Callback(value)
        end
    end

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            if options.EnableAnimation ~= false then
                TweenService:Create(sliderButton, TWEEN_INFO, { Size = UDim2.new(0, 12, 0, 12) }):Play()
            end
            updateSlider(input)
        end
    end)

    sliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if options.EnableAnimation ~= false then
                TweenService:Create(sliderButton, TWEEN_INFO, { Size = UDim2.new(0, 10, 0, 10) }):Play()
            end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    return sliderFrame, value
end

-- 表格模块
function UILibrary:CreateTable(parent, options)
    options = options or {}
    local tableFrame = Instance.new("Frame")
    tableFrame.Size = options.Size or UDim2.new(1, -10, 0, 100)
    tableFrame.Position = options.Position or UDim2.new(0, 5, 0, 0)
    tableFrame.BackgroundColor3 = options.BackgroundColor or THEME.Background
    tableFrame.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    tableFrame.ClipsDescendants = true
    tableFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = tableFrame

    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.new(0, options.CellWidth or 80, 0, options.CellHeight or 20)
    layout.CellPadding = UDim2.new(0, 5, 0, 5)
    layout.Parent = tableFrame

    for _, row in ipairs(options.Data or {}) do
        for _, cell in ipairs(row) do
            self:CreateLabel(tableFrame, {
                Text = tostring(cell),
                Size = UDim2.new(0, options.CellWidth or 80, 0, options.CellHeight or 20),
                TextSize = options.TextSize or 11,
                TextColor3 = options.TextColor or THEME.Text,
                Font = options.Font or THEME.Font,
                EnableAnimation = options.EnableAnimation
            })
        end
    end

    return tableFrame
end

-- 滚动框架模块
function UILibrary:CreateScrollingFrame(parent, options)
    options = options or {}
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = options.Size or UDim2.new(1, -10, 0, 100)
    scrollingFrame.Position = options.Position or UDim2.new(0, 5, 0, 0)
    scrollingFrame.BackgroundColor3 = options.BackgroundColor or THEME.Background
    scrollingFrame.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    scrollingFrame.ScrollBarThickness = options.ScrollBarThickness or 6
    scrollingFrame.CanvasSize = options.CanvasSize or UDim2.new(0, 0, 0, 0)
    scrollingFrame.ClipsDescendants = true
    scrollingFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = scrollingFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scrollingFrame

    return scrollingFrame
end

-- 弹窗模块
function UILibrary:CreateModal(parent, options)
    options = options or {}
    local modalFrame = Instance.new("Frame")
    modalFrame.Size = options.Size or UDim2.new(0, 200, 0, 150)
    modalFrame.Position = options.Position or UDim2.new(0.5, -100, 0.5, -75)
    modalFrame.BackgroundColor3 = options.BackgroundColor or THEME.Background
    modalFrame.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    modalFrame.ClipsDescendants = true
    modalFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or 12)
    corner.Parent = modalFrame

    local title = self:CreateLabel(modalFrame, {
        Text = options.Title or "",
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.new(0, 10, 0, 10),
        TextSize = options.TextSize or 16,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        EnableAnimation = options.EnableAnimation
    })

    local closeButton = self:CreateButton(modalFrame, {
        Text = options.CloseText or "X",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(1, -35, 0, 10),
        BackgroundColor3 = options.CloseButtonColor or THEME.Primary,
        TextColor3 = options.CloseTextColor or THEME.Text,
        EnableAnimation = options.EnableAnimation,
        Callback = function()
            if options.EnableAnimation ~= false then
                TweenService:Create(modalFrame, TWEEN_INFO, { BackgroundTransparency = 1 }):Play()
                wait(0.3)
            end
            modalFrame:Destroy()
            if options.CloseCallback then
                options.CloseCallback()
            end
        end
    })

    -- 淡入动画
    if options.EnableAnimation ~= false then
        modalFrame.BackgroundTransparency = 1
        TweenService:Create(modalFrame, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency }):Play()
    end

    return modalFrame
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
                TweenService:Create(gui, TWEEN_INFO, { Size = UDim2.new(gui.Size.X.Scale, gui.Size.X.Offset + 2, gui.Size.Y.Scale, gui.Size.Y.Offset + 2) }):Play()
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

    if options.Gradient then
        local gradient = Instance.new("UIGradient")
        gradient.Color = options.GradientColor or ColorSequence.new({
            ColorSequenceKeypoint.new(0, THEME.Background),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 48, 50))
        })
        gradient.Transparency = options.GradientTransparency or NumberSequence.new({
            NumberSequenceKeypoint.new(0, THEME.Transparency),
            NumberSequenceKeypoint.new(1, THEME.Transparency + 0.1)
        })
        gradient.Parent = mainFrame
    end

    -- 标签栏
    local tabBar = Instance.new("Frame")
    tabBar.Size = options.TabBarSize or UDim2.new(0, 60, 1, -40)
    tabBar.Position = options.TabBarPosition or UDim2.new(0, 10, 0, 40)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = mainFrame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, options.TabPadding or 5)
    tabLayout.Parent = tabBar

    -- 内容区域
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = options.ContentSize or UDim2.new(0, 220, 1, -40)
    contentFrame.Position = options.ContentPosition or UDim2.new(0, 80, 0, 40)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ClipsDescendants = true
    contentFrame.Parent = mainFrame

    local titleLabel = self:CreateLabel(mainFrame, {
        Text = options.Title or "",
        Size = options.TitleSize or UDim2.new(1, -20, 0, 25),
        Position = options.TitlePosition or UDim2.new(0, 10, 0, 10),
        TextSize = options.TitleTextSize or 14,
        TextColor3 = options.TitleColor or THEME.Text,
        Font = options.Font or THEME.Font,
        EnableAnimation = options.EnableAnimation
    })

    -- 窗口动画
    if options.EnableAnimation ~= false then
        local originalSize = mainFrame.Size
        mainFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * 0.95, originalSize.Y.Scale, originalSize.Y.Offset * 0.95)
        TweenService:Create(mainFrame, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency, Size = originalSize }):Play()
    else
        mainFrame.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    end

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
        TextSize = options.TextSize or 12,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        EnableAnimation = options.EnableAnimation,
        Callback = function()
            for _, child in ipairs(contentFrame:GetChildren()) do
                if child:IsA("Frame") then
                    if options.EnableAnimation ~= false then
                        TweenService:Create(child, TWEEN_INFO, { Position = UDim2.new(1, 0, 0, 0) }):Play()
                    else
                        child.Position = UDim2.new(1, 0, 0, 0)
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

    local content = Instance.new("Frame")
    content.Size = options.ContentSize or UDim2.new(1, 0, 1, 0)
    content.Position = UDim2.new(options.Active and 0 or 1, 0, 0, 0)
    content.BackgroundTransparency = 1
    content.Visible = options.Active or false
    content.Parent = contentFrame
    options.ContentFrame = content

    return tabButton, content
end

-- 作者介绍模块（可选，保持灵活）
function UILibrary:CreateAuthorInfo(parent, options)
    options = options or {}
    local authorFrame = Instance.new("Frame")
    authorFrame.Size = options.Size or UDim2.new(1, -10, 0, 30)
    authorFrame.Position = options.Position or UDim2.new(0, 5, 0, 0)
    authorFrame.BackgroundColor3 = options.BackgroundColor or THEME.Accent
    authorFrame.BackgroundTransparency = options.BackgroundTransparency or THEME.Transparency
    authorFrame.ClipsDescendants = true
    authorFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or THEME.CornerRadius)
    corner.Parent = authorFrame

    local authorLabel = self:CreateLabel(authorFrame, {
        Text = options.AuthorText or "",
        Size = UDim2.new(0.5, 0, 0, 20),
        Position = UDim2.new(0, 5, 0, 5),
        TextSize = options.TextSize or 11,
        TextColor3 = options.TextColor or THEME.Text,
        Font = options.Font or THEME.Font,
        EnableAnimation = options.EnableAnimation
    })

    local socialButton = self:CreateButton(authorFrame, {
        Text = options.SocialText or "",
        Size = UDim2.new(0.5, -5, 0, 20),
        Position = UDim2.new(0.5, 0, 0, 5),
        TextSize = options.TextSize or 11,
        TextColor3 = options.TextColor or THEME.Text,
        TextXAlignment = Enum.TextXAlignment.Right,
        BackgroundTransparency = options.SocialBackgroundTransparency or 1,
        BackgroundColor3 = options.SocialBackgroundColor or THEME.Primary,
        Font = options.Font or THEME.Font,
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
        CornerRadius = newTheme.CornerRadius or DEFAULT_THEME.CornerRadius
    }
end

return UILibrary
