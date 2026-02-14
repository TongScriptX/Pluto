--[[
    Pluto UI 库完整示例
    包含所有模块和功能的演示
--]]

-- 加载 UI 库
local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/develop/Pluto/UILibrary/PlutoUILibrary.lua"))()

-- 销毁已存在的UI实例（可选，防止重复创建）
UILibrary:DestroyExistingInstances()

-- ============================================
-- 创建主窗口
-- ============================================
local window = UILibrary:CreateUIWindow({
    Title = "Pluto UI 完整示例"
})

-- ============================================
-- 创建标签页
-- ============================================
-- 主页标签
local homeTab, homeContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "主页",
    Icon = "home",
    Active = true
})

-- 组件标签
local compTab, compContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "组件",
    Icon = "layout"
})

-- 设置标签
local settingsTab, settingsContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "设置",
    Icon = "settings"
})

-- ============================================
-- 主页内容 - 使用子标签页
-- ============================================
local subTabs = UILibrary:CreateSubTabs(homeContent, {
    Items = {
        { Name = "概览", Icon = "📊" },
        { Name = "快捷", Icon = "⚡" },
        { Name = "关于", Icon = "ℹ️" }
    },
    DefaultActive = 1,
    OnSwitch = function(index, name)
        print("切换到子标签页:", name)
    end
})

-- 子标签页 1: 概览
local overviewContent = subTabs.GetContent(1)
if overviewContent then
    local infoCard = UILibrary:CreateCard(overviewContent)
    UILibrary:CreateLabel(infoCard, { Text = "用户概览", TextSize = 14 })
    UILibrary:CreateLabel(infoCard, { Text = "欢迎使用 Pluto UI 库" })
    UILibrary:CreateLabel(infoCard, { Text = "版本: 1.0.0" })
    
    -- 演示通知
    local notifyCard = UILibrary:CreateCard(overviewContent)
    UILibrary:CreateLabel(notifyCard, { Text = "通知演示", TextSize = 14 })
    UILibrary:CreateButton(notifyCard, {
        Text = "发送成功通知",
        Icon = "checkCircle",
        Callback = function()
            UILibrary:Notify({ Title = "成功", Text = "操作已完成！" })
        end
    })
    UILibrary:CreateButton(notifyCard, {
        Text = "发送错误通知",
        Icon = "xCircle",
        Callback = function()
            UILibrary:Notify({ Title = "错误", Text = "操作失败，请重试" })
        end
    })
end

-- 子标签页 2: 快捷操作
local quickContent = subTabs.GetContent(2)
if quickContent then
    local actionCard = UILibrary:CreateCard(quickContent)
    UILibrary:CreateLabel(actionCard, { Text = "快捷操作", TextSize = 14 })
    UILibrary:CreateButton(actionCard, {
        Text = "切换到设置页",
        Icon = "arrowRight",
        Callback = function()
            -- 程序化切换标签页
            for _, child in ipairs(window.Sidebar:GetChildren()) do
                if child:IsA("TextButton") and child.Text == "设置" then
                    child.MouseButton1Click:Fire()
                end
            end
        end
    })
    UILibrary:CreateButton(actionCard, {
        Text = "切换到子标签2",
        Icon = "chevronRight",
        Callback = function()
            subTabs.SwitchTo(3)
        end
    })
end

-- 子标签页 3: 关于
local aboutContent = subTabs.GetContent(3)
if aboutContent then
    local aboutCard = UILibrary:CreateCard(aboutContent)
    UILibrary:CreateLabel(aboutCard, { Text = "关于 Pluto UI", TextSize = 14 })
    UILibrary:CreateLabel(aboutCard, { Text = "一个现代化的 Roblox UI 库" })
    UILibrary:CreateLabel(aboutCard, { Text = "支持毛玻璃效果、流畅动画" })
    
    -- 作者信息
    UILibrary:CreateAuthorInfo(aboutCard, {
        Author = "Pluto Team",
        Version = "1.0.0"
    })
end

-- ============================================
-- 组件页内容 - 展示所有组件
-- ============================================
-- 按钮组件
local btnCard = UILibrary:CreateCard(compContent)
UILibrary:CreateLabel(btnCard, { Text = "按钮 Button", TextSize = 14 })
UILibrary:CreateButton(btnCard, {
    Text = "普通按钮",
    Icon = "mouse-pointer",
    Callback = function()
        UILibrary:Notify({ Title = "按钮", Text = "你点击了普通按钮" })
    end
})

-- 开关组件
local toggleCard = UILibrary:CreateCard(compContent)
UILibrary:CreateLabel(toggleCard, { Text = "开关 Toggle", TextSize = 14 })
local toggle1, toggleState1 = UILibrary:CreateToggle(toggleCard, {
    Text = "启用功能A",
    DefaultState = true,
    Callback = function(state)
        print("功能A:", state)
    end
})
local toggle2, toggleState2 = UILibrary:CreateToggle(toggleCard, {
    Text = "启用功能B",
    DefaultState = false,
    Callback = function(state)
        print("功能B:", state)
    end
})

