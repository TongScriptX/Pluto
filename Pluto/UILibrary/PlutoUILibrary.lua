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
    PRIMARY_COLOR = Color3.fromRGB(63, 81, 181) -- 默认颜色
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
    Font = Enum.Font.GothamBold  
}  

-- UI 样式常量（调整为 4pt 网格）
local UI_STYLES = {
    CardHeightSingle   = 60,
    CardHeightMulti    = 88,
    ButtonHeight       = 28,
    LabelHeight        = 20,
    TabButtonHeight    = 32,
    Padding            = 8,
    YPadding           = 8,
    CornerRadius       = 12,
    WindowWidth        = 400,
    WindowHeight       = 300,
    SidebarWidth       = 80,
    TitleBarHeight     = 32,
    -- 通知相关样式
    NotificationSpacing = 4,
    NotificationWidth = 200,
    NotificationMargin = 10
}

-- 备选字体（优先粗体）
local function getAvailableFont()
    local fonts = {
        Enum.Font.GothamBold,
        Enum.Font.BuilderSansBold,
        Enum.Font.SourceSansBold,
        Enum.Font.Roboto,
        Enum.Font.Gotham
    }
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
    return Enum.Font.SourceSansBold
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

-- 动画配置
UILibrary.TWEEN_INFO_UI = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
UILibrary.TWEEN_INFO_BUTTON = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
UILibrary.THEME = THEME
UILibrary.DEFAULT_THEME = DEFAULT_THEME
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
    
    -- 清空实例引用
    UILibrary._instances = {}
    
    -- 清空通知队列
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

    -- 检查现有容器是否有效
    if UILibrary._instances.notificationContainer and 
       UILibrary._instances.notificationContainer.Parent and
       UILibrary._instances.screenGui and
       UILibrary._instances.screenGui.Parent then
        notificationContainer = UILibrary._instances.notificationContainer
        screenGui = UILibrary._instances.screenGui
        return true
    end

    -- 销毁旧的通知 ScreenGui
    local playerGui = Players.LocalPlayer.PlayerGui
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "PlutoUILibrary" then
            child:Destroy()
        end
    end

    -- 创建新的ScreenGui
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
    
    -- 存储实例引用
    UILibrary._instances.screenGui = screenGui

    notificationContainer = Instance.new("Frame")
    notificationContainer.Name = "NotificationContainer"
    notificationContainer.Size = UDim2.new(0, UI_STYLES.NotificationWidth + UI_STYLES.NotificationMargin, 1, 0)
    notificationContainer.Position = UDim2.new(1, -(UI_STYLES.NotificationWidth + UI_STYLES.NotificationMargin), 0, 0)
    notificationContainer.BackgroundTransparency = 1
    notificationContainer.Parent = screenGui
    notificationContainer.Visible = true
    notificationContainer.ZIndex = 20
    
    -- 存储实例引用
    UILibrary._instances.notificationContainer = notificationContainer
    
    return true
end

-- 计算通知应该显示的Y位置
local function calculateNotificationYPosition()
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
    end
    
    local totalHeight = 20
    
    -- 计算所有现有通知占用的高度
    for _, notifData in ipairs(UILibrary._notifications) do
        if notifData.frame and notifData.frame.Parent and not notifData.isRemoved then
            local actualHeight = notifData.frame.AbsoluteSize.Y
            local heightToUse = actualHeight > 0 and actualHeight or (notifData.estimatedHeight or 80)
            totalHeight = totalHeight + heightToUse + UI_STYLES.NotificationSpacing
        end
    end
    
    -- 从屏幕底部向上计算位置
    return screenSize.Y - totalHeight
end

