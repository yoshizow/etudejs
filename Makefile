RACC_DEBUG = -g -v

.PHONY: build synthetic testparse test distclean

all: build

build: synthetic

synthetic: parser.rb

testparse: build
	ruby test/testparse.rb $(ARG)

testcodegen: build
	ruby test/testcodegen.rb $(ARG)

testinterp: build
	ruby test/testinterp.rb $(ARG)

#test: build
#	ruby rjs.rb

parser.rb: parser.y
	racc $(RACC_DEBUG) -o $@ $<

clean:
	rm -f parser.output

distclean: clean
	rm -f parser.rb
