.PHONY: test clean

SRC=$(shell find src -name "*.d")
FLAGS=-unittest -main -g -cov -Isrc

test:
	dmd $(FLAGS) $(SRC) -oflibddoc-tests
	./libddoc-tests

clean:
	-rm libddoc-tests
	-rm *.o
	-rm *.lst
