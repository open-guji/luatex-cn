#!/usr/bin/env python3
"""按 scripts/font-manifest.json 下载项目字体到仓库内目录（不装系统字体）。

用法:
    python3 scripts/download_fonts.py            # 下载 required 字体（测试必需）
    python3 scripts/download_fonts.py --all      # 连同 optional（Ext-B/Plus/朱雀等）
    python3 scripts/download_fonts.py --verify   # 只校验已下载文件的 SHA-256
    python3 scripts/download_fonts.py --user     # 安装到 TEXMFHOME（供日常排版使用）
    python3 scripts/download_fonts.py --dest DIR # 下载到指定目录（如文档项目的 ./fonts/）

字体默认放入 manifest 的 font_dir（test/fonts/，gitignored），供测试经 OSFONTDIR
使用。日常排版用 --user 装入 TEXMFHOME/fonts/truetype/luatex-cn/（免管理员权限、
不进系统字体库，luaotfload 可按文件名找到），或用 --dest 放进文档目录后以
\\设置字体族{Jigmo} / \\setmainfont{Jigmo.ttf} 引用。

普通条目下载后校验 SHA-256，与 manifest 不符即报错退出。带 npm 源的条目
（woff2 切片）会下载 tarball（校验其 sha256）后用 fonttools 合并为单个 TTF，
合并输出不校验哈希（fonttools 版本可能影响字节），需要 pip install fonttools brotli。
"""
import argparse
import hashlib
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = Path(__file__).resolve().parent / "font-manifest.json"


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


#: 可重试的 HTTP 状态：限流与服务端临时故障
RETRY_STATUS = {408, 425, 429, 500, 502, 503, 504}
#: 每次重试前的等待秒数（服务端给了 Retry-After 时以它为准）
RETRY_BACKOFF = (2, 6, 15, 40)


def _urlopen_with_retry(url):
    """打开 url；遇到限流/临时故障按 RETRY_BACKOFF 退避重试。

    CI 上并发跑多个作业时 raw.githubusercontent 很容易回 429，
    单次失败就让整个字体下载步骤失败太脆。
    """
    last = None
    for attempt, wait in enumerate((*RETRY_BACKOFF, None)):
        try:
            return urllib.request.urlopen(url, timeout=120)
        except urllib.error.HTTPError as e:
            last = e
            if e.code not in RETRY_STATUS or wait is None:
                raise
            retry_after = e.headers.get("Retry-After") if e.headers else None
            if retry_after and retry_after.isdigit():
                wait = max(wait, int(retry_after))
        except urllib.error.URLError as e:
            last = e
            if wait is None:
                raise
        print(f"  {last}，{wait}s 后重试（第 {attempt + 2} 次）...", file=sys.stderr)
        time.sleep(wait)
    raise last  # 不可达：最后一轮 wait 为 None 时已 raise


def download(url, dest):
    """下载 url 到 dest；URL 以 .gz 结尾时边下边解压（sha256 校验解压后内容）。"""
    tmp = dest.with_suffix(dest.suffix + ".part")
    print(f"下载: {url}")
    with _urlopen_with_retry(url) as resp, open(tmp, "wb") as out:
        if url.endswith(".gz"):
            import gzip
            with gzip.open(resp, "rb") as gz:
                while True:
                    chunk = gz.read(1 << 20)
                    if not chunk:
                        break
                    out.write(chunk)
        else:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
    tmp.rename(dest)


def extract_from_archive(archive, member, dest, font_dir):
    """从 zip 压缩包中解出字体文件。压缩包按 sha256 缓存复用。"""
    import zipfile

    cached = fetch_archive(archive["url"], archive["sha256"],
                           font_dir / ".archives", ".zip")
    with zipfile.ZipFile(cached) as zf:
        with zf.open(archive.get("member", member)) as src, open(dest, "wb") as out:
            while True:
                chunk = src.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)


def fetch_archive(url, sha256, cache_dir, suffix):
    """下载压缩包到缓存目录（按 sha256 命名复用），校验后返回路径。"""
    cache_dir.mkdir(parents=True, exist_ok=True)
    cached = cache_dir / (sha256[:16] + suffix)
    if not (cached.exists() and sha256_of(cached) == sha256):
        download(url, cached)
        actual = sha256_of(cached)
        if actual != sha256:
            cached.unlink()
            raise RuntimeError(f"压缩包 sha256 不符: 期望 {sha256} 实际 {actual}")
    return cached


