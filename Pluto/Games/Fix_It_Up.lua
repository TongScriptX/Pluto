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
local config = {}

local LocalPlayer = Players.LocalPlayer

-- 获取玩家车辆
local function getPlayerVehicle()
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then
        PlutoX.debug("[Fix It Up] 未找到 Vehicles 文件夹")
        return nil
    end

    for _, vehicle in ipairs(vehicles:GetChildren()) do
        local owner = vehicle:GetAttribute("Owner")
        if owner and tostring(owner) == LocalPlayer.Name then
            PlutoX.debug("[Fix It Up] 找到玩家车辆")
            return vehicle
        end
    end

    PlutoX.debug("[Fix It Up] 未找到玩家车辆")
    return nil
end

-- AutoFarm 主循环
local isFarming = false
local platformFolder = nil
local farmTask = nil

local function stopAutoFarm()
    isFarming = false
    if farmTask then
        task.cancel(farmTask)
        farmTask = nil
    end
    if platformFolder then
        platformFolder:Destroy()
        platformFolder = nil
    end
end

local function performAutoFarm()
    PlutoX.debug("[Fix It Up] performAutoFarm 开始执行")

    -- 查找玩家车辆
    PlutoX.debug("[Fix It Up] 开始查找玩家车辆...")
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then
        PlutoX.debug("[Fix It Up] 未找到 Vehicles 文件夹")
        UILibrary:Notify({Title="AutoFarm错误", Text="未找到车辆文件夹", Duration=5})
        stopAutoFarm()
        return
    end

    PlutoX.debug("[Fix It Up] Vehicles 文件夹存在，子对象数量: " .. #vehicles:GetChildren())

    local carModel = nil
    for _, vehicle in ipairs(vehicles:GetChildren()) do
        local owner = vehicle:GetAttribute("Owner")
        PlutoX.debug("[Fix It Up] 检查车辆: " .. vehicle.Name .. ", Owner: " .. tostring(owner) .. ", LocalPlayer.Name: " .. LocalPlayer.Name)
        if owner and tostring(owner) == LocalPlayer.Name then
            carModel = vehicle
            PlutoX.debug("[Fix It Up] 找到玩家车辆: " .. vehicle.Name)
            break
        end
    end

    if not carModel then
        PlutoX.debug("[Fix It Up] 未找到玩家车辆，请先进入车辆")
        UILibrary:Notify({Title="AutoFarm错误", Text="请先进入车辆", Duration=5})
        stopAutoFarm()
        return
    end

    local driveSeat = carModel:FindFirstChild("DriveSeat")
    if not driveSeat then
        PlutoX.debug("[Fix It Up] 未找到 DriveSeat")
        UILibrary:Notify({Title="AutoFarm错误", Text="未找到驾驶座位", Duration=5})
        stopAutoFarm()
        return
    end

    PlutoX.debug("[Fix It Up] 找到 DriveSeat，位置: " .. tostring(driveSeat.Position))

    carModel.PrimaryPart = driveSeat
    PlutoX.debug("[Fix It Up] 设置 PrimaryPart 完成")

    -- 创建平台
    PlutoX.debug("[Fix It Up] 开始创建平台...")
    platformFolder = Instance.new("Folder", Workspace)
    platformFolder.Name = "AutoPlatform"

    local platform = Instance.new("Part", platformFolder)
    platform.Anchored = true
    platform.Size = Vector3.new(100000, 10, 10000)
    platform.BrickColor = BrickColor.new("Dark stone grey")
    platform.Material = Enum.Material.SmoothPlastic
    platform.Position = Vector3.new(
        driveSeat.Position.X + 50000,
        driveSeat.Position.Y + 5,
        driveSeat.Position.Z
    )

    PlutoX.debug("[Fix It Up] 平台创建完成，位置: " .. tostring(platform.Position))

    local originPos = Vector3.new(
        driveSeat.Position.X,
        platform.Position.Y + 5000,
        driveSeat.Position.Z
    )
    PlutoX.debug("[Fix It Up] 起始位置: " .. tostring(originPos))

    local speed = 600
    local interval = 0.05
    local distancePerTick = speed * interval
    local currentPosX = originPos.X
    local lastTpTime = tick()

    PlutoX.debug("[Fix It Up] 传送车辆到起始位置...")
    carModel:PivotTo(CFrame.new(originPos, originPos + Vector3.new(1, 0, 0)))
    PlutoX.debug("[Fix It Up] 车辆传送完成")

    isFarming = true
    PlutoX.debug("[Fix It Up] 启动 farmTask...")
    farmTask = task.spawn(function()
        PlutoX.debug("[Fix It Up] farmTask 开始运行")
        while isFarming do
            currentPosX = currentPosX + distancePerTick
            local pos = Vector3.new(currentPosX, originPos.Y, originPos.Z)
            carModel:PivotTo(CFrame.new(pos, pos + Vector3.new(1, 0, 0)))

            if carModel.PrimaryPart then
                carModel.PrimaryPart.Velocity = Vector3.zero
                carModel.PrimaryPart.RotVelocity = Vector3.zero
            end

            if tick() - lastTpTime > 5 then
                PlutoX.debug("[Fix It Up] 重置位置")
                currentPosX = originPos.X
                carModel:PivotTo(CFrame.new(Vector3.new(currentPosX, originPos.Y, originPos.Z), Vector3.new(currentPosX + 1, originPos.Y, originPos.Z)))
                lastTpTime = tick()
            end

            task.wait(interval)
        end
        PlutoX.debug("[Fix It Up] farmTask 结束")
        if platformFolder then
            platformFolder:Destroy()
            platformFolder = nil
        end
    end)

    PlutoX.debug("[Fix It Up] AutoFarm 已启动")
end

-- 获取车库车辆列表
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

-- AutoFarm 控制卡片
local farmCard = UILibrary:CreateCard(mainContent, { IsMultiElement = true })

UILibrary:CreateLabel(farmCard, {
    Text = "请先进入车辆，然后启用 AutoFarm"
})

UILibrary:CreateToggle(farmCard, {
    Text = "启用 AutoFarm",
    DefaultState = false,
    Callback = function(value)
        if value then
            isFarming = true
            performAutoFarm()
        else
            stopAutoFarm()
        end
    end
})

-- 脚本加载完成
PlutoX.debug("[" .. gameName .. "] 脚本加载完成")
