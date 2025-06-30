-- Android Roblox FPS Booster + FPS 显示
-- Wait for game
if not game:IsLoaded() then game.Loaded:Wait() end

-- 根目录
local root = workspace:WaitForChild("MapRoot",5) or workspace

-- 优化函数
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

-- 批量优化
local all = root:GetDescendants()
for i,obj in ipairs(all) do
  optimize(obj)
  if i % 50 == 0 then task.wait() end
end

-- 监听新增物件
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

-- 终极 FPS 解锁
if setfpscap then setfpscap(999) end

-- FPS 显示
-- Create ScreenGui & TextLabel
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FPSBoosterGui"
screenGui.Parent = playerGui
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Name = "FPSLabel"
fpsLabel.Size = UDim2.new(0, 100, 0, 25)
fpsLabel.Position = UDim2.new(0, 10, 0, 10)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
fpsLabel.TextColor3 = Color3.new(1, 1, 1)
fpsLabel.Font = Enum.Font.SourceSansBold
fpsLabel.TextScaled = true
fpsLabel.Text = "FPS: 0"
fpsLabel.Parent = screenGui

-- 计算与更新 FPS
local frameCount = 0
local lastTime = tick()
RunService.RenderStepped:Connect(function(delta)
  frameCount = frameCount + 1
  local now = tick()
  if now - lastTime >= 1 then
    local fps = math.floor(frameCount / (now - lastTime))
    fpsLabel.Text = "FPS: " .. fps
    frameCount = 0
    lastTime = now
  end
end)

-- Lua 内存清理
task.spawn(function()
  while task.wait(10) do
    collectgarbage("collect")
  end
end)

print("FPS Booster + FPS 显示 已激活")