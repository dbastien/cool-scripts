# Unsaved Dump Plugin for Notepad++

This is a minimal C++ Notepad++ plugin that:

1. finds every open tab that looks like an unsaved scratch buffer
2. combines those tabs into one `dump.txt`
3. closes those tabs without prompting to save

## What counts as an "unsaved" tab here

This build treats a tab as an unsaved scratch tab when the tab's name/path is **not an absolute filesystem path**.

That matches the common Notepad++ `new 1`, `new 2`, etc. case.

If you want it to also include named files with unsaved edits, change `IsUnsavedScratchBuffer()` in `src/UnsavedDumpPlugin.cpp`.

## Build

### Requirements

- Visual Studio 2022 or Build Tools for Visual Studio 2022
- CMake 3.21+
- 64-bit Notepad++

### Commands

From a Developer PowerShell or x64 Native Tools prompt:

```powershell
cd path\to\UnsavedDumpPlugin
cmake -S . -B build -A x64
cmake --build build --config Release
```

The linker writes the DLL under `build\` (exact path depends on the CMake generator; often `build\Release\` for VS-style layouts). This repo also keeps a copy at:

```text
dist\UnsavedDumpPlugin.dll
```

## Install

Create this folder if it does not exist:

```text
%ProgramFiles%\Notepad++\plugins\UnsavedDumpPlugin\
```

Then copy:

```text
dist\UnsavedDumpPlugin.dll
```

into that folder and restart Notepad++.

For portable Notepad++, use the portable app's `plugins\UnsavedDumpPlugin\` folder instead.

## Use

After restart, go to:

```text
Plugins -> Unsaved Dump Plugin -> Dump unsaved tabs to dump.txt and close
```

The plugin opens a Save dialog with `dump.txt` prefilled. Once the dump is written successfully, it closes the matching tabs.

## Notes

- The dump file is written as UTF-8 with BOM.
- Each tab is wrapped with `BEGIN TAB` / `END TAB` markers.
- The plugin only closes tabs **after** the dump file is written successfully.
- I built this as standalone source; I did **not** compile or test the DLL in this environment.
