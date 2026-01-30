# SQL-Reports

PowerShell-based SQL reporting automation system that generates daily and monthly reports from SQL databases and distributes them via email.

## Overview

This project provides an automated solution to:
- Execute SQL queries against a SQL Server database
- Generate reports in CSV and HTML formats
- Email reports with configurable email templates
- Manage encrypted SQL credentials securely using DPAPI
- Handle log rotation for long-running operations

## Features

- **Multiple Report Configurations**: Support for day and month-based reports (configured via `.psd1` files)
- **Secure Credential Management**: DPAPI encryption for SQL passwords
- **Flexible Email Delivery**: Multiple email body formats (HTML table, CSV attachment, CSV in body)
- **Log Management**: Automatic log rotation with configurable size and backup limits
- **Data Conversion**: Automatic DataTable to PowerShell object conversion for flexible output
- **Error Handling**: Comprehensive error logging and transaction support

## Project Structure

```
SQL-Reports/
├── run-report.ps1                    # Main report execution script
├── encode_password.ps1               # Utility to encrypt SQL credentials
├── config-report-sla_day.psd1        # Day report configuration
├── config-report-sla_day.sql         # Day report SQL query
├── config-report-sla_day.xml         # Day report metadata (optional)
├── config-report-sla_month.psd1      # Month report configuration
├── config-report-sla_month.sql       # Month report SQL query
├── config-report-sla_month.xml       # Month report metadata (optional)
├── secrets/                          # Directory for encrypted credentials
└── README.md                         # This file
```

## Scripts

### `run-report.ps1`

Main report execution script that:
1. Loads configuration from a `.psd1` file
2. Decrypts SQL credentials from encrypted binary file
3. Executes SQL query against the database
4. Exports results to CSV format
5. Generates HTML email body with results summary
6. Sends email via configured SMTP server
7. Maintains transaction log

**Parameters:**
- `-ConfigPath` (optional): Path to configuration file (default: `D:\Reports\config.psd1`)
- `-MailBodyMode` (optional): Email format - `AttachOnly`, `HtmlTable`, or `CsvInBody` (default: `HtmlTable`)
- `-MaxRowsInBody` (optional): Maximum rows to display in email body (default: `200`)
- `-MaxBodyKB` (optional): Maximum email body size in KB (default: `1024`)

**Usage:**
```powershell
.\run-report.ps1 -ConfigPath "D:\Reports\config.psd1"
```

### `encode_password.ps1`

Utility script to encrypt SQL passwords using Windows DPAPI (Data Protection API).

**Parameters:**
- `-SecretsDir` (optional): Directory to store encrypted password (default: `D:\Reports\secrets`)
- `-FileName` (optional): Filename for encrypted password (default: `sql.pass.bin`)
- `-SqlUser` (optional): SQL username for display in prompt (default: `Insert password for encoding`)
- `-Scope` (optional): DPAPI scope - `LocalMachine` or `CurrentUser` (default: `LocalMachine`)
- `-Entropy` (optional): Optional salt for encryption
- `-Force` (switch): Overwrite existing encrypted file

**Usage:**
```powershell
.\ encode_password.ps1 -SecretsDir "D:\Reports\secrets" -FileName "sql.pass.bin" -SqlUser "sqluser"
```

**Important:** The same `-Scope` and `-Entropy` values used during encryption must be used during decryption in `run-report.ps1`.

## Configuration Files

### Format: PowerShell Data File (.psd1)

Configuration files use PowerShell's hashtable format. Example structure:

```powershell
@{
  Sql = @{
    ServerInstance            = "server.domain,port"
    Database                  = "DatabaseName"
    QueryFile                 = "path\to\query.sql"
    SqlUser                   = "username"
    SqlPasswordFile           = "path\to\sql.pass.bin"
    Encrypt                   = $false
    TrustServerCertificate    = $true
    ConnectTimeoutSeconds     = 15
    CommandTimeoutSeconds     = 120
  }

  Output = @{
    Folder = "path\to\output"
  }

  Report = @{
    Title       = "Report Title"
    PeriodLabel = "Period description (e.g., 'for yesterday')"
  }

  Mail = @{
    SmtpServer     = "smtp.server"
    Port           = 25
    UseSsl         = $false
    To             = @("recipient@example.com")
    Cc             = @("cc@example.com")
    SubjectPrefix  = "[Prefix] "
  }
}
```

### Configuration Sections

#### `Sql`
- **ServerInstance**: SQL Server instance (format: `server[,port]`)
- **Database**: Database name
- **QueryFile**: Path to SQL query file
- **SqlUser**: SQL username
- **SqlPasswordFile**: Path to DPAPI-encrypted password file
- **Encrypt**: Enable SQL encryption (set to `$true` for production)
- **TrustServerCertificate**: Accept self-signed certificates
- **ConnectTimeoutSeconds**: Connection timeout duration
- **CommandTimeoutSeconds**: Query execution timeout duration

#### `Output`
- **Folder**: Directory where CSV files will be saved

#### `Report`
- **Title**: Report title for display
- **PeriodLabel**: Description of reporting period (e.g., "for yesterday", "for January 2026")

#### `Mail`
- **SmtpServer**: SMTP server hostname or IP
- **Port**: SMTP port (typically 25, 587, or 465)
- **UseSsl**: Enable SSL/TLS
- **To**: Array of recipient email addresses
- **Cc**: Array of CC email addresses (optional)
- **SubjectPrefix**: Prefix for email subject line

