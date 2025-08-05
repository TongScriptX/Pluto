-- ConsoleUI.lua
local module = {}

function module.CreateUI(playerGui)
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
    -- 禁止聚焦编辑
    textBox.Focused:Connect(function() textBox:ReleaseFocus() end)

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

    return {
        Gui = gui,
        TextBox = textBox,
        CopyBtn = copyBtn,
        Notice = notice,
        Scroll = scroll
    }
end

return module