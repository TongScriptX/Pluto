-- // 加载 Valkyrie UI 库 // --
-- 注意：请确保你的执行器允许外部加载，并且能够访问 raw.githubusercontent.com
local success, valkyrieModule = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Valkyrie_UILib/Valkyrie.lua"))()
end)

if not success or type(valkyrieModule) ~= "table" then
    warn("无法加载 Valkyrie UI 库:", valkyrieModule or "未知错误")
    return
end

-- // 初始化 Valkyrie UI // --
-- 创建一个新的 Valkyrie UI 实例
-- 你可以在这里自定义标题、图标等
local UI = valkyrieModule.new({
    Title = "我的脚本 - Valkyrie UI 示例", -- 窗口标题
    FloatingIcon = "rbxassetid://7072719185" -- 悬浮按钮图标 (这里使用了库自带的 User 图标)
})

-- 等待 UI 初始化完成
repeat task.wait() until UI and UI.isInitialized

-- // 创建标签页和控件 // --

-- 1. 在默认的 "主页" 标签页添加内容
-- (通常不需要手动获取，因为 AddTab 会自动处理第一个标签页，但我们可以通过 tabs 表访问它)
-- local homeTabContent = UI.tabs["主页"].content -- 获取主页内容容器 (可选)

-- 2. 添加一个名为 "功能" 的新标签页
local featuresTabContent = UI:AddTab("功能", "rbxassetid://7072717281") -- 使用 Add 图标

-- 3. 在 "功能" 标签页中添加内容
-- 创建一个内容区块
local exampleSection = UI:CreateContentSection(featuresTabContent, {
    title = "示例控件",
    items = {} -- 我们将通过 CreateRowItem 添加项目
})

-- --- 添加各种控件 ---

-- 添加一个按钮
UI:CreateRowItem(exampleSection, "打印信息", {
    type = "button",
    text = "点击我",
    callback = function()
        print("按钮被点击了！")
        -- 使用 UI 的通知系统
        UI:Notify({
            Title = "操作成功",
            Message = "你点击了按钮！",
            Type = "Success", -- 可以是 Info (默认), Success, Warning, Error
            Duration = 2
        })
    end
}, "这是一个示例按钮")

-- 添加一个开关 (Toggle)
UI:CreateRowItem(exampleSection, "启用功能", {
    type = "toggle",
    default = false, -- 初始状态
    callback = function(isEnabled)
        print("开关状态:", isEnabled)
        if isEnabled then
            UI:Notify({Title = "已启用", Message = "功能已开启", Type = "Success"})
        else
            UI:Notify({Title = "已禁用", Message = "功能已关闭", Type = "Warning"})
        end
        -- 在这里放置你的功能逻辑
        -- 例如：启用/禁用某个游戏功能
    end
}, "控制某个功能的开关")

-- 添加一个滑块 (Slider)
UI:CreateRowItem(exampleSection, "调整数值", {
    type = "slider",
    min = 0,
    max = 100,
    default = 50,
    callback = function(value)
        print("滑块值:", value)
        -- 使用 UI 的通知系统显示当前值
        UI:Notify({Title = "数值调整", Message = "当前值: " .. math.floor(value), Type = "Info", Duration = 1})
        -- 在这里放置使用该数值的逻辑
        -- 例如：调整角色速度、跳跃高度等
    end
}, "使用滑块调整一个数值 (0-100)")

-- 4. 添加一个名为 "设置" 的新标签页
local settingsTabContent = UI:AddTab("设置", "rbxassetid://7072719338") -- 使用 Settings 图标

-- 在 "设置" 标签页中添加内容
local settingsSection = UI:CreateContentSection(settingsTabContent, {
    title = "脚本设置",
    items = {}
})

