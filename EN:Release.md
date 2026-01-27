English | [中文版](Release)

# Release Process

`luatex-cn` follows an automated release workflow to ensure compliance with CTAN (Comprehensive TeX Archive Network) standards.

## Development Workflow

Building and testing are powered by `l3build`:

```bash
# Run all Lua unit tests
l3build test

# Install to local TEXMFHOME
l3build install

# Create release bundle (.zip)
l3build bundle
```

## Automated Publishing (CI/CD)

GitHub Actions handles the packaging:
1. **Source Sync**: The `main` branch is used for active development.
2. **Packaging**:
   - Extracts `src/`, `文档/` (docs), and `示例/` (examples).
   - Translates folders and filenames to English as required by CTAN, using `scripts/file_name_translation.json`.
   - Generates the standardized directory structure (doc, example, tex).
3. **Release Branch**: The packaged content is pushed to the `ctan` branch and published via GitHub Releases.

## Versioning

- Version numbers are stored in the root `VERSION` file.
- Significant changes are recorded in the [[Changelog | EN:Changelog]].
- We follow Semantic Versioning (SemVer) principles.

---

👉 Next Steps: Check [[Development Documentation | EN:Development]].
