# Changelog

## [Driving Empire] - 2026-01-02

### Added
- 日志系统增强：使用LogService捕获所有类型的输出（包括错误和警告）
- 目标达成自动退出：达到目标金额后发送webhook并自动退出游戏
- Webhook重试机制：目标达成webhook发送失败时自动重试（最多3次）

### Fixed
- 修复FPS Boost中Transparency类型错误（ParticleEmitter和Trail使用NumberSequence类型）
- 修复投放检测中lastCheckAmount未初始化导致的错误

### Performance
- 优化Console.lua性能：使用对象池、批量更新、LayoutOrder优化、更新节流
- 限制可见日志数量为50条，但保留完整历史记录

## [Driving Empire] - 2026-01-01

### Added
- 搜索购买功能：支持通过关键词搜索车辆并购买
- 一键购买功能：按价格从低到高自动购买车辆
- 后悔功能：一键卖出所有通过一键购买功能购买的车辆
- 下拉框UI组件：支持可滚动的选项列表
- 自动购买标签页：将购买功能改名为"自动购买"并移到通知设置前

### Fixed
- 修复购买参数错误
- 修复下拉框显示层级问题
- 修复UI元素清理问题
- 修复后悔功能只卖出部分车辆的问题
- 增加卖车间隔时间，确保稳定
- 修复从商店外搜索时车辆数量不足的问题

### Performance
- 优化车辆数据获取性能（等待时间从1-2秒优化为0.7-1秒）
- 优化车辆遍历性能
- 减少控制台输出
- 清理代码注释，简化代码

### UI
- 加宽下拉框显示完整车辆名称和价格（标签20%，按钮80%）
- 提升下拉框显示层级
- 添加下拉框和输入框示例到文档

### Documentation
- 更新UI库README.md，添加下拉框组件文档
- 更新ULibrary_Example.lua，添加更多组件示例
- 完善API参考表

### Chores
- 关闭调试模式（DEBUG_MODE设置为false）