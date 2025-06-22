-- PlutoXUILibrary.lua
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("StarterGui")

local PlutoXUILibrary = {}

-- 颜色定义
local THEME = {
    Primary = Color3.fromRGB(40, 38, 89), -- #282659
    Background = Color3.fromRGB(28, 37, 38), -- #1C2526
    Accent = Color3.fromRGB(114, 137, 218), -- #7289DA
    Text = Color3.new(1, 1, 1),
    Success = Color3.fromRGB(0, 255, 0),
    Error = Color3.fromRGB(255, 0, 0)
}

-- 默认字体
local DEFAULT_FONT = Enum.Font.SourceSans -- 替换 SFPro 为 SourceSans

-- 动画配置
local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- 通知模块
function PlutoXUILibrary:Notify(title, text, duration, isWarn)
    pcall(function()
        CoreGui:SetCore("SendNotification", {
            Title = isWarn and "警告: " .. title or title,
            Text = tostring(text),
            Icon = "",
            Duration = duration or 5
        })
    end)
    if isWarn then warn(text) else print(text) end
end

-- 按钮模块
function PlutoXUILibrary:CreateButton(parent, options)
    options = options or {}
    local button = Instance.new("TextButton")
    button.Size = options.Size or UDim2.new(0, 100, 0, 30)
    button.Position = options.Position or UDim2.new(0, 0, 0, 0)
    button.BackgroundColor3 = options.BackgroundColor or THEME.Primary
    button.Text = options.Text or "Button"
    button.TextColor3 = options.TextColor or THEME.Text
    button.TextSize = options.TextSize or 14
    button.Font = options.Font or DEFAULT_FONT
    button.BackgroundTransparency = options.BackgroundTransparency or 0
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or 8)
    corner.Parent = button

    if options.Callback then
        button.MouseButton1Click:Connect(options.Callback)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TWEEN_INFO, { BackgroundTransparency = 0.1 }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TWEEN_INFO, { BackgroundTransparency = options.BackgroundTransparency or 0 }):Play()
    end)

    return button
end

-- 文本标签模块
function PlutoXUILibrary:CreateLabel(parent, options)
    options = options or {}
    local label = Instance.new("TextLabel")
    label.Size = options.Size or UDim2.new(1, -20, 0, 15)
    label.Position = options.Position or UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = options.Text or ""
    label.TextColor3 = options.TextColor or THEME.Text
    label.TextSize = options.TextSize or 13
    label.Font = options.Font or DEFAULT_FONT
    label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = parent
    return label
end

-- 输入框模块
function PlutoXUILibrary:CreateTextBox(parent, options)
    options = options or {}
    local textBox = Instance.new("TextBox")
    textBox.Size = options.Size or UDim2.new(1, -20, 0, 30)
    textBox.Position = options.Position or UDim2.new(0, 10, 0, 0)
    textBox.BackgroundColor3 = options.BackgroundColor or THEME.Background
    textBox.BackgroundTransparency = options.BackgroundTransparency or 0.6
    textBox.TextColor3 = options.TextColor or THEME.Text
    textBox.TextSize = options.TextSize or 13
    textBox.Font = options.Font or DEFAULT_FONT
    textBox.PlaceholderText = options.PlaceholderText or "Input"
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.None
    textBox.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, options.CornerRadius or 8)
    corner.Parent = textBox

    if options.OnFocusLost then
        textBox.FocusLost:Connect(options.OnFocusLost)
    end

    return textBox
end

