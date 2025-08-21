-- ConsoleUI.lua
local module = {}

function module.CreateUI(playerGui)
    local gui = Instance.new("ScreenGui", playerGui)
    gui.Name = "OneTimeConsoleGui"
    gui.ResetOnSpawn = false

    -- 主框架
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0.8, 0, 0.5, 0)
    frame.Position = UDim2.new(0.1, 0, 0.25, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.Visible = false

    local scroll = Instance.new("ScrollingFrame", frame)
    scroll.Size = UDim2.new(1, 0, 0.85, 0)
    scroll.ScrollBarThickness = 6
    scroll.BackgroundTransparency = 1
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

    -- UIListLayout
    local layout = Instance.new("UIListLayout", scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)

    local copyBtn = Instance.new("TextButton", frame)
    copyBtn.Size = UDim2.new(0, 140, 0, 40)
    copyBtn.Position = UDim2.new(1, -150, 0.85, 0)
    copyBtn.Text = "复制并清空"
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

    local floatBtn = Instance.new("TextButton", gui)
    floatBtn.Size = UDim2.new(0, 60, 0, 60)
    floatBtn.Position = UDim2.new(0, 20, 0.7, 0)
    floatBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    floatBtn.Text = "≡"
    floatBtn.TextSize = 24

    -- 拖动逻辑
    local dragging, dragInput, dragStart, startPos
    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = floatBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    floatBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            floatBtn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    floatBtn.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)

    return {
        Gui = gui,
        Frame = frame,
        CopyBtn = copyBtn,
        Notice = notice,
        Scroll = scroll
    }
end

return module