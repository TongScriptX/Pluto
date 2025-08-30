-- Valkyrie UI Library v2.0 - 优化版 (无背景色修改版)
-- 简约、精致、高级的用户界面设计
-- 修改说明: 移除了大部分元素的默认灰色背景 (BackgroundColor3)，使其更透明或使用主题背景色。
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Valkyrie = {}
Valkyrie.__index = Valkyrie
Valkyrie.instance = nil
-- 配置文件
local CONFIG_FOLDER = "ValkyrieUI"
local CONFIG_FILE = "config.json"
-- 精致的现代化主题
local DefaultTheme = {
    Primary = Color3.fromRGB(18, 18, 22),
    Secondary = Color3.fromRGB(24, 24, 28),
    Accent = Color3.fromRGB(99, 102, 241),
    AccentHover = Color3.fromRGB(129, 132, 251),
    Text = Color3.fromRGB(248, 250, 252),
    TextSecondary = Color3.fromRGB(148, 163, 184),
    Border = Color3.fromRGB(39, 39, 42),
    Success = Color3.fromRGB(34, 197, 94),
    Warning = Color3.fromRGB(245, 158, 11),
    Error = Color3.fromRGB(239, 68, 68),
    Background = Color3.fromRGB(15, 15, 18), -- 新增背景色用于需要轻微区分的区域
    Surface = Color3.fromRGB(30, 31, 38)
}
-- 简化的图标系统
local Icons = {
    Home = "rbxassetid://7072707318",
    Settings = "rbxassetid://7072719338",
    Palette = "rbxassetid://7072717972",
    Close = "rbxassetid://7072725342",
    Add = "rbxassetid://7072717281",
    Delete = "rbxassetid://7072725463",
    Check = "rbxassetid://7072706796",
    Valkyrie = "rbxassetid://7072719594"
}
-- 精简的胶囊类型
local CapsuleTypes = {
    {
        name = "飞行模式",
        type = "Toggle",
        desc = "启用飞行功能",
        functionality = function(enabled)
            local player = Players.LocalPlayer
            if player and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    if enabled then
                        local bodyVelocity = Instance.new("BodyVelocity")
                        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                        bodyVelocity.Parent = player.Character.HumanoidRootPart
                        player.Character:SetAttribute("Flying", true)
                        player.Character:SetAttribute("BodyVelocity", bodyVelocity)
                    else
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
        name = "移动速度",
        type = "Slider",
        desc = "调节行走速度",
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
        name = "跳跃增强",
        type = "Slider",
        desc = "调节跳跃力度",
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
        name = "回到出生点",
        type = "Button",
        desc = "快速传送到出生位置",
        functionality = function()
            local player = Players.LocalPlayer
            if player and player.Character then
                local spawnLocation = workspace:FindFirstChild("SpawnLocation")
                if spawnLocation then
                    player.Character:MoveTo(spawnLocation.Position + Vector3.new(0, 5, 0))
                end
            end
        end
    }
}
-- 创建实例
function Valkyrie.new(config)
    if Valkyrie.instance then
        Valkyrie.instance:Destroy()
    end
    local self = setmetatable({}, Valkyrie)
    Valkyrie.instance = self
    self.config = config or {}
    self.config.Title = self.config.Title or "Valkyrie"
    self.config.FloatingIcon = self.config.FloatingIcon or Icons.Valkyrie
    self.config.Size = self.config.Size or UDim2.new(0, 420, 0, 380)
    self.config.Position = self.config.Position or UDim2.new(0.5, -210, 0.5, -190)
    self.isVisible = false
    self.isInitialized = false
    -- 主题初始化
    self.currentTheme = {}
    for k, v in pairs(DefaultTheme) do
        self.currentTheme[k] = v
    end
    self.tabs = {}
    self.capsules = {}
    self.notifications = {}
    self.nextCapsulePosition = Vector2.new(100, 100)
    self:LoadConfig()
    self:ShowStartupAnimation()
    return self
end
-- 启动动画
function Valkyrie:ShowStartupAnimation()
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
    logoImage.Size = UDim2.new(0, 80, 0, 80)
    logoImage.Position = UDim2.new(0.5, -40, 0.5, -60)
    logoImage.BackgroundTransparency = 1
    logoImage.Image = self.config.FloatingIcon
    logoImage.ImageTransparency = 1
    logoImage.Parent = startupFrame
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0, 200, 0, 40)
    titleLabel.Position = UDim2.new(0.5, -100, 0.5, 20)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Valkyrie"
    titleLabel.TextColor3 = Color3.fromRGB(248, 250, 252)
    titleLabel.TextSize = 28
    titleLabel.TextTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = startupFrame
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Size = UDim2.new(0, 200, 0, 20)
    subtitleLabel.Position = UDim2.new(0.5, -100, 0.5, 55)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Text = "Premium UI Library"
    subtitleLabel.TextColor3 = Color3.fromRGB(148, 163, 184)
    subtitleLabel.TextSize = 14
    subtitleLabel.TextTransparency = 1
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.Parent = startupFrame
    spawn(function()
        TweenService:Create(logoImage, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {ImageTransparency = 0}):Play()
        wait(0.2)
        TweenService:Create(titleLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {TextTransparency = 0}):Play()
        wait(0.1)
        TweenService:Create(subtitleLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {TextTransparency = 0}):Play()
        wait(1.8)
        local fadeOut1 = TweenService:Create(logoImage, TweenInfo.new(0.4), {ImageTransparency = 1})
        local fadeOut2 = TweenService:Create(titleLabel, TweenInfo.new(0.4), {TextTransparency = 1})
        local fadeOut3 = TweenService:Create(subtitleLabel, TweenInfo.new(0.4), {TextTransparency = 1})
        local fadeOut4 = TweenService:Create(startupFrame, TweenInfo.new(0.4), {BackgroundTransparency = 1})
        fadeOut1:Play()
        fadeOut2:Play()
        fadeOut3:Play()
        fadeOut4:Play()
        fadeOut4.Completed:Connect(function()
            startupGui:Destroy()
            self:CreateMainUI()
            self:CreateFloatingButton()
            self.isInitialized = true
        end)
    end)
