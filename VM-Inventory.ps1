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
                Email        = $appInfo.app.email
                Version      = $appInfo.app.version
                BuildCounter = $appInfo.build.counter
                LastUpdated  = $appInfo.build.lastUpdated
                
                # Display settings
                ShowSummary  = $appInfo.display.showSummary
                ShowHierarchy = $appInfo.display.showHierarchy
                DebugMode    = $appInfo.display.debugMode

                Available    = $true
            }
        } 
        else {
            [Console]::Beep()
            Write-Host "WARNING: app-info.json not found at: $appInfoPath" -ForegroundColor Red

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
        Email       = "N/A"
        Version     = "v0.0.0"
        BuildCounter = 0
        LastUpdated = "N/A"
        
        # Default display settings
        ShowSummary = $true
        ShowHierarchy = $true
        DebugMode   = $false

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

        Write-Host ""
        Write-Host " WARNING:" -ForegroundColor Red

        Write-Host " Console width is too small (" -ForegroundColor Red -NoNewline
        Write-Host "$currentWidth" -ForegroundColor White -NoNewline
        Write-Host " characters)." -ForegroundColor Red

        Write-Host " Recommended width: " -ForegroundColor Red -NoNewline
        Write-Host "$requiredWidth" -ForegroundColor White -NoNewline
        Write-Host " characters or more." -ForegroundColor Red

        Write-Host " Resize your window or use classic PowerShell console." -ForegroundColor Red
        Write-Host ""
        
        Write-Host " Press any key to continue..." -ForegroundColor Yellow
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
    
    $indent = " " * 19
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

    Write-Host ""
    Write-Host "VMware Desktop   : $($config.vmDesktopCore)" -ForegroundColor Cyan
    Write-Host "VMware Version   : $($config.vmProductVersion)" -ForegroundColor Cyan
    Write-Host "Install Path     : $($config.vmInstallPath)" -ForegroundColor Cyan
    Write-Host "Default VM Path  : $($config.defaultVmPath)" -ForegroundColor Cyan
    Write-Host "Windows Services : $($config.vmServices)" -ForegroundColor Cyan

    if ($config.vmInstalledInfo) {
        Write-Host "VMware Installed : $($config.vmInstalledInfo.Name)" -ForegroundColor Cyan
        Write-Host "Version          : $($config.vmInstalledInfo.Version)" -ForegroundColor Cyan
    } 
    else {
        Write-Host "VMware Workstation is NOT installed." -ForegroundColor Red
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

    Write-Host " "
    Write-Host "Total VMs         : $totalVms" -ForegroundColor Green
    Write-Host "Total Standalone  : $totalStandalone" -ForegroundColor Green
    Write-Host "Total Clones      : $totalClones" -ForegroundColor Yellow
    Write-Host "Total Snapshots   : $totalSnapshots" -ForegroundColor Cyan
    
    # Display size with appropriate unit
    if ($totalBytes -ge 1TB) {
        Write-Host ("Total Size On Disk: {0:N2} TB  ({1:N2} GB)" -f $totalTB, $totalGB) -ForegroundColor Green
    } 
    elseif ($totalBytes -ge 1GB) {
        Write-Host ("Total Size On Disk: {0:N2} GB  ({1:N2} MB)" -f $totalGB, $totalMB) -ForegroundColor Green
    } 
    else {
        Write-Host ("Total Size On Disk: {0:N2} MB  ({1:N2} KB)" -f $totalMB, $totalKB) -ForegroundColor Green
    }

}

# ==========================================================
# Step 4: Display VM Info Table
# ==========================================================
function showVmInfoTable {
    param([object[]]$vmInfo)

    Write-Host ""
    Write-Host "Virtual Machines Details:" -ForegroundColor White
    
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
    Write-Host $header -ForegroundColor Yellow

    # Underline
    $underline = ""
    foreach ($col in $columns) {
        $underline += ("-" * $widths[$col]) + " "
    }
    Write-Host $underline -ForegroundColor Yellow

    # Rows
    $rowNum = 1
    $previousVmType = ""
    foreach ($vm in $vmInfo) {
        # Add blank line when VM type group changes and reset counter
        if ($previousVmType -ne "" -and $previousVmType -ne $vm.VmType) {
            Write-Host ""
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
        
        if ($snapshotStart -ge 0) {
            $beforeSnapshot = $row.Substring(0, $snapshotStart)
            $afterSnapshot = $row.Substring($snapshotStart + $snapshotCountStr.Length)
            
            # Output with colors
            $rowColor = if ($vm.VmType -eq "Clone") { "Yellow" } else { "Green" }
            Write-Host $beforeSnapshot -ForegroundColor $rowColor -NoNewline
            Write-Host $snapshotCountStr -ForegroundColor Cyan -NoNewline
            Write-Host $afterSnapshot -ForegroundColor $rowColor
        }
        else {
            # Fallback if string replacement fails
            $rowColor = if ($vm.VmType -eq "Clone") { "Yellow" } else { "Green" }
            Write-Host $row -ForegroundColor $rowColor
        }
        
        $previousVmType = $vm.VmType
        $rowNum++
    }
}

# ==========================================================
# Step 5: Pretty VM Hierarchy
# ==========================================================
function showVmHierarchyPretty {
    param([object[]]$vmInfo)

    Write-Host ""
    Write-Host "Virtual Machine Hierarchy:" -ForegroundColor White

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
            Write-Host $line -ForegroundColor Green
        } 
        else {
            # Clone VM - tree structure in green, content in yellow
            $treeStructure = $left -replace '^(\|[\s\-\|]*)', '$1'
            $vmName = $vm.Name
            $restOfLine = $vm.OS.PadRight($osWidth) + $vm.Size.PadLeft($sizeWidth) + " " + $vm.Created
            
            # Extract just the tree characters (|, -, spaces)
            if ($left -match '^([\|\s\-]+)(.*)$') {
                $treeChars = $matches[1]
                $nameOnly = $matches[2]
                
                Write-Host $treeChars -ForegroundColor Green -NoNewline
                Write-Host $nameOnly -ForegroundColor Yellow -NoNewline
                Write-Host $pad -NoNewline
                Write-Host $restOfLine -ForegroundColor Yellow
            } 
            else {
                # Fallback if regex fails
                Write-Host $left -ForegroundColor Yellow -NoNewline
                Write-Host $pad -NoNewline
                Write-Host $restOfLine -ForegroundColor Yellow
            }
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
    param([int]$requiredWidth = 245)
    Clear-Host

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
    
    # Load the app-info.json configuration
    $appInfo       = getAppInfo -scriptDir $root    
    
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
# Show application info
# ==========================================================
function showAppInfo {
    param([psobject]$config)

    $currentWidth = $Host.UI.RawUI.WindowSize.Width

    Write-Host "============================================================================================"  -ForegroundColor Yellow
    
    # Build banner with different colors for each component
    Write-Host "$($config.AppInfo.Name)" -ForegroundColor Green -NoNewline
    Write-Host " | Version: " -ForegroundColor Yellow -NoNewline
    Write-Host "$($config.AppInfo.Version)" -ForegroundColor Green -NoNewline
    Write-Host " | Build: " -ForegroundColor Yellow -NoNewline
    Write-Host $("{0:000}" -f $config.AppInfo.BuildCounter) -ForegroundColor Green -NoNewline
    Write-Host " | SHA-1: " -ForegroundColor Yellow -NoNewline
    
    if ($config.GitSha.Available) {
        Write-Host "$($config.GitSha.Short)" -ForegroundColor Green -NoNewline
    } 
    else {
        Write-Host "N/A" -ForegroundColor Green -NoNewline
    }
    
    Write-Host " | Date: " -ForegroundColor Yellow -NoNewline
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
    Write-Host "$localTime" -ForegroundColor Green
    Write-Host "============================================================================================"  -ForegroundColor Yellow
    
    Write-Host "Description      : $($config.AppInfo.Description)" -ForegroundColor Cyan
    Write-Host "Author           : $($config.AppInfo.Author)" -ForegroundColor Cyan
    Write-Host "Email            : $($config.AppInfo.Email)" -ForegroundColor Cyan
    write-Host ""
    Write-Host "Console Width    : $currentWidth" -ForegroundColor Yellow
    Write-Host "Script Location  : $($config.Root)" -ForegroundColor Yellow
    Write-Host "Running From     : $($config.RunningFrom)" -ForegroundColor Yellow
    Write-Host "Report Output    : $($config.Report)" -ForegroundColor Yellow
    Write-Host "Show Summary     : $($config.ShowSummaryTable)" -ForegroundColor Yellow
    Write-Host "Debug Mode       : $($config.DebugMode)" -ForegroundColor Yellow
    Write-Host "User Name        : $($config.RunningUsername)" -ForegroundColor Yellow
    Write-Host "Machine Name     : $($config.RunningMachine)" -ForegroundColor Yellow
    Write-Host "Domain           : $(if ($config.RunningDomain) { $config.RunningDomain } else { 'N/A' })" -ForegroundColor Yellow
    Write-Host "User ID          : $($config.RunningUser)" -ForegroundColor Yellow
}

# ==========================================================
# Main Entry Point
# ==========================================================
function main {
    # Initialize Configuration
    # The required console width is set to 245 characters for optimal display
    # Adjust as needed based on your environment
    # See the checkConsoleWidth() function
    $config = init(245)

    # Display Application Info
    showAppInfo($config)
    showVmwareEnvironment($config)

    # Get all VMs
    $vmList    = getAllVms($config)

    # Fail gracefully if no VMs found
    if (-not $vmList -or $vmList.Count -eq 0) {
        [Console]::Beep()

        Write-Host ""
        Write-Host "No VMware virtual machines (.vmx files) were found under:" -ForegroundColor Red
        Write-Host "  $($config.Root)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please verify the VM directory location and try again." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    # Enrich VM Info
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
}

# ==========================================================
# Entry Call
# ==========================================================
main
