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
    PRIMARY_COLOR = Color3.fromRGB(0, 120, 215) -- Win10 蓝色
end

-- 默认主题 - Win10 风格
local DEFAULT_THEME = {
    Primary = Color3.fromRGB(0, 120, 215),
    Background = Color3.fromRGB(243, 243, 243),
    SecondaryBackground = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(0, 90, 158),
    Text = Color3.fromRGB(0, 0, 0),
    TextSecondary = Color3.fromRGB(96, 96, 96),
    Success = Color3.fromRGB(16, 124, 16),
    Error = Color3.fromRGB(232, 17, 35),
    Border = Color3.fromRGB(213, 213, 213),
    Shadow = Color3.fromRGB(0, 0, 0),
    Font = Enum.Font.SourceSans
}

-- UI 样式常量 - 响应式设计
local UI_STYLES = {
    CardHeightSingle = 64,
    CardHeightMulti = 96,
    ButtonHeight = 32,
    LabelHeight = 24,
    TabButtonHeight = 48,
    Padding = 12,
    YPadding = 12,
    CornerRadius = 4,
    WindowWidth = 480,
    WindowHeight = 640,
    SidebarWidth = 48,
    TitleBarHeight = 32,
    NotificationSpacing = 8,
    NotificationWidth = 320,
    NotificationMargin = 16,
    ShadowSize = 8,
    BorderSize = 1
}

-- 备选字体
local function getAvailableFont()
    local fonts = {Enum.Font.SourceSans, Enum.Font.Gotham, Enum.Font.Arial}
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
    TextSecondary = DEFAULT_THEME.TextSecondary,
    Success = DEFAULT_THEME.Success,
    Error = DEFAULT_THEME.Error,
    Border = DEFAULT_THEME.Border,
    Shadow = DEFAULT_THEME.Shadow,
    Font = getAvailableFont()
}

-- 验证主题值
for key, value in pairs(THEME) do
    if key ~= "Font" and value == nil then
        warn("[Theme]: Invalid value for " .. key .. ", using default")
        THEME[key] = DEFAULT_THEME[key]
    end
end

-- 动画配置 - 苹果风格缓动
UILibrary.TWEEN_INFO_SMOOTH = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
UILibrary.TWEEN_INFO_QUICK = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
UILibrary.TWEEN_INFO_SPRING = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
UILibrary.THEME = THEME
UILibrary.UI_STYLES = UI_STYLES

-- 添加阴影效果
local function addShadow(element)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    shadow.ImageColor3 = THEME.Shadow
    shadow.ImageTransparency = 0.85
    shadow.Size = UDim2.new(1, UI_STYLES.ShadowSize * 2, 1, UI_STYLES.ShadowSize * 2)
    shadow.Position = UDim2.new(0, -UI_STYLES.ShadowSize, 0, -UI_STYLES.ShadowSize)
    shadow.ZIndex = element.ZIndex - 1
    shadow.Parent = element
    return shadow
end

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
    
    local totalHeight = UI_STYLES.NotificationMargin
    
    for _, notifData in ipairs(UILibrary._notifications) do
        if notifData.frame and notifData.frame.Parent then
            local estimatedHeight = notifData.estimatedHeight or 88
            totalHeight = totalHeight + estimatedHeight + UI_STYLES.NotificationSpacing
        end
    end
    
    return screenSize.Y - totalHeight - 88
end

