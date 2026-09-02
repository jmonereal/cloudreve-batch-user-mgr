# Cloudreve Batch User Manager Plugin — Installation & Usage Guide

> Version: 1.0 · For Cloudreve v4.x · Updated: 2026-09-02 · [中文文档](README.zh-CN.md)

---

## 1. Overview

A lightweight plugin that adds **bulk user management** capabilities to the Cloudreve admin panel — no source code modification, no compilation required.

### Core Features

| Feature | Description |
|---------|-------------|
| User List | Pagination, search (with @ by email, otherwise by nickname), filter by group/status, sort by ID |
| Bulk Delete | Single or batch deletion with confirmation |
| Bulk Ban/Unban | Toggle user status (active / manual_banned) individually or in bulk |
| CSV Bulk Create | File upload or direct paste, auto header detection, any column order |
| Self-Delete Protection | Currently signed-in account cannot be deleted/banned (UI hidden + fallback filter) |
| Session Inheritance | Auto-reads Cloudreve admin session, no repeated password entry |
| URL Hidden | Entry button opens via full-screen iframe overlay, address bar stays `/admin/user` |
| Bilingual (ZH/EN) | Follows Cloudreve language / browser language, manual switch with persistence |

### How It Works

| Component | Implementation | Storage |
|-----------|----------------|---------|
| Manager page | Pure static HTML (single file, zero dependencies) | `data/statics/pages/batch-user-mgr.html` |
| Entry button | Official "Footer Code" setting (`siteScript`) injection | Database `settings` table |
| Installer | PowerShell script, deploys via Cloudreve API | Anywhere, not resident |

**No** backend code changes, database schema changes, or binary patches. Cloudreve upgrades preserve the entry button (stored in DB); the manager page file may need re-copying if the static directory is overwritten.

---

## 2. Requirements

| Item | Requirement |
|------|-------------|
| Cloudreve | v4.x (tested on 4.1.5) |
| Admin Account | Email + password with user management permissions |
| Static Directory | `data/statics/pages/` writable (under Cloudreve install dir) |
| Script Runtime | Windows + PowerShell 5.1+ (pre-installed, no extra setup) |
| Network | Script machine can reach Cloudreve service port |

---

## 3. One-Click Installation (Recommended)

### 3.1 Prepare Files

Place both files in the same directory:

```
your-folder/
  ├── batch-user-mgr.html          # Manager page
  └── install-batch-user-mgr.ps1   # One-click installer script
```

### 3.2 Run Installation

Open PowerShell, navigate to the directory, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 `
  -Email admin@example.com `
  -Password yourpass
```

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Server` | Yes | `http://10.139.73.2:5212` | Cloudreve service URL (with port) |
| `-Email` | Yes | — | Admin email |
| `-Password` | Yes | — | Admin password |
| `-StaticsDir` | No | `Z:\data\statics\pages` | Cloudreve static directory path (modify for remote) |
| `-PageSource` | No | Same as script | Manager page source path |

### 3.3 Expected Output

```
[1/4] Login successful (admin@example.com)
[2/4] Page deployed: Z:\data\statics\pages\batch-user-mgr.html (route /pages/batch-user-mgr.html)
[3/4] Entry button written to 'Footer Code' setting (stored in DB, survives upgrades)
[4/4] Verification passed: /admin/user page contains injection script.
```

Seeing `[4/4] Verification passed` means success.

### 3.4 Post-Install Verification

1. Log in to Cloudreve admin in browser
2. Navigate to **User Management** (`/admin/user`)
3. Green floating button appears at bottom-right with two lines:
   - Line 1: `👥 批量用户管理`
   - Line 2: `Batch User Manager`
4. Click button → full-screen overlay with batch manager, address bar unchanged
5. `‹ Back to Admin` button at top-right closes overlay

---

## 4. Manual Installation (No PowerShell)

If you can't run the script, deploy manually in two steps.

### Step 1: Deploy Page File

Copy `batch-user-mgr.html` to Cloudreve's static directory:

```
<Cloudreve-install-dir>/data/statics/pages/batch-user-mgr.html
```

Verify: open `http://<your-address>/pages/batch-user-mgr.html` in browser — should show manager page.

### Step 2: Inject Entry Button

1. Log in to Cloudreve admin → **Settings** → find **"Footer Code"** setting
2. Paste the following:

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

3. Save settings
4. Visit `/admin/user` to confirm button appears

---