end
-- 创建主界面
function Valkyrie:CreateMainUI()
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "ValkyrieUI"
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.ScreenGui.Parent = CoreGui
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "MainFrame"
    self.MainFrame.Size = self.config.Size
    self.MainFrame.Position = self.config.Position
    self.MainFrame.BackgroundColor3 = self.currentTheme.Primary
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Visible = false
    self.MainFrame.Active = true
    self.MainFrame.Parent = self.ScreenGui
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "DropShadow"
    shadow.Size = UDim2.new(1, 16, 1, 16)
    shadow.Position = UDim2.new(0, -8, 0, -8)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.8
    shadow.ZIndex = -1
    shadow.Parent = self.MainFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = self.MainFrame
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 16)
    shadowCorner.Parent = shadow
    self:CreateTitleBar()
    self:CreateContentArea()
    self:CreateNotificationSystem()
    self:MakeDraggable()
    self:AdaptForMobile()
    self:AddTab("主页", Icons.Home, true)
    self:AddTab("功能", Icons.Settings)
    self:AddTab("主题", Icons.Palette)
end
-- 创建标题栏
function Valkyrie:CreateTitleBar()
    self.TitleBar = Instance.new("Frame")
    self.TitleBar.Name = "TitleBar"
    self.TitleBar.Size = UDim2.new(1, 0, 0, 50)
    self.TitleBar.Position = UDim2.new(0, 0, 0, 0)
    self.TitleBar.BackgroundTransparency = 1
    self.TitleBar.BorderSizePixel = 0
    self.TitleBar.Parent = self.MainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 24, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = self.config.Title
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 20
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = self.TitleBar

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 32, 0, 32)
    closeButton.Position = UDim2.new(1, -44, 0, 9)
    -- 确保 BackgroundColor3 始终有一个 Color3 值
    -- 如果 self.currentTheme.Background 是 nil，则使用一个默认的深色或透明色
    closeButton.BackgroundColor3 = self.currentTheme.Background or self.currentTheme.Surface or Color3.fromRGB(30, 31, 38) -- 添加后备选项
    closeButton.BackgroundTransparency = 0.8 -- 使用透明度
    -- closeButton.BackgroundColor3 = self.currentTheme.Surface -- 可以选择保留这行作为后备，如果 Background 不够好
    closeButton.BorderSizePixel = 0
    closeButton.Text = "×"
    closeButton.TextColor3 = self.currentTheme.Text
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = self.TitleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton

    closeButton.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            self:Notify("已关闭", "UI 已完全销毁", "warning")
            wait(0.5)
            self:Destroy()
        end, "关闭UI时出错")
    end)

    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {
            BackgroundColor3 = self.currentTheme.Error,
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    end)

    closeButton.MouseLeave:Connect(function()
        -- 同样确保恢复时也有默认值
        TweenService:Create(closeButton, TweenInfo.new(0.2), {
            BackgroundColor3 = self.currentTheme.Background or self.currentTheme.Surface or Color3.fromRGB(30, 31, 38),
            TextColor3 = self.currentTheme.Text
        }):Play()
    end)
end

-- 创建内容区域
function Valkyrie:CreateContentArea()
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(1, -32, 0, 1)
    separator.Position = UDim2.new(0, 16, 0, 49)
    separator.BackgroundColor3 = self.currentTheme.Border
    separator.BorderSizePixel = 0
    separator.Parent = self.MainFrame
    self.SidebarFrame = Instance.new("Frame")
    self.SidebarFrame.Name = "SidebarFrame"
    self.SidebarFrame.Size = UDim2.new(0, 120, 1, -65)
    self.SidebarFrame.Position = UDim2.new(0, 16, 0, 58)
    self.SidebarFrame.BackgroundTransparency = 1 -- 透明背景
    self.SidebarFrame.BorderSizePixel = 0
    self.SidebarFrame.Parent = self.MainFrame
    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.FillDirection = Enum.FillDirection.Vertical
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.Parent = self.SidebarFrame
    local sidebarSeparator = Instance.new("Frame")
    sidebarSeparator.Size = UDim2.new(0, 1, 1, 0)
    sidebarSeparator.Position = UDim2.new(0, 140, 0, 0)
    sidebarSeparator.BackgroundColor3 = self.currentTheme.Border
    sidebarSeparator.BorderSizePixel = 0
    sidebarSeparator.Parent = self.SidebarFrame
    self.ContentFrame = Instance.new("ScrollingFrame")
    self.ContentFrame.Name = "ContentFrame"
    self.ContentFrame.Size = UDim2.new(1, -160, 1, -65)
    self.ContentFrame.Position = UDim2.new(0, 148, 0, 58)
    self.ContentFrame.BackgroundTransparency = 1 -- 透明背景
    self.ContentFrame.BorderSizePixel = 0
    self.ContentFrame.ScrollBarThickness = 4
    self.ContentFrame.ScrollBarImageColor3 = self.currentTheme.Accent
    self.ContentFrame.ScrollBarImageTransparency = 0.5
    self.ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    self.ContentFrame.Parent = self.MainFrame
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 16)
    contentLayout.Parent = self.ContentFrame
    local contentPadding = Instance.new("UIPadding")
    contentPadding.PaddingTop = UDim.new(0, 16)
    contentPadding.PaddingBottom = UDim.new(0, 16)
    contentPadding.PaddingLeft = UDim.new(0, 16)
    contentPadding.PaddingRight = UDim.new(0, 16)
    contentPadding.Parent = self.ContentFrame
    contentLayout.Changed:Connect(function()
        self.ContentFrame.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 32)
    end)
