local placeId = game.PlaceId

local DRIVING_EMPIRE_ID = 3351674303
local GREENVILLE_ID = 891852901

local function loadRemoteScript(url)
    local success, res = pcall(function()
        return game:HttpGet(url)
    end)
    if success then
        local func, err = loadstring(res)
        if func then
            func()
        else
            warn("loadstring解析失败：", err)
        end
    else
        warn("HttpGet请求失败：", res)
    end
end

if placeId == DRIVING_EMPIRE_ID then
    loadRemoteScript("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Games/Driving_Empire.lua")
elseif placeId == GREENVILLE_ID then
    loadRemoteScript("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Games/Greenville.lua")
else
    print("[Pluto-X]: 尚未支持，请等待")
end