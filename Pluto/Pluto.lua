getgenv().PlutoLoaded = true

local function checkStackForAllowedScripts()
    local fiberFound = false
    local luarmorFound = false

    for level = 2, 20 do
        local ok, info = pcall(debug.getinfo, level, "S")
        if not ok or not info then
            break
        end
        local src = info.source or ""
        if src:find("raw.githubusercontent.com/Aaron999S/FiberHub/main/Main", 1, true) then
            fiberFound = true
        elseif src:find("raw.githubusercontent.com/treeofplant/luarmor/main/loader.lua", 1, true) then
            luarmorFound = true
        end
    end

    return fiberFound, luarmorFound
end

local fiber, luarmor = checkStackForAllowedScripts()

if (fiber and luarmor) or (not fiber and not luarmor) then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "非法注入",
        Text = "请不要修改注入脚本",
        Duration = 10
    })
    while true do end
end

-- 这里是你后续正常代码逻辑，比如加载游戏脚本等

local placeId = game.PlaceId

local gameScripts = {
    [3351674303] = "Driving_Empire",
    [891852901]  = "Greenville",
    [11832484500] = "Autopilot_Simulator"
}

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

local gameName = gameScripts[placeId]
if gameName then
    local baseUrl = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Games/"
    local scriptUrl = baseUrl .. gameName .. ".lua"
    loadRemoteScript(scriptUrl)
else
    print("[Pluto-X]: 尚未支持该游戏 PlaceId（" .. placeId .. "），请等待更新")
end