#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cloudreve CSV 用户导入（绕过浏览器编码问题）。

用法:
  python import_users.py 名单.csv
  python import_users.py 名单.csv --server http://10.139.73.2:5212
  python import_users.py 名单.csv --dry-run   # 只预览不写入

CSV 列（表头自动识别，顺序任意）:
  username/nick/user/name, email/mail, password/pass, role/group
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path


def decode_bytes(raw: bytes) -> str:
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig")
    if raw.startswith(b"\xff\xfe"):
        return raw.decode("utf-16le")
    if raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16be")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("gb18030")


def parse_csv(text: str) -> list[dict]:
    text = text.lstrip("﻿")
    reader = csv.reader(text.splitlines())
    rows = [list(r) for r in reader if any(c.strip() for c in r)]
    if not rows:
        return []
    head = [c.strip().lower() for c in rows[0]]

    def col(*names: str) -> int:
        for n in names:
            if n in head:
                return head.index(n)
        return -1

    iu, ie, ip, ir = (
        col("username", "user", "nick", "name"),
        col("email", "mail"),
        col("password", "pass"),
        col("role", "group", "group_name"),
    )
    has_header = iu >= 0 or ie >= 0
    data_rows = rows[1:] if has_header else rows
    out: list[dict] = []
    seen: set[str] = set()
    for p in data_rows:
        p = [c.strip() for c in p]
        email = p[ie] if ie >= 0 and ie < len(p) else (p[0] if p else "")
        if not email or "@" not in email:
            continue
        user = (p[iu] if iu >= 0 and iu < len(p) else "") or email.split("@")[0]
        password = (p[ip] if ip >= 0 and ip < len(p) else "") or "Temp123456"
        role = (p[ir] if ir >= 0 and ir < len(p) else "") or "user"
        key = email.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(
            {
                "email": email,
                "nick": unicodedata.normalize("NFC", user.strip()),
                "password": password,
                "role": role.strip().lower() or "user",
            }
        )
    return out


def api(server: str, method: str, path: str, body=None, token: str | None = None):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
    req = urllib.request.Request(server.rstrip("/") + path, data=data, method=method)
    req.add_header("Content-Type", "application/json; charset=utf-8")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def resolve_group_id(groups: list[dict], role: str) -> int:
    want = (role or "user").lower()
    for g in groups:
        if str(g.get("name", "")).lower() == want:
            return int(g["id"])
    return 1 if want == "admin" else 2


def main() -> int:
    ap = argparse.ArgumentParser(description="Cloudreve CSV import with correct encoding")
    ap.add_argument("csv_file", help="CSV path (UTF-8 / GBK / GB18030)")
    ap.add_argument("--server", default="http://10.139.73.2:5212")
    ap.add_argument("--email", default="onereal@qq.com")
    ap.add_argument("--password", default="admin888")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    raw = Path(args.csv_file).read_bytes()
    text = decode_bytes(raw)
    rows = parse_csv(text)
    if not rows:
        print("未解析到有效行（需要含 @ 的 email 列）")
        return 1

    print(f"解析到 {len(rows)} 行，预览:")
    for r in rows[:8]:
        print(f"  {r['nick']}  <{r['email']}>  role={r['role']}")
        print(f"    nick hex={r['nick'].encode('utf-8').hex()}")
    if len(rows) > 8:
        print("  ...")

    if args.dry_run:
        print("dry-run 结束，未写入")
        return 0

    login = api(args.server, "POST", "/api/v4/session/token", {"email": args.email, "password": args.password})
    if login.get("code") != 0:
        print("登录失败:", login.get("msg"))
        return 1
    token = login["data"]["token"]["access_token"]
    try:
        g = api(args.server, "POST", "/api/v4/admin/group",
                {"page": 1, "page_size": 50, "order_by": "id", "order_direction": "asc", "conditions": {}},
                token)
        groups = g.get("data", {}).get("groups") or []
    except Exception:
        groups = []

    ok = fail = 0
    for r in rows:
        gid = resolve_group_id(groups, r["role"])
        try:
            resp = api(
                args.server,
                "PUT",
                "/api/v4/admin/user",
                {
                    "user": {
                        "id": 0,
                        "email": r["email"],
                        "nick": r["nick"],
                        "status": "active",
                        "group_users": gid,
                        "edges": {},
                    },
                    "password": r["password"],
                },
                token,
            )
            if resp.get("code") == 0:
                nick = (resp.get("data") or {}).get("nick")
                print(f"✔ 新建 {r['email']}  nick={nick!r}")
                ok += 1
                continue
            # 邮箱已存在 → 按邮箱查出用户并改正昵称
            found = api(
                args.server,
                "POST",
                "/api/v4/admin/user",
                {
                    "page": 1,
                    "page_size": 5,
                    "order_by": "id",
                    "order_direction": "desc",
                    "conditions": {"user_email": r["email"]},
                },
                token,
            )
            users = (found.get("data") or {}).get("users") or []
            hit = next((u for u in users if (u.get("email") or "").lower() == r["email"].lower()), None)
            if not hit:
                print(f"✘ {r['email']}  {resp.get('msg')}")
                fail += 1
                continue
            detail = api(args.server, "GET", f"/api/v4/admin/user/{hit['id']}", token=token)
            user = detail.get("data") or {}
            if "user" in user:
                user = user["user"]
            user["nick"] = r["nick"]
            upd = api(
                args.server,
                "PUT",
                f"/api/v4/admin/user/{hit['id']}",
                {"user": user, "two_fa": "clear"},
                token,
            )
            if upd.get("code") == 0:
                print(f"✔ 改昵称 #{hit['id']} {r['email']}  → {r['nick']!r}")
                ok += 1
            else:
                print(f"✘ {r['email']}  改昵称失败 {upd.get('msg')}")
                fail += 1
        except urllib.error.HTTPError as e:
            print(f"✘ {r['email']}  HTTP {e.code}")
            fail += 1
        time.sleep(0.15)

    print(f"完成: 成功 {ok}/{len(rows)}")
    return 0 if fail == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