end
-- 创建悬浮按钮
function Valkyrie:CreateFloatingButton()
    self.FloatingButton = Instance.new("ImageButton")
    self.FloatingButton.Name = "FloatingButton"
    self.FloatingButton.Size = UDim2.new(0, 56, 0, 56)
    self.FloatingButton.Position = UDim2.new(1, -76, 1, -76)
    self.FloatingButton.BackgroundColor3 = self.currentTheme.Accent
    self.FloatingButton.BorderSizePixel = 0
    self.FloatingButton.Image = self.config.FloatingIcon
    self.FloatingButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    self.FloatingButton.Active = true
    self.FloatingButton.Parent = self.ScreenGui
    local floatCorner = Instance.new("UICorner")
    floatCorner.CornerRadius = UDim.new(0, 28)
    floatCorner.Parent = self.FloatingButton
    local floatShadow = Instance.new("ImageLabel")
    floatShadow.Size = UDim2.new(1, 8, 1, 8)
    floatShadow.Position = UDim2.new(0, -4, 0, -4)
    floatShadow.BackgroundTransparency = 1
    floatShadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    floatShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    floatShadow.ImageTransparency = 0.7
    floatShadow.ZIndex = -1
    floatShadow.Parent = self.FloatingButton
    local floatShadowCorner = Instance.new("UICorner")
    floatShadowCorner.CornerRadius = UDim.new(0, 28)
    floatShadowCorner.Parent = floatShadow
    self:MakeFloatingButtonDraggable()
    self.FloatingButton.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            self:Toggle()
        end, "切换UI显示时出错")
    end)
    self.FloatingButton.MouseEnter:Connect(function()
        TweenService:Create(self.FloatingButton, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = self.currentTheme.AccentHover,
            Size = UDim2.new(0, 60, 0, 60)
        }):Play()
    end)
    self.FloatingButton.MouseLeave:Connect(function()
        TweenService:Create(self.FloatingButton, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundColor3 = self.currentTheme.Accent,
            Size = UDim2.new(0, 56, 0, 56)
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
    tabButton.Size = UDim2.new(1, 0, 0, 36)
    -- tabButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0, 0) -- 移除
    tabButton.BackgroundTransparency = 1 -- 透明背景
    tabButton.BorderSizePixel = 0
    tabButton.Text = ""
    tabButton.LayoutOrder = #self.tabs + 1
    tabButton.Parent = self.SidebarFrame
    local iconLabel = Instance.new("ImageLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(0, 16, 0, 16)
    iconLabel.Position = UDim2.new(0, 8, 0.5, -8)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Image = icon
    iconLabel.ImageColor3 = self.currentTheme.TextSecondary
    iconLabel.Parent = tabButton
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Text"
    textLabel.Size = UDim2.new(1, -32, 1, 0)
    textLabel.Position = UDim2.new(0, 28, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = name
    textLabel.TextColor3 = self.currentTheme.TextSecondary
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Font = Enum.Font.GothamMedium
    textLabel.Parent = tabButton
    local tabContent = Instance.new("Frame")
    tabContent.Name = name .. "Content"
    tabContent.Size = UDim2.new(1, 0, 1, 0)
    tabContent.BackgroundTransparency = 1 -- 透明背景
    tabContent.BorderSizePixel = 0
    tabContent.Visible = false
    tabContent.Parent = self.ContentFrame
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.FillDirection = Enum.FillDirection.Vertical
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 12)
    contentLayout.Parent = tabContent
    tabButton.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            self:SwitchTab(name)
        end, "切换标签页时出错")
    end)
    tabButton.MouseEnter:Connect(function()
        if not self.tabs[name] or not self.tabs[name].active then
            -- TweenService:Create(tabButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(255, 255, 255, 8)}):Play()
            TweenService:Create(tabButton, TweenInfo.new(0.15), {BackgroundTransparency = 0.95}):Play() -- 使用透明度
            TweenService:Create(iconLabel, TweenInfo.new(0.15), {ImageColor3 = self.currentTheme.Text}):Play()
            TweenService:Create(textLabel, TweenInfo.new(0.15), {TextColor3 = self.currentTheme.Text}):Play()
        end
    end)
    tabButton.MouseLeave:Connect(function()
        if not self.tabs[name] or not self.tabs[name].active then
            -- TweenService:Create(tabButton, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
            TweenService:Create(tabButton, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() -- 保持透明
            TweenService:Create(iconLabel, TweenInfo.new(0.15), {ImageColor3 = self.currentTheme.TextSecondary}):Play()
            TweenService:Create(textLabel, TweenInfo.new(0.15), {TextColor3 = self.currentTheme.TextSecondary}):Play()
        end
    end)
    self.tabs[name] = {
        button = tabButton,
        content = tabContent,
        icon = iconLabel,
        text = textLabel,
        active = false
    }
    self:CreateTabContent(name, tabContent)
    if defaultSelected or #self.tabs == 1 then
        spawn(function()
            wait(0.1)
            self:SwitchTab(name)
        end)
    end
    return tabContent
end
-- 切换标签页
function Valkyrie:SwitchTab(tabName)
    for name, tab in pairs(self.tabs) do
        if tab and tab.content and tab.button and tab.text and tab.icon then
            local isActive = name == tabName
            tab.content.Visible = isActive
            tab.active = isActive
            if isActive then
                -- TweenService:Create(tab.button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(99, 102, 241, 20)}):Play()
                TweenService:Create(tab.button, TweenInfo.new(0.2), {BackgroundTransparency = 0.92}):Play() -- 使用透明度
                TweenService:Create(tab.text, TweenInfo.new(0.2), {TextColor3 = self.currentTheme.Accent}):Play()
                TweenService:Create(tab.icon, TweenInfo.new(0.2), {ImageColor3 = self.currentTheme.Accent}):Play()
            else
                -- TweenService:Create(tab.button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                TweenService:Create(tab.button, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play() -- 保持透明
                TweenService:Create(tab.text, TweenInfo.new(0.2), {TextColor3 = self.currentTheme.TextSecondary}):Play()
                TweenService:Create(tab.icon, TweenInfo.new(0.2), {ImageColor3 = self.currentTheme.TextSecondary}):Play()
            end
        end
    end
end
-- 创建标签页内容
function Valkyrie:CreateTabContent(name, container)
    if name == "主页" then
        self:CreateHomeContent(container)
    elseif name == "功能" then
        self:CreateFunctionContent(container)
    elseif name == "主题" then
        self:CreateThemeContent(container)
    end
end
-- 创建主页内容
function Valkyrie:CreateHomeContent(container)
    local welcomeSection = self:CreateSection(container, "欢迎使用 Valkyrie")
    self:CreateLabel(welcomeSection, "🚀 现代化的用户界面设计")
    self:CreateLabel(welcomeSection, "⚡ 流畅的动画和交互体验")
    self:CreateLabel(welcomeSection, "🎨 完全可自定义的主题系统")
    self:CreateLabel(welcomeSection, "📱 完美适配移动端设备")
    local quickSection = self:CreateSection(container, "快速操作")
    self:CreateButton(quickSection, "创建新功能", function()
        self:SwitchTab("功能")
        self:Notify("已跳转", "切换到功能管理页面", "success")
    end)
    self:CreateButton(quickSection, "自定义主题", function()
        self:SwitchTab("主题")
        self:Notify("已跳转", "切换到主题设置页面", "success")
    end)
end
-- 创建功能内容
function Valkyrie:CreateFunctionContent(container)
    local createSection = self:CreateSection(container, "创建新功能")
    for _, capsuleType in ipairs(CapsuleTypes) do
        local item = self:CreateItem(createSection, capsuleType.name, capsuleType.desc)
        local createBtn = Instance.new("TextButton")
        createBtn.Size = UDim2.new(0, 60, 0, 28)
        createBtn.Position = UDim2.new(1, -64, 0.5, -14)
        createBtn.BackgroundColor3 = self.currentTheme.Accent
        createBtn.BorderSizePixel = 0
        createBtn.Text = "创建"
        createBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        createBtn.TextSize = 12
        createBtn.Font = Enum.Font.GothamMedium
        createBtn.Parent = item
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = createBtn
        createBtn.MouseButton1Click:Connect(function()
            self:SafeExecute(function()
                self:CreateCapsule(capsuleType.name, capsuleType)
                self:Notify("创建成功", "功能胶囊已创建", "success")
            end, "创建胶囊时出错")
        end)
        createBtn.MouseEnter:Connect(function()
            TweenService:Create(createBtn, TweenInfo.new(0.15), {BackgroundColor3 = self.currentTheme.AccentHover}):Play()
        end)
        createBtn.MouseLeave:Connect(function()
            TweenService:Create(createBtn, TweenInfo.new(0.15), {BackgroundColor3 = self.currentTheme.Accent}):Play()
        end)
    end
    self.CapsuleListSection = self:CreateSection(container, "已创建的功能")
    self:RefreshCapsuleList()
end
-- 创建主题内容
function Valkyrie:CreateThemeContent(container)
    local colorSection = self:CreateSection(container, "颜色配置")
    self:CreateColorItem(colorSection, "主色调", self.currentTheme.Accent, function(color)
        self:SafeExecute(function()
            self.currentTheme.Accent = color
            self.currentTheme.AccentHover = Color3.fromRGB(
                math.min(255, color.R * 255 + 30),
                math.min(255, color.G * 255 + 30),
                math.min(255, color.B * 255 + 30)
            )
            self:UpdateTheme()
            self:SaveConfig()
        end, "更新主色调时出错")
    end)
    self:CreateColorItem(colorSection, "背景色", self.currentTheme.Primary, function(color)
        self:SafeExecute(function()
            self.currentTheme.Primary = color
            self:UpdateTheme()
            self:SaveConfig()
        end, "更新背景色时出错")
    end)
    local actionSection = self:CreateSection(container, "主题管理")
    self:CreateButton(actionSection, "重置为默认主题", function()
        self:SafeExecute(function()
            for k, v in pairs(DefaultTheme) do
                self.currentTheme[k] = v
            end
            self:UpdateTheme()
            self:SaveConfig()
            self:Notify("重置完成", "主题已恢复默认设置", "success")
        end, "重置主题时出错")
    end)
    local iconItem = self:CreateItem(actionSection, "悬浮按钮图标", "输入 Roblox 资产 ID")
    local iconInput = Instance.new("TextBox")
    iconInput.Size = UDim2.new(0, 120, 0, 28)
    iconInput.Position = UDim2.new(1, -124, 0.5, -14)
    -- iconInput.BackgroundColor3 = self.currentTheme.Surface -- 移除
    iconInput.BackgroundTransparency = 0.8 -- 使用透明度
    iconInput.BackgroundColor3 = self.currentTheme.Background -- 或使用主题背景色
    iconInput.BorderSizePixel = 0
    iconInput.PlaceholderText = "资产 ID"
    iconInput.Text = ""
    iconInput.TextColor3 = self.currentTheme.Text
    iconInput.TextSize = 12
    iconInput.Font = Enum.Font.Gotham
    iconInput.Parent = iconItem
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = iconInput
    iconInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and iconInput.Text ~= "" then
            self:SafeExecute(function()
                local assetId = "rbxassetid://" .. iconInput.Text
                self.config.FloatingIcon = assetId
                if self.FloatingButton then
                    self.FloatingButton.Image = assetId
                end
                self:SaveConfig()
                self:Notify("图标已更新", "悬浮按钮图标更新成功", "success")
            end, "更新图标时出错")
        end
    end)
end
-- 创建区块
function Valkyrie:CreateSection(parent, title)
    local section = Instance.new("Frame")
    section.Name = title
    section.BackgroundColor3 = self.currentTheme.Secondary
    section.BorderSizePixel = 0
    section.LayoutOrder = #parent:GetChildren()
    section.Parent = parent
    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 12)
    sectionCorner.Parent = section
    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.FillDirection = Enum.FillDirection.Vertical
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Padding = UDim.new(0, 8)
    sectionLayout.Parent = section
    local sectionPadding = Instance.new("UIPadding")
    sectionPadding.PaddingTop = UDim.new(0, 16)
    sectionPadding.PaddingBottom = UDim.new(0, 16)
    sectionPadding.PaddingLeft = UDim.new(0, 16)
    sectionPadding.PaddingRight = UDim.new(0, 16)
    sectionPadding.Parent = section
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.LayoutOrder = 1
    titleLabel.Parent = section
    sectionLayout.Changed:Connect(function()
        local totalHeight = sectionLayout.AbsoluteContentSize.Y + 32
        if totalHeight > 0 then
            section.Size = UDim2.new(1, 0, 0, totalHeight)
        end
    end)
    return section
end
-- 创建项目
function Valkyrie:CreateItem(parent, name, description)
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, description and 56 or 40)
    item.BackgroundTransparency = 1 -- 透明背景
    item.LayoutOrder = #parent:GetChildren()
    item.Parent = parent
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -80, 0, 18)
    nameLabel.Position = UDim2.new(0, 0, 0, 2)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = self.currentTheme.Text
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.GothamMedium
    nameLabel.Parent = item
    if description then
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -80, 0, 14)
        descLabel.Position = UDim2.new(0, 0, 0, 22)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = description
        descLabel.TextColor3 = self.currentTheme.TextSecondary
        descLabel.TextSize = 12
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextWrapped = true
        descLabel.Parent = item
    end
    return item
