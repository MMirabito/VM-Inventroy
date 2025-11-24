# VM-Inventory Architecture Documentation

## Overview
This document provides a technical deep-dive into the VM-Inventory PowerShell script architecture, explaining how the code works, function relationships, and data flow.

## Script Flow Diagram

```mermaid
graph TD
    A[Script Start] --> B[init Function]
    B --> C[Configuration Loading]
    C --> D[VMware Environment Detection]
    D --> E[VM Discovery]
    E --> F[VM Analysis]
    F --> G[Data Processing]
    G --> H[Display Output]
    H --> I[Script End]

    C --> C1[Load app-info.json]
    C --> C2[Get Git SHA]
    C --> C3[Detect Script Path]
    
    D --> D1[Registry Scan]
    D --> D2[Service Status]
    D --> D3[VM Path Detection]
    
    E --> E1[Find .vmx Files]
    E --> E2[Recursive Search]
    
    F --> F1[OS Detection]
    F --> F2[Size Calculation]
    F --> F3[Clone Analysis]
    F --> F4[Snapshot Count]
    
    G --> G1[Sort & Group]
    G --> G2[Build Hierarchy]
    
    H --> H1[App Info Display]
    H --> H2[Summary Table]
    H --> H3[Detailed Table]
    H --> H4[Hierarchy Tree]
```

## Function Architecture

### Core Functions Map

```mermaid
graph LR
    subgraph "Entry Point"
        main[main]
    end
    
    subgraph "Initialization"
        init[init]
        getAppInfo[getAppInfo]
        getScriptPath[getScriptPath]
        getGitCommitSha[getGitCommitSha]
        checkConsoleWidth[checkConsoleWidth]
    end
    
    subgraph "VMware Detection"
        getVmwareRegByKey[getVmwareRegByKey]
        getVmwareServicesStatus[getVmwareServicesStatus]
        getVmwareInstalledInfo[getVmwareInstalledInfo]
        getVmwareDefaultVmPath[getVmwareDefaultVmPath]
    end
    
    subgraph "VM Discovery & Analysis"
        getAllVms[getAllVms]
        getVmInfo[getVmInfo]
        getOSFromGuestInfo[getOSFromGuestInfo]
    end
    
    subgraph "Display Functions"
        showAppInfo[showAppInfo]
        showVmwareEnvironment[showVmwareEnvironment]
        showVMInfo[showVMInfo]
        showVmInfoTable[showVmInfoTable]
        showVmHierarchyPretty[showVmHierarchyPretty]
    end
    
    subgraph "Utilities"
        debug[debug]
    end
    
    main --> init
    init --> getAppInfo
    init --> getScriptPath
    init --> getGitCommitSha
    init --> checkConsoleWidth
    init --> getVmwareRegByKey
    init --> getVmwareServicesStatus
    init --> getVmwareInstalledInfo
    init --> getVmwareDefaultVmPath
    
    main --> getAllVms
    main --> getVmInfo
    getVmInfo --> getOSFromGuestInfo
    
    main --> showAppInfo
    main --> showVmwareEnvironment
    main --> showVMInfo
    main --> showVmInfoTable
    main --> showVmHierarchyPretty
```

## Data Flow Architecture

### Configuration Data Flow

```mermaid
sequenceDiagram
    participant S as Script Start
    participant I as init()
    participant A as getAppInfo()
    participant J as app-info.json
    participant G as getGitCommitSha()
    participant R as Git Repository
    
    S->>I: Initialize
    I->>A: Load configuration
    A->>J: Read JSON file
    J-->>A: App metadata
    I->>G: Get version info
    G->>R: Query Git SHA
    R-->>G: Commit hash
    G-->>I: Version data
    A-->>I: Configuration object
    I-->>S: Complete config
```

### VM Discovery & Analysis Flow

```mermaid
sequenceDiagram
    participant M as main()
    participant GV as getAllVms()
    participant GI as getVmInfo()
    participant OS as getOSFromGuestInfo()
    participant FS as File System
    
    M->>GV: Discover VMs
    GV->>FS: Search for .vmx files
    FS-->>GV: VM file list
    GV-->>M: VM collection
    
    loop For each VM
        M->>GI: Analyze VM
        GI->>OS: Detect OS
        OS->>FS: Read VMware Tools data
        FS-->>OS: Guest info
        OS-->>GI: OS details
        GI->>FS: Calculate size
        FS-->>GI: Disk usage
        GI->>FS: Count snapshots
        FS-->>GI: Snapshot data
        GI-->>M: VM details
    end
```

