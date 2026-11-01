#!/usr/bin/env python3
"""校正 Dockerfile 里失效的 apk 版本 pin。

为什么需要
----------
Dockerfile 里的 apk 包全部钉死版本（从上游 hassio-addons/app-node-red 同步下来）。
Alpine 一旦发布新的 revision（例如 nodejs 24.22.1-r0 -> 24.22.1-r1），旧版本的包会
从仓库里撤下，`apk add nodejs=24.22.1-r0` 直接报 "unable to select packages"，退出码
2，镜像构建在第一个 RUN 层就失败（2026-10-30 nodejs r0->r1、2026-10-28 python3-dev
都是这个原因）。

这个脚本扫描 Dockerfile 里 `apk add` 段内的 `包名=版本`，对照当前 APKINDEX 校验：
版本已不存在的改成仓库里的当前版本（构建会用到 amd64 / aarch64 两个架构，取两边
都存在的那个）。下面几种情况保留原样并提示，交给人工决定：

  * 源里已找不到这个包（改名或被移除）
  * 新版本主版本号变了（24.x -> 26.x 这类，可能还要同步改配置）
  * 失效的 pin 超过 MAX_STALE 个 —— 大概率是基础镜像换了 Alpine 分支，
    ALPINE_BRANCH 该更新了，这时候自动改反而会把版本改错

用法
----
    python3 node-red/refresh_pins.py                 # 直接修正 node-red/Dockerfile
    python3 node-red/refresh_pins.py --check         # 只检查，需要修正时退出码 1
    python3 node-red/refresh_pins.py --branch edge --arch x86_64
    ALPINE_MIRROR=https://mirrors.aliyun.com/alpine python3 node-red/refresh_pins.py

网络不通时只告警、不阻断（本地或 CI 的 CDN 抖动不应该让构建挂掉）。
"""

from __future__ import annotations

import argparse
import io
import os
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

# 基础镜像 ghcr.io/hassio-addons/base:21.0.10 基于 Alpine 3.24（app-base 的
# alpine_3_24 变体）。base 镜像大版本变化时这里要跟着改。
ALPINE_BRANCH = "3.24"
REPOS = ("main", "community")
ARCHES = ("x86_64", "aarch64")
MIRRORS = (
    "https://dl-cdn.alpinelinux.org/alpine",
    "https://mirrors.aliyun.com/alpine",
)
TIMEOUTS = (15, 90)
MAX_STALE = 3

ADDON_DIR = Path(__file__).resolve().parent
DEFAULT_DOCKERFILE = ADDON_DIR / "Dockerfile"

# 只匹配 apk add 段内的 "name=version"（--virtual / --no-cache 这类选项不会命中）
PIN_RE = re.compile(r"(?<![\w+.-])([a-z0-9][a-z0-9+._-]*)=([0-9][0-9A-Za-z._-]*)")


class DownloadError(RuntimeError):
    """apk 源索引拿不到。"""


class TooManyStale(RuntimeError):
    """失效的 pin 太多，怀疑 Alpine 分支变了，不敢自动改。"""


# --------------------------------------------------------------------------- #
# 取源索引
# --------------------------------------------------------------------------- #
def branch_path(branch: str) -> str:
    if branch in ("edge", "latest-stable") or branch.startswith("v"):
        return branch
    return f"v{branch}"


def parse_index(blob: bytes) -> dict[str, str]:
    index: dict[str, str] = {}
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tar:
        member = next((m for m in tar.getmembers() if m.name == "APKINDEX"), None)
        if member is None or member.isfile() is False:
            raise ValueError("压缩包里没有 APKINDEX")
        text = tar.extractfile(member).read().decode("utf-8", "replace")

    for block in text.split("\n\n"):
        name = version = None
        for line in block.split("\n"):
            if line.startswith("P:"):
                name = line[2:]
            elif line.startswith("V:"):
                version = line[2:]
        if name and version:
            index[name] = version
    return index


_INDEX_CACHE: dict[tuple[str, str, str], dict[str, str]] = {}


def fetch_index(branch: str, repo: str, arch: str) -> dict[str, str]:
    key = (branch, repo, arch)
    if key in _INDEX_CACHE:
        return _INDEX_CACHE[key]

    override = os.environ.get("ALPINE_MIRROR")
    mirrors = (override.rstrip("/"),) if override else MIRRORS
    timeouts = (90,) if override else TIMEOUTS

    last_error = ""
    for mirror, timeout in zip(mirrors, timeouts):
        url = f"{mirror}/{branch_path(branch)}/{repo}/{arch}/APKINDEX.tar.gz"
        try:
            with urllib.request.urlopen(url, timeout=timeout) as response:
                index = parse_index(response.read())
        except Exception as exc:  # noqa: BLE001 - 网络/解压异常一律换下一个源
            last_error = f"{url}: {exc}"
            continue
        _INDEX_CACHE[key] = index
        return index

    raise DownloadError(last_error or f"{repo}/{arch} 索引下载失败")


