# Cloudreve 批量用户管理插件 — 安装与使用文档

> 版本：1.0 · 适用 Cloudreve v4.x · 更新：2026-09-02

---

## 一、插件简介

为 Cloudreve 后台增加**批量用户管理**能力的轻量插件，无需修改源码、无需编译。

### 核心功能

| 功能 | 说明 |
|------|------|
| 用户列表 | 分页、搜索（含 @ 按邮箱，否则按昵称）、按用户组/状态筛选、ID 排序 |
| 批量删除 | 单删 + 批量删除，含二次确认 |
| 批量封禁/解封 | 单个或批量切换用户状态（active / manual_banned） |
| CSV 批量创建 | 文件上传或直接粘贴，表头自动识别，任意列序 |
| 自删保护 | 当前登录账号无法被删除/封禁（UI 隐藏 + 兜底过滤双重防护） |
| 免登录继承 | 自动读取 Cloudreve 后台已登录会话，无需重复输入密码 |
| URL 隐藏 | 入口按钮以 iframe 全屏覆盖打开，地址栏保持 `/admin/user` 不变 |
| 中英双语 | 跟随 Cloudreve 语言设置 / 浏览器语言，支持手动切换并持久化 |

### 技术原理

| 组成 | 实现方式 | 存储位置 |
|------|----------|----------|
| 管理页面 | 纯静态 HTML（单文件，零依赖） | `data/statics/pages/batch-user-mgr.html` |
| 入口按钮 | 官方"页脚代码"设置项（`siteScript`）注入 | 数据库 `settings` 表 |
| 一键脚本 | PowerShell 脚本，调用 Cloudreve API 自动部署 | 随意放置，不驻留系统 |

**不含**任何后端代码修改、数据库结构变更、二进制补丁。Cloudreve 升级不会丢失入口按钮（存数据库），管理页面文件升级后需重新复制（静态目录可能被覆盖）。

---

## 二、环境要求

| 项目 | 要求 |
|------|------|
| Cloudreve | v4.x（已在 4.1.5 实测通过） |
| 管理员账号 | 拥有用户管理权限的邮箱 + 密码 |
| 静态目录 | `data/statics/pages/` 可写（Cloudreve 安装目录下） |
| 执行脚本 | Windows + PowerShell 5.1+（已自带，无需额外安装） |
| 网络 | 脚本运行机能访问 Cloudreve 服务端口 |

---

## 三、一键安装（推荐）

### 3.1 准备文件

将以下两个文件放在同一目录：

```
your-folder/
  ├── batch-user-mgr.html          # 管理页面
  └── install-batch-user-mgr.ps1   # 一键安装脚本
```

### 3.2 执行安装

打开 PowerShell，切换到文件所在目录，执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 `
  -Email admin@example.com `
  -Password yourpass
```

**参数说明：**

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `-Server` | 是 | `http://10.139.73.2:5212` | Cloudreve 服务地址（含端口） |
| `-Email` | 是 | — | 管理员邮箱 |
| `-Password` | 是 | — | 管理员密码 |
| `-StaticsDir` | 否 | `Z:\data\statics\pages` | Cloudreve 静态目录路径（远程部署需修改） |
| `-PageSource` | 否 | 脚本同目录 | 页面文件来源路径（非同目录时指定） |

### 3.3 安装输出示例

```
[1/4] 登录成功 (admin@example.com)
[2/4] 页面已就位: Z:\data\statics\pages\batch-user-mgr.html (访问路由 /pages/batch-user-mgr.html)
[3/4] 入口按钮已写入官方'页脚代码'设置 (存数据库, 升级不丢失)
[4/4] 验证通过: /admin/user 页面已包含注入脚本。
```

看到 `[4/4] 验证通过` 即安装成功。

### 3.4 安装后验证

1. 浏览器登录 Cloudreve 后台
2. 进入 **用户管理** 页面（`/admin/user`）
3. 右下角出现绿色浮动按钮，显示两行文字：
   - 第一行：`👥 批量用户管理`
   - 第二行：`Batch User Manager`
