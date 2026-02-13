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

-- 默认主题（深色毛玻璃效果）
local DEFAULT_THEME = {
    Primary = Color3.fromRGB(63, 81, 181),       -- 原紫色主色
    Background = Color3.fromRGB(20, 20, 24),     -- 深色背景（毛玻璃基底）
    SecondaryBackground = Color3.fromRGB(40, 42, 50), -- 深灰卡片（毛玻璃效果）
    Accent = Color3.fromRGB(92, 107, 192),       -- 紫色强调
    Text = Color3.fromRGB(255, 255, 255),        -- 白色文字
    Success = Color3.fromRGB(76, 175, 80),       -- 绿色
    Error = Color3.fromRGB(244, 67, 54),         -- 红色
    Font = Enum.Font.GothamBold
}  

-- UI 样式常量（层级化圆角系统）
local UI_STYLES = {
    CardHeightSingle   = 60,
    CardHeightMulti    = 88,
    ButtonHeight       = 28,
    LabelHeight        = 20,
    TabButtonHeight    = 32,
    SubTabButtonHeight = 26,  -- 子标签页按钮高度（更紧凑）
    SubTabBarHeight    = 36,  -- 子标签页栏高度
    Padding            = 8,
    YPadding           = 8,
    -- 层级化圆角：小元素4px，中元素6px，大元素10px，容器14px
    CornerRadiusSmall  = 4,   -- 滑块轨道、输入框
    CornerRadiusMedium = 6,   -- 按钮、开关
    CornerRadiusLarge  = 10,  -- 卡片
    CornerRadiusXLarge = 14,  -- 窗口、主面板
    CornerRadiusPill   = 16,  -- 胶囊形状（子标签页）
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
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusMedium)
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
    -- 使用主题色或默认值，确保不透明避免灰色
    card.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground or Color3.fromRGB(40, 42, 50)
    card.BackgroundTransparency = 0.1  -- 毛玻璃效果
    card.BorderSizePixel = 0
    card.Parent = parent
    card.Visible = true
    card.ZIndex = 2

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusLarge)
    corner.Parent = card

    -- 毛玻璃边框效果（深色背景下的玻璃边缘）
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)  -- 白色边缘
    stroke.Transparency = 0.85  -- 半透明确保深色背景可见
    stroke.Thickness = 1
    stroke.Parent = card

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
    button.TextSize = options.TextSize or 12
    button.Font = THEME.Font
    button.Parent = parent
    button.Visible = true
    button.ZIndex = 3

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusMedium)
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

