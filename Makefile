# Makefile for luatex-cn package

PACKAGE = luatex_cn
TEXMF = $(shell kpsewhich -var-value TEXMFHOME)

.PHONY: install clean test

# Install the package to local texmf tree
install:
	@echo "Installing $(PACKAGE) to $(TEXMF)/tex/latex/$(PACKAGE)/"
	@mkdir -p $(TEXMF)/tex/latex/$(PACKAGE)
	@cp src/$(PACKAGE).sty $(TEXMF)/tex/latex/$(PACKAGE)/
	@cp src/*.lua $(TEXMF)/tex/latex/$(PACKAGE)/
	@texhash

# Clean build artifacts
clean:
	rm -f *.aux *.log *.out *.toc *.synctex.gz *.fls *.fdb_latexmk src/*.aux src/*.log src/*.out src/*.idx src/*.ilg src/*.ind

# Test compilation
test: example.tex
	TEXINPUTS=./src//: lualatex example.tex

# Generate documentation
doc: src/luatex_cn.dtx
	cd src && pdflatex luatex_cn.dtx
	cd src && makeindex -s gind.ist luatex_cn.idx
	cd src && pdflatex luatex_cn.dtx