## Setup Instructions

### 1. Prepare Directories
```powershell
mkdir "D:\Reports\out"
mkdir "D:\Reports\secrets"
```

### 2. Encrypt SQL Password
```powershell
.\encode_password.ps1 `
  -SecretsDir "D:\Reports\secrets" `
  -FileName "sql.pass.bin" `
  -SqlUser "sqluser" `
  -Force
```

When prompted, enter the SQL server password.

### 3. Create Configuration Files
Copy and customize `config-report-sla_day.psd1` and `config-report-sla_month.psd1` with your:
- SQL Server connection details
- Database and query file paths
- Output folder
- Email recipients and SMTP settings

### 4. Create SQL Query Files
Create `.sql` files referenced in the configuration (e.g., `config-report-sla_day.sql`) with your report queries.

### 5. Test Execution
```powershell
.\run-report.ps1 -ConfigPath "D:\Reports\config-report-sla_day.psd1"
```

### 6. Schedule with Windows Task Scheduler
Create scheduled tasks to run reports automatically:
```powershell
# Create a trigger for daily execution
$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -File 'D:\Reports\run-report.ps1' -ConfigPath 'D:\Reports\config-report-sla_day.psd1'"
Register-ScheduledTask -TaskName "Daily SQL Report" -Trigger $trigger -Action $action -RunLevel Highest
```

## Email Output Modes

### AttachOnly
Sends CSV file as attachment without including data in email body.

### HtmlTable
(Default) Generates HTML table in email body with limited rows (configurable via `-MaxRowsInBody`). Full CSV is attached.

### CsvInBody
Includes full CSV content in email body (as pre-formatted text) in addition to attachment.

## Security Considerations

1. **DPAPI Encryption**: Passwords are encrypted using Windows DPAPI, which is tied to the machine and user account
2. **File Permissions**: Restrict access to `secrets/` directory containing encrypted credentials
3. **SQL Connections**: Use `Encrypt=$true` and `TrustServerCertificate=$false` in production
4. **Credential Scope**: 
   - Use `LocalMachine` scope for automation accounts
   - Use `CurrentUser` scope for user-specific credentials

## Logging

- Transaction logs are written to the path specified in `run-report.ps1` (default: `D:\Reports\out\run-report.log`)
- Logs are automatically rotated when exceeding 10MB, with up to 5 backups retained
- Each execution is appended to the current log file

## Troubleshooting

### "Missing SqlPasswordFile"
- Verify the encrypted password file exists at the path specified in configuration
- Run `encode_password.ps1` to create it if missing

### "File already exists: $path"
- Use `-Force` parameter to overwrite existing files, or remove the file manually

### Connection Timeout
- Increase `ConnectTimeoutSeconds` in configuration
- Verify SQL Server is accessible from the machine
- Check firewall rules for the specified port

### Query Timeout
- Increase `CommandTimeoutSeconds` in configuration
- Optimize the SQL query for performance

### Email Not Sent
- Verify SMTP server is accessible and port is correct
- Check firewall rules for SMTP communication
- Ensure recipient email addresses are valid
- Review transaction log for specific error messages

## Requirements

- Windows PowerShell 5.0+ or PowerShell Core 7.0+
- SQL Server Native Client or ODBC driver
- Network access to SQL Server and SMTP server
- Write permissions to output folder

## Contributing

We welcome contributions! Whether you're reporting bugs, suggesting features, or submitting code, please follow these guidelines:

### Reporting Bugs

1. Check the [Issues](../../issues) page to ensure the bug hasn't already been reported
2. Create a new issue with a clear, descriptive title
3. Include:
   - Detailed description of the bug
   - Steps to reproduce the issue
   - Expected vs. actual behavior
   - Your environment (OS, PowerShell version, SQL Server version)
   - Relevant error messages or logs

### Suggesting Features

1. Check existing issues to see if the feature has been suggested
2. Create an issue describing:
   - The feature request with clear motivation
   - Use cases and expected behavior
   - Any alternatives you've considered

### Submitting Code Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes with clear, atomic commits
4. Follow these code standards:
   - Use meaningful variable and function names
   - Add comments for complex logic
   - Follow PowerShell naming conventions (PascalCase for functions, camelCase for variables)
   - Ensure code is compatible with PowerShell 5.0+
5. Test your changes thoroughly:
   - Test with the provided test configurations
   - Verify email functionality works as expected
   - Check log rotation and error handling
6. Update documentation if needed (README.md, comments, etc.)
7. Commit with descriptive messages: `git commit -m "Add feature: description"`
8. Push to your fork and submit a Pull Request

### Pull Request Process

1. Update documentation to reflect any new features or changes
2. Include a clear description of what your PR does and why
3. Link related issues using "Closes #issue-number" 
4. Be responsive to feedback and review comments
5. Ensure your code doesn't break existing functionality

### Code Review

All submissions require review. Maintainers will provide feedback on:
- Code quality and style
- Functionality and correctness
- Documentation completeness
- Testing coverage

### Development Setup

1. Clone the repository
2. Review [Setup Instructions](#setup-instructions) section
3. Test scripts in your environment
4. Make changes and validate thoroughly

### Communication

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow

## License

MIT License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2026 SYSMA.CZ

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

## Support

For issues or questions, contact the development team.
