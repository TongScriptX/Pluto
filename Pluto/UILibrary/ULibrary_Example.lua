-- 加载 UI 库
local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"))()

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
    -- 用户信息卡片
    local userCard = UILibrary:CreateCard(overviewContent)
    UILibrary:CreateLabel(userCard, {
        Text = "用户信息",
        TextSize = 14
    })
    UILibrary:CreateLabel(userCard, {
        Text = "用户名: Player123"
    })
    UILibrary:CreateLabel(userCard, {
        Text = "等级: 15"
    })
    
    -- 快捷操作卡片
    local actionCard = UILibrary:CreateCard(overviewContent)
    UILibrary:CreateLabel(actionCard, {
        Text = "快捷操作",
        TextSize = 14
    })
    
    UILibrary:CreateButton(actionCard, {
        Text = "开始游戏",
        Callback = function()
            UILibrary:Notify({
                Title = "游戏开始",
                Text = "游戏即将开始，请准备！"
            })
        end
    })
    
    UILibrary:CreateButton(actionCard, {
        Text = "查看成就",
        Callback = function()
            UILibrary:Notify({
                Title = "成就",
                Text = "暂无新成就"
            })
        end
    })
end

-- 子标签页 2: 角色
local characterContent = subTabs.GetContent(2)
if characterContent then
    local charCard = UILibrary:CreateCard(characterContent)
    UILibrary:CreateLabel(charCard, {
        Text = "角色属性",
        TextSize = 14
    })
    UILibrary:CreateLabel(charCard, { Text = "力量: 85" })
    UILibrary:CreateLabel(charCard, { Text = "敏捷: 72" })
    UILibrary:CreateLabel(charCard, { Text = "智力: 68" })
    
    -- 下拉框选择职业
    local roleDropdown = UILibrary:CreateDropdown(charCard, {
        Text = "职业",
        DefaultOption = "战士",
        Options = { "战士", "法师", "弓箭手", "刺客" },
        Callback = function(selectedRole)
            UILibrary:Notify({
                Title = "职业选择",
                Text = "你选择了: " .. selectedRole
            })
        end
    })
end

-- 子标签页 3: 背包
local backpackContent = subTabs.GetContent(3)
if backpackContent then
    local bagCard = UILibrary:CreateCard(backpackContent)
    UILibrary:CreateLabel(bagCard, {
        Text = "背包物品",
        TextSize = 14
    })
    UILibrary:CreateLabel(bagCard, { Text = "生命药水 x10" })
    UILibrary:CreateLabel(bagCard, { Text = "魔法药水 x5" })
    UILibrary:CreateLabel(bagCard, { Text = "金币: 1,250" })
    UILibrary:CreateButton(bagCard, {
        Text = "整理背包",
        Callback = function()
            UILibrary:Notify({ Title = "背包", Text = "背包已整理" })
        end
    })
end

-- 操作卡片
local actionCard = UILibrary:CreateCard(homeContent)
UILibrary:CreateLabel(actionCard, {
    Text = "快捷操作",
    TextSize = 14
})

UILibrary:CreateButton(actionCard, {
    Text = "开始游戏",
    Callback = function()
        UILibrary:Notify({
            Title = "游戏开始",
            Text = "游戏即将开始，请准备！"
        })
    end
})

UILibrary:CreateButton(actionCard, {
    Text = "查看成就",
    Callback = function()
        UILibrary:Notify({
            Title = "成就",
            Text = "暂无新成就"
        })
    end
})

-- 下拉框示例
local dropdownCard = UILibrary:CreateCard(homeContent)
UILibrary:CreateLabel(dropdownCard, {
    Text = "选择角色",
    TextSize = 14
})

local roleDropdown = UILibrary:CreateDropdown(dropdownCard, {
    Text = "角色",
    DefaultOption = "战士",
    Options = {
        "战士",
        "法师",
        "弓箭手",
        "刺客"
    },
    Callback = function(selectedRole)
        UILibrary:Notify({
            Title = "角色选择",
            Text = "你选择了: " .. selectedRole
        })
    end
})

-- 输入框示例
local inputCard = UILibrary:CreateCard(homeContent)
UILibrary:CreateLabel(inputCard, {
    Text = "输入设置",
    TextSize = 14
})

local nameInput = UILibrary:CreateTextBox(inputCard, {
    PlaceholderText = "请输入你的名字",
    Text = "",
    OnFocusLost = function(text)
        if text and text ~= "" then
            UILibrary:Notify({
                Title = "输入确认",
                Text = "你的名字是: " .. text
            })
        end
    end
})

-- === 设置页面内容 ===
-- 显示设置
local displayCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(displayCard, {
    Text = "显示设置",
    TextSize = 14
})

-- 音量控制
UILibrary:CreateLabel(displayCard, {
    Text = "音量控制"
})

local volumeSlider = Instance.new("Frame") -- 简化的滑块示例
volumeSlider.Size = UDim2.new(1, 0, 0, 20)
volumeSlider.Parent = displayCard

-- 游戏设置
local gameCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(gameCard, {
    Text = "游戏设置",
    TextSize = 14
})

local autoSaveToggle, autoSaveState = UILibrary:CreateToggle(gameCard, {
    Text = "自动保存",
    DefaultState = true,
    Callback = function(state)
        print("自动保存设置:", state)
    end
})

-- 创建悬浮按钮
UILibrary:CreateFloatingButton(window.MainFrame, {
    Text = "T",
    MainFrame = window.MainFrame
})

-- 自定义主题（可选）
UILibrary:SetTheme({
    Primary = Color3.fromRGB(63, 81, 181),
    Background = Color3.fromRGB(30, 30, 30),
    SecondaryBackground = Color3.fromRGB(46, 46, 46),
    Accent = Color3.fromRGB(92, 107, 192),
    Text = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54)
})