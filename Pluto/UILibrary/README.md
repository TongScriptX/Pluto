## PlutoUILibrary 使用教程

## 目录
- [创建主窗口](#创建主窗口)
- [创建标签页](#创建标签页)
- [创建卡片](#创建卡片)
- [创建按钮](#创建按钮)
- [创建悬浮按钮](#创建悬浮按钮)
- [创建文本标签](#创建文本标签)
- [创建输入框](#创建输入框)
- [创建开关](#创建开关)
- [创建通知](#创建通知)
- [创建作者信息](#创建作者信息)
- [切换主题](#切换主题)
- [启用拖拽](#启用拖拽)

---

## 创建主窗口

**功能**：创建包含侧边栏、标题栏和主内容区域的窗口。

**返回值**：包含：
- `MainFrame`：主框架
- `ScreenGui`：屏幕 GUI
- `Sidebar`：侧边栏
- `TitleLabel`：标题标签
- `MainPage`：主内容区域

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
```

**效果**：创建 400x300 像素窗口，包含侧边栏和标题栏。

---

## 创建标签页

**功能**：创建标签页系统，支持动态切换内容。

**参数**：
- `sidebar`（Instance）：侧边栏框架
- `titleLabel`（Instance）：标题标签
- `mainPage`（Instance）：主内容区域
- `options`（表）：
  - `Text`（字符串）：标签页名称
  - `Active`（布尔值）：初始激活，默认 `false`

**返回值**：
- `TextButton`：标签页按钮
- `ScrollingFrame`：标签页内容框架

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
local tab1, content1 = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "Tab 1",
    Active = true
})
local tab2, content2 = UILibrary:CreateTab(window.Sidebar, window.TitleLabel, window.MainPage, {
    Text = "Tab 2"
})
```

**效果**：创建两个标签页，初始显示 "Tab 1"，点击侧边栏按钮切换内容。

---

## 创建卡片

**功能**：创建圆角卡片容器，用于组织 UI 元素。

**参数**：
- `parent`（Instance）：父对象
- `options`（表）：
  - `IsMultiElement`（布尔值）：多元素卡片（高度 90 像素），默认 `false`（高度 60 像素）

**返回值**：卡片的 `Frame` 实例

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
local card = UILibrary:CreateCard(window.MainPage, { IsMultiElement = true })
```

**效果**：在主窗口内容区域创建多元素卡片容器。

---

## 创建按钮

**功能**：创建交互式按钮，支持点击回调和悬停效果。

**参数**：
- `parent`（Instance）：父对象
- `options`（表）：
  - `Text`（字符串）：按钮文本
  - `BackgroundColor3`（Color3）：背景颜色，默认主题 Primary
  - `BackgroundTransparency`（数字）：背景透明度，默认 `0.5`
  - `Callback`（函数）：点击回调

**返回值**：按钮的 `TextButton` 实例

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
local card = UILibrary:CreateCard(window.MainPage)
UILibrary:CreateButton(card, {
    Text = "Click Me",
    Callback = function()
        print("Button clicked!")
    end
})
```

**效果**：在卡片中创建文本为 "Click Me" 的按钮，点击打印 "Button clicked!"。

---

## 创建悬浮按钮

**功能**：创建可拖拽悬浮按钮，用于切换主窗口显隐。

**参数**：
- `parent`（Instance）：父对象
- `options`（表）：
  - `Text`（字符串）：按钮文本，默认 `"T"`
  - `MainFrame`（Instance）：关联主窗口框架

**返回值**：悬浮按钮的 `TextButton` 实例

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
local floatingButton = UILibrary:CreateFloatingButton(window.ScreenGui, {
    MainFrame = window.MainFrame,
    Text = "Menu"
})
```

**效果**：创建悬浮按钮，点击切换主窗口显/隐，可拖拽移动。

---

## 创建文本标签

**功能**：创建文本标签，支持自定义大小、位置和对齐。

**参数**：
- `parent`（Instance）：父对象
- `options`（表）：
  - `Text`（字符串）：标签文本
  - `Size`（UDim2）：大小，默认 `1,-2*Padding,0,LabelHeight`
  - `Position`（UDim2）：位置，默认 `0,Padding,0,Padding`
  - `TextSize`（整数）：文本大小，默认 `12`
  - `TextXAlignment`（Enum.TextXAlignment）：水平对齐，默认 `Left`

**返回值**：标签的 `TextLabel` 实例

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
local card = UILibrary:CreateCard(window.MainPage)
UILibrary:CreateLabel(card, {
    Text = "Settings",
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Center
})
```

**效果**：在卡片中创建居中显示的 "Settings" 标签，字体大小 14。

---

## 创建输入框

**功能**：创建文本输入框，支持焦点事件和占位符。

**参数**：
- `parent`（Instance）：父对象
- `options`（表）：
  - `PlaceholderText`（字符串）：占位符文本
  - `Text`（字符串）：初始文本，默认 `""`
  - `OnFocusLost`（函数）：失去焦点回调

**返回值**：输入框的 `TextBox` 实例

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
local card = UILibrary:CreateCard(window.MainPage)
UILibrary:CreateTextBox(card, {
    PlaceholderText = "Enter your name",
    OnFocusLost = function()
        print("Input submitted")
    end
})
```

**效果**：创建占位符为 "Enter your name" 的输入框，失去焦点打印 "Input submitted"。

---

## 创建开关

**功能**：创建开关控件，支持状态切换和回调。

**参数**：
- `parent`（Instance）：父对象
- `options`（表）：
  - `Text`（字符串）：开关标签文本
  - `DefaultState`（布尔值）：初始状态，默认 `false`
  - `Callback`（函数）：状态改变回调，接收新状态

**返回值**：
- `Frame`：开关容器框架
- `boolean`：当前状态

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
local card = UILibrary:CreateCard(window.MainPage)
local toggle, state = UILibrary:CreateToggle(card, {
    Text = "Sound",
    DefaultState = true,
    Callback = function(newState)
        print("Sound is now", newState and "ON" or "OFF")
    end
})
```

**效果**：创建初始开启的 "Sound" 开关，切换时打印状态。

---

## 创建通知

**功能**：在右下角显示弹出式通知。

**参数**：
- `options`（表）：
  - `Title`（字符串）：标题，默认 `"Notification"`
  - `Text`（字符串）：内容，默认 `""`
  - `Duration`（数字）：显示时间（秒），默认 `3`

**返回值**：通知的 `Frame` 实例

**示例**：

```lua
UILibrary:Notify({
    Title = "Welcome!",
    Text = "Thanks for using UILibrary!",
    Duration = 5
})
```

**效果**：显示标题为 "Welcome!"、内容为 "Thanks for using UILibrary!" 的通知，持续 5 秒。

---

## 创建作者信息

**功能**：创建包含作者信息和社交按钮的卡片。

**参数**：
- `parent`（Instance）：父对象
- `options`（表）：
  - `Text`（字符串）：作者信息文本
  - `SocialText`（字符串）：社交按钮文本
  - `SocialCallback`（函数）：社交按钮点击回调

**返回值**：作者卡片的 `Frame` 实例

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
UILibrary:CreateAuthorInfo(window.MainPage, {
    Text = "Created by DevX",
    SocialText = "Follow",
    SocialCallback = function()
        print("Followed!")
    end
})
```

**效果**：创建包含 "Created by DevX" 和 "Follow" 按钮的卡片。

---

## 切换主题

**功能**：动态切换 UI 主题（颜色和字体）。

**参数**：
- `newTheme`（表）：
  - `Primary`（Color3）：主色调
  - `Background`（Color3）：背景色
  - `SecondaryBackground`（Color3）：次背景色
  - `Accent`（Color3）：高亮色
  - `Text`（Color3）：文本色
  - `Success`（Color3）：成功状态色
  - `Error`（Color3）：错误状态色
  - `Font`（Enum.Font）：字体

**返回值**：无

**示例**：

```lua
UILibrary:SetTheme({
    Primary = Color3.fromRGB(100, 100, 255),
    Background = Color3.fromRGB(50, 50, 50),
    Font = Enum.Font.Arial
})
```

**效果**：切换 UI 主题为新颜色方案和 Arial 字体。

---

## 启用拖拽

**功能**：使 UI 元素可拖拽移动。

**参数**：
- `gui`（Instance）：要应用拖拽的 UI 对象

**返回值**：无

**示例**：

```lua
local window = UILibrary:CreateUIWindow()
UILibrary:MakeDraggable(window.MainFrame)
```

**效果**：使主窗口可通过鼠标或触摸拖拽移动。