## Function Details

### 1. Initialization Functions

#### `init()`
**Purpose**: Master initialization function that sets up the entire runtime environment.

**Key Responsibilities**:
- Console width validation
- User context detection
- VMware environment discovery
- Configuration loading
- OS mapping setup

**Returns**: Configuration object with all runtime settings

#### `getAppInfo()`
**Purpose**: Loads application metadata from JSON configuration.

**Data Sources**:
- `app-info.json` file
- Fallback hardcoded values

**Key Features**:
- Debug mode detection
- Display preferences
- Version and build information

### 2. VMware Detection Functions

#### `getVmwareRegByKey()`
**Purpose**: Registry scanner for VMware installation details.

**Registry Paths Searched**:
```
HKLM:\SOFTWARE\VMware, Inc.
HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.
HKLM:\SOFTWARE\VMware, Inc.\VMware Workstation
HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstation
```

#### `getVmwareDefaultVmPath()`
**Purpose**: Extracts default VM storage location from VMware preferences.

**File Location**: `%APPDATA%\VMware\preferences.ini`
**Key**: `prefvmx.defaultVMPath`

### 3. VM Analysis Functions

#### `getVmInfo()`
**Purpose**: Core VM analysis function that extracts comprehensive VM metadata.

**Analysis Pipeline**:
```mermaid
graph TD
    A[VM .vmx File] --> B[OS Detection]
    B --> C[Size Calculation]
    C --> D[Clone Analysis]
    D --> E[Snapshot Counting]
    E --> F[Metadata Extraction]
    F --> G[VM Object Creation]
    
    B --> B1[VMware Tools Data]
    B --> B2[Fallback to Metadata]
    
    D --> D1[Disk Descriptor Analysis]
    D --> D2[Parent Relationship Detection]
    
    E --> E1[.vmsd File Count]
    E --> E2[Delta File Fallback]
```

#### `getOSFromGuestInfo()`
**Purpose**: Advanced OS detection using VMware Tools guest information.

**Detection Strategy**:
1. Parse `guestInfo.detailed.data` from .vmx
2. Extract `prettyName` field
3. Clean up verbose build information
4. Return human-readable OS name

### 4. Display Functions

#### `showVmHierarchyPretty()`
**Purpose**: Creates visual tree representation of VM clone relationships.

**Tree Building Algorithm**:
```mermaid
graph TD
    A[Build Children Map] --> B[Calculate Depth Levels]
    B --> C[Generate Tree Labels]
    C --> D[Compute Column Widths]
    D --> E[Recursive Tree Printing]
    
    E --> E1[Standalone VMs - Green]
    E --> E2[Clone VMs - Yellow]
    E --> E3[Tree Structure - Green]
```

**Tree Characters**:
- `+-- ` for standalone VMs (root level)
- `|   ` for continuation lines
- `|── ` for clone branches

#### `showVmInfoTable()`
**Purpose**: Displays comprehensive VM data in tabular format with color coding.

**Table Features**:
- Dynamic column width calculation
- Color-coded rows (Green for standalone, Yellow for clones)
- Cyan highlighting for snapshot counts
- Group separation with blank lines

## Data Structures

### Configuration Object
```powershell
[PSCustomObject]@{
    # Path Information
    ScriptPath       = String
    Root             = String
    RunningFrom      = String
    
    # Application Metadata  
    AppInfo          = AppInfoObject
    GitSha           = GitShaObject
    
    # VMware Environment
    vmDesktopCore    = String
    vmProductVersion = String
    vmInstallPath    = String
    defaultVmPath    = String
    vmServices       = String
    vmInstalledInfo  = VmwareInstallObject
    
    # Runtime Settings
    ShowSummaryTable = Boolean
    OSMap            = Hashtable
    
    # User Context
    RunningUser      = String
    RunningMachine   = String
    RunningUsername  = String
    RunningDomain    = String
    IsDomainUser     = Boolean
}
```

### VM Information Object
```powershell
[PSCustomObject]@{
    Name           = String      # VM display name
    VmType         = String      # "Standalone" or "Clone"
    Parent         = String      # Parent VM name (for clones)
    ParentDisk     = String      # Parent disk file
    Descriptor     = String      # VMDK descriptor file
    Path           = String      # VM directory path
    VmxConfig      = String      # .vmx filename
    OS             = String      # Detected operating system
    Size           = String      # Human-readable size
    SizeBytes      = Integer     # Size in bytes
    Created        = String      # Creation timestamp
    SnapshotCount  = Integer     # Number of snapshots
    Standalone     = Integer     # 1 if standalone, 0 if clone
    Clone          = Integer     # 1 if clone, 0 if standalone
}
```