4. 点击按钮 → 全屏覆盖批量管理界面，地址栏不变
5. 管理界面顶部右侧有 `‹ 返回后台` 按钮，点击返回

---

## 四、手动安装（无 PowerShell 环境）

如果无法运行脚本，可手动完成两步部署。

### 步骤 1：部署页面文件

将 `batch-user-mgr.html` 复制到 Cloudreve 静态目录：

```
<Cloudreve安装目录>/data/statics/pages/batch-user-mgr.html
```

访问验证：浏览器打开 `http://<你的地址>/pages/batch-user-mgr.html`，应显示管理页面。

### 步骤 2：注入入口按钮

1. 登录 Cloudreve 后台 → **设置** → 找到 **"页脚代码"** 设置项
2. 粘贴以下内容：

```html
<!-- crbm:begin -->
<script>
(function(){
  var btn=document.createElement('div');
  btn.id='crbm-entry';
  btn.style.cssText='display:none;position:fixed;right:20px;bottom:20px;z-index:99998';
  btn.innerHTML='<span style="display:inline-flex;flex-direction:column;align-items:center;gap:2px;padding:10px 18px;border-radius:16px;background:#00d4aa;color:#001a15;font-weight:600;font-family:system-ui;cursor:pointer;box-shadow:0 4px 16px rgba(0,0,0,.35);line-height:1.3"><span style="font-size:14px">\uD83D\uDC65 批量用户管理</span><span style="font-size:11px;opacity:.75">Batch User Manager</span></span>';
  document.body.appendChild(btn);
  var iframe=null;
  function openMgr(){
    if(iframe)return;
    iframe=document.createElement('iframe');
    iframe.src='/pages/batch-user-mgr.html';
    iframe.style.cssText='position:fixed;top:0;left:0;width:100vw;height:100vh;border:0;z-index:99999;background:#0b0b12';
    document.body.appendChild(iframe);
  }
  function closeMgr(){
    if(iframe){iframe.remove();iframe=null;}
  }
  btn.onclick=openMgr;
  window.addEventListener('message',function(e){
    if(e.data&&e.data.type==='closeBatchMgr')closeMgr();
  });
  function check(){
    var p=window.location.pathname||'';
    btn.style.display=(p.indexOf('/admin')===0)?'block':'none';
  }
  setInterval(check,800);check();
})();
</script>
<!-- crbm:end -->
```

3. 保存设置
4. 访问 `/admin/user` 确认按钮出现

---

## 五、使用指南

### 5.1 进入管理界面

1. 以管理员身份登录 Cloudreve
2. 进入任意后台管理页面（如 `/admin/user` 用户管理）
3. 点击右下角绿色浮动按钮
4. 批量管理界面以全屏覆盖方式打开

### 5.2 用户列表

| 操作 | 方法 |
|------|------|
| 搜索 | 搜索框输入关键词：含 `@` 按邮箱搜索，否则按昵称 |
| 筛选用户组 | 下拉选择用户组（Admin / User 等） |
| 筛选状态 | 下拉选择状态（正常/未激活/已封禁/系统封禁） |
| 每页条数 | 下拉选择 10/25/50/100 |
| 排序 | 点击 `ID ↓/↑` 按钮切换降序/升序 |
| 翻页 | 底部 `‹ 上一页` / `下一页 ›` |

### 5.3 批量删除

1. 勾选目标用户复选框（可单选或多选）
2. 点击 `🗑 批量删除` 按钮
3. 确认对话框 → 点击确定
4. 删除完成提示

**自删保护**：当前登录账号行显示灰色"当前账号"标签，复选框禁用，全选自动跳过。即使绕过 UI 勾选，删除请求发出前仍会强制过滤当前账号 ID。

### 5.4 批量封禁/解封

1. 勾选目标用户
2. 点击 `🚫 批量封禁` 或 `✅ 批量解禁`
3. 确认对话框 → 点击确定
4. 逐个执行，完成后显示成功/失败统计

单个操作：点击用户行操作列的 `封` / `解` 按钮。

### 5.5 CSV 批量创建用户