-- 重新排列所有通知位置
local function rearrangeNotifications()
    local screenSize = GuiService:GetScreenResolution()
    if screenSize == Vector2.new(0, 0) then
        screenSize = Vector2.new(720, 1280)
    end
    
    local currentY = 20
    
    -- 从最新的通知开始，从下往上重新排列
    for i = #UILibrary._notifications, 1, -1 do
        local notifData = UILibrary._notifications[i]
        if notifData.frame and notifData.frame.Parent and not notifData.isRemoved and notifData.frame.Visible then
            -- 使用实际高度
            local frameHeight = notifData.frame.AbsoluteSize.Y
            if frameHeight <= 0 then
                frameHeight = notifData.estimatedHeight or 80
            end
            
            local targetY = screenSize.Y - currentY - frameHeight
            local targetPos = UDim2.new(1, -UI_STYLES.NotificationMargin, 0, targetY)
            
            -- 取消之前的移动动画
            if notifData.moveTween then
                notifData.moveTween:Cancel()
            end
            
            -- 创建新的移动动画
            if math.abs(notifData.frame.Position.Y.Offset - targetY) > 1 then
                notifData.moveTween = TweenService:Create(notifData.frame, UILibrary.TWEEN_INFO_UI, {
                    Position = targetPos
                })
                notifData.moveTween:Play()
            end
            
            currentY = currentY + frameHeight + UI_STYLES.NotificationSpacing
        end
    end
end

-- 移除通知
local function removeNotification(notificationData)
    if not notificationData or not notificationData.frame then
        return
    end
    
    local notification = notificationData.frame
    
    -- 停止所有相关动画
    if notificationData.moveTween then
        notificationData.moveTween:Cancel()
        notificationData.moveTween = nil
    end
    if notificationData.slideInTween then
        notificationData.slideInTween:Cancel()
        notificationData.slideInTween = nil
    end
    
    -- 标记为已移除，防止自动移除任务继续执行
    notificationData.isRemoved = true
    notificationData.autoRemoveTask = nil
    
    -- 从队列中移除
    for i, notifData in ipairs(UILibrary._notifications) do
        if notifData.id == notificationData.id then
            table.remove(UILibrary._notifications, i)
            break
        end
    end
    
    -- 独立的滑出动画
    local slideOutTween = TweenService:Create(notification, UILibrary.TWEEN_INFO_UI, {
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

    -- 生成唯一ID
    UILibrary._notificationId = UILibrary._notificationId + 1
    local notificationId = UILibrary._notificationId

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
    listLayout.Padding = UDim.new(0, 2)
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

    -- 创建通知数据
    local notificationData = {
        id = notificationId,
        frame = notification,
        duration = options.Duration or 3,
        startTime = tick(),
        estimatedHeight = 80,
        slideInTween = nil,
        moveTween = nil,
        isRemoved = false
    }

    -- 等待布局计算完成，获取实际高度
    task.spawn(function()
        local attempts = 0
        while notification.AbsoluteSize.Y <= 1 and attempts < 50 do
            task.wait(0.02)
            attempts = attempts + 1
        end
        
        if notification.AbsoluteSize.Y > 1 then
            notificationData.estimatedHeight = notification.AbsoluteSize.Y
        end
        
        -- 获取实际高度后，添加到队列并计算位置
        table.insert(UILibrary._notifications, notificationData)
        
        -- 计算并设置目标位置
        local targetY = calculateNotificationYPosition()
        notification.Position = UDim2.new(1, UI_STYLES.NotificationWidth + UI_STYLES.NotificationMargin, 0, targetY)
        
        -- 立即执行滑入动画
        notificationData.slideInTween = TweenService:Create(notification, UILibrary.TWEEN_INFO_UI, {
            Position = UDim2.new(1, -UI_STYLES.NotificationMargin, 0, targetY),
            BackgroundTransparency = 0.1
        })
        notificationData.slideInTween:Play()
        
        -- 重新排列所有通知
        rearrangeNotifications()
    end)

    -- 自动移除通知
    task.spawn(function()
        task.wait(notificationData.duration)
        
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

-- 创建卡片
function UILibrary:CreateCard(parent, options)
    if not parent then
        warn("[Card]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, 0, 0, 0)
    card.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    card.BackgroundTransparency = 0.3
    card.Parent = parent
    card.Visible = true
    card.ZIndex = 2

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    corner.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = card

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 2)
    padding.Parent = card

    -- 动画仅用于初始位置，不再设置固定透明度
    TweenService:Create(card, self.TWEEN_INFO_UI, {
        BackgroundTransparency = 0.3
    }):Play()

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
    button.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)
    button.BackgroundColor3 = options.BackgroundColor3 or THEME.Primary or DEFAULT_THEME.Primary
    button.BackgroundTransparency = options.BackgroundTransparency or 0.4
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
        local isAnimating = false
        local initialSize = button.Size
        
        button.MouseButton1Click:Connect(function()
            if isAnimating then return end
            isAnimating = true
            
            TweenService:Create(button, self.TWEEN_INFO_BUTTON, {Size = UDim2.new(initialSize.X.Scale, initialSize.X.Offset * 0.95, initialSize.Y.Scale, initialSize.Y.Offset * 0.95)}):Play()
            task.wait(0.1)
            TweenService:Create(button, self.TWEEN_INFO_BUTTON, {Size = initialSize}):Play()
            
            local success, err = pcall(options.Callback)
            if not success then
                warn("[Button]: Callback failed: ", err)
            end
            
            task.wait(0.05)
            isAnimating = false
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
            corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)    corner.Parent = button

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

    button.MouseEnter:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = THEME.Primary or DEFAULT_THEME.Primary}):Play()
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

    -- 添加自动高度支持
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