-- 灵动岛悬浮按钮模块
function UILibrary:CreateFloatingButton(parent, options)
    if not parent then
        warn("[FloatingButton]: Creation failed: Parent is nil")
        return nil
    end
    options = options or {}

    -- TopBar 配置（根据 CoreGui.TopBarApp.TopBarApp.MenuIconHolder）
    local TOPBAR_HEIGHT = 48
    local TOPBAR_OFFSET = 10
    
    -- 灵动岛尺寸配置（参考 UnibarMenu['2']）
    local ISLAND_WIDTH_COLLAPSED = 100
    local ISLAND_WIDTH_EXPANDED = 160
    local ISLAND_HEIGHT_COLLAPSED = 44
    local ISLAND_HEIGHT_EXPANDED = 44
    local ISLAND_RADIUS = 22
    local ISLAND_BG_COLOR = Color3.fromRGB(0, 0, 0)
    local ISLAND_BG_TRANSPARENCY = 0.35
    local ISLAND_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
    local TOP_OFFSET = TOPBAR_OFFSET + (TOPBAR_HEIGHT - ISLAND_HEIGHT_COLLAPSED) / 2

    -- 确保parent是ScreenGui且设置IgnoreGuiInset
    local screenGui = parent
    if parent.ClassName ~= "ScreenGui" then
        screenGui = parent:FindFirstAncestorOfClass("ScreenGui")
    end
    if screenGui and screenGui.ClassName == "ScreenGui" then
        screenGui.IgnoreGuiInset = true
    end

    -- 创建灵动岛容器
    local island = Instance.new("Frame")
    island.Name = "DynamicIsland"
    island.Size = UDim2.new(0, ISLAND_WIDTH_COLLAPSED, 0, ISLAND_HEIGHT_COLLAPSED)
    island.Position = UDim2.new(0.5, -ISLAND_WIDTH_COLLAPSED/2, 0, TOP_OFFSET)
    island.BackgroundColor3 = ISLAND_BG_COLOR
    island.BackgroundTransparency = ISLAND_BG_TRANSPARENCY
    island.BorderSizePixel = 0
    island.Parent = parent
    island.Visible = true
    island.ZIndex = 100
    island.ClipsDescendants = true

    local islandCorner = Instance.new("UICorner")
    islandCorner.CornerRadius = UDim.new(0, ISLAND_RADIUS)
    islandCorner.Parent = island

    -- 内容容器
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "ContentContainer"
    contentContainer.Size = UDim2.new(1, 0, 1, 0)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = island

    -- 收缩状态：显示时间
    local collapsedContent = Instance.new("Frame")
    collapsedContent.Name = "CollapsedContent"
    collapsedContent.Size = UDim2.new(1, 0, 1, 0)
    collapsedContent.BackgroundTransparency = 1
    collapsedContent.Parent = contentContainer

    -- 时间显示
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Name = "TimeLabel"
    timeLabel.Size = UDim2.new(1, 0, 1, 0)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = "00:00"
    timeLabel.TextColor3 = ISLAND_TEXT_COLOR
    timeLabel.TextSize = 12
    timeLabel.Font = Enum.Font.GothamBold
    timeLabel.Parent = collapsedContent

    -- 更新时间的函数
    local function updateTime()
        local now = os.time()
        local utc8Time = now + 8 * 3600
        local hours = math.floor((utc8Time % 86400) / 3600)
        local minutes = math.floor((utc8Time % 3600) / 60)
        timeLabel.Text = string.format("%02d:%02d", hours, minutes)
    end

    task.spawn(function()
        while island and island.Parent do
            updateTime()
            task.wait(1)
        end
    end)

    -- 展开状态内容
    local expandedContent = Instance.new("Frame")
    expandedContent.Name = "ExpandedContent"
    expandedContent.Size = UDim2.new(1, 0, 1, 0)
    expandedContent.BackgroundTransparency = 1
    expandedContent.Visible = false
    expandedContent.Parent = contentContainer

    local expandedIcon = Instance.new("TextLabel")
    expandedIcon.Name = "Icon"
    expandedIcon.Size = UDim2.new(0, 18, 0, 18)
    expandedIcon.Position = UDim2.new(0, 8, 0.5, -9)
    expandedIcon.BackgroundTransparency = 1
    expandedIcon.Text = "◈"
    expandedIcon.TextColor3 = ISLAND_TEXT_COLOR
    expandedIcon.TextSize = 14
    expandedIcon.Font = THEME.Font
    expandedIcon.Parent = expandedContent

    -- 展开状态的文字
    local expandedLabel = Instance.new("TextLabel")
    expandedLabel.Name = "Label"
    expandedLabel.Size = UDim2.new(1, -50, 1, 0)
    expandedLabel.Position = UDim2.new(0, 34, 0, 0)
    expandedLabel.BackgroundTransparency = 1
    expandedLabel.Text = "隐藏窗口"
    expandedLabel.TextColor3 = ISLAND_TEXT_COLOR
    expandedLabel.TextSize = 12
    expandedLabel.Font = THEME.Font
    expandedLabel.TextXAlignment = Enum.TextXAlignment.Left
    expandedLabel.Parent = expandedContent

    -- 状态变量
    local isExpanded = false
    local isAnimating = false
    local mainFrame = options.MainFrame
    local uiVisible = true

    -- 动画配置
    local EXPAND_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
    local COLLAPSE_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)
    local FADE_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
    local MOVE_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- 获取窗口中心位置
    local function getCenterPosition()
        if mainFrame then
            local size = mainFrame.AbsoluteSize
            return UDim2.new(0.5, -size.X/2, 0.5, -size.Y/2)
        end
        return UDim2.new(0.5, -200, 0.5, -150)
    end

    -- 应用淡入/淡出动画到所有子元素
    local function applyFadeToAll(frame, targetTransparency)
        local tweens = {}
        
        local function processElement(element)
            if element:IsA("Frame") then
                local baseTransparency = element:GetAttribute("BaseTransparency")
                if baseTransparency then
                    table.insert(tweens, TweenService:Create(element, FADE_TWEEN, {
                        BackgroundTransparency = targetTransparency == 0 and tonumber(baseTransparency) or 1
                    }))
                end
            elseif element:IsA("TextLabel") or element:IsA("TextButton") then
                table.insert(tweens, TweenService:Create(element, FADE_TWEEN, {
                    TextTransparency = targetTransparency
                }))
            elseif element:IsA("ImageLabel") or element:IsA("ImageButton") then
                table.insert(tweens, TweenService:Create(element, FADE_TWEEN, {
                    ImageTransparency = targetTransparency
                }))
            end
            
            for _, child in ipairs(element:GetChildren()) do
                processElement(child)
            end
        end
        
        processElement(frame)
        return tweens
    end

    -- 展开动画（横向和纵向同时展开）
    local function expandIsland()
        if isAnimating or isExpanded then return end
        isAnimating = true

        -- 同时展开宽度和高度
        TweenService:Create(island, EXPAND_TWEEN, {
            Size = UDim2.new(0, ISLAND_WIDTH_EXPANDED, 0, ISLAND_HEIGHT_EXPANDED),
            Position = UDim2.new(0.5, -ISLAND_WIDTH_EXPANDED/2, 0, TOP_OFFSET)
        }):Play()

        task.wait(0.15)
        collapsedContent.Visible = false
        expandedContent.Visible = true
        expandedLabel.Text = uiVisible and "隐藏窗口" or "显示窗口"

        isExpanded = true
        isAnimating = false
    end

    -- 收缩动画（横向和纵向同时收缩）
    local function collapseIsland()
        if isAnimating or not isExpanded then return end
        isAnimating = true

        expandedContent.Visible = false
        collapsedContent.Visible = true

        -- 同时收缩宽度和高度
        TweenService:Create(island, COLLAPSE_TWEEN, {
            Size = UDim2.new(0, ISLAND_WIDTH_COLLAPSED, 0, ISLAND_HEIGHT_COLLAPSED),
            Position = UDim2.new(0.5, -ISLAND_WIDTH_COLLAPSED/2, 0, TOP_OFFSET)
        }):Play()

        isExpanded = false
        isAnimating = false
    end

    -- 点击灵动岛
    island.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not isAnimating then
                if isExpanded then
                    uiVisible = not uiVisible
                    expandedLabel.Text = uiVisible and "隐藏窗口" or "显示窗口"

                    if mainFrame then
                        if uiVisible then
                            -- 显示窗口
                            mainFrame.Visible = true
                            mainFrame.BackgroundTransparency = 1
                            expandedLabel.Text = "显示中..."
                            
                            local fadeTweens = applyFadeToAll(mainFrame, 0)
                            table.insert(fadeTweens, TweenService:Create(mainFrame, FADE_TWEEN, {
                                BackgroundTransparency = 0.15
                            }))
                            for _, tween in ipairs(fadeTweens) do
                                tween:Play()
                            end
                            
                            task.wait(0.8)
                        else
                            -- 隐藏窗口（不再移动到中心，直接淡出）
                            expandedLabel.Text = "隐藏中..."
                            
                            local fadeTweens = applyFadeToAll(mainFrame, 1)
                            table.insert(fadeTweens, TweenService:Create(mainFrame, FADE_TWEEN, {
                                BackgroundTransparency = 1
                            }))
                            for _, tween in ipairs(fadeTweens) do
                                tween:Play()
                            end
                            
                            task.wait(0.35)
                            mainFrame.Visible = false
                            task.wait(0.2)
                        end
                    else
                        task.wait(0.5)
                    end

                    collapseIsland()
                else
                    expandIsland()
                end
            end
        end
    end)

    -- 点击其他地方收回
    local function onOutsideClick(input)
        if isExpanded and not isAnimating then
            local mousePos = Vector2.new(input.Position.X, input.Position.Y)
            local islandPos = island.AbsolutePosition
            local islandSize = island.AbsoluteSize

            if mousePos.X < islandPos.X or mousePos.X > islandPos.X + islandSize.X or
               mousePos.Y < islandPos.Y or mousePos.Y > islandPos.Y + islandSize.Y then
                collapseIsland()
            end
        end
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            onOutsideClick(input)
        end
    end)

    -- 悬停效果
    island.MouseEnter:Connect(function()
        if not isExpanded and not isAnimating then
            TweenService:Create(island, TweenInfo.new(0.15), {
                Size = UDim2.new(0, ISLAND_WIDTH_COLLAPSED + 6, 0, ISLAND_HEIGHT_COLLAPSED + 2),
                Position = UDim2.new(0.5, -(ISLAND_WIDTH_COLLAPSED + 6)/2, 0, TOP_OFFSET)
            }):Play()
        end
    end)

    island.MouseLeave:Connect(function()
        if not isExpanded and not isAnimating then
            TweenService:Create(island, TweenInfo.new(0.15), {
                Size = UDim2.new(0, ISLAND_WIDTH_COLLAPSED, 0, ISLAND_HEIGHT_COLLAPSED),
                Position = UDim2.new(0.5, -ISLAND_WIDTH_COLLAPSED/2, 0, TOP_OFFSET)
            }):Play()
        end
    end)

    return island
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

    -- 创建容器 Frame
    local container = Instance.new("Frame")
    container.Name = "TextBoxContainer_" .. (options.PlaceholderText or "Unnamed")
    container.Size = UDim2.new(1, 0, 0, UI_STYLES.ButtonHeight)
    container.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = parent
    container.ZIndex = 3

    local corner = Instance.new("UICorner", container)
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusSmall)
    
    -- 添加与卡片一致的边框到容器
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.6
    stroke.Thickness = 1
    stroke.Parent = container

    -- 创建 TextBox 作为子元素
    local textBox = Instance.new("TextBox")
    textBox.Name = "TextBox"
    textBox.Size = UDim2.new(1, -tbPad * 2, 1, 0)
    textBox.Position = UDim2.new(0, tbPad, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.TextColor3 = THEME.Text or DEFAULT_THEME.Text
    textBox.TextSize = options.TextSize or 12
    textBox.Font = THEME.Font
    textBox.PlaceholderText = options.PlaceholderText or ""
    textBox.Text = options.Text or ""
    textBox.TextWrapped = true
    textBox.TextTruncate = Enum.TextTruncate.AtEnd
    textBox.BorderSizePixel = 0
    textBox.ClearTextOnFocus = options.ClearTextOnFocus or false
    textBox.Parent = container
    textBox.ZIndex = 4

    textBox.Focused:Connect(function()
        TweenService:Create(stroke, self.TWEEN_INFO_BUTTON, {
            Color = THEME.Primary or DEFAULT_THEME.Primary,
            Transparency = 0.3
        }):Play()
    end)
    textBox.FocusLost:Connect(function()
        TweenService:Create(stroke, self.TWEEN_INFO_BUTTON, {
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 0.6
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
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = parent
    toggleFrame.ZIndex = 2
    
    -- 延迟设置避免默认灰色
    task.spawn(function()
        game:GetService("RunService").Heartbeat:Wait()
        toggleFrame.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
        toggleFrame.BackgroundTransparency = 0.999
    end)

    local label = self:CreateLabel(toggleFrame, {
        Text = options.Text or "",
        Size = UDim2.new(0.6, -tgPad, 1, 0),
        TextSize = 12
    })
    label.ZIndex = 3

    -- 胶囊样式开关（与整体 UI 协调）
    local track = Instance.new("Frame", toggleFrame)
    track.Name = "Track"
    -- 尺寸与 ButtonHeight(28) 协调，高度约 70%
    track.Size = UDim2.new(0, 36, 0, 20)
    track.Position = UDim2.new(1, -(36 + tgPad), 0.5, -10)
    track.BackgroundColor3 = (options.DefaultState and (THEME.Success or DEFAULT_THEME.Success)
                              or (THEME.Error or DEFAULT_THEME.Error))
    track.ZIndex = 3

    -- 完全圆角（胶囊形状）
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(0.5, 0)

    -- 圆形滑块
    local thumb = Instance.new("TextButton", track)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, 16, 0, 16)
    -- 开启时靠右 (36-16-2=18)，关闭时靠左 (2)
    thumb.Position = options.DefaultState and UDim2.new(0, 18, 0, 2) or UDim2.new(0, 2, 0, 2)
    thumb.BackgroundColor3 = Color3.new(1,1,1)
    thumb.Text = ""
    thumb.ZIndex = 4

    -- 滑块圆形
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(0.5, 0)

    local state = options.DefaultState or false
    
    local function toggleSwitch()
        state = not state
        local targetPos = state and UDim2.new(0, 18, 0, 2) or UDim2.new(0, 2, 0, 2)
        local targetColor = state and (THEME.Success or DEFAULT_THEME.Success) or (THEME.Error or DEFAULT_THEME.Error)
        TweenService:Create(thumb, self.TWEEN_INFO_BUTTON, {Position = targetPos}):Play()
        TweenService:Create(track, self.TWEEN_INFO_BUTTON, {BackgroundColor3 = targetColor}):Play()
        if options.Callback then pcall(options.Callback, state) end
    end
    
    thumb.MouseButton1Click:Connect(toggleSwitch)
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            toggleSwitch()
        end
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
    buttonCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusMedium)

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
    optionsListCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusLarge)

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
            optionCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusSmall)

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
    sliderFrame.Parent = parent
    sliderFrame.ZIndex = 2
    
    -- 延迟设置避免默认灰色
    task.spawn(function()
        game:GetService("RunService").Heartbeat:Wait()
        sliderFrame.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
        sliderFrame.BackgroundTransparency = 0.999
    end)

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
            valueInputCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusSmall)
    valueInputCorner.Parent = valueInput

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
            trackCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusSmall)
    trackCorner.Parent = track

    -- 滑块填充（使用主题强调色）
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new((defaultValue - minValue) / (maxValue - minValue), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent or DEFAULT_THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    fill.ZIndex = 4

    local fillCorner = Instance.new("UICorner")
            fillCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusSmall)
    fillCorner.Parent = fill

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
    local dragFinalValue = nil

    local function updateSliderVisuals(value)
        local percent = (value - minValue) / (maxValue - minValue)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        thumb.Position = UDim2.new(percent, -6, 0.5, -6)
        valueInput.Text = tostring(value) .. suffix
    end

    local function setValue(value, callCallback)
        value = math.clamp(math.floor(value), minValue, maxValue)
        if value ~= currentValue then
            currentValue = value
            updateSliderVisuals(value)
            if callCallback and options.Callback then
                pcall(options.Callback, value)
            end
        end
    end

    local function updateSlider(inputPosition, callCallback)
        local trackAbsolutePos = track.AbsolutePosition
        local trackAbsoluteSize = track.AbsoluteSize
        local relativeX = inputPosition.X - trackAbsolutePos.X
        local percent = math.clamp(relativeX / trackAbsoluteSize.X, 0, 1)
        local value = math.floor(minValue + (maxValue - minValue) * percent)
        setValue(value, callCallback)
    end
    
    valueInput.FocusLost:Connect(function()
        local text = valueInput.Text:gsub(suffix, ""):match("%d+")
        local num = tonumber(text)
        if num then
            setValue(num, true)
        else
            valueInput.Text = tostring(currentValue) .. suffix
        end
    end)

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragFinalValue = currentValue
        end
    end)

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            updateSlider(input.Position, false)
            isDragging = true
            dragFinalValue = currentValue
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position, false)
            dragFinalValue = currentValue
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDragging = false
            if options.Callback and dragFinalValue ~= nil then
                pcall(options.Callback, dragFinalValue)
            end
            dragFinalValue = nil
        end
    end)

    return sliderFrame, function() return currentValue end, setValue
