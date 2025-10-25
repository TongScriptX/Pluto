local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local UILibrary = {}

-- 存储已创建的UI实例
UILibrary._instances = {}

-- 通知队列管理
UILibrary._notifications = {}
UILibrary._notificationId = 0
UILibrary._isProcessingQueue = false

local function decimalToColor3(decimal)
    local r = math.floor(decimal / 65536) % 256
    local g = math.floor(decimal / 256) % 256
    local b = decimal % 256
    return Color3.fromRGB(r, g, b)
end

local PRIMARY_COLOR = rawget(_G, "PRIMARY_COLOR")
if type(PRIMARY_COLOR) == "number" then
    PRIMARY_COLOR = decimalToColor3(PRIMARY_COLOR)
elseif PRIMARY_COLOR == nil then
    PRIMARY_COLOR = Color3.fromRGB(63, 81, 181)
end

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

-- ✨ 优化后的 UI 样式常量（统一到 4pt/8pt 网格，参考苹果设计规范）
local UI_STYLES = {
    CardHeightSingle   = 64,      -- 调整为 8 的倍数
    CardHeightMulti    = 96,      -- 调整为 8 的倍数
    ButtonHeight       = 32,      -- 增加至 32pt，更舒适
    LabelHeight        = 20,      -- 保持
    TabButtonHeight    = 36,      -- 增加至 36pt
    Padding            = 16,      -- ✨ 提升至 16pt（苹果标准内边距）
    YPadding           = 16,      -- ✨ 统一垂直内边距 16pt
    ElementSpacing     = 12,      -- ✨ 元素间间距 12pt（苹果标准）
    CardSpacing        = 16,      -- ✨ 卡片间间距 16pt
    SidebarPadding     = 12,      -- ✨ 侧边栏内边距 12pt
    CornerRadius       = 10,      -- ✨ 提升圆角至 10pt
    WindowWidth        = 400,
    WindowHeight       = 300,
    SidebarWidth       = 80,
    TitleBarHeight     = 40,      -- 增加至 40pt
    ContentPadding     = 16,      -- ✨ 内容区域边距 16pt
    -- 通知相关样式
    NotificationSpacing = 8,      -- 统一至 8pt
    NotificationWidth = 220,      -- 增加宽度
    NotificationMargin = 16       -- 增加边距
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
    Primary = PRIMARY_COLOR or DEFAULT_THEME.Primary,
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

-- ✨ 优化后的动画配置（使用 Quint 缓动，更流畅）
UILibrary.TWEEN_INFO_UI = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
UILibrary.TWEEN_INFO_BUTTON = TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
UILibrary.TWEEN_INFO_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
UILibrary.TWEEN_INFO_NOTIFICATION = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
UILibrary.THEME = THEME
UILibrary.UI_STYLES = UI_STYLES

-- 销毁已存在的UI实例
function UILibrary:DestroyExistingInstances()
    if Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") then
        local playerGui = Players.LocalPlayer.PlayerGui
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name == "PlutoUILibrary" or child.Name == "PlutoUILibraryWindow" then
                child:Destroy()
            end
        end
    end
    UILibrary._instances = {}
    UILibrary._notifications = {}
    UILibrary._notificationId = 0
end

-- 通知容器
local notificationContainer = nil
local screenGui = nil

-- 初始化通知容器
local function initNotificationContainer()
    if not Players.LocalPlayer then
        warn("[Notification]: LocalPlayer not found")
        return false
    end

    if UILibrary._instances.notificationContainer and 
       UILibrary._instances.notificationContainer.Parent and
       UILibrary._instances.screenGui and
       UILibrary._instances.screenGui.Parent then
        notificationContainer = UILibrary._instances.notificationContainer
        screenGui = UILibrary._instances.screenGui
        return true
    end

    local playerGui = Players.LocalPlayer.PlayerGui
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "PlutoUILibrary" then
            child:Destroy()
        end
    end

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
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 15
    
    UILibrary._instances.screenGui = screenGui

    notificationContainer = Instance.new("Frame")
    notificationContainer.Name = "NotificationContainer"
    notificationContainer.Size = UDim2.new(0, UI_STYLES.NotificationWidth + UI_STYLES.NotificationMargin, 1, 0)
    notificationContainer.Position = UDim2.new(1, -(UI_STYLES.NotificationWidth + UI_STYLES.NotificationMargin), 0, 0)
    notificationContainer.BackgroundTransparency = 1
    notificationContainer.Parent = screenGui
    notificationContainer.Visible = true
    notificationContainer.ZIndex = 20
    
    UILibrary._instances.notificationContainer = notificationContainer
    
    return true
end

-- 计算通知Y位置
local function calculateNotificationYPosition()
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
    end
    
    local totalHeight = 20
    
    for _, notifData in ipairs(UILibrary._notifications) do
        if notifData.frame and notifData.frame.Parent then
            local estimatedHeight = notifData.estimatedHeight or 80
            totalHeight = totalHeight + estimatedHeight + UI_STYLES.NotificationSpacing
        end
    end
    
    return screenSize.Y - totalHeight - 80
end

-- 重新排列通知位置
local function rearrangeNotifications()
    if UILibrary._isProcessingQueue then
        return
    end
    
    UILibrary._isProcessingQueue = true
    
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
    end
    
    local currentY = 20
    
    for i = #UILibrary._notifications, 1, -1 do
        local notifData = UILibrary._notifications[i]
        if notifData.frame and notifData.frame.Parent and notifData.frame.Visible then
            local frameHeight = notifData.frame.AbsoluteSize.Y > 0 and notifData.frame.AbsoluteSize.Y or notifData.estimatedHeight or 80
            local targetY = screenSize.Y - currentY - frameHeight
            local targetPos = UDim2.new(1, -UI_STYLES.NotificationMargin, 0, targetY)
            
            if notifData.moveTween then
                notifData.moveTween:Cancel()
            end
            
            if math.abs(notifData.frame.Position.Y.Offset - targetY) > 1 then
                notifData.moveTween = TweenService:Create(notifData.frame, UILibrary.TWEEN_INFO_NOTIFICATION, {
                    Position = targetPos
                })
                notifData.moveTween:Play()
            end
            
            currentY = currentY + frameHeight + UI_STYLES.NotificationSpacing
        end
    end
    
    task.wait(0.05)
    UILibrary._isProcessingQueue = false
end

-- 移除通知
local function removeNotification(notificationData)
    if not notificationData or not notificationData.frame then
        return
    end
    
    local notification = notificationData.frame
    
    if notificationData.moveTween then
        notificationData.moveTween:Cancel()
        notificationData.moveTween = nil
    end
    if notificationData.slideInTween then
        notificationData.slideInTween:Cancel()
        notificationData.slideInTween = nil
    end
    
    notificationData.isRemoved = true
    notificationData.autoRemoveTask = nil
    
    for i, notifData in ipairs(UILibrary._notifications) do
        if notifData.id == notificationData.id then
            table.remove(UILibrary._notifications, i)
            break
        end
    end
    
    local slideOutTween = TweenService:Create(notification, UILibrary.TWEEN_INFO_NOTIFICATION, {
        Position = UDim2.new(1, UI_STYLES.NotificationWidth + UI_STYLES.NotificationMargin, 0, notification.Position.Y.Offset),
        BackgroundTransparency = 1
    })
    
    slideOutTween:Play()
    slideOutTween.Completed:Connect(function()
        if notification and notification.Parent then
            notification:Destroy()
        end
        task.wait(0.1)
        rearrangeNotifications()
    end)
end

-- ✨ 优化后的通知模块
function UILibrary:Notify(options)
    options = options or {}
    if not initNotificationContainer() then
        warn("[Notification]: Failed to initialize ScreenGui")
        return nil
    end

    UILibrary._notificationId = UILibrary._notificationId + 1
    local notificationId = UILibrary._notificationId

    local targetY = calculateNotificationYPosition()
    local estimatedHeight = 80

    local notification = Instance.new("Frame")
    notification.Name = "Notification_" .. notificationId
    notification.Size = UDim2.new(0, UI_STYLES.NotificationWidth, 0, 0)
    notification.AutomaticSize = Enum.AutomaticSize.Y
    notification.AnchorPoint = Vector2.new(1, 0)
    notification.BackgroundColor3 = THEME.Background or DEFAULT_THEME.Background
    notification.BackgroundTransparency = 1
    notification.Parent = notificationContainer
    notification.Visible = true
    notification.ZIndex = 21

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = notification

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingTop = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingBottom = UDim.new(0, UI_STYLES.Padding)
    padding.Parent = notification

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = notification

    local titleLabel = self:CreateLabel(notification, {
        Text = options.Title or "Notification",
        Size = UDim2.new(1, 0, 0, UI_STYLES.LabelHeight),
        TextSize = 13
    })
    titleLabel.ZIndex = 22

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = 11,
        TextWrapped = true
    })
    textLabel.ZIndex = 22

    local notificationData = {
        id = notificationId,
        frame = notification,
        duration = options.Duration or 3,
        startTime = tick(),
        estimatedHeight = estimatedHeight,
        slideInTween = nil,
        moveTween = nil,
        isRemoved = false
    }

    table.insert(UILibrary._notifications, notificationData)

    notification.Position = UDim2.new(1, UI_STYLES.NotificationWidth + UI_STYLES.NotificationMargin, 0, targetY)

    task.spawn(function()
        local attempts = 0
        while notification.AbsoluteSize.Y <= 1 and attempts < 50 do
            task.wait(0.02)
            attempts = attempts + 1
        end
        
        if notification.AbsoluteSize.Y > 1 then
            notificationData.estimatedHeight = notification.AbsoluteSize.Y
        end
        
        rearrangeNotifications()
    end)

    task.spawn(function()
        local delayTime = math.min(#UILibrary._notifications * 0.1, 0.5)
        task.wait(delayTime)
        
        if notification.Parent then
            notificationData.slideInTween = TweenService:Create(notification, UILibrary.TWEEN_INFO_NOTIFICATION, {
                Position = UDim2.new(1, -UI_STYLES.NotificationMargin, 0, targetY),
                BackgroundTransparency = 0.1
            })
            notificationData.slideInTween:Play()
        end
    end)

    task.spawn(function()
        local totalWaitTime = notificationData.duration + (math.min(#UILibrary._notifications * 0.1, 0.5))
        task.wait(totalWaitTime)
        
        if not notificationData.isRemoved and notification.Parent and notificationData.frame then
            removeNotification(notificationData)
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

-- ✨ 优化后的卡片创建（对齐窗口边缘）
function UILibrary:CreateCard(parent, options)
    if not parent then
        warn("[Card]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, 0, 0, 0)  -- ✨ 完全填充宽度，不留边距
    card.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    card.BackgroundTransparency = 0.25
    card.Parent = parent
    card.Visible = true
    card.ZIndex = 2

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)  -- ✨ 卡片内元素间距 8pt
    layout.Parent = card

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingTop = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingBottom = UDim.new(0, UI_STYLES.Padding)
    padding.Parent = card

    TweenService:Create(card, self.TWEEN_INFO_UI, {
        BackgroundTransparency = 0.25
    }):Play()

    return card
end

-- ✨ 优化后的按钮模块
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
    button.BackgroundTransparency = options.BackgroundTransparency or 0.3
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
            -- ✨ 优化点击反馈动画
            local originalSize = button.Size
            TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, originalSize.Y.Scale, originalSize.Y.Offset * 0.96)
            }):Play()
            task.wait(0.08)
            TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = originalSize
            }):Play()
            local success, err = pcall(options.Callback)
            if not success then
                warn("[Button]: Callback failed: ", err)
            end
        end)
    end

    -- ✨ 优化悬停反馈
    button.MouseEnter:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_FAST, {
            BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent,
            BackgroundTransparency = 0.15
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_FAST, {
            BackgroundColor3 = options.BackgroundColor3 or THEME.Primary or DEFAULT_THEME.Primary,
            BackgroundTransparency = options.BackgroundTransparency or 0.3
        }):Play()
    end)

    return button
