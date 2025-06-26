local Players = game:GetService("Players")
local LogService = game:GetService("LogService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 清除旧日志
LogService:ClearOutput()

-- 创建 GUI
local gui = Instance.new("ScreenGui", playerGui)
gui.Name = "OneTimeConsoleGui"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0.8, 0, 0.5, 0)
frame.Position = UDim2.new(0.1, 0, 0.25, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

local scroll = Instance.new("ScrollingFrame", frame)
scroll.Size = UDim2.new(1, 0, 0.85, 0)
scroll.CanvasSize = UDim2.new(0, 0, 10, 0)
scroll.ScrollBarThickness = 6
scroll.BackgroundTransparency = 1

local textBox = Instance.new("TextBox", scroll)
textBox.Size = UDim2.new(1, 0, 1, 0)
textBox.ClearTextOnFocus = false
textBox.TextEditable = false
textBox.TextWrapped = true
textBox.TextColor3 = Color3.fromRGB(240, 240, 240)
textBox.Font = Enum.Font.Code
textBox.TextSize = 14
textBox.BackgroundTransparency = 1
textBox.TextXAlignment = Enum.TextXAlignment.Left
textBox.TextYAlignment = Enum.TextYAlignment.Top

local copyBtn = Instance.new("TextButton", frame)
copyBtn.Size = UDim2.new(0, 140, 0, 40)
copyBtn.Position = UDim2.new(1, -150, 0.85, 0)
copyBtn.Text = "复制并关闭"
copyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

local notice = Instance.new("TextLabel", frame)
notice.Size = UDim2.new(0.6, 0, 0, 30)
notice.Position = UDim2.new(0.02, 0, 0.85, 0)
notice.BackgroundTransparency = 1
notice.TextColor3 = Color3.fromRGB(255, 255, 0)
notice.Font = Enum.Font.Code
notice.TextSize = 14
notice.TextXAlignment = Enum.TextXAlignment.Left
notice.Text = ""

-- 捕获日志输出
local output = ""
local conn = LogService.MessageOut:Connect(function(msg, msgType)
	output ..= ("[%s] %s\n"):format(msgType.Name, msg)
	textBox.Text = output
	textBox.CursorPosition = #output + 1
	scroll.CanvasPosition = Vector2.new(0, 1e9)
end)

-- 复制剪贴板兼容处理
local function trySetClipboard(text)
	local success = false
	if setclipboard then
		setclipboard(text)
		success = true
	elseif syn and syn.set_clipboard then
		syn.set_clipboard(text)
		success = true
	elseif clipboard and clipboard.set then
		clipboard.set(text)
		success = true
	end
	return success
end

-- 点击复制按钮逻辑
copyBtn.MouseButton1Click:Connect(function()
	if conn then conn:Disconnect() end

	local success = trySetClipboard(output)
	if success then
		notice.Text = "✅ 日志已复制到剪贴板"
	else
		notice.Text = "⚠️ 无法自动复制，请手动复制文本"
		textBox:CaptureFocus()
		textBox.SelectionStart = 1
		textBox.CursorPosition = #output + 1
	end

	-- 1秒后关闭 UI
	task.delay(1.2, function()
		gui:Destroy()
	end)
end)
