-- 自动检测并加载脚本的主入口
local HttpService = game:GetService("HttpService")
local placeId = game.PlaceId

-- 在这里替换为这两个游戏的真实 PlaceId
local DRIVING_EMPIRE_ID = 3351674303 
local GREENVILLE_ID = 891852901

-- 加载远程脚本的通用函数
local function loadRemoteScript(url)
    local success, res = pcall(function()
        return HttpService:GetAsync(url)
    end)
    if success then
        local func, err = loadstring(res)
        if func then
            func()
        else
            warn("loadstring 解析失败：", err)
        end
    else
        warn("GET 脚本失败：", res)
    end
end

-- 主检测流程
if placeId == DRIVING_EMPIRE_ID then
    loadRemoteScript("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Notifier/Driving_Empire.lua")
elseif placeId == GREENVILLE_ID then
    loadRemoteScript("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Notifier/Greenville.lua")
else
    -- 非目标游戏，不做任何操作
end