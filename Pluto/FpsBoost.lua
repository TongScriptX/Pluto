-- Android Roblox FPS Booster + FPS 显示 + 提升比较
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 创建 GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FPSBoosterGui"
screenGui.Parent = playerGui

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0, 140, 0, 30)
fpsLabel.Position = UDim2.new(0, 10, 0, 10)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
fpsLabel.TextColor3 = Color3.new(1, 1, 1)
fpsLabel.Font = Enum.Font.SourceSansBold
fpsLabel.TextScaled = true
fpsLabel.Text = "FPS: ..."
fpsLabel.Parent = screenGui

local boostLabel = Instance.new("TextLabel")
boostLabel.Size = UDim2.new(0, 220, 0, 30)
boostLabel.Position = UDim2.new(0, 10, 0, 45)
boostLabel.BackgroundTransparency = 0.5
boostLabel.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
boostLabel.TextColor3 = Color3.new(0, 1, 0)
boostLabel.Font = Enum.Font.SourceSans
boostLabel.TextScaled = true
boostLabel.Text = "优化效果检测中..."
boostLabel.Parent = screenGui

-- FPS 平均记录函数
local function getAverageFPS(duration)
	local frameCount = 0
	local start = tick()
	local lastTime = tick()

	local connection
	connection = RunService.RenderStepped:Connect(function()
		frameCount += 1
		local now = tick()
		if now - lastTime >= 1 then
			fpsLabel.Text = "FPS: " .. math.floor(frameCount / (now - start))
			lastTime = now
		end
	end)

	task.wait(duration)
	connection:Disconnect()

	local elapsed = tick() - start
	local averageFPS = frameCount / elapsed
	return averageFPS
end

-- 🔹 获取原始 FPS
local baseFPS = getAverageFPS(5)

-- ➤ FPS 优化逻辑开始
local root = workspace:FindFirstChild("MapRoot") or workspace
local function optimize(obj)
	pcall(function()
		if obj:IsA("Decal") or obj:IsA("Texture")
			or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Sparkles")
		then obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Material = Enum.Material.SmoothPlastic
			obj.Reflectance = 0
			obj.CastShadow = false
		end
	end)
end

for i,obj in ipairs(root:GetDescendants()) do
	optimize(obj)
	if i % 50 == 0 then task.wait() end
end

workspace.DescendantAdded:Connect(function(obj)
	task.defer(optimize, obj)
end)

-- Lighting 优化
local L = game:GetService("Lighting")
L.GlobalShadows = false
L.FogEnd = 1e9
L.Brightness = 0.5
L.OutdoorAmbient = Color3.new(0,0,0)
for _,name in ipairs({"BloomEffect","DepthOfFieldEffect","ColorCorrectionEffect","SunRaysEffect","BlurEffect"}) do
	local e = L:FindFirstChild(name)
	if e then e.Enabled = false end
end

-- FPS 解锁
if setfpscap then setfpscap(999) end

-- Lua 垃圾清理
task.spawn(function()
	while task.wait(10) do
		collectgarbage("collect")
	end
end)

-- 🔹 获取优化后 FPS
local optimizedFPS = getAverageFPS(5)

-- 计算提升
local diff = math.floor(optimizedFPS - baseFPS)
local percent = math.floor((diff / baseFPS) * 100)
local status = diff > 0 and "↑" or (diff < 0 and "↓" or "≈")
boostLabel.Text = string.format("FPS 提升：%s%d (约 %s%d%%)", status, math.abs(diff), status, math.abs(percent))

print("✅ Android FPS Booster + 提升比较已激活")