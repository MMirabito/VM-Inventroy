<#
================================================================================
 VM-Inventory
--------------------------------------------------------------------------------
 Description:
    VMware Workstation inventory tool that scans and analyzes virtual
    machine environments with visual hierarchy displays and intelligent OS detection.

 Author      : Massimo Max Mirabito
 Version     : v1.0.3
 Created     : 2025-01-01
 License     : Apache License 2.0

 AI Assistance:
    Portions of this script were developed with the assistance of AI technology
    to accelerate development, improve code clarity, and reduce manual effort.
    All final logic, testing, and validation were performed by a human operator.

--------------------------------------------------------------------------------
 Usage: .\VM-Inventory.ps1  or  .\run.cmd  |  Requires: PowerShell 5.1+, VMware Workstation

 Disclaimer:
    This script is provided "as-is" without any warranties. Use at your own risk.
================================================================================
#>


# ==========================================================
# Logging System - Centralized Output Management
# ==========================================================

# Global logging configuration
$script:LogConfig = @{
    EnableConsole = $true
    EnableFile = $false
    LogFilePath = $null
    MinLevel = "INFO"  # DEBUG, INFO, WARN, ERROR
    IncludeTimestamp = $true
    IncludeLevel = $true
    IncludeTimestampInFile = $true   # Full logging in files
    IncludeLevelInFile = $true       # Full logging in files
}

# Log level priorities
$script:LogLevels = @{
    "DEBUG" = 0
    "INFO"  = 1
    "WARN"  = 2
    "ERROR" = 3
}

# Color mapping for console output
$script:LogColors = @{
    "DEBUG" = "Gray"
    "INFO"  = "Green"
    "WARN"  = "Yellow"
    "ERROR" = "Red"
}

# ==========================================================
# Initialize Logging
# ==========================================================
function initializeLogging {
    param(
        [bool]$enableFileLogging = $false,
        [string]$logDirectory = $null,
        [string]$minLevel = "INFO"
    )

    $script:LogConfig.EnableFile = $enableFileLogging
    $script:LogConfig.MinLevel = $minLevel

    if ($enableFileLogging) {
        if (-not $logDirectory) {
            $logDirectory = Split-Path -Parent (getScriptPath)
        }

        # Create logs subdirectory
        $logsDir = Join-Path $logDirectory "logs"
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $logFileName = "VM-Inventory_$timestamp.log"
        $script:LogConfig.LogFilePath = Join-Path $logsDir $logFileName

        # Create empty log file
        "" | Out-File -FilePath $script:LogConfig.LogFilePath -Encoding UTF8
    }
}

