#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
四库全书简明目录 插件

处理模板特有命令：
- \\注{content}  → indent=2 的夹注
- \\按{content}  → indent=4 的夹注（含抬头命令）
- \\國朝         → \\相对抬头[1]{國朝}，展开为"國朝"并提升 indent
"""

import re
import sys
from pathlib import Path

# 确保能导入 converter 中的基类
sys.path.insert(0, str(Path(__file__).parent.parent))
from converter import ConverterPlugin, strip_punct, extract_brace_content


class SikuMuluPlugin(ConverterPlugin):
    """四库全书简明目录专用插件"""

    ZHU_INDENT = 2   # \注 的缩进
    AN_INDENT = 4    # \按 的缩进

    def get_template_mapping(self) -> dict:
        return {
            "四库全书文渊阁简明目录": "SikuWenyuanMulu",
        }

    def parse_command(self, cmd_name: str, line: str, context: dict) -> list[dict] | None:
        """解析 \\注、\\按 命令"""
        if cmd_name == '注':
            return self._parse_zhu(line, context)
        elif cmd_name == '按':
            return self._parse_an(line, context)
        return None

    def _parse_zhu(self, line: str, context: dict) -> list[dict]:
        """解析 \\注{content} — 可能跨行"""
        lines = context["lines"]
        idx = context["idx"]

        # 收集完整的命令（可能跨行）
        full_text, consumed = self._collect_brace_content(lines, idx, '\\注')

        # 处理 \样式 包裹的内容
        full_text = self._strip_style_wrapper(full_text)

        # 处理抬头命令（\國朝、\平抬、\单抬、\相对抬头、\\分列）
        segments = self._process_taitou_commands(full_text, self.ZHU_INDENT)

        # 去标点
        for seg in segments:
            seg["text"] = strip_punct(seg["text"])

        # 过滤空段
        segments = [s for s in segments if s["text"]]

        # 如果没有特殊分段，返回简单夹注
        if len(segments) == 1 and segments[0]["indent_delta"] == 0:
            return [{
                "type": "jiazhu",
                "text": segments[0]["text"],
                "indent": self.ZHU_INDENT,
                "_consumed_lines": consumed,
            }]

        # 有分段信息
        return [{
            "type": "jiazhu",
            "text": ''.join(s["text"] for s in segments),
            "indent": self.ZHU_INDENT,
            "segments": segments,
            "_consumed_lines": consumed,
        }]

    def _parse_an(self, line: str, context: dict) -> list[dict]:
        """解析 \\按{content} — 可能跨行，含抬头命令"""
        lines = context["lines"]
        idx = context["idx"]

        # 收集完整的命令
        full_text, consumed = self._collect_brace_content(lines, idx, '\\按')

        # 注意：不去掉"謹按"/"謹案"，因为去标点后这些字仍然占位
        # 只去掉冒号（作为标点已在 strip_punct 中处理）

        # 处理抬头命令
        segments = self._process_taitou_commands(full_text, self.AN_INDENT)

        # 去标点
        for seg in segments:
            seg["text"] = strip_punct(seg["text"])

        # 过滤空段
        segments = [s for s in segments if s["text"]]

        if len(segments) == 1 and segments[0]["indent_delta"] == 0:
            return [{
                "type": "jiazhu",
                "text": segments[0]["text"],
                "indent": self.AN_INDENT,
                "_consumed_lines": consumed,
            }]

        return [{
            "type": "jiazhu",
            "text": ''.join(s["text"] for s in segments),
            "indent": self.AN_INDENT,
            "segments": segments,
            "_consumed_lines": consumed,
        }]

    def _collect_brace_content(self, lines: list[str], idx: int, cmd: str) -> tuple[str, int]:
        """收集命令的花括号内容，支持跨行和嵌套花括号"""
        combined = ''
        consumed = 0

        for i in range(idx, len(lines)):
            combined += lines[i]
            consumed += 1
            if i < len(lines) - 1:
                combined += '\n'

            # 检查花括号是否闭合（从命令后的第一个 { 开始计数）
            cmd_pos = combined.find(cmd)
            if cmd_pos == -1:
                continue
            brace_start = combined.find('{', cmd_pos + len(cmd))
            if brace_start == -1:
                continue

            depth = 0
            closed = False
            for j in range(brace_start, len(combined)):
                if combined[j] == '{':
                    depth += 1
                elif combined[j] == '}':
                    depth -= 1
                    if depth == 0:
                        # 提取内容
                        content = combined[brace_start + 1:j]
                        return content.replace('\n', ''), consumed
            # 花括号未闭合，继续读取下一行

        # 未找到完整的花括号 — 尽力提取
        m = re.search(re.escape(cmd) + r'\{(.+)', combined, re.DOTALL)
        if m:
            return m.group(1).rstrip('}').replace('\n', ''), consumed
        return '', consumed

    def _strip_style_wrapper(self, text: str) -> str:
        """去除 \\样式[...]{content} 包裹，保留 content"""
        # 处理多个 \样式 块
        result = text
        while True:
            m = re.search(r'\\样式\[.*?\]\{', result)
            if not m:
                break
            # 找到匹配的右花括号
            start = m.end()
            depth = 1
            end = start
            for i in range(start, len(result)):
                if result[i] == '{':
                    depth += 1
                elif result[i] == '}':
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
            # 替换为内容
            inner = result[start:end]
            result = result[:m.start()] + inner + result[end + 1:]
        return result

    def _process_guochao(self, text: str) -> list[dict]:
        """处理 \\國朝 命令 → 展开为"國朝"，indent 提升 1"""
        if '\\國朝' not in text:
            return [{"text": text, "indent_delta": 0}]

        segments = []
        parts = text.split('\\國朝')

        for i, part in enumerate(parts):
            if i > 0:
                # \國朝 = \相对抬头[1]{國朝}
                # "國朝" 两个字的 indent 提升 1（相对于基础 indent）
                # 但后续文字也在这个提升的 indent 下（直到下一个换列标记）
                segments.append({"text": "國朝", "indent_delta": -1})
            part = part.strip()
            if part:
                segments.append({"text": part, "indent_delta": 0})

        return segments

    def _process_taitou_commands(self, text: str, base_indent: int) -> list[dict]:
        """
        处理按语中的抬头命令（\\单抬、\\平抬、\\相对抬头[N]{text}）

        每个抬头命令：
        1. 截断当前小列（命令前的文字结束当前段）
        2. 设置新的绝对 indent，后续文字在新 indent 下排版

        \\单抬 → 绝对 indent = -1
        \\平抬 → 绝对 indent = 0
        \\相对抬头[N]{text} → 绝对 indent = base_indent - N
        \\國朝 = \\相对抬头[1]{國朝}

        返回的 segments 用 indent_delta（相对于 base_indent）。
        每个抬头命令产生的段落有 force_break=True，强制开始新的小列。
        """
        # 注意：搜索顺序很重要，先搜索长命令再搜短命令
        # \\ (TeX换行) 必须排在最后，因为其他命令都以 \ 开头
        TAITOU_CMDS = ['\\相对抬头', '\\单抬', '\\平抬', '\\國朝']
        ALL_CMDS = TAITOU_CMDS + ['\\\\']
        if not any(cmd in text for cmd in ALL_CMDS):
            return [{"text": text, "indent_delta": 0}]

        segments = []
        remaining = text
        current_abs_indent = base_indent

        while remaining:
            # 找最近的特殊命令
            earliest_pos = len(remaining)
            earliest_cmd = None

            for cmd in ALL_CMDS:
                pos = remaining.find(cmd)
                if pos != -1 and pos < earliest_pos:
                    earliest_pos = pos
                    earliest_cmd = cmd
            # 如果找到 \\，但该位置实际上是某个命令的前缀（如 \\单抬 中的 \\）
            # 需要检查是否有更长的命令也从该位置开始
            if earliest_cmd == '\\\\':
                for cmd in TAITOU_CMDS:
                    if remaining[earliest_pos:].startswith(cmd):
                        earliest_cmd = cmd
                        break

            if earliest_cmd is None:
                # 没有更多命令
                if remaining.strip():
                    segments.append({
                        "text": remaining.strip(),
                        "indent_delta": current_abs_indent - base_indent,
                    })
                break

            # 命令前的文字
            before = remaining[:earliest_pos].strip()
            if before:
                segments.append({
                    "text": before,
                    "indent_delta": current_abs_indent - base_indent,
                })

            # 处理命令 — 每个抬头命令强制开始新小列
            after_cmd = remaining[earliest_pos + len(earliest_cmd):]

            if earliest_cmd == '\\单抬':
                current_abs_indent = -1
                remaining = after_cmd.lstrip()
            elif earliest_cmd == '\\平抬':
                current_abs_indent = 0
                remaining = after_cmd.lstrip()
            elif earliest_cmd == '\\相对抬头':
                m = re.match(r'\[(\d+)\]\{(.+?)\}', after_cmd.lstrip())
                if m:
                    n = int(m.group(1))
                    taitou_text = m.group(2)
                    target_indent = base_indent - n
                    segments.append({
                        "text": taitou_text,
                        "indent_delta": target_indent - base_indent,
                        "force_break": True,
                    })
                    remaining = after_cmd.lstrip()[m.end():].lstrip()
                    current_abs_indent = target_indent
                else:
                    remaining = after_cmd.lstrip()
                continue  # force_break 已在段落中标记
            elif earliest_cmd == '\\國朝':
                # \國朝 = \相对抬头[1]{國朝}
                # 但在实际引擎中，夹注内 sr.get_indent() 可能返回不同值
                # 实测 PDF 显示 \國朝 的 indent 与当前上下文相同（不变）
                segments.append({
                    "text": "國朝",
                    "indent_delta": current_abs_indent - base_indent,
                    "force_break": True,
                })
                remaining = after_cmd.lstrip()
                # current_abs_indent 不变
                continue
            elif earliest_cmd == '\\\\':
                # \\ = TeX 强制换行，在夹注中表示强制分列
                # 不改变 indent，只强制开始新的小列
                remaining = after_cmd.lstrip()
                # 后续文字需要 force_break

            # 对于 \单抬、\平抬、\\，后续第一个段落也需要 force_break
            # 标记在下一轮循环的第一个 segment 中
            if remaining.strip():
                # peek：下一轮循环产生的第一个 segment 需要 force_break
                # 用一个特殊的空段落标记
                segments.append({
                    "text": "",
                    "indent_delta": current_abs_indent - base_indent,
                    "force_break": True,
                    "_placeholder": True,
                })

        # 合并 placeholder 和后续段落
        merged = []
        i = 0
        while i < len(segments):
            seg = segments[i]
            if seg.get("_placeholder") and not seg["text"]:
                # 把 force_break 传给下一个段落
                if i + 1 < len(segments):
                    next_seg = segments[i + 1]
                    next_seg["force_break"] = True
                    next_seg["indent_delta"] = seg["indent_delta"]
                    i += 1
                    continue
                else:
                    i += 1
                    continue
            merged.append(seg)
            i += 1

        return merged
