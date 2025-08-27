-- 直接通过 loadstring 加载并执行 Valkyrie.lua
local Valkyrie = loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Valkyrie_UILib/Valkyrie.lua"))()

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