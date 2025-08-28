-- Valkyrie UI Library
-- 一个现代化的 Roblox UI 库，支持主题切换、移动端适配、胶囊组件等功能

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Valkyrie = {}
Valkyrie.__index = Valkyrie

-- 主题系统
local Themes = {
    Dark = {
        Primary = Color3.fromRGB(25, 25, 35),
        Secondary = Color3.fromRGB(35, 35, 45),
        Accent = Color3.fromRGB(88, 101, 242),
        AccentHover = Color3.fromRGB(98, 111, 252),
        Text = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(200, 200, 200),
        Border = Color3.fromRGB(55, 55, 65),
        Success = Color3.fromRGB(67, 181, 129),
        Warning = Color3.fromRGB(250, 166, 26),
        Error = Color3.fromRGB(240, 71, 71),
        Background = Color3.fromRGB(15, 15, 20)
    },
    Light = {
        Primary = Color3.fromRGB(250, 250, 255),
        Secondary = Color3.fromRGB(240, 240, 245),
        Accent = Color3.fromRGB(88, 101, 242),
        AccentHover = Color3.fromRGB(98, 111, 252),
        Text = Color3.fromRGB(25, 25, 35),
        TextSecondary = Color3.fromRGB(100, 100, 120),
        Border = Color3.fromRGB(200, 200, 210),
        Success = Color3.fromRGB(67, 181, 129),
        Warning = Color3.fromRGB(250, 166, 26),
        Error = Color3.fromRGB(240, 71, 71),
        Background = Color3.fromRGB(255, 255, 255)
    }
}

-- 图标系统
local Icons = {
    Home = "rbxassetid://7072707318",
    Settings = "rbxassetid://7072719338",
    User = "rbxassetid://7072719185",
    Bell = "rbxassetid://7072706479",
    Close = "rbxassetid://7072725342",
    Menu = "rbxassetid://7072719185",
    Add = "rbxassetid://7072717281",
    Delete = "rbxassetid://7072725463",
    Edit = "rbxassetid://7072717972",
    Check = "rbxassetid://7072706796",
    X = "rbxassetid://7072725342",
    Arrow = "rbxassetid://7072719594",
    Search = "rbxassetid://7072719594",
    Star = "rbxassetid://7072719594"
}

-- 创建 UI 实例
function Valkyrie.new(config)
    local self = setmetatable({}, Valkyrie)
    
    -- 配置
    self.config = config or {}
    self.config.Title = self.config.Title or "Valkyrie UI"
    self.config.Theme = self.config.Theme or "Dark"
    self.config.Size = self.config.Size or UDim2.new(0, 600, 0, 400)
    self.config.Position = self.config.Position or UDim2.new(0.5, -300, 0.5, -200)
    
    -- 状态
    self.isVisible = false
    self.currentTheme = Themes[self.config.Theme]
    self.tabs = {}
    self.capsules = {}
    self.notifications = {}
    
    -- 创建主界面
    self:CreateMainUI()
    self:CreateFloatingButton()
    
    return self
end

-- 创建主界面
function Valkyrie:CreateMainUI()
    -- 主容器
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "ValkyrieUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.ScreenGui.Parent = CoreGui
    
    -- 主框架
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "MainFrame"
    self.MainFrame.Size = self.config.Size
    self.MainFrame.Position = self.config.Position
    self.MainFrame.BackgroundColor3 = self.currentTheme.Primary
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Visible = false
    self.MainFrame.Parent = self.ScreenGui
    
    -- 圆角
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.MainFrame
    
    -- 阴影效果
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.8
    shadow.ZIndex = -1
    shadow.Parent = self.MainFrame
    
    -- 标题栏
    self:CreateTitleBar()
    
    -- 内容区域
    self:CreateContentArea()
    
    -- 通知系统
    self:CreateNotificationSystem()
    
    -- 使窗口可拖拽
    self:MakeDraggable()
    
    -- 移动端适配 - 在所有组件创建完成后调用
    spawn(function()
        wait(0.1)
        self:AdaptForMobile()
    end)
end

-- 创建标题栏
function Valkyrie:CreateTitleBar()
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 45)
    self.TitleBar.Position = UDim2.new(0, 0, 0, 0)
    self.TitleBar.BackgroundColor3 = self.currentTheme.Secondary
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Parent = self.MainFrame
    
    -- 标题栏圆角
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = self.TitleBar
    
    -- 标题文本
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -90, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = self.config.Title
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = self.TitleBar
    
    -- 关闭按钮
    local closeButton = Instance.new("ImageButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -37, 0, 7.5)
    closeButton.BackgroundColor3 = self.currentTheme.Error
    closeButton.BorderSizePixel = 0
    closeButton.Image = Icons.Close
    closeButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Parent = self.TitleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    -- 关闭按钮事件
    closeButton.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    
    -- 悬停效果
    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
    end)
    
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.Error}):Play()
    end)
end

-- 创建内容区域
function Valkyrie:CreateContentArea()
    -- 标签页容器
    self.TabContainer = Instance.new("Frame")
    self.TabContainer.Name = "TabContainer"
    self.TabContainer.Size = UDim2.new(1, 0, 0, 40)
    self.TabContainer.Position = UDim2.new(0, 0, 0, 45)
    self.TabContainer.BackgroundColor3 = self.currentTheme.Secondary
    self.TabContainer.BorderSizePixel = 0
    self.TabContainer.Parent = self.MainFrame
    
    -- 标签页布局
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 2)
    tabLayout.Parent = self.TabContainer
    
    -- 内容框架
    self.ContentFrame = Instance.new("Frame")
    self.ContentFrame.Name = "ContentFrame"
    self.ContentFrame.Size = UDim2.new(1, 0, 1, -85)
    self.ContentFrame.Position = UDim2.new(0, 0, 0, 85)
    self.ContentFrame.BackgroundColor3 = self.currentTheme.Primary
    self.ContentFrame.BorderSizePixel = 0
    self.ContentFrame.Parent = self.MainFrame
    
    -- 内容圆角
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = self.ContentFrame
    
    -- 创建默认标签页
    self:AddTab("主页", Icons.Home)
    self:AddTab("胶囊管理", Icons.Settings)
    self:AddTab("主题设置", Icons.Edit)
