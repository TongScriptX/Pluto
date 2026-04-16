# Pluto UI Library 使用文档

## 目录
- [简介](#简介)
- [安装](#安装)
- [快速开始](#快速开始)
- [核心组件](#核心组件)
  - [主窗口 (CreateUIWindow)](#主窗口-createuiwindow)
  - [标签页 (CreateTab)](#标签页-createtab)
  - [卡片 (CreateCard)](#卡片-createcard)
  - [按钮 (CreateButton)](#按钮-createbutton)
  - [标签 (CreateLabel)](#标签-createlabel)
  - [输入框 (CreateTextBox)](#输入框-createtextbox)
  - [开关 (CreateToggle)](#开关-createtoggle)
  - [下拉框 (CreateDropdown)](#下拉框-createdropdown)
  - [悬浮按钮 (CreateFloatingButton)](#悬浮按钮-createfloatingbutton)
  - [通知 (Notify)](#通知-notify)
- [主题系统](#主题系统)
  - [设置主题 (SetTheme)](#设置主题-settheme)
  - [自定义颜色](#自定义颜色)
- [高级功能](#高级功能)
  - [自动布局](#自动布局)
  - [拖拽功能](#拖拽功能)
  - [动画效果](#动画效果)
- [完整示例](#完整示例)
- [API 参考](#api-参考)

## 简介

Pluto UI Library 是一个功能强大的 Roblox UI 库，提供了现代化的界面组件和自动布局系统。它采用 Material Design 风格，支持主题定制、动画效果和响应式设计。

## 安装
```lua
local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"))()
```

## 快速开始

```lua
-- 创建主窗口
local window = UILibrary:CreateUIWindow({
    Title = "我的应用"
})

-- 创建标签页
local homeTab, homeContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "主页",
    Active = true
})

-- 创建卡片
local card = UILibrary:CreateCard(homeContent)

-- 添加内容
local titleLabel = UILibrary:CreateLabel(card, {
    Text = "欢迎使用 Pluto UI Library",
    TextSize = 14
})

local descriptionLabel = UILibrary:CreateLabel(card, {
    Text = "这是一个现代化的 UI 库，支持自动布局和主题定制。"
})

-- 创建按钮
local button = UILibrary:CreateButton(card, {
    Text = "点击我",
    Callback = function()
        UILibrary:Notify({
            Title = "通知",
            Text = "按钮被点击了！",
            Duration = 3
        })
    end
})
```

## 核心组件

### 主窗口 (CreateUIWindow)

创建应用程序的主窗口。

```lua
local window = UILibrary:CreateUIWindow({
    Title = "窗口标题"
})
```

**返回值：**
- `MainFrame`: 主窗口框架
- `ScreenGui`: 屏幕GUI
- `Sidebar`: 侧边栏
- `TitleLabel`: 标题标签
- `MainPage`: 主内容区域

### 标签页 (CreateTab)

创建侧边栏标签页。

```lua
local tabButton, tabContent = UILibrary:CreateTab(sidebar, titleLabel, mainPage, {
    Text = "标签名称",    -- 标签显示文本
    Active = false        -- 是否默认激活
})
```

### 子标签页 (CreateSubTabs)

在主标签页内创建胶囊样式的子标签页，用于细分功能区域。

```lua
local subTabs = UILibrary:CreateSubTabs(tabContent, {
    Items = {                            -- 子标签页列表
        { Name = "基本信息", Icon = "👤" },
        { Name = "设置选项", Icon = "⚙️" },
        { Name = "统计数据", Icon = "📊" }
    },
    DefaultActive = 1,                   -- 默认激活的子标签页索引
    OnSwitch = function(index, name)     -- 切换回调函数
        print("切换到:", name)
    end
})
```

**返回对象的方法：**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `SwitchTo(index)` | `number` | `void` | 切换到指定子标签页 |
| `GetActiveIndex()` | 无 | `number` | 获取当前激活索引 |
| `GetContent(index)` | `number` | `Frame` | 获取内容容器 |
| `GetButton(index)` | `number` | `TextButton` | 获取按钮实例 |
| `AddElement(index, element)` | `number, Instance` | `void` | 添加元素到子标签页 |

**使用示例：**

```lua
-- 获取子标签页内容并添加元素
local content1 = subTabs.GetContent(1)
if content1 then
    local card = UILibrary:CreateCard(content1)
    UILibrary:CreateLabel(card, { Text = "基本信息内容" })
end

-- 程序化切换子标签页
subTabs.SwitchTo(2)

-- 获取当前激活索引
local currentIndex = subTabs.GetActiveIndex()
```

### 卡片 (CreateCard)

创建内容卡片容器。

```lua
local card = UILibrary:CreateCard(parent, {
    IsMultiElement = false -- 是否为多元素卡片（影响高度）
})
```

### 按钮 (CreateButton)

创建交互按钮。

```lua
local button = UILibrary:CreateButton(parent, {
    Text = "按钮文本",                    -- 按钮显示文本
    BackgroundColor3 = Color3.fromRGB(),  -- 背景颜色（可选）
    BackgroundTransparency = 0.4,         -- 背景透明度（可选）
    Callback = function()                 -- 点击回调函数
        -- 按钮点击逻辑
    end
})
```

### 标签 (CreateLabel)

创建文本标签。

```lua
local label = UILibrary:CreateLabel(parent, {
    Text = "标签文本",                    -- 显示文本
    TextSize = 12,                       -- 字体大小（可选）
    TextXAlignment = Enum.TextXAlignment.Left -- 文本对齐方式（可选）
})
```

### 输入框 (CreateTextBox)

创建文本输入框。

```lua
local textBox = UILibrary:CreateTextBox(parent, {
    PlaceholderText = "提示文本",         -- 占位符文本
    Text = "默认文本",                    -- 默认值（可选）
    TextSize = 12,                       -- 字体大小（可选）
    OnFocusLost = function(text)         -- 失去焦点时的回调
        print("输入内容:", text)
    end
})
```

### 开关 (CreateToggle)

创建开关组件。

```lua
local toggle, state = UILibrary:CreateToggle(parent, {
    Text = "开关标签",                    -- 开关标签文本
    DefaultState = false,                 -- 默认状态（可选）
    Callback = function(newState)         -- 状态改变回调
        print("开关状态:", newState)
    end
})
```

### 下拉框 (CreateDropdown)

创建下拉选择框组件。

```lua
local dropdown = UILibrary:CreateDropdown(parent, {
    Text = "选择标签",                    -- 下拉框标签文本
    DefaultOption = "选项1",              -- 默认选中的选项
    Options = {                          -- 选项列表
        "选项1",
        "选项2",
        "选项3"
    },
    Callback = function(selectedOption)   -- 选中回调
        print("选中了:", selectedOption)
    end
})
```

### 悬浮按钮 (CreateFloatingButton)

创建悬浮操作按钮。

```lua
local floatingButton = UILibrary:CreateFloatingButton(parent, {
    Text = "T",                          -- 按钮文本
    MainFrame = window.MainFrame,        -- 关联的主窗口
    Callback = function()                -- 点击回调（可选）
        -- 悬浮按钮逻辑
    end
})
```

### 通知 (Notify)

显示通知消息。

```lua
local notification = UILibrary:Notify({
    Title = "通知标题",                   -- 通知标题
    Text = "通知内容",                    -- 通知文本
    Duration = 3                         -- 显示时长（秒，默认3秒）
})
```

## 主题系统

### 设置主题 (SetTheme)

自定义界面主题。

```lua
UILibrary:SetTheme({
    Primary = Color3.fromRGB(255, 87, 34),      -- 主色调
    Background = Color3.fromRGB(30, 30, 30),     -- 背景色
    SecondaryBackground = Color3.fromRGB(46, 46, 46), -- 次背景色
    Accent = Color3.fromRGB(255, 152, 0),       -- 强调色
    Text = Color3.fromRGB(255, 255, 255),       -- 文字颜色
    Success = Color3.fromRGB(76, 175, 80),      -- 成功颜色
    Error = Color3.fromRGB(244, 67, 54),        -- 错误颜色
    Font = Enum.Font.Roboto                     -- 字体
})
```

### 自定义颜色

你也可以通过全局变量设置主色调：

```lua
_G.PRIMARY_COLOR = 0xFF5722 -- 设置为十六进制颜色值
-- 然后加载 UILibrary
local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"))()
```

## 高级功能

### 自动布局

Pluto UI Library 采用自动布局系统，所有组件会根据添加顺序自动排列：

```lua
-- 创建卡片
local card = UILibrary:CreateCard(parent)

-- 添加组件，无需指定位置
UILibrary:CreateLabel(card, {Text = "标题"})
UILibrary:CreateLabel(card, {Text = "描述内容"})
UILibrary:CreateButton(card, {Text = "操作按钮"})
```

### 拖拽功能

主窗口和悬浮按钮支持拖拽：

```lua
-- 主窗口默认支持拖拽（通过标题栏和侧边栏）
-- 悬浮按钮也支持拖拽
```

### 动画效果

所有组件都内置了平滑的动画效果：

```lua
-- 按钮点击动画
-- 通知显示/隐藏动画
-- 标签页切换动画
-- 开关切换动画
```

## 完整示例

```lua
-- 加载 UI 库
local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/TongScriptX/Pluto/refs/heads/main/Pluto/UILibrary/PlutoUILibrary.lua"))()

-- 创建主窗口
local window = UILibrary:CreateUIWindow({
    Title = "Pluto UI 示例"
})

-- 创建主页标签
local homeTab, homeContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "主页",
    Active = true
})

-- 创建设置标签
local settingsTab, settingsContent = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "设置"
})

-- === 主页内容 ===
-- 用户信息卡片
local userCard = UILibrary:CreateCard(homeContent)
UILibrary:CreateLabel(userCard, {
    Text = "用户信息",
    TextSize = 14
})
UILibrary:CreateLabel(userCard, {
    Text = "用户名: Player123"
})
UILibrary:CreateLabel(userCard, {
    Text = "等级: 15"
})

-- 操作卡片
local actionCard = UILibrary:CreateCard(homeContent)
UILibrary:CreateLabel(actionCard, {
    Text = "快捷操作",
    TextSize = 14
})

UILibrary:CreateButton(actionCard, {
    Text = "开始游戏",
    Callback = function()
        UILibrary:Notify({
            Title = "游戏开始",
            Text = "游戏即将开始，请准备！"
        })
    end
})

UILibrary:CreateButton(actionCard, {
    Text = "查看成就",
    Callback = function()
        UILibrary:Notify({
            Title = "成就",
            Text = "暂无新成就"
        })
    end
})

-- === 设置页面内容 ===
-- 显示设置
local displayCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(displayCard, {
    Text = "显示设置",
    TextSize = 14
})

-- 音量控制
UILibrary:CreateLabel(displayCard, {
    Text = "音量控制"
})

local volumeSlider = Instance.new("Frame") -- 简化的滑块示例
volumeSlider.Size = UDim2.new(1, 0, 0, 20)
volumeSlider.Parent = displayCard

-- 游戏设置
local gameCard = UILibrary:CreateCard(settingsContent)
UILibrary:CreateLabel(gameCard, {
    Text = "游戏设置",
    TextSize = 14
})

local autoSaveToggle, autoSaveState = UILibrary:CreateToggle(gameCard, {
    Text = "自动保存",
    DefaultState = true,
    Callback = function(state)
        print("自动保存设置:", state)
    end
})

-- 创建悬浮按钮
UILibrary:CreateFloatingButton(window.MainFrame, {
    Text = "T",
    MainFrame = window.MainFrame
})

-- 自定义主题（可选）
UILibrary:SetTheme({
    Primary = Color3.fromRGB(63, 81, 181),
    Background = Color3.fromRGB(30, 30, 30),
    SecondaryBackground = Color3.fromRGB(46, 46, 46),
    Accent = Color3.fromRGB(92, 107, 192),
    Text = Color3.fromRGB(255, 255, 255),
    Success = Color3.fromRGB(76, 175, 80),
    Error = Color3.fromRGB(244, 67, 54)
})
```

## API 参考

### 主要方法

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `CreateUIWindow(options)` | `table` | `window` | 创建主窗口 |
| `CreateTab(sidebar, titleLabel, mainPage, options)` | `Frame, Label, Frame, table` | `tabButton, tabContent` | 创建标签页 |
| `CreateSubTabs(tabContent, options)` | `Frame, table` | `subTabs` | 创建子标签页 |
| `CreateCard(parent, options)` | `Instance, table` | `Frame` | 创建卡片 |
| `CreateButton(parent, options)` | `Instance, table` | `TextButton` | 创建按钮 |
| `CreateLabel(parent, options)` | `Instance, table` | `TextLabel` | 创建标签 |
| `CreateTextBox(parent, options)` | `Instance, table` | `TextBox` | 创建输入框 |
| `CreateToggle(parent, options)` | `Instance, table` | `Frame, boolean` | 创建开关 |
| `CreateDropdown(parent, options)` | `Instance, table` | `Frame` | 创建下拉框 |
| `CreateFloatingButton(parent, options)` | `Instance, table` | `TextButton` | 创建悬浮按钮 |
| `Notify(options)` | `table` | `Frame` | 显示通知 |
| `SetTheme(theme)` | `table` | `void` | 设置主题 |

### 选项参数

#### Window Options
```lua
{
    Title = "窗口标题" -- 字符串
}
```

#### Tab Options
```lua
{
    Text = "标签文本",    -- 字符串
    Active = false        -- 布尔值
}
```

#### Card Options
```lua
{
    IsMultiElement = false -- 布尔值
}
```

#### Button Options
```lua
{
    Text = "按钮文本",                    -- 字符串
    BackgroundColor3 = Color3,            -- Color3
    BackgroundTransparency = 0.4,         -- 数字 (0-1)
    Callback = function() end             -- 函数
}
```

#### Label Options
```lua
{
    Text = "标签文本",                    -- 字符串
    TextSize = 12,                       -- 数字
    TextXAlignment = Enum.TextXAlignment -- 枚举
}
```

#### TextBox Options
```lua
{
    PlaceholderText = "提示文本",         -- 字符串
    Text = "默认文本",                    -- 字符串
    TextSize = 12,                       -- 数字
    OnFocusLost = function(text) end     -- 函数
}
```

#### Toggle Options
```lua
{
    Text = "开关标签",                    -- 字符串
    DefaultState = false,                 -- 布尔值
    Callback = function(state) end        -- 函数
}
```

#### Dropdown Options
```lua
{
    Text = "选择标签",                    -- 字符串
    DefaultOption = "默认选项",            -- 字符串
    Options = {"选项1", "选项2"},         -- 数组
    Callback = function(option) end      -- 函数
}
```

#### FloatingButton Options
```lua
{
    Text = "按钮文本",                    -- 字符串
    MainFrame = Frame,                    -- Frame实例
    Callback = function() end             -- 函数
}
```

#### Notify Options
```lua
{
    Title = "通知标题",                   -- 字符串
    Text = "通知内容",                    -- 字符串
    Duration = 3                         -- 数字（秒）
}
```

#### Theme Options
```lua
{
    Primary = Color3,                    -- 主色调
    Background = Color3,                 -- 背景色
    SecondaryBackground = Color3,        -- 次背景色
    Accent = Color3,                     -- 强调色
    Text = Color3,                       -- 文字颜色
    Success = Color3,                    -- 成功颜色
    Error = Color3,                      -- 错误颜色
    Font = Enum.Font                     -- 字体枚举
}
```

#### SubTabs Options
```lua
{
    Items = {                            -- 子标签页项目列表
        { Name = "标签1", Icon = "📱" },  -- 带图标的标签
        { Name = "标签2" },               -- 纯文本标签
        "标签3"                           -- 简写形式
    },
    DefaultActive = 1,                   -- 默认激活的索引（数字）
    OnSwitch = function(index, name)     -- 切换回调函数
        print("切换到:", name)
    end
}
```