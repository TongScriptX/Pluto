-- 服务和变量声明
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- UI
local UILibrary
local success, result = pcall(function()
    local url = "https://api.959966.xyz/github/raw/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if success and result then
    UILibrary = result
else
    error("[PlutoUILibrary] 加载失败！请检查网络连接或链接是否有效：" .. tostring(result))
end

-- PlutoX
local success, PlutoX = pcall(function()
    local url = "https://api.959966.xyz/github/raw/TongScriptX/Pluto/refs/heads/main/Pluto/Common/PlutoX-Notifier.lua"
    local source = game:HttpGet(url)
    return loadstring(source)()
end)

if not success or not PlutoX then
    error("[PlutoX] 模块加载失败！请检查网络连接或链接是否有效：" .. tostring(PlutoX))
end

-- 玩家信息
local player = Players.LocalPlayer
if not player then
    error("无法获取当前玩家")
end

local username = player.Name
local gameName = "Fix It Up"

-- 初始化调试系统
PlutoX.setGameInfo(gameName, username, HttpService)

-- 配置
local config = {
    autoFarmEnabled = false,
    selectedCar = nil,
    pathName = "JunkyardToRepairv3"
}

local LocalPlayer = Players.LocalPlayer
local isAutoFarmActive = false

-- 默认路径
local defaultPaths = {
    JunkyardToRepairv3 = {
        Vector3.new(-1626.6254882812, 3.5604448318481, -315.85256958008),
        Vector3.new(-1611.2081298828, 3.3032665252686, -327.68154907227),
        Vector3.new(-1582.7303466797, 3.1615476608276, -319.58898925781),
        Vector3.new(-1360.5404052734, 3.1766638755798, -67.149131774902)
    }
}

-- 获取玩家车辆
local function getPlayerVehicle()
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then
        PlutoX.debug("[Fix It Up] 未找到 Vehicles 文件夹")
        return nil
    end

    for _, vehicle in ipairs(vehicles:GetChildren()) do
        if vehicle:GetAttribute("Owner") == LocalPlayer.Name then
            PlutoX.debug("[Fix It Up] 找到玩家车辆")
            return vehicle
        end
    end

    PlutoX.debug("[Fix It Up] 未找到玩家车辆")
    return nil
end

-- 加载车辆
local function loadVehicle(carName)
    PlutoX.debug("[Fix It Up] 尝试加载车辆: " .. tostring(carName))

    local remoteLoad = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Vehicles"):WaitForChild("RemoteLoad")
    remoteLoad:FireServer(carName)

    task.wait(3)

    local vehicle = getPlayerVehicle()
    if vehicle then
        PlutoX.debug("[Fix It Up] 车辆加载成功")
        return true
    else
        PlutoX.warn("[Fix It Up] 车辆加载失败")
        return false
    end
end

-- 沿路径移动车辆
local function driveAlongPath(pathPoints)
    PlutoX.debug("[Fix It Up] 开始沿路径移动，共 " .. #pathPoints .. " 个点")

    local vehicle = getPlayerVehicle()
    if not vehicle then
        PlutoX.warn("[Fix It Up] 未找到车辆，无法移动")
        return false
    end

    for i, point in ipairs(pathPoints) do
        if not config.autoFarmEnabled then
            PlutoX.debug("[Fix It Up] AutoFarm 已停止")
            return false
        end

        PlutoX.debug("[Fix It Up] 移动到路径点 " .. i .. "/" .. #pathPoints)

        -- 传送车辆到路径点
        vehicle:PivotTo(CFrame.new(point))
        task.wait(0.5)
    end

    PlutoX.debug("[Fix It Up] 路径移动完成")
    return true
end

-- 拆卸零件
local function stripParts()
    PlutoX.debug("[Fix It Up] 开始拆卸零件")

    local vehicle = getPlayerVehicle()
    if not vehicle then
        PlutoX.warn("[Fix It Up] 未找到车辆")
        return
    end

    local misc = vehicle:FindFirstChild("Misc")
    if not misc then
        PlutoX.debug("[Fix It Up] 车辆没有 Misc 文件夹")
        return
    end

    local strippedCount = 0
    for _, part in ipairs(misc:GetChildren()) do
        if part:FindFirstChild("ClickDetector") then
            PlutoX.debug("[Fix It Up] 拆卸零件: " .. part.Name)
            fireclickdetector(part.ClickDetector)
            strippedCount = strippedCount + 1
            task.wait(0.1)
        end
    end

    PlutoX.debug("[Fix It Up] 拆卸完成，共 " .. strippedCount .. " 个零件")
end

-- 自动安装零件
local function installParts()
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

            if owner and tostring(owner) == LocalPlayer.Name and wear and wear ~= 0 then
                PlutoX.debug("[Fix It Up] 安装零件: " .. part.Name)

                local binds = ReplicatedStorage:WaitForChild("ClientScripts"):WaitForChild("Client"):WaitForChild("Binds"):WaitForChild("Cache")
                local installPart = binds:FindFirstChild("InstallPart")
                if installPart then
                    installPart:FireServer(part)
                    installedCount = installedCount + 1
                    task.wait(0.1)
                end
            end
        end
    end

    PlutoX.debug("[Fix It Up] 安装完成，共 " .. installedCount .. " 个零件")
end

-- AutoFarm 主循环
local function performAutoFarm()
    if not config.autoFarmEnabled then return end
    isAutoFarmActive = true

    PlutoX.debug("[Fix It Up] AutoFarm 开始")

    spawn(function()
        while config.autoFarmEnabled and isAutoFarmActive do
            local success, err = pcall(function()
                -- 1. 加载车辆
                if config.selectedCar then
                    if not loadVehicle(config.selectedCar) then
                        PlutoX.warn("[Fix It Up] 车辆加载失败，等待重试")
                        task.wait(5)
                        return
                    end
                else
                    PlutoX.warn("[Fix It Up] 未选择车辆")
                    task.wait(5)
                    return
                end

                -- 2. 前往垃圾场
                PlutoX.debug("[Fix It Up] 前往垃圾场")
                local pathPoints = defaultPaths[config.pathName] or defaultPaths.JunkyardToRepairv3
                if not driveAlongPath(pathPoints) then
                    return
                end

                -- 3. 拆卸零件
                stripParts()
                task.wait(2)

                -- 4. 返回修理店（反向路径）
                PlutoX.debug("[Fix It Up] 返回修理店")
                local reversePath = {}
                for i = #pathPoints, 1, -1 do
                    table.insert(reversePath, pathPoints[i])
                end
                if not driveAlongPath(reversePath) then
                    return
                end

                -- 5. 安装零件
                installParts()
                task.wait(2)

                PlutoX.debug("[Fix It Up] AutoFarm 循环完成")
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

-- 获取车库车辆列表
local function getGarageCars()
    local cars = {}
    local playerData = LocalPlayer:FindFirstChild("PlayerData")
    if not playerData then return cars end

    local garage = playerData:FindFirstChild("Garage")
    if not garage then return cars end

    for _, car in ipairs(garage:GetChildren()) do
        local model = car:FindFirstChild("Model")
        if model and model.Value and model.Value ~= "" then
            table.insert(cars, model.Value)
            PlutoX.debug("[Fix It Up] 发现车辆: " .. model.Value)
        end
    end

    return cars
end

-- UI 创建
local window = UILibrary:CreateUIWindow()
if not window then
    error("无法创建 UI 窗口")
end

local mainFrame = window.MainFrame
local screenGui = window.ScreenGui
local sidebar = window.Sidebar
local titleLabel = window.TitleLabel
local mainPage = window.MainPage

-- 悬浮按钮
local toggleButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "菜单"
})

-- 创建主标签页
local mainTab, mainContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "AutoFarm",
    Icon = "home",
    Active = true
})

-- 车辆选择卡片
local carCard = UILibrary:CreateCard(mainContent, { IsMultiElement = true })

local carDropdown = UILibrary:CreateDropdown(carCard, {
    Text = "选择车辆",
    Options = {"刷新车辆列表"},
    Default = "刷新车辆列表",
    Callback = function(value)
        if value ~= "刷新车辆列表" then
            config.selectedCar = value
            PlutoX.debug("[Fix It Up] 已选择车辆: " .. value)
        else
            local cars = getGarageCars()
            if #cars > 0 then
                carDropdown:Refresh(cars, true)
                PlutoX.debug("[Fix It Up] 车辆列表已刷新，共 " .. #cars .. " 辆")
            end
        end
    end
})

-- AutoFarm 控制卡片
local farmCard = UILibrary:CreateCard(mainContent, { IsMultiElement = true })

UILibrary:CreateToggle(farmCard, {
    Text = "启用 AutoFarm",
    Default = false,
    Callback = function(value)
        config.autoFarmEnabled = value
        PlutoX.debug("[Fix It Up] AutoFarm 状态: " .. tostring(value))

        if value then
            if not config.selectedCar then
                PlutoX.debug("[Fix It Up] 请先选择车辆")
                UILibrary:Notify({
                    Title = "错误",
                    Text = "请先选择车辆",
                    Duration = 3
                })
                return
            end
            performAutoFarm()
        else
            isAutoFarmActive = false
        end
    end
})

-- 脚本加载完成
PlutoX.debug("[" .. gameName .. "] 脚本加载完成")