end

-- ✨ 优化后的悬浮按钮
function UILibrary:CreateFloatingButton(parent, options)
    if not parent then
        warn("[FloatingButton]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local button = Instance.new("TextButton")
    button.Name = "FloatingButton"
    button.Size = UDim2.new(0, 36, 0, 36)
    button.Position = UDim2.new(1, -48, 1, -88)
    button.BackgroundColor3 = THEME.Primary or DEFAULT_THEME.Primary
    button.BackgroundTransparency = 0.15
    button.Text = options.Text or "T"
    button.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    button.TextSize = 14
    button.Font = THEME.Font
    button.Rotation = 0
    button.Parent = parent
    button.Visible = true
    button.ZIndex = 15
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = button

    if not button.Parent then
        warn("[FloatingButton]: Button has no parent after creation")
        button:Destroy()
        return nil
    end

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

    -- ✨ 优化悬浮按钮悬停效果
    button.MouseEnter:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_FAST, {
            BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent,
            Size = UDim2.new(0, 38, 0, 38)
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_FAST, {
            BackgroundColor3 = THEME.Primary or DEFAULT_THEME.Primary,
            Size = UDim2.new(0, 36, 0, 36)
        }):Play()
    end)

    self:MakeDraggable(button, button)
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
    label.Size = options.Size or UDim2.new(1, 0, 0, UI_STYLES.LabelHeight)
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

    if options.AutomaticSize then
        label.AutomaticSize = options.AutomaticSize
    end

    local success, err = pcall(function()
        TweenService:Create(label, self.TWEEN_INFO_UI, {TextTransparency = 0}):Play()
    end)
    if not success then
        warn("[Label]: Animation failed: ", err)
    end

    return label
