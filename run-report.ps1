 ($i = $MaxBackups - 1; $i -ge 1; $i--) {
    $src = "$LogPath.$i"
    $dst = "$LogPath." + ($i + 1)
    if (Test-Path $src) { Move-Item -Force $src $dst }
  }

  # Current -> .1
  Move-Item -Force $LogPath "$LogPath.1"
}

$logPath = "D:\Reports\out\run-report.log"
Rotate-Log -LogPath $logPath -MaxBytes (10MB) -MaxBackups 5
Start-Transcript -Path $logPath -Append | Out-Null

try {
  $logPath = "D:\Reports\out\run-report.log"
  Start-Transcript -Path $logPath -Append | Out-Null

  Set-StrictMode -Version Latest
  $ErrorActionPreference = "Stop"

  function Convert-DataTableToObjects {
    param([Parameter(Mandatory=$true)][System.Data.DataTable]$DataTable)

    foreach ($row in $DataTable.Rows) {
      $h = [ordered]@{}
      foreach ($col in $DataTablparam(
  [Parameter(Mandatory=$false)]
  [string]$ConfigPath = "D:\Reports\config.psd1",

  [ValidateSet("AttachOnly","HtmlTable","CsvInBody")]
  [string]$MailBodyMode = "HtmlTable",
  [int]$MaxRowsInBody = 200,
  
  # Protection against huge body (typically SMTP / client limits)
  [Parameter(Mandatory=$false)]
  [int]$MaxBodyKB = 1024
)
function Rotate-Log {
  param(
    [Parameter(Mandatory=$true)][string]$LogPath,
    [int64]$MaxBytes = 10MB,
    [int]$MaxBackups = 5
  )

  if (-not (Test-Path $LogPath)) { return }

  $size = (Get-Item $LogPath).Length
  if ($size -lt $MaxBytes) { return }

  # Delete oldest
  $oldest = "$LogPath.$MaxBackups"
  if (Test-Path $oldest) { Remove-Item -Force $oldest }

  # Shift: .4 -> .5, .3 -> .4, ... , .1 -> .2
  fore.Columns) {
        $h[$col.ColumnName] = $row[$col.ColumnName]
      }
      [pscustomobject]$h
    }
  }

  $cfg = Import-PowerShellDataFile -Path $ConfigPath

  # Output
  $cfgPrefix  = [IO.Path]::GetFileNameWithoutExtension($ConfigPath)
  $reportDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
  $runDate = (Get-Date).ToString("yyyy-MM-dd")
  New-Item -ItemType Directory -Force -Path $cfg.Output.Folder | Out-Null
  #$csvPath = Join-Path $cfg.Output.Folder ("casoi_alerts_{0}.csv" -f $reportDate)
  $csvPath    = Join-Path $cfg.Output.Folder ("{0}_casoi_alerts_{1}.csv" -f $cfgPrefix, $reportDate)

  # SQL query
  $query = Get-Content -Path $cfg.Sql.QueryFile -Raw

  # SQL credential
  if (-not (Test-Path $cfg.Sql.SqlPasswordFile)) {
    throw "Missing SqlPasswordFile: $($cfg.Sql.SqlPasswordFile)"
  }
  Add-Type -AssemblyName System.Security

  $enc   = [IO.File]::ReadAllBytes($cfg.Sql.SqlPasswordFile)
  $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
           $enc, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine
         )
  $sqlPass = [Text.Encoding]::UTF8.GetString($bytes)
  $sqlUser = $cfg.Sql.SqlUser
#  if (-not (Test-Path $cfg.Sql.SqlCredentialPath)) {
#    throw "Missing SQL credential: $($cfg.Sql.SqlCredentialPath)"
#  }
#  $sqlCred = Import-Clixml -Path $cfg.Sql.SqlCredentialPath
#  $sqlUser = $sqlCred.UserName
#  $sqlPass = $sqlCred.GetNetworkCredential().Password

  # Connection string
  $encrypt = [bool]$cfg.Sql.Encrypt
  $trust   = [bool]$cfg.Sql.TrustServerCertificate
  $ct      = [int]$cfg.Sql.ConnectTimeoutSeconds

  $connString = "Server=$($cfg.Sql.ServerInstance);Database=$($cfg.Sql.Database);User ID=$sqlUser;Password=$sqlPass;Encrypt=$encrypt;TrustServerCertificate=$trust;Connect Timeout=$ct;"

  # Execute
  Add-Type -AssemblyName System.Data

  $conn = New-Object System.Data.SqlClient.SqlConnection $connString
  $cmd  = $conn.CreateCommand()
  $cmd.CommandText = $query
  $cmd.CommandTimeout = [int]$cfg.Sql.CommandTimeoutSeconds

  $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
  $dt = New-Object System.Data.DataTable

  $conn.Open()
  [void]$da.Fill($dt)
  $conn.Close()

  $rows = Convert-DataTableToObjects -DataTable $dt

  # CSV export
  $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

  # HTML body
$rowsCount = if ($rows) { $rows.Count } else { 0 }

$periodLabel = if ($cfg.Report -and $cfg.Report.PeriodLabel) { [string]$cfg.Report.PeriodLabel }
               elseif ($cfg.Mail -and $cfg.Mail.PeriodLabel) { [string]$cfg.Mail.PeriodLabel }
               else { "Report date: $reportDate" }

$pre = "<p>$periodLabel</p><p>CSV is attached.</p>"

  if ($rowsCount -eq 0) {
    $tableHtml = "<p>$periodLabel</p><p>No data.</p>"
  }
  elseif ($MailBodyMode -eq "AttachOnly") {
    $tableHtml = $pre
  }
  elseif ($MailBodyMode -eq "CsvInBody") {
    $csvText = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
    $csvHtml = [System.Net.WebUtility]::HtmlEncode($csvText)
    $tableHtml = "<p>$periodLabel</p>" +
                 "<p>CSV content is included below and also attached.</p>" +
                 "<pre style='font-family: Consolas, monospace; white-space: pre;'>" + $csvHtml + "</pre>"
  }
  else {
    # HtmlTable (more readable)
    $bodyRows = $rows
    $truncated = $false
    if ($rowsCount -gt $MaxRowsInBody) {
      $bodyRows = $rows | Select-Object -First $MaxRowsInBody
      $truncated = $true
    }

    $css = @"
<style>
table { border-collapse: collapse; font-family: Segoe UI, Arial, sans-serif; font-size: 12px; }
th, td { border: 1px solid #ddd; padding: 6px 8px; vertical-align: top; }
th { position: sticky; top: 0; background: #f3f3f3; }
</style>
"@
    $note = if ($truncated) { "<p><b>Note:</b> Showing first $MaxRowsInBody rows out of $rowsCount. Full CSV is attached.</p>" } else { "" }

    $tableHtml = $css + $pre + $note + (($bodyRows | ConvertTo-Html -Fragment) -join "`r`n")
}
  $subject = "{0} - {1} - generated: {2}" -f $cfg.Mail.SubjectPrefix, $cfg.Report.Title, $runDate
  # Send email via local relay (no auth)
  $mailParams = @{
    SmtpServer  = $cfg.Mail.SmtpServer
    Port        = [int]$cfg.Mail.Port
    UseSsl      = [bool]$cfg.Mail.UseSsl
    From        = $cfg.Mail.From
    To          = $cfg.Mail.To
    Subject     = $subject
    Body        = $tableHtml
    BodyAsHtml  = $true
    Attachments = $csvPath
    ErrorAction = "Stop"
  }
  if ($cfg.Mail.Cc -and $cfg.Mail.Cc.Count -gt 0) { $mailParams["Cc"] = $cfg.Mail.Cc }

  Send-MailMessage @mailParams

  Write-Host "OK: report created and sent. CSV: $csvPath"
  Stop-Transcript | Out-Null
  exit 0
}
catch {
  Write-Error $_
  try { Stop-Transcript | Out-Null } catch {}
  exit 1
}