def build_from_npm_woff2(npm, dest, font_dir):
    """npm woff2 切片一条龙：下载 tarball → 解出切片 → 合并为单个 TTF。

    切片是按 Unicode 区段拆分的同一字体的子集（webfont 分发形态），字形集互不
    重叠，可用 fontTools.merge 无损合回；实测 GSUB 的 vert/vrt2 竖排特性保留。
    """
    import fnmatch
    import os
    import tarfile
    import tempfile

    try:
        from fontTools.ttLib import TTFont
        from fontTools.merge import Merger
    except ImportError:
        raise RuntimeError(
            "npm woff2 字体需要 fonttools 与 brotli，请先: pip install fonttools brotli")

    tarball = fetch_archive(npm["tarball"], npm["sha256"],
                            font_dir / ".archives", ".tgz")
    # SOURCE_DATE_EPOCH 固定 head 表时间戳，使同版本 fonttools 的输出可复现
    os.environ.setdefault("SOURCE_DATE_EPOCH", "0")
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        slices = []
        with tarfile.open(tarball, "r:gz") as tf:
            for member in tf.getmembers():
                if fnmatch.fnmatch(member.name, npm["member_glob"]):
                    tf.extract(member, tmp, filter="data")
                    slices.append(tmp / member.name)
        if not slices:
            raise RuntimeError(f"tarball 中未找到 {npm['member_glob']}")
        print(f"合并 {len(slices)} 片 woff2 → {dest.name} ...")
        ttfs = []
        for i, w in enumerate(sorted(slices)):
            f = TTFont(w)
            f.flavor = None  # woff2 → 普通 sfnt
            out = tmp / f"slice{i:04d}.ttf"
            f.save(out)
            ttfs.append(str(out))
        merged = Merger().merge(ttfs)
        merged.save(dest)


def resolve_texmfhome():
    out = subprocess.run(["kpsewhich", "-var-value", "TEXMFHOME"],
                         capture_output=True, text=True, check=True)
    home = out.stdout.strip()
    if not home:
        raise RuntimeError("kpsewhich 未返回 TEXMFHOME")
    return Path(home).expanduser()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--all", action="store_true", help="包含 optional 字体")
    ap.add_argument("--verify", action="store_true", help="只校验，不下载")
    dest_group = ap.add_mutually_exclusive_group()
    dest_group.add_argument("--dest", metavar="DIR",
                            help="下载到指定目录（如文档项目的 ./fonts/）")
    dest_group.add_argument("--user", action="store_true",
                            help="安装到 TEXMFHOME/fonts/truetype/luatex-cn/（日常排版用）")
    args = ap.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.user:
        font_dir = resolve_texmfhome() / "fonts" / "truetype" / "luatex-cn"
    elif args.dest:
        font_dir = Path(args.dest).expanduser().resolve()
    else:
        font_dir = REPO_ROOT / manifest["font_dir"]
    font_dir.mkdir(parents=True, exist_ok=True)

    failures = []
    for font in manifest["fonts"]:
        optional = font.get("required_for") == ["optional"]
        if optional and not (args.all or args.verify):
            continue
        dest = font_dir / font["file"]
        expected_sha = font.get("sha256")  # npm 合并输出无固定哈希，条目可不含此字段

        if dest.exists():
            if expected_sha is None:
                print(f"已就绪: {font['file']} (npm 合并输出，不校验哈希)")
                continue
            actual = sha256_of(dest)
            if actual == expected_sha:
                print(f"已就绪: {font['file']} (sha256 OK)")
                continue
            if args.verify:
                failures.append(f"{font['file']}: sha256 不符 {actual}")
                continue
            print(f"哈希不符，重新下载: {font['file']}")
            dest.unlink()
        elif args.verify:
            if not optional:
                failures.append(f"{font['file']}: 缺失")
            continue

        npm = font.get("npm")
        archive = font.get("archive")
        if npm:
            # npm woff2 切片：下载 tarball（校验 sha256）→ fonttools 合并为 TTF
            try:
                build_from_npm_woff2(npm, dest, font_dir)
            except Exception as e:  # noqa: BLE001
                failures.append(f"{font['file']}: npm 构建失败 ({e})")
                continue
        elif archive:
            # zip 分发的字体：下载（或复用）压缩包，校验后解出成员文件。
            # 压缩包按其 sha256 缓存在 font_dir/.archives/，同包多字体只下一次。
            try:
                extract_from_archive(archive, font["file"], dest, font_dir)
            except Exception as e:  # noqa: BLE001
                failures.append(f"{font['file']}: 压缩包获取失败 ({e})")
                continue
        else:
            for url in font["urls"]:
                try:
                    download(url, dest)
                    break
                except Exception as e:  # noqa: BLE001 - 尝试下一个镜像
                    print(f"  失败 ({e})，尝试下一个源...", file=sys.stderr)
            else:
                failures.append(f"{font['file']}: 所有下载源均失败")
                continue

        actual = sha256_of(dest)
        if expected_sha is None:
            print(f"完成: {font['file']} (sha256 {actual[:16]}…，npm 合并输出不校验)")
        elif actual != expected_sha:
            dest.unlink()
            failures.append(
                f"{font['file']}: 下载内容 sha256 不符\n"
                f"  期望 {expected_sha}\n  实际 {actual}"
            )
        else:
            print(f"完成: {font['file']} (sha256 OK)")

    if failures:
        print("\nERROR:", file=sys.stderr)
        for f in failures:
            print("  " + f, file=sys.stderr)
        sys.exit(1)
    print(f"\n字体位于 {font_dir}")
    if args.user:
        print("已安装到 TEXMFHOME，\\设置字体族 / \\setmainfont{文件名.ttf} 可直接使用；"
              "如需按字体名引用，请再执行: luaotfload-tool --update")


if __name__ == "__main__":
    main()