# ==========================================================
# Core Logging Function
# ==========================================================
function log {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        
        [string]$MethodName = "",
        [hashtable]$Data = $null,
        $Color = $null,
        $ErrorRecord = $null
    )

    # Check if this log level should be output
    $currentLevelPriority = $script:LogLevels[$script:LogConfig.MinLevel]
    $messageLevelPriority = $script:LogLevels[$Level]

    if ($messageLevelPriority -lt $currentLevelPriority) {
        return  # Skip messages below minimum level
    }

    # Auto-detect calling function and line number
    $lineNumber = ""
    $callStack = Get-PSCallStack
    if ($callStack.Count -gt 1) {
        # Check if called from a wrapper function (logDebug, logInfo, logWarn, logError)
        $caller = $callStack[1]
        if ($caller.FunctionName -match '^log(Debug|Info|Warn|Error)$' -and $callStack.Count -gt 2) {
            # Skip the wrapper and get the actual calling function
            $caller = $callStack[2]
        }
        
        # Always capture line number from call stack
        $lineNumber = $caller.ScriptLineNumber
        
        # Only auto-detect method name if not provided
        if (-not $MethodName) {
            $MethodName = $caller.FunctionName
            if (-not $MethodName -or $MethodName -eq '<ScriptBlock>') {
                $MethodName = "main"
            }
        }
    }

    # Build log message
    $logParts = @()
    
    if ($script:LogConfig.IncludeTimestamp) {
        $logParts += Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    if ($script:LogConfig.IncludeLevel) {
        # Pad log level to 5 characters for alignment
        $logParts += "[" + $Level.PadRight(5) + "]"
    }
    
    if ($MethodName) {
        # Format: [function_name:line_number] with total max width of 25 chars
        # Apply smart truncation showing prefix...suffix for long names
        $maxTotalWidth = 25
        
        if ($lineNumber) {
            $paddedLineNumber = $lineNumber.ToString().PadLeft(4)
            $colonAndLine = ":$paddedLineNumber"  # ":1234" = 5 chars
            $availableForMethod = $maxTotalWidth - $colonAndLine.Length - 2  # -2 for brackets []
            
            if ($MethodName.Length -gt $availableForMethod) {
                # Smart truncation: show prefix...suffix
                $ellipsis = "..."
                $remainingSpace = $availableForMethod - $ellipsis.Length
                $prefixLen = [Math]::Floor($remainingSpace / 2)
                $suffixLen = [Math]::Ceiling($remainingSpace / 2)
                
                $prefix = $MethodName.Substring(0, $prefixLen)
                $suffix = $MethodName.Substring($MethodName.Length - $suffixLen)
                $truncated = $prefix + $ellipsis + $suffix
                $paddedMethodName = $truncated.PadLeft($availableForMethod)
            } else {
                $paddedMethodName = $MethodName.PadLeft($availableForMethod)
            }
            
            $logParts += "[${paddedMethodName}${colonAndLine}]"
        } else {
            # No line number - use full 23 chars for method name (25 - 2 for brackets)
            $availableForMethod = $maxTotalWidth - 2
            
            if ($MethodName.Length -gt $availableForMethod) {
                $ellipsis = "..."
                $remainingSpace = $availableForMethod - $ellipsis.Length
                $prefixLen = [Math]::Floor($remainingSpace / 2)
                $suffixLen = [Math]::Ceiling($remainingSpace / 2)
                
                $prefix = $MethodName.Substring(0, $prefixLen)
                $suffix = $MethodName.Substring($MethodName.Length - $suffixLen)
                $truncated = $prefix + $ellipsis + $suffix
                $paddedMethodName = $truncated.PadLeft($availableForMethod)
            } else {
                $paddedMethodName = $MethodName.PadLeft($availableForMethod)
            }
            
            $logParts += "[$paddedMethodName]"
        }
    }
    
    $logParts += $Message
    
    # Split into metadata and message for separate coloring
    $metadata = $logParts[0..($logParts.Count - 2)] -join " "
    $messageText = $logParts[-1]
    
    # Console output with separate colors
    if ($script:LogConfig.EnableConsole) {
        # Metadata color based on log level
        $metadataColor = switch ($Level) {
            "DEBUG" { "Gray" }
            "INFO"  { "Green" }
            "WARN"  { "Yellow" }
            "ERROR" { "Red" }
            default { "Green" }
        }
        
        # Message color: custom if provided, otherwise use log level color
        $messageColor = if ($null -ne $Color) { $Color } else { $metadataColor }
        
        # Output metadata and message with separate colors
        Write-Host $metadata -ForegroundColor $metadataColor -NoNewline
        Write-Host " $messageText" -ForegroundColor $messageColor
    }

    # File output (identical to console output)
    if ($script:LogConfig.EnableFile -and $script:LogConfig.LogFilePath) {
        # Build file log message - same as console but without colors
        $fileLogParts = @()
        
        if ($script:LogConfig.IncludeTimestampInFile) {
            $fileLogParts += Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        if ($script:LogConfig.IncludeLevelInFile) {
            # Pad log level to 5 characters for alignment in files too
            $fileLogParts += "[" + $Level.PadRight(5) + "]"
        }
        
        if ($MethodName) {
            # Use same format as console: [methodName:lineNum]
            if ($lineNumber) {
                $paddedLineNumber = $lineNumber.ToString().PadLeft(4)
                $colonAndLine = ":$paddedLineNumber"
                $availableForMethod = 25 - $colonAndLine.Length - 2
                
                if ($MethodName.Length -gt $availableForMethod) {
                    $ellipsis = "..."
                    $remainingSpace = $availableForMethod - $ellipsis.Length
                    $prefixLen = [Math]::Floor($remainingSpace / 2)
                    $suffixLen = [Math]::Ceiling($remainingSpace / 2)
                    
                    $prefix = $MethodName.Substring(0, $prefixLen)
                    $suffix = $MethodName.Substring($MethodName.Length - $suffixLen)
                    $truncated = $prefix + $ellipsis + $suffix
                    $paddedMethodName = $truncated.PadLeft($availableForMethod)
                } else {
                    $paddedMethodName = $MethodName.PadLeft($availableForMethod)
                }
                
                $fileLogParts += "[${paddedMethodName}${colonAndLine}]"
            } else {
                $availableForMethod = 23
                
                if ($MethodName.Length -gt $availableForMethod) {
                    $ellipsis = "..."
                    $remainingSpace = $availableForMethod - $ellipsis.Length
                    $prefixLen = [Math]::Floor($remainingSpace / 2)
                    $suffixLen = [Math]::Ceiling($remainingSpace / 2)
                    
                    $prefix = $MethodName.Substring(0, $prefixLen)
                    $suffix = $MethodName.Substring($MethodName.Length - $suffixLen)
                    $truncated = $prefix + $ellipsis + $suffix
                    $paddedMethodName = $truncated.PadLeft($availableForMethod)
                } else {
                    $paddedMethodName = $MethodName.PadLeft($availableForMethod)
                }
                
                $fileLogParts += "[$paddedMethodName]"
            }
        }
        
        $fileLogParts += $Message
        $fileLogMessage = $fileLogParts -join " "
        
        $fileLogMessage | Out-File -FilePath $script:LogConfig.LogFilePath -Append -Encoding UTF8
        
        # Handle ErrorRecord
        $logData = $Data
        if ($ErrorRecord) {
            if (-not $logData) { $logData = @{} }
            $logData['Exception'] = $ErrorRecord.Exception.Message
            $logData['ScriptLine'] = $ErrorRecord.InvocationInfo.ScriptLineNumber
        }
        
        # Add data if provided
        if ($logData) {
            $dataJson = $logData | ConvertTo-Json -Depth 3 -Compress
            "  Data: $dataJson" | Out-File -FilePath $script:LogConfig.LogFilePath -Append -Encoding UTF8
        }
    }
}

# ==========================================================
# Convenience Wrapper Functions
# ==========================================================
function logDebug {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$MethodName = "",
        [hashtable]$Data = $null
    )
    log -Message $Message -Level DEBUG -MethodName $MethodName -Data $Data
}

function logInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$MethodName = "",
        [hashtable]$Data = $null
    )
    log -Message $Message -Level INFO -MethodName $MethodName -Data $Data
}

function logWarn {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$MethodName = "",
        [hashtable]$Data = $null
    )
    log -Message $Message -Level WARN -MethodName $MethodName -Data $Data
}

function logError {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$MethodName = "",
        [hashtable]$Data = $null,
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
    )
    log -Message $Message -Level ERROR -MethodName $MethodName -Data $Data -ErrorRecord $ErrorRecord
}

# Backward compatibility alias for existing debug calls
Set-Alias -Name debug -Value logDebug

# ==========================================================
# Helper: Get Accurate OS from VMware Tools Guest Info
# ==========================================================
function getOSFromGuestInfo {
    param([string]$vmxPath)
    
    try {
        # Check for guestInfo.detailed.data with prettyName
        $guestInfoLine = Select-String -Path $vmxPath -Pattern 'guestInfo\.detailed\.data\s*=\s*".*prettyName=.*"' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($guestInfoLine) {
            $guestData = ($guestInfoLine.Matches[0].Value -split '=', 2)[1].Trim().Trim('"')
            
            # Extract prettyName from the detailed data
            if ($guestData -match "prettyName='([^']+)'") {
                $fullName = $matches[1]
                
                # Truncate verbose build information for cleaner display
                $cleanName = $fullName
                
                # Remove build numbers: (Build XXXXX.XXXX)
                $cleanName = $cleanName -replace '\s*\(Build [^)]+\)', ''
                
                # Clean up extra spaces and commas
                $cleanName = $cleanName -replace ',\s*,', ','  # Remove double commas
                $cleanName = $cleanName -replace '\s+', ' '    # Multiple spaces to single
                $cleanName = $cleanName.Trim()                # Remove leading/trailing spaces
                
                return $cleanName
            }
        }
    } 
    catch {
        # Guest info not available or malformed
    }
    
    return $null
}

