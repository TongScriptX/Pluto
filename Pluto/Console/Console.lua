local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/Console/ConsoleUI.lua"

-- Http请求获取UI代码
local success, uiCode = pcall(function()
    return game:HttpGet(url)
end)

if not success then
    warn("无法从GitHub加载UI代码")
    return
end

-- 运行UI代码，得到模块
local uiModule = loadstring(uiCode)()
local ui = uiModule.CreateUI(playerGui)

-- 清除旧日志
LogService:ClearOutput()

local output = ""
local conn = LogService.MessageOut:Connect(function(msg, msgType)
    output ..= ("[%s] %s\n"):format(msgType.Name, msg)
    ui.TextBox.Text = output
--  ui.TextBox.CursorPosition = #output + 1
--  ui.Scroll.CanvasPosition = Vector2.new(0, 1e9)
end)

local function trySetClipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    elseif syn and syn.set_clipboard then
        syn.set_clipboard(text)
        return true
    elseif clipboard and clipboard.set then
        clipboard.set(text)
        return true
    end
    return false
end

ui.CopyBtn.MouseButton1Click:Connect(function()
    if conn then conn:Disconnect() end

    local success = trySetClipboard(output)
    if success then
        ui.Notice.Text = "✅ 日志已复制到剪贴板"
    else
        ui.Notice.Text = "⚠️ 无法自动复制，请手动复制文本"
        ui.TextBox:CaptureFocus()
        ui.TextBox.SelectionStart = 1
        ui.TextBox.CursorPosition = #output + 1
    end

    task.delay(1.2, function()
        ui.Gui:Destroy()
    end)
end)