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

## 📊 Sample Output

The script provides multiple views of your VM inventory:

### Summary Information
```
Total VMs        : 15
Total Snapshots  : 23
Total Size       : 245.67 GB  (251,567.89 MB)
```

### Detailed Table View
Lists all VMs with columns for Name, Type, Parent, Snapshots, Path, OS, Size, and Creation Date

### Hierarchical Tree View
```
+-- Windows10-Base          Windows 10 x64    45.23 GB    2024-06-15 14:30:22
|   |-- Dev-Clone1          Windows 10 x64    12.45 GB    2024-08-20 09:15:33
|   |-- Test-Clone2         Windows 10 x64    8.92 GB     2024-09-01 16:42:10
```

## 🚀 Getting Started

### Prerequisites

- **Windows Operating System**: Windows 10/11 or Windows Server
- **PowerShell**: PowerShell 5.1 or later (built into Windows)
- **VMware Workstation**: Installed and configured on your system
- **Administrator Rights**: Recommended for full registry access

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
├── VM-Inventory.ps1    # Main PowerShell script
├── run.cmd             # Batch launcher for easy execution
├── LICENSE             # Apache 2.0 License
└── README.md           # This file
```

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

## 👤 Author

**Massimo Max Mirabito**

## 🙏 Acknowledgments

Portions of this script were developed with the assistance of AI technology to accelerate development, improve code clarity, and reduce manual effort. All final logic, testing, and validation were performed by a human operator.

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
