#!/usr/bin/env python3
"""一键重建示例文档的 PDF 与预览图。

渲染算法一变（字距、居中、标点挤压……），仓库里所有示例的 PDF 与预览图
就全部过期。本脚本把「哪个 tex 产出哪个 PDF、哪个 PDF 的第几页导出成哪张
PNG」写成清单（下方 DOCS），跑一次全部重建，结果可复现。

用法：

    python3 scripts/build/build_examples.py            # 重建 示例/ 全部
    python3 scripts/build/build_examples.py --check    # 只报告差异，不写文件
    python3 scripts/build/build_examples.py --only 红楼梦
    python3 scripts/build/build_examples.py --all      # 含 全书复刻/（慢）
    python3 scripts/build/build_examples.py --list

字体：与回归测试同样经 OSFONTDIR 指向 test/fonts/，不需要安装系统字体。
缺字体时先跑 `python3 scripts/download_fonts.py --all` 或
`sh scripts/download_test_fonts.sh`。

外部依赖：lualatex、pdftoppm、pdfinfo（poppler）。
"""

import argparse
import concurrent.futures
import hashlib
import multiprocessing
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[2]
FONTS_DIR = BASE_DIR / "test" / "fonts"

# 与 test/regression_test.py 同样的做法：测试字体经 OSFONTDIR 提供，
# 不进系统字体库。示例用到的 TW-Kai / 京華老宋体 / Jigmo / 思源宋体
# 都在 scripts/font-manifest.json 里。
_prev_osfontdir = os.environ.get("OSFONTDIR")
os.environ["OSFONTDIR"] = (
    f"{FONTS_DIR}{os.pathsep}{_prev_osfontdir}" if _prev_osfontdir else str(FONTS_DIR)
)

# 预览图统一分辨率。历史上这批图是手工做的，dpi 从 68 到 251 都有，
# 这里统一到 150（README 里显示够清晰，单页 PNG 约 1MB 以内）。
DEFAULT_DPI = 150


@dataclass
class Png:
    """一张由 PDF 某页导出的预览图。"""

    path: str  # 相对仓库根
    page: int  # 1-based
    dpi: int = DEFAULT_DPI


@dataclass
class Doc:
    """一个示例文档：一个 tex → 一个或多个 PDF 落点 → 若干预览图。"""

    tex: str
    pdfs: list  # 相对仓库根；多个落点时内容相同，只是复制多份
    images: list = field(default_factory=list)
    group: str = "示例"

    @property
    def name(self):
        return Path(self.tex).stem


