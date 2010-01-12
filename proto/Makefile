RACC_DEBUG = -g -v

.PHONY: synthetic testparse test distclean

all: test

synthetic: parser.rb

testparse: synthetic
	ruby test/testparse.rb $(ARG)

testcodegen: synthetic
	ruby test/testcodegen.rb $(ARG)

testinterp: synthetic
	ruby test/testinterp.rb $(ARG)

test: synthetic
	ruby rjs.rb

parser.rb: parser.y
	racc $(RACC_DEBUG) -o $@ $<

distclean:
	rm -f parser.rb
