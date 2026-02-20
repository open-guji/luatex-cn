---
description: Verify all example PDF renderings against baselines using a pixel-perfect comparison script.
---

To perform visual regression testing on example TeX files, use the following commands:

// turbo
1. **Check for regressions** (basic suite - default, run during development):
```bash
python3 test/regression_test.py check
```

// turbo
2. **Check past issue regressions** (run occasionally):
```bash
python3 test/regression_test.py check --past-issues
```

// turbo
3. **Check all suites** (run before release):
```bash
python3 test/regression_test.py check --all
```

// turbo
4. **Save new baselines** (update golden reference images):
```bash
python3 test/regression_test.py save
```

This system will:
- Recompile TeX files in the selected suite's `tex/` directory.
- Convert ALL pages of the resulting PDFs to PNGs.
- Perform pixel-perfect comparison against stored baselines in `baseline/`.
- Generate difference images in `diff/` if any page differs.

Test suites are stored under `test/regression_test/{basic,past_issue,complete}/`.