## Logging System

The script includes a centralized logging system with multiple output levels and flexible configuration.

### Log Levels (Priority-Based Filtering)
- **DEBUG** (0): Detailed diagnostic information for troubleshooting
- **INFO** (1): General informational messages
- **WARN** (2): Warning messages for potential issues
- **ERROR** (3): Error messages for failures

### Logging Functions
- **Core**: `_log()` - Private function handling all logging logic
- **Wrappers**: `logDebug()`, `logInfo()`, `logWarn()`, `logError()` - Public API
- **Configuration**: `initializeLogging()` - Sets up logging system
- **Helpers**: `hideMethodName()`, `showMethodName()` - Toggle method name display

### Log Output Format
```
2025-01-23 14:30:15 [DEBUG] [    getVmInfo:123] Processing VM: Windows-10-Pro
2025-01-23 14:30:15 [INFO ] [ 456] Total VMs: 15
2025-01-23 14:30:15 [WARN ] [ 789] Console width is too small
2025-01-23 14:30:15 [ERROR] [1234] VMware Workstation is NOT installed
```

**Format Components**:
- Timestamp: `yyyy-MM-dd HH:mm:ss`
- Log Level: `[LEVEL]` (padded to 5 characters)
- Line Number: `[####]` (padded to 4 digits)
- Method Name (optional): `[methodName:line]` (padded to 25 characters)
- Message: Actual log content

### Color Coding
- **DEBUG**: `DarkGray` - Diagnostic details
- **INFO**: `Green` - Normal operations
- **WARN**: `Yellow` - Warnings
- **ERROR**: `Red` - Errors
- **Custom**: Messages can override default color

### Configuration
Logging is configured via `app-info.json`:
```json
{
  "logging": {
    "enableFileLogging": false,
    "logLevel": "INFO",
    "logFilePath": ".\\logs\\VM-Inventory_{timestamp}.log",
    "includeMethodName": true
  }
}
```

### File Logging
When enabled, logs are written to timestamped files in the `logs/` directory with identical format to console output (minus colors).

## Performance Considerations

### File System Operations
- **Recursive VM Discovery**: Uses `Get-ChildItem -Recurse` for comprehensive scanning
- **Size Calculation**: Aggregates all files in VM directory
- **Snapshot Detection**: Prioritizes .vmsd files over file pattern matching

### Memory Usage
- **Streaming Processing**: VMs processed individually, not batch-loaded
- **Selective Data Loading**: Only reads necessary portions of large files
- **Object Reuse**: Configuration object passed by reference

### Error Handling Strategy
- **Graceful Degradation**: Script continues even if individual VMs fail
- **Informative Fallbacks**: Default values when detection fails
- **User Feedback**: Clear error messages and warnings

## Extension Points

### Adding New OS Detection
1. Extend the `$osMap` hashtable in `init()`
2. Add new patterns to `getOSFromGuestInfo()`
3. Update fallback logic in `getVmInfo()`

### Adding New Display Formats
1. Create new function following naming pattern `show*`
2. Add configuration flag to `app-info.json`
3. Integrate into main execution flow

### Adding New VM Analysis Features
1. Extend the VM object structure
2. Add analysis logic to `getVmInfo()`
3. Update display functions to show new data

## Dependencies and Requirements

### PowerShell Requirements
- **Version**: 5.1 or higher
- **Execution Policy**: Must allow script execution
- **Modules**: Uses built-in cmdlets only

### External Dependencies
- **VMware Workstation**: Must be installed for VM path detection
- **File System Access**: Read permissions to VM directories
- **Registry Access**: For VMware installation detection

### Optional Dependencies
- **Git**: For commit SHA detection and build automation
- **app-info.json**: For configuration customization

## Troubleshooting Guide

### Common Issues
1. **No VMs Found**: Check VMware default path in preferences.ini
2. **Permission Denied**: Run PowerShell as Administrator
3. **Console Width Warnings**: Resize terminal or use classic console
4. **Missing OS Detection**: Ensure VMware Tools are installed in VMs

### Debug Mode Activation
Enable detailed logging by setting log level to DEBUG in app-info.json:
```json
{
  "logging": {
    "logLevel": "DEBUG",
    "enableFileLogging": true,
    "includeMethodName": true
  }
}
```

This documentation provides a comprehensive technical reference for understanding, maintaining, and extending the VM-Inventory script architecture.