end

-- ✨ 优化后的输入框模块（与卡片对齐）
function UILibrary:CreateTextBox(parent, options)
    if not parent then
        warn("[TextBox]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}

    local textBox = Instance.new("TextBox")
    textBox.Name = "TextBox_" .. (options.PlaceholderText or "Unnamed")
    textBox.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)  -- ✨ 完全填充宽度
    textBox.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    textBox.BackgroundTransparency = 0.25
    textBox.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    textBox.TextSize = options.TextSize or 12
    textBox.Font = THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.Text = options.Text or ""
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = 2
    textBox.BorderColor3 = THEME.Background or DEFAULT_THEME.Background
    textBox.Parent = parent
    textBox.ZIndex = 3

    local corner = Instance.new("UICorner", textBox)
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)

    -- ✨ 优化聚焦动画
    textBox.Focused:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_FAST, {
            BorderColor3 = THEME.Primary or DEFAULT_THEME.Primary,
            BackgroundTransparency = 0.15
        }):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_FAST, {
            BorderColor3 = THEME.Background or DEFAULT_THEME.Background,
            BackgroundTransparency = 0.25
        }):Play()
        if options.OnFocusLost then pcall(options.OnFocusLost, textBox.Text) end
    end)

    return textBox
end

-- ✨ 优化后的开关模块（与卡片对齐）
function UILibrary:CreateToggle(parent, options)
    if not parent then
        warn("[Toggle]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "Toggle_" .. (options.Text or "Unnamed")
    toggleFrame.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)  -- ✨ 完全填充宽度
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent
    toggleFrame.ZIndex = 2

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(1, -48, 1, 0),  -- ✨ 为开关留出固定空间
        TextSize = 12
    })
    label.ZIndex = 3

    -- ✨ 优化滑块轨道尺寸和圆角
    local track = Instance.new("Frame", toggleFrame)
    track.Name = "Track"
    track.Size = UDim2.new(0, 36, 0, 20)
    track.Position = UDim2.new(1, -36, 0.5, -10)  -- ✨ 右对齐
    track.BackgroundColor3 = (options.DefaultState and (THEME.Success or DEFAULT_THEME.Success)
                              or (THEME.Error or DEFAULT_THEME.Error))
    track.BackgroundTransparency = 0.2
    track.ZIndex = 3
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("TextButton", track)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = options.DefaultState and UDim2.new(0, 18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    thumb.Text = ""
    thumb.ZIndex = 4
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)

    local state = options.DefaultState or false
    
    -- ✨ 优化开关动画（更流畅的滑动）
    thumb.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0, 18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local targetColor = state and (THEME.Success or DEFAULT_THEME.Success) or (THEME.Error or DEFAULT_THEME.Error)
        
        TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            Position = targetPos
        }):Play()
        TweenService:Create(track, self.TWEEN_INFO_FAST, {
            BackgroundColor3 = targetColor
        }):Play()
        
        if options.Callback then pcall(options.Callback, state) end
    end)

    return toggleFrame, state