# ==========================================================
# Helper: Debug Logging with Formal Format
# ==========================================================
function debug {
    param(
        [string]$MethodName,
        [string]$Message,
        [object]$Data = $null
    )
    
    # Get call stack information
    $callStack = Get-PSCallStack
    $caller = $callStack[1] # The function that called debug
    $lineNumber = $caller.ScriptLineNumber
    $callingFunction = $caller.FunctionName
    
    # If no function name, use the method name parameter
    if (-not $callingFunction -or $callingFunction -eq '<ScriptBlock>') {
        $callingFunction = $MethodName
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $paddedMethodName = $callingFunction.PadLeft(15)
    $paddedLineNumber = $lineNumber.ToString().PadLeft(4)
    Write-Host "[$timestamp] [DEBUG] [${paddedMethodName}:(${paddedLineNumber})] $Message" -ForegroundColor White
    
    if ($Data) {
        if ($Data -is [string]) {
            Write-Host $Data -ForegroundColor White
        } 
        else {
            # Create compact JSON with 2-space indentation and debug header for each line
            $jsonLines = ($Data | ConvertTo-Json -Depth 2) -split "`n"
            foreach ($line in $jsonLines) {
                $trimmedLine = $line.TrimStart()
                $indentLevel = ($line.Length - $trimmedLine.Length) / 4
                $newIndent = "  " * $indentLevel
                $formattedLine = $newIndent + $trimmedLine
                
                # Display debug header with each JSON line
                Write-Host "[$timestamp] [DEBUG] [${paddedMethodName}:(${paddedLineNumber})] $formattedLine" -ForegroundColor White
            }
        }
    }
}

# ==========================================================
# Helper: Read App Info from JSON
# ==========================================================
function getAppInfo {
    param([string]$scriptDir)
    
    $appInfoPath = Join-Path $scriptDir "app-info.json"
    
    try {
        if (Test-Path $appInfoPath) {
            $appInfo = Get-Content $appInfoPath -Raw | ConvertFrom-Json
            
            # Debug mode: Display JSON content
            if ($appInfo.display.debugMode) {
                debug -MethodName "getAppInfo" -Message "JSON Configuration Loaded:" -Data $appInfo
            }
            
            return [PSCustomObject]@{
                Name         = $appInfo.app.name
                Description  = $appInfo.app.description
                Author       = $appInfo.app.author
                GitHubHandle = $appInfo.app.githubHandle
                Version      = $appInfo.app.version
                BuildCounter = $appInfo.build.counter
                LastUpdated  = $appInfo.build.lastUpdated
                
                # Display settings
                ShowSummary  = $appInfo.display.showSummary
                ShowHierarchy = $appInfo.display.showHierarchy
                DebugMode    = $appInfo.display.debugMode

                # Logging settings
                EnableFileLogging = $appInfo.logging.enableFileLogging
                LogLevel = $appInfo.logging.logLevel
                LogFilePath = $appInfo.logging.logFilePath

                Available    = $true
            }
        } 
        else {
            [Console]::Beep()
            log "WARNING: app-info.json not found at: $appInfoPath" -Level WARN

        }
    } 
    catch {
        Write-Warning "Failed to read app-info.json: $_"
    }   
    
    # Fallback to hardcoded values
    return [PSCustomObject]@{
        Name        = "VM-Inventory"
        Description = "VMware Workstation VM inventory tool"
        Author      = "Massimo Max Mirabito"
        GitHubHandle = "@MMirabito"
        Version     = "v0.0.0"
        BuildCounter = 0
        LastUpdated = "N/A"
        
        # Default display settings
        ShowSummary = $true
        ShowHierarchy = $true
        DebugMode   = $false

        # Default logging settings
        EnableFileLogging = $false
        LogLevel = "INFO"
        LogFilePath = ".\\logs\\VM-Inventory_{timestamp}.log"

        Available   = $false
    }
}

# ==========================================================
# Helper: Reliable Script Path Detection
# ==========================================================
function getScriptPath {
    if ($MyInvocation.MyCommand.Path) { return $MyInvocation.MyCommand.Path }
    elseif ($PSCommandPath) { return $PSCommandPath }
    else { throw "Unable to determine script path." }
}

# ==========================================================
# Helper: Get Git Commit SHA
# ==========================================================
function getGitCommitSha {
    try {
        # Check if we're in a git repository
        $gitDir = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -eq 0) {
            $fullSha = git rev-parse HEAD 2>$null
            $shortSha = git rev-parse --short HEAD 2>$null
            
            if ($LASTEXITCODE -eq 0 -and $fullSha -and $shortSha) {
                return [PSCustomObject]@{
                    Full = $fullSha.Trim()
                    Short = $shortSha.Trim()
                    Available = $true
                }
            }
        }
    } 
    catch {
        # Git not available or not a git repository
    }
    
    return [PSCustomObject]@{
        Full = "Not Available"
        Short = "N/A"
        Available = $false
    }
}

# ==========================================================
# Helper: Check Console Width
# =========================================================
function checkConsoleWidth {
    param([int]$requiredWidth = 180)

    $currentWidth = $Host.UI.RawUI.WindowSize.Width

    if ($currentWidth -lt $requiredWidth) {
        [Console]::Beep()

        log "" -Level WARN
        log " WARNING:" -Level WARN

        log " Console width is too small ($currentWidth characters)." -Level WARN
        log " Recommended width: $requiredWidth characters or more." -Level WARN
        log " Resize your window or use classic PowerShell console." -Level WARN
        log "" -Level WARN
        
        log " Press any key to continue..." -Color Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Clear the "Press any key" line
        $Host.UI.RawUI.CursorPosition = @{X=0; Y=$Host.UI.RawUI.CursorPosition.Y-1}
        Write-Host (" " * 50)
        $Host.UI.RawUI.CursorPosition = @{X=0; Y=$Host.UI.RawUI.CursorPosition.Y-1}

    }

}


# ==========================================================
# VMware: Registry & Environment Info
# ==========================================================
function getVmwareRegByKey {
    param([string]$KeyName)

    $paths = @(
        "HKLM:\SOFTWARE\VMware, Inc.",
        "HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.",
        "HKLM:\SOFTWARE\VMware, Inc.\VMware Workstation",
        "HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation"
    )

    foreach ($regPath in $paths) {
        if (Test-Path $regPath) {
            $item = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if ($item.PSObject.Properties.Match($KeyName).Count -gt 0) {
                return $item.$KeyName
            }
        }
    }
    return $null
}

