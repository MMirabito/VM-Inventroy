<#
================================================================================
 VM-Inventory
--------------------------------------------------------------------------------
 Description :
    Scans VMware Workstation environments and generates a complete inventory of
    all virtual machines, including size, OS, snapshots, and clone hierarchy.

 Author       : Massimo Max Mirabito
 Version      : v1.0.3
 Created      : 2025-01-01

 permission is granted to use, copy, modify, and distribute this script for
    educational and informational purposes only, provided that the original
    author is credited.

 AI Assistance :
    Portions of this script were developed with the assistance of AI technology
    to accelerate development, improve code clarity, and reduce manual effort.
    All final logic, testing, and validation were performed by a human operator.

License      : Apache License 2.0
--------------------------------------------------------------------------------
 Disclaimer   :
    This script is provided "as-is" without any warranties. The author is not
    responsible for any damage or data loss that may occur from its use.
    Use this script at your own risk.
================================================================================
 Usage :
    1. Ensure you have PowerShell installed on your Windows machine.
    2. Save this script as 'vm-inventory.ps1'.
    3. Open PowerShell as Administrator.
    4. Navigate to the script directory.
    5. Run the script: .\vm-inventory.ps1
    6. Review the output in the console and the generated report file.

 Note        :
    This script is intended for educational and informational purposes only.
    Use it at your own risk. The author is not responsible for any damage or
    data loss that may occur from its use.

================================================================================
#>
# ==========================================================
# Helper: Reliable Script Path Detection
# ==========================================================
function getScriptPath {
    if ($MyInvocation.MyCommand.Path) { return $MyInvocation.MyCommand.Path }
    elseif ($PSCommandPath) { return $PSCommandPath }
    else { throw "Unable to determine script path." }
}

