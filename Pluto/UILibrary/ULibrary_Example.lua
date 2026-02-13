-- 加载 UI 库
local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/develop/Pluto/UILibrary/PlutoUILibrary.lua"))()

-- 创建主窗口
local window = UILibrary:CreateUIWindow({
    Title = "Pluto UI 示例"
})

-- 创建主页标签
local homeTab, homeContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "主页",
    Active = true
})

-- 创建设置标签
local settingsTab, settingsContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "设置"
})

-- === 主页内容 - 使用子标签页 ===
local subTabs = UILibrary:CreateSubTabs(homeContent, {
    Items = {
        { Name = "概览", Icon = "🏠" },
        { Name = "角色", Icon = "👤" },
        { Name = "背包", Icon = "🎒" }
    },
    DefaultActive = 1,
    OnSwitch = function(index, name)
        print("切换到子标签页:", name)
    end
})

-- 子标签页 1: 概览
local overviewContent = subTabs.GetContent(1)
if overviewContent then
    local userCard = UILibrary:CreateCard(overviewContent)
    UILibrary:CreateLabel(userCard, { Text = "用户信息", TextSize = 14 })
    UILibrary:CreateLabel(userCard, { Text = "用户名: Player123" })
    UILibrary:CreateLabel(userCard, { Text = "等级: 15" })
    
    local actionCard = UILibrary:CreateCard(overviewContent)
    UILibrary:CreateLabel(actionCard, { Text = "快捷操作", TextSize = 14 })
    UILibrary:CreateButton(actionCard, {
        Text = "开始游戏",
        Callback = function()
            UILibrary:Notify({ Title = "游戏开始", Text = "游戏即将开始！" })
        end
    })
end

-- 子标签页 2: 角色
local characterContent = subTabs.GetContent(2)
if characterContent then
    local charCard = UILibrary:CreateCard(characterContent)
    UILibrary:CreateLabel(charCard, { Text = "角色属性", TextSize = 14 })
    UILibrary:CreateLabel(charCard, { Text = "力量: 85" })
    UILibrary:CreateLabel(charCard, { Text = "敏捷: 72" })
    
    UILibrary:CreateDropdown(charCard, {
        Text = "职业",
        DefaultOption = "战士",
        Options = { "战士", "法师", "弓箭手" },
        Callback = function(selected)
            UILibrary:Notify({ Title = "职业", Text = "选择了: " .. selected })
        end
    })
end

-- 子标签页 3: 背包
local backpackContent = subTabs.GetContent(3)
if backpackContent then
    local bagCard = UILibrary:CreateCard(backpackContent)
    UILibrary:CreateLabel(bagCard, { Text = "背包物品", TextSize = 14 })
    UILibrary:CreateLabel(bagCard, { Text = "生命药水 x10" })
    UILibrary:CreateButton(bagCard, {
        Text = "整理背包",
        Callback = function()
            UILibrary:Notify({ Title = "背包", Text = "已整理" })
        end
    })
end

-- === 设置页面内容 ===
local displayCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(displayCard, { Text = "显示设置", TextSize = 14 })

UILibrary:CreateToggle(displayCard, {
    Text = "自动保存",
    DefaultState = true,
    Callback = function(state)
        print("自动保存:", state)
    end
})

UILibrary:CreateSlider(displayCard, {
    Text = "音量",
    Min = 0,
    Max = 100,
    Default = 75,
    Callback = function(value)
        print("音量:", value)
    end
})

-- 创建输入框示例
local inputCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(inputCard, { Text = "输入设置", TextSize = 14 })
UILibrary:CreateTextBox(inputCard, {
    PlaceholderText = "输入玩家名称...",
    Text = "",
    OnFocusLost = function(text)
        print("输入内容:", text)
    end
})

-- 创建灵动岛悬浮按钮（控制窗口显示/隐藏）
UILibrary:CreateFloatingButton(window.ScreenGui, {
    MainFrame = window.MainFrame
})

-- 可选：自定义主题
UILibrary:SetTheme({
    Primary = Color3.fromRGB(63, 81, 181),
    Background = Color3.fromRGB(25, 25, 28),
    SecondaryBackground = Color3.fromRGB(40, 42, 50),
    Accent = Color3.fromRGB(92, 107, 192),
    Text = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54)
})