end
-- 创建标签
function Valkyrie:CreateLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = self.currentTheme.TextSecondary
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.LayoutOrder = #parent:GetChildren()
    label.Parent = parent
    return label
end
-- 创建按钮
function Valkyrie:CreateButton(parent, text, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = self.currentTheme.Accent
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.Font = Enum.Font.GothamMedium
    button.LayoutOrder = #parent:GetChildren()
    button.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    if callback then
        button.MouseButton1Click:Connect(callback)
    end
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundColor3 = self.currentTheme.AccentHover,
            Size = UDim2.new(1, 0, 0, 38)
        }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.15), {
            BackgroundColor3 = self.currentTheme.Accent,
            Size = UDim2.new(1, 0, 0, 36)
        }):Play()
    end)
    return button
end
-- 创建颜色选择项
function Valkyrie:CreateColorItem(parent, name, defaultColor, callback)
    local item = self:CreateItem(parent, name, "点击预览色块来调整颜色")
    local colorPreview = Instance.new("TextButton")
    colorPreview.Size = UDim2.new(0, 32, 0, 32)
    colorPreview.Position = UDim2.new(1, -36, 0.5, -16)
    colorPreview.BackgroundColor3 = defaultColor
    colorPreview.BorderSizePixel = 1
    colorPreview.BorderColor3 = self.currentTheme.Border
    colorPreview.Text = ""
    colorPreview.Parent = item
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 6)
    previewCorner.Parent = colorPreview
    colorPreview.MouseButton1Click:Connect(function()
        self:ShowColorPicker(defaultColor, function(color)
            colorPreview.BackgroundColor3 = color
            if callback then
                callback(color)
            end
        end)
    end)
    return item
