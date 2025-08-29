-- Valkyrie UI Library v2.0
-- 全面改进版：支持配置保存、自定义主题、更好的移动端适配等

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local Valkyrie = {}
Valkyrie.__index = Valkyrie
Valkyrie.instance = nil -- 单例模式

-- 配置文件路径
local CONFIG_FOLDER = "ValkyrieUI"
local CONFIG_FILE = "config.json"

-- 默认主题
local DefaultTheme = {
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
    Star = "rbxassetid://7072719594",
    Roblox = "rbxassetid://7072719594" -- 默认Roblox图标，可自定义
}

-- 胶囊功能类型
local CapsuleTypes = {
    {
        name = "飞行开关", 
        type = "Toggle", 
        desc = "开启/关闭飞行功能",
        functionality = function(enabled)
            local player = Players.LocalPlayer
            if player and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    if enabled then
                        -- 启用飞行
                        local bodyVelocity = Instance.new("BodyVelocity")
                        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                        bodyVelocity.Parent = player.Character.HumanoidRootPart
                        player.Character:SetAttribute("Flying", true)
                        player.Character:SetAttribute("BodyVelocity", bodyVelocity)
                    else
                        -- 禁用飞行
                        local bodyVelocity = player.Character:GetAttribute("BodyVelocity")
                        if bodyVelocity then
                            bodyVelocity:Destroy()
                        end
                        player.Character:SetAttribute("Flying", false)
                    end
                end
            end
        end
    },
    {
        name = "速度滑块", 
        type = "Slider", 
        desc = "调节行走速度 (16-100)",
        min = 16,
        max = 100,
        default = 16,
        functionality = function(value)
            local player = Players.LocalPlayer
            if player and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = value
                end
            end
        end
    },
    {
        name = "跳跃高度", 
        type = "Slider", 
        desc = "调节跳跃高度 (50-200)",
        min = 50,
        max = 200,
        default = 50,
        functionality = function(value)
            local player = Players.LocalPlayer
            if player and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.JumpPower = value
                end
            end
        end
    },
    {
        name = "无限跳跃", 
        type = "Toggle", 
        desc = "开启/关闭无限跳跃",
        functionality = function(enabled)
            local player = Players.LocalPlayer
            if player and player.Character then
                player.Character:SetAttribute("InfiniteJump", enabled)
                
                if enabled then
                    -- 连接无限跳跃功能
                    local connection
                    connection = UserInputService.JumpRequest:Connect(function()
                        if player.Character and player.Character:GetAttribute("InfiniteJump") then
                            local humanoid = player.Character:FindFirstChild("Humanoid")
                            if humanoid then
                                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                            end
                        else
                            connection:Disconnect()
                        end
                    end)
                end
            end
        end
    },
    {
        name = "传送到出生点", 
        type = "Button", 
        desc = "一键传送到出生点",
        functionality = function()
            local player = Players.LocalPlayer
            if player and player.Character then
                local spawnLocation = workspace:FindFirstChild("SpawnLocation")
                if spawnLocation then
                    player.Character:MoveTo(spawnLocation.Position + Vector3.new(0, 5, 0))
                end
            end
        end
    },
    {
        name = "玩家信息", 
        type = "Label", 
        desc = "显示当前玩家信息",
        functionality = function()
            local player = Players.LocalPlayer
            return "玩家: " .. player.Name .. " | ID: " .. player.UserId
        end
    }
}

-- 创建 UI 实例
function Valkyrie.new(config)
    -- 销毁之前的实例
    if Valkyrie.instance then
        Valkyrie.instance:Destroy()
    end
    
    local self = setmetatable({}, Valkyrie)
    Valkyrie.instance = self
    
    -- 配置
    self.config = config or {}
    self.config.Title = self.config.Title or "Valkyrie UI"
    self.config.FloatingIcon = self.config.FloatingIcon or Icons.Roblox
    self.config.Size = self.config.Size or UDim2.new(0, 400, 0, 400)
    self.config.Position = self.config.Position or UDim2.new(0.5, -200, 0.5, -200)
    
    -- 状态
    self.isVisible = false
    self.isInitialized = false
    
    -- 初始化主题 (确保在使用前完全初始化)
    self.currentTheme = {}
    for k, v in pairs(DefaultTheme) do
        self.currentTheme[k] = v
    end
    
    self.customTheme = nil
    self.tabs = {}
    self.capsules = {}
    self.notifications = {}
    self.nextCapsulePosition = Vector2.new(100, 100)
    
    -- 加载配置
    self:LoadConfig()
    
    -- 显示启动动画
    self:ShowStartupAnimation()
    
    return self
end


