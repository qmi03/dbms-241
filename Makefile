fmt:
	find . -name *.typ -exec typstfmt {} \; 

watch:
	typst watch main.typ out/watch.pdf

compile:
	typst compile main.typ out/main.pdf

open:
	sioyek out/watch.pdf