end
-- 显示颜色选择器
function Valkyrie:ShowColorPicker(currentColor, callback)
    local picker = Instance.new("Frame")
    picker.Size = UDim2.new(0, 280, 0, 200)
    picker.Position = UDim2.new(0.5, -140, 0.5, -100)
    picker.BackgroundColor3 = self.currentTheme.Primary
    picker.BorderSizePixel = 0
    picker.Parent = self.ScreenGui
    local pickerCorner = Instance.new("UICorner")
    pickerCorner.CornerRadius = UDim.new(0, 12)
    pickerCorner.Parent = picker
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "颜色选择器"
    title.TextColor3 = self.currentTheme.Text
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = picker
    local colorFrame = Instance.new("Frame")
    colorFrame.Size = UDim2.new(1, -32, 0, 100)
    colorFrame.Position = UDim2.new(0, 16, 0, 50)
    colorFrame.BackgroundTransparency = 1
    colorFrame.Parent = picker
    local rgbValues = {currentColor.R * 255, currentColor.G * 255, currentColor.B * 255}
    local colors = {"红", "绿", "蓝"}
    for i = 1, 3 do
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, 0, 0, 28)
        sliderFrame.Position = UDim2.new(0, 0, 0, (i-1) * 32)
        sliderFrame.BackgroundTransparency = 1
        sliderFrame.Parent = colorFrame
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 20, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = colors[i]
        label.TextColor3 = self.currentTheme.Text
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.Parent = sliderFrame
        local slider = self:CreateSlider(sliderFrame, rgbValues[i], 0, 255, function(value)
            rgbValues[i] = value
            local newColor = Color3.fromRGB(rgbValues[1], rgbValues[2], rgbValues[3])
            if callback then
                callback(newColor)
            end
        end)
        slider.frame.Size = UDim2.new(1, -60, 1, 0)
        slider.frame.Position = UDim2.new(0, 30, 0, 0)
    end
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 60, 0, 30)
    closeBtn.Position = UDim2.new(1, -76, 1, -42)
    -- closeBtn.BackgroundColor3 = self.currentTheme.Surface -- 移除
    closeBtn.BackgroundTransparency = 0.8 -- 使用透明度
    closeBtn.BackgroundColor3 = self.currentTheme.Background -- 或使用主题背景色
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "完成"
    closeBtn.TextColor3 = self.currentTheme.Text
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.Parent = picker
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        picker:Destroy()
    end)