# ---------------------------------------------------------------------------
# 清单
#
# 注：以下图片是素材或参考图，不是渲染产物，脚本永不触碰——
#   示例/*/文渊阁宝印.png            \印章 的输入素材
#   示例/*/ref-*.png                  底本扫描与参考书影（工尺谱、红楼梦、
#                                     欧式族谱、史记卷十六）
#   示例/史记五帝本纪/page_*.jpg      底本扫描（archive.org）
#   示例/四库全书简明目录/page_*.jpg  底本扫描
#   示例/史记五帝本纪/colored_example.jpg  故宫藏本书影
# ---------------------------------------------------------------------------
DOCS = [
    Doc(
        tex="示例/四库全书简明目录/目录.tex",
        pdfs=["示例/四库全书简明目录/目录.pdf"],
        # 首页展示用的是第 2 页（第 1 页是卷端）
        images=[Png("示例/首页展示/mulu-color.png", page=2)],
    ),
    Doc(
        tex="示例/史记五帝本纪/史记.tex",
        pdfs=["示例/史记五帝本纪/史记.pdf"],
    ),
    Doc(
        tex="示例/史记五帝本纪/史记-黑白.tex",
        pdfs=["示例/史记五帝本纪/史记-黑白.pdf"],
        images=[Png("示例/首页展示/shiji-bw.png", page=1)],
    ),
    Doc(
        tex="示例/红楼梦甲戌本/石头记.tex",
        pdfs=["示例/红楼梦甲戌本/石头记.pdf"],
        images=[
            Png("示例/红楼梦甲戌本/page1.png", page=1),
            Png("示例/红楼梦甲戌本/page2.png", page=2),
            Png("示例/首页展示/honglou-p1.png", page=1),
            Png("示例/首页展示/honglou-p2.png", page=2),
        ],
    ),
    Doc(
        tex="示例/史记卷十六·现代/卷十六.tex",
        pdfs=["示例/史记卷十六·现代/卷十六.pdf"],
        images=[
            Png("示例/史记卷十六·现代/page-1.png", page=1),
            Png("示例/史记卷十六·现代/page-2.png", page=2),
            Png("示例/史记卷十六·现代/page-3.png", page=3),
            Png("示例/首页展示/juan16-p1.png", page=1),
            Png("示例/首页展示/juan16-p2.png", page=2),
        ],
    ),
    Doc(
        tex="示例/工尺谱/圣世呈符.tex",
        pdfs=["示例/工尺谱/圣世呈符.pdf"],
        images=[Png("示例/工尺谱/圣世呈符-预览.png", page=1)],
    ),
    Doc(
        tex="示例/工尺谱/西厢记佳期.tex",
        pdfs=["示例/工尺谱/西厢记佳期.pdf"],
        images=[Png("示例/工尺谱/西厢记佳期-预览.png", page=1)],
    ),
    Doc(
        tex="示例/欧式族谱/族谱.tex",
        pdfs=["示例/欧式族谱/族谱.pdf"],
        # 现在是单页横排族谱；旧的 p2–p4.png 是更早的多页版本遗留，见 STALE
        images=[Png("示例/欧式族谱/p1.png", page=1)],
    ),
    Doc(
        tex="示例/线装书封面/封面.tex",
        pdfs=["示例/线装书封面/封面.pdf"],
        images=[
            Png("示例/线装书封面/page-1.png", page=1),
            Png("示例/线装书封面/page-2.png", page=2),
            Png("示例/线装书封面/page-3.png", page=3),
            Png("示例/线装书封面/page-4.png", page=4),
        ],
    ),
    Doc(
        tex="示例/论辩的魂灵/论辩的魂灵.tex",
        pdfs=["示例/论辩的魂灵/论辩的魂灵.pdf"],
    ),
    Doc(
        tex="示例/首页展示/example.tex",
        pdfs=["示例/首页展示/example.pdf"],
        images=[Png("示例/首页展示/example.png", page=1)],
    ),
    # ---- 全书复刻（页数多、编译慢，默认不建，用 --all 或 --group 全书复刻）
    Doc(
        group="全书复刻",
        tex="全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一.tex",
        pdfs=["全书复刻/欽定四庫全書簡明目錄/欽定四庫全書簡明目錄冊一.pdf"],
    ),
    Doc(
        group="全书复刻",
        tex="全书复刻/欽定四庫全書簡明目錄/ditigal_tex/column1_digital.tex",
        pdfs=["全书复刻/欽定四庫全書簡明目錄/ditigal_tex/column1_digital.pdf"],
    ),
    Doc(
        group="全书复刻",
        tex="全书复刻/紅樓夢/甲戌本/tex/凡例.tex",
        pdfs=["全书复刻/紅樓夢/甲戌本/凡例.pdf"],
    ),
    Doc(
        group="全书复刻",
        tex="全书复刻/紅樓夢/甲戌本/tex/第一回.tex",
        pdfs=[
            "全书复刻/紅樓夢/甲戌本/第一回.pdf",
            "全书复刻/紅樓夢/甲戌本/tex/第一回.pdf",
        ],
    ),
]

# 清单未覆盖、且已确认是历史遗留的产物；--prune 时删除。
# （曾列在此处的 欧式族谱 p2–p4、史记卷十六 page-004/005 其实是底本扫描，
#   并非产物，已改名为 ref-* 归入上面的保护范围。）
STALE = []

# 清单未覆盖但**不是**本脚本产物的图片（素材、底本扫描、参考书影），
# 报告「未纳入清单」时跳过它们。
PROTECTED_SUFFIXES = ("文渊阁宝印.png", "colored_example.jpg")
PROTECTED_PATTERNS = ("ref-", "page_")

# 有 PDF 但没有对应 tex 的产物，只提示、不处理（构建方式待确认）。
UNMAPPED_NOTE = [
    "全书复刻/欽定四庫全書簡明目錄/欽定四庫全書簡明目錄冊一（标点).pdf",
]


def run(cmd, cwd=None):
    """跑一条命令，返回 CompletedProcess（不抛异常）。"""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def check_tools():
    missing = [t for t in ("lualatex", "pdftoppm", "pdfinfo") if not shutil.which(t)]
    if missing:
        sys.exit(f"缺少外部命令：{', '.join(missing)}（pdftoppm/pdfinfo 来自 poppler）")
    if not list(FONTS_DIR.glob("*.ttf")) and not list(FONTS_DIR.glob("*.otf")):
        print(
            f"警告：{FONTS_DIR} 中没有字体，编译可能失败。\n"
            "      先跑 python3 scripts/download_fonts.py --all",
            file=sys.stderr,
        )