-- 启动动画
function Valkyrie:ShowStartupAnimation()
    -- 创建启动画面
    local startupGui = Instance.new("ScreenGui")
    startupGui.Name = "ValkyrieStartup"
    startupGui.ResetOnSpawn = false
    startupGui.Parent = CoreGui
    
    local startupFrame = Instance.new("Frame")
    startupFrame.Size = UDim2.new(1, 0, 1, 0)
    startupFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    startupFrame.BackgroundTransparency = 0
    startupFrame.BorderSizePixel = 0
    startupFrame.Parent = startupGui
    
    local logoImage = Instance.new("ImageLabel")
    logoImage.Size = UDim2.new(0, 150, 0, 150)
    logoImage.Position = UDim2.new(0.5, -75, 0.5, -75)
    logoImage.BackgroundTransparency = 1
    logoImage.Image = self.config.FloatingIcon
    logoImage.ImageTransparency = 1
    logoImage.Parent = startupFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 300, 0, 50)
    titleLabel.Position = UDim2.new(0.5, -150, 0.5, 100)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Valkyrie UI"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 24
    titleLabel.TextTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = startupFrame
    
    -- 淡入动画
    spawn(function()
        TweenService:Create(logoImage, TweenInfo.new(0.8), {ImageTransparency = 0}):Play()
        TweenService:Create(titleLabel, TweenInfo.new(0.8), {TextTransparency = 0}):Play()
        
        wait(1.5)
        
        -- 淡出动画
        local fadeOut1 = TweenService:Create(logoImage, TweenInfo.new(0.5), {ImageTransparency = 1})
        local fadeOut2 = TweenService:Create(titleLabel, TweenInfo.new(0.5), {TextTransparency = 1})
        local fadeOut3 = TweenService:Create(startupFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
        
        fadeOut1:Play()
        fadeOut2:Play()
        fadeOut3:Play()
        
        fadeOut3.Completed:Connect(function()
            startupGui:Destroy()
            -- 创建主界面
            self:CreateMainUI()
            self:CreateFloatingButton()
            self.isInitialized = true
        end)
    end)
end

-- 创建主界面
function Valkyrie:CreateMainUI()
    -- 主容器
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "ValkyrieUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.ScreenGui.IgnoreGuiInset = true
    self.ScreenGui.Parent = CoreGui
    
    -- 确保主题已正确初始化
    if not self.currentTheme or not self.currentTheme.Primary then
        self.currentTheme = {}
        for k, v in pairs(DefaultTheme) do
            self.currentTheme[k] = v
        end
    end
    
    -- 确保配置已初始化
    if not self.config then
        self.config = {}
    end
    self.config.Size = self.config.Size or UDim2.new(0, 400, 0, 400)
    self.config.Position = self.config.Position or UDim2.new(0.5, -200, 0.5, -200)
    
    -- 主框架
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "MainFrame"
    self.MainFrame.Size = self.config.Size
    self.MainFrame.Position = self.config.Position
    self.MainFrame.BackgroundColor3 = self.currentTheme.Primary
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Visible = false
    self.MainFrame.Active = true
    self.MainFrame.Parent = self.ScreenGui
    
    -- 圆角
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = self.MainFrame
    
    -- 创建组件
    self:CreateTitleBar()
    self:CreateContentArea()
    self:CreateNotificationSystem()
    self:MakeDraggable()
    self:AdaptForMobile()
    
    -- 创建默认标签页
    self:AddTab("主页", Icons.Home, true)
    self:AddTab("胶囊管理", Icons.Settings)
    self:AddTab("主题设置", Icons.Edit)
end

-- 创建标题栏
function Valkyrie:CreateTitleBar()
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 40)
    self.TitleBar.Position = UDim2.new(0, 0, 0, 0)
    self.TitleBar.BackgroundColor3 = self.currentTheme.Secondary or Color3.fromRGB(35, 35, 45)
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Parent = self.MainFrame
    
    -- Rest of the function remains the same...
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = self.TitleBar
    
    -- 标题文本
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -80, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = self.config.Title
    titleLabel.TextColor3 = self.currentTheme.Text or Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = self.TitleBar
    
    -- 关闭按钮
    local closeButton = Instance.new("ImageButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 25, 0, 25)
    closeButton.Position = UDim2.new(1, -32, 0, 7.5)
    closeButton.BackgroundColor3 = self.currentTheme.Error or Color3.fromRGB(240, 71, 71)
    closeButton.BorderSizePixel = 0
    closeButton.Image = Icons.Close
    closeButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Parent = self.TitleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            self:Notify({
                Title = "UI 已关闭",
                Message = "Valkyrie UI 已完全销毁",
                Type = "Warning",
                Duration = 2
            })
            wait(0.5)
            self:Destroy()
        end, "关闭UI时出错")
    end)
    
    -- 悬停效果
    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
    end)
    
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.Error or Color3.fromRGB(240, 71, 71)}):Play()
    end)
end

-- 创建内容区域（左侧标签，右侧内容）
function Valkyrie:CreateContentArea()
    -- 左侧标签栏
    self.SidebarFrame = Instance.new("Frame")
    self.SidebarFrame.Name = "SidebarFrame"
    self.SidebarFrame.Size = UDim2.new(0, 120, 1, -45)
    self.SidebarFrame.Position = UDim2.new(0, 5, 0, 42)
    self.SidebarFrame.BackgroundColor3 = self.currentTheme.Secondary
    self.SidebarFrame.BorderSizePixel = 0
    self.SidebarFrame.Parent = self.MainFrame
    
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 8)
    sidebarCorner.Parent = self.SidebarFrame
    
    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, 5)
    sidebarLayout.Parent = self.SidebarFrame
    
    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 5)
    sidebarPadding.PaddingBottom = UDim.new(0, 5)
    sidebarPadding.PaddingLeft = UDim.new(0, 5)
    sidebarPadding.PaddingRight = UDim.new(0, 5)
    sidebarPadding.Parent = self.SidebarFrame
    
    -- 右侧内容框架
    self.ContentFrame = Instance.new("Frame")
    self.ContentFrame.Name = "ContentFrame"
    self.ContentFrame.Size = UDim2.new(1, -135, 1, -45)
    self.ContentFrame.Position = UDim2.new(0, 130, 0, 42)
    self.ContentFrame.BackgroundColor3 = self.currentTheme.Background
    self.ContentFrame.BorderSizePixel = 0
    self.ContentFrame.Parent = self.MainFrame
    
    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 8)
    contentCorner.Parent = self.ContentFrame
end

-- 创建悬浮按钮（可拖拽）
function Valkyrie:CreateFloatingButton()
    self.FloatingButton = Instance.new("ImageButton")
    self.FloatingButton.Name = "FloatingButton"
    self.FloatingButton.Size = UDim2.new(0, 55, 0, 55)
    self.FloatingButton.Position = UDim2.new(1, -75, 1, -75)
    self.FloatingButton.BackgroundColor3 = self.currentTheme.Accent
    self.FloatingButton.BorderSizePixel = 0
    self.FloatingButton.Image = self.config.FloatingIcon
    self.FloatingButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    self.FloatingButton.Active = true
    self.FloatingButton.Parent = self.ScreenGui
    
    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 27.5)
    floatCorner.Parent = self.FloatingButton
    
    -- 使悬浮按钮可拖拽
    self:MakeFloatingButtonDraggable()
    
    -- 点击事件
    self.FloatingButton.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            self:Toggle()
        end, "切换UI显示时出错")
    end)
    
    -- 悬停效果
    self.FloatingButton.MouseEnter:Connect(function()
        TweenService:Create(self.FloatingButton, TweenInfo.new(0.2), {
            BackgroundColor3 = self.currentTheme.AccentHover,
            Size = UDim2.new(0, 60, 0, 60)
        }):Play()
    end)
    
    self.FloatingButton.MouseLeave:Connect(function()
        TweenService:Create(self.FloatingButton, TweenInfo.new(0.2), {
            BackgroundColor3 = self.currentTheme.Accent,
            Size = UDim2.new(0, 55, 0, 55)
        }):Play()
    end)
end

-- 使悬浮按钮可拖拽
function Valkyrie:MakeFloatingButtonDraggable()
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    self.FloatingButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = self.FloatingButton.Position
        end
    end)
    
    self.FloatingButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.FloatingButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                                                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- 添加标签页