end
-- 创建开关
function Valkyrie:CreateToggle(parent, default, callback)
    local toggle = {enabled = default or false}
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 44, 0, 24)
    frame.BackgroundTransparency = 1 -- 透明背景
    frame.Parent = parent
    local switchFrame = Instance.new("Frame")
    switchFrame.Size = UDim2.new(1, 0, 1, 0)
    switchFrame.BackgroundColor3 = toggle.enabled and self.currentTheme.Accent or self.currentTheme.Border
    switchFrame.BorderSizePixel = 0
    switchFrame.Parent = frame
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 12)
    switchCorner.Parent = switchFrame
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 20, 0, 20)
    thumb.Position = toggle.enabled and UDim2.new(1, -22, 0, 2) or UDim2.new(0, 2, 0, 2)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.Parent = switchFrame
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 10)
    thumbCorner.Parent = thumb
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = switchFrame
    button.MouseButton1Click:Connect(function()
        self:SafeExecute(function()
            toggle.enabled = not toggle.enabled
            local targetPos = toggle.enabled and UDim2.new(1, -22, 0, 2) or UDim2.new(0, 2, 0, 2)
            local targetColor = toggle.enabled and self.currentTheme.Accent or self.currentTheme.Border
            TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Position = targetPos}):Play()
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
    frame.BackgroundTransparency = 1 -- 透明背景
    frame.Parent = parent
    local valueBox = Instance.new("TextLabel")
    valueBox.Size = UDim2.new(0, 40, 0, 20)
    valueBox.Position = UDim2.new(1, -40, 0, 0)
    -- valueBox.BackgroundColor3 = self.currentTheme.Surface -- 移除
    valueBox.BackgroundTransparency = 0.8 -- 使用透明度
    valueBox.BackgroundColor3 = self.currentTheme.Background -- 或使用主题背景色
    valueBox.BorderSizePixel = 0
    valueBox.Text = tostring(math.floor(slider.value))
    valueBox.TextColor3 = self.currentTheme.Text
    valueBox.TextSize = 11
    valueBox.Font = Enum.Font.GothamMedium
    valueBox.Parent = frame
    local valueCorner = Instance.new("UICorner")
    valueCorner.CornerRadius = UDim.new(0, 4)
    valueCorner.Parent = valueBox
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -50, 0, 4)
    track.Position = UDim2.new(0, 0, 0.5, -2)
    track.BackgroundColor3 = self.currentTheme.Border
    track.BorderSizePixel = 0
    track.Parent = frame
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(0, 2)
    trackCorner.Parent = track
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((slider.value - slider.min) / (slider.max - slider.min), 0, 1, 0)
    fill.BackgroundColor3 = self.currentTheme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 2)
    fillCorner.Parent = fill
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = UDim2.new((slider.value - slider.min) / (slider.max - slider.min), -8, 0.5, -8)
    thumb.BackgroundColor3 = self.currentTheme.Accent
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(0, 8)
    thumbCorner.Parent = thumb
    local function updateSlider(newValue)
        newValue = math.clamp(newValue, slider.min, slider.max)
        slider.value = newValue
        local relativeX = (newValue - slider.min) / (slider.max - slider.min)
        thumb.Position = UDim2.new(relativeX, -8, 0.5, -8)
        fill.Size = UDim2.new(relativeX, 0, 1, 0)
        valueBox.Text = tostring(math.floor(newValue))
        if callback then
            callback(newValue)
        end
    end
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
    slider.frame = frame
    slider.update = updateSlider
    return slider
end
-- 创建胶囊
function Valkyrie:CreateCapsule(name, capsuleTypeData, config)
    config = config or {}
    if not capsuleTypeData or not capsuleTypeData.type then
        self:Notify("创建失败", "胶囊类型数据无效", "error")
        return nil
    end
    if self.capsules[name] then
        self:Notify("创建失败", "胶囊名称已存在", "error")
        return nil
    end
    local capsule = {
        name = name,
        type = capsuleTypeData.type,
        typeData = capsuleTypeData,
        position = config.position or self:GetNextCapsulePosition()
    }
    local frame = Instance.new("Frame")
    frame.Name = name .. "Capsule"
    frame.Size = config.size or self:GetCapsuleSize(capsuleTypeData)
    frame.Position = UDim2.new(0, capsule.position.X, 0, capsule.position.Y)
    frame.BackgroundColor3 = self.currentTheme.Secondary
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = self.ScreenGui
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 18)
    frameCorner.Parent = frame
    local frameShadow = Instance.new("ImageLabel")
    frameShadow.Size = UDim2.new(1, 8, 1, 8)
    frameShadow.Position = UDim2.new(0, -4, 0, -4)
    frameShadow.BackgroundTransparency = 1
    frameShadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    frameShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    frameShadow.ImageTransparency = 0.8
    frameShadow.ZIndex = -1
    frameShadow.Parent = frame
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 18)
    shadowCorner.Parent = frameShadow
    local content = self:CreateCapsuleContent(frame, capsuleTypeData, name, config)
    self:MakeCapsuleDraggable(frame, capsule)
    capsule.frame = frame
    capsule.content = content
    self.capsules[name] = capsule
    self:UpdateNextCapsulePosition()
    self:RefreshCapsuleList()
    self:SaveConfig()
    return capsule
end
-- 创建胶囊内容
function Valkyrie:CreateCapsuleContent(parent, capsuleTypeData, name, config)
    if not capsuleTypeData or not capsuleTypeData.type then
        return nil
    end
    if capsuleTypeData.type == "Button" then
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -8, 1, -8)
        button.Position = UDim2.new(0, 4, 0, 4)
        button.BackgroundColor3 = self.currentTheme.Accent
        button.BorderSizePixel = 0
        button.Text = config.text or name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.Font = Enum.Font.GothamMedium
        button.Parent = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 14)
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
        toggleFrame.Size = UDim2.new(1, -8, 1, -8)
        toggleFrame.Position = UDim2.new(0, 4, 0, 4)
        toggleFrame.BackgroundTransparency = 1 -- 透明背景
        toggleFrame.Parent = parent
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -50, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = self.currentTheme.Text
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.GothamMedium
        label.Parent = toggleFrame
        local toggle = self:CreateToggle(toggleFrame, config.default or false, function(enabled)
            if capsuleTypeData.functionality then
                capsuleTypeData.functionality(enabled)
            end
        end)
        toggle.frame.Position = UDim2.new(1, -48, 0.5, -12)
        return toggle
    elseif capsuleTypeData.type == "Slider" then
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(1, -8, 1, -8)
        sliderFrame.Position = UDim2.new(0, 4, 0, 4)
        sliderFrame.BackgroundTransparency = 1 -- 透明背景
        sliderFrame.Parent = parent
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 14)
        label.BackgroundTransparency = 1
        label.Text = name
        label.TextColor3 = self.currentTheme.Text
        label.TextSize = 10
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.GothamMedium
        label.Parent = sliderFrame
        local slider = self:CreateSlider(sliderFrame,
            capsuleTypeData.default or config.default or 50,
            capsuleTypeData.min or config.min or 0,
            capsuleTypeData.max or config.max or 100,
            function(value)
                if capsuleTypeData.functionality then
                    capsuleTypeData.functionality(value)
                end
            end)
        slider.frame.Size = UDim2.new(1, 0, 1, -16)
        slider.frame.Position = UDim2.new(0, 0, 0, 16)
        return slider
    end
    return nil
