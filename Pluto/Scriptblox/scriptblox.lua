local HttpService = game:GetService("HttpService")

-- 安全加载 Pluto UI 库
local url = "https://raw.githubusercontent.com/TongScriptX/Pluto/main/Pluto/UILibrary/PlutoUILibrary.lua"

local content
local success, err = pcall(function()
    content = game:HttpGet(url)
end)
if not success or not content or content == "" then
    error("获取 UI 库失败：" .. tostring(err))
end

local func, err2 = loadstring(content)
if not func then
    error("编译 UI 库失败：" .. tostring(err2))
end

local success2, UILibrary = pcall(func)
if not success2 or type(UILibrary) ~= "table" then
    error("执行 UI 库失败，或者返回结果非法")
end

-- 创建主窗口
local window = UILibrary:CreateUIWindow()
assert(window, "创建窗口失败")

local mainFrame = window.MainFrame
local screenGui = window.ScreenGui
local sidebar = window.Sidebar
local titleLabel = window.TitleLabel
local mainPage = window.MainPage

UILibrary:MakeDraggable(mainFrame)

-- 创建悬浮按钮，用来显示/隐藏主窗口
local floatingButton = UILibrary:CreateFloatingButton(screenGui, {
    MainFrame = mainFrame,
    Text = "菜单"
})

-- 搜索标签页
local tabBtn, tabContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "ScriptBlox 搜索",
    Active = true,
})

-- 搜索输入卡片
local searchCard = UILibrary:CreateCard(tabContent, { IsMultiElement = true })

local searchBox = UILibrary:CreateTextBox(searchCard, {
    PlaceholderText = "输入关键词搜索脚本",
})

local searchBtn = UILibrary:CreateButton(searchCard, {
    Text = "搜索",
    Callback = function()
        local query = searchBox.Text
        if not query or query == "" then
            warn("请输入搜索关键词")
            return
        end
        doSearch(query)
    end,
})

-- 搜索结果滚动区
local resultsScrollingFrame = Instance.new("ScrollingFrame")
resultsScrollingFrame.Parent = tabContent
resultsScrollingFrame.Size = UDim2.new(1, -10, 1, -130)
resultsScrollingFrame.Position = UDim2.new(0, 5, 0, 120)
resultsScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
resultsScrollingFrame.ScrollBarThickness = 6
resultsScrollingFrame.BackgroundTransparency = 1

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = resultsScrollingFrame
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Padding = UDim.new(0, 5)

local function clearResults()
    for _, child in pairs(resultsScrollingFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local currentScripts = {}

-- 已保存脚本相关函数
local function readSavedScripts()
    if not isfile or not readfile then
        warn("当前执行器不支持读写文件")
        return {}
    end

    if not isfile("Pluto_X_Scriptblox.json") then
        return {}
    end

    local content = readfile("Pluto_X_Scriptblox.json")
    local ok, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if ok and type(data) == "table" then
        return data
    else
        warn("读取保存脚本失败或格式错误")
        return {}
    end
end

local function appendSavedScript(sc)
    if not writefile or not isfile or not readfile then
        UILibrary:Notify({
            Title = "错误",
            Text = "当前执行器不支持文件写入",
            Duration = 3
        })
        return false
    end

    local saved = {}
    if isfile("Pluto_X_Scriptblox.json") then
        local content = readfile("Pluto_X_Scriptblox.json")
        local ok, data = pcall(function()
            return HttpService:JSONDecode(content)
        end)
        if ok and type(data) == "table" then
            saved = data
        end
    end

    -- 防止重复保存（根据 id）
    for _, v in ipairs(saved) do
        if v.id == sc.id then
            UILibrary:Notify({
                Title = "提示",
                Text = "脚本已存在，无需重复保存",
                Duration = 3
            })
            return true
        end
    end

    table.insert(saved, {
        id = sc.id,
        title = sc.title,
        game = sc.game,
        views = sc.views,
        script = sc.script,
    })

    local jsonText = HttpService:JSONEncode(saved)
    local ok, err = pcall(function()
        writefile("Pluto_X_Scriptblox.json", jsonText)
    end)
    if not ok then
        UILibrary:Notify({
            Title = "保存失败",
            Text = tostring(err),
            Duration = 3
        })
        return false
    end
    return true
end

-- 搜索函数
function doSearch(keyword)
    clearResults()
    currentScripts = {}
    local url = "https://scriptblox.com/api/script/search?q=" .. HttpService:UrlEncode(keyword) .. "&max=10&page=1"
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok then
        warn("搜索请求失败:", res)
        return
    end

    local success, data = pcall(function()
        return HttpService:JSONDecode(res)
    end)
    if not success or not data or not data.result or not data.result.scripts then
        warn("脚本数据解析失败或字段缺失")
        return
    end

    for index, sc in ipairs(data.result.scripts) do
        table.insert(currentScripts, sc)

        local card = UILibrary:CreateCard(resultsScrollingFrame, { IsMultiElement = true })
        card.Size = UDim2.new(1, 0, 0, 90)
        card.LayoutOrder = index

        UILibrary:CreateLabel(card, { Text = sc.title or "无标题", TextSize = 14 })
        UILibrary:CreateLabel(card, { Text = "游戏: " .. (sc.game and sc.game.name or "未知"), TextSize = 12 })
        UILibrary:CreateLabel(card, { Text = "浏览量: " .. tostring(sc.views or 0), TextSize = 12 })

        local injectBtn = UILibrary:CreateButton(card, {
            Text = "注入脚本",
            Position = UDim2.new(0, 5, 1, -35),
            Size = UDim2.new(0, 90, 0, 30),
            Callback = function()
                if sc.script and #sc.script > 0 then
                    local func, err = loadstring(sc.script)
                    if func then
                        pcall(func)
                        UILibrary:Notify({
                            Title = "注入成功",
                            Text = sc.title or "无标题",
                            Duration = 3
                        })
                    else
                        UILibrary:Notify({
                            Title = "注入失败",
                            Text = err or "未知错误",
                            Duration = 3
                        })
                    end
                else
                    UILibrary:Notify({
                        Title = "注入失败",
                        Text = "该脚本无脚本内容，无法注入",
                        Duration = 3
                    })
                end
            end
        })

        local saveBtn = UILibrary:CreateButton(card, {
            Text = "保存脚本",
            Position = UDim2.new(0, 105, 1, -35),
            Size = UDim2.new(0, 90, 0, 30),
            Callback = function()
                if not sc.script or #sc.script == 0 then
                    UILibrary:Notify({
                        Title = "保存失败",
                        Text = "该脚本无脚本内容，无法保存",
                        Duration = 3
                    })
                    return
                end
                local ok = appendSavedScript(sc)
                if ok then
                    UILibrary:Notify({
                        Title = "保存成功",
                        Text = "脚本《" .. (sc.title or "无标题") .. "》已保存",
                        Duration = 3
                    })
                end
            end
        })
    end

    local contentHeight = (#data.result.scripts) * (90 + 5) + 5
    resultsScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end

-- 已保存脚本标签页
-- 创建已保存脚本标签页
local savedTabBtn, savedTabContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "已保存脚本",
    Active = false,
})