-- 开关模块
function PlutoXUILibrary:CreateToggle(parent, options)
    options = options or {}
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = options.Size or UDim2.new(0, 90, 0, 25)
    toggleFrame.Position = options.Position or UDim2.new(0, 0, 0, 0)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "Toggle",
        Size = UDim2.new(0.6, 0, 1, 0),
        TextSize = 12,
        Font = options.Font or DEFAULT_FONT
    })

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 40, 0, 20)
    toggle.Position = UDim2.new(0.65, 0, 0, 2.5)
    toggle.BackgroundColor3 = options.DefaultState and THEME.Success or THEME.Error
    toggle.Text = options.DefaultState and "开" or "关"
    toggle.TextColor3 = THEME.Text
    toggle.TextSize = 12
    toggle.Font = options.Font or DEFAULT_FONT
    toggle.Parent = toggleFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = toggle

    local state = options.DefaultState or false
    toggle.MouseButton1Click:Connect(function()
        state = not state
        toggle.BackgroundColor3 = state and THEME.Success or THEME.Error
        toggle.Text = state and "开" or "关"
        if options.Callback then
            options.Callback(state)
        end
    end)

    return toggleFrame, state
end

-- 滑块模块
function PlutoXUILibrary:CreateSlider(parent, options)
    options = options or {}
    local min, max = options.Min or 0, options.Max or 100
    local defaultValue = math.clamp(options.DefaultValue or min, min, max)

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = options.Size or UDim2.new(1, -20, 0, 30)
    sliderFrame.Position = options.Position or UDim2.new(0, 10, 0, 0)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent

    local label = self:CreateLabel(sliderFrame, {
        Text = (options.Text or "Slider") .. ": " .. tostring(defaultValue),
        Size = UDim2.new(1, 0, 0, 15),
        TextSize = 12,
        Font = options.Font or DEFAULT_FONT
    })

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, -10, 0, 5)
    sliderBar.Position = UDim2.new(0, 5, 0, 20)
    sliderBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    sliderBar.Parent = sliderFrame
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 3)
    barCorner.Parent = sliderBar

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 10, 0, 10)
    sliderButton.Position = UDim2.new((defaultValue - min) / (max - min), -5, 0, 17.5)
    sliderButton.BackgroundColor3 = THEME.Primary
    sliderButton.Text = ""
    sliderButton.Parent = sliderFrame
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 5)
    buttonCorner.Parent = sliderButton

    local value = defaultValue
    local dragging = false

    local function updateSlider(input)
        local delta = input.Position.X - sliderFrame.AbsolutePosition.X
        local maxWidth = sliderFrame.AbsoluteSize.X - 10
        local newPos = math.clamp(delta, 0, maxWidth)
        value = min + (newPos / maxWidth) * (max - min)
        value = math.round(value)
        sliderButton.Position = UDim2.new(newPos / maxWidth, -5, 0, 17.5)
        label.Text = (options.Text or "Slider") .. ": " .. value
        if options.Callback then
            options.Callback(value)
        end
    end

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)

    sliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
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
function PlutoXUILibrary:CreateTable(parent, options)
    options = options or {}
    local tableFrame = Instance.new("Frame")
    tableFrame.Size = options.Size or UDim2.new(1, -20, 0, 100)
    tableFrame.Position = options.Position or UDim2.new(0, 10, 0, 0)
    tableFrame.BackgroundColor3 = THEME.Background
    tableFrame.BackgroundTransparency = 0.6
    tableFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
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
                TextSize = 12,
                Font = options.Font or DEFAULT_FONT
            })
        end
    end

    return tableFrame
end

-- 滚动框架模块
function PlutoXUILibrary:CreateScrollingFrame(parent, options)
    options = options or {}
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = options.Size or UDim2.new(1, -20, 0, 100)
    scrollingFrame.Position = options.Position or UDim2.new(0, 10, 0, 0)
    scrollingFrame.BackgroundColor3 = THEME.Background
    scrollingFrame.BackgroundTransparency = 0.6
    scrollingFrame.ScrollBarThickness = 6
    scrollingFrame.CanvasSize = options.CanvasSize or UDim2.new(0, 0, 0, 0)
    scrollingFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = scrollingFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scrollingFrame

    return scrollingFrame
end

