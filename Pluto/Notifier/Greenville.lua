
local player = game:GetService("Players").LocalPlayer

-- 等待 UI 路径加载
local label = player:WaitForChild("PlayerGui"):WaitForChild("UI")
    :WaitForChild("Uni"):WaitForChild("Hud")
    :WaitForChild("Money"):WaitForChild("Label")

-- 初次输出
print("[金钱读取] 当前金额为：" .. label.Text)

-- 实时监听 Text 变化
label:GetPropertyChangedSignal("Text"):Connect(function()
    print("[金钱变化] 当前金额为：" .. label.Text)
end)