end

-- 创建悬浮按钮
function Valkyrie:CreateFloatingButton()
    self.FloatingButton = Instance.new("ImageButton")
    self.FloatingButton.Name = "FloatingButton"
    self.FloatingButton.Size = UDim2.new(0, 60, 0, 60)
    self.FloatingButton.Position = UDim2.new(1, -80, 1, -80)
    self.FloatingButton.BackgroundColor3 = self.currentTheme.Accent
    self.FloatingButton.BorderSizePixel = 0
    self.FloatingButton.Image = Icons.Menu
    self.FloatingButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    self.FloatingButton.Parent = self.ScreenGui
    
    -- 悬浮按钮圆角
    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 30)
    floatCorner.Parent = self.FloatingButton
    
    -- 悬浮按钮阴影
    local floatShadow = Instance.new("Frame")
    floatShadow.Name = "Shadow"
    floatShadow.Size = UDim2.new(1, 10, 1, 10)
    floatShadow.Position = UDim2.new(0, -5, 0, -5)
    floatShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    floatShadow.BackgroundTransparency = 0.9
    floatShadow.ZIndex = -1
    floatShadow.Parent = self.FloatingButton
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 35)
    shadowCorner.Parent = floatShadow
    
    -- 悬浮按钮事件
    self.FloatingButton.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    -- 悬停效果
    self.FloatingButton.MouseEnter:Connect(function()
        TweenService:Create(self.FloatingButton, TweenInfo.new(0.2), {
            BackgroundColor3 = self.currentTheme.AccentHover,
            Size = UDim2.new(0, 65, 0, 65)
        }):Play()
    end)
    
    self.FloatingButton.MouseLeave:Connect(function()
        TweenService:Create(self.FloatingButton, TweenInfo.new(0.2), {
            BackgroundColor3 = self.currentTheme.Accent,
            Size = UDim2.new(0, 60, 0, 60)
        }):Play()
    end)
end

-- 创建通知系统
function Valkyrie:CreateNotificationSystem()
    self.NotificationContainer = Instance.new("Frame")
    self.NotificationContainer.Name = "NotificationContainer"
    self.NotificationContainer.Size = UDim2.new(0, 300, 1, 0)
    self.NotificationContainer.Position = UDim2.new(1, -320, 0, 20)
    self.NotificationContainer.BackgroundTransparency = 1
    self.NotificationContainer.Parent = self.ScreenGui
    
    local notifLayout = Instance.new("UIListLayout")
    notifLayout.FillDirection = Enum.FillDirection.Vertical
    notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifLayout.Padding = UDim.new(0, 10)
    notifLayout.Parent = self.NotificationContainer
end

-- 添加标签页
function Valkyrie:AddTab(name, icon)
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name .. "Tab"
    tabButton.Size = UDim2.new(0, 120, 1, 0)
    tabButton.BackgroundColor3 = self.currentTheme.Primary
    tabButton.BorderSizePixel = 0
    tabButton.Text = ""
    tabButton.Parent = self.TabContainer
    
    -- 标签页图标
    local iconLabel = Instance.new("ImageLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(0, 20, 0, 20)
    iconLabel.Position = UDim2.new(0, 10, 0.5, -10)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Image = icon
    iconLabel.ImageColor3 = self.currentTheme.TextSecondary
    iconLabel.Parent = tabButton
    
    -- 标签页文本
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Text"
    textLabel.Size = UDim2.new(1, -40, 1, 0)
    textLabel.Position = UDim2.new(0, 35, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = name
    textLabel.TextColor3 = self.currentTheme.TextSecondary
    textLabel.TextSize = 14
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Font = Enum.Font.Gotham
    textLabel.Parent = tabButton
    
    -- 标签页内容
    local tabContent = Instance.new("Frame")
    tabContent.Name = name .. "Content"
    tabContent.Size = UDim2.new(1, 0, 1, 0)
    tabContent.Position = UDim2.new(0, 0, 0, 0)
    tabContent.BackgroundTransparency = 1
    tabContent.Visible = #self.tabs == 0 -- 第一个标签页默认显示
    tabContent.Parent = self.ContentFrame
    
    -- 标签页切换事件
    tabButton.MouseButton1Click:Connect(function()
        self:SwitchTab(name)
    end)
    
    -- 悬停效果
    tabButton.MouseEnter:Connect(function()
        if not self.tabs[name] or not self.tabs[name].active then
            TweenService:Create(tabButton, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.Secondary}):Play()
            TweenService:Create(iconLabel, TweenInfo.new(0.2), {ImageColor3 = self.currentTheme.Text}):Play()
            TweenService:Create(textLabel, TweenInfo.new(0.2), {TextColor3 = self.currentTheme.Text}):Play()
        end
    end)
    
    tabButton.MouseLeave:Connect(function()
        if not self.tabs[name] or not self.tabs[name].active then
            TweenService:Create(tabButton, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.Primary}):Play()
            TweenService:Create(iconLabel, TweenInfo.new(0.2), {ImageColor3 = self.currentTheme.TextSecondary}):Play()
            TweenService:Create(textLabel, TweenInfo.new(0.2), {TextColor3 = self.currentTheme.TextSecondary}):Play()
        end
    end)
    
    -- 存储标签页信息
    self.tabs[name] = {
        button = tabButton,
        content = tabContent,
        icon = iconLabel,
        text = textLabel,
        active = #self.tabs == 0
    }
    
    -- 如果是第一个标签页，设置为活跃状态
    if #self.tabs == 1 then
        self:SwitchTab(name)
    end
    
    -- 创建预设内容
    self:CreateTabContent(name, tabContent)
    
    return tabContent