# ==========================================================
# Get VMware Services Status    
# ==========================================================
function getVmwareServicesStatus {
    $services = Get-Service -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "VMware *" }

    if (-not $services) { return "None" }

    # Calculate the maximum service name length for alignment
    $maxNameLength = ($services | ForEach-Object { $_.DisplayName.Length } | Measure-Object -Maximum).Maximum
    
    # Calculate indent to align with log metadata
    # Format: "2025-11-23 12:00:06 [INFO ] [showVmw...ironment: 626] Windows Services : "
    # Timestamp: 19 chars, Space: 1, [Level]: 8, Space: 1, [Method:Line]: 25, Space: 1, Label: 19 = 74 chars total
    $indent = " " * 73
    
    return ($services | ForEach-Object { 
        $paddedName = $_.DisplayName.PadRight($maxNameLength)
        "$paddedName ($($_.Status))"
    }) -join ("`n$indent")
}

# ==========================================================
# Get VMware Installed Application Info
# ==========================================================
function getVmwareInstalledInfo {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $paths) {
        Get-ChildItem $path -ErrorAction SilentlyContinue | ForEach-Object {
            $app = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
            if ($app.DisplayName -like "VMware Workstation*") {
                return [PSCustomObject]@{
                    Name        = $app.DisplayName
                    Version     = $app.DisplayVersion
                    Publisher   = $app.Publisher
                    InstallPath = $app.InstallLocation
                    Uninstall   = $app.UninstallString
                    RegistryKey = $_.PsPath
                }
            }
        }
    }
    return $null
}

# ==========================================================
# Get VMware Default VM Path from preferences.ini
# ==========================================================
function getVmwareDefaultVmPath {
    $prefPath = "$env:APPDATA\VMware\preferences.ini"
    if (Test-Path $prefPath) {
        $line = Select-String -Path $prefPath -Pattern 'prefvmx\.defaultVMPath' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($line) { return ($line.Line -split '=')[1].Trim().Trim('"') }
    }
    return $null
}

# ==========================================================
# Show VMware Environment
# ==========================================================
function showVmwareEnvironment {
    param([psobject]$config)

    log ""
    log "VMware Desktop   : $($config.vmDesktopCore)"
    log "VMware Version   : $($config.vmProductVersion)"
    log "Install Path     : $($config.vmInstallPath)"
    log "Default VM Path  : $($config.defaultVmPath)"
    log "Windows Services : $($config.vmServices)"

    if ($config.vmInstalledInfo) {
        log "VMware Installed : $($config.vmInstalledInfo.Name)"
        log "Version          : $($config.vmInstalledInfo.Version)"
    } 
    else {
        log "VMware Workstation is NOT installed." -Level ERROR -MethodName "showVmwareEnvironment"
    }
}

# ==========================================================
# Step 1: List All VMs
# ==========================================================
function getAllVms {
    param([psobject]$config)

    return Get-ChildItem -Path $config.defaultVmPath -Recurse -Include *.vmx -File -ErrorAction SilentlyContinue |
           Sort-Object BaseName
}

