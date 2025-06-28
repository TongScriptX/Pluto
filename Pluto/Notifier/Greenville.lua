-- 搜索目标值（数字或字符串）
local targetValues = {
    8500,
    "8,500"
}

-- 支持检查的属性对象类型
local valueTypes = {
    "NumberValue",
    "IntValue",
    "FloatValue",
    "DoubleConstrainedValue",
    "StringValue"
}

-- 判断是否为目标值
local function isTargetValue(value)
    for _, target in ipairs(targetValues) do
        if value == target then
            return true
        end
    end
    return false
end

-- 判断是否是支持的对象类型
local function isSupportedType(obj)
    return table.find(valueTypes, obj.ClassName) ~= nil
end

-- 任务控制
local queue = {} -- 广度优先遍历队列
local totalChecked = 0
local totalMatches = 0
local batchSize = 50 -- 每次处理多少对象
local delayTime = 0.03 -- 每批之间的等待时间
local startTime = tick()

-- 添加根对象（遍历整个游戏）
table.insert(queue, {instance = game, path = "game"})

-- 打印初始提示
print("[开始] 全局搜索目标值（8500 / '8,500'）...")

-- 异步递归处理函数
task.spawn(function()
    while #queue > 0 do
        for i = 1, math.min(#queue, batchSize) do
            local item = table.remove(queue, 1)
            local instance = item.instance
            local path = item.path

            -- 检查值是否匹配
            if isSupportedType(instance) and isTargetValue(instance.Value) then
                print("[匹配对象] " .. path .. " (" .. instance.ClassName .. "): " .. tostring(instance.Value))
                totalMatches += 1
            end

            -- 加入子对象到队列
            for _, child in ipairs(instance:GetChildren()) do
                table.insert(queue, {
                    instance = child,
                    path = path .. "/" .. child.Name
                })
            end

            totalChecked += 1
        end

        print(string.format("[搜索中] 已检查: %d，匹配: %d，用时: %.2f 秒", totalChecked, totalMatches, tick() - startTime))
        task.wait(delayTime)
    end

    print(string.format("[完成] 共匹配: %d 个对象，检查: %d 项，用时: %.2f 秒", totalMatches, totalChecked, tick() - startTime))
end)