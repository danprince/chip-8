install:
	cd moongl && make && sudo make install
	cd moonglfw && make && sudo make install

test:
	lua test.lua

start:
	lua main.lua