-- 弹窗模块
function PlutoXUILibrary:CreateModal(parent, options)
    options = options or {}
    local modalFrame = Instance.new("Frame")
    modalFrame.Size = options.Size or UDim2.new(0, 200, 0, 150)
    modalFrame.Position = UDim2.new(0.5, -100, 0.5, -75)
    modalFrame.BackgroundColor3 = THEME.Background
    modalFrame.BackgroundTransparency = 0.3
    modalFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = modalFrame

    local title = self:CreateLabel(modalFrame, {
        Text = options.Title or "Modal",
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.new(0, 10, 0, 10),
        TextSize = 16,
        Font = options.Font or DEFAULT_FONT
    })

    local closeButton = self:CreateButton(modalFrame, {
        Text = "X",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(1, -35, 0, 10),
        Callback = function()
            modalFrame:Destroy()
        end
    })

    return modalFrame
end

-- 拖拽模块
function PlutoXUILibrary:MakeDraggable(gui, options)
    options = options or {}
    local dragging = false
    local startPos, startGuiPos

    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = input.Position
            startGuiPos = gui.Position
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
        end
    end)
end

-- 主窗口模块
function PlutoXUILibrary:CreateWindow(options)
    options = options or {}
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PlutoXUI"
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    screenGui.ResetOnSpawn = false

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = options.Size or UDim2.new(0, 300, 0, 360)
    mainFrame.Position = options.Position or UDim2.new(0, 60, 0, 10)
    mainFrame.BackgroundColor3 = THEME.Background
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = mainFrame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 37, 38)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 48, 50))
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.4)
    })
    gradient.Parent = mainFrame

    local titleLabel = self:CreateLabel(mainFrame, {
        Text = options.Title or "Pluto-X UI",
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.new(0, 10, 0, 10),
        TextSize = 18,
        Font = options.Font or DEFAULT_FONT
    })

    return mainFrame, screenGui
end

-- 作者介绍模块
function PlutoXUILibrary:CreateAuthorInfo(parent, options)
    options = options or {}
    local authorFrame = Instance.new("Frame")
    authorFrame.Size = options.Size or UDim2.new(1, -20, 0, 30)
    authorFrame.Position = options.Position or UDim2.new(0, 10, 0, 300)
    authorFrame.BackgroundColor3 = THEME.Accent
    authorFrame.BackgroundTransparency = 0.7
    authorFrame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = authorFrame

    local authorLabel = self:CreateLabel(authorFrame, {
        Text = options.AuthorName or "作者: Unknown",
        Size = UDim2.new(0.5, 0, 0, 20),
        Position = UDim2.new(0, 5, 0, 5),
        TextSize = 12,
        Font = options.Font or DEFAULT_FONT
    })

    local socialButton = self:CreateButton(authorFrame, {
        Text = options.SocialText or "Social: Join",
        Size = UDim2.new(0.5, -5, 0, 20),
        Position = UDim2.new(0.5, 0, 0, 5),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        BackgroundTransparency = 1,
        Callback = options.SocialCallback or function()
            self:Notify("Social", "No link provided", 5, false)
        end,
        Font = options.Font or DEFAULT_FONT
    })

    -- 动画效果
    socialButton.MouseEnter:Connect(function()
        TweenService:Create(socialButton, TWEEN_INFO, { TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end)
    socialButton.MouseLeave:Connect(function()
        TweenService:Create(socialButton, TWEEN_INFO, { TextSize = 12, TextColor3 = THEME.Text }):Play()
    end)
    socialButton.MouseButton1Click:Connect(function()
        TweenService:Create(socialButton, TWEEN_INFO, { TextColor3 = THEME.Success }):Play()
        wait(0.5)
        TweenService:Create(socialButton, TWEEN_INFO, { TextColor3 = THEME.Text }):Play()
    end)

    return authorFrame
end

-- 主题切换模块
function PlutoXUILibrary:SetTheme(element, theme)
    theme = theme or THEME
    element.BackgroundColor3 = theme.Background or THEME.Background
    if element:IsA("TextButton") or element:IsA("TextLabel") or element:IsA("TextBox") then
        element.TextColor3 = theme.Text or THEME.Text
    end
    for _, child in ipairs(element:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("TextBox") or child:IsA("ScrollingFrame") then
            self:SetTheme(child, theme)
        end
    end
end

return PlutoXUILibrary