# ==========================================================
# Step 3: Enrich VM list with OS, size, creation date, snapshot count
# ==========================================================
function getVmInfo {
    param([System.IO.FileInfo]$vmx, [psobject]$config)

    $vmPath = $vmx.FullName
    $vmDir  = $vmx.DirectoryName

    if ($config.DebugMode) {
        debug -MethodName "getVmInfo" -Message "Processing VM: $($vmx.BaseName)" -Data @{
            VmxPath = $vmPath
            VmDir = $vmDir
        }
    }

    # Guest OS - Try VMware Tools data first, fallback to metadata
    $guestInfoOS = getOSFromGuestInfo -vmxPath $vmPath
    
    if ($guestInfoOS) {
        # Use accurate OS from VMware Tools
        $friendlyOs = $guestInfoOS
        if ($config.DebugMode) {
            debug -MethodName "getVmInfo" -Message "OS detected from VMware Tools: $friendlyOs"
        }
    } 
    else {
        # Fallback to VMware metadata with OS mapping
        $osLine = Select-String -Path $vmPath -Pattern 'guestOS\s*=\s*".*"' | Select-Object -First 1
        if ($osLine) {
            $rawOs = ($osLine.Matches[0].Value -split '=')[1].Trim().Trim('"')
            $friendlyOs = if ($config.OSMap.ContainsKey($rawOs)) { $config.OSMap[$rawOs] } else { $rawOs }
            if ($config.DebugMode) {
                debug -MethodName "getVmInfo" -Message "OS detected from metadata" -Data @{
                    RawOS = $rawOs
                    MappedOS = $friendlyOs
                }
            }
        } 
        else {
            $friendlyOs = "Unknown"
            if ($config.DebugMode) {
                debug -MethodName "getVmInfo" -Message "OS detection failed - using Unknown"
            }
        }
    }

    # Folder Size
    $bytes = (
        Get-ChildItem -LiteralPath $vmDir -Recurse -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum
    ).Sum

    $sizeBytes = $bytes
    if ($bytes -lt 1GB) {
        $size = ("{0:N2} MB" -f ($bytes / 1MB))
    } 
    else {
        $size = ("{0:N2} GB" -f ($bytes / 1GB))
    }

    if ($config.DebugMode) {
        debug -MethodName "getVmInfo" -Message "Size calculated" -Data @{
            SizeBytes = $sizeBytes
            SizeFormatted = $size
        }
    }

    # Created date
    $created = (Get-Item $vmDir).CreationTime.ToString("yyyy-MM-dd HH:mm:ss")

    # Disk descriptor
    $descriptorFile = Get-ChildItem -LiteralPath $vmDir -Filter *.vmdk -ErrorAction SilentlyContinue |
                      Sort-Object Length |
                      Select-Object -First 1

    $parentVmName = ""
    $parentDisk = ""
    $vmType = "Standalone"
    $standalone = 1
    $clone = 0

    if ($descriptorFile -and $descriptorFile.Length -gt 0) {
        if ($config.DebugMode) {
            debug -MethodName "getVmInfo" -Message "Analyzing disk descriptor" -Data @{
                DescriptorFile = $descriptorFile.Name
                FileSize = $descriptorFile.Length
            }
        }

        $descLines = Get-Content -LiteralPath $descriptorFile.FullName -TotalCount 50 -ErrorAction SilentlyContinue
        $joined = $descLines -join "`n"

        if ($joined -match 'parentFileNameHint\s*=\s*"(.*?)"') {
            $parentRel = $matches[1]
            $parentDisk = Split-Path $parentRel -Leaf

            if ([System.IO.Path]::IsPathRooted($parentRel)) {
                $parentPath = $parentRel
            } 
            else {
                $parentPath = Join-Path $vmDir $parentRel
            }

            $parentDir = Split-Path $parentPath -Parent

            if ($parentDir -ne $vmDir) {
                $vmType = "Clone"
                $parentVmName = Split-Path $parentDir -Leaf
                $standalone = 0
                $clone = 1

                if ($config.DebugMode) {
                    debug -MethodName "getVmInfo" -Message "Clone detected" -Data @{
                        ParentVM = $parentVmName
                        ParentDisk = $parentDisk
                        ParentPath = $parentPath
                    }
                }
            }
        } 
        else {
            if ($config.DebugMode) {
                debug -MethodName "getVmInfo" -Message "No parent hint found - Standalone VM"
            }
        }
    } 
    else {
        if ($config.DebugMode) {
            debug -MethodName "getVmInfo" -Message "No valid descriptor file found"
        }
    }

    # Snapshot Count (calculate after VM type determination)
    # Use .vmsd file as primary source for snapshot count (most reliable)
    $vmsdPath = Join-Path $vmDir "$($vmx.BaseName).vmsd"
    $snapshotCount = 0

    if (Test-Path $vmsdPath) {
        # Count unique snapshots in .vmsd file (most accurate method)
        $vmsdContent = Get-Content -Path $vmsdPath -ErrorAction SilentlyContinue
        $snapshotCount = ($vmsdContent | Where-Object { $_ -match '^snapshot[0-9]+\.uid' }).Count
        
        if ($config.DebugMode) {
            debug -MethodName "getVmInfo" -Message "Snapshots counted from .vmsd file" -Data @{
                VmsdPath = $vmsdPath
                SnapshotCount = $snapshotCount
            }
        }
    } 
    else {
        # Fallback: Look for snapshot-specific delta files (exclude clone deltas)
        # Only count if this is NOT a clone VM (clones have delta files but aren't snapshots)
        if ($vmType -eq "Standalone") {
            $deltaFiles = Get-ChildItem -LiteralPath $vmDir -Name "*.vmdk" -ErrorAction SilentlyContinue | Where-Object { 
                $_ -match '-[0-9]{6}\.vmdk$' -and $_ -notmatch 'flat\.vmdk$'
            }
            $snapshotCount = $deltaFiles.Count
            
            if ($config.DebugMode) {
                debug -MethodName "getVmInfo" -Message "Snapshots counted from delta files (fallback)" -Data @{
                    DeltaFilesFound = $deltaFiles.Count
                    SnapshotCount = $snapshotCount
                }
            }
        } 
        else {
            if ($config.DebugMode) {
                debug -MethodName "getVmInfo" -Message "Skipping delta file count - VM is a clone"
            }
        }
    }

    if ($config.DebugMode) {
        debug -MethodName "getVmInfo" -Message "VM processing completed" -Data @{
            VMName = $vmx.BaseName
            VMType = $vmType
            FinalOS = $friendlyOs
            FinalSize = $size
            SnapshotCount = $snapshotCount
        }
    }

    return [PSCustomObject]@{
        Name           = $vmx.BaseName
        VmType         = $vmType
        Parent         = $parentVmName
        ParentDisk     = $parentDisk
        Descriptor     = $descriptorFile.Name
        Path           = $vmDir
        VmxConfig      = $vmx.Name
        OS             = $friendlyOs
        Size           = $size
        SizeBytes      = $sizeBytes
        Created        = $created
        SnapshotCount  = $snapshotCount

        Standalone     = $standalone
        Clone          = $clone
    }
}

# ==========================================================
# Show VM Summary Info  
# ==========================================================
function showVMInfo {
    param([object[]]$vmDetails)

    $totalVms = $vmDetails.Count
    $totalSnapshots = ($vmDetails | Measure-Object -Property SnapshotCount -Sum).Sum
    $totalStandalone = ($vmDetails | Measure-Object -Property Standalone -Sum).Sum
    $totalClones = ($vmDetails | Measure-Object -Property Clone -Sum).Sum

    $totalBytes = ($vmDetails | Measure-Object -Property SizeBytes -Sum).Sum
    $totalBytes = ($vmDetails | Measure-Object -Property SizeBytes -Sum).Sum
    # Convert for readable display with TB support
    $totalTB = $totalBytes / 1TB
    $totalGB = $totalBytes / 1GB
    $totalMB = $totalBytes / 1MB
    $totalKB = $totalBytes / 1KB

    log " "
    log "Total VMs         : $totalVms" -Color Green
    log "Total Standalone  : $totalStandalone" -Color Green
    log "Total Clones      : $totalClones" -Color Yellow
    log "Total Snapshots   : $totalSnapshots" -Color Cyan
    
    # Display size with appropriate unit
    if ($totalBytes -ge 1TB) {
        log ("Total Size On Disk: {0:N2} TB  ({1:N2} GB)" -f $totalTB, $totalGB) -Color Green
    } 
    elseif ($totalBytes -ge 1GB) {
        log ("Total Size On Disk: {0:N2} GB  ({1:N2} MB)" -f $totalGB, $totalMB) -Color Green
    } 
    else {
        log ("Total Size On Disk: {0:N2} MB  ({1:N2} KB)" -f $totalMB, $totalKB) -Color Green
    }

}