-- 重新排列通知
local function rearrangeNotifications()
    if UILibrary._isProcessingQueue then
        return
    end
    
    UILibrary._isProcessingQueue = true
    
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
    end
    
    local currentY = UI_STYLES.NotificationMargin
    
    for i = #UILibrary._notifications, 1, -1 do
        local notifData = UILibrary._notifications[i]
        if notifData.frame and notifData.frame.Parent and notifData.frame.Visible then
            local frameHeight = notifData.frame.AbsoluteSize.Y > 0 and notifData.frame.AbsoluteSize.Y or notifData.estimatedHeight or 88
            local targetY = screenSize.Y - currentY - frameHeight
            local targetPos = UDim2.new(1, -UI_STYLES.NotificationMargin, 0, targetY)
            
            if notifData.moveTween then
                notifData.moveTween:Cancel()
            end
            
            if math.abs(notifData.frame.Position.Y.Offset - targetY) > 1 then
                notifData.moveTween = TweenService:Create(notifData.frame, UILibrary.TWEEN_INFO_SMOOTH, {
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
    
    local slideOutTween = TweenService:Create(notification, UILibrary.TWEEN_INFO_SMOOTH, {
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

-- 通知模块
function UILibrary:Notify(options)
    options = options or {}
    if not initNotificationContainer() then
        warn("[Notification]: Failed to initialize ScreenGui")
        return nil
    end

    UILibrary._notificationId = UILibrary._notificationId + 1
    local notificationId = UILibrary._notificationId

    local targetY = calculateNotificationYPosition()
    local estimatedHeight = 88

    local notification = Instance.new("Frame")
    notification.Name = "Notification_" .. notificationId
    notification.Size = UDim2.new(0, UI_STYLES.NotificationWidth, 0, 0)
    notification.AutomaticSize = Enum.AutomaticSize.Y
    notification.AnchorPoint = Vector2.new(1, 0)
    notification.BackgroundColor3 = THEME.SecondaryBackground
    notification.BackgroundTransparency = 1
    notification.BorderSizePixel = UI_STYLES.BorderSize
    notification.BorderColor3 = THEME.Border
    notification.Parent = notificationContainer
    notification.Visible = true
    notification.ZIndex = 21

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = notification

    addShadow(notification)

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
        TextSize = 14,
        Font = Enum.Font.SourceSansSemibold
    })
    titleLabel.ZIndex = 22

    local textLabel = self:CreateLabel(notification, {
        Text = options.Text or "",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextSize = 12,
        TextWrapped = true,
        TextColor3 = THEME.TextSecondary
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
        local delayTime = math.min(#UILibrary._notifications * 0.08, 0.4)
        task.wait(delayTime)
        
        if notification.Parent then
            notificationData.slideInTween = TweenService:Create(notification, UILibrary.TWEEN_INFO_SPRING, {
                Position = UDim2.new(1, -UI_STYLES.NotificationMargin, 0, targetY),
                BackgroundTransparency = 0
            })
            notificationData.slideInTween:Play()
        end
    end)

    task.spawn(function()
        local totalWaitTime = notificationData.duration + (math.min(#UILibrary._notifications * 0.08, 0.4))
        task.wait(totalWaitTime)
        
        if not notificationData.isRemoved and notification.Parent and notificationData.frame then
            removeNotification(notificationData)
        end
    end)

    return notification
end

-- 应用淡入/淡出动画
function UILibrary:ApplyFadeTweens(target, tweenInfo, isVisible)
    local tweens = {}
    if target:IsA("Frame") or target:IsA("ScrollingFrame") then
        local transparency = isVisible and 0 or 1
        table.insert(tweens, TweenService:Create(target, tweenInfo, {BackgroundTransparency = transparency}))
    elseif target:IsA("TextLabel") or target:IsA("TextButton") then
        table.insert(tweens, TweenService:Create(target, tweenInfo, {TextTransparency = isVisible and 0 or 1}))
    end
    for _, child in ipairs(target:GetDescendants()) do
        if child:IsA("Frame") or child:IsA("ScrollingFrame") then
            local transparency = isVisible and 0 or 1
            table.insert(tweens, TweenService:Create(child, tweenInfo, {BackgroundTransparency = transparency}))
        elseif child:IsA("TextLabel") or child:IsA("TextButton") then
            table.insert(tweens, TweenService:Create(child, tweenInfo, {TextTransparency = isVisible and 0 or 1}))
        end
    end
    return tweens
end

-- 创建卡片 - 响应式宽度
function UILibrary:CreateCard(parent, options)
    if not parent then
        warn("[Card]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, 0, 0, 0) -- 填充父容器宽度
    card.BackgroundColor3 = THEME.SecondaryBackground
    card.BackgroundTransparency = 0
    card.BorderSizePixel = UI_STYLES.BorderSize
    card.BorderColor3 = THEME.Border
    card.Parent = parent
    card.Visible = true
    card.ZIndex = 2

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = card

    addShadow(card)

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = card

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingTop = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingBottom = UDim.new(0, UI_STYLES.Padding)
    padding.Parent = card

    TweenService:Create(card, self.TWEEN_INFO_SMOOTH, {
        BackgroundTransparency = 0
    }):Play()

    return card
end

-- 按钮模块 - 响应式宽度
function UILibrary:CreateButton(parent, options)
    if not parent then
        warn("[Button]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}
    local button = Instance.new("TextButton")
    button.Name = "Button_" .. (options.Text or "Unnamed")
    button.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight) -- 填充父容器宽度
    button.BackgroundColor3 = options.BackgroundColor3 or THEME.Primary
    button.BackgroundTransparency = options.BackgroundTransparency or 0
    button.BorderSizePixel = 0
    button.Text = options.Text or ""
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 13
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
            TweenService:Create(button, self.TWEEN_INFO_QUICK, {
                Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, originalSize.Y.Scale, originalSize.Y.Offset * 0.92)
            }):Play()
            task.wait(0.1)
            TweenService:Create(button, self.TWEEN_INFO_SPRING, {Size = originalSize}):Play()
            local success, err = pcall(options.Callback)
            if not success then
                warn("[Button]: Callback failed: ", err)
            end
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_QUICK, {
            BackgroundColor3 = THEME.Accent
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_QUICK, {
            BackgroundColor3 = options.BackgroundColor3 or THEME.Primary
        }):Play()
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
    button.Size = UDim2.new(0, 48, 0, 48)
    button.Position = UDim2.new(1, -64, 1, -80)
    button.BackgroundColor3 = THEME.Primary
    button.BackgroundTransparency = 0
    button.BorderSizePixel = 0
    button.Text = options.Text or "≡"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 20
    button.Font = THEME.Font
    button.Rotation = 0
    button.Parent = parent
    button.Visible = true
    button.ZIndex = 15
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 24)
    corner.Parent = button

    addShadow(button)

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
            button.Text = isVisible and "×" or "≡"
            mainFrame.Visible = true
            mainFrame.Position = isVisible and (lastKnownPos or firstOpenPos) or firstOpenPos
            mainFrame.ZIndex = isVisible and 5 or 1
            
            local tweens = self:ApplyFadeTweens(mainFrame, self.TWEEN_INFO_SMOOTH, isVisible)
            for _, t in ipairs(tweens) do
                t:Play()
            end
            
            local tween = TweenService:Create(mainFrame, self.TWEEN_INFO_SMOOTH, {
                BackgroundTransparency = isVisible and 0 or 1
            })
            tween:Play()
            tween.Completed:Connect(function()
                if not isVisible then
                    mainFrame.Visible = false
                    lastKnownPos = mainFrame.Position
                end
                button.Active = true
            end)
            
            TweenService:Create(button, self.TWEEN_INFO_SPRING, {
                Rotation = isVisible and 90 or 0
            }):Play()
        end)
    end

    button.MouseEnter:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_QUICK, {
            BackgroundColor3 = THEME.Accent,
            Size = UDim2.new(0, 52, 0, 52)
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_QUICK, {
            BackgroundColor3 = THEME.Primary,
            Size = UDim2.new(0, 48, 0, 48)
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
    label.TextColor3 = options.TextColor3 or THEME.Text
    label.TextSize = options.TextSize or 13
    label.Font = options.Font or THEME.Font
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
        TweenService:Create(label, self.TWEEN_INFO_SMOOTH, {TextTransparency = 0}):Play()
    end)
    if not success then
        warn("[Label]: Animation failed: ", err)
    end

    return label
end

-- 输入框模块 - 响应式宽度
function UILibrary:CreateTextBox(parent, options)
    if not parent then
        warn("[TextBox]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}

    local textBox = Instance.new("TextBox")
    textBox.Name = "TextBox_" .. (options.PlaceholderText or "Unnamed")
    textBox.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight) -- 填充父容器宽度
    textBox.BackgroundColor3 = THEME.SecondaryBackground
    textBox.BackgroundTransparency = 0
    textBox.TextColor3 = THEME.Text
    textBox.TextSize = options.TextSize or 13
    textBox.Font = THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.PlaceholderColor3 = THEME.TextSecondary
    textBox.Text = options.Text or ""
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = UI_STYLES.BorderSize
    textBox.BorderColor3 = THEME.Border
    textBox.Parent = parent
    textBox.ZIndex = 3

    local corner = Instance.new("UICorner", textBox)
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = textBox

    textBox.Focused:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_QUICK, {
            BorderColor3 = THEME.Primary
        }):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_QUICK, {
            BorderColor3 = THEME.Border
        }):Play()
        if options.OnFocusLost then pcall(options.OnFocusLost, textBox.Text) end
    end)

    return textBox
end

-- 开关模块 - 响应式布局
function UILibrary:CreateToggle(parent, options)
    if not parent then
        warn("[Toggle]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "Toggle_" .. (options.Text or "Unnamed")
    toggleFrame.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent
    toggleFrame.ZIndex = 2

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.7, -8, 1, 0),
        TextSize = 13
    })
    label.ZIndex = 3

    local track = Instance.new("Frame", toggleFrame)
    track.Name = "Track"
    track.Size = UDim2.new(0, 40, 0, 20)
    track.Position = UDim2.new(1, -40, 0.5, -10)
    track.BackgroundColor3 = (options.DefaultState and THEME.Success or THEME.Border)
    track.BorderSizePixel = 0
    track.ZIndex = 3
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(0, 10)

    local thumb = Instance.new("TextButton", track)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = options.DefaultState and UDim2.new(0, 22, 0, 2) or UDim2.new(0, 2, 0, 2)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    thumb.Text = ""
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 4
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(0, 8)

    addShadow(thumb)

    local state = options.DefaultState or false
    thumb.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0, 22, 0, 2) or UDim2.new(0, 2, 0, 2)
        local targetColor = state and THEME.Success or THEME.Border
        TweenService:Create(thumb, self.TWEEN_INFO_SPRING, {Position = targetPos}):Play()
        TweenService:Create(track, self.TWEEN_INFO_QUICK, {BackgroundColor3 = targetColor}):Play()
        if options.Callback then pcall(options.Callback, state) end
    end)

    thumb.MouseEnter:Connect(function()
        TweenService:Create(thumb, self.TWEEN_INFO_QUICK, {
            Size = UDim2.new(0, 18, 0, 18),
            Position = state and UDim2.new(0, 21, 0, 1) or UDim2.new(0, 1, 0, 1)
        }):Play()
    end)
    thumb.MouseLeave:Connect(function()
        TweenService:Create(thumb, self.TWEEN_INFO_QUICK, {
            Size = UDim2.new(0, 16, 0, 16),
            Position = state and UDim2.new(0, 22, 0, 2) or UDim2.new(0, 2, 0, 2)
        }):Play()
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
                print("[MakeDraggable]: Drag started: GUI =", gui.Name, "Target =", targetFrame.Name)
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
                print("[MakeDraggable]: Drag ended: GUI =", gui.Name, "Target =", targetFrame.Name)
            end
        end
    end)
