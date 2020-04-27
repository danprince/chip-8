install:
	cd moongl && make && make install
	cd moonglfw && make && make install

test:
	lua test.lua

start:
	lua main.lua