end

-- 拖拽模块
local developmentMode = false

function UILibrary:MakeDraggable(gui, targetFrame)
    if not gui then
        warn("[MakeDraggable]: Failed: GUI is nil")
        return
    end
    if not targetFrame then
        warn("[MakeDraggable]: Failed: targetFrame is nil")
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
            startGuiOffset = targetFrame.AbsolutePosition
            targetFrame.ZIndex = targetFrame.Name == "FloatingButton" and 15 or 5
            if developmentMode then
                print("[MakeDraggable]: Drag started: GUI =", gui.Name, "Target =", targetFrame.Name, "Position =", tostring(targetFrame.Position))
            end
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
            local guiSize = targetFrame.AbsoluteSize
            local maxX = math.max(0, screenSize.X - math.max(guiSize.X, 1))
            local maxY = math.max(0, screenSize.Y - math.max(guiSize.Y, 1))
            newOffset = Vector2.new(
                math.clamp(newOffset.X, 0, maxX),
                math.clamp(newOffset.Y, 0, maxY)
            )
            targetFrame.Position = UDim2.new(0, newOffset.X, 0, newOffset.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            targetFrame.ZIndex = targetFrame.Name == "FloatingButton" and 15 or 5
            if developmentMode then
                print("[MakeDraggable]: Drag ended: GUI =", gui.Name, "Target =", targetFrame.Name, "Position =", tostring(targetFrame.Position))
            end
        end
    end)
