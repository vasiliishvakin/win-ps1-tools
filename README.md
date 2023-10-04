# Powershell tools for windows

## Description
 - add-user.ps1: Add a user to the local machine, add it to groups from config and create directories sceleton from config
   - add-user.json: Config file for add-user.ps1
 - set-folders.ps1: Redirect user windows folders to another locations from config
   - set-folders.json: Config file for set-folders.ps1
 - software-install.ps1: Download and run software installers from config
   - software-install.json: Config file for software-install.ps1


## Usage
before using scripts you need allow execution of unsigned scripts:
```powershell
Set-ExecutionPolicy RemoteSigned
```