-- 添加一个颜色选择器 (Color Picker) 来改变主题主色调
UI:CreateRowItem(settingsSection, "主色调", {
    type = "color",
    default = UI.currentTheme.Accent, -- 使用当前主题的主色调作为默认值
    callback = function(newColor)
        print("新颜色:", newColor)
        -- 更新 UI 主题的主色调
        UI.currentTheme.Accent = newColor
        -- 计算悬停颜色 (简单地增加亮度)
        UI.currentTheme.AccentHover = Color3.fromRGB(
            math.min(255, newColor.R * 255 + 20),
            math.min(255, newColor.G * 255 + 20),
            math.min(255, newColor.B * 255 + 20)
        )
        -- 应用新主题
        UI:UpdateTheme()
        -- 保存配置 (包括新主题)
        UI:SaveConfig()
        UI:Notify({Title = "主题更新", Message = "主色调已更改", Type = "Success"})
    end
}, "自定义 UI 主色调")

-- 添加一个文本框 (Textbox) 来更改悬浮按钮图标
UI:CreateRowItem(settingsSection, "悬浮按钮图标", {
    type = "textbox",
    placeholder = "输入 Roblox Asset ID",
    callback = function(assetIdText)
        if assetIdText and assetIdText ~= "" then
            -- 简单验证是否为数字 (Asset ID 通常是数字)
            local assetIdNumber = tonumber(assetIdText)
            if assetIdNumber then
                local fullAssetId = "rbxassetid://" .. assetIdNumber
                print("新图标 Asset ID:", fullAssetId)
                -- 更新配置
                UI.config.FloatingIcon = fullAssetId
                -- 更新 UI 上的图标
                if UI.FloatingButton then
                    UI.FloatingButton.Image = fullAssetId
                end
                -- 保存配置 (包括新图标)
                UI:SaveConfig()
                UI:Notify({Title = "图标更新", Message = "悬浮按钮图标已更改", Type = "Success"})
            else
                UI:Notify({Title = "输入无效", Message = "请输入有效的 Asset ID 数字", Type = "Error"})
            end
        end
    end
}, "输入图像的 Roblox Asset ID")


-- // 脚本逻辑 // --
-- 你可以在这里添加你的主要脚本逻辑
-- 例如，监听开关状态、使用滑块值等

-- 示例：根据开关状态执行循环逻辑
local someFeatureEnabled = false

-- 假设我们有一个需要持续运行的功能，由上面的开关控制
spawn(function()
    while true do
        if someFeatureEnabled then
            -- 执行功能逻辑
            -- print("功能正在运行...")
            -- 这里放置你的代码
        end
        task.wait(1) -- 控制循环频率
    end
end)

-- 确保开关回调能修改全局状态
-- 注意：我们需要访问到 CreateRowItem 创建的开关。由于 CreateRowItem 不直接返回控件引用，
-- 我们需要修改回调来间接影响。或者，更好的方法是使用一个表来存储状态。
-- 这里我们修改上面开关的回调示例 (你需要替换掉上面那个开关的创建代码)：
--[[
-- 用于存储功能状态的表
local featureStates = {
    someFeature = false
}

-- 添加一个开关 (Toggle) - 更新版
UI:CreateRowItem(exampleSection, "启用功能", {
    type = "toggle",
    default = false, -- 初始状态
    callback = function(isEnabled)
        featureStates.someFeature = isEnabled -- 更新状态表
        print("开关状态:", isEnabled)
        if isEnabled then
            UI:Notify({Title = "已启用", Message = "功能已开启", Type = "Success"})
        else
            UI:Notify({Title = "已禁用", Message = "功能已关闭", Type = "Warning"})
        end
    end
}, "控制某个功能的开关")

-- 然后在循环中使用 featureStates.someFeature
spawn(function()
    while true do
        if featureStates.someFeature then
             -- 执行功能逻辑
             -- print("功能正在运行...")
             -- 这里放置你的代码
        end
        task.wait(1)
    end
end)
--]]

print("Valkyrie UI 示例脚本已加载并运行！")