def pdf_pages(pdf):
    """PDF 页数；读不到返回 0。"""
    out = run(["pdfinfo", str(pdf)]).stdout
    for line in out.splitlines():
        if line.startswith("Pages:"):
            return int(line.split()[-1])
    return 0


def render(pdf, page, dpi, dest):
    """把 pdf 的第 page 页渲染成 dest（PNG）。"""
    with tempfile.TemporaryDirectory() as tmp:
        prefix = Path(tmp) / "page"
        res = run(
            ["pdftoppm", "-png", "-r", str(dpi), "-f", str(page), "-l", str(page),
             str(pdf), str(prefix)]
        )
        produced = sorted(Path(tmp).glob("page-*.png"))
        if res.returncode != 0 or not produced:
            raise RuntimeError(f"pdftoppm 失败：{pdf} 第 {page} 页\n{res.stderr}")
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(produced[0], dest)


def page_fingerprint(pdf, dpi=72):
    """PDF 逐页渲染后的哈希列表——用于「内容是否变了」的判定。

    直接比较 PDF 字节没有意义（每次编译的时间戳都不同）。
    """
    if not Path(pdf).exists():
        return None
    with tempfile.TemporaryDirectory() as tmp:
        prefix = Path(tmp) / "p"
        res = run(["pdftoppm", "-png", "-r", str(dpi), str(pdf), str(prefix)])
        if res.returncode != 0:
            return None
        return [
            hashlib.md5(p.read_bytes()).hexdigest()
            for p in sorted(Path(tmp).glob("p-*.png"))
        ]


def describe_diff(old, new):
    """比较两组页面指纹，给出一句人话。"""
    if old is None:
        return "新建"
    if old == new:
        return "无变化"
    if len(old) != len(new):
        return f"页数 {len(old)} → {len(new)}，内容有变"
    changed = sum(1 for a, b in zip(old, new) if a != b)
    return f"{changed}/{len(new)} 页有变化"


def compile_doc(doc, passes, workdir):
    """编译一个 doc，返回 (built_pdf, error)。built_pdf 在 workdir 里。"""
    tex = BASE_DIR / doc.tex
    out = Path(workdir) / doc.name
    out.mkdir(parents=True, exist_ok=True)
    for _ in range(passes):
        res = run(
            ["lualatex", "-interaction=nonstopmode", "-halt-on-error",
             f"-output-directory={out}", tex.name],
            cwd=tex.parent,
        )
        if res.returncode != 0:
            tail = "\n".join((res.stdout or "").splitlines()[-25:])
            return None, f"lualatex 失败：{doc.tex}\n{tail}"
    built = out / f"{tex.stem}.pdf"
    if not built.exists():
        return None, f"没有产出 PDF：{doc.tex}"
    return built, None


def process(doc, args, workdir):
    """编译 + 比较 + （非 --check 时）落盘。返回结果字典。"""
    result = {"doc": doc, "error": None, "pdf_diff": "", "images": []}

    built, err = compile_doc(doc, args.passes, workdir)
    if err:
        result["error"] = err
        return result

    fresh = page_fingerprint(built)
    diff = describe_diff(page_fingerprint(BASE_DIR / doc.pdfs[0]), fresh)
    result["pdf_diff"] = diff
    result["pages"] = pdf_pages(built)

    # 内容一样就不落盘：PDF 每次编译的 CreationDate 与 /ID 都不同，
    # 覆盖会让 git 冒出一堆「其实没变」的二进制改动。逐个落点判定，
    # 因为同一个 tex 可能有多个 PDF 落点、各自的新旧程度不同。
    if not args.check:
        kept = 0
        for dest in doc.pdfs:
            dest_path = BASE_DIR / dest
            if dest_path.exists() and page_fingerprint(dest_path) == fresh:
                kept += 1
                continue
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(built, dest_path)
        if kept:
            result["pdf_diff"] += f"，{kept} 处保留原文件"

    if args.skip_images:
        return result

    n_pages = result["pages"]
    for img in doc.images:
        if img.page > n_pages:
            result["images"].append((img.path, f"跳过：PDF 只有 {n_pages} 页"))
            continue
        dpi = args.dpi or img.dpi
        dest = BASE_DIR / img.path
        if args.check:
            with tempfile.TemporaryDirectory() as tmp:
                probe = Path(tmp) / "probe.png"
                render(built, img.page, dpi, probe)
                if not dest.exists():
                    state = "新建"
                elif probe.read_bytes() == dest.read_bytes():
                    state = "无变化"
                else:
                    state = "有变化"
            result["images"].append((img.path, state))
        else:
            render(built, img.page, dpi, dest)
            result["images"].append((img.path, f"已生成 p{img.page} @{dpi}dpi"))
    return result