end

-- 创建标签页内容
function Valkyrie:CreateTabContent(name, container)
    if name == "主页" then
        self:CreateHomeContent(container)
    elseif name == "胶囊管理" then
        self:CreateCapsuleContent(container)
    elseif name == "主题设置" then
        self:CreateThemeContent(container)
    end
end

-- 创建主页内容
function Valkyrie:CreateHomeContent(container)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -20)
    scrollFrame.Position = UDim2.new(0, 10, 0, 10)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = self.currentTheme.Accent
    scrollFrame.Parent = container
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 15)
    layout.Parent = scrollFrame
    
    -- 欢迎标题
    local welcomeLabel = Instance.new("TextLabel")
    welcomeLabel.Name = "WelcomeLabel"
    welcomeLabel.Size = UDim2.new(1, 0, 0, 50)
    welcomeLabel.BackgroundTransparency = 1
    welcomeLabel.Text = "欢迎使用 Valkyrie UI"
    welcomeLabel.TextColor3 = self.currentTheme.Text
    welcomeLabel.TextSize = 24
    welcomeLabel.TextXAlignment = Enum.TextXAlignment.Left
    welcomeLabel.Font = Enum.Font.GothamBold
    welcomeLabel.Parent = scrollFrame
    
    -- 功能介绍
    local features = {
        {title = "🎨 主题系统", desc = "支持明暗主题切换，实时预览效果"},
        {title = "📱 移动适配", desc = "完美适配移动端设备，响应式设计"},
        {title = "💊 胶囊组件", desc = "可创建独立的浮动胶囊，自由拖拽"},
        {title = "🔔 通知系统", desc = "优雅的通知提醒，多种样式可选"},
        {title = "🎯 模块化", desc = "高度模块化设计，易于扩展和定制"}
    }
    
    for i, feature in ipairs(features) do
        local featureFrame = Instance.new("Frame")
        featureFrame.Name = "Feature" .. i
        featureFrame.Size = UDim2.new(1, 0, 0, 80)
        featureFrame.BackgroundColor3 = self.currentTheme.Secondary
        featureFrame.BorderSizePixel = 0
        featureFrame.LayoutOrder = i
        featureFrame.Parent = scrollFrame
        
        local featureCorner = Instance.new("UICorner")
        featureCorner.CornerRadius = UDim.new(0, 8)
        featureCorner.Parent = featureFrame
        
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Title"
        titleLabel.Size = UDim2.new(1, -20, 0, 25)
        titleLabel.Position = UDim2.new(0, 15, 0, 10)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = feature.title
        titleLabel.TextColor3 = self.currentTheme.Text
        titleLabel.TextSize = 16
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.Parent = featureFrame
        
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "Description"
        descLabel.Size = UDim2.new(1, -20, 0, 35)
        descLabel.Position = UDim2.new(0, 15, 0, 35)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = feature.desc
        descLabel.TextColor3 = self.currentTheme.TextSecondary
        descLabel.TextSize = 14
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.Parent = featureFrame
    end
    
    -- 更新滚动框大小
    layout.Changed:Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
end

-- 创建胶囊管理内容
function Valkyrie:CreateCapsuleContent(container)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = self.currentTheme.Accent
    scrollFrame.Parent = container
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 10)
    layout.Parent = scrollFrame
    
    -- 标题
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "胶囊管理"
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = container
    
    -- 添加胶囊按钮
    local addButton = Instance.new("TextButton")
    addButton.Name = "AddCapsule"
    addButton.Size = UDim2.new(0, 120, 0, 35)
    addButton.Position = UDim2.new(1, -130, 0, 10)
    addButton.BackgroundColor3 = self.currentTheme.Accent
    addButton.BorderSizePixel = 0
    addButton.Text = "添加胶囊"
    addButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    addButton.TextSize = 14
    addButton.Font = Enum.Font.GothamBold
    addButton.Parent = container
    
    local addCorner = Instance.new("UICorner")
    addCorner.CornerRadius = UDim.new(0, 6)
    addCorner.Parent = addButton
    
    addButton.MouseButton1Click:Connect(function()
        self:CreateCapsule("新胶囊", "TextButton")
    end)
    
    -- 胶囊列表标题
    self.CapsuleListFrame = scrollFrame
    
    -- 更新滚动框大小
    layout.Changed:Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
end