end
-- 获取胶囊尺寸
function Valkyrie:GetCapsuleSize(capsuleTypeData)
    if capsuleTypeData.type == "Button" then
        return UDim2.new(0, 100, 0, 36)
    elseif capsuleTypeData.type == "Toggle" then
        return UDim2.new(0, 120, 0, 36)
    elseif capsuleTypeData.type == "Slider" then
        return UDim2.new(0, 140, 0, 50)
    end
    return UDim2.new(0, 100, 0, 36)
end
-- 获取下一个胶囊位置
function Valkyrie:GetNextCapsulePosition()
    return self.nextCapsulePosition
end
-- 更新下一个胶囊位置
function Valkyrie:UpdateNextCapsulePosition()
    self.nextCapsulePosition = self.nextCapsulePosition + Vector2.new(25, 25)
    if self.nextCapsulePosition.X > 700 or self.nextCapsulePosition.Y > 400 then
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
            if dragging then
                dragging = false
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
    for _, child in pairs(self.CapsuleListSection:GetChildren()) do
        if child.Name:find("CapsuleItem") then
            child:Destroy()
        end
    end
    for name, capsule in pairs(self.capsules) do
        local item = self:CreateItem(self.CapsuleListSection, name, capsule.typeData.name .. " - " .. capsule.typeData.desc)
        item.Name = name .. "CapsuleItem"
        local deleteBtn = Instance.new("TextButton")
        deleteBtn.Size = UDim2.new(0, 50, 0, 24)
        deleteBtn.Position = UDim2.new(1, -54, 0.5, -12)
        deleteBtn.BackgroundColor3 = self.currentTheme.Error
        deleteBtn.BorderSizePixel = 0
        deleteBtn.Text = "删除"
        deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteBtn.TextSize = 11
        deleteBtn.Font = Enum.Font.GothamMedium
        deleteBtn.Parent = item
        local deleteBtnCorner = Instance.new("UICorner")
        deleteBtnCorner.CornerRadius = UDim.new(0, 5)
        deleteBtnCorner.Parent = deleteBtn
        deleteBtn.MouseButton1Click:Connect(function()
            self:SafeExecute(function()
                self:DeleteCapsule(name)
            end, "删除胶囊时出错")
        end)
        deleteBtn.MouseEnter:Connect(function()
            TweenService:Create(deleteBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
        end)
        deleteBtn.MouseLeave:Connect(function()
            TweenService:Create(deleteBtn, TweenInfo.new(0.15), {BackgroundColor3 = self.currentTheme.Error}):Play()
        end)
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
        self:Notify("已删除", "胶囊 " .. name .. " 已被删除", "warning")
    end
end
-- 创建通知系统
function Valkyrie:CreateNotificationSystem()
    self.NotificationContainer = Instance.new("Frame")
    self.NotificationContainer.Name = "NotificationContainer"
    self.NotificationContainer.Size = UDim2.new(0, 280, 1, 0)
    self.NotificationContainer.Position = UDim2.new(1, -300, 0, 20)
    self.NotificationContainer.BackgroundTransparency = 1
    self.NotificationContainer.Parent = self.ScreenGui
    local notifLayout = Instance.new("UIListLayout")
    notifLayout.FillDirection = Enum.FillDirection.Vertical
    notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifLayout.Padding = UDim.new(0, 8)
    notifLayout.Parent = self.NotificationContainer
end
-- 精简的通知系统
function Valkyrie:Notify(title, message, type)
    if not self.NotificationContainer then return end
    type = type or "info"
    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.Size = UDim2.new(1, 0, 0, 60)
    notif.BackgroundColor3 = self.currentTheme.Secondary
    notif.BorderSizePixel = 0
    notif.Parent = self.NotificationContainer
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 10)
    notifCorner.Parent = notif
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 1, 0)
    indicator.Position = UDim2.new(0, 0, 0, 0)
    indicator.BorderSizePixel = 0
    indicator.Parent = notif
    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(0, 1.5)
    indicatorCorner.Parent = indicator
    local indicatorColor = self.currentTheme.Accent
    if type == "success" then indicatorColor = self.currentTheme.Success
    elseif type == "warning" then indicatorColor = self.currentTheme.Warning
    elseif type == "error" then indicatorColor = self.currentTheme.Error
    end
    indicator.BackgroundColor3 = indicatorColor
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -40, 0, 18)
    titleLabel.Position = UDim2.new(0, 12, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = self.currentTheme.Text
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.Parent = notif
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -40, 0, 28)
    messageLabel.Position = UDim2.new(0, 12, 0, 24)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = self.currentTheme.TextSecondary
    messageLabel.TextSize = 11
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextWrapped = true
    messageLabel.Parent = notif
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -26, 0, 6)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "×"
    closeBtn.TextColor3 = self.currentTheme.TextSecondary
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = notif
    closeBtn.MouseButton1Click:Connect(function()
        local fadeOut = TweenService:Create(notif, TweenInfo.new(0.2), {
            Position = UDim2.new(1, 20, 0, 0),
            BackgroundTransparency = 1
        })
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            notif:Destroy()
        end)
    end)
    notif.Position = UDim2.new(1, 20, 0, 0)
    TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                       {Position = UDim2.new(0, 0, 0, 0)}):Play()
    spawn(function()
        wait(4)
        if notif.Parent then
            local slideOut = TweenService:Create(notif, TweenInfo.new(0.3), {
                Position = UDim2.new(1, 20, 0, 0),
                BackgroundTransparency = 1
            })
            slideOut:Play()
            slideOut.Completed:Connect(function()
                notif:Destroy()
            end)
        end
    end)
