# Makefile for luatex-cn package

PACKAGE = luatex-cn
TEXMF = $(shell kpsewhich -var-value TEXMFHOME)

.PHONY: install clean test

# Install the package to local texmf tree
install:
	@echo "Installing $(PACKAGE) to $(TEXMF)/tex/latex/$(PACKAGE)/"
	@mkdir -p $(TEXMF)/tex/latex/$(PACKAGE)
	@cp $(PACKAGE).sty $(TEXMF)/tex/latex/$(PACKAGE)/
	@cp *.lua $(TEXMF)/tex/latex/$(PACKAGE)/
	@texhash

# Clean build artifacts
clean:
	rm -f *.aux *.log *.out *.toc *.synctex.gz *.fls *.fdb_latexmk

# Test compilation
test: example.tex
	lualatex example.tex

# Generate documentation
doc: luatex-cn.dtx
	pdflatex luatex-cn.dtx
	makeindex -s gind.ist luatex-cn.idx
	pdflatex luatex-cn.dtx