function Valkyrie:AddTab(name, icon, defaultSelected)
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name .. "Tab"
    tabButton.Size = UDim2.new(1, 0, 0, 40)
    tabButton.BackgroundColor3 = self.currentTheme.Primary
    tabButton.BorderSizePixel = 0
    tabButton.Text = ""
    tabButton.LayoutOrder = #self.tabs + 1
    tabButton.Parent = self.SidebarFrame
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabButton
    
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
    textLabel.TextSize = 12
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Font = Enum.Font.Gotham
    textLabel.Parent = tabButton
    
    -- 标签页内容
    local tabContent = Instance.new("ScrollingFrame")
    tabContent.Name = name .. "Content"
    tabContent.Size = UDim2.new(1, -10, 1, -10)
    tabContent.Position = UDim2.new(0, 5, 0, 5)
    tabContent.BackgroundTransparency = 1
    tabContent.BorderSizePixel = 0
    tabContent.ScrollBarThickness = 6
    tabContent.ScrollBarImageColor3 = self.currentTheme.Accent
    tabContent.Visible = false
    tabContent.Parent = self.ContentFrame
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 10)
    contentLayout.Parent = tabContent
    
    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 10)
    contentPadding.PaddingBottom = UDim.new(0, 10)
    contentPadding.PaddingLeft = UDim.new(0, 10)
    contentPadding.PaddingRight = UDim.new(0, 10)
    contentPadding.Parent = tabContent
    
    -- 标签页切换事件
    tabButton.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            self:SwitchTab(name)
            -- 删除互动通知
        end, "切换标签页时出错")
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
        active = false
    }
    
    -- 创建预设内容
    self:CreateTabContent(name, tabContent)
    
    -- 如果是默认选中或第一个标签页
    if defaultSelected or #self.tabs == 1 then
        spawn(function()
            wait(0.1)
            self:SwitchTab(name)
        end)
    end
    
    -- 更新滚动区域
    contentLayout.Changed:Connect(function()
        tabContent.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 20)
    end)
    
    return tabContent
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
    -- 欢迎区域
    self:CreateContentSection(container, {
        title = "欢迎使用 Valkyrie UI v2.0",
        items = {
            {type = "label", text = "🎉 全新设计，更好的用户体验"},
            {type = "label", text = "💊 智能胶囊管理系统"},
            {type = "label", text = "🎨 完全自定义主题支持"},
            {type = "label", text = "📱 完美的移动端适配"},
            {type = "label", text = "💾 配置自动保存与加载"},
            {type = "label", text = "🔔 智能通知系统"}
        }
    })
    
    -- 快速操作
    self:CreateContentSection(container, {
        title = "快速操作",
        items = {
            {
                type = "button", 
                text = "创建新胶囊", 
                callback = function()
                    self:SwitchTab("胶囊管理")
                    self:Notify({
                        Title = "快速跳转",
                        Message = "已跳转到胶囊管理页面",
                        Type = "Success",
                        Duration = 2
                    })
                end
            },
            {
                type = "button", 
                text = "自定义主题", 
                callback = function()
                    self:SwitchTab("主题设置")
                    self:Notify({
                        Title = "快速跳转",
                        Message = "已跳转到主题设置页面",
                        Type = "Success",
                        Duration = 2
                    })
                end
            }
        }
    })
end

-- 创建胶囊管理内容
function Valkyrie:CreateCapsuleContent(container)
    -- 添加胶囊区域
    local addSection = self:CreateContentSection(container, {
        title = "添加新胶囊",
        items = {
            {type = "label", text = "选择胶囊类型："}
        }
    })
    
    -- 胶囊类型选择
    for i, capsuleType in ipairs(CapsuleTypes) do
        self:CreateRowItem(addSection, capsuleType.name, {
            type = "button",
            text = "创建",
            callback = function()
                self:SafeExecute(function()
                    self:ShowCreateCapsuleDialog(capsuleType)
                end, "创建胶囊时出错")
            end
        }, capsuleType.desc)
    end
    
    -- 已创建胶囊列表
    self.CapsuleListSection = self:CreateContentSection(container, {
        title = "已创建的胶囊",
        items = {}
    })
    
    self:RefreshCapsuleList()
end

-- 创建主题设置内容
function Valkyrie:CreateThemeContent(container)
    -- 主色调设置
    local colorSection = self:CreateContentSection(container, {
        title = "主色调设置",
        items = {}
    })
    
    -- 颜色选择器
    self:CreateRowItem(colorSection, "主色调", {
        type = "color",
        default = self.currentTheme.Accent,
        callback = function(color)
            self:SafeExecute(function()
                self.currentTheme.Accent = color
                self.currentTheme.AccentHover = Color3.fromRGB(
                    math.min(255, color.R * 255 + 20),
                    math.min(255, color.G * 255 + 20),
                    math.min(255, color.B * 255 + 20)
                )
                self:UpdateTheme()
                self:SaveConfig()
            end, "更新主色调时出错")
        end
    })
    
    -- 背景颜色
    self:CreateRowItem(colorSection, "背景色", {
        type = "color",
        default = self.currentTheme.Primary,
        callback = function(color)
            self:SafeExecute(function()
                self.currentTheme.Primary = color
                self:UpdateTheme()
                self:SaveConfig()
            end, "更新背景色时出错")
        end
    })
    
    -- 主题操作
    local themeSection = self:CreateContentSection(container, {
        title = "主题管理",
        items = {}
    })
    
    self:CreateRowItem(themeSection, "重置主题", {
        type = "button",
        text = "重置",
        callback = function()
            self:SafeExecute(function()
                -- 复制默认主题
                for k, v in pairs(DefaultTheme) do
                    self.currentTheme[k] = v
                end
                self:UpdateTheme()
                self:SaveConfig()
            end, "重置主题时出错")
        end
    })
    
    self:CreateRowItem(themeSection, "悬浮按钮图标", {
        type = "textbox",
        placeholder = "输入图像资产ID",
        callback = function(value)
            self:SafeExecute(function()
                if value and value ~= "" then
                    local assetId = "rbxassetid://" .. value
                    self.config.FloatingIcon = assetId
                    if self.FloatingButton then
                        self.FloatingButton.Image = assetId
                    end
                    self:SaveConfig()
                end
            end, "更新图标时出错")
        end
    })
end