-- 创建主题设置内容
function Valkyrie:CreateThemeContent(container)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -20)
    scrollFrame.Position = UDim2.new(0, 10, 0, 10)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = self.currentTheme.Accent
    scrollFrame.Parent = container
    
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 15)
    layout.Parent = scrollFrame
    
    -- 主题选择
    local themeFrame = Instance.new("Frame")
    themeFrame.Name = "ThemeFrame"
    themeFrame.Size = UDim2.new(1, 0, 0, 100)
    themeFrame.BackgroundColor3 = self.currentTheme.Secondary
    themeFrame.BorderSizePixel = 0
    themeFrame.Parent = scrollFrame
    
    local themeCorner = Instance.new("UICorner")
    themeCorner.CornerRadius = UDim.new(0, 8)
    themeCorner.Parent = themeFrame
    
    local themeLabel = Instance.new("TextLabel")
    themeLabel.Name = "Label"
    themeLabel.Size = UDim2.new(1, -20, 0, 30)
    themeLabel.Position = UDim2.new(0, 15, 0, 10)
    themeLabel.BackgroundTransparency = 1
    themeLabel.Text = "主题模式"
    themeLabel.TextColor3 = self.currentTheme.Text
    themeLabel.TextSize = 16
    themeLabel.TextXAlignment = Enum.TextXAlignment.Left
    themeLabel.Font = Enum.Font.GothamBold
    themeLabel.Parent = themeFrame
    
    -- 主题切换按钮
    local themeButtons = {}
    for i, themeName in ipairs({"Dark", "Light"}) do
        local button = Instance.new("TextButton")
        button.Name = themeName .. "Button"
        button.Size = UDim2.new(0, 80, 0, 35)
        button.Position = UDim2.new(0, 15 + (i-1) * 90, 0, 45)
        button.BackgroundColor3 = self.config.Theme == themeName and self.currentTheme.Accent or self.currentTheme.Primary
        button.BorderSizePixel = 0
        button.Text = themeName == "Dark" and "暗色" or "亮色"
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.Font = Enum.Font.Gotham
        button.Parent = themeFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            self:ChangeTheme(themeName)
            for _, btn in pairs(themeButtons) do
                btn.BackgroundColor3 = self.currentTheme.Primary
            end
            button.BackgroundColor3 = self.currentTheme.Accent
        end)
        
        themeButtons[themeName] = button
    end
    
    -- 颜色自定义
    local colorFrame = Instance.new("Frame")
    colorFrame.Name = "ColorFrame"
    colorFrame.Size = UDim2.new(1, 0, 0, 150)
    colorFrame.BackgroundColor3 = self.currentTheme.Secondary
    colorFrame.BorderSizePixel = 0
    colorFrame.Parent = scrollFrame
    
    local colorCorner = Instance.new("UICorner")
    colorCorner.CornerRadius = UDim.new(0, 8)
    colorCorner.Parent = colorFrame
    
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Name = "Label"
    colorLabel.Size = UDim2.new(1, -20, 0, 30)
    colorLabel.Position = UDim2.new(0, 15, 0, 10)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "自定义颜色"
    colorLabel.TextColor3 = self.currentTheme.Text
    colorLabel.TextSize = 16
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.Font = Enum.Font.GothamBold
    colorLabel.Parent = colorFrame
    
    -- 主色调选择器
    local accentColorPicker = self:CreateColorPicker(colorFrame, "主色调", UDim2.new(0, 15, 0, 50), self.currentTheme.Accent)
    accentColorPicker.ColorChanged.Event:Connect(function(color)
        self.currentTheme.Accent = color
        self.currentTheme.AccentHover = Color3.fromRGB(
            math.min(255, color.R * 255 + 20),
            math.min(255, color.G * 255 + 20),
            math.min(255, color.B * 255 + 20)
        )
        self:UpdateTheme()
    end)
    
    -- 更新滚动框大小
    layout.Changed:Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)
end

-- 创建颜色选择器
function Valkyrie:CreateColorPicker(parent, name, position, defaultColor)
    local picker = {}
    
    local frame = Instance.new("Frame")
    frame.Name = name .. "Picker"
    frame.Size = UDim2.new(1, -30, 0, 40)
    frame.Position = position
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0, 80, 1, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = self.currentTheme.Text
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Parent = frame
    
    local colorPreview = Instance.new("Frame")
    colorPreview.Size = UDim2.new(0, 30, 0, 30)
    colorPreview.Position = UDim2.new(0, 90, 0, 5)
    colorPreview.BackgroundColor3 = defaultColor
    colorPreview.BorderSizePixel = 2
    colorPreview.BorderColor3 = self.currentTheme.Border
    colorPreview.Parent = frame
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 4)
    previewCorner.Parent = colorPreview
    
    -- RGB 滑块
    local sliders = {}
    local colors = {"R", "G", "B"}
    local values = {defaultColor.R * 255, defaultColor.G * 255, defaultColor.B * 255}
    
    for i, colorName in ipairs(colors) do
        local slider = self:CreateSlider(frame, colorName, UDim2.new(0, 130 + (i-1) * 80, 0, 5), values[i], 0, 255)
        sliders[colorName] = slider
        
        slider.ValueChanged.Event:Connect(function(value)
            values[i] = value
            local newColor = Color3.fromRGB(values[1], values[2], values[3])
            colorPreview.BackgroundColor3 = newColor
            if picker.ColorChanged then
                picker.ColorChanged:Fire(newColor)
            end
        end)
    end
    
    -- 创建事件
    picker.ColorChanged = Instance.new("BindableEvent")
    
    return picker
end

-- 创建滑块
function Valkyrie:CreateSlider(parent, name, position, defaultValue, minValue, maxValue)
    local slider = {}
    
    local frame = Instance.new("Frame")
    frame.Name = name .. "Slider"
    frame.Size = UDim2.new(0, 70, 0, 30)
    frame.Position = position
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 15, 0, 15)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = self.currentTheme.Text
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.Font = Enum.Font.Gotham
    label.Parent = frame
    
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 4)
    track.Position = UDim2.new(0, 10, 0, 20)
    track.BackgroundColor3 = self.currentTheme.Border
    track.BorderSizePixel = 0
    track.Parent = frame
    
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 2)
    trackCorner.Parent = track
    
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = UDim2.new((defaultValue - minValue) / (maxValue - minValue), -6, 0, -4)
    thumb.BackgroundColor3 = self.currentTheme.Accent
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 6)
    thumbCorner.Parent = thumb
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0, 30, 0, 15)
    valueLabel.Position = UDim2.new(1, -25, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(math.floor(defaultValue))
    valueLabel.TextColor3 = self.currentTheme.TextSecondary
    valueLabel.TextSize = 10
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.Parent = frame
    
    -- 滑块事件
    local dragging = false
    local currentValue = defaultValue
    
    local function updateSlider(input)
        local trackSize = track.AbsoluteSize.X
        local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / trackSize, 0, 1)
        currentValue = minValue + (maxValue - minValue) * relativeX
        
        thumb.Position = UDim2.new(relativeX, -6, 0, -4)
        valueLabel.Text = tostring(math.floor(currentValue))
        
        if slider.ValueChanged then
            slider.ValueChanged:Fire(currentValue)
        end
    end
    
    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    
    thumb.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            updateSlider(input)
        end
    end)
    
    -- 创建事件
    slider.ValueChanged = Instance.new("BindableEvent")
    
    return slider
