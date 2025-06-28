-- LocalScript (必须放在 StarterGui 中)
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 目标文本
local targetText = "8,500"

-- 遍历 PlayerGui，匹配文本并输出完整路径
for _, gui in ipairs(playerGui:GetDescendants()) do
    if (gui:IsA("TextLabel") or gui:IsA("TextBox")) and gui.Text == targetText then
        print("[匹配 UI] 路径:", gui:GetFullName(), "文本值:", gui.Text)
    end
end

-- 实时监听后续文本变化（可选）
for _, gui in ipairs(playerGui:GetDescendants()) do
    if gui:IsA("TextLabel") or gui:IsA("TextBox") then
        gui:GetPropertyChangedSignal("Text"):Connect(function()
            if gui.Text == targetText then
                print("[实时匹配 UI] 路径:", gui:GetFullName(), "文本值:", gui.Text)
            end
        end)
    end
end