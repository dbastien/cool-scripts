function find { param([string]$Root='.',[string]$Name='*') Get-ChildItem -Recurse -Force -File -Path $Root -Filter $Name }