end

-- 切换标签页
function Valkyrie:SwitchTab(tabName)
    for name, tab in pairs(self.tabs) do
        if tab and tab.content and tab.button and tab.text and tab.icon then
            local isActive = name == tabName
            tab.content.Visible = isActive
            tab.active = isActive
            
            local targetColor = isActive and self.currentTheme.Accent or self.currentTheme.Primary
            local targetTextColor = isActive and Color3.fromRGB(255, 255, 255) or self.currentTheme.TextSecondary
            local targetIconColor = isActive and Color3.fromRGB(255, 255, 255) or self.currentTheme.TextSecondary
            
            TweenService:Create(tab.button, TweenInfo.new(0.3), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(tab.text, TweenInfo.new(0.3), {TextColor3 = targetTextColor}):Play()
            TweenService:Create(tab.icon, TweenInfo.new(0.3), {ImageColor3 = targetIconColor}):Play()
        end
    end
end

-- 创建胶囊
function Valkyrie:CreateCapsule(name, componentType, config)
    local capsule = {}
    config = config or {}
    
    -- 胶囊容器
    local capsuleFrame = Instance.new("Frame")
    capsuleFrame.Name = name .. "Capsule"
    capsuleFrame.Size = UDim2.new(0, config.Size and config.Size.X or 120, 0, config.Size and config.Size.Y or 40)
    capsuleFrame.Position = config.Position or UDim2.new(0.5, -60, 0.5, -20)
    capsuleFrame.BackgroundColor3 = self.currentTheme.Secondary
    capsuleFrame.BorderSizePixel = 0
    capsuleFrame.Parent = self.ScreenGui
    
    local capsuleCorner = Instance.new("UICorner")
    capsuleCorner.CornerRadius = UDim.new(0, 20)
    capsuleCorner.Parent = capsuleFrame
    
    -- 创建组件内容
    local component
    if componentType == "TextButton" then
        component = Instance.new("TextButton")
        component.Size = UDim2.new(1, -10, 1, -10)
        component.Position = UDim2.new(0, 5, 0, 5)
        component.BackgroundColor3 = self.currentTheme.Accent
        component.BorderSizePixel = 0
        component.Text = config.Text or name
        component.TextColor3 = Color3.fromRGB(255, 255, 255)
        component.TextSize = 14
        component.Font = Enum.Font.Gotham
        component.Parent = capsuleFrame
        
        local componentCorner = Instance.new("UICorner")
        componentCorner.CornerRadius = UDim.new(0, 15)
        componentCorner.Parent = component
        
    elseif componentType == "Toggle" then
        component = self:CreateToggle(capsuleFrame, config.Text or name, config.Default or false)
        
    elseif componentType == "Slider" then
        component = self:CreateSlider(capsuleFrame, config.Text or name, UDim2.new(0, 5, 0, 5), 
                                     config.Default or 50, config.Min or 0, config.Max or 100)
    end
    
    -- 使胶囊可拖拽
    self:MakeCapsuleDraggable(capsuleFrame)
    
    -- 添加到胶囊列表
    capsule.frame = capsuleFrame
    capsule.component = component
    capsule.name = name
    capsule.type = componentType
    self.capsules[name] = capsule
    
    -- 在胶囊管理页面添加条目
    self:AddCapsuleToList(capsule)
    
    return capsule
end

-- 创建开关组件
function Valkyrie:CreateToggle(parent, text, default)
    local toggle = {}
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 1, -10)
    frame.Position = UDim2.new(0, 5, 0, 5)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self.currentTheme.Text
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.Parent = frame
    
    local switchFrame = Instance.new("Frame")
    switchFrame.Size = UDim2.new(0, 30, 0, 16)
    switchFrame.Position = UDim2.new(1, -35, 0.5, -8)
    switchFrame.BackgroundColor3 = default and self.currentTheme.Accent or self.currentTheme.Border
    switchFrame.BorderSizePixel = 0
    switchFrame.Parent = frame
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 8)
    switchCorner.Parent = switchFrame
    
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = default and UDim2.new(1, -14, 0, 2) or UDim2.new(0, 2, 0, 2)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.Parent = switchFrame
    
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 6)
    thumbCorner.Parent = thumb
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = switchFrame
    
    toggle.enabled = default
    toggle.ToggleChanged = Instance.new("BindableEvent")
    
    button.MouseButton1Click:Connect(function()
        toggle.enabled = not toggle.enabled
        
        local targetPos = toggle.enabled and UDim2.new(1, -14, 0, 2) or UDim2.new(0, 2, 0, 2)
        local targetColor = toggle.enabled and self.currentTheme.Accent or self.currentTheme.Border
        
        TweenService:Create(thumb, TweenInfo.new(0.2), {Position = targetPos}):Play()
        TweenService:Create(switchFrame, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        
        toggle.ToggleChanged:Fire(toggle.enabled)
    end)
    
    return toggle
end

-- 使胶囊可拖拽
function Valkyrie:MakeCapsuleDraggable(frame)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- 添加胶囊到管理列表
function Valkyrie:AddCapsuleToList(capsule)
    local listItem = Instance.new("Frame")
    listItem.Name = capsule.name .. "ListItem"
    listItem.Size = UDim2.new(1, 0, 0, 50)
    listItem.BackgroundColor3 = self.currentTheme.Secondary
    listItem.BorderSizePixel = 0
    listItem.Parent = self.CapsuleListFrame
    
    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = UDim.new(0, 8)
    itemCorner.Parent = listItem
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.4, -10, 1, 0)
    nameLabel.Position = UDim2.new(0, 10, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = capsule.name
    nameLabel.TextColor3 = self.currentTheme.Text
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Parent = listItem
    
    local typeLabel = Instance.new("TextLabel")
    typeLabel.Size = UDim2.new(0.3, -10, 1, 0)
    typeLabel.Position = UDim2.new(0.4, 0, 0, 0)
    typeLabel.BackgroundTransparency = 1
    typeLabel.Text = capsule.type
    typeLabel.TextColor3 = self.currentTheme.TextSecondary
    typeLabel.TextSize = 12
    typeLabel.TextXAlignment = Enum.TextXAlignment.Left
    typeLabel.Font = Enum.Font.Gotham
    typeLabel.Parent = listItem
    
    -- 删除按钮
    local deleteButton = Instance.new("ImageButton")
    deleteButton.Size = UDim2.new(0, 30, 0, 30)
    deleteButton.Position = UDim2.new(1, -40, 0.5, -15)
    deleteButton.BackgroundColor3 = self.currentTheme.Error
    deleteButton.BorderSizePixel = 0
    deleteButton.Image = Icons.Delete
    deleteButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    deleteButton.Parent = listItem
    
    local deleteCorner = Instance.new("UICorner")
    deleteCorner.CornerRadius = UDim.new(0, 4)
    deleteCorner.Parent = deleteButton
    
    deleteButton.MouseButton1Click:Connect(function()
        capsule.frame:Destroy()
        listItem:Destroy()
        self.capsules[capsule.name] = nil
    end)
end

-- 使主窗口可拖拽
function Valkyrie:MakeDraggable()
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    self.TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.MainFrame.Position
        end
    end)
    
    self.TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                                               startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- 移动端适配
