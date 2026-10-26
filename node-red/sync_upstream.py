#!/usr/bin/env python3
"""把本地的 Node-RED app 与上游 hassio-addons/app-node-red 保持同步。

同步策略
--------
1. 托管文件（原样覆盖为上游内容）：
     Dockerfile（末尾自动追加 overlay/Dockerfile.append）
     build.yaml, DOCS.md
     rootfs/etc/nginx/**, rootfs/etc/s6-overlay/**
   package.json 单独处理：与上游合并，同一个依赖取版本号较高的一方，
   这样上游升级能生效，本地 ncu 升级过的依赖也不会被降级。
2. 本地文件（永不被同步覆盖）：
     config.yaml, icon.png, logo.png, .README.j2
     rootfs/etc/node-red/{config.js,settings.js,flows.json}
3. overlay 目录（本地补丁，同步后覆盖回去）：
     overlay/Dockerfile.append     追加到 Dockerfile 末尾的本地构建步骤
     overlay/rootfs/**             被改过的启动脚本，会覆盖上游同名文件
     上游改动了 overlay 里的文件时会打印提示（每个文件只提示一次）
4. 版本联动：config.yaml 的 version 跟随 package.json 里 node-red 的版本；
   上游 node-red 版本没变但文件有变化时，patch 位自增，保证 HA 能感知到更新。

用法
----
    python3 node-red/sync_upstream.py                   # 同步 + 更新版本
    python3 node-red/sync_upstream.py --check           # 只检查，有差异时退出码 1
    python3 node-red/sync_upstream.py --version-only    # 只做版本联动
    python3 node-red/sync_upstream.py --source DIR      # 用本地目录代替 GitHub 下载
    python3 node-red/sync_upstream.py --addon-dir DIR   # 指定 app 目录（测试用）
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

UPSTREAM_REPO = "hassio-addons/app-node-red"
UPSTREAM_REF = "main"
UPSTREAM_SUBDIR = "node-red"

ADDON_DIR = Path(__file__).resolve().parent
OVERLAY_DIR = ADDON_DIR / "overlay"
DOCKERFILE_APPEND = OVERLAY_DIR / "Dockerfile.append"
BASELINE_FILE = OVERLAY_DIR / ".baseline.json"

MANAGED_FILES = ("build.yaml", "DOCS.md")
MANAGED_TREES = ("rootfs/etc/nginx", "rootfs/etc/s6-overlay")
LOCAL_FILES = frozenset(
    {
        "config.yaml",
        "icon.png",
        "logo.png",
        ".README.j2",
        "rootfs/etc/node-red/config.js",
        "rootfs/etc/node-red/settings.js",
        "rootfs/etc/node-red/flows.json",
        "sync_upstream.py",
    }
)


def log(message: str) -> None:
    print(f"[sync] {message}", flush=True)


def set_addon_dir(addon: Path) -> None:
    """切换工作目录（配合 --addon-dir 使用）。"""
    global ADDON_DIR, OVERLAY_DIR, DOCKERFILE_APPEND, BASELINE_FILE
    ADDON_DIR = addon
    OVERLAY_DIR = addon / "overlay"
    DOCKERFILE_APPEND = OVERLAY_DIR / "Dockerfile.append"
    BASELINE_FILE = OVERLAY_DIR / ".baseline.json"


# --------------------------------------------------------------------------- #
# 上游获取
# --------------------------------------------------------------------------- #
def fetch_upstream(destination: Path) -> Path:
    """下载上游仓库 tarball，返回其中的 node-red 目录。"""
    url = f"https://codeload.github.com/{UPSTREAM_REPO}/tar.gz/refs/heads/{UPSTREAM_REF}"
    log(f"下载上游 {UPSTREAM_REPO}@{UPSTREAM_REF} ...")
    request = urllib.request.Request(url, headers={"User-Agent": "sync_upstream.py"})
    with urllib.request.urlopen(request, timeout=180) as response:
        payload = response.read()

    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as archive:
        try:
            archive.extractall(destination, filter="data")
        except TypeError:  # Python < 3.12
            archive.extractall(destination)

    entries = [item for item in destination.iterdir() if item.is_dir()]
    if not entries:
        raise SystemExit("上游压缩包解压失败")
    return entries[0] / UPSTREAM_SUBDIR


def resolve_source(source: str | None, workdir: Path) -> Path:
    """确定上游内容目录（支持本地目录，便于离线测试）。"""
    if source is None:
        return fetch_upstream(workdir)

    root = Path(source).resolve()
    if (root / UPSTREAM_SUBDIR / "package.json").exists():
        return root / UPSTREAM_SUBDIR
    if (root / "package.json").exists():
        return root
    raise SystemExit(f"{root} 看起来不是 app-node-red 的目录")


# --------------------------------------------------------------------------- #
# 基础工具
# --------------------------------------------------------------------------- #
def read_bytes(path: Path) -> bytes | None:
    return path.read_bytes() if path.is_file() else None


def normalize(content: bytes) -> bytes:
    """统一成 LF：Windows 工作区是 CRLF，git 提交时也会归一化成 LF。"""
    return content.replace(b"\r\n", b"\n")


def digest(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def write_if_changed(path: Path, content: bytes, changes: list[str], dry_run: bool) -> None:
    content = normalize(content)
    current = read_bytes(path)
    if current is not None and normalize(current) == content:
        return
    relative = path.relative_to(ADDON_DIR).as_posix()
    if relative not in changes:
        changes.append(relative)
    if not dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)


def overlay_files() -> dict[str, bytes]:
    """overlay 目录里需要覆盖到 app 目录的文件。"""
    files: dict[str, bytes] = {}
    if not OVERLAY_DIR.is_dir():
        return files
    for item in sorted(OVERLAY_DIR.rglob("*")):
        if not item.is_file() or item.name in {"Dockerfile.append", ".baseline.json"}:
            continue
        files[item.relative_to(OVERLAY_DIR).as_posix()] = item.read_bytes()
    return files


def collect_files(root: Path) -> dict[str, bytes]:
    files: dict[str, bytes] = {}
    for item in sorted(root.rglob("*")):
        if item.is_file():
            files[item.relative_to(root).as_posix()] = item.read_bytes()
    return files


# --------------------------------------------------------------------------- #
# 文件同步
# --------------------------------------------------------------------------- #
def sync_tree(
    upstream: Path,
    tree: str,
    protected: set[str],
    changes: list[str],
    dry_run: bool,
) -> None:
    source = upstream / tree
    if not source.is_dir():
        log(f"上游不存在 {tree}，跳过")
        return

    upstream_files = collect_files(source)
    for relative, content in upstream_files.items():
        target_relative = f"{tree}/{relative}"
        if target_relative in protected:
            continue
        write_if_changed(ADDON_DIR / target_relative, content, changes, dry_run)

    # 删除上游已经移除的陈旧文件（保留本地文件与 overlay 文件）
    local = ADDON_DIR / tree
    if not local.is_dir():
        return
    for item in sorted(local.rglob("*")):
        if not item.is_file():
            continue
        relative = item.relative_to(ADDON_DIR).as_posix()
        if relative in protected:
            continue
        if item.relative_to(local).as_posix() not in upstream_files:
            entry = f"{relative} (删除)"
            if entry not in changes:
                changes.append(entry)
            if not dry_run:
                item.unlink()


def version_key(value: object) -> tuple[int, ...] | None:
    """把 "5.0.9" 之类的固定版本号转成可比较的元组；非固定版本返回 None。"""
    if not isinstance(value, str):
        return None
    text = value.strip().lstrip("vV")
    if not re.fullmatch(r"\d+(?:\.\d+)*", text):
        return None
    return tuple(int(part) for part in text.split("."))


def merge_package_json(upstream: Path, addon: Path) -> tuple[bytes, str | None]:
    """上游 package.json 与本地合并，依赖取版本号较高的一方。

    这样上游升级依赖能生效，本地 `ncu` 升级过的依赖也不会被降级回旧版本。
    """
    upstream_file = upstream / "package.json"
    if not upstream_file.is_file():
        log("上游缺少 package.json，跳过")
        return b"", None
    upstream_bytes = upstream_file.read_bytes()

    local_bytes = read_bytes(addon / "package.json")
    if local_bytes is None:
        return normalize(upstream_bytes), node_red_version(upstream_file)

    try:
        upstream_data = json.loads(upstream_bytes.decode("utf-8"))
        local_data = json.loads(normalize(local_bytes).decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        log("package.json 解析失败，直接使用上游版本")
        return normalize(upstream_bytes), node_red_version(upstream_file)

    merged = dict(upstream_data)
    merged_dependencies = dict(upstream_data.get("dependencies") or {})
    for name, local_version in (local_data.get("dependencies") or {}).items():
        if name not in merged_dependencies:
            merged_dependencies[name] = local_version
            continue
        local_key = version_key(local_version)
        upstream_key = version_key(merged_dependencies[name])
        if local_key and upstream_key and local_key > upstream_key:
            log(
                f"依赖 {name} 本地 {local_version} 高于上游 "
                f"{merged_dependencies[name]}，保留本地版本"
            )
            merged_dependencies[name] = local_version
    merged["dependencies"] = merged_dependencies

    for key, value in local_data.items():
        merged.setdefault(key, value)

    content = (json.dumps(merged, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    wanted = (merged_dependencies or {}).get("node-red")
    return content, wanted


def sync_dockerfile(upstream: Path, changes: list[str], dry_run: bool) -> None:
    """上游 Dockerfile + 本地追加片段，一次性写入，保证幂等。"""
    source = upstream / "Dockerfile"
    if not source.is_file():
        log("上游缺少 Dockerfile，跳过")
        return

    content = source.read_bytes().rstrip(b"\n") + b"\n\n"
    if DOCKERFILE_APPEND.is_file():
        appendix = DOCKERFILE_APPEND.read_bytes()
        if not appendix.endswith(b"\n"):
            appendix += b"\n"
        content += appendix

    write_if_changed(ADDON_DIR / "Dockerfile", content, changes, dry_run)


def apply_overlay(changes: list[str], dry_run: bool) -> None:
    for relative, content in overlay_files().items():
        write_if_changed(ADDON_DIR / relative, content, changes, dry_run)


def load_baseline() -> dict[str, str]:
    content = read_bytes(BASELINE_FILE)
    if content is None:
        return {}
    try:
        return json.loads(content.decode("utf-8")).get("files", {})
    except (json.JSONDecodeError, UnicodeDecodeError):
        return {}


def check_overlay_baseline(
    upstream: Path, changes: list[str], dry_run: bool
) -> None:
    """上游改动了被 overlay 覆盖的文件时提示一次（记忆上游内容指纹）。"""
    baseline = load_baseline()
    updated = dict(baseline)
    warned = False

    for relative in sorted(overlay_files()):
        upstream_file = upstream / relative
        if not upstream_file.is_file():
            continue
        current = digest(upstream_file.read_bytes())
        previous = baseline.get(relative)
        if previous is not None and previous != current:
            log(
                f"注意：上游改动了 {relative}，本地 overlay 仍是旧实现，"
                f"建议对比 {UPSTREAM_REPO}/{UPSTREAM_SUBDIR}/{relative}"
            )
            warned = True
        updated[relative] = current

    if updated != baseline:
        if warned:
            changes.append("overlay/.baseline.json")
        if not dry_run:
            BASELINE_FILE.parent.mkdir(parents=True, exist_ok=True)
            BASELINE_FILE.write_text(
                json.dumps({"files": updated}, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            if not warned:
                log(f"已记录 overlay 基线（{len(updated)} 个文件）")


# --------------------------------------------------------------------------- #
# 版本联动
# --------------------------------------------------------------------------- #
def node_red_version(package_json: Path) -> str | None:
    try:
        data = json.loads(package_json.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    return (data.get("dependencies") or {}).get("node-red")


def config_version(config: Path) -> str | None:
    match = re.search(r"(?m)^version:\s*(\S+)\s*$", config.read_text(encoding="utf-8"))
    return match.group(1) if match else None


def as_numbers(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in re.findall(r"\d+", version)[:3])


def bump_patch(version: str) -> str:
    numbers = as_numbers(version)
    if not numbers:
        return version
    parts = list(numbers) + [0] * (3 - len(numbers))
    parts[-1] += 1
    return ".".join(str(part) for part in parts)


def sync_version(
    addon: Path,
    changes: list[str],
    content_changed: bool,
    dry_run: bool,
    wanted: str | None = None,
) -> None:
    config = addon / "config.yaml"
    wanted = wanted or node_red_version(addon / "package.json")
    current = config_version(config)

    if not wanted or not current:
        log("读不到 node-red 版本或 config.yaml 版本，跳过版本联动")
        return

    if as_numbers(wanted) > as_numbers(current):
        target = wanted
        reason = "跟随 package.json 的 node-red 版本"
    elif content_changed:
        target = bump_patch(current)
        reason = f"node-red 仍是 {wanted}，patch 位自增以保证可更新"
    else:
        log(f"版本无需变更（node-red {wanted} / app {current}）")
        return

    log(f"版本：{current} -> {target}（{reason}）")
    text = config.read_text(encoding="utf-8")
    updated = re.sub(r"(?m)^version:\s*\S+\s*$", f"version: {target}", text, count=1)
    if updated != text:
        entry = f"config.yaml (version -> {target})"
        if entry not in changes:
            changes.append(entry)
        if not dry_run:
            config.write_text(updated, encoding="utf-8", newline="")


# --------------------------------------------------------------------------- #
# 提示信息
# --------------------------------------------------------------------------- #
def report_config_drift(upstream: Path) -> None:
    """config.yaml 不由脚本覆盖，这里只提示上游新增/保留了哪些选项。"""
    upstream_config = upstream / "config.yaml"
    local_config = ADDON_DIR / "config.yaml"
    if not upstream_config.is_file() or not local_config.is_file():
        return

    def keys(path: Path) -> dict[str, set[str]]:
        result: dict[str, set[str]] = {"options": set(), "schema": set()}
        section = None
        for line in path.read_text(encoding="utf-8").splitlines():
            match = re.match(r"^(options|schema):\s*$", line)
            if match:
                section = match.group(1)
                continue
            if line and not line.startswith((" ", "\t", "-")):
                section = None
                continue
            if section and re.match(r"^  [A-Za-z0-9_]+:", line):
                result[section].add(line.split(":")[0].strip())
        return result

    upstream_keys = keys(upstream_config)
    local_keys = keys(local_config)
    for section in ("options", "schema"):
        missing = sorted(upstream_keys[section] - local_keys[section])
        if missing:
            log(f"提示：上游 config.yaml 的 {section} 新增了 {missing}，需要时手动合并")
        extra = sorted(local_keys[section] - upstream_keys[section])
        if extra:
            log(f"提示：本地 config.yaml 的 {section} 保留了本地项 {extra}（不同步）")


# --------------------------------------------------------------------------- #
# 入口
# --------------------------------------------------------------------------- #
def finish(changes: list[str], dry_run: bool) -> int:
    if not changes:
        log("已与上游一致，无变更")
        return 0

    log(f"{'将变更' if dry_run else '已变更'} {len(changes)} 个文件：")
    for change in changes:
        print(f"       - {change}")
    return 1 if dry_run else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="同步上游 hassio-addons/app-node-red")
    parser.add_argument("--check", action="store_true", help="只检查，不写文件")
    parser.add_argument("--version-only", action="store_true", help="只做版本联动")
    parser.add_argument("--source", help="使用本地目录作为上游内容")
    parser.add_argument("--addon-dir", help="app 目录，默认是本脚本所在目录")
    args = parser.parse_args()

    addon = Path(args.addon_dir).resolve() if args.addon_dir else ADDON_DIR
    set_addon_dir(addon)
    changes: list[str] = []
    dry_run = args.check

    if args.version_only:
        sync_version(addon, changes, content_changed=True, dry_run=dry_run)
        return finish(changes, dry_run)

    with tempfile.TemporaryDirectory() as tmp:
        upstream = resolve_source(args.source, Path(tmp))
        protected = set(overlay_files()) | LOCAL_FILES

        for name in MANAGED_FILES:
            source = upstream / name
            if not source.is_file():
                log(f"上游缺少 {name}，跳过")
                continue
            write_if_changed(addon / name, source.read_bytes(), changes, dry_run)

        package_content, package_node_red = merge_package_json(upstream, addon)
        if package_content:
            write_if_changed(
                addon / "package.json", package_content, changes, dry_run
            )

        for tree in MANAGED_TREES:
            sync_tree(upstream, tree, protected, changes, dry_run)
        sync_dockerfile(upstream, changes, dry_run)
        apply_overlay(changes, dry_run)
        check_overlay_baseline(upstream, changes, dry_run)
        report_config_drift(upstream)
        sync_version(
            addon,
            changes,
            content_changed=bool(changes),
            dry_run=dry_run,
            wanted=package_node_red or node_red_version(upstream / "package.json"),
        )

    return finish(changes, dry_run)


if __name__ == "__main__":
    sys.exit(main())