# ==========================================================
# Step 4: Display VM Info Table
# ==========================================================
function showVmInfoTable {
    param([object[]]$vmInfo)

    log ""
    log "Virtual Machines Details:" -Color White
    
    $columns = "#","Name","VmType","Parent","SnapshotCount","Path","VmxConfig","OS","Size","Created"

    $widths = @{}
    foreach ($col in $columns) {
        $max = $col.Length
        foreach ($vm in $vmInfo) {
            if ($col -eq "#") { continue }
            $val = $vm.$col
            if ($null -eq $val) { $val = "" }
            $len = $val.ToString().Length
            if ($len -gt $max) { $max = $len }
        }
        $widths[$col] = $max + 2
    }

    # Header
    $header = ""
    foreach ($col in $columns) {
        $header += $col.PadRight($widths[$col]) + " "
    }
    log $header -Color Yellow -MethodName "showVmInfoTable"

    # Underline
    $underline = ""
    foreach ($col in $columns) {
        $underline += ("-" * $widths[$col]) + " "
    }
    log $underline -Color Yellow -MethodName "showVmInfoTable"

    # Rows
    $rowNum = 1
    $previousVmType = ""
    foreach ($vm in $vmInfo) {
        # Add blank line when VM type group changes and reset counter
        if ($previousVmType -ne "" -and $previousVmType -ne $vm.VmType) {
            log "" -MethodName "showVmInfoTable"
            $rowNum = 1  # Reset counter for new group
        }
        
        $row = ""
        foreach ($col in $columns) {
            if ($col -eq "#") {
                $row += $rowNum.ToString().PadRight($widths[$col]) + " "
                continue
            }
            $val = $vm.$col
            if ($null -eq $val) { $val = "" }
            if ($col -eq "Size") {
                $row += $val.ToString().PadLeft($widths[$col]) + " "
            } 
            else {
                $row += $val.ToString().PadRight($widths[$col]) + " "
            }
        }
        
        # Simple approach: Replace the snapshot count part with colored version
        $snapshotCountStr = $vm.SnapshotCount.ToString().PadRight($widths['SnapshotCount']) + " "
        $snapshotStart = $row.IndexOf($snapshotCountStr)
        
        # Determine row color
        $rowColor = if ($vm.VmType -eq "Clone") { "Yellow" } else { "Green" }
        
        # Log the full row
        log $row -Color $rowColor -MethodName "showVmInfoTable"
        
        $previousVmType = $vm.VmType
        $rowNum++
    }
}

# ==========================================================
# Step 5: Pretty VM Hierarchy
# ==========================================================
function showVmHierarchyPretty {
    param([object[]]$vmInfo)

    log ""
    log "Virtual Machine Hierarchy:" -Color White

    # Build children lookup 
    $children = @{}
    foreach ($vm in $vmInfo) { $children[$vm.Name] = @() }
    foreach ($vm in $vmInfo) {
        if ($vm.Parent -and $children.ContainsKey($vm.Parent)) {
            $children[$vm.Parent] += $vm.Name
        }
    }

    # Compute depth
    $depthMap = @{}
    function getDepth {
        param($name, $level)
        $depthMap[$name] = $level
        foreach ($c in $children[$name]) {
            getDepth $c ($level + 1)
        }
    }
    foreach ($base in $vmInfo | Where-Object { $_.VmType -eq "Standalone" }) {
        getDepth $base.Name 0
    }

    # Build left labels
    $leftLabels = @{}
    foreach ($vm in $vmInfo) {
        $level = $depthMap[$vm.Name]
        if ($level -eq 0) {
            $prefix = "+-- "
        } 
        else {
            $prefix = ("|   " * $level) + "|-- "
        }

        $label = $prefix + $vm.Name 
        $leftLabels[$vm.Name] = $label
    }

    # Compute max left-label width and pad labels
    $maxLeft = ($leftLabels.Values | Measure-Object Length -Maximum).Maximum
    $keys = $leftLabels.Keys.Clone()   # snapshot of keys
    foreach ($key in $keys) {
        $text = $leftLabels[$key]
        $len  = $text.Length
        $pad  = $maxLeft - $len

        if ($pad -lt 0) { $pad = 0 }

        $padded = $text + (" " * $pad)
        $leftLabels[$key] = $padded
    }

    # OS / Size column widths
    $osWidth   = ($vmInfo.OS   | Measure-Object Length -Maximum).Maximum + 4
    $sizeWidth = ($vmInfo.Size | Measure-Object Length -Maximum).Maximum + 4

    # Print node
    function printNode {
        param([string]$name)

        $vm = $vmInfo | Where-Object { $_.Name -eq $name }
        $left = $leftLabels[$name] 

        $padSpaces = $maxLeft - $left.Length
        if ($padSpaces -lt 1) { $padSpaces = 1 }
        $pad = " " * $padSpaces

        if ($depthMap[$name] -eq 0) {
            # Standalone VM - everything in green
            $line =
                $left +
                $pad +
                $vm.OS.PadRight($osWidth) +
                $vm.Size.PadLeft($sizeWidth) + 
                " " +
                $vm.Created 
            log $line -Color Green -MethodName "showVmHierarchyPretty"
        } 
        else {
            # Clone VM - full line in yellow
            $line =
                $left +
                $pad +
                $vm.OS.PadRight($osWidth) +
                $vm.Size.PadLeft($sizeWidth) + 
                " " +
                $vm.Created
            log $line -Color Yellow -MethodName "showVmHierarchyPretty"
        }

        foreach ($child in $children[$name]) {
            printNode $child
        }
    }

    # Print bases
    foreach ($base in $vmInfo | Where-Object { $_.VmType -eq "Standalone" } | Sort-Object Name) {
        printNode $base.Name
    }
}


