# Makefile for luatex-cn package

PACKAGE = luatex_cn
TEXMF = $(shell kpsewhich -var-value TEXMFHOME)
INSTALL_DIR = $(TEXMF)/tex/latex/$(PACKAGE)

.PHONY: install clean test doc

# Install the package to local texmf tree
install:
	@echo "Installing $(PACKAGE) to $(INSTALL_DIR)/"
	@mkdir -p $(INSTALL_DIR)
	@mkdir -p $(INSTALL_DIR)/vertical
	@mkdir -p $(INSTALL_DIR)/banxin
	@mkdir -p $(INSTALL_DIR)/configs
	@cp src/luatex_cn.sty $(INSTALL_DIR)/
	@cp src/guji.cls $(INSTALL_DIR)/
	@cp src/cvbook.cls $(INSTALL_DIR)/
	@cp src/vertical/*.sty $(INSTALL_DIR)/vertical/
	@cp src/vertical/*.lua $(INSTALL_DIR)/vertical/
	@cp src/banxin/*.sty $(INSTALL_DIR)/banxin/
	@cp src/banxin/*.lua $(INSTALL_DIR)/banxin/
	@cp src/configs/*.cfg $(INSTALL_DIR)/configs/ 2>/dev/null || true
	@texhash

# Clean build artifacts
clean:
	rm -f *.aux *.log *.out *.toc *.synctex.gz *.fls *.fdb_latexmk
	rm -f src/vertical/*.aux src/vertical/*.log src/vertical/*.out
	rm -f example/*.aux example/*.log example/*.out example/*.pdf

# Test compilation (compile shiji.tex in example directory)
test:
	cd example && lualatex shiji.tex

# Generate documentation (placeholder)
doc:
	@echo "Documentation generation not yet implemented"