#### CSV 格式

```csv
username,email,password,role
zhang3,zhang3@example.com,Temp123456,user
li4,li4@example.com,Temp123456,admin
```

| 列名 | 必填 | 说明 |
|------|------|------|
| `username` / `nick` / `user` / `name` | 否 | 昵称，留空则取邮箱 @ 前部分 |
| `email` / `mail` | 是 | 邮箱（必须含 @） |
| `password` / `pass` | 否 | 密码，留空默认 `Temp123456` |
| `role` / `group` / `group_name` | 否 | `admin` 或 `user`，留空默认 `user` |

**特性**：
- 表头自动识别，列顺序任意
- 支持文件上传或直接粘贴
- 重复邮箱自动去重
- 逐行执行，每行独立成功/失败，日志实时显示

#### 操作步骤

1. 点击"点击选择 CSV 文件"选择文件，或展开"或直接粘贴 CSV 内容"粘贴文本
2. 点击 `导入并创建`
3. 确认对话框显示将创建的用户数量 → 确定开始
4. 实时日志显示每行结果：`✔ xxx@example.com 创建成功` 或 `✘ xxx@example.com 失败：原因`
5. 完成后显示统计：`导入完成：成功 N/M`

### 5.6 语言切换

| 操作 | 方法 |
|------|------|
| 切换语言 | 点击页面顶部右侧 `EN`（切英文）或 `中文`（切中文） |
| 自动检测 | 首次访问按 Cloudreve 语言设置 > 浏览器语言自动选择 |
| 持久化 | 选择存 localStorage，刷新保持 |

### 5.7 退出登录

点击页面顶部右侧 `退出登录` 按钮，清除本页会话并显示登录弹层。

---

## 六、卸载

### 6.1 一键卸载（推荐）

```powershell
# 仅移除入口按钮（保留页面文件）
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 -Email admin@example.com -Password yourpass -Uninstall

# 移除入口按钮 + 删除页面文件
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 -Email admin@example.com -Password yourpass -Uninstall -RemovePage
```

### 6.2 手动卸载

1. 删除静态目录下的页面文件：`data/statics/pages/batch-user-mgr.html`
2. 后台 → 设置 → "页脚代码" → 清空 `<!-- crbm:begin -->` 到 `<!-- crbm:end -->` 之间的内容 → 保存

---

## 七、远程/多实例部署

### 同机部署（脚本与 Cloudreve 同机）

直接使用默认参数，脚本自动将页面文件复制到 `data/statics/pages/`。

### 异机部署（脚本在管理机，Cloudreve 在服务器）

1. 手动将 `batch-user-mgr.html` 复制到服务器的 `data/statics/pages/` 目录
2. 在管理机运行脚本，指定服务地址：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 `
  -Email admin@example.com -Password yourpass `
  -StaticsDir \\10.139.73.2\cloudreve\data\statics\pages