-- 创建内容区块
function Valkyrie:CreateContentSection(parent, config)
    local section = Instance.new("Frame")
    section.Name = config.title
    section.BackgroundColor3 = self.currentTheme.Secondary
    section.BorderSizePixel = 0
    section.LayoutOrder = #parent:GetChildren()
    section.Parent = parent
    
    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 8)
    sectionCorner.Parent = section

    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.FillDirection = Enum.FillDirection.Vertical
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Padding = UDim.new(0, 5)
    sectionLayout.Parent = section

    local sectionPadding = Instance.new("UIPadding")
    sectionPadding.PaddingTop = UDim.new(0, 10)
    sectionPadding.PaddingBottom = UDim.new(0, 10)
    sectionPadding.PaddingLeft = UDim.new(0, 10)
    sectionPadding.PaddingRight = UDim.new(0, 10)
    sectionPadding.Parent = section

    -- 标题
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 25)
    titleLabel.BackgroundTransparency = 0  -- 确保背景透明
    titleLabel.Text = config.title
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.LayoutOrder = 1
    titleLabel.Parent = section

    -- 添加项目
    for i, item in ipairs(config.items or {}) do
        if item.type == "label" then
            self:CreateLabel(section, item.text, i + 1)
        elseif item.type == "button" then
            self:CreateButton(section, item.text, item.callback, i + 1)
        end
    end

    -- 更新大小
    sectionLayout.Changed:Connect(function()
        local totalHeight = sectionLayout.AbsoluteContentSize.Y + 20
        if totalHeight > 0 then
            section.Size = UDim2.new(1, 0, 0, totalHeight)
        end
    end)

    return section
end

-- 创建行项目（左侧名称，右侧控件）
function Valkyrie:CreateRowItem(parent, name, config, description)
    -- 确定行高
    local rowHeight = 30 -- 基础高度：名称标签
    if description then rowHeight = rowHeight + 20 end -- 如果有描述，增加高度

    -- 根据控件类型增加高度
    if config.type == "button" then
        rowHeight = rowHeight + 30 -- 按钮高度 + 间距
    elseif config.type == "toggle" then
        rowHeight = rowHeight + 30 -- 开关容器高度 + 间距
    elseif config.type == "slider" then
        rowHeight = rowHeight + 40 -- 滑块容器高度 + 间距
    elseif config.type == "textbox" then
        rowHeight = rowHeight + 30 -- 文本框高度 + 间距
    elseif config.type == "color" then
        rowHeight = rowHeight + 40 -- 颜色选择器容器高度 + 间距
    end

    -- 创建行容器 Frame
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, rowHeight) -- 使用计算出的高度
    row.BackgroundTransparency = 1 -- 关键：确保行容器本身透明，不显示背景色
    row.BorderSizePixel = 0
    row.LayoutOrder = #parent:GetChildren()
    row.Name = name .. "Row" -- 可选：给行命名方便调试
    row.Parent = parent

    -- 使用 UIListLayout 管理内部垂直排列
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Vertical
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Padding = UDim.new(0, 2) -- 控件间的垂直间距
    rowLayout.Parent = row

    -- 名称标签
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1 -- 确保背景透明
    nameLabel.BorderSizePixel = 0 -- 移除边框
    nameLabel.Text = name
    nameLabel.TextColor3 = self.currentTheme.Text
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Parent = row

    local descLabel = nil
    -- 描述标签（如果有）
    if description then
        descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, 0, 0, 15)
        descLabel.BackgroundTransparency = 1 -- 确保背景透明
        descLabel.BorderSizePixel = 0 -- 移除边框
        descLabel.Text = description
        descLabel.TextColor3 = self.currentTheme.TextSecondary
        descLabel.TextSize = 11
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.Parent = row
    end

    -- 控件
    if config.type == "button" then
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 25) -- 调整按钮高度
        button.BackgroundColor3 = self.currentTheme.Accent
        button.BorderSizePixel = 0
        button.Text = config.text or "按钮"
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.Font = Enum.Font.Gotham
        button.Parent = row -- 直接作为 row 的子项
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = button
        if config.callback then
            button.MouseButton1Click:Connect(config.callback)
        end
        button.MouseEnter:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.AccentHover}):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.Accent}):Play()
        end)

    elseif config.type == "toggle" then
        -- 创建开关，但不给其容器添加背景色
        local toggle = self:CreateToggle(row, config.default or false, config.callback) -- 直接作为 row 的子项
        -- toggle.frame.Size = UDim2.new(1, 0, 0, 25) -- 如果需要调整开关容器大小
        -- toggle.frame.Position = UDim2.new(0, 0, 0, 0) -- 通常不需要，因为 ListLayout 会处理

    elseif config.type == "slider" then
        -- 创建滑块，但不给其容器添加背景色
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, 0, 0, 35) -- 设置滑块区域高度
        sliderFrame.BackgroundTransparency = 1 -- 关键：确保容器透明
        sliderFrame.BorderSizePixel = 0
        sliderFrame.Parent = row -- 作为 row 的子项

        -- 传递 capsuleTypeData 或 config 的 min/max/default
        local min_val = (config.min or 0)
        local max_val = (config.max or 100)
        local default_val = (config.default or ((min_val + max_val) / 2)) -- 默认值逻辑

        local slider = self:CreateSlider(sliderFrame, default_val, min_val, max_val,
            function(value)
                if config.callback then
                    config.callback(value)
                end
            end)

    elseif config.type == "textbox" then
        local textbox = Instance.new("TextBox")
        textbox.Size = UDim2.new(1, 0, 0, 25) -- 调整文本框高度
        textbox.BackgroundColor3 = self.currentTheme.Secondary -- 文本框通常需要背景色以便输入
        textbox.BackgroundTransparency = 0 -- 确保背景色可见
        textbox.BorderSizePixel = 0
        textbox.Text = config.default or ""
        textbox.PlaceholderText = config.placeholder or ""
        textbox.TextColor3 = self.currentTheme.Text
        textbox.TextSize = 12
        textbox.Font = Enum.Font.Gotham
        textbox.Parent = row -- 直接作为 row 的子项
        local textboxCorner = Instance.new("UICorner")
        textboxCorner.CornerRadius = UDim.new(0, 4)
        textboxCorner.Parent = textbox
        if config.callback then
            textbox.FocusLost:Connect(function(enterPressed)
                 -- 可以移除 enterPressed 条件，失去焦点即触发
                 -- if enterPressed then
                    config.callback(textbox.Text)
                 -- end
            end)
        end

    elseif config.type == "color" then
         -- 创建颜色选择器，但不给其容器添加背景色
        local colorFrame = Instance.new("Frame")
        colorFrame.Size = UDim2.new(1, 0, 0, 35) -- 设置颜色选择器区域高度
        colorFrame.BackgroundTransparency = 1 -- 关键：确保容器透明
        colorFrame.BorderSizePixel = 0
        colorFrame.Parent = row -- 作为 row 的子项

        local colorPicker = self:CreateColorPicker(colorFrame, config.default or Color3.fromRGB(255, 255, 255), config.callback)

    end

    -- 注意：移除了原来动态调整 row 高度的 rowLayout.Changed 连接，
    -- 因为我们已经根据内容预先计算了高度。如果内容高度动态变化很复杂，
    -- 可以保留，但需要确保它不会与预设高度冲突或导致闪烁。
    -- 如果保留，确保只在必要时更新，并且逻辑正确。
    -- [[
    -- rowLayout.Changed:Connect(function()
    --     local contentHeight = rowLayout.AbsoluteContentSize.Y
    --     if contentHeight > 0 then
    --         row.Size = UDim2.new(1, 0, 0, contentHeight + 5) -- +5 是为了底部 padding
    --     end
    -- end)
    -- ]]

    return row
