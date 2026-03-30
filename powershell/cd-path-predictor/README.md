# CdPathPredictor

A tiny PowerShell predictor plugin that only emits suggestions for `cd`, `sl`, and `Set-Location`, and only when PowerShell completion says the target is a real container path.

## Why this exists

PSReadLine predictions can come from history and plugins. History is useful, but it is not a guarantee that a predicted path is valid in the current location. This predictor uses PowerShell completion instead, then filters results down to `ProviderContainer` matches so the suggestions are grounded in live path completion.

## Requirements

- PowerShell 7.2 or newer
- PSReadLine 2.2.2 or newer
- .NET 6 SDK or newer to build

## What changed in this version

- Removes the one LINQ call from the hot path in `TryGetLocationCommand(...)`
- Adds a tiny 200 ms cache for repeated prediction calls on the same input
- Keys the cache by current directory, input text, and cursor position
- Caches empty results too, so dead-end inputs do not keep re-running completion

The cache is intentionally tiny and short-lived. It is there to avoid hammering `CommandCompletion.CompleteInput(...)` while you are paused on the same `cd` line, not to invent a whole state machine.

## Build

```powershell
cd <this folder>
dotnet build -c Release
```

The built module files end up under:

```text
bin\Release\net6.0\
```

## Install for your user

```powershell
$moduleRoot = Join-Path $HOME 'Documents\PowerShell\Modules\CdPathPredictor\0.2.1'
New-Item -ItemType Directory -Force -Path $moduleRoot | Out-Null
Copy-Item .\bin\Release\net6.0\CdPathPredictor.dll $moduleRoot
Copy-Item .\bin\Release\net6.0\CdPathPredictor.psd1 $moduleRoot
Import-Module CdPathPredictor
Set-PSReadLineOption -PredictionSource Plugin
Set-PSReadLineOption -PredictionViewStyle ListView
```

## Profile snippet

```powershell
Import-Module CdPathPredictor
Set-PSReadLineOption -PredictionSource Plugin
Set-PSReadLineOption -PredictionViewStyle ListView
```

## Notes

- This is intentionally narrow. It only predicts location commands.
- It leans on `CommandCompletion.CompleteInput(...)` so it follows real PowerShell completion behavior.
- The cache uses `Environment.CurrentDirectory` as a cheap location key. For filesystem `cd` usage that is usually the right tradeoff for a simple plugin.
- If you later want richer behavior, the official `CompletionPredictor` repo is the next thing to raid for ideas, especially its runspace and state-sync pieces.
