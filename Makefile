ifeq ($(OS),Windows_NT)
	export NOW = $(shell date /t)$(shell time /t)
	# If you're using Windows, change the path to wherever you put LuaComp in.
	COMMAND = lua53 "C:/Standalone Programs/luacomp.lua"
else
	export NOW = $(shell date)
	COMMAND = luacomp
endif

all: compile
	exit

compile:
	@echo Building OCLinux
	@${COMMAND} ./src/OCLinux.lua -O ./boot/kernel/OCLinux.lua

clean:
	@echo Cleaning up...
	@del .\boot\kernel\OCLinux.lua

help:
	${COMMAND} --directives
