# VM-Inventory

A PowerShell-based inventory tool that scans VMware Workstation environments and generates a complete inventory of all virtual machines, including size, OS, snapshots, and clone hierarchy.

## 📋 Overview

VM-Inventory is a comprehensive PowerShell script designed for VMware Workstation users who need to:
- Track all virtual machines in their environment
- Monitor disk space usage across VMs
- Identify snapshot usage and potential disk bloat
- Visualize VM clone relationships and parent-child hierarchies
- Generate detailed reports of their virtual infrastructure

## ✨ Features

- **Automatic VM Discovery**: Scans your VMware Workstation directory for all `.vmx` files
- **Detailed VM Information**: Displays OS type, disk size, creation date, and snapshot count
- **Clone Detection**: Identifies cloned VMs and their parent relationships
- **Hierarchical View**: Beautiful tree-style visualization of VM parent-child relationships
- **VMware Environment Info**: Shows installed VMware version, services status, and configuration
- **Summary Statistics**: Total VM count, snapshot count, and aggregate disk usage
- **Friendly OS Names**: Translates VMware guest OS codes to readable names

## 📚 Documentation

- **[Architecture Documentation](ARCHITECTURE.md)** - Technical deep-dive into how the code works, with visual diagrams and function explanations
- **[Development Scripts](scripts/README.md)** - Git hooks and development tools for automated versioning

## 📊 Sample Output

The script provides multiple views of your VM inventory:

### 1. Application Header
```
============================================================================================
VM-Inventory | Version: v1.0.3 | Build: 012 | SHA-1: a1b2c3d | Date: 2025-01-23 14:30:15 EST
============================================================================================
Description      : VMware Workstation VM inventory CLI tool
Author           : Massimo Max Mirabito
GitHub           : @MMirabito

Console Width    : 180
Script Location  : D:\MyProjects\VM-Inventroy
Running From     : D:\MyProjects\VM-Inventroy
User Name        : SysAdmin
Machine Name     : DESKTOP-ABC123
```

### 2. VMware Environment
```
VMware Desktop   : VMware Workstation Pro
VMware Version   : 17.0.2
Install Path     : C:\Program Files (x86)\VMware\VMware Workstation
Default VM Path  : D:\VMs
Windows Services : VMware Authorization Service (Running)
                   VMware DHCP Service (Running)
                   VMware NAT Service (Running)
```

### 3. Summary Information
```
Total VMs        : 29
Total Standalone : 14
Total Clones     : 15
Total Snapshots  : 12
Total Size       : 1.63 TB  (1,672.18 GB)
```

### 4. Detailed Table View
```
# Name                    VmType     Parent           SnapshotCount Path                              OS                    Size      Created             
- ----------------------- ---------- ---------------- ------------- --------------------------------- --------------------- --------- --------------------
1 Windows-10-Base         Standalone                  2             D:\VMs\Windows-10-Base            Windows 10 x64        67.76 GB  2021-06-12 09:19:16
2 Ubuntu-20.04-LTS        Standalone                  0             D:\VMs\Ubuntu-20.04-LTS           Ubuntu 20.04.3 LTS    12.34 GB  2021-08-15 10:30:22
3 Development-Clone       Clone      Windows-10-Base  1             D:\VMs\Development-Clone          Windows 10 x64        96.52 GB  2021-11-03 17:23:42
4 Testing-Environment     Clone      Windows-10-Base  0             D:\VMs\Testing-Environment        Windows 10 x64        45.18 GB  2022-01-15 09:45:30
```
*Note: Standalone VMs display in green, clones in yellow, and snapshot counts in cyan*

### 5. Hierarchical Tree View
```
Virtual Machine Hierarchy:
+-- Windows-10-Base              Windows 10 x64           67.76 GB     2021-06-12 09:19:16
|   |── Development-Clone        Windows 10 x64           96.52 GB     2021-11-03 17:23:42
|   |── Testing-Environment      Windows 10 x64           45.18 GB     2022-01-15 09:45:30
+-- Ubuntu-20.04-LTS             Ubuntu 20.04.3 LTS       12.34 GB     2021-08-15 10:30:22
+-- Windows-Server-2019          Windows Server 2019      89.45 GB     2021-09-10 14:20:15
|   |── Domain-Controller        Windows Server 2019      125.67 GB    2021-10-05 11:15:45
```
*Note: Green for standalone VMs and tree structure, yellow for clone VM names*

## 🚀 Getting Started

### Prerequisites

- **Windows Operating System**: Windows 10/11 or Windows Server
- **PowerShell**: PowerShell 5.1 or later (built into Windows)
- **VMware Workstation**: Installed and configured on your system
- **Administrator Rights**: Recommended for full registry access

### Development Dependencies (Optional)

If you plan to contribute to this project or use the automated versioning features:

- **Git**: For version control and accessing the pre-commit hook functionality
- **jq**: JSON processor required for the pre-commit hook (install with `winget install jqlang.jq`)

### Installation

1. **Clone or Download** this repository:
   ```powershell
   git clone https://github.com/MMirabito/VM-Inventroy.git
   cd VM-Inventroy
   ```

