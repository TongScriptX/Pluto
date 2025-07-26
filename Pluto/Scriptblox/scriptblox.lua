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

    -- 防止重复保存（根据 id 字段）
    if not sc.id then
        sc.id = tostring(math.random(1000000, 9999999)) -- 兜底生成一个 ID
    end
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

    -- 打印调试
    print("准备保存，当前脚本总数：", #saved)
    for i,v in ipairs(saved) do
        print(i, v.title)
    end

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

local resultsPerPage = 5
local currentPage = 1
local totalPages = 1
local currentKeyword = ""

-- 分页按钮竖排区域，放在搜索框下面（可根据搜索框位置微调 Y）
local pageControlsFrame = Instance.new("Frame")
pageControlsFrame.Size = UDim2.new(0, 100, 0, 100)
pageControlsFrame.Position = UDim2.new(0, 5, 0, 80) -- Y=80 是默认搜索框下，改成你实际高度
pageControlsFrame.BackgroundTransparency = 1
pageControlsFrame.Parent = tabContent

local pageLayout = Instance.new("UIListLayout")
pageLayout.Parent = pageControlsFrame
pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
pageLayout.Padding = UDim.new(0, 6)

-- 上一页按钮
local prevBtn = UILibrary:CreateButton(pageControlsFrame, {
    Text = "上一页",
    Size = UDim2.new(1, 0, 0, 26),
    Callback = function()
        if currentPage > 1 then
            currentPage -= 1
            doSearch(currentKeyword, currentPage)
        end
    end
})

-- 页码标签
local pageLabel = Instance.new("TextLabel")
pageLabel.Parent = pageControlsFrame
pageLabel.Size = UDim2.new(1, 0, 0, 26)
pageLabel.BackgroundTransparency = 1
pageLabel.Text = "第 1 页"
pageLabel.TextColor3 = Color3.new(1,1,1)
pageLabel.Font = Enum.Font.SourceSans
pageLabel.TextSize = 16
pageLabel.TextScaled = false
pageLabel.TextXAlignment = Enum.TextXAlignment.Center
pageLabel.TextYAlignment = Enum.TextYAlignment.Center

-- 下一页按钮
local nextBtn = UILibrary:CreateButton(pageControlsFrame, {
    Text = "下一页",
    Size = UDim2.new(1, 0, 0, 26),
    Callback = function()
        if currentPage < totalPages then
            currentPage += 1
            doSearch(currentKeyword, currentPage)
        end
    end
})

-- 搜索结果滚动区（位于分页按钮右侧）
local resultsScrollingFrame = Instance.new("ScrollingFrame")
resultsScrollingFrame.Parent = tabContent
resultsScrollingFrame.Position = UDim2.new(0, 110, 0, 80)
resultsScrollingFrame.Size = UDim2.new(1, -115, 1, -90)
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

function doSearch(keyword, page)
    clearResults()
    currentScripts = {}
    currentKeyword = keyword
    currentPage = page or 1

    local maxPerRequest = 50 -- 提前加载较多，避免频繁请求
    local url = "https://scriptblox.com/api/script/search?q=" .. HttpService:UrlEncode(keyword) .. "&max=" .. maxPerRequest .. "&page=1"

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

    local allResults = data.result.scripts
    totalPages = math.ceil(#allResults / resultsPerPage)
    if totalPages == 0 then totalPages = 1 end
    if currentPage > totalPages then currentPage = totalPages end

    local startIndex = (currentPage - 1) * resultsPerPage + 1
    local endIndex = math.min(startIndex + resultsPerPage - 1, #allResults)

    for index = startIndex, endIndex do
        local sc = allResults[index]
        table.insert(currentScripts, sc)

        local card = UILibrary:CreateCard(resultsScrollingFrame, { IsMultiElement = true })
        card.Size = UDim2.new(1, 0, 0, 90)
        card.LayoutOrder = index

        UILibrary:CreateLabel(card, { Text = sc.title or "无标题", TextSize = 14 })
        UILibrary:CreateLabel(card, { Text = "游戏: " .. (sc.game and sc.game.name or "未知"), TextSize = 12 })
        UILibrary:CreateLabel(card, { Text = "浏览量: " .. tostring(sc.views or 0), TextSize = 12 })

        UILibrary:CreateButton(card, {
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

        UILibrary:CreateButton(card, {
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
                    refreshSavedList()
                end
            end
        })
    end

    -- 更新页码标签
    pageLabel.Text = string.format("第 %d / %d 页", currentPage, totalPages)

    -- 自动调整滚动区域高度
    local visibleCount = endIndex - startIndex + 1
    local contentHeight = visibleCount * (90 + 5) + 5
    resultsScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end

-- 已保存脚本标签页
-- 创建已保存脚本标签页
local savedTabBtn, savedTabContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "已保存脚本",
    Active = false,
})

-- 确保有 UIListLayout（用于已保存脚本）
local savedListLayout = savedTabContent:FindFirstChildOfClass("UIListLayout")
if not savedListLayout then
    savedListLayout = Instance.new("UIListLayout")
    savedListLayout.Parent = savedTabContent
    savedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    savedListLayout.Padding = UDim.new(0, 5)
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

        -- 注入按钮
        UILibrary:CreateButton(card, {
            Text = "注入",
            Position = UDim2.new(0.6, 5, 0, 15),
            Size = UDim2.new(0.12, -5, 0, 30),
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

        -- 删除按钮
        UILibrary:CreateButton(card, {
            Text = "删除",
            Position = UDim2.new(0.73, 5, 0, 15),
            Size = UDim2.new(0.12, -5, 0, 30),
            Callback = function()
                local saved = readSavedScripts()
                if saved then
                    for idx, v in ipairs(saved) do
                        if v.title == sc.title and v.script == sc.script then
                            table.remove(saved, idx)
                            break
                        end
                    end
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

        -- 复制按钮
        UILibrary:CreateButton(card, {
            Text = "复制",
            Position = UDim2.new(0.86, 5, 0, 15),
            Size = UDim2.new(0.12, -10, 0, 30),
            Callback = function()
                if setclipboard and type(sc.script) == "string" then
                    setclipboard(sc.script)
                    UILibrary:Notify({
                        Title = "已复制",
                        Text = "脚本内容已复制到剪贴板",
                        Duration = 2,
                    })
                else
                    UILibrary:Notify({
                        Title = "复制失败",
                        Text = "无法访问剪贴板功能",
                        Duration = 2,
                    })
                end
            end,
        })
    end

    local totalHeight = (#savedScripts + 1) * (90 + 5) + 10
    savedTabContent.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

refreshSavedList()