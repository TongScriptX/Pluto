# 🤝 Pluto 项目贡献指南

欢迎为 Pluto 项目做出贡献！请仔细阅读以下指南，确保您的贡献能够顺利合并。

## 📋 目录

- [Git 规范](#git-规范)
- [开发流程](#开发流程)
- [提交规范](#提交规范)
- [分支规范](#分支规范)
- [代码审查](#代码审查)
- [问题报告](#问题报告)

## 🎯 Git 规范

### 分支管理规范

#### 长期分支（常驻）

| 分支名 | 保护级别 | 用途 | 谁可推送 |
|--------|----------|------|----------|
| `main` | 强制 PR + CI 通过 | 生产可部署代码 | 仅 Maintainer 合并 |
| `develop` | 可选保护 | 集成测试分支 | 技术负责人 |

#### 短期分支（用完即删）

命名模板：`<type>/<ticket>-<short-desc>`

**type 只能出现以下关键字，全部小写：**

| 类型 | 场景 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat/PROJ-123-login-by-oauth` |
| `fix` | 修补缺陷 | `fix/PROJ-456-memory-leak` |
| `docs` | 仅文档变动 | `docs/api-readme-typo` |
| `style` | 代码格式、无逻辑变更 | `style/remove-trailing-space` |
| `refactor` | 重构 | `refactor/extract-user-service` |
| `test` | 补充缺失测试 | `test/add-login-unit` |
| `chore` | 杂项（升级依赖、脚本） | `chore/bump-springboot-3.2` |
| `hotfix` | 生产紧急修复 | `hotfix/PROJ-888-zero-division` |
| `release` | 版本发布 | `release/v2.5.0` |

**规则：**
- 整段 ≤ 50 字符，小写，连字符 `-` 分隔
- 必须关联工单号（无工单用 `no-ticket` 占位）
- 禁止个人前缀、拼音、中文、空格、下划线

### Commit Message 规范（Angular 风格）

#### 格式（三段式）

```
<type>(<scope>): <subject>          ← 必填，≤ 72 字符
<BLANK LINE>
<body>                              ← 可选，72 字符换行
<BLANK LINE>
<footer>                            ← 可选，关联工单/BREAKING CHANGE
```

#### type 列表（与分支类型保持一致）

`feat` `fix` `docs` `style` `refactor` `test` `chore` `perf` `ci` `build` `revert`

#### 示例

```
feat(auth): add GitHub OAuth2 login flow

- 使用 authorization_code 模式
- 新增 /auth/callback 路由与单元测试
- 刷新令牌有效期 24h

Closes PROJ-123
```

#### 强制红线

1. subject 禁止出现句号 `.`
2. 首字母小写，动词用一般现在时（add/fix/remove）
3. 合并请求必须 `--no-ff` 保留历史；禁止直接 `push -f` 到 `main`
4. 一次 commit 只做一件事；禁止混排功能与格式化

## 🔄 开发流程

### 1. 准备工作

```bash
# 克隆仓库
git clone https://github.com/TongScriptX/Pluto.git
cd Pluto

# 安装 pre-commit 钩子
pre-commit install --hook-type commit-msg

# 配置本地 Git（仅需一次）
git config user.name "Your Name"
git config user.email "you@example.com"
```

### 2. 开发循环

1. **更新本地主分支**
   ```bash
   git fetch origin && git merge origin/main
   ```

2. **新建功能分支**
   ```bash
   git switch -c feat/PROJ-123-desc
   ```

3. **编码 & 自测**
   ```bash
   # 运行测试
   # 根据项目使用的测试框架
   ```

4. **格式化 & 静态检查**
   ```bash
   pre-commit run --all
   ```

5. **提交**
   ```bash
   git commit -m "feat(scope): xxx"
   ```

6. **推送**
   ```bash
   git push -u origin feat/PROJ-123-desc
   ```

7. **创建 PR**
   - 目标分支选 `main`
   - 使用 PR 模板填写详细信息

8. **处理 review**
   - 评论必须回复"Done"
   - 使用 `commit --fixup` + `rebase -i --autosquash`

9. **合并后清理**
   ```bash
   git branch -d feat/PROJ-123-desc
   git push origin --delete feat/PROJ-123-desc
   ```

### 3. 合并策略

- 使用 `Merge Commit` 保留分支痕迹；禁止直接 `rebase` 进 `main`
- 若需线性历史，由 Maintainer 在 GitHub 选 "Rebase and merge" 统一操作

## 🔍 代码审查

### 审查要点

1. **代码质量**
   - 逻辑是否清晰
   - 是否遵循项目编码规范
   - 是否有潜在的性能问题

2. **测试覆盖**
   - 是否有足够的单元测试
   - 测试用例是否覆盖边界情况

3. **安全性**
   - 是否有安全漏洞
   - 是否有敏感信息泄露

4. **文档**
   - 是否更新了相关文档
   - 代码注释是否充分

### 审查流程

1. 创建 PR 后，自动触发 CI 检查
2. CI 通过后，由 Maintainer 进行代码审查
3. 审查通过后，合并到 `main` 分支
4. 自动触发 Discord 通知

## 🐛 问题报告

### Bug 报告

使用以下模板报告 Bug：

```markdown
## 🐛 Bug 描述
简要描述遇到的问题

## 🔄 复现步骤
1. 进入 '...'
2. 点击 '....'
3. 滚动到 '....'
4. 看到错误

## 🎯 期望行为
描述您期望发生的情况

## 📸 截图
如果适用，添加截图来帮助解释问题

## 🖥️ 环境信息
- 操作系统: [例如 iOS]
- 浏览器: [例如 chrome, safari]
- 版本: [例如 22]

## 📝 附加信息
添加任何其他关于问题的信息
```

### 功能请求

使用以下模板提出新功能：

```markdown
## 🚀 功能描述
简要描述您希望添加的功能

## 🎯 解决的问题
这个功能解决了什么问题？

## 💡 建议的解决方案
描述您希望如何实现这个功能

## 🔄 替代方案
描述您考虑过的其他解决方案

## 📝 附加信息
添加任何其他关于功能请求的信息
```

## 📞 联系方式

如有疑问，请通过以下方式联系：

- 创建 GitHub Issue
- 在 Discord 社群中讨论

---

感谢您的贡献！🎉