end

-- 创建标签
function Valkyrie:CreateLabel(parent, text, layoutOrder)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self.currentTheme.TextSecondary
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.LayoutOrder = layoutOrder or 1
    label.Parent = parent
    return label
end

-- 创建按钮
function Valkyrie:CreateButton(parent, text, callback, layoutOrder)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 35)
    button.BackgroundColor3 = self.currentTheme.Accent
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.Font = Enum.Font.Gotham
    button.LayoutOrder = layoutOrder or 1
    button.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    if callback then
        button.MouseButton1Click:Connect(callback)
    end
    
    -- 悬停效果
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.AccentHover}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = self.currentTheme.Accent}):Play()
    end)
    
    return button
end

-- 创建开关
function Valkyrie:CreateToggle(parent, default, callback)
    local toggle = {enabled = default or false}
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 50, 0, 25)
    frame.BackgroundTransparency = 1  -- 确保容器透明
    frame.BorderSizePixel = 0  -- 移除边框
    frame.Parent = parent
    
    local switchFrame = Instance.new("Frame")
    switchFrame.Size = UDim2.new(0, 40, 0, 20)
    switchFrame.Position = UDim2.new(0, 5, 0.5, -10)
    switchFrame.BackgroundColor3 = toggle.enabled and self.currentTheme.Accent or self.currentTheme.Border
    switchFrame.BorderSizePixel = 0
    switchFrame.Parent = frame
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 10)
    switchCorner.Parent = switchFrame
    
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = toggle.enabled and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.Parent = switchFrame
    
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 8)
    thumbCorner.Parent = thumb
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0  -- 移除边框
    button.Text = ""
    button.Parent = switchFrame
    
    button.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            toggle.enabled = not toggle.enabled
            
            local targetPos = toggle.enabled and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
            local targetColor = toggle.enabled and self.currentTheme.Accent or self.currentTheme.Border
            
            TweenService:Create(thumb, TweenInfo.new(0.2), {Position = targetPos}):Play()
            TweenService:Create(switchFrame, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            
            if callback then
                callback(toggle.enabled)
            end
        end, "切换开关时出错")
    end)
    
    toggle.frame = frame
    return toggle
end

-- 创建滑块
function Valkyrie:CreateSlider(parent, default, min, max, callback)
    local slider = {value = default or 50, min = min or 0, max = max or 100}
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1  -- 确保容器透明
    frame.BorderSizePixel = 0  -- 移除边框
    frame.Parent = parent
    
    -- 数值显示和输入框
    local valueBox = Instance.new("TextBox")
    valueBox.Size = UDim2.new(0, 60, 0, 20)
    valueBox.Position = UDim2.new(1, -60, 0, 0)
    valueBox.BackgroundColor3 = self.currentTheme.Secondary
    valueBox.BorderSizePixel = 0
    valueBox.Text = tostring(math.floor(slider.value))
    valueBox.TextColor3 = self.currentTheme.Text
    valueBox.TextSize = 10
    valueBox.Font = Enum.Font.Gotham
    valueBox.Parent = frame
    
    local valueCorner = Instance.new("UICorner")
    valueCorner.CornerRadius = UDim.new(0, 3)
    valueCorner.Parent = valueBox
    
    -- 滑轨
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -70, 0, 4)
    track.Position = UDim2.new(0, 0, 0.5, -2)
    track.BackgroundColor3 = self.currentTheme.Border
    track.BorderSizePixel = 0
    track.Parent = frame
    
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 2)
    trackCorner.Parent = track
    
    -- 滑块
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = UDim2.new((slider.value - slider.min) / (slider.max - slider.min), -8, 0.5, -8)
    thumb.BackgroundColor3 = self.currentTheme.Accent
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 8)
    thumbCorner.Parent = thumb
    
    -- 更新函数
    local function updateSlider(newValue)
        newValue = math.clamp(newValue, slider.min, slider.max)
        slider.value = newValue
        
        local relativeX = (newValue - slider.min) / (slider.max - slider.min)
        thumb.Position = UDim2.new(relativeX, -8, 0.5, -8)
        valueBox.Text = tostring(math.floor(newValue))
        
        if callback then
            callback(newValue)
        end
    end
    
    -- 拖拽功能 (保持原有逻辑)
    local dragging = false
    
    local function handleInput(input)
        if track.AbsoluteSize.X > 0 then
            local trackSize = track.AbsoluteSize.X
            local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / trackSize, 0, 1)
            local newValue = slider.min + (slider.max - slider.min) * relativeX
            updateSlider(newValue)
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
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            handleInput(input)
            dragging = true
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            handleInput(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- 数值框输入
    valueBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local newValue = tonumber(valueBox.Text)
            if newValue then
                updateSlider(newValue)
            else
                valueBox.Text = tostring(math.floor(slider.value))
                warn("Invalid input in slider textbox")
            end
        end
    end)
    
    slider.frame = frame
    slider.update = updateSlider
    return slider
end

-- 创建颜色选择器
function Valkyrie:CreateColorPicker(parent, defaultColor, callback)
    local picker = {color = defaultColor or Color3.fromRGB(255, 255, 255)}
    
    -- 颜色预览
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 25, 1, 0)
    preview.BackgroundColor3 = picker.color
    preview.BorderSizePixel = 1
    preview.BorderColor3 = self.currentTheme.Border
    preview.Parent = parent
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 4)
    previewCorner.Parent = preview
    
    -- RGB滑块区域
    local rgbFrame = Instance.new("Frame")
    rgbFrame.Size = UDim2.new(1, -30, 1, 0)
    rgbFrame.Position = UDim2.new(0, 30, 0, 0)
    rgbFrame.BackgroundTransparency = 1
    rgbFrame.Parent = parent
    
    local sliders = {}
    local colors = {"R", "G", "B"}
    local values = {picker.color.R * 255, picker.color.G * 255, picker.color.B * 255}
    
    for i, colorName in ipairs(colors) do
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1/3, -2, 1, 0)
        sliderFrame.Position = UDim2.new((i-1)/3, (i-1)*2, 0, 0)
        sliderFrame.BackgroundTransparency = 1
        sliderFrame.Parent = rgbFrame
        
        sliders[colorName] = self:CreateSlider(sliderFrame, values[i], 0, 255, function(value)
            values[i] = value
            picker.color = Color3.fromRGB(values[1], values[2], values[3])
            preview.BackgroundColor3 = picker.color
            if callback then
                callback(picker.color)
            end
        end)
    end
    
    return picker