-- 滑块组件
local sliderCard = UILibrary:CreateCard(compContent)
UILibrary:CreateLabel(sliderCard, { Text = "滑块 Slider", TextSize = 14 })
UILibrary:CreateSlider(sliderCard, {
    Text = "音量",
    Min = 0,
    Max = 100,
    Default = 75,
    Callback = function(value)
        print("音量:", value)
    end
})
UILibrary:CreateSlider(sliderCard, {
    Text = "灵敏度",
    Min = 0.1,
    Max = 10,
    Default = 5,
    Callback = function(value)
        print("灵敏度:", value)
    end
})

-- 下拉框组件
local dropdownCard = UILibrary:CreateCard(compContent)
UILibrary:CreateLabel(dropdownCard, { Text = "下拉框 Dropdown", TextSize = 14 })
UILibrary:CreateDropdown(dropdownCard, {
    Text = "语言",
    DefaultOption = "简体中文",
    Options = { "简体中文", "English", "日本語", "한국어" },
    Callback = function(selected)
        UILibrary:Notify({ Title = "语言", Text = "选择了: " .. selected })
    end
})
UILibrary:CreateDropdown(dropdownCard, {
    Text = "画质",
    DefaultOption = "高",
    Options = { "低", "中", "高", "超高" },
    Callback = function(selected)
        print("画质:", selected)
    end
})

-- 输入框组件
local inputCard = UILibrary:CreateCard(compContent)
UILibrary:CreateLabel(inputCard, { Text = "输入框 TextBox", TextSize = 14 })
UILibrary:CreateTextBox(inputCard, {
    PlaceholderText = "输入用户名...",
    OnFocusLost = function(text)
        if text ~= "" then
            print("输入的用户名:", text)
        end
    end
})
UILibrary:CreateTextBox(inputCard, {
    PlaceholderText = "输入密码...",
    OnFocusLost = function(text)
        if text ~= "" then
            print("密码长度:", #text)
        end
    end
})

-- ============================================
-- 设置页内容
-- ============================================
-- 主题设置
local themeCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(themeCard, { Text = "主题设置", TextSize = 14 })
UILibrary:CreateDropdown(themeCard, {
    Text = "主题色",
    DefaultOption = "紫色",
    Options = { "紫色", "蓝色", "绿色", "红色" },
    Callback = function(selected)
        local colors = {
            ["紫色"] = Color3.fromRGB(63, 81, 181),
            ["蓝色"] = Color3.fromRGB(33, 150, 243),
            ["绿色"] = Color3.fromRGB(76, 175, 80),
            ["红色"] = Color3.fromRGB(244, 67, 54)
        }
        UILibrary:SetTheme({ Primary = colors[selected] })
        UILibrary:Notify({ Title = "主题", Text = "已切换到" .. selected .. "主题" })
    end
})

-- 显示设置
local displayCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(displayCard, { Text = "显示设置", TextSize = 14 })
UILibrary:CreateToggle(displayCard, {
    Text = "显示通知",
    DefaultState = true
})
UILibrary:CreateToggle(displayCard, {
    Text = "启用动画",
    DefaultState = true
})

-- 其他设置
local otherCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(otherCard, { Text = "其他设置", TextSize = 14 })
UILibrary:CreateButton(otherCard, {
    Text = "重置所有设置",
    Icon = "refresh",
    Callback = function()
        UILibrary:Notify({ Title = "重置", Text = "设置已重置" })
    end
})
UILibrary:CreateButton(otherCard, {
    Text = "关于作者",
    Icon = "info",
    Callback = function()
        subTabs.SwitchTo(3)
    end
})

-- ============================================
-- 创建灵动岛悬浮按钮
-- ============================================
UILibrary:CreateFloatingButton(window.ScreenGui, {
    MainFrame = window.MainFrame
})

-- ============================================
-- 自定义主题（可选，放在最后覆盖默认主题）
-- ============================================
--[[
UILibrary:SetTheme({
    Primary = Color3.fromRGB(63, 81, 181),      -- 主色
    Background = Color3.fromRGB(25, 25, 28),    -- 背景色
    SecondaryBackground = Color3.fromRGB(40, 42, 50), -- 次级背景
    Accent = Color3.fromRGB(92, 107, 192),      -- 强调色
    Text = Color3.fromRGB(255, 255, 255),       -- 文字颜色
    Success = Color3.fromRGB(76, 175, 80),      -- 成功色
    Error = Color3.fromRGB(244, 67, 54)         -- 错误色
})
--]]