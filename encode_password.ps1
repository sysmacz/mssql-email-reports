param(
  [string]$SecretsDir = "D:\Reports\secrets",
  [string]$FileName   = "sql.pass.bin",

  # For prompt only (so that it doesn't change "hardcode" in the text)
  [string]$SqlUser    = "sql user",

  # DPAPI scope: LocalMachine (default) or CurrentUser
  [ValidateSet("LocalMachine","CurrentUser")]
  [string]$Scope      = "LocalMachine",

  # Optional "entropy" (salt) – if used, it must be used again during decryption
  [byte[]]$Entropy    = $null,

  # Overwrite existing file
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 1) Create directory
New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null

# 2) Calculate target path
$path = Join-Path $SecretsDir $FileName

if ((Test-Path -LiteralPath $path) -and -not $Force) {
  throw "File already exists: $path. Use -Force to overwrite."
}

# 3) Ask for password (prompt is parameterized)
$sec = Read-Host ("Enter SQL password for {0}" -f $SqlUser) -AsSecureString

Add-Type -AssemblyName System.Security

$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try {
  $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  $bytes = [Text.Encoding]::UTF8.GetBytes($plain)

  $dpapiScope = [System.Security.Cryptography.DataProtectionScope]::$Scope

  $enc = [System.Security.Cryptography.ProtectedData]::Protect(
    $bytes,
    $Entropy,
    $dpapiScope
  )

  [IO.File]::WriteAllBytes($path, $enc)
}
finally {
  if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
Write-Host ("The password has been encrypted and stored in: {0}" -f $path)