-- 输入框模块
function UILibrary:CreateTextBox(parent, options)
    if not parent then
        warn("[TextBox]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}
    local tbPad = UI_STYLES.Padding or 6

    local textBox = Instance.new("TextBox")
    textBox.Name = "TextBox_" .. (options.PlaceholderText or "Unnamed")
    textBox.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)
    textBox.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    textBox.BackgroundTransparency = 0.3
    textBox.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    textBox.TextSize = options.TextSize or 12
    textBox.Font = THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.Text = options.Text or ""
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = 1
    textBox.BorderColor3 = THEME.Background or DEFAULT_THEME.Background
    textBox.Parent = parent
    textBox.ZIndex = 3

    local corner = Instance.new("UICorner", textBox)
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)

    textBox.Focused:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_BUTTON, {
            BorderColor3 = THEME.Primary or DEFAULT_THEME.Primary
        }):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(textBox, self.TWEEN_INFO_BUTTON, {
            BorderColor3 = THEME.Background or DEFAULT_THEME.Background
        }):Play()
        if options.OnFocusLost then pcall(options.OnFocusLost, textBox.Text) end
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
    local tgPad = UI_STYLES.Padding or 6

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "Toggle_" .. (options.Text or "Unnamed")
    toggleFrame.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent
    toggleFrame.ZIndex = 2

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, -tgPad, 1, 0),
        TextSize = 12
    })
    label.ZIndex = 3

    local track = Instance.new("Frame", toggleFrame)
    track.Name = "Track"
    track.Size = UDim2.new(0, 30, 0, 8)
    track.Position = UDim2.new(0.65, 0, 0.5, -4)
    track.BackgroundColor3 = (options.DefaultState and (THEME.Success or DEFAULT_THEME.Success)
                              or (THEME.Error or DEFAULT_THEME.Error))
    track.ZIndex = 3
    local trackCorner = Instance.new("UICorner", track)
            trackCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    local thumb = Instance.new("TextButton", track)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 15, 0, 15)
    thumb.Position = options.DefaultState and UDim2.new(0, 15, 0, -4) or UDim2.new(0, 0, 0, -4)
    thumb.BackgroundColor3 = Color3.new(1,1,1)
    thumb.Text = ""
    thumb.ZIndex = 4
    local thumbCorner = Instance.new("UICorner", thumb)
            thumbCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)
    local state = options.DefaultState or false
    thumb.MouseButton1Click:Connect(function()
        state = not state
        local targetPos = state and UDim2.new(0, 15, 0, -4) or UDim2.new(0, 0, 0, -4)
        local targetColor = state and (THEME.Success or DEFAULT_THEME.Success) or (THEME.Error or DEFAULT_THEME.Error)
        TweenService:Create(thumb, self.TWEEN_INFO_BUTTON, {Position = targetPos}):Play()
        TweenService:Create(track, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = targetColor}):Play()
        if options.Callback then pcall(options.Callback, state) end
    end)

    return toggleFrame, state
end