end

-- 显示创建胶囊对话框
function Valkyrie:ShowCreateCapsuleDialog(capsuleTypeData)
    -- 创建对话框
    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 300, 0, 150)
    dialog.Position = UDim2.new(0.5, -150, 0.5, -75)
    dialog.BackgroundColor3 = self.currentTheme.Primary
    dialog.BorderSizePixel = 0
    dialog.Parent = self.ScreenGui
    
    local dialogCorner = Instance.new("UICorner")
    dialogCorner.CornerRadius = UDim.new(0, 12)
    dialogCorner.Parent = dialog
    
    -- 标题
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "创建 " .. capsuleTypeData.name
    title.TextColor3 = self.currentTheme.Text
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = dialog
    
    -- 描述
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -20, 0, 30)
    desc.Position = UDim2.new(0, 10, 0, 40)
    desc.BackgroundTransparency = 1
    desc.Text = capsuleTypeData.desc
    desc.TextColor3 = self.currentTheme.TextSecondary
    desc.TextSize = 12
    desc.Font = Enum.Font.Gotham
    desc.TextWrapped = true
    desc.Parent = dialog
    
    -- 按钮区域
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, 0, 0, 40)
    buttonFrame.Position = UDim2.new(0, 0, 1, -50)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = dialog
    
    -- 取消按钮
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 80, 0, 30)
    cancelBtn.Position = UDim2.new(1, -90, 0, 5)
    cancelBtn.BackgroundColor3 = self.currentTheme.Border
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "取消"
    cancelBtn.TextColor3 = self.currentTheme.Text
    cancelBtn.TextSize = 12
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.Parent = buttonFrame
    
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 4)
    cancelCorner.Parent = cancelBtn
    
    -- 创建按钮
    local createBtn = Instance.new("TextButton")
    createBtn.Size = UDim2.new(0, 80, 0, 30)
    createBtn.Position = UDim2.new(1, -180, 0, 5)
    createBtn.BackgroundColor3 = self.currentTheme.Accent
    createBtn.BorderSizePixel = 0
    createBtn.Text = "创建"
    createBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    createBtn.TextSize = 12
    createBtn.Font = Enum.Font.Gotham
    createBtn.Parent = buttonFrame
    
    local createCorner = Instance.new("UICorner")
    createCorner.CornerRadius = UDim.new(0, 4)
    createCorner.Parent = createBtn
    
    -- 事件处理
    cancelBtn.MouseButton1Click:Connect(function()
        dialog:Destroy()
    end)
    
    createBtn.MouseButton1Click:Connect(function()
        self:CreateCapsule(capsuleTypeData.name, capsuleTypeData)
        dialog:Destroy()
        self:Notify({
            Title = "胶囊已创建",
            Message = "成功创建胶囊: " .. capsuleTypeData.name,
            Type = "Success",
            Duration = 3
        })
    end)
end

-- 创建胶囊
function Valkyrie:CreateCapsule(name, capsuleTypeData, config)
    config = config or {}
    
    -- 验证 capsuleTypeData
    if not capsuleTypeData then
        self:Notify({
            Title = "创建失败",
            Message = "胶囊类型数据无效",
            Type = "Error",
            Duration = 2
        })
        return nil
    end
    
    if not capsuleTypeData.type then
        self:Notify({
            Title = "创建失败", 
            Message = "胶囊类型缺少type字段",
            Type = "Error",
            Duration = 2
        })
        return nil
    end
    
    -- 检查名称重复
    if self.capsules[name] then
        self:Notify({
            Title = "创建失败",
            Message = "胶囊名称已存在",
            Type = "Error",
            Duration = 2
        })
        return nil
    end
    
    local capsule = {
        name = name,
        type = capsuleTypeData.type,
        typeData = capsuleTypeData,
        position = config.position or self:GetNextCapsulePosition()
    }
    
    -- 创建胶囊框架
    local frame = Instance.new("Frame")
    frame.Name = name .. "Capsule"
    frame.Size = config.size or self:GetCapsuleSize(capsuleTypeData)
    frame.Position = UDim2.new(0, capsule.position.X, 0, capsule.position.Y)
    frame.BackgroundColor3 = self.currentTheme.Secondary
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = self.ScreenGui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 20)
    frameCorner.Parent = frame
    
    -- 创建胶囊内容
    local content = self:CreateCapsuleContent(frame, capsuleTypeData, name, config)
    
    -- 使胶囊可拖拽
    self:MakeCapsuleDraggable(frame, capsule)
    
    capsule.frame = frame
    capsule.content = content
    self.capsules[name] = capsule
    
    -- 更新下一个位置
    self:UpdateNextCapsulePosition()
    
    -- 刷新胶囊列表
    self:RefreshCapsuleList()
    
    -- 保存配置
    self:SaveConfig()
    
    return capsule
end