end
-- 显示/隐藏主界面
function Valkyrie:Show()
    if not self.isVisible and self.MainFrame then
        self.isVisible = true
        self.MainFrame.Visible = true
        self.MainFrame.Size = UDim2.new(0, 300, 0, 280)
        self.MainFrame.BackgroundTransparency = 1
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
        TweenService:Create(self.MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = self.config.Size,
            BackgroundTransparency = 0 -- 恢复主窗口背景透明度
        }):Play()
        spawn(function()
            wait(0.1)
            for _, obj in pairs(self.MainFrame:GetDescendants()) do
                if obj:IsA("GuiObject") then
                    spawn(function()
                        local targetTransparency = 0
                        if obj.Name == "ContentFrame" then targetTransparency = 1
                        elseif obj.Parent and obj.Parent.Name == "ContentFrame" then targetTransparency = 1
                        end
                        TweenService:Create(obj, TweenInfo.new(0.3), {BackgroundTransparency = targetTransparency}):Play()
                        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                            TweenService:Create(obj, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
                        end
                        if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                            TweenService:Create(obj, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()
                        end
                    end)
                end
            end
        end)
        self:Notify("欢迎回来", "Valkyrie UI 已准备就绪", "success")
    end
end
function Valkyrie:Hide()
    if self.isVisible and self.MainFrame then
        self.isVisible = false
        for _, obj in pairs(self.MainFrame:GetDescendants()) do
            if obj:IsA("GuiObject") then
                spawn(function()
                    TweenService:Create(obj, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                        TweenService:Create(obj, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
                    end
                    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                        TweenService:Create(obj, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
                    end
                end)
            end
        end
        local mainFade = TweenService:Create(self.MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 300, 0, 280),
            BackgroundTransparency = 1
        })
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
    self.MainFrame.BackgroundColor3 = self.currentTheme.Primary
    -- if self.SidebarFrame then self.SidebarFrame.BackgroundColor3 = self.currentTheme.Secondary end -- Sidebar 保持透明
    if self.ContentFrame then self.ContentFrame.ScrollBarImageColor3 = self.currentTheme.Accent end
    if self.FloatingButton then self.FloatingButton.BackgroundColor3 = self.currentTheme.Accent end
    for _, tab in pairs(self.tabs) do
        if tab.button and tab.text and tab.icon then
            if tab.active then
                -- tab.button.BackgroundColor3 = self.currentTheme.Accent -- 不再使用背景色
                tab.text.TextColor3 = self.currentTheme.Accent
                tab.icon.ImageColor3 = self.currentTheme.Accent
            else
                -- tab.button.BackgroundColor3 = Color3.fromRGB(0, 0, 0, 0) -- 不再使用背景色
                tab.text.TextColor3 = self.currentTheme.TextSecondary
                tab.icon.ImageColor3 = self.currentTheme.TextSecondary
            end
        end
    end
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
        self.MainFrame.Size = UDim2.new(0.9, 0, 0.7, 0)
        self.MainFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
        if self.FloatingButton then
            self.FloatingButton.Size = UDim2.new(0, 60, 0, 60)
            self.FloatingButton.Position = UDim2.new(1, -75, 1, -75)
        end
    end
end
-- 安全执行函数
function Valkyrie:SafeExecute(func, errorMessage)
    local success, err = pcall(func)
    if not success then
        self:Notify("错误", errorMessage or "操作执行失败", "error")
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
        if writefile then
            if not isfolder(CONFIG_FOLDER) then
                makefolder(CONFIG_FOLDER)
            end
            writefile(CONFIG_FOLDER .. "/" .. CONFIG_FILE, jsonConfig)
        end
    end)
    if not success then
        self:Notify("保存失败", "配置保存时出错", "error")
    end
end
function Valkyrie:LoadConfig()
    local success, err = pcall(function()
        if readfile and isfile(CONFIG_FOLDER .. "/" .. CONFIG_FILE) then
            local jsonConfig = readfile(CONFIG_FOLDER .. "/" .. CONFIG_FILE)
            local config = HttpService:JSONDecode(jsonConfig)
            if config then
                if config.theme then
                    self.currentTheme = config.theme
                end
                if config.floatingIcon then
                    self.config.FloatingIcon = config.floatingIcon
                end
                self.savedCapsulesConfig = config.capsules
            end
        end
    end)
    if not success then
        self.currentTheme = {}
        for k, v in pairs(DefaultTheme) do
            self.currentTheme[k] = v
        end
    end
end
-- 加载保存的胶囊
function Valkyrie:LoadSavedCapsules()
    if self.savedCapsulesConfig then
        for name, config in pairs(self.savedCapsulesConfig) do
            spawn(function()
                wait(0.1)
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
                end
            end)
        end
        self.savedCapsulesConfig = nil
    end
end
-- 销毁UI
function Valkyrie:Destroy()
    self:SafeExecute(function()
        for _, capsule in pairs(self.capsules) do
            if capsule.frame then
                capsule.frame:Destroy()
            end
        end
        if self.ScreenGui then
            self.ScreenGui:Destroy()
        end
        self.tabs = {}
        self.capsules = {}
        self.notifications = {}
        Valkyrie.instance = nil
    end, "销毁UI时出错")
end
-- 初始化完成后的回调
spawn(function()
    repeat wait(0.1) until Valkyrie.instance and Valkyrie.instance.isInitialized
    Valkyrie.instance:LoadSavedCapsules()
    wait(0.5)
    Valkyrie.instance:Notify("初始化完成", "所有功能已准备就绪", "success")
end)
return Valkyrie