# ==========================================================
# Initialization
# ==========================================================
function init {
    param(
        [int]$requiredWidth = 245
    )
    
    Clear-Host

    $scriptDir = Split-Path -Parent (getScriptPath)
    
    # Load app-info.json to get logging configuration
    $appInfo = getAppInfo -scriptDir $scriptDir
    
    # Initialize logging system with settings from app-info.json
    $logFilePath = if ($appInfo.LogFilePath -and $appInfo.LogFilePath -ne ".\\logs\\VM-Inventory_{timestamp}.log") {
        # Use custom path if provided
        $appInfo.LogFilePath
    } else {
        # Use default pattern with actual timestamp
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        Join-Path $scriptDir "logs\VM-Inventory_$timestamp.log"
    }
    
    # Create logs directory if it doesn't exist and file logging is enabled
    if ($appInfo.EnableFileLogging) {
        $logsDir = Split-Path -Parent $logFilePath
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }
    }
    
    initializeLogging -enableFileLogging $appInfo.EnableFileLogging -logDirectory $scriptDir -minLevel $appInfo.LogLevel
    
    log "Initializing VM-Inventory script" -Level DEBUG -MethodName "init"

    checkConsoleWidth($requiredWidth)

    # Get current user info
    $fullUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $parts = $fullUser -split "\\", 2
    
    # Extract domain/machine and username
    $domainOrMachine = $parts[0]
    $userName = $parts[1]
    
    # Get actual machine name separately
    $machineName = $env:COMPUTERNAME
    
    # Determine if user is domain or local
    $isDomainUser = $domainOrMachine -ne $machineName
    $domainName = if ($isDomainUser) { $domainOrMachine } else { $null }

    $scriptPath    = getScriptPath
    $defaultVmPath = getVmwareDefaultVmPath
    $gitSha        = getGitCommitSha
    $root          = Split-Path -Parent $scriptPath    
    
    $scriptName    = Split-Path -Leaf $scriptPath
    $report        = Join-Path $root "VM_Clone_Map.txt"

    # Use display settings from JSON, with fallback defaults
    $showSummaryTable = $appInfo.ShowSummary
    $debugMode = $appInfo.DebugMode

    # OS mapping (expand as needed)
	$osMap = @{
		# ---- Windows Desktop ----
		"windows7-64"           = "Windows 7 x64"
		"windows8-64"           = "Windows 8 / 8.1 x64"
		"windows9-64"           = "Windows 10 x64"
		"windows10-64"          = "Windows 11 x64"
		"win11-64"              = "Windows 11 x64"

		# ---- Windows Server ----
		"windows9srv-64"        = "Windows Server 2016 x64"
		"windows2019srv-64"     = "Windows Server 2019 x64"
		"windows2019srvnext-64" = "Windows Server 2022 x64"
		"windows10srv-64"       = "Windows Server 2022 x64"
		"windows2025srv-64"     = "Windows Server 2025 x64"
		"windows2008srv-64"     = "Windows Server 2008 R2 x64"
		"windows2003srv-64"     = "Windows Server 2003 x64"

		# ---- Linux ----
		"ubuntu-64"             = "Ubuntu 64-bit"
		"ubuntu22-64"           = "Ubuntu 22.04+ 64-bit"
		"debian-64"             = "Debian 64-bit"
		"rhel7-64"              = "RHEL 7 x64"
		"rhel8-64"              = "RHEL 8 x64"
		"centos-64"             = "CentOS 64-bit"
		"sles12-64"             = "SUSE Linux Enterprise 12 x64"
		"sles15-64"             = "SUSE Linux Enterprise 15 x64"
		"rocky-64"              = "Rocky Linux 64-bit"
		"alma-64"               = "AlmaLinux 64-bit"
		"genericlinux-64"       = "Generic Linux 64-bit"

		# ---- macOS ----
		"darwin-64"             = "macOS (64-bit)"
		"darwin21-64"           = "macOS Monterey"
		"darwin22-64"           = "macOS Ventura"

		# ---- Catch-all ----
		"other-64"              = "Other 64-bit OS"
		"otherlinux-64"         = "Other Linux 64-bit"
		"Unknown"               = "Unknown OS"
	}


    return [PSCustomObject]@{
        ScriptPath       = $scriptPath
        ScriptName       = $scriptName
        Root             = $root
        Report           = $report
        ShowSummaryTable = $showSummaryTable
        DebugMode        = $debugMode
        GitSha           = $gitSha
        AppInfo          = $appInfo

        vmDesktopCore     = getVmwareRegByKey "Core"
        vmProductVersion  = getVmwareRegByKey "ProductVersion"
        vmInstallPath     = getVmwareRegByKey "InstallPath"
        vmServices        = getVmwareServicesStatus
        vmInstalledInfo   = getVmwareInstalledInfo

        OSMap             = $osMap
        defaultVmPath     = $defaultVmPath

        RunningUser       = $fullUser        # DOMAIN\User or MACHINE\User
        RunningMachine    = $machineName     # DESKTOP-NJ4PR8H
        RunningUsername   = $userName        # SysAdmin
        RunningDomain     = $domainName      # DOMAIN or null if local user
        IsDomainUser      = $isDomainUser    # True if domain user, False if local

        RunningFrom       = $root   
    }
}

# ==========================================================
# Test Logging System - Display All Logging Options
# ==========================================================
function testLoggingSystem {
    log ""
    log "========================================" -Color Yellow
    log "LOGGING SYSTEM TEST" -Color Yellow
    log "========================================" -Color Yellow
    log ""
    
    # Test 1: Direct log() calls with different levels
    log "Test 1: Direct log() function calls" -Color White
    log "This is a DEBUG message" -Level DEBUG
    log "This is an INFO message" -Level INFO
    log "This is a WARN message" -Level WARN
    log "This is an ERROR message" -Level ERROR
    log ""
    
    # Test 2: Convenience wrapper functions
    log "Test 2: Convenience wrapper functions" -Color White
    logDebug "This is logDebug() wrapper"
    logInfo "This is logInfo() wrapper"
    logWarn "This is logWarn() wrapper"
    logError "This is logError() wrapper"
    log ""
    
    # Test 3: With explicit MethodName
    log "Test 3: Explicit MethodName parameter" -Color White
    log "Message with explicit method name" -Level INFO -MethodName "CustomMethod"
    log ""
    
    # Test 4: With Data parameter
    log "Test 4: With Data hashtable" -Color White
    log "Message with data" -Level INFO -Data @{
        Key1 = "Value1"
        Key2 = "Value2"
        Count = 42
    }
    log ""
    
    # Test 5: Long method name truncation test
    log "Test 5: Method name truncation (simulated)" -Color White
    log "This tests truncation" -Level INFO -MethodName "VeryLongMethodNameThatExceedsTheMaximumWidth"
    log ""
    
    # Test 6: Custom colors
    log "Test 6: Custom colors" -Color White
    log "Custom Magenta color" -Level INFO -Color Magenta
    log "Custom Green color" -Level INFO -Color Green
    log "Custom Red color" -Level INFO -Color Red
    log ""
    
    # Test 7: Empty message
    log "Test 7: Empty message handling" -Color White
    log "" -Level INFO
    log ""
    
    # Test 8: All levels at once
    log "Test 8: All levels in sequence" -Color White
    log "Level: DEBUG" -Level DEBUG
    log "Level: INFO" -Level INFO
    log "Level: WARN" -Level WARN
    log "Level: ERROR" -Level ERROR
    log ""
    
    log "========================================" -Color Yellow
    log "LOGGING SYSTEM TEST COMPLETE" -Color Yellow
    log "========================================" -Color Yellow
    log ""
    
    # Pause to review
    log "Press any key to continue with main script..." -Color Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    log ""
}

