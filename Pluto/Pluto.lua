-- Main script
local NotificationHolder = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Module.Lua"))()
local Notification = loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/UI/main/STX/Client.Lua"))()

local whitelistScript = game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/main/Pluto/whitelist.lua")
if not whitelistScript or whitelistScript == "" then
    print("获取白名单失败")
else
    local whitelistFunction = loadstring(whitelistScript)
    if not whitelistFunction then
        print("加载白名单失败")
    else
        local whitelist = whitelistFunction()
        print(type(whitelist))  -- 打印类型

        local customerlist = {
            -- 顾客名单
        }

        local player = game.Players.LocalPlayer
        local playerName = player.Name
        local isInWhitelist = false
        local isInCustomer = false

        for _, allowedName in ipairs(whitelist) do
            if playerName == allowedName then
                isInWhitelist = true
                break
            end
        end

        for _, customerName in ipairs(customerlist) do
            if playerName == customerName then
                isInCustomer = true
                break
            end
        end

        if isInCustomer then
            Notification:Notify(
            {Title = "Pluto", Description = "检测到顾客名单,正在加载"},
            {OutlineColor = Color3.fromRGB(74, 78, 105), Time = 5, Type = "image"},
            {Image = "http://www.roblox.com/asset/?id=6023426923", ImageColor = Color3.fromRGB(74, 78, 105)}
        )
        end

        if isInWhitelist then
            Notification:Notify(
            {Title = "Pluto", Description = "检测admin名单,正在加载"},
            {OutlineColor = Color3.fromRGB(74, 78, 105), Time = 5, Type = "image"},
            {Image = "http://www.roblox.com/asset/?id=6023426923", ImageColor = Color3.fromRGB(74, 78, 105)}
            )
        end

        if isInWhitelist or isInCustomer then

            game.Players.PlayerAdded:Connect(
                function(player)
                    local owner = player.Name
                    if owner == "tongguheren090325" or owner == "Tongdscsh" then
                        Notification:Notify(
                        {Title = "Pluto", Description = "Pluto作者-Tong进入了服务器"},
                        {OutlineColor = Color3.fromRGB(74, 78, 105), Time = 5, Type = "image"},
                        {Image = "http://www.roblox.com/asset/?id=6023426923", ImageColor = Color3.fromRGB(74, 78, 105)}
                        )
                    end
                end
            )
            print("hello pluto")
        else
            game.Players.LocalPlayer:Kick("未检测到白名单")
        end
    end
end
