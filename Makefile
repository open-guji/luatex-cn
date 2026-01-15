# Makefile for luatex-cn package

PACKAGE = luatex_cn
TEXMF = $(shell kpsewhich -var-value TEXMFHOME)
INSTALL_DIR = $(TEXMF)/tex/latex/$(PACKAGE)

.PHONY: install clean test doc

# Install the package to local texmf tree
install:
	@echo "Installing $(PACKAGE) to $(INSTALL_DIR)/"
	@mkdir -p $(INSTALL_DIR)
	@mkdir -p $(INSTALL_DIR)/cn_vertical
	@mkdir -p $(INSTALL_DIR)/cn_banxin
	@mkdir -p $(INSTALL_DIR)/guji
	@cp luatex_cn/luatex_cn.sty $(INSTALL_DIR)/
	@cp cn_vertical/*.sty $(INSTALL_DIR)/cn_vertical/
	@cp cn_vertical/*.lua $(INSTALL_DIR)/cn_vertical/
	@cp cn_banxin/*.sty $(INSTALL_DIR)/cn_banxin/
	@cp cn_banxin/*.lua $(INSTALL_DIR)/cn_banxin/
	@cp guji/*.cls $(INSTALL_DIR)/guji/
	@texhash

# Clean build artifacts
clean:
	rm -f *.aux *.log *.out *.toc *.synctex.gz *.fls *.fdb_latexmk
	rm -f cn_vertical/*.aux cn_vertical/*.log cn_vertical/*.out

# Test compilation (compile shiji.tex in cn_vertical directory)
test:
	cd cn_vertical && lualatex shiji.tex

# Generate documentation (placeholder)
doc:
	@echo "Documentation generation not yet implemented"