```

> 若 `StaticsDir` 不可写（网络路径权限问题），脚本会在步骤 2 报错，但入口按钮仍会写入（步骤 1 登录 + 步骤 3 写设置不依赖静态目录）。页面文件需手动拷贝。

### 部署到多个 Cloudreve 实例

对每个实例分别运行脚本，修改 `-Server` 参数即可。脚本幂等，重复执行不会产生重复注入。

---

## 八、常见问题

### Q1：点击浮动按钮没反应？

检查浏览器控制台（F12）是否有 JS 报错。常见原因：
- 页脚代码设置未保存成功 → 后台重新粘贴
- 浏览器扩展拦截 → 用无痕模式测试

### Q2：管理页面显示"登录已失效"？

Token 有效期 1 小时。解决方式：
- 确认 Cloudreve 后台仍处于登录状态
- 刷新页面，会自动尝试用 refresh_token 续期
- 续期失败则显示登录弹层，重新输入管理员邮箱密码

### Q3：CSV 导入显示成功但用户不存在？

本插件已修复此问题。根因是旧版页面误把创建请求发给了搜索端点。当前版本使用正确的 `PUT /api/v4/admin/user` 创建接口，导入日志会显示真实的成功/失败状态。

### Q4：能否删除当前登录的管理员账号？

不能。插件内置三重自删保护：
1. 当前账号行无删除/封禁按钮，复选框禁用
2. 全选操作自动跳过当前账号
3. 删除/封禁请求发出前强制过滤当前账号 ID

### Q5：升级 Cloudreve 后插件还在吗？

- **入口按钮**：在。存储在数据库 `settings` 表，升级不丢失。
- **管理页面文件**：可能丢失。静态目录 `data/statics/pages/` 可能被升级包覆盖，需重新运行安装脚本或手动复制文件。

### Q6：如何修改浮动按钮样式/位置？

编辑 `install-batch-user-mgr.ps1` 中 `btn.style.cssText` 行，修改 CSS 属性后重新运行脚本。或在后台"页脚代码"中直接编辑 `<!-- crbm:begin -->` 到 `<!-- crbm:end -->` 之间的内容。

### Q7：批量操作会触发限流吗？

单个请求之间有 250ms 间隔，正常使用不会触发限流。如遇大量用户（100+）建议分批操作。

---

## 九、技术参考

### API 端点

| 操作 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 登录 | POST | `/api/v4/session/token` | 获取 access_token + refresh_token |
| 刷新 token | POST | `/api/v4/session/token/refresh` | access_token 过期时自动调用 |
| 用户列表 | POST | `/api/v4/admin/user` | body 传搜索条件，page 从 1 开始 |
| 用户详情 | GET | `/api/v4/admin/user/{id}` | 获取单个用户完整信息 |
| 创建用户 | PUT | `/api/v4/admin/user` | body: `{user:{...}, password}` |
| 更新用户 | PUT | `/api/v4/admin/user/{id}` | body: `{user:{...}, two_fa:'clear'}` |
| 批量删除 | POST | `/api/v4/admin/user/batch/delete` | body: `{ids:[...]}` |
| 用户组列表 | POST | `/api/v4/admin/group` | 获取用户组 ID 映射 |
| 读取设置 | POST | `/api/v4/admin/settings` | body: `{keys:['siteScript']}` |
| 写入设置 | PATCH | `/api/v4/admin/settings` | body: `{settings:{siteScript:'...'}}` |

### 文件清单

| 文件 | 路径 | 说明 |
|------|------|------|
| 管理页面 | `data/statics/pages/batch-user-mgr.html` | 主界面（单文件，零依赖） |
| 安装脚本 | `install-batch-user-mgr.ps1` | 一键部署/卸载（可随意放置） |
| 本文档 | `README-batch-user-mgr.md` | 安装与使用说明 |

### localStorage 键

| 键 | 作用 | 写入者 |
|----|------|--------|
| `cloudreve_session` | Cloudreve 原生会话 | Cloudreve 前端 |
| `crbm_session` | 本页独立登录会话（回退用） | 批量管理页 |
| `crbm_lang` | 语言偏好（`zh`/`en`） | 批量管理页 |
| `i18nextLng` | Cloudreve 语言设置 | Cloudreve i18next |

---

## 十、更新日志

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-01 | 0.1 | 初始版本：页面开发、API 适配、CSV 模板 |
| 2026-09-01 | 0.2 | 修复列表 API 路径（POST 搜索端点，page 从 1 开始） |
| 2026-09-01 | 0.3 | 修复"导入成功但未生效"（改用 PUT 创建接口） |
| 2026-09-01 | 0.4 | 添加自删保护（超管不能删除自己） |
| 2026-09-01 | 0.5 | 集成进原系统（siteScript 注入浮动按钮） |
| 2026-09-01 | 0.6 | 免登录继承 Cloudreve 会话 |
| 2026-09-01 | 0.7 | URL 隐藏（iframe 全屏覆盖） |
| 2026-09-02 | 1.0 | 中英双语、一键安装脚本、两行双语浮动按钮 |

---

> **维护方**：AI 助手（Hermes Agent）
> **反馈**：如遇问题请检查控制台报错并参考「常见问题」章节