def report_unmanaged():
    """列出示例目录里不在清单、也不是素材/扫描件的图片。

    始终按完整清单判定——否则 --only 会把没被选中的产物误报为孤儿。
    """
    managed = {img.path for d in DOCS for img in d.images}
    stray = []
    for pattern in ("示例/*/*.png", "示例/*/*.jpg"):
        for p in sorted(BASE_DIR.glob(pattern)):
            rel = p.relative_to(BASE_DIR).as_posix()
            if rel in managed or rel in STALE:
                continue
            name = p.name
            if name.endswith(PROTECTED_SUFFIXES) or name.startswith(PROTECTED_PATTERNS):
                continue
            stray.append(rel)
    return stray


def main():
    ap = argparse.ArgumentParser(description="重建示例的 PDF 与预览图")
    ap.add_argument("--only", help="按子串筛选（匹配 tex 路径）")
    ap.add_argument("--group", choices=["示例", "全书复刻"], help="只建某一组")
    ap.add_argument("--all", action="store_true", help="含 全书复刻/（慢）")
    ap.add_argument("--check", action="store_true", help="只报告差异，不写任何文件")
    ap.add_argument("--list", action="store_true", help="列出清单后退出")
    ap.add_argument("--skip-images", action="store_true", help="只重建 PDF")
    ap.add_argument("--dpi", type=int, help="覆盖所有预览图的 dpi")
    ap.add_argument("--passes", type=int, default=2, help="lualatex 遍数（默认 2）")
    ap.add_argument("--jobs", type=int, default=max(1, multiprocessing.cpu_count() // 2))
    ap.add_argument("--prune", action="store_true", help="删除 STALE 里的历史遗留图")
    ap.add_argument("--keep-temp", action="store_true", help="保留编译临时目录")
    args = ap.parse_args()

    docs = DOCS
    if args.group:
        docs = [d for d in docs if d.group == args.group]
    elif not args.all:
        docs = [d for d in docs if d.group == "示例"]
    if args.only:
        docs = [d for d in docs if args.only in d.tex]
    if not docs:
        sys.exit("清单里没有匹配的文档")

    if args.list:
        for d in docs:
            imgs = "、".join(f"{Path(i.path).name}(p{i.page})" for i in d.images) or "—"
            print(f"[{d.group}] {d.tex}\n    → {d.pdfs[0]}\n    → {imgs}")
        return

    check_tools()
    mode = "检查" if args.check else "重建"
    print(f"{mode} {len(docs)} 个文档（{args.passes} 遍编译，{args.jobs} 并发）\n")

    workdir = Path(tempfile.mkdtemp(prefix="ltc-examples-"))
    results = []
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = {pool.submit(process, d, args, workdir): d for d in docs}
            for fut in concurrent.futures.as_completed(futures):
                res = fut.result()
                results.append(res)
                doc = res["doc"]
                if res["error"]:
                    print(f"✗ {doc.name}\n{res['error']}\n")
                else:
                    print(f"✓ {doc.name}  PDF: {res['pdf_diff']}（{res['pages']} 页）")
                    for path, state in res["images"]:
                        print(f"    {path}  {state}")
    finally:
        if args.keep_temp:
            print(f"\n编译临时目录：{workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)

    if args.prune and not args.check:
        for rel in STALE:
            p = BASE_DIR / rel
            if p.exists():
                p.unlink()
                print(f"已删除历史遗留：{rel}")
    elif not args.check:
        left = [rel for rel in STALE if (BASE_DIR / rel).exists()]
        if left:
            print("\n历史遗留（清单未覆盖，--prune 可删）：")
            for rel in left:
                print(f"    {rel}")

    stray = report_unmanaged()
    if stray:
        print("\n未纳入清单的图片（既非产物也非已知素材，请确认）：")
        for rel in stray:
            print(f"    {rel}")
    for rel in UNMAPPED_NOTE:
        if (BASE_DIR / rel).exists():
            print(f"\n提示：{rel} 没有对应的 tex 条目，本脚本不管它。")

    failed = [r for r in results if r["error"]]
    print(f"\n完成：{len(results) - len(failed)} 成功，{len(failed)} 失败")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