end

-- ✨ 优化后的主窗口模块
function UILibrary:CreateUIWindow(options)
    options = options or {}
    if not Players.LocalPlayer then
        warn("[Window]: LocalPlayer not found")
        return nil
    end

    if UILibrary._instances.mainWindow then
        local oldWindow = UILibrary._instances.mainWindow
        if oldWindow.ScreenGui and oldWindow.ScreenGui.Parent then
            oldWindow.ScreenGui:Destroy()
        end
        UILibrary._instances.mainWindow = nil
    end

    local playerGui = Players.LocalPlayer.PlayerGui
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "PlutoUILibraryWindow" then
            child:Destroy()
        end
    end

    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
    end
    local windowWidth = math.min(UI_STYLES.WindowWidth, screenSize.X * 0.8)
    local windowHeight = math.min(UI_STYLES.WindowHeight, screenSize.Y * 0.8)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PlutoUILibraryWindow"
    local success, err = pcall(function()
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 30)
    end)
    if not success then
        warn("[ScreenGui]: Initialization failed: ", err)
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
    sidebarLayout.Padding = UDim.new(0, UI_STYLES.ElementSpacing)
    sidebarLayout.Parent = sidebar
    
    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingLeft = UDim.new(0, UI_STYLES.SidebarPadding)
    sidebarPadding.PaddingRight = UDim.new(0, UI_STYLES.SidebarPadding)
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

    self:MakeDraggable(titleBar, mainFrame)
    self:MakeDraggable(sidebar, mainFrame)

    task.delay(0.05, function()
        for _, t in ipairs(self:ApplyFadeTweens(mainFrame, self.TWEEN_INFO_UI, true)) do
            t:Play()
        end
    end)

    local windowInstance = {
        MainFrame = mainFrame,
        ScreenGui = screenGui,
        Sidebar = sidebar,
        TitleLabel = titleLabel,
        MainPage = mainPage
    }
    UILibrary._instances.mainWindow = windowInstance

    return windowInstance
end