function Valkyrie:AdaptForMobile()
    if UserInputService.TouchEnabled then
        -- 调整主窗口大小
        self.MainFrame.Size = UDim2.new(0.9, 0, 0.8, 0)
        self.MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
        
        -- 调整悬浮按钮大小
        if self.FloatingButton then
            self.FloatingButton.Size = UDim2.new(0, 70, 0, 70)
            self.FloatingButton.Position = UDim2.new(1, -90, 1, -90)
        end
        
        -- 调整字体大小 - 稍后在标签页创建后调用
        spawn(function()
            wait(0.1) -- 等待标签页创建完成
            for _, tab in pairs(self.tabs) do
                if tab and tab.text then
                    tab.text.TextSize = 16
                end
            end
        end)
    end
end

-- 显示/隐藏主界面
function Valkyrie:Show()
    if not self.isVisible then
        self.isVisible = true
        self.MainFrame.Visible = true
        
        -- 淡入动画
        self.MainFrame.BackgroundTransparency = 1
        TweenService:Create(self.MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
                          {BackgroundTransparency = 0}):Play()
        
        -- 缩放动画
        self.MainFrame.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(self.MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
                          {Size = self.config.Size}):Play()
    end
end

function Valkyrie:Hide()
    if self.isVisible then
        self.isVisible = false
        
        -- 淡出动画
        local fadeOut = TweenService:Create(self.MainFrame, TweenInfo.new(0.2), {BackgroundTransparency = 1})
        local scaleOut = TweenService:Create(self.MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), 
                                           {Size = UDim2.new(0, 0, 0, 0)})
        
        fadeOut:Play()
        scaleOut:Play()
        
        scaleOut.Completed:Connect(function()
            self.MainFrame.Visible = false
        end)
    end
end

function Valkyrie:Toggle()
    if self.isVisible then
        self:Hide()
    else
        self:Show()
    end
end

-- 更改主题
function Valkyrie:ChangeTheme(themeName)
    if Themes[themeName] then
        self.currentTheme = Themes[themeName]
        self.config.Theme = themeName
        self:UpdateTheme()
    end
end

-- 更新主题
function Valkyrie:UpdateTheme()
    -- 更新主界面
    self.MainFrame.BackgroundColor3 = self.currentTheme.Primary
    self.TitleBar.BackgroundColor3 = self.currentTheme.Secondary
    self.ContentFrame.BackgroundColor3 = self.currentTheme.Primary
    self.TabContainer.BackgroundColor3 = self.currentTheme.Secondary
    
    -- 更新悬浮按钮
    self.FloatingButton.BackgroundColor3 = self.currentTheme.Accent
    
    -- 更新所有标签页
    for _, tab in pairs(self.tabs) do
        if not tab.active then
            tab.button.BackgroundColor3 = self.currentTheme.Primary
            tab.text.TextColor3 = self.currentTheme.TextSecondary
            tab.icon.ImageColor3 = self.currentTheme.TextSecondary
        else
            tab.button.BackgroundColor3 = self.currentTheme.Accent
            tab.text.TextColor3 = Color3.fromRGB(255, 255, 255)
            tab.icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
    
    -- 更新胶囊
    for _, capsule in pairs(self.capsules) do
        capsule.frame.BackgroundColor3 = self.currentTheme.Secondary
    end
end

