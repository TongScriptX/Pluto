-- 服务和变量声明
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- PlutoX 核心引用
local PlutoX = _G.PlutoX
local UILibrary = PlutoX.UILibrary

-- 游戏信息
local gameName = "Fix It Up"
local gameId = game.PlaceId

PlutoX.info("[" .. gameName .. "] 脚本加载中...")

-- 配置
local config = {
    autoFarmEnabled = false,
    autoInstallEnabled = false
}

local LocalPlayer = Players.LocalPlayer
local isAutoFarmActive = false

-- 获取玩家车辆
local function getPlayerVehicle()
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then
        PlutoX.debug("[Fix It Up] 未找到 Vehicles 文件夹")
        return nil
    end

    local vehicle = vehicles:FindFirstChild(LocalPlayer.Name)
    if vehicle and vehicle:GetAttribute("Owner") == LocalPlayer.Name then
        PlutoX.debug("[Fix It Up] 找到玩家车辆: " .. LocalPlayer.Name)
        return vehicle
    end

    PlutoX.debug("[Fix It Up] 未找到玩家车辆")
    return nil
end

-- 自动安装零件
local function performAutoInstall()
    PlutoX.debug("[Fix It Up] 开始自动安装零件")

    local moveableParts = Workspace:FindFirstChild("MoveableParts")
    if not moveableParts then
        PlutoX.debug("[Fix It Up] 未找到 MoveableParts")
        return
    end

    local installedCount = 0
    for _, part in ipairs(moveableParts:GetChildren()) do
        if not part:IsA("Model") then
            local owner = part:GetAttribute("Owner")
            local wear = part:GetAttribute("Wear")

            if owner and tostring(owner) == LocalPlayer.Name then
                if wear and wear ~= 0 then
                    PlutoX.debug("[Fix It Up] 发现可安装零件: " .. part.Name .. " (磨损: " .. wear .. ")")
                    installedCount = installedCount + 1

                    -- 触发安装逻辑（需要根据游戏实际 Remote 调整）
                    local binds = ReplicatedStorage:WaitForChild("ClientScripts"):WaitForChild("Client"):WaitForChild("Binds"):WaitForChild("Cache")
                    local installPart = binds:FindFirstChild("InstallPart")
                    if installPart then
                        installPart:FireServer(part)
                        task.wait(0.1)
                    end
                end
            end
        end
    end

    PlutoX.debug("[Fix It Up] 自动安装完成，共安装 " .. installedCount .. " 个零件")
end

-- AutoFarm 主循环
local function performAutoFarm()
    if not config.autoFarmEnabled then return end
    isAutoFarmActive = true

    PlutoX.debug("[Fix It Up] AutoFarm 开始")

    spawn(function()
        while config.autoFarmEnabled and isAutoFarmActive do
            local success, err = pcall(function()
                local vehicle = getPlayerVehicle()

                if not vehicle then
                    PlutoX.debug("[Fix It Up] 车辆丢失，等待重新生成...")
                    task.wait(3)
                    return
                end

                -- 执行自动安装
                if config.autoInstallEnabled then
                    performAutoInstall()
                end

                PlutoX.debug("[Fix It Up] AutoFarm 循环完成，等待下一轮")
                task.wait(2)
            end)

            if not success then
                PlutoX.warn("[Fix It Up] AutoFarm 错误: " .. tostring(err))
                task.wait(5)
            end
        end

        PlutoX.debug("[Fix It Up] AutoFarm 停止")
        isAutoFarmActive = false
    end)
end

-- UI 创建
local window = UILibrary:CreateWindow({
    Title = "Pluto - " .. gameName,
    AccentColor = PlutoX.theme.Primary
})

local mainTab = window:AddTab({ Name = "主要功能" })

mainTab:AddToggle({
    Name = "启用 AutoFarm",
    Default = false,
    Callback = function(value)
        config.autoFarmEnabled = value
        PlutoX.debug("[Fix It Up] AutoFarm 状态: " .. tostring(value))

        if value then
            performAutoFarm()
        else
            isAutoFarmActive = false
        end
    end
})

mainTab:AddToggle({
    Name = "自动安装零件",
    Default = false,
    Callback = function(value)
        config.autoInstallEnabled = value
        PlutoX.debug("[Fix It Up] 自动安装状态: " .. tostring(value))
    end
})

PlutoX.info("[" .. gameName .. "] 脚本加载完成")