## 5. Usage Guide

### 5.1 Opening the Manager

1. Log in to Cloudreve as admin
2. Navigate to any admin page (e.g., `/admin/user` User Management)
3. Click the green floating button at bottom-right
4. Batch manager opens as full-screen overlay

### 5.2 User List

| Action | Method |
|--------|--------|
| Search | Type in search box: with `@` searches by email, otherwise by nickname |
| Filter group | Dropdown select (Admin / User etc.) |
| Filter status | Dropdown select (Active/Inactive/Banned/Sys. banned) |
| Page size | Dropdown select 10/25/50/100 |
| Sort | Click `ID ↓/↑` button to toggle desc/asc |
| Pagination | `‹ Prev` / `Next ›` at bottom |

### 5.3 Bulk Delete

1. Check target user checkboxes (single or multiple)
2. Click `🗑 Delete Selected`
3. Confirm dialog → OK
4. Deletion complete toast

**Self-Delete Protection**: Current account row shows gray "Current account" label, checkbox disabled, select-all auto-skips. Even bypassing UI selection, delete requests filter out current account ID before sending.

### 5.4 Bulk Ban/Unban

1. Check target users
2. Click `🚫 Ban Selected` or `✅ Unban Selected`
3. Confirm dialog → OK
4. Executes per-user, shows success/failure stats when done

Single operation: click `Ban` / `Unban` button in user row action column.

### 5.5 CSV Bulk Create Users

#### CSV Format

```csv
username,email,password,role
zhang3,zhang3@example.com,Temp123456,user
li4,li4@example.com,Temp123456,admin
```

| Column | Required | Description |
|--------|----------|-------------|
| `username` / `nick` / `user` / `name` | No | Nickname; defaults to email prefix before @ |
| `email` / `mail` | Yes | Email (must contain @) |
| `password` / `pass` | No | Password; defaults to `Temp123456` |
| `role` / `group` / `group_name` | No | `admin` or `user`; defaults to `user` |

**Features**:
- Auto header detection, any column order
- File upload or direct paste
- Duplicate emails auto-deduplicated
- Per-row execution, each row succeeds/fails independently, real-time log

#### Steps

1. Click "Click to choose a CSV file" to select file, or expand "Or paste CSV content directly" to paste text
2. Click `Import & Create`
3. Confirm dialog shows user count → OK to start
4. Real-time log shows each row: `✔ xxx@example.com created` or `✘ xxx@example.com failed: reason`
5. Completion summary: `Done: N/M succeeded`

### 5.6 Language Switch

| Action | Method |
|--------|--------|
| Switch language | Click `EN` (to English) or `中文` (to Chinese) at top-right |
| Auto-detect | First visit: Cloudreve language > browser language |
| Persistence | Saved to localStorage, persists across refreshes |

### 5.7 Sign Out

Click `Sign out` button at top-right to clear session and show login dialog.

---

## 6. Uninstallation

### 6.1 One-Click Uninstall (Recommended)

```powershell
# Remove entry button only (keep page file)
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 -Email admin@example.com -Password yourpass -Uninstall

# Remove entry button + delete page file
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 -Email admin@example.com -Password yourpass -Uninstall -RemovePage
```

### 6.2 Manual Uninstall

1. Delete page file: `data/statics/pages/batch-user-mgr.html`
2. Admin → Settings → "Footer Code" → clear content between `<!-- crbm:begin -->` and `<!-- crbm:end -->` → Save

---

## 7. Remote / Multi-Instance Deployment

### Same Machine (script and Cloudreve on same host)

Use default parameters — script auto-copies page file to `data/statics/pages/`.

### Remote Machine (script on admin workstation, Cloudreve on server)

1. Manually copy `batch-user-mgr.html` to server's `data/statics/pages/` directory
2. Run script on admin machine with server address:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-batch-user-mgr.ps1 `
  -Server http://10.139.73.2:5212 `
  -Email admin@example.com -Password yourpass `
  -StaticsDir \\10.139.73.2\cloudreve\data\statics\pages
```