end

-- 拖拽模块
local developmentMode = false
local DEBUG_DRAG = false

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
    local startMousePos = Vector2.new(0, 0)
    local startFramePos = Vector2.new(0, 0)

    local function isMouseOverGui(input)
        local mousePos = Vector2.new(input.Position.X, input.Position.Y)
        local guiPos = gui.AbsolutePosition
        local guiSize = gui.AbsoluteSize
        return mousePos.X >= guiPos.X and mousePos.X <= guiPos.X + guiSize.X 
           and mousePos.Y >= guiPos.Y and mousePos.Y <= guiPos.Y + guiSize.Y
    end

    UserInputService.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isMouseOverGui(input) then
            dragging = true
            startMousePos = Vector2.new(input.Position.X, input.Position.Y)
            
            -- 立即获取并锁定位置
            local currentAbsPos = targetFrame.AbsolutePosition
            startFramePos = Vector2.new(currentAbsPos.X, currentAbsPos.Y)
            
            -- 立即锁定为像素定位
            targetFrame.Position = UDim2.new(0, startFramePos.X, 0, startFramePos.Y)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        
        local currentMousePos = Vector2.new(input.Position.X, input.Position.Y)
        local delta = currentMousePos - startMousePos
        local newFramePos = startFramePos + delta
        
        local screenSize = GuiService:GetScreenResolution()
        if screenSize.X == 0 then screenSize = Vector2.new(720, 1280) end
        
        local frameSize = targetFrame.AbsoluteSize
        newFramePos = Vector2.new(
            math.clamp(newFramePos.X, 0, screenSize.X - frameSize.X),
            math.clamp(newFramePos.Y, 0, screenSize.Y - frameSize.Y)
        )
        
        targetFrame.Position = UDim2.new(0, newFramePos.X, 0, newFramePos.Y)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
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
    mainFrame.BackgroundTransparency = 1  -- 初始透明，用于淡入动画
    mainFrame.Parent = screenGui
    mainFrame.Visible = true
    mainFrame.ZIndex = 5
    mainFrame.ClipsDescendants = true
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusXLarge)
    corner.Parent = mainFrame

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, UI_STYLES.SidebarWidth, 1, 0)
    sidebar.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    sidebar.BackgroundTransparency = 1  -- 初始透明，用于入场动画
    sidebar.Parent = mainFrame
    sidebar.Visible = true
    sidebar.ZIndex = 6
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusXLarge)
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
    titleBar.BackgroundTransparency = 1  -- 初始透明，用于入场动画
    titleBar.Parent = mainFrame
    titleBar.Visible = true
    titleBar.ZIndex = 6
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusXLarge)
    titleCorner.Parent = titleBar

    local titleLabel = self:CreateLabel(titleBar, {
        Text = "Home",
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextSize = 16
    })
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.ZIndex = 7

    local mainPage = Instance.new("Frame")
    mainPage.Name = "MainPage"
    mainPage.Size = UDim2.new(0, windowWidth - UI_STYLES.SidebarWidth, 0, windowHeight - UI_STYLES.TitleBarHeight)
    mainPage.Position = UDim2.new(0, UI_STYLES.SidebarWidth, 0, UI_STYLES.TitleBarHeight)
    mainPage.BackgroundColor3 = THEME.SecondaryBackground or DEFAULT_THEME.SecondaryBackground
    mainPage.BackgroundTransparency = 1  -- 初始透明，用于入场动画
    mainPage.Parent = mainFrame
    mainPage.Visible = true
    mainPage.ZIndex = 6
    mainPage.ClipsDescendants = true
    local pageCorner = Instance.new("UICorner")
    pageCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusXLarge)
    pageCorner.Parent = mainPage
    
    -- 添加左右边距，让内容有呼吸空间
    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingLeft = UDim.new(0, 16)
    pagePadding.PaddingRight = UDim.new(0, 16)
    pagePadding.PaddingTop = UDim.new(0, 12)
    pagePadding.PaddingBottom = UDim.new(0, 12)
    pagePadding.Parent = mainPage

    self:MakeDraggable(titleBar, mainFrame)
    self:MakeDraggable(sidebar, mainFrame)

    -- 入场动画：淡入效果
    task.delay(0.05, function()
        -- 主窗口透明度渐变
        TweenService:Create(mainFrame, self.TWEEN_INFO_UI, {
            BackgroundTransparency = 0.15
        }):Play()
        
        -- Sidebar 淡入
        TweenService:Create(sidebar, self.TWEEN_INFO_UI, {
            BackgroundTransparency = 0.1
        }):Play()
        
        -- TitleBar 淡入
        TweenService:Create(titleBar, self.TWEEN_INFO_UI, {
            BackgroundTransparency = 0
        }):Play()
        
        -- MainPage 淡入
        TweenService:Create(mainPage, self.TWEEN_INFO_UI, {
            BackgroundTransparency = 0.5
        }):Play()
        
        -- 其他子元素（文本等）淡入
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
        TextSize = 13,
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
    content.ScrollBarThickness = 4
    
    -- 延迟设置透明背景，避免默认灰色（与 Toggle 一致）
    task.spawn(function()
        game:GetService("RunService").Heartbeat:Wait()
        content.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
        content.BackgroundTransparency = 0.999
    end)
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

    -- 简化CanvasSize更新，移除task.defer避免递归
    local paddingY = UI_STYLES.YPadding or 10
    local lastCanvasHeight = 0
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local newHeight = listLayout.AbsoluteContentSize.Y
        if math.abs(newHeight - lastCanvasHeight) > 2 then
            lastCanvasHeight = newHeight
            content.CanvasSize = UDim2.new(0, 0, 0, newHeight + paddingY)
        end
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

-- 子标签页容器模块
function UILibrary:CreateSubTabs(tabContent, options)
    if not tabContent then
        warn("[SubTabs]: 创建失败 - tabContent 为 nil")
        return nil
    end

    options = options or {}
    local subTabItems = options.Items or {}
    
    -- 如果Items为空或nil，直接返回nil，不留空
    if #subTabItems == 0 then
        return nil
    end
    
    local defaultActive = options.DefaultActive or 1
    local onSwitch = options.OnSwitch
    
    -- 创建子标签页按钮容器
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "SubTabsButtonContainer"
    buttonContainer.Size = UDim2.new(1, 0, 0, UI_STYLES.SubTabBarHeight)
    buttonContainer.BorderSizePixel = 0
    buttonContainer.Parent = tabContent
    buttonContainer.ZIndex = 7
    buttonContainer.Visible = true
    
    -- 延迟设置避免默认灰色（参考Toggle和Slider）
    task.spawn(function()
        game:GetService("RunService").Heartbeat:Wait()
        buttonContainer.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
        buttonContainer.BackgroundTransparency = 0.99
    end)
    
    -- 添加边框（参考Card的做法）
    local containerStroke = Instance.new("UIStroke")
    containerStroke.Color = Color3.fromRGB(255, 255, 255)
    containerStroke.Transparency = 0.95
    containerStroke.Thickness = 1
    containerStroke.Parent = buttonContainer
    
    -- 水平布局
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = buttonContainer
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.Parent = buttonContainer
    
    -- 创建内容容器（所有子标签页内容都放这里）
    local contentContainer = Instance.new("Frame")
    contentContainer.Name = "SubTabsContentContainer"
    contentContainer.Size = UDim2.new(1, 0, 1, -UI_STYLES.SubTabBarHeight)
    contentContainer.Position = UDim2.new(0, 0, 0, UI_STYLES.SubTabBarHeight)
    contentContainer.BorderSizePixel = 0
    contentContainer.Parent = tabContent
    contentContainer.ZIndex = 6
    

    
    -- 延迟设置避免默认灰色
    task.spawn(function()
        game:GetService("RunService").Heartbeat:Wait()
        contentContainer.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
        contentContainer.BackgroundTransparency = 0.99
    end)
    
    -- 存储子标签页数据
    local subTabsData = {}
    local activeSubTab = nil
    
    -- 切换子标签页函数
    local function switchToSubTab(index)
        if not subTabsData[index] then return end
        
        local targetData = subTabsData[index]
        if activeSubTab == targetData then return end
        
        -- 隐藏当前活动标签页
        if activeSubTab then
            TweenService:Create(activeSubTab.button, UILibrary.TWEEN_INFO_BUTTON, {
                BackgroundTransparency = 0.6,
                BackgroundColor3 = Color3.fromRGB(60, 62, 70)
            }):Play()
            activeSubTab.button.TextColor3 = Color3.fromRGB(160, 160, 170)
            activeSubTab.content.Visible = false
        end
        
        -- 显示目标标签页
        activeSubTab = targetData
        targetData.content.Visible = true
        
        TweenService:Create(targetData.button, UILibrary.TWEEN_INFO_BUTTON, {
            BackgroundTransparency = 0.3,
            BackgroundColor3 = THEME.Primary or DEFAULT_THEME.Primary
        }):Play()
        targetData.button.TextColor3 = THEME.Text or DEFAULT_THEME.Text
        
        if onSwitch then
            task.spawn(function()
                onSwitch(index, targetData.name)
            end)
        end
    end
    
    -- 创建子标签页
    for i, item in ipairs(subTabItems) do
        local subTabName = type(item) == "string" and item or item.Name or "SubTab" .. i
        local subTabIcon = type(item) == "table" and item.Icon or nil
        
        -- 外层容器（边框在这里）
        local btnContainer = Instance.new("Frame")
        btnContainer.Name = "SubTabContainer_" .. subTabName
        btnContainer.Size = UDim2.new(0, 0, 0, UI_STYLES.SubTabButtonHeight)
        btnContainer.AutomaticSize = Enum.AutomaticSize.X
        btnContainer.BorderSizePixel = 0
        btnContainer.Parent = buttonContainer
        btnContainer.ZIndex = 7
        
        task.spawn(function()
            game:GetService("RunService").Heartbeat:Wait()
            btnContainer.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
            btnContainer.BackgroundTransparency = 0.99
        end)
        
        local containerCorner = Instance.new("UICorner")
        containerCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusPill)
        containerCorner.Parent = btnContainer
        
        local containerStroke = Instance.new("UIStroke")
        containerStroke.Color = Color3.fromRGB(255, 255, 255)
        containerStroke.Transparency = 0.6
        containerStroke.Thickness = 1
        containerStroke.Parent = btnContainer
        
        -- 内部按钮（有颜色）
        local button = Instance.new("TextButton")
        button.Name = "SubTabButton_" .. subTabName
        button.Size = UDim2.new(1, 0, 1, 0)
        button.BackgroundColor3 = i == defaultActive and (THEME.Primary or DEFAULT_THEME.Primary) or Color3.fromRGB(60, 62, 70)
        button.BackgroundTransparency = i == defaultActive and 0.3 or 0.6
        button.Text = subTabIcon and (subTabIcon .. " " .. subTabName) or subTabName
        button.TextColor3 = i == defaultActive and (THEME.Text or DEFAULT_THEME.Text) or Color3.fromRGB(160, 160, 170)
        button.TextSize = 11
        button.Font = THEME.Font
        button.Parent = btnContainer
        button.ZIndex = 8
        button.BorderSizePixel = 0
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, UI_STYLES.CornerRadiusPill)
        btnCorner.Parent = button
        
        local btnPadding = Instance.new("UIPadding")
        btnPadding.PaddingLeft = UDim.new(0, 12)
        btnPadding.PaddingRight = UDim.new(0, 12)
        btnPadding.Parent = button
        
        local content = Instance.new("Frame")
        content.Name = "SubTabContent_" .. subTabName
        content.Size = UDim2.new(1, 0, 0, 0)
        content.Position = UDim2.new(0, 0, 0, 0)
        content.AutomaticSize = Enum.AutomaticSize.Y
        content.BorderSizePixel = 0
        content.Visible = i == defaultActive
        content.ZIndex = 6
        content.Parent = contentContainer
        
        task.spawn(function()
            game:GetService("RunService").Heartbeat:Wait()
            content.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
            content.BackgroundTransparency = 0.999
        end)
        
        local contentLayout = Instance.new("UIListLayout")
        contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        contentLayout.Padding = UDim.new(0, UI_STYLES.Padding)
        contentLayout.Parent = content
        
        local contentPadding = Instance.new("UIPadding")
        contentPadding.PaddingLeft = UDim.new(0, UI_STYLES.Padding)
        contentPadding.PaddingRight = UDim.new(0, UI_STYLES.Padding)
        contentPadding.PaddingTop = UDim.new(0, UI_STYLES.Padding)
        contentPadding.PaddingBottom = UDim.new(0, UI_STYLES.Padding)
        contentPadding.Parent = content
        
        -- 简化CanvasSize更新，移除task.defer避免递归
        -- 子标签页内容使用AutomaticSize，不需要手动管理CanvasSize
        
        -- 存储数据
        table.insert(subTabsData, {
            index = i,
            name = subTabName,
            button = button,
            content = content
        })
        
        -- 点击事件
        button.MouseButton1Click:Connect(function()
            switchToSubTab(i)
        end)
        
        -- 悬停效果（使用新的颜色方案）
        button.MouseEnter:Connect(function()
            if activeSubTab ~= subTabsData[i] then
                TweenService:Create(button, UILibrary.TWEEN_INFO_BUTTON, {
                    BackgroundTransparency = 0.4,
                    BackgroundColor3 = Color3.fromRGB(70, 72, 80)
                }):Play()
            end
        end)
        
        button.MouseLeave:Connect(function()
            if activeSubTab ~= subTabsData[i] then
                TweenService:Create(button, UILibrary.TWEEN_INFO_BUTTON, {
                    BackgroundTransparency = 0.6,
                    BackgroundColor3 = Color3.fromRGB(60, 62, 70)
                }):Play()
            end
        end)
    end
    
    -- 默认激活指定索引（确保在有效范围内）
    if #subTabsData > 0 then
        local validIndex = math.clamp(defaultActive, 1, #subTabsData)
        task.delay(0.1, function()
            switchToSubTab(validIndex)
        end)
    end
    
    -- 返回控制接口
    return {
        Container = contentContainer,
        SwitchTo = switchToSubTab,
        GetActiveIndex = function() 
            return activeSubTab and activeSubTab.index or nil
        end,
        GetContent = function(index)
            return subTabsData[index] and subTabsData[index].content or nil
        end,
        GetButton = function(index)
            return subTabsData[index] and subTabsData[index].button or nil
        end,
        AddElement = function(index, element)
            if subTabsData[index] and element then
                element.Parent = subTabsData[index].content
                -- 添加元素后会触发ChildAdded，CanvasSize会自动更新
                -- 不需要手动更新，避免重复计算
            end
        end
    }
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