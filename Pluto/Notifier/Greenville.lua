local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 等待本地玩家和子对象加载
repeat task.wait() until player and player.Parent and #player:GetChildren() > 0

local startTime = tick()

-- 目标值（数字/字符串）
local targetValues = {
    8500,
    "8,500"
}

-- 类型
local valueTypes = {
    "NumberValue",
    "IntValue",
    "FloatValue",
    "DoubleConstrainedValue",
    "StringValue"
}

-- 判断是否匹配
local function isTargetValue(value)
    for _, target in ipairs(targetValues) do
        if value == target then
            return true
        end
    end
    return false
end

-- 匹配数 & 层级追踪
local matchCount = 0
local checkedCount = 0
local level = 0

-- 每 N 次输出一次提示
local updateEvery = 20

-- 遍历函数
local function checkDescendants(object, path)
    level += 1
    for _, child in ipairs(object:GetChildren()) do
        checkedCount += 1
        local newPath = path .. "/" .. child.Name

        if table.find(valueTypes, child.ClassName) and isTargetValue(child.Value) then
            print("[匹配对象] " .. newPath .. " (" .. child.ClassName .. "): " .. tostring(child.Value))
            matchCount += 1
        end

        -- 输出实时进度
        if checkedCount % updateEvery == 0 then
            local now = tick()
            print(string.format("[搜索中] 当前层级: %d，已检查: %d，耗时: %.2f 秒", level, checkedCount, now - startTime))
        end

        checkDescendants(child, newPath)
    end
    level -= 1
end

-- 执行
print("[开始] 正在搜索本地玩家数据中值为 8500 或 '8,500' 的对象...")
checkDescendants(player, "Players/" .. player.Name)

-- 结束提示
local duration = tick() - startTime
print("[完成] 匹配数: " .. matchCount .. "，共检查: " .. checkedCount .. " 项，耗时: " .. string.format("%.2f", duration) .. " 秒")