-- 通知系统
function Valkyrie:Notify(config)
    config = config or {}
    local title = config.Title or "通知"
    local message = config.Message or ""
    local type = config.Type or "Info" -- Info, Success, Warning, Error
    local duration = config.Duration or 5
    
    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.Size = UDim2.new(1, 0, 0, 80)
    notif.BackgroundColor3 = self.currentTheme.Secondary
    notif.BorderSizePixel = 0
    notif.Parent = self.NotificationContainer
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 8)
    notifCorner.Parent = notif
    
    -- 类型指示器
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 4, 1, 0)
    indicator.Position = UDim2.new(0, 0, 0, 0)
    indicator.BorderSizePixel = 0
    indicator.Parent = notif
    
    local indicatorColor = self.currentTheme.Accent
    if type == "Success" then indicatorColor = self.currentTheme.Success
    elseif type == "Warning" then indicatorColor = self.currentTheme.Warning
    elseif type == "Error" then indicatorColor = self.currentTheme.Error
    end
    indicator.BackgroundColor3 = indicatorColor
    
    -- 标题
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -40, 0, 25)
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = notif
    
    -- 消息
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -40, 0, 35)
    messageLabel.Position = UDim2.new(0, 15, 0, 35)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = self.currentTheme.TextSecondary
    messageLabel.TextSize = 12
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextWrapped = true
    messageLabel.Parent = notif
    
    -- 关闭按钮
    local closeBtn = Instance.new("ImageButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -30, 0, 10)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Image = Icons.Close
    closeBtn.ImageColor3 = self.currentTheme.TextSecondary
    closeBtn.Parent = notif
    
    closeBtn.MouseButton1Click:Connect(function()
        notif:Destroy()
    end)
    
    -- 滑入动画
    notif.Position = UDim2.new(1, 0, 0, 0)
    TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
                       {Position = UDim2.new(0, 0, 0, 0)}):Play()
    
    -- 自动消失
    if duration > 0 then
        spawn(function()
            wait(duration)
            local slideOut = TweenService:Create(notif, TweenInfo.new(0.3), {Position = UDim2.new(1, 0, 0, 0)})
            slideOut:Play()
            slideOut.Completed:Connect(function()
                notif:Destroy()
            end)
        end)
    end
end

-- 示例用法函数
function Valkyrie:CreateExampleComponents()
    -- 创建一些示例胶囊
    spawn(function()
        wait(1)
        self:CreateCapsule("速度开关", "Toggle", {Text = "速度", Default = false})
        
        wait(0.5)
        self:CreateCapsule("跳跃高度", "Slider", {
            Text = "跳跃", 
            Default = 50, 
            Min = 0, 
            Max = 100,
            Position = UDim2.new(0.3, 0, 0.3, 0),
            Size = {X = 150, Y = 40}
        })
        
        wait(0.5)
        self:CreateCapsule("传送", "TextButton", {
            Text = "传送到大厅",
            Position = UDim2.new(0.7, 0, 0.7, 0),
            Size = {X = 120, Y = 35}
        })
        
        -- 显示欢迎通知
        wait(0.5)
        self:Notify({
            Title = "欢迎使用 Valkyrie!",
            Message = "UI 库已成功加载，您可以开始使用所有功能。",
            Type = "Success",
            Duration = 5
        })
    end)
end

-- 销毁 UI
function Valkyrie:Destroy()
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
    
    -- 清理胶囊
    for _, capsule in pairs(self.capsules) do
        if capsule.frame then
            capsule.frame:Destroy()
        end
    end
    
    -- 清理表
    self.tabs = {}
    self.capsules = {}
    self.notifications = {}
end

-- 获取组件值
function Valkyrie:GetCapsuleValue(name)
    local capsule = self.capsules[name]
    if capsule then
        if capsule.type == "Toggle" then
            return capsule.component.enabled
        elseif capsule.type == "Slider" then
            return capsule.component.currentValue or 0
        end
    end
    return nil
end

-- 设置组件值
function Valkyrie:SetCapsuleValue(name, value)
    local capsule = self.capsules[name]
    if capsule then
        if capsule.type == "Toggle" then
            -- 触发点击事件来改变状态
            capsule.component.enabled = value
            -- 这里需要手动更新UI外观
        elseif capsule.type == "Slider" then
            -- 更新滑块值
            capsule.component.currentValue = value
        end
    end
end

-- 添加自定义标签页
function Valkyrie:AddCustomTab(name, icon, contentFunction)
    local tabContent = self:AddTab(name, icon)
    if contentFunction then
        contentFunction(tabContent)
    end
    return tabContent
end

-- 添加自定义组件到标签页
function Valkyrie:AddButton(parent, config)
    config = config or {}
    
    local button = Instance.new("TextButton")
    button.Name = config.Name or "CustomButton"
    button.Size = config.Size or UDim2.new(0, 120, 0, 35)
    button.Position = config.Position or UDim2.new(0, 10, 0, 10)
    button.BackgroundColor3 = config.Color or self.currentTheme.Accent
    button.BorderSizePixel = 0
    button.Text = config.Text or "按钮"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = config.TextSize or 14
    button.Font = Enum.Font.Gotham
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    -- 悬停效果
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(255, (config.Color or self.currentTheme.Accent).R * 255 + 20),
                math.min(255, (config.Color or self.currentTheme.Accent).G * 255 + 20),
                math.min(255, (config.Color or self.currentTheme.Accent).B * 255 + 20)
            )
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = config.Color or self.currentTheme.Accent
        }):Play()
    end)
    
    if config.Callback then
        button.MouseButton1Click:Connect(config.Callback)
    end
    
    return button
end