end

-- 主窗口模块
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
    local windowWidth = math.min(UI_STYLES.WindowWidth, screenSize.X * 0.85)
    local windowHeight = math.min(UI_STYLES.WindowHeight, screenSize.Y * 0.85)

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
    mainFrame.BackgroundColor3 = THEME.Background
    mainFrame.BackgroundTransparency = 0
    mainFrame.BorderSizePixel = UI_STYLES.BorderSize
    mainFrame.BorderColor3 = THEME.Border
    mainFrame.Parent = screenGui
    mainFrame.Visible = true
    mainFrame.ZIndex = 5
    mainFrame.ClipsDescendants = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = mainFrame

    addShadow(mainFrame)

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, UI_STYLES.SidebarWidth, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
    sidebar.BackgroundTransparency = 0
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    sidebar.Visible = true
    sidebar.ZIndex = 6

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.Parent = sidebar
    
    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingLeft = UDim.new(0, 4)
    sidebarPadding.PaddingRight = UDim.new(0, 4)
    sidebarPadding.PaddingTop = UDim.new(0, 8)
    sidebarPadding.Parent = sidebar

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(0, windowWidth - UI_STYLES.SidebarWidth, 0, UI_STYLES.TitleBarHeight)
    titleBar.Position = UDim2.new(0, UI_STYLES.SidebarWidth, 0, 0)
    titleBar.BackgroundColor3 = THEME.SecondaryBackground
    titleBar.BackgroundTransparency = 0
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    titleBar.Visible = true
    titleBar.ZIndex = 6

    local titleLabel = self:CreateLabel(titleBar, {
        Text = "Home",
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextSize = 14,
        Font = Enum.Font.SourceSansSemibold,
        TextTransparency = 0
    })
    titleLabel.ZIndex = 7

    local mainPage = Instance.new("Frame")
    mainPage.Name = "MainPage"
    mainPage.Size = UDim2.new(0, windowWidth - UI_STYLES.SidebarWidth, 0, windowHeight - UI_STYLES.TitleBarHeight)
    mainPage.Position = UDim2.new(0, UI_STYLES.SidebarWidth, 0, UI_STYLES.TitleBarHeight)
    mainPage.BackgroundColor3 = THEME.Background
    mainPage.BackgroundTransparency = 0
    mainPage.BorderSizePixel = 0
    mainPage.Parent = mainFrame
    mainPage.Visible = true
    mainPage.ZIndex = 6
    mainPage.ClipsDescendants = true

    self:MakeDraggable(titleBar, mainFrame)

    task.delay(0.05, function()
        for _, t in ipairs(self:ApplyFadeTweens(mainFrame, self.TWEEN_INFO_SMOOTH, true)) do
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

-- 标签页模块
function UILibrary:CreateTab(sidebar, titleLabel, mainPage, options)
    if not sidebar or not mainPage or not titleLabel then
        warn("[Tab]: 创建失败 - sidebar、titleLabel 或 mainPage 为 nil")
        return nil, nil
    end

    options = options or {}
    local isActive = options.Active or false
    local tabText = options.Text or "Unnamed"

    local tabButton = Instance.new("TextButton")
    tabButton.Name = "TabButton_" .. tabText
    tabButton.Size = UDim2.new(1, 0, 0, UI_STYLES.TabButtonHeight)
    tabButton.BackgroundColor3 = isActive and THEME.Primary or THEME.SecondaryBackground
    tabButton.BackgroundTransparency = isActive and 0 or 1
    tabButton.BorderSizePixel = 0
    tabButton.Text = ""
    tabButton.Parent = sidebar
    tabButton.ZIndex = 7

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = tabButton

    -- 图标或文字标签
    local iconLabel = self:CreateLabel(tabButton, {
        Text = options.Icon or string.sub(tabText, 1, 1),
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextSize = 18,
        Font = Enum.Font.SourceSansSemibold,
        TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or THEME.TextSecondary
    })
    iconLabel.ZIndex = 8

    if not tabButton then
        warn("[Tab]: 创建失败 - tabButton 为 nil")
        return nil, nil
    end

    local content = Instance.new("ScrollingFrame")
    content.Name = "TabContent_" .. tabText
    content.Size = UDim2.new(1, 0, 1, 0)
    content.Position = isActive and UDim2.new(0, 0, 0, 0) or UDim2.new(1, 0, 0, 0)
    content.BackgroundColor3 = THEME.Background
    content.BackgroundTransparency = isActive and 0 or 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 6
    content.ScrollingEnabled = true
    content.ClipsDescendants = true
    content.CanvasSize = UDim2.new(0, 0, 0, 100)
    content.Visible = isActive
    content.ZIndex = 6
    content.Parent = mainPage

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, UI_STYLES.Padding)
    listLayout.Parent = content

    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
    contentPadding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
    contentPadding.PaddingTop = UDim.new(0, UI_STYLES.YPadding)
    contentPadding.PaddingBottom = UDim.new(0, UI_STYLES.YPadding)
    contentPadding.Parent = content

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        task.defer(function()
            content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + UI_STYLES.YPadding * 2)
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

        TweenService:Create(content, self.TWEEN_INFO_SMOOTH, {
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0
        }):Play()

        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                local isThisButton = btn == tabButton
                TweenService:Create(btn, self.TWEEN_INFO_QUICK, {
                    BackgroundColor3 = isThisButton and THEME.Primary or THEME.SecondaryBackground,
                    BackgroundTransparency = isThisButton and 0 or 1
                }):Play()
                
                local btnIcon = btn:FindFirstChildOfClass("TextLabel")
                if btnIcon then
                    TweenService:Create(btnIcon, self.TWEEN_INFO_QUICK, {
                        TextColor3 = isThisButton and Color3.fromRGB(255, 255, 255) or THEME.TextSecondary
                    }):Play()
                end
            end
        end

        titleLabel.Text = tabText
    end

    tabButton.MouseButton1Click:Connect(switchToThisTab)

    tabButton.MouseEnter:Connect(function()
        if not isActive then
            TweenService:Create(tabButton, self.TWEEN_INFO_QUICK, {
                BackgroundTransparency = 0.5
            }):Play()
        end
    end)

    tabButton.MouseLeave:Connect(function()
        if not isActive then
            TweenService:Create(tabButton, self.TWEEN_INFO_QUICK, {
                BackgroundTransparency = 1
            }):Play()
        end
    end)

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
        TextSize = 13,
        TextColor3 = THEME.TextSecondary
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
        TextSecondary = newTheme.TextSecondary or DEFAULT_THEME.TextSecondary,
        Success = newTheme.Success or DEFAULT_THEME.Success,
        Error = newTheme.Error or DEFAULT_THEME.Error,
        Border = newTheme.Border or DEFAULT_THEME.Border,
        Shadow = newTheme.Shadow or DEFAULT_THEME.Shadow,
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
                element.BorderColor3 = THEME.Border
            elseif element.Name == "Sidebar" then
                element.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
            elseif element.Name == "TitleBar" then
                element.BackgroundColor3 = THEME.SecondaryBackground
            elseif element.Name == "MainPage" or element.Name:match("^TabContent_") then
                element.BackgroundColor3 = THEME.Background
            elseif element.Name == "Card" or element.Name == "AuthorFrame" then
                element.BackgroundColor3 = THEME.SecondaryBackground
                element.BorderColor3 = THEME.Border
            elseif element.Name:match("^Notification_") then
                element.BackgroundColor3 = THEME.SecondaryBackground
                element.BorderColor3 = THEME.Border
            end
        elseif element:IsA("TextButton") then
            if element.Name == "FloatingButton" then
                element.BackgroundColor3 = THEME.Primary
                element.TextColor3 = Color3.fromRGB(255, 255, 255)
                element.Font = THEME.Font
            elseif element.Name:match("^Button_") then
                local isActive = element.BackgroundTransparency == 0
                element.BackgroundColor3 = isActive and THEME.Accent or THEME.Primary
                element.TextColor3 = Color3.fromRGB(255, 255, 255)
                element.Font = THEME.Font
            end
        elseif element:IsA("TextLabel") then
            element.TextColor3 = THEME.Text
            element.Font = THEME.Font
        elseif element:IsA("TextBox") then
            element.BackgroundColor3 = THEME.SecondaryBackground
            element.TextColor3 = THEME.Text
            element.Font = THEME.Font
            element.BorderColor3 = THEME.Border
            element.PlaceholderColor3 = THEME.TextSecondary
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