# ==========================================================
# Show application info
# ==========================================================
function showAppInfo {
    param([psobject]$config)

    $currentWidth = $Host.UI.RawUI.WindowSize.Width

    log "============================================================================================" -Color Yellow -MethodName "showAppInfo"
    
    # Build banner as a single line
    $shaValue = if ($config.GitSha.Available) { $config.GitSha.Short } else { "N/A" }
    
    # Convert UTC timestamp to local time with timezone
    $localTime = try { 
        $convertedTime = [DateTime]::Parse($config.AppInfo.LastUpdated).ToLocalTime()
        $tzName = [TimeZoneInfo]::Local.StandardName
        # Create proper timezone abbreviations
        $timezone = switch -Regex ($tzName) {
            "Eastern"   { if ([TimeZoneInfo]::Local.IsDaylightSavingTime($convertedTime)) { "EDT" } else { "EST" } }
            "Central"   { if ([TimeZoneInfo]::Local.IsDaylightSavingTime($convertedTime)) { "CDT" } else { "CST" } }
            "Mountain"  { if ([TimeZoneInfo]::Local.IsDaylightSavingTime($convertedTime)) { "MDT" } else { "MST" } }
            "Pacific"   { if ([TimeZoneInfo]::Local.IsDaylightSavingTime($convertedTime)) { "PDT" } else { "PST" } }
            "Atlantic"  { if ([TimeZoneInfo]::Local.IsDaylightSavingTime($convertedTime)) { "ADT" } else { "AST" } }
            default     { ($tzName -replace ' Time| Standard| Daylight').Substring(0, [Math]::Min(3, ($tzName -replace ' Time| Standard| Daylight').Length)) }
        }
        $convertedTime.ToString("yyyy-MM-dd HH:mm:ss") + " $timezone"
    } 
    catch { 
        $config.AppInfo.LastUpdated 
    }
    
    $banner = "$($config.AppInfo.Name) | Version: $($config.AppInfo.Version) | Build: $("{0:000}" -f $config.AppInfo.BuildCounter) | SHA-1: $shaValue | Date: $localTime"
    log $banner -Color Green -MethodName "showAppInfo"
    log "============================================================================================" -Color Yellow -MethodName "showAppInfo"
    
    log "Description      : $($config.AppInfo.Description)" -Color Cyan -MethodName "showAppInfo"
    log "Author           : $($config.AppInfo.Author)" -Color Cyan -MethodName "showAppInfo"
    log "GitHub           : $($config.AppInfo.GitHubHandle)" -Color Cyan -MethodName "showAppInfo"
    log "" -MethodName "showAppInfo"
    log "Console Width    : $currentWidth" -Color Yellow -MethodName "showAppInfo"
    log "Script Location  : $($config.Root)" -Color Yellow -MethodName "showAppInfo"
    log "Running From     : $($config.RunningFrom)" -Color Yellow -MethodName "showAppInfo"
    log "Report Output    : $($config.Report)" -Color Yellow -MethodName "showAppInfo"
    log "Show Summary     : $($config.ShowSummaryTable)" -Color Yellow -MethodName "showAppInfo"
    log "Debug Mode       : $($config.DebugMode)" -Color Yellow -MethodName "showAppInfo"
    log "User Name        : $($config.RunningUsername)" -Color Yellow -MethodName "showAppInfo"
    log "Machine Name     : $($config.RunningMachine)" -Color Yellow -MethodName "showAppInfo"
    log "Domain           : $(if ($config.RunningDomain) { $config.RunningDomain } else { 'N/A' })" -Color Yellow -MethodName "showAppInfo"
    log "User ID          : $($config.RunningUser)" -Color Yellow -MethodName "showAppInfo"
}

# ==========================================================
# Main Entry Point
# ==========================================================
function main {
    # TEST LOGGING SYSTEM - Comment out after testing
    testLoggingSystem
    
    # Initialize Configuration
    # The required console width is set to 245 characters for optimal display
    # Adjust as needed based on your environment
    # See the checkConsoleWidth() function
    # 
    # Logging configuration is now set in app-info.json under the "logging" section
    $config = init -requiredWidth 245
    
    log "Configuration initialized" -Level DEBUG -MethodName "main" -Data @{
        DefaultVmPath = $config.defaultVmPath
        ShowSummaryTable = $config.ShowSummaryTable
        DebugMode = $config.DebugMode
    }

    # Display Application Info
    showAppInfo($config)
    showVmwareEnvironment($config)

    # Get all VMs
    log "Scanning for virtual machines..." -Level DEBUG -MethodName "main"
    $vmList    = getAllVms($config)

    # Fail gracefully if no VMs found
    if (-not $vmList -or $vmList.Count -eq 0) {
        [Console]::Beep()

        log "" -Level ERROR -MethodName "main"
        log "No VMware virtual machines (.vmx files) were found under:" -Level ERROR -MethodName "main"
        log "  $($config.defaultVmPath)" -Level ERROR -MethodName "main"
        log "" -Level ERROR -MethodName "main"
        log "Please verify the VM directory location and try again." -Level WARN -MethodName "main"
        log "" -Level ERROR -MethodName "main"
        exit 1
    }

    log "Found $($vmList.Count) virtual machine(s)" -MethodName "main"

    # Enrich VM Info
    log "Enriching VM information..." -Level DEBUG -MethodName "main"
    $vmDetails = foreach ($vm in $vmList) { getVmInfo -vmx $vm -config $config }
    $vmDetails = $vmDetails | Sort-Object VmType, Parent, Name, Created

    # Display VM Info
    showVMInfo($vmDetails)
    
    # Display Summary Table
    if ($config.ShowSummaryTable) {
        showVmInfoTable($vmDetails)
    }
    
    # Display Pretty Hierarchy
    if ($config.AppInfo.ShowHierarchy) {
        showVmHierarchyPretty $vmDetails
    }

    Write-Host ""
    
    log "VM-Inventory completed successfully" -Level DEBUG -MethodName "main"
    
    # If file logging was enabled, inform user of log location
    if ($script:LogConfig.EnableFile) {
        log "Log file saved to: $($script:LogConfig.LogFilePath)" -MethodName "main"
    }
}

# ==========================================================
# Entry Call
# ==========================================================
main