-- 下拉框模块
function UILibrary:CreateDropdown(parent, options)
    if not parent then
        warn("[Dropdown]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}
    local ddPad = UI_STYLES.Padding or 6

    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Name = "Dropdown_" .. (options.Text or "Unnamed")
    dropdownFrame.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)
    dropdownFrame.BackgroundTransparency = 1
    dropdownFrame.Parent = parent
    dropdownFrame.ZIndex = 100

    local label = self:CreateLabel(dropdownFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.2, -ddPad, 1, 0),
        TextSize = 12
    })
    label.ZIndex = 101

    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Name = "DropdownButton"
    dropdownButton.Size = UDim2.new(0.8, -ddPad, 0, UI_STYLES.ButtonHeight)
    dropdownButton.Position = UDim2.new(0.2, ddPad, 0, 0)
    dropdownButton.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    dropdownButton.BackgroundTransparency = 0.3
    dropdownButton.BorderSizePixel = 1
    dropdownButton.BorderColor3 = THEME.Background or DEFAULT_THEME.Background
    dropdownButton.Text = options.DefaultOption or "选择选项"
    dropdownButton.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    dropdownButton.TextSize = 11
    dropdownButton.Font = THEME.Font
    dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
    dropdownButton.Parent = dropdownFrame
    dropdownButton.ZIndex = 101

    local buttonCorner = Instance.new("UICorner", dropdownButton)
    buttonCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)

    local arrowLabel = Instance.new("TextLabel")
    arrowLabel.Name = "Arrow"
    arrowLabel.Size = UDim2.new(0, 20, 1, 0)
    arrowLabel.Position = UDim2.new(1, -20, 0, 0)
    arrowLabel.BackgroundTransparency = 1
    arrowLabel.Text = "▼"
    arrowLabel.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    arrowLabel.TextSize = 10
    arrowLabel.Font = THEME.Font
    arrowLabel.Parent = dropdownButton
    arrowLabel.ZIndex = 102

    local optionsList = Instance.new("ScrollingFrame")
    optionsList.Name = "OptionsList"
    optionsList.Size = UDim2.new(0.8, -ddPad, 0, 0)
    optionsList.Position = UDim2.new(0.2, ddPad, 1, 4)
    optionsList.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    optionsList.BackgroundTransparency = 0.3
    optionsList.BorderSizePixel = 1
    optionsList.BorderColor3 = THEME.Background or DEFAULT_THEME.Background
    optionsList.ScrollBarThickness = 4
    optionsList.ScrollBarImageColor3 = THEME.Primary or DEFAULT_THEME.Primary
    optionsList.Visible = false
    optionsList.ZIndex = 99999
    
    local screenGui = parent
    while screenGui and screenGui.ClassName ~= "ScreenGui" do
        screenGui = screenGui.Parent
    end
    if screenGui then
        optionsList.Parent = screenGui
    else
        optionsList.Parent = dropdownFrame
    end

    local optionsListCorner = Instance.new("UICorner", optionsList)
    optionsListCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)

    local optionsListLayout = Instance.new("UIListLayout")
    optionsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    optionsListLayout.Padding = UDim.new(0, 2)
    optionsListLayout.Parent = optionsList

    local optionsListPadding = Instance.new("UIPadding")
    optionsListPadding.PaddingLeft = UDim.new(0, 4)
    optionsListPadding.PaddingRight = UDim.new(0, 4)
    optionsListPadding.PaddingTop = UDim.new(0, 4)
    optionsListPadding.PaddingBottom = UDim.new(0, 4)
    optionsListPadding.Parent = optionsList

    local isOpen = false
    local selectedOption = options.DefaultOption or nil

    -- 创建选项按钮
    local function createOptions()
        for _, child in ipairs(optionsList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for i, option in ipairs(options.Options or {}) do
            local optionButton = Instance.new("TextButton")
            optionButton.Name = "Option_" .. i
            optionButton.Size = UDim2.new(1, 0, 0, 24)
            optionButton.BackgroundColor3 = THEME.Background or DEFAULT_THEME.Background
            optionButton.BackgroundTransparency = 0.5
            optionButton.BorderSizePixel = 0
            optionButton.Text = tostring(option)
            optionButton.TextColor3 = THEME.Text or DEFAULT_THEME.Text
            optionButton.TextSize = 11
            optionButton.Font = THEME.Font
            optionButton.TextXAlignment = Enum.TextXAlignment.Left
            optionButton.Parent = optionsList
            optionButton.ZIndex = 1001

            local optionCorner = Instance.new("UICorner", optionButton)
            optionCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)

            optionButton.MouseEnter:Connect(function()
                TweenService:Create(optionButton, self.TWEEN_INFO_BUTTON, {
                    BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent,
                    BackgroundTransparency = 0.5
                }):Play()
            end)

            optionButton.MouseLeave:Connect(function()
                TweenService:Create(optionButton, self.TWEEN_INFO_BUTTON, {
                    BackgroundColor3 = THEME.Background or DEFAULT_THEME.Background,
                    BackgroundTransparency = 0.5
                }):Play()
            end)

            optionButton.MouseButton1Click:Connect(function()
                selectedOption = tostring(option)
                dropdownButton.Text = selectedOption
                isOpen = false
                optionsList.Visible = false
                arrowLabel.Text = "▼"
                
                if options.Callback then
                    pcall(options.Callback, selectedOption)
                end
            end)
        end

        -- 更新选项列表高度
        local contentHeight = #options.Options * 28 + 8
        optionsList.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
    end

    createOptions()

    -- 切换下拉框显示状态
    dropdownButton.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        optionsList.Visible = isOpen
        arrowLabel.Text = isOpen and "▲" or "▼"

        if isOpen then
            -- 计算绝对位置
            local buttonAbsolutePos = dropdownButton.AbsolutePosition
            local buttonAbsoluteSize = dropdownButton.AbsoluteSize
            local screenGuiPos = optionsList.Parent.AbsolutePosition
            
            optionsList.Position = UDim2.new(0, buttonAbsolutePos.X - screenGuiPos.X, 0, buttonAbsolutePos.Y + buttonAbsoluteSize.Y + 4)
            
            -- 设置实际高度
            local listHeight = math.min(200, #options.Options * 28 + 8)
            optionsList.Size = UDim2.new(0, buttonAbsoluteSize.X, 0, listHeight)
            TweenService:Create(optionsList, self.TWEEN_INFO_UI, {
                BackgroundTransparency = 0.3
            }):Play()
        else
            -- 隐藏时重置高度为0
            optionsList.Size = UDim2.new(0, 0, 0, 0)
            TweenService:Create(optionsList, self.TWEEN_INFO_UI, {
                BackgroundTransparency = 0.3
            }):Play()
        end
    end)

    dropdownButton.MouseEnter:Connect(function()
        TweenService:Create(dropdownButton, self.TWEEN_INFO_BUTTON, {
            BorderColor3 = THEME.Primary or DEFAULT_THEME.Primary
        }):Play()
    end)

    dropdownButton.MouseLeave:Connect(function()
        TweenService:Create(dropdownButton, self.TWEEN_INFO_BUTTON, {
            BorderColor3 = THEME.Background or DEFAULT_THEME.Background
        }):Play()
    end)

    return dropdownFrame