function Valkyrie:AddToggle(parent, config)
    config = config or {}
    
    local frame = Instance.new("Frame")
    frame.Name = config.Name or "CustomToggle"
    frame.Size = config.Size or UDim2.new(1, -20, 0, 40)
    frame.Position = config.Position or UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = self.currentTheme.Secondary
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local toggle = self:CreateToggle(frame, config.Text or "开关", config.Default or false)
    
    if config.Callback then
        toggle.ToggleChanged.Event:Connect(config.Callback)
    end
    
    return toggle
end

function Valkyrie:AddSlider(parent, config)
    config = config or {}
    
    local frame = Instance.new("Frame")
    frame.Name = config.Name or "CustomSlider"
    frame.Size = config.Size or UDim2.new(1, -20, 0, 60)
    frame.Position = config.Position or UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = self.currentTheme.Secondary
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 25)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = config.Text or "滑块"
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.Gotham
    titleLabel.Parent = frame
    
    local slider = self:CreateSlider(frame, "", UDim2.new(0, 10, 0, 30), 
                                    config.Default or 50, config.Min or 0, config.Max or 100)
    
    if config.Callback then
        slider.ValueChanged.Event:Connect(config.Callback)
    end
    
    return slider
end

function Valkyrie:AddLabel(parent, config)
    config = config or {}
    
    local label = Instance.new("TextLabel")
    label.Name = config.Name or "CustomLabel"
    label.Size = config.Size or UDim2.new(1, -20, 0, 30)
    label.Position = config.Position or UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.Text = config.Text or "标签"
    label.TextColor3 = config.Color or self.currentTheme.Text
    label.TextSize = config.TextSize or 14
    label.TextXAlignment = config.TextXAlignment or Enum.TextXAlignment.Left
    label.Font = config.Font or Enum.Font.Gotham
    label.TextWrapped = true
    label.Parent = parent
    
    return label
end

-- 保存配置
function Valkyrie:SaveConfig()
    local config = {
        Theme = self.config.Theme,
        Position = {
            X = {Scale = self.MainFrame.Position.X.Scale, Offset = self.MainFrame.Position.X.Offset},
            Y = {Scale = self.MainFrame.Position.Y.Scale, Offset = self.MainFrame.Position.Y.Offset}
        },
        Capsules = {}
    }
    
    for name, capsule in pairs(self.capsules) do
        config.Capsules[name] = {
            Type = capsule.type,
            Position = {
                X = {Scale = capsule.frame.Position.X.Scale, Offset = capsule.frame.Position.X.Offset},
                Y = {Scale = capsule.frame.Position.Y.Scale, Offset = capsule.frame.Position.Y.Offset}
            },
            Size = {
                X = {Scale = capsule.frame.Size.X.Scale, Offset = capsule.frame.Size.X.Offset},
                Y = {Scale = capsule.frame.Size.Y.Scale, Offset = capsule.frame.Size.Y.Offset}
            }
        }
    end
    
    -- 这里可以添加保存到文件的逻辑
    return config
end

-- 加载配置
function Valkyrie:LoadConfig(config)
    if not config then return end
    
    if config.Theme then
        self:ChangeTheme(config.Theme)
    end
    
    if config.Position then
        self.MainFrame.Position = UDim2.new(
            config.Position.X.Scale, config.Position.X.Offset,
            config.Position.Y.Scale, config.Position.Y.Offset
        )
    end
    
    if config.Capsules then
        for name, capsuleConfig in pairs(config.Capsules) do
            local capsule = self:CreateCapsule(name, capsuleConfig.Type)
            if capsule and capsuleConfig.Position then
                capsule.frame.Position = UDim2.new(
                    capsuleConfig.Position.X.Scale, capsuleConfig.Position.X.Offset,
                    capsuleConfig.Position.Y.Scale, capsuleConfig.Position.Y.Offset
                )
            end
            if capsule and capsuleConfig.Size then
                capsule.frame.Size = UDim2.new(
                    capsuleConfig.Size.X.Scale, capsuleConfig.Size.X.Offset,
                    capsuleConfig.Size.Y.Scale, capsuleConfig.Size.Y.Offset
                )
            end
        end
    end
end

-- 返回库对象
return Valkyrie

--[[
使用示例:

local Valkyrie = require(script.ValkyrieUI)

-- 创建 UI 实例
local ui = Valkyrie.new({
    Title = "我的脚本",
    Theme = "Dark",
    Size = UDim2.new(0, 600, 0, 400)
})

-- 显示 UI
ui:Show()

-- 添加自定义标签页
local mainTab = ui:AddCustomTab("主要功能", "rbxassetid://7072707318", function(container)
    -- 添加按钮
    ui:AddButton(container, {
        Text = "传送到大厅",
        Position = UDim2.new(0, 10, 0, 10),
        Callback = function()
            print("传送功能")
        end
    })
    
    -- 添加开关
    ui:AddToggle(container, {
        Text = "飞行模式",
        Position = UDim2.new(0, 10, 0, 60),
        Default = false,
        Callback = function(enabled)
            print("飞行模式:", enabled)
        end
    })
    
    -- 添加滑块
    ui:AddSlider(container, {
        Text = "行走速度",
        Position = UDim2.new(0, 10, 0, 110),
        Default = 16,
        Min = 1,
        Max = 100,
        Callback = function(value)
            print("速度设置为:", value)
        end
    })
end)

-- 创建胶囊组件
ui:CreateCapsule("快速传送", "TextButton", {
    Text = "传送",
    Position = UDim2.new(0, 100, 0, 100)
})

-- 发送通知
ui:Notify({
    Title = "脚本已加载!",
    Message = "所有功能都已准备就绪",
    Type = "Success",
    Duration = 3
})

-- 创建示例组件
ui:CreateExampleComponents()
]]