-- 创建胶囊内容
function Valkyrie:CreateCapsuleContent(parent, capsuleTypeData, name, config)
    -- 安全检查
    if not capsuleTypeData then
        warn("CreateCapsuleContent: capsuleTypeData is nil")
        return nil
    end
    
    if not capsuleTypeData.type then
        warn("CreateCapsuleContent: capsuleTypeData.type is nil")
        return nil
    end
    
    if capsuleTypeData.type == "Button" then
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -10, 1, -10)
        button.Position = UDim2.new(0, 5, 0, 5)
        button.BackgroundColor3 = self.currentTheme.Accent
        button.BorderSizePixel = 0
        button.Text = config.text or name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.Font = Enum.Font.Gotham
        button.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 15)
        corner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            self:SafeExecute(function()
                if capsuleTypeData.functionality then
                    capsuleTypeData.functionality()
                end
            end, "按钮功能执行时出错")
        end)
        
        return button
        
    elseif capsuleTypeData.type == "Toggle" then
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(1, -10, 1, -10)
        toggleFrame.Position = UDim2.new(0, 5, 0, 5)
        toggleFrame.BackgroundTransparency = 1
        toggleFrame.Parent = parent
        
        local toggle = self:CreateToggle(toggleFrame, config.default or false, function(enabled)
            if capsuleTypeData.functionality then
                capsuleTypeData.functionality(enabled)
            end
        end)
        
        return toggle
        
    elseif capsuleTypeData.type == "Slider" then
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, -10, 1, -10)
        sliderFrame.Position = UDim2.new(0, 5, 0, 5)
        sliderFrame.BackgroundTransparency = 1
        sliderFrame.Parent = parent
        
        local slider = self:CreateSlider(sliderFrame, 
            capsuleTypeData.default or config.default or 50, 
            capsuleTypeData.min or config.min or 0, 
            capsuleTypeData.max or config.max or 100, 
            function(value)
                if capsuleTypeData.functionality then
                    capsuleTypeData.functionality(value)
                end
            end)
        
        return slider
        
    elseif capsuleTypeData.type == "Label" then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 1, -10)
        label.Position = UDim2.new(0, 5, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = config.text or name
        label.TextColor3 = self.currentTheme.Text
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.TextWrapped = true
        label.Parent = parent
        
        -- 如果是玩家信息标签，定期更新
        if capsuleTypeData.functionality then
            spawn(function()
                while label.Parent do
                    local success, result = pcall(capsuleTypeData.functionality)
                    if success and result then
                        label.Text = result
                    end
                    wait(1)
                end
            end)
        end
        
        return label
    end
    
    return nil
end

-- 获取胶囊尺寸
function Valkyrie:GetCapsuleSize(capsuleTypeData)
    if capsuleTypeData.type == "Button" then
        return UDim2.new(0, 120, 0, 35)
    elseif capsuleTypeData.type == "Toggle" then
        return UDim2.new(0, 80, 0, 35)
    elseif capsuleTypeData.type == "Slider" then
        return UDim2.new(0, 150, 0, 35)
    elseif capsuleTypeData.type == "Label" then
        return UDim2.new(0, 140, 0, 35)
    end
    return UDim2.new(0, 100, 0, 35)
end

-- 获取下一个胶囊位置
function Valkyrie:GetNextCapsulePosition()
    return self.nextCapsulePosition
end

-- 更新下一个胶囊位置
function Valkyrie:UpdateNextCapsulePosition()
    self.nextCapsulePosition = self.nextCapsulePosition + Vector2.new(30, 30)
    
    -- 如果超出屏幕边界，重置位置
    if self.nextCapsulePosition.X > 800 or self.nextCapsulePosition.Y > 500 then
        self.nextCapsulePosition = Vector2.new(100, 100)
    end
end

-- 使胶囊可拖拽
function Valkyrie:MakeCapsuleDraggable(frame, capsule)
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
            -- 删除互动通知，保存新位置
            if dragging then
                dragging = false
                -- 保存新位置
                capsule.position = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
                self:SaveConfig()
            end
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

-- 刷新胶囊列表
function Valkyrie:RefreshCapsuleList()
    if not self.CapsuleListSection then return end
    
    -- 清除现有列表项
    for _, child in pairs(self.CapsuleListSection:GetChildren()) do
        if child.Name:find("CapsuleItem") then
            child:Destroy()
        end
    end
    
    -- 添加胶囊列表项
    for name, capsule in pairs(self.capsules) do
        self:CreateRowItem(self.CapsuleListSection, name, {
            type = "button",
            text = "删除",
            callback = function()
                self:SafeExecute(function()
                    self:DeleteCapsule(name)
                end, "删除胶囊时出错")
            end
        }, capsule.typeData.name .. " - " .. capsule.typeData.desc)
    end
end

-- 删除胶囊
function Valkyrie:DeleteCapsule(name)
    local capsule = self.capsules[name]
    if capsule then
        if capsule.frame then
            capsule.frame:Destroy()
        end
        self.capsules[name] = nil
        self:RefreshCapsuleList()
        self:SaveConfig()
        self:Notify({
            Title = "胶囊已删除",
            Message = "胶囊 " .. name .. " 已被删除",
            Type = "Warning",
            Duration = 2
        })
    end
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

-- 通知系统
function Valkyrie:Notify(config)
    if not self.NotificationContainer then return end
    
    config = config or {}
    local title = config.Title or "通知"
    local message = config.Message or ""
    local type = config.Type or "Info"
    local duration = config.Duration or 3
    
    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.Size = UDim2.new(1, 0, 0, 70)
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
    titleLabel.Size = UDim2.new(1, -30, 0, 20)
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = notif
    
    -- 消息
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -30, 0, 30)
    messageLabel.Position = UDim2.new(0, 15, 0, 30)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = self.currentTheme.TextSecondary
    messageLabel.TextSize = 10
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextWrapped = true
    messageLabel.Parent = notif
    
    -- 关闭按钮
    local closeBtn = Instance.new("ImageButton")
    closeBtn.Size = UDim2.new(0, 16, 0, 16)
    closeBtn.Position = UDim2.new(1, -22, 0, 6)
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

