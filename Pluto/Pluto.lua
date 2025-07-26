getgenv().PlutoLoaded = true

local function kill(reason)
    while true do end
end

local function checkStackForAllowedScripts()
    local fiberFound = false
    local luarmorFound = false
    local plutoFound = false
    local validPlutoCall = false

    for level = 2, 20 do
        local ok, info = pcall(debug.getinfo, level, "Sl")
        if not ok or not info then break end

        local src = tostring(info.source or "")
        local linedefined = info.linedefined or 0

        if src:find("raw.githubusercontent.com/Aaron999S/FiberHub/main/Main", 1, true) then
            fiberFound = true
        elseif src:find("raw.githubusercontent.com/treeofplant/luarmor/main/loader.lua", 1, true) then
            luarmorFound = true
        elseif src:find("pluto%-x%.vercel%.app") then
            plutoFound = true
            if linedefined <= 1 then
                validPlutoCall = true
            end
        end
    end

    if not plutoFound or not validPlutoCall then
        kill("非法注入：不要修改注入脚本")
    end

    if fiberFound and luarmorFound then
        kill("非法注入：检测到同时加载 Fiber 和 Luarmor")
    end

    if not fiberFound and not luarmorFound then
        -- Pluto 必须是干净 loadstring 注入（getgenv允许，但不能附加其他行为）
        -- 前面已经确认是干净调用，如果不是，就已经 kill 掉了
        -- 所以这里无需再判断
    end
end

checkStackForAllowedScripts()

-- Pluto 主体逻辑
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
        end
    end
end

local gameName = gameScripts[placeId]
if gameName then
    local baseUrl = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Games/"
    local scriptUrl = baseUrl .. gameName .. ".lua"
    loadRemoteScript(scriptUrl)
end