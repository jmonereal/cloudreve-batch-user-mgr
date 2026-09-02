# Cloudreve 批量用户管理 - 一键安装/卸载脚本
# 无需修改源代码：页面 = 复制静态文件；入口按钮 = 官方"页脚代码"设置(siteScript)
#
# 用法(在脚本目录执行):
#   安装:  powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 -Server http://10.139.73.2:5212 -Email admin@example.com -Password yourpass
#   卸载:  powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 -Server http://10.139.73.2:5212 -Email admin@example.com -Password yourpass -Uninstall
#   卸载并删除页面文件:  追加 -RemovePage
param(
  [string]$Server = 'http://10.139.73.2:5212',
  [string]$Email = 'onereal@qq.com',
  [string]$Password = 'admin888',
  [string]$StaticsDir = 'Z:\data\statics\pages',   # Cloudreve 静态目录(data/statics/pages)
  [string]$PageSource = '',                        # 页面文件来源, 默认取脚本同目录的 batch-user-mgr.html
  [switch]$Uninstall,
  [switch]$RemovePage
)
$ErrorActionPreference = 'Stop'
$M1 = '<!-- crbm:begin -->'
$M2 = '<!-- crbm:end -->'
$Page = 'batch-user-mgr.html'

# ---------- 登录获取 token ----------
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -Uri "$Server/api/v4/session/token" -Method Post -Body $loginBody -ContentType 'application/json'
if ($login.code -ne 0) { throw "登录失败: $($login.msg)" }
$tok = $login.data.token.access_token
$H = @{ Authorization = "Bearer $tok" }
Write-Host "[1/4] 登录成功 ($Email)" -ForegroundColor Green

# ---------- 读取当前 siteScript ----------
$cur = Invoke-RestMethod -Uri "$Server/api/v4/admin/settings" -Method Post -Body '{"keys":["siteScript"]}' -ContentType 'application/json' -Headers $H
$old = [string]$cur.data.siteScript

if ($Uninstall) {
  # 移除标记块; 若是无标记的旧版注入(整段都是我们的), 清空
  if ($old.Contains($M1)) {
    $new = [regex]::Replace($old, '(?s)' + [regex]::Escape($M1) + '.*?' + [regex]::Escape($M2), '').Trim()
  } elseif ($old.Contains('crbm-entry')) {
    $new = ''
  } else {
    $new = $old
  }
  $body = @{ settings = @{ siteScript = $new } } | ConvertTo-Json -Depth 4 -Compress
  $r = Invoke-RestMethod -Uri "$Server/api/v4/admin/settings" -Method Patch -Body $body -ContentType 'application/json' -Headers $H
  if ($r.code -ne 0) { throw "写入设置失败: $($r.msg)" }
  Write-Host "[2/4] 已从页脚代码移除注入脚本" -ForegroundColor Green
  if ($RemovePage) {
    $f = Join-Path $StaticsDir $Page
    if (Test-Path $f) { Remove-Item $f -Force; Write-Host "[3/4] 已删除 $f" -ForegroundColor Green }
  } else { Write-Host "[3/4] 保留页面文件 $StaticsDir\$Page (加 -RemovePage 可删除)" -ForegroundColor Yellow }
  Write-Host "[4/4] 卸载完成。" -ForegroundColor Cyan
  exit 0
}

# ---------- 安装 ----------
# 1. 复制页面文件
if (-not $PageSource) { $PageSource = Join-Path $PSScriptRoot $Page }
if (-not (Test-Path $PageSource)) { throw "找不到页面文件 $PageSource - 请将其与脚本放在同一目录, 或用 -PageSource 指定" }
if (-not (Test-Path $StaticsDir)) { throw "静态目录不存在: $StaticsDir - 远程部署请先手动拷贝页面文件到目标机 data/statics/pages/" }
$dest = Join-Path $StaticsDir $Page
if ((Resolve-Path $PageSource -ErrorAction SilentlyContinue).Path -ne (Resolve-Path $StaticsDir -ErrorAction SilentlyContinue).Path + '\' + $Page) {
  Copy-Item $PageSource $dest -Force
}
Write-Host "[2/4] 页面已就位: $dest (访问路由 /pages/$Page)" -ForegroundColor Green

# 2. 组装注入脚本(替换旧块, 幂等可重复执行; emoji/中文均用 JS 转义保证纯 ASCII 传输)
$injector = @'
<!-- crbm:begin -->
<script>
(function(){
  var btn=document.createElement('div');
  btn.id='crbm-entry';
  btn.style.cssText='display:none;position:fixed;right:20px;bottom:20px;z-index:99998';
  btn.innerHTML='<span style="display:inline-flex;flex-direction:column;align-items:center;gap:2px;padding:10px 18px;border-radius:16px;background:#00d4aa;color:#001a15;font-weight:600;font-family:system-ui;cursor:pointer;box-shadow:0 4px 16px rgba(0,0,0,.35);line-height:1.3"><span style="font-size:14px">\uD83D\uDC65 \u6279\u91cf\u7528\u6237\u7ba1\u7406</span><span style="font-size:11px;opacity:.75">Batch User Manager</span></span>';
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
  window.__crbm_v2=true;
})();
</script>
<!-- crbm:end -->
'@

# 3. 写入设置(移除旧块后追加最新版, 不碰用户已有的其他页脚内容)
$base = $old
if ($base.Contains($M1)) {
  $base = [regex]::Replace($base, '(?s)' + [regex]::Escape($M1) + '.*?' + [regex]::Escape($M2), '').Trim()
} elseif ($base.Contains('crbm-entry')) {
  $base = ''
}
$newVal = ($base + "`r`n" + $injector).Trim()
$body = @{ settings = @{ siteScript = $newVal } } | ConvertTo-Json -Depth 4 -Compress
$r = Invoke-RestMethod -Uri "$Server/api/v4/admin/settings" -Method Patch -Body $body -ContentType 'application/json' -Headers $H
if ($r.code -ne 0) { throw "写入设置失败: $($r.msg)" }
Write-Host "[3/4] 入口按钮已写入官方'页脚代码'设置 (存数据库, 升级不丢失)" -ForegroundColor Green

# 4. 验证服务端渲染结果
$html = Invoke-WebRequest -Uri "$Server/admin/user" -UseBasicParsing -Headers $H
$ok = $html.Content.Contains('crbm:begin') -and $html.Content.Contains('closeBatchMgr')
if ($ok) {
  Write-Host "[4/4] 验证通过: /admin/user 页面已包含注入脚本。管理员登录后台即可看到右下角'批量用户管理'按钮。" -ForegroundColor Cyan
} else {
  Write-Warning "[4/4] 服务端页面未检测到注入脚本, 请检查 siteScript 设置。"
}
