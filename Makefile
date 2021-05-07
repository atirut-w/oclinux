ifeq ($(OS),Windows_NT)
	export NOW = $(shell date /t)$(shell time /t)
	# If you're using Windows, change the path to wherever you put LuaComp in.
	COMMAND = lua53 "C:/Standalone Programs/luacomp.lua"
else
	export NOW = $(shell date)
	# This assumes you already have LuaComp installed.
	COMMAND = luacomp
endif

all: compile install clean
	@exit

compile:
	@echo Compiling OCLinux...
ifeq ($(OS),Windows_NT)
	@if not exist .\build mkdir .\build
else
	@mkdir -p ./build
endif
	@${COMMAND} ./src/OCLinux.lua -O ./build/OCLinux.lua

install:
	@echo Installing OCLinux...
ifeq ($(OS),Windows_NT)
	@if not exist .\boot\kernel mkdir .\boot\kernel
	@move .\build\OCLinux.lua .\boot\kernel
else
	@mkdir -p ./boot/kernel
	@mv .\build\OCLinux.lua .\boot\kernel
endif

clean:
	@echo Cleaning up...
ifeq ($(OS),Windows_NT)
	@if exist .\build rmdir .\build
else
	@mkdir -p ./build
endif
