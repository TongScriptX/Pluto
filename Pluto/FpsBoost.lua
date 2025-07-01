-- Android Roblox FPS Booster + 延迟批次 + FPS 提升显示
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
fpsLabel.Size = UDim2.new(0, 120, 0, 30)
fpsLabel.Position = UDim2.new(0, 10, 0, 10)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.BackgroundColor3 = Color3.new(0,0,0)
fpsLabel.TextColor3 = Color3.new(1,1,1)
fpsLabel.Font = Enum.Font.SourceSansBold
fpsLabel.TextScaled = true
fpsLabel.Text = "FPS: ..."
fpsLabel.Parent = screenGui

local boostLabel = Instance.new("TextLabel")
boostLabel.Size = UDim2.new(0, 240, 0, 30)
boostLabel.Position = UDim2.new(0, 10, 0, 45)
boostLabel.BackgroundTransparency = 0.5
boostLabel.BackgroundColor3 = Color3.new(0.1,0.1,0.1)
boostLabel.TextColor3 = Color3.new(0,1,0)
boostLabel.Font = Enum.Font.SourceSans
boostLabel.TextScaled = true
boostLabel.Text = "优化效果检测中..."
boostLabel.Parent = screenGui

-- 平均 FPS 计算函数
local function getAverageFPS(duration)
  local count, startT, lastT = 0, tick(), tick()
  local conn = RunService.RenderStepped:Connect(function()
    count += 1
    local now = tick()
    if now - lastT >= 1 then
      fpsLabel.Text = "FPS: " .. math.floor(count / (now - startT))
      lastT = now
    end
  end)
  task.wait(duration)
  conn:Disconnect()
  return count / (tick() - startT)
end

-- 🔹 获取优化前 FPS
local baseFPS = getAverageFPS(5)

-- ✅ 优化逻辑：延迟隐藏 + 分帧销毁
local root = workspace:FindFirstChild("MapRoot") or workspace
local toDestroy = {}

for _,obj in ipairs(root:GetDescendants()) do
  if obj:IsA("Decal") or obj:IsA("Texture")
    or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Sparkles") then
    obj.Transparency = 1 -- 先隐藏
    table.insert(toDestroy, obj)
  elseif obj:IsA("BasePart") then
    obj.Material = Enum.Material.SmoothPlastic
    obj.Reflectance = 0
    obj.CastShadow = false
  end
end

-- 分批销毁
task.spawn(function()
  for i,obj in ipairs(toDestroy) do
    task.defer(function()
      if obj and obj.Parent then obj:Destroy() end
    end)
    if i % 30 == 0 then task.wait() end
  end
end)

workspace.DescendantAdded:Connect(function(obj)
  task.defer(function()
    if obj:IsA("Decal") or obj:IsA("Texture")
      or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Sparkles") then
      obj.Transparency = 1
      task.wait()
      if obj.Parent then obj:Destroy() end
    elseif obj:IsA("BasePart") then
      obj.Material = Enum.Material.SmoothPlastic
      obj.Reflectance = 0
      obj.CastShadow = false
    end
  end)
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

-- 垃圾回收
task.spawn(function()
  while task.wait(10) do
    collectgarbage("collect")
  end
end)

-- 🔹 获取优化后 FPS
local optimizedFPS = getAverageFPS(5)

-- 计算并显示提升
local diff = math.floor(optimizedFPS - baseFPS)
local perc = math.floor((diff / baseFPS) * 100)
local sym = diff > 0 and "↑" or (diff < 0 and "↓" or "≈")
boostLabel.Text = string.format("FPS 提升：%s%d (%s%d%%)", sym, math.abs(diff), sym, math.abs(perc))

print("✅ 延迟批次优化 + FPS 对比 已激活")