-- 确保有 UIListLayout
local uiListLayout = savedTabContent:FindFirstChildOfClass("UIListLayout")
if not uiListLayout then
    uiListLayout = Instance.new("UIListLayout")
    uiListLayout.Parent = savedTabContent
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 5)
end

-- 刷新按钮变量
local refreshBtn

local function refreshSavedList()
    -- 清理之前的所有 Frame 和按钮（除了非 Frame 的 UI 例如 Layout）
    for _, child in pairs(savedTabContent:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    -- 创建刷新按钮，LayoutOrder设为0确保排最前面
    refreshBtn = UILibrary:CreateButton(savedTabContent, {
        Text = "刷新列表",
        Size = UDim2.new(0, 100, 0, 30),
        LayoutOrder = 0,
        Callback = function()
            refreshSavedList()
            UILibrary:Notify({
                Title = "已刷新",
                Text = "已保存脚本列表已更新",
                Duration = 2,
            })
        end,
    })

    local savedScripts = readSavedScripts() or {}

    for i, sc in ipairs(savedScripts) do
        local card = UILibrary:CreateCard(savedTabContent, { IsMultiElement = true })
        card.Size = UDim2.new(1, -10, 0, 90)
        card.LayoutOrder = i + 1 -- 刷新按钮在最上，脚本从1开始往后排

        UILibrary:CreateLabel(card, {
            Text = sc.title or "无标题",
            TextSize = 14,
            Position = UDim2.new(0, 10, 0, 10),
            Size = UDim2.new(0.6, -10, 0, 25),
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        UILibrary:CreateLabel(card, {
            Text = "已保存",
            TextSize = 12,
            Position = UDim2.new(0, 10, 0, 40),
            Size = UDim2.new(0.6, -10, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        UILibrary:CreateButton(card, {
            Text = "注入",
            Position = UDim2.new(0.6, 10, 0, 15),
            Size = UDim2.new(0.15, -10, 0, 30),
            Callback = function()
                if sc.script and #sc.script > 0 then
                    local func, err = loadstring(sc.script)
                    if func then
                        pcall(func)
                        UILibrary:Notify({
                            Title = "注入成功",
                            Text = sc.title or "无标题",
                            Duration = 3,
                        })
                    else
                        UILibrary:Notify({
                            Title = "注入失败",
                            Text = err or "未知错误",
                            Duration = 3,
                        })
                    end
                else
                    UILibrary:Notify({
                        Title = "注入失败",
                        Text = "无脚本内容",
                        Duration = 3,
                    })
                end
            end,
        })

        UILibrary:CreateButton(card, {
            Text = "删除",
            Position = UDim2.new(0.78, 10, 0, 15),
            Size = UDim2.new(0.15, -10, 0, 30),
            Callback = function()
                local saved = readSavedScripts()
                if saved then
                    for idx, v in ipairs(saved) do
                        if v.title == sc.title and v.script == sc.script then
                            table.remove(saved, idx)
                            break
                        end
                    end
                    local HttpService = game:GetService("HttpService")
                    writefile("Pluto_X_Scriptblox.json", HttpService:JSONEncode(saved))
                    UILibrary:Notify({
                        Title = "删除成功",
                        Text = sc.title or "无标题",
                        Duration = 3,
                    })
                    refreshSavedList()
                end
            end,
        })
    end

    local totalHeight = (#savedScripts + 1) * (90 + 5) + 10
    savedTabContent.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

refreshSavedList()