2. **No additional dependencies** required - uses built-in PowerShell cmdlets

### Usage

#### Option 1: Run with PowerShell (Recommended)

1. Open PowerShell as Administrator
2. Navigate to the script directory:
   ```powershell
   cd d:\MyProjects\VM-Inventroy
   ```
3. Execute the script:
   ```powershell
   .\VM-Inventory.ps1
   ```

#### Option 2: Run with Batch File

Double-click the `run.cmd` file, or run from Command Prompt:
```cmd
run.cmd
```

The batch file automatically launches PowerShell with the correct execution policy.

### Configuration

The script auto-detects your VMware environment by:
- Reading VMware registry keys
- Scanning the default VM path from `preferences.ini`
- Running from the script's directory

**Default Behavior**:
- Scans the directory where the script is located
- Generates output to console
- Can be customized by modifying the `init` function in the script

## 📁 Project Structure

```
VM-Inventroy/
├── VM-Inventory.ps1        # Main PowerShell script
├── run.cmd                 # Batch launcher for easy execution
├── app-info.json           # Application metadata and build tracking
├── scripts/                # Development tools and Git hooks
│   ├── pre-commit          # Optional Git pre-commit hook
│   └── README.md           # Hook installation guide
├── ARCHITECTURE.md         # Technical documentation
├── LICENSE                 # Apache 2.0 License
└── README.md               # This file
```

## 🔧 Development Features

### Optional: Automated Build Versioning

This project includes an optional Git pre-commit hook that automatically increments the build counter in `app-info.json` with each commit. This provides automatic version tracking for development builds.

**Installation:**
The hook is completely optional. See **[Development Scripts Guide](scripts/README.md)** for detailed installation instructions.

**How it works:**
- Before each commit, the hook reads the current build counter from `app-info.json`
- Increments the counter by 1
- Updates the timestamp to current UTC time
- Stages the updated file for the commit

**Dependencies:**
- **jq**: JSON command-line processor (install with `winget install jqlang.jq`)
- The hook gracefully skips if jq is not available

**For Contributors:**
Installing the hook is completely optional. The project works perfectly without it, but it provides automated versioning for those who want it.

## 🔍 How It Works

1. **Environment Detection**: Reads VMware Workstation installation details from Windows Registry
2. **VM Discovery**: Recursively scans for `.vmx` configuration files
3. **Data Enrichment**: 
   - Parses each `.vmx` file for OS information
   - Calculates folder sizes for each VM
   - Counts snapshots by detecting delta VMDK files and `.vmsd` files
   - Identifies clones by examining VMDK descriptor files
4. **Hierarchy Building**: Constructs parent-child relationships between base VMs and clones
5. **Report Generation**: Displays formatted tables and tree views in the console

## 🛠️ Technical Details

### Functions Overview

- `getVmwareRegByKey`: Retrieves VMware configuration from Windows Registry
- `getVmwareServicesStatus`: Checks status of VMware Windows services
- `getAllVms`: Discovers all `.vmx` files in the scan path
- `getVmInfo`: Extracts detailed information from each VM
- `showVmInfoTable`: Displays VMs in a tabular format
- `showVmHierarchyPretty`: Renders the clone hierarchy tree
- `showVMInfo`: Displays summary statistics

### VM Type Detection

- **Standalone**: Base VMs without parent relationships
- **Clone**: VMs created from another VM (linked or full clone)

### Snapshot Detection

Counts snapshots using two methods:
- Delta VMDK files (e.g., `*-000001.vmdk`)
- Entries in `.vmsd` snapshot descriptor files

## 📝 Version History

- **v1.0.3** (2025-01-01) - Current release
  - Complete inventory functionality
  - Clone hierarchy detection
  - Summary statistics
  - Formatted console output

## 🤝 Contributing

Contributions are welcome! Please feel free to:
- Report bugs or issues
- Suggest new features
- Submit pull requests

## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

### License Summary
- ✅ Commercial use allowed
- ✅ Modification allowed
- ✅ Distribution allowed
- ✅ Patent use allowed
- ℹ️ License and copyright notice required
- ℹ️ State changes required

## ⚠️ Disclaimer

This script is provided "as-is" without any warranties. The author is not responsible for any damage or data loss that may occur from its use. **Use this script at your own risk.**

This tool is read-only and does not modify any VM files or configurations. It only scans and reports information.

## 👤 Authors

- Developer: **Massimo Max Mirabito** GitHub: [@MMirabito](https://github.com/MMirabito)
- AI Assistant: **GitHub Copilot**

## 🙏 Acknowledgments

Portions of this script were developed with the assistance of AI technology to accelerate development, improve code clarity, and reduce manual effort. All final logic, testing, and validation were performed by a human developer.

## 📮 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Review the code comments for detailed implementation notes

## 🔮 Future Enhancements

Potential features for future versions:
- Export to CSV/JSON/HTML formats
- Email report generation
- Multi-path scanning
- VM performance metrics
- Orphaned VMDK detection
- Disk space recommendations
- PowerCLI integration for ESXi environments

---

**Made with ❤️ for VMware Workstation users**