end

-- 滑块模块
function UILibrary:CreateSlider(parent, options)
    if not parent then
        warn("[Slider]: Creation failed: Parent is nil")
        return nil
    end

    options = options or {}
    local tgPad = UI_STYLES.Padding or 6
    local minValue = options.Min or 0
    local maxValue = options.Max or 100
    local defaultValue = options.Default or minValue
    local suffix = options.Suffix or ""

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = "Slider_" .. (options.Text or "Unnamed")
    sliderFrame.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = parent
    sliderFrame.ZIndex = 2

    -- 标签（左侧，使用CreateLabel保持一致）
    local label = self:CreateLabel(sliderFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.35, -tgPad, 1, 0),
        TextSize = 12
    })
    label.ZIndex = 3

    -- 值输入框（右侧固定宽度，可点击编辑）
    local valueInput = Instance.new("TextBox")
    valueInput.Name = "ValueInput"
    valueInput.Size = UDim2.new(0, 45, 0, 20)
    valueInput.Position = UDim2.new(1, -45, 0.5, -10)
    valueInput.BackgroundTransparency = 0.8
    valueInput.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    valueInput.BorderSizePixel = 0
    valueInput.Text = tostring(defaultValue) .. suffix
    valueInput.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    valueInput.TextSize = 11
    valueInput.Font = THEME.Font
    valueInput.TextXAlignment = Enum.TextXAlignment.Center
    valueInput.ClearTextOnFocus = true
    valueInput.Parent = sliderFrame
    valueInput.ZIndex = 3
    
    local valueInputCorner = Instance.new("UICorner")
            valueInputCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)    valueInputCorner.Parent = valueInput

    -- 滑块轨道（直接放在sliderFrame中，左侧是标签，右侧是数值框）
    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, -110, 0, 6)
    track.Position = UDim2.new(0, 70, 0.5, -3)
    track.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    track.BorderSizePixel = 0
    track.Parent = sliderFrame
    track.ZIndex = 3

    local trackCorner = Instance.new("UICorner")
            trackCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)    trackCorner.Parent = track

    -- 滑块填充（使用主题强调色）
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new((defaultValue - minValue) / (maxValue - minValue), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    fill.ZIndex = 4

    local fillCorner = Instance.new("UICorner")
            fillCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadius)    fillCorner.Parent = fill

    -- 滑块按钮（与Toggle的thumb一致）
    local thumb = Instance.new("TextButton")
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = UDim2.new((defaultValue - minValue) / (maxValue - minValue), -6, 0.5, -6)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    thumb.Text = ""
    thumb.Parent = track
    thumb.ZIndex = 5

    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0.5, 0)
    thumbCorner.Parent = thumb

    local currentValue = defaultValue
    local isDragging = false

    local function updateSliderVisuals(value)
        local percent = (value - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        thumb.Position = UDim2.new(percent, -6, 0.5, -6)
        valueInput.Text = tostring(value) .. suffix
    end

    local function setValue(value)
        value = math.clamp(math.floor(value), minValue, maxValue)
        if value ~= currentValue then
            currentValue = value
            updateSliderVisuals(value)
            if options.Callback then
                pcall(options.Callback, value)
            end
        end
    end

    local function updateSlider(inputPosition)
        local trackAbsolutePos = track.AbsolutePosition
        local trackAbsoluteSize = track.AbsoluteSize
        local relativeX = inputPosition.X - trackAbsolutePos.X
        local percent = math.clamp(relativeX / trackAbsoluteSize.X, 0, 1)
        local value = math.floor(minValue + (maxValue - minValue) * percent)
        setValue(value)
    end
    
    -- 输入框失去焦点时更新值
    valueInput.FocusLost:Connect(function()
        local text = valueInput.Text:gsub(suffix, ""):match("%d+")
        local num = tonumber(text)
        if num then
            setValue(num)
        else
            -- 输入无效，恢复原值
            valueInput.Text = tostring(currentValue) .. suffix
        end
    end)

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
        end
    end)

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            updateSlider(input.Position)
            isDragging = true
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    return sliderFrame, function() return currentValue end, setValue
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