> If `StaticsDir` is not writable (network path permissions), step 2 errors, but the entry button is still written (login + settings write don't depend on static dir). Page file needs manual copy.

### Multiple Cloudreve Instances

Run script for each instance with different `-Server` parameter. Script is idempotent — repeated runs don't create duplicate injections.

---

## 8. FAQ

### Q1: Floating button doesn't respond when clicked?

Check browser console (F12) for JS errors. Common causes:
- Footer Code setting not saved → re-paste in admin
- Browser extension blocking → test in incognito mode

### Q2: Manager shows "Session expired"?

Token validity is 1 hour. Solutions:
- Ensure Cloudreve admin is still logged in
- Refresh page — auto-attempts refresh_token renewal
- If renewal fails, login dialog appears — re-enter admin credentials

### Q3: CSV import shows success but users don't exist?

This issue was fixed. Root cause: old version sent create requests to the search endpoint. Current version uses correct `PUT /api/v4/admin/user` create endpoint — import log shows real success/failure status.

### Q4: Can I delete the currently signed-in admin account?

No. Three layers of self-delete protection:
1. Current account row has no delete/ban buttons, checkbox disabled
2. Select-all operation auto-skips current account
3. Delete/ban requests filter out current account ID before sending

### Q5: Does the plugin survive Cloudreve upgrades?

- **Entry button**: Yes. Stored in database `settings` table, survives upgrades.
- **Manager page file**: Maybe not. Static directory `data/statics/pages/` may be overwritten by upgrade package — re-run installer or manually copy file.

### Q6: How to modify floating button style/position?

Edit `btn.style.cssText` line in `install-batch-user-mgr.ps1`, modify CSS, re-run script. Or edit `<!-- crbm:begin -->` to `<!-- crbm:end -->` content directly in admin "Footer Code" setting.

### Q7: Does bulk operation trigger rate limiting?

250ms delay between individual requests — normal usage won't trigger limits. For large batches (100+), consider splitting into smaller groups.

---

## 9. Technical Reference

### API Endpoints

| Operation | Method | Path | Notes |
|-----------|--------|------|-------|
| Login | POST | `/api/v4/session/token` | Get access_token + refresh_token |
| Refresh token | POST | `/api/v4/session/token/refresh` | Auto-called when access_token expires |
| User list | POST | `/api/v4/admin/user` | Search conditions in body, page starts from 1 |
| User detail | GET | `/api/v4/admin/user/{id}` | Get full user info |
| Create user | PUT | `/api/v4/admin/user` | Body: `{user:{...}, password}` |
| Update user | PUT | `/api/v4/admin/user/{id}` | Body: `{user:{...}, two_fa:'clear'}` |
| Batch delete | POST | `/api/v4/admin/user/batch/delete` | Body: `{ids:[...]}` |
| Group list | POST | `/api/v4/admin/group` | Get group ID mapping |
| Read settings | POST | `/api/v4/admin/settings` | Body: `{keys:['siteScript']}` |
| Write settings | PATCH | `/api/v4/admin/settings` | Body: `{settings:{siteScript:'...'}}` |

### File Manifest

| File | Path | Description |
|------|------|-------------|
| Manager page | `data/statics/pages/batch-user-mgr.html` | Main UI (single file, zero deps) |
| Installer | `install-batch-user-mgr.ps1` | One-click deploy/uninstall (place anywhere) |
| This doc (EN) | `README.md` | English documentation |
| This doc (ZH) | `README.zh-CN.md` | Chinese documentation |

### localStorage Keys

| Key | Purpose | Writer |
|-----|---------|--------|
| `cloudreve_session` | Cloudreve native session | Cloudreve frontend |
| `crbm_session` | Independent login session (fallback) | Batch manager page |
| `crbm_lang` | Language preference (`zh`/`en`) | Batch manager page |
| `i18nextLng` | Cloudreve language setting | Cloudreve i18next |

---

## 10. Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-09-01 | 0.1 | Initial: page dev, API adaptation, CSV template |
| 2026-09-01 | 0.2 | Fixed list API path (POST search endpoint, page from 1) |
| 2026-09-01 | 0.3 | Fixed "import succeeds but no effect" (switched to PUT create endpoint) |
| 2026-09-01 | 0.4 | Added self-delete protection (admin can't delete self) |
| 2026-09-01 | 0.5 | Integrated into native admin (siteScript injection) |
| 2026-09-01 | 0.6 | Session inheritance (no repeated login) |
| 2026-09-01 | 0.7 | URL hidden (iframe full-screen overlay) |
| 2026-09-02 | 1.0 | Bilingual ZH/EN, one-click installer, two-line bilingual floating button |

---

> **Maintained by**: AI Assistant (Hermes Agent)
> **Support**: For issues, check browser console errors and refer to FAQ section
