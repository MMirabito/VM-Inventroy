# Git Hooks Setup

This directory contains Git hooks that can be optionally installed to enhance your development workflow.

## Available Hooks

### `pre-commit`
Automatically increments the build counter in `app-info.json` with each commit and updates the timestamp.

**Features:**
- Increments build counter automatically
- Updates timestamp to current UTC time
- Gracefully handles missing dependencies
- Cross-platform compatible (Windows, Linux, macOS)

**Dependencies:**
- **jq** (JSON processor)
  - Windows: `winget install jqlang.jq`
  - macOS: `brew install jq`
  - Linux: `sudo apt install jq` or `sudo yum install jq`

## Quick Setup (Windows)

**Automated Setup (Recommended):**

Just run the setup script - it does everything automatically:

```powershell
.\scripts\setup-hooks.ps1
```

Or double-click: `scripts\setup-hooks.cmd`

The script will:
- Check for jq and install it if needed
- Copy the pre-commit hook to .git/hooks/
- Configure VS Code settings
- Test the hook with a real commit
- Give you clear next steps

**Manual Setup (Alternative):**

If you prefer to do it manually, follow these steps:

1. **Install jq** (if not already installed):
   ```powershell
   winget install jqlang.jq
   ```

2. **Refresh your terminal PATH** (choose one):
   - **Option A**: Close and reopen your terminal
   - **Option B**: Run this command to refresh the current session:
     ```powershell
     $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
     ```

3. **Verify jq is available**:
   ```powershell
   jq --version
   # Should output: jq-1.8.1 (or similar)
   ```

4. **Install the hook**:
   ```powershell
   Copy-Item .\scripts\pre-commit .git\hooks\pre-commit
   ```

5. **Configure VS Code** (optional):
   Add to your VS Code settings.json:
   ```json
   "git.allowNoVerifyCommit": false
   ```

6. **Test it works**:
   ```powershell
   # Make any change and commit
   git add .
   git commit -m "Test pre-commit hook"
   # Should see: Build counter incremented: X → Y
   ```

## Installation

### Option 1: Manual Copy
```bash
# Windows (PowerShell/Command Prompt)
copy scripts\pre-commit .git\hooks\pre-commit

# Linux/macOS
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Option 2: Using Git
```bash
# From repository root
git config core.hooksPath scripts
```

### Option 3: Symbolic Link (Advanced)
```bash
# Linux/macOS
ln -s ../../scripts/pre-commit .git/hooks/pre-commit

# Windows (as Administrator)
mklink .git\hooks\pre-commit ..\..\scripts\pre-commit
```

## Usage

Once installed, the hook runs automatically before each commit:

1. **With jq installed**: Build counter increments automatically
   ```
   Build counter incremented: 15 → 16
   [main abc1234] Your commit message
   ```

2. **Without jq**: Hook skips gracefully with helpful message
   ```
   Info: jq not found. Skipping build counter increment.
         Install jq to enable automatic versioning: winget install jqlang.jq
   [main abc1234] Your commit message
   ```

## Troubleshooting

### Hook Not Running
- Verify hook file exists: `.git/hooks/pre-commit`
- Check execute permissions (Linux/macOS): `chmod +x .git/hooks/pre-commit`
- Ensure no `.sample` extension

### jq Not Found
- Install jq using your package manager
- Verify installation: `jq --version`
- Restart terminal after installation

### Permission Issues
- Windows: Run terminal as Administrator for some installation methods
- Linux/macOS: Ensure execute permissions on hook file

## Uninstalling

To remove the hook:
```bash
rm .git/hooks/pre-commit
```

## For Contributors

If you're contributing to this project:

1. **Optional Setup**: Installing the hook is completely optional
2. **Automatic Versioning**: If installed, your commits will automatically increment the build counter
3. **No Conflicts**: The hook handles missing dependencies gracefully
4. **Team Sync**: Build counters from different contributors will merge without conflicts

The build counter provides a simple way to track development activity and is used in the application's version display.