-- 显示/隐藏主界面（淡入淡出）
function Valkyrie:Show()
    if not self.isVisible and self.MainFrame then
        self.isVisible = true
        self.MainFrame.Visible = true
        
        -- 淡入动画
        for _, obj in pairs(self.MainFrame:GetDescendants()) do
            if obj:IsA("GuiObject") then
                if obj.BackgroundTransparency < 1 then
                    obj.BackgroundTransparency = 1
                end
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    obj.TextTransparency = 1
                end
                if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    obj.ImageTransparency = 1
                end
            end
        end
        
        -- 开始淡入
        for _, obj in pairs(self.MainFrame:GetDescendants()) do
            if obj:IsA("GuiObject") then
                spawn(function()
                    if obj.BackgroundTransparency == 1 and obj ~= self.MainFrame then
                        local targetTransparency = 0
                        if obj.Name == "ContentFrame" then targetTransparency = 0
                        elseif obj.Parent and obj.Parent.Name == "ContentFrame" then targetTransparency = 1
                        end
                        
                        TweenService:Create(obj, TweenInfo.new(0.4), {BackgroundTransparency = targetTransparency}):Play()
                    end
                    
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                        TweenService:Create(obj, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
                    end
                    
                    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                        TweenService:Create(obj, TweenInfo.new(0.4), {ImageTransparency = 0}):Play()
                    end
                end)
            end
        end
        
        TweenService:Create(self.MainFrame, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()
        
        self:Notify({
            Title = "界面已打开",
            Message = "欢迎回到 Valkyrie UI",
            Type = "Success",
            Duration = 2
        })
    end
end

function Valkyrie:Hide()
    if self.isVisible and self.MainFrame then
        self.isVisible = false
        
        -- 淡出动画
        for _, obj in pairs(self.MainFrame:GetDescendants()) do
            if obj:IsA("GuiObject") then
                spawn(function()
                    TweenService:Create(obj, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
                    
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                        TweenService:Create(obj, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
                    end
                    
                    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                        TweenService:Create(obj, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
                    end
                end)
            end
        end
        
        local mainFade = TweenService:Create(self.MainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1})
        mainFade:Play()
        mainFade.Completed:Connect(function()
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

-- 更新主题
function Valkyrie:UpdateTheme()
    if not self.MainFrame then return end
    
    -- 更新主界面颜色
    self.MainFrame.BackgroundColor3 = self.currentTheme.Primary
    if self.TitleBar then self.TitleBar.BackgroundColor3 = self.currentTheme.Secondary end
    if self.SidebarFrame then self.SidebarFrame.BackgroundColor3 = self.currentTheme.Secondary end
    if self.ContentFrame then self.ContentFrame.BackgroundColor3 = self.currentTheme.Primary end
    if self.FloatingButton then self.FloatingButton.BackgroundColor3 = self.currentTheme.Accent end
    
    -- 更新所有标签页
    for _, tab in pairs(self.tabs) do
        if tab.button and tab.text and tab.icon then
            if tab.active then
                tab.button.BackgroundColor3 = self.currentTheme.Accent
                tab.text.TextColor3 = Color3.fromRGB(255, 255, 255)
                tab.icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            else
                tab.button.BackgroundColor3 = self.currentTheme.Primary
                tab.text.TextColor3 = self.currentTheme.TextSecondary
                tab.icon.ImageColor3 = self.currentTheme.TextSecondary
            end
        end
    end
    
    -- 更新胶囊
    for _, capsule in pairs(self.capsules) do
        if capsule.frame then
            capsule.frame.BackgroundColor3 = self.currentTheme.Secondary
        end
    end
end

-- 使主窗口可拖拽
function Valkyrie:MakeDraggable()
    if not self.TitleBar then return end
    
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
    if UserInputService.TouchEnabled and self.MainFrame then
        -- 调整主窗口大小和位置 (保持方形)
        self.MainFrame.Size = UDim2.new(0.85, 0, 0.6, 0)
        self.MainFrame.Position = UDim2.new(0.075, 0, 0.2, 0)
        
        -- 调整悬浮按钮
        if self.FloatingButton then
            self.FloatingButton.Size = UDim2.new(0, 65, 0, 65)
            self.FloatingButton.Position = UDim2.new(1, -80, 1, -80)
        end
    end
end

-- 安全执行函数
function Valkyrie:SafeExecute(func, errorMessage)
    local success, err = pcall(func)
    if not success then
        self:Notify({
            Title = "错误",
            Message = errorMessage or "操作执行失败",
            Type = "Error",
            Duration = 3
        })
        warn("Valkyrie UI Error: " .. tostring(err))
    end
end

-- 配置保存和加载
function Valkyrie:SaveConfig()
    local success, err = pcall(function()
        local config = {
            theme = self.currentTheme,
            floatingIcon = self.config.FloatingIcon,
            capsules = {}
        }
        
        -- 保存胶囊配置
        for name, capsule in pairs(self.capsules) do
            if capsule.typeData and capsule.typeData.name then
                config.capsules[name] = {
                    type = capsule.type,
                    typeName = capsule.typeData.name,
                    position = {
                        x = capsule.position and capsule.position.X or 100, 
                        y = capsule.position and capsule.position.Y or 100
                    }
                }
            end
        end
        
        local jsonConfig = HttpService:JSONEncode(config)
        
        -- 尝试保存到文件系统（如果支持）
        if writefile then
            if not isfolder(CONFIG_FOLDER) then
                makefolder(CONFIG_FOLDER)
            end
            writefile(CONFIG_FOLDER .. "/" .. CONFIG_FILE, jsonConfig)
        end
    end)
    
    if not success then
        self:Notify({
            Title = "保存失败",
            Message = "配置保存时出错: " .. tostring(err),
            Type = "Error",
            Duration = 2
        })
    end
end

function Valkyrie:LoadConfig()
    local success, err = pcall(function()
        if readfile and isfile(CONFIG_FOLDER .. "/" .. CONFIG_FILE) then
            local jsonConfig = readfile(CONFIG_FOLDER .. "/" .. CONFIG_FILE)
            local config = HttpService:JSONDecode(jsonConfig)
            
            if config then
                -- 加载主题
                if config.theme then
                    self.currentTheme = config.theme
                end
                
                -- 加载悬浮按钮图标
                if config.floatingIcon then
                    self.config.FloatingIcon = config.floatingIcon
                end
                
                -- 稍后加载胶囊（在UI创建完成后）
                self.savedCapsulesConfig = config.capsules
            end
        end
    end)
    
    if not success then
        -- 使用默认配置
        self.currentTheme = table.clone(DefaultTheme)
    end
end

-- 加载保存的胶囊
function Valkyrie:LoadSavedCapsules()
    if self.savedCapsulesConfig then
        for name, config in pairs(self.savedCapsulesConfig) do
            spawn(function()
                wait(0.1)
                -- 查找对应的胶囊类型数据
                local capsuleTypeData = nil
                for _, typeData in ipairs(CapsuleTypes) do
                    if typeData.name == config.typeName then
                        capsuleTypeData = typeData
                        break
                    end
                end
                
                if capsuleTypeData then
                    self:CreateCapsule(name, capsuleTypeData, {
                        position = Vector2.new(config.position.x, config.position.y)
                    })
                else
                    warn("Cannot find capsule type: " .. tostring(config.typeName))
                end
            end)
        end
        self.savedCapsulesConfig = nil
    end
end


-- 销毁UI
function Valkyrie:Destroy()
    self:SafeExecute(function()
        -- 销毁所有胶囊
        for _, capsule in pairs(self.capsules) do
            if capsule.frame then
                capsule.frame:Destroy()
            end
        end
        
        -- 销毁主UI
        if self.ScreenGui then
            self.ScreenGui:Destroy()
        end
        
        -- 清理引用
        self.tabs = {}
        self.capsules = {}
        self.notifications = {}
        
        -- 清除单例
        Valkyrie.instance = nil
    end, "销毁UI时出错")
end

-- 初始化完成后的回调
spawn(function()
    repeat wait(0.1) until Valkyrie.instance and Valkyrie.instance.isInitialized
    
    -- 加载保存的胶囊
    Valkyrie.instance:LoadSavedCapsules()
    
    -- 显示启动完成通知
    wait(0.5)
    Valkyrie.instance:Notify({
        Title = "Valkyrie UI v2.0",
        Message = "初始化完成，所有功能已就绪！",
        Type = "Success",
        Duration = 3
    })
end)

return Valkyrie