-- 主窗口模块
function UILibrary:CreateUIWindow(options)
    options = options or {}
    if not Players.LocalPlayer then
        warn("[Window]: LocalPlayer not found")
        return nil
    end

    -- 销毁已存在的主窗口实例
    if UILibrary._instances.mainWindow then
        local oldWindow = UILibrary._instances.mainWindow
        if oldWindow.ScreenGui and oldWindow.ScreenGui.Parent then
            oldWindow.ScreenGui:Destroy()
        end
        UILibrary._instances.mainWindow = nil
    end

    -- 额外检查并销毁遗留的窗口GUI
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

    self:MakeDraggable(titleBar, mainFrame)
    self:MakeDraggable(sidebar, mainFrame)

    task.delay(0.05, function()
        for _, t in ipairs(self:ApplyFadeTweens(mainFrame, self.TWEEN_INFO_UI, true)) do
            t:Play()
        end
    end)

    -- 存储实例引用
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

    local tabButton = self:CreateButton(sidebar, {
        Text = tabText,
        Size = UDim2.new(1, 0, 0, UI_STYLES.TabButtonHeight),
        BackgroundColor3 = isActive and (THEME.Accent or DEFAULT_THEME.Accent) or (THEME.Primary or DEFAULT_THEME.Primary),
        BackgroundTransparency = isActive and 0 or 0.5
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
    listLayout.Padding = UDim.new(0, UI_STYLES.Padding or 6)
    listLayout.Parent = content

    local paddingY = UI_STYLES.YPadding or 10
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

        TweenService:Create(content, self.TWEEN_INFO_UI, {
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0.5
        }):Play()

        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                TweenService:Create(btn, self.TWEEN_INFO_BUTTON, {
                    BackgroundColor3 = btn == tabButton and (THEME.Accent or DEFAULT_THEME.Accent) or (THEME.Primary or DEFAULT_THEME.Primary),
                    BackgroundTransparency = btn == tabButton and 0 or 0.5
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