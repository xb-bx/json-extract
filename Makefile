./json-extract: *.odin
	odin build . -error-pos-style:unix -debug

run: ./json-extract
	./json-extract
