-- 获取本地玩家对象
local player = game:GetService("Players").LocalPlayer

-- 目标值列表（数字 + 字符串）
local targetValues = {
    8500,
    "8,500"
}

-- 支持的对象类型（数值或字符串）
local valueTypes = {
    "NumberValue",
    "IntValue",
    "FloatValue",
    "DoubleConstrainedValue",
    "StringValue"
}

-- 判断是否匹配目标值
local function isTargetValue(value)
    for _, target in ipairs(targetValues) do
        if value == target then
            return true
        end
    end
    return false
end

-- 递归检查
local function checkDescendants(object, path)
    for _, child in ipairs(object:GetChildren()) do
        local newPath = path .. "/" .. child.Name
        if table.find(valueTypes, child.ClassName) and isTargetValue(child.Value) then
            print("[匹配对象] " .. newPath .. " (" .. child.ClassName .. "): " .. tostring(child.Value))
        end
        checkDescendants(child, newPath)
    end
end

-- 执行
checkDescendants(player, "Players/" .. player.Name)