-- ✨ 优化后的标签页模块
function UILibrary:CreateTab(sidebar, titleLabel, mainPage, options)
    if not sidebar or not mainPage or not titleLabel then
        warn("[Tab]: 创建失败 - sidebar、titleLabel 或 mainPage 为 nil")
        return nil, nil
    end

    options = options or {}
    local isActive = options.Active or false
    local tabText = options.Text or "Unnamed"

    local tabButton = self:CreateButton(sidebar, {
        Text = tabText,
        Size = UDim2.new(1, 0, 0, UI_STYLES.TabButtonHeight),  -- ✨ 完全填充宽度
        BackgroundColor3 = isActive and (THEME.Accent or DEFAULT_THEME.Accent) or (THEME.Primary or DEFAULT_THEME.Primary),
        BackgroundTransparency = isActive and 0 or 0.4
    })

    if not tabButton then
        warn("[Tab]: 创建失败 - tabButton 为 nil")
        return nil, nil
    end
    tabButton.ZIndex = 7

    local content = Instance.new("ScrollingFrame")
    content.Name = "TabContent_" .. tabText
    content.Size = UDim2.new(1, 0, 1, 0)
    content.Position = isActive and UDim2.new(0, 0, 0, 0) or UDim2.new(1, 0, 0, 0)
    content.BackgroundColor3 = THEME.Background or DEFAULT_THEME.Background
    content.BackgroundTransparency = isActive and 0.5 or 1
    content.ScrollBarThickness = 4
    content.ScrollingEnabled = true
    content.ClipsDescendants = true
    content.CanvasSize = UDim2.new(0, 0, 0, 100)
    content.Visible = isActive
    content.ZIndex = 6
    content.Parent = mainPage

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, UI_STYLES.CardSpacing)  -- ✨ 卡片间距 16pt
    listLayout.Parent = content

    -- ✨ 为内容区域添加 Padding（苹果风格：16pt 边距）
    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingLeft = UDim.new(0, UI_STYLES.ContentPadding)
    contentPadding.PaddingRight = UDim.new(0, UI_STYLES.ContentPadding)
    contentPadding.PaddingTop = UDim.new(0, UI_STYLES.ContentPadding)
    contentPadding.PaddingBottom = UDim.new(0, UI_STYLES.ContentPadding)
    contentPadding.Parent = content

    local paddingY = UI_STYLES.ContentPadding * 2  -- ✨ 上下边距总和
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        task.defer(function()
            content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + paddingY)
        end)
    end) = true
    content.CanvasSize = UDim2.new(0, 0, 0, 100)
    content.Visible = isActive
    content.ZIndex = 6
    content.Parent = mainPage

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, UI_STYLES.ElementSpacing)
    listLayout.Parent = content

    local paddingY = UI_STYLES.YPadding
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        task.defer(function()
            content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + paddingY)
        end)
    end)

    local function switchToThisTab()
        for _, child in ipairs(mainPage:GetChildren()) do
            if child:IsA("ScrollingFrame") and child ~= content then
                child.Visible = false
                child.Position = UDim2.new(1, 0, 0, 0)
                child.BackgroundTransparency = 1
                child.ZIndex = 6
                child.CanvasPosition = Vector2.new(0, 0)
            end
        end

        content.Position = UDim2.new(-1, 0, 0, 0)
        content.Visible = true
        content.ZIndex = 6
        content.Size = UDim2.new(1, 0, 1, 0)
        content.CanvasPosition = Vector2.new(0, 0)

        -- ✨ 使用优化后的标签页切换动画
        TweenService:Create(content, self.TWEEN_INFO_UI, {
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0.5
        }):Play()

        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                TweenService:Create(btn, self.TWEEN_INFO_BUTTON, {
                    BackgroundColor3 = btn == tabButton and (THEME.Accent or DEFAULT_THEME.Accent) or (THEME.Primary or DEFAULT_THEME.Primary),
                    BackgroundTransparency = btn == tabButton and 0 or 0.4
                }):Play()
            end
        end

        titleLabel.Text = tabText
    end

    tabButton.MouseButton1Click:Connect(switchToThisTab)

    if isActive then
        task.defer(switchToThisTab)
    end

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