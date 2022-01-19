build:
	@mkdir -p boot/
	@cd src/ && luacomp main.lua -O ../boot/kernel.lua
