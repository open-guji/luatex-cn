# Example Directory

[中文版](README.md)

This directory contains several examples of the `luatex-cn` package, demonstrating features ranging from traditional Chinese book (Guji) layout to modern vertical typesetting.

## Example List

### 1. [Shiji - Annals of the Five Emperors](./史记五帝本纪/)
- **Highlights**: Demonstrates highly complex ancient book layout.
- **Key Features**:
    - Absolutely positioned red seals (overlapping text).
    - Customized Banxin (center column) with text and "Fish Tail" symbols.
    - Complex interlinear annotations.
    - Traditional black grid lines (Wusilan) and indentation.

### 2. [Shiji - Table of Contents](./史记目录/)
- **Highlights**: Styled after the Qing Dynasty "Siku Quanshu" (Northern Four Pavilions edition).
- **Key Features**:
    - Standard ancient book Table of Contents layout.
    - Strict line/character constraints (8 lines, 21 characters per line).
    - Classic white-mouth, double-bordered, single fish-tail style.

### 3. [HongLouMeng - Jiaxu Edition](./红楼梦甲戌本/)
- **Highlights**: Simulates a manuscript/annotated edition style.
- **Key Features**:
    - **Side and Top Notes**: Marginalia implemented using the `sidenote` system.
    - **Double-column Small Text**: Inline annotations in two columns.
    - No fish-tail in Banxin, with page numbers at the bottom.

### 4. [Modern Vertical Book](./现代竖排书/)
- **Highlights**: Minimalist modern vertical style.
- **Key Features**:
    - Demonstrates pure vertical text support without ancient book elements.
    - Suitable for modern literature or reports requiring vertical layout.

---

*Note: All Guji examples are digital reconstructions based on scans of historical documents, intended to showcase the adaptability of `luatex-cn` to various complex vertical typesetting scenarios.*
