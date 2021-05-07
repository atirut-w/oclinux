# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Use LuaComp to build the kernel so that I won't have to write everything for the kernel in a single file(huge chunk of codes are tedious to work with).
- Use Make to automate the compilation and installation process.

### Changed
- The codes for the kernel is now split into multiple files. They have to be built with LuaComp before you can use them.

### Removed
- The full kernel is now excluded from the repository. You now have to build the kernel with LuaComp.

# [1.0.0] - 2021-04-05
### Added
- You can now pass arguments into processes spawned by `dofileThreaded` via an option table parameter "`argument`"

### Changed
- The scheduler now clear thread arguments after the initial thread execution.
- Moved `system.kernel.thread` to `os.thread`.
- Remade the basic display functionalities of the kernel and moved them over to `os.simpleDisplay`.
- Moved kernel module management to `os.kernel`.
- Moved `system.kernel.readfile` to `os.kernel.readfile`.

### Removed
- Removed the `system` table.

## [0.1.0] - 2021-02-28
### Added
- Introduced CHANGELOG.md with semantic versioning.
- Added `getIndex`, `get` and `kill` function to the thread scheduler. These are self-explanatory and receives a PID as argument.
- Added thread status(not to be confused with the coroutine status). As of this commit, a "suspended" status will cause the scheduler to skip the execution of the suspended thread.

### Changed
- Updated `standardlib.lua` to use the new `errorHandler` parameter instead of the old one.
- TinyShell now use a custom error handler for threads. This prevent programs from crashing everything along with it.