def collect_versions(packages, branch: str, arches) -> dict[str, dict[str, str]]:
    """包名 -> {架构: 当前版本}；main 里找不到再去 community 找。"""
    versions: dict[str, dict[str, str]] = {name: {} for name in packages}
    for repo in REPOS:
        unresolved = any(
            arch not in versions[name] for name in versions for arch in arches
        )
        if not unresolved:
            break
        for arch in arches:
            index = fetch_index(branch, repo, arch)
            for name in versions:
                if arch not in versions[name] and name in index:
                    versions[name][arch] = index[name]
    return versions


# --------------------------------------------------------------------------- #
# 解析 Dockerfile
# --------------------------------------------------------------------------- #
def find_pins(lines: list[str]) -> list[tuple[int, str, str]]:
    """返回 [(行号, 包名, 版本)]，只认 apk add 命令行（含续行）里的 pin。"""
    pins: list[tuple[int, str, str]] = []
    in_apk_add = False
    for lineno, line in enumerate(lines):
        if "apk add" in line:
            in_apk_add = True
        if not in_apk_add:
            continue
        for match in PIN_RE.finditer(line):
            pins.append((lineno, match.group(1), match.group(2)))
        if not line.rstrip().endswith("\\"):
            in_apk_add = False
    return pins


def major(version: str) -> str:
    match = re.match(r"(\d+)", version)
    return match.group(1) if match else version


def process(
    content: bytes, branch: str = ALPINE_BRANCH, arches=ARCHES
) -> tuple[bytes | None, list[str], list[str]]:
    """返回 (新内容或 None, 变更说明, 需要人工处理的问题)。"""
    lines = content.decode("utf-8").split("\n")
    pins = find_pins(lines)
    if not pins:
        return None, [], []

    versions = collect_versions({name for _, name, _ in pins}, branch, tuple(arches))

    edits: list[tuple[int, str, str, str | None]] = []
    changes: list[str] = []
    problems: list[str] = []
    stale = 0

    for lineno, name, pinned in pins:
        per_arch = {arch: versions.get(name, {}).get(arch) for arch in arches}

        if all(per_arch.get(arch) == pinned for arch in arches):
            continue  # pin 当前有效

        found = [v for v in per_arch.values() if v]
        if not found:
            problems.append(f"{name}: 源里已经没有这个包，pin 保持原样，需要人工处理")
            continue

        stale += 1
        candidates = sorted(set(found))

        if len(candidates) == 1:
            target = candidates[0]
            if major(target) != major(pinned):
                problems.append(
                    f"{name}: {pinned} 已撤下，当前是 {target}"
                    "（主版本变化，可能还要改配置），pin 保持原样等人工确认"
                )
                continue
            edits.append((lineno, name, pinned, target))
            changes.append(f"{name}: {pinned} -> {target}")
        else:
            # 两个架构版本不一致，没法用同一个 pin，交给 apk 自己按架构解析
            edits.append((lineno, name, pinned, None))
            changes.append(f"{name}: 各架构当前版本不一致 {per_arch}，去掉 pin")

    if stale > MAX_STALE:
        raise TooManyStale(
            f"失效的 pin 有 {stale} 个（阈值 {MAX_STALE}），"
            f"基础镜像可能换了 Alpine 分支，请确认 --branch 是否为 {branch}"
        )

    if not edits:
        return None, changes, problems

    updated = list(lines)
    for lineno, name, pinned, target in edits:
        token = f"{name}={pinned}"
        updated[lineno] = updated[lineno].replace(
            token, f"{name}={target}" if target else name, 1
        )

    return "\n".join(updated).encode("utf-8"), changes, problems


# --------------------------------------------------------------------------- #
# 入口
# --------------------------------------------------------------------------- #
def main() -> int:
    parser = argparse.ArgumentParser(description="校正 Dockerfile 里失效的 apk 版本 pin")
    parser.add_argument("--dockerfile", default=str(DEFAULT_DOCKERFILE), help="要检查的 Dockerfile")
    parser.add_argument("--branch", default=ALPINE_BRANCH, help="Alpine 分支，默认 %(default)s")
    parser.add_argument(
        "--arch",
        action="append",
        dest="arches",
        help="要一起满足的架构，可重复，默认 x86_64 + aarch64",
    )
    parser.add_argument("--check", action="store_true", help="只检查不写文件")
    args = parser.parse_args()

    path = Path(args.dockerfile)
    if not path.is_file():
        print(f"找不到 {path}", file=sys.stderr)
        return 2

    try:
        updated, changes, problems = process(
            path.read_bytes(), args.branch, args.arches or ARCHES
        )
    except DownloadError as exc:
        print(f"跳过校验：apk 源索引拿不到（{exc}）", file=sys.stderr)
        return 0
    except TooManyStale as exc:
        print(f"拒绝自动修正：{exc}", file=sys.stderr)
        return 3

    for line in changes:
        print(f"  {line}")
    for line in problems:
        print(f"  ! {line}")

    if updated is None:
        if problems:
            print(f"{path.name}: 有 {len(problems)} 处需要人工处理")
            return 2
        print(f"{path.name}: pin 都有效，无需改动")
        return 0

    if args.check:
        print(f"{path.name}: 有 {len(changes)} 处需要修正（--check 模式，未写文件）")
        return 2 if problems else 1

    path.write_bytes(updated)
    print(f"{path.name}: 已修正 {len(changes)} 处 pin")
    return 2 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