# ==========================================================
# Helper: Check Console Width
# =========================================================
function checkConsoleWidth {
    param([int]$requiredWidth = 180)

    $currentWidth = $Host.UI.RawUI.WindowSize.Width

    if ($currentWidth -lt $requiredWidth) {
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

    $indent = " " * 19
    return ($services | ForEach-Object { "$($_.DisplayName) ($($_.Status))" }) -join ("`n$indent ")
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
    Write-Host " VMware Desktop   : $($config.vmDesktopCore)" -ForegroundColor Cyan
    Write-Host " VMware Version   : $($config.vmProductVersion)" -ForegroundColor Cyan
    Write-Host " Install Path     : $($config.vmInstallPath)" -ForegroundColor Cyan
    Write-Host " Default VM Path  : $($config.defaultVmPath)" -ForegroundColor Cyan
    Write-Host " Windows Services : $($config.vmServices)" -ForegroundColor Cyan

    if ($config.vmInstalledInfo) {
        Write-Host " VMware Installed : $($config.vmInstalledInfo.Name)" -ForegroundColor Cyan
        Write-Host " Version          : $($config.vmInstalledInfo.Version)" -ForegroundColor Cyan
    } else {
        Write-Host " VMware Workstation is NOT installed." -ForegroundColor Red
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

    # Snapshot Count
    $deltaCount = (Get-ChildItem -LiteralPath $vmDir -Filter "*-000*.vmdk" -ErrorAction SilentlyContinue).Count
    $vmsdPath = Join-Path $vmDir "$($vmx.BaseName).vmsd"
    $vmsdCount = 0

    if (Test-Path $vmsdPath) {
        $vmsdCount = (Select-String -Path $vmsdPath -Pattern "snapshot[0-9]+\\.uid" -ErrorAction SilentlyContinue).Count
    }

    $snapshotCount = [Math]::Max($deltaCount, $vmsdCount)

    # Guest OS
    $osLine = Select-String -Path $vmPath -Pattern 'guestOS\s*=\s*".*"' | Select-Object -First 1
    if ($osLine) {
        $rawOs = ($osLine.Matches[0].Value -split '=')[1].Trim().Trim('"')
        $friendlyOs = if ($config.OSMap.ContainsKey($rawOs)) { $config.OSMap[$rawOs] } else { $rawOs }
    } else {
        $friendlyOs = "Unknown"
    }

    # Folder Size
    $bytes = (
        Get-ChildItem -LiteralPath $vmDir -Recurse -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum
    ).Sum

    $sizeBytes = $bytes
    if ($bytes -lt 1GB) {
        $size = ("{0:N2} MB" -f ($bytes / 1MB))
    } else {
        $size = ("{0:N2} GB" -f ($bytes / 1GB))
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

    if ($descriptorFile -and $descriptorFile.Length -gt 0) {
        $descLines = Get-Content -LiteralPath $descriptorFile.FullName -TotalCount 50 -ErrorAction SilentlyContinue
        $joined = $descLines -join "`n"

        if ($joined -match 'parentFileNameHint\s*=\s*"(.*?)"') {
            $parentRel = $matches[1]
            $parentDisk = Split-Path $parentRel -Leaf

            if ([System.IO.Path]::IsPathRooted($parentRel)) {
                $parentPath = $parentRel
            } else {
                $parentPath = Join-Path $vmDir $parentRel
            }

            $parentDir = Split-Path $parentPath -Parent

            if ($parentDir -ne $vmDir) {
                $vmType = "Clone"
                $parentVmName = Split-Path $parentDir -Leaf
            }
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
    }
}

# ==========================================================
# Show VM Summary Info  
# ==========================================================
function showVMInfo {
    param([object[]]$vmDetails)

    $totalVms = $vmDetails.Count
    $totalSnapshots = ($vmDetails | Measure-Object -Property SnapshotCount -Sum).Sum

    $totalBytes = ($vmDetails | Measure-Object -Property SizeBytes -Sum).Sum
    # Convert for readable display
    $totalGB = $totalBytes / 1GB
    $totalMB = $totalBytes / 1MB

    Write-Host " "
    Write-Host " Total VMs        : $totalVms" -ForegroundColor Cyan
    Write-Host " Total Snapshots  : $totalSnapshots" -ForegroundColor Cyan
    Write-Host (" Total Size       : {0:N2} GB  ({1:N2} MB)" -f $totalGB, $totalMB)  -ForegroundColor Cyan

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
    foreach ($vm in $vmInfo) {
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
            } else {
                $row += $val.ToString().PadRight($widths[$col]) + " "
            }
        }
        Write-Host $row
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
        } else {
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

        $line =
            $left +
            $pad +
            $vm.OS.PadRight($osWidth) +
            $vm.Size.PadRight($sizeWidth) +
            $vm.Created 

        if ($depthMap[$name] -eq 0) {
            Write-Host $line -ForegroundColor Yellow
        } else {
            Write-Host $line -ForegroundColor White
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
    param([int]$requiredWidth = 180)
    Clear-Host

    checkConsoleWidth($requiredWidth)

    # Get current user info
    $fullUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $parts = $fullUser -split "\\", 2
    $machineName = $parts[0]
    $userName    = $parts[1]

    $scriptPath    = getScriptPath
    $defaultVmPath = getVmwareDefaultVmPath

    $scriptVersion = "v1.0.3"
    $scriptName    = Split-Path -Leaf $scriptPath
    $scriptDate    = (Get-Item $scriptPath).LastWriteTime.ToString("yyyy-MM-dd")

    $root   = Split-Path -Parent $scriptPath
    $report = Join-Path $root "VM_Clone_Map.txt"

    $showSummaryTable = $true
    $debugMode = $false

    # OS mapping (expand as needed)
    $osMap = @{
        "windows9-64"  = "Windows 10 x64"
        "windows10-64" = "Windows 11 x64"
    }

    return [PSCustomObject]@{
        ScriptPath       = $scriptPath
        ScriptVersion    = $scriptVersion
        ScriptName       = $scriptName
        ScriptDate       = $scriptDate
        Root             = $root
        Report           = $report
        ShowSummaryTable = $showSummaryTable
        DebugMode        = $debugMode

        vmDesktopCore     = getVmwareRegByKey "Core"
        vmProductVersion  = getVmwareRegByKey "ProductVersion"
        vmInstallPath     = getVmwareRegByKey "InstallPath"
        vmServices        = getVmwareServicesStatus
        vmInstalledInfo   = getVmwareInstalledInfo

        OSMap             = $osMap
        defaultVmPath     = $defaultVmPath

        RunningIdentity   = $fullUser        # DESKTOP-NJ4PR8H\SysAdmin
        RunningMachine    = $machineName     # DESKTOP-NJ4PR8H
        RunningUser       = $userName        # SysAdmin

        RunningFrom       = $root   
    }
}

# ==========================================================
# Show application info
# ==========================================================
function showAppInfo {
    param([psobject]$config)

    $currentWidth = $Host.UI.RawUI.WindowSize.Width

    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host " $($config.ScriptName) | Version: $($config.ScriptVersion) | Date: $($config.ScriptDate)" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host " Console Width    : $currentWidth" -ForegroundColor Yellow
    Write-Host " Script Location  : $($config.Root)" -ForegroundColor Yellow
    Write-Host " Running From     : $($config.RunningFrom)" -ForegroundColor Yellow
    Write-Host " Report Output    : $($config.Report)" -ForegroundColor Yellow
    Write-Host " Show Summary     : $($config.ShowSummaryTable)" -ForegroundColor Yellow
    Write-Host " Debug Mode       : $($config.DebugMode)" -ForegroundColor Yellow
    Write-Host " User Name        : $($config.RunningUser)" -ForegroundColor Yellow
    Write-Host " Machine Name     : $($config.RunningMachine)" -ForegroundColor Yellow
    Write-Host " Identity         : $($config.RunningIdentity)" -ForegroundColor Yellow
}

# ==========================================================
# Main Entry Point
# ==========================================================
function main {
    # Initialize Configuration
    $config = init(180)

    # Display Application Info
    showAppInfo($config)
    showVmwareEnvironment($config)

    # Get all VMs
    $vmList    = getAllVms($config)
    # Fail gracefully if no VMs found
    if (-not $vmList -or $vmList.Count -eq 0) {
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
    $vmDetails = $vmDetails | Sort-Object VmType, Name

    # Display VM Info
    showVMInfo($vmDetails)
    
    # Display Summary Table
    if ($config.ShowSummaryTable) {
        showVmInfoTable($vmDetails)
    }
    
    # Display Pretty Hierarchy
    showVmHierarchyPretty $vmDetails
}

# ==========================================================
# Entry Call
# ==========================================================
main
