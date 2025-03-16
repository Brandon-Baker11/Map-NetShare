# Map-NetShare
This is a tool that I wrote in PowerShell that will map a network share drive to a remote computer.

## Technologies Used
- PowerShell

## Operating Systems Used
- Windows 11 Enterprise (23H2)

## How it works
The Map-NetShare function automates network drive mapping based on a user's email address. It retrieves the user's logon name from Active Directory (AD), then identifies the groups they belong to, filtering for those with network share addresses. The relevant group names and share paths are stored in an array for easy reference.

The technician is then prompted to select the network shares to be mapped. The selected paths are written to a paths.txt file, which is out-filed to the target user's computer. Along with this, a batch script responsible for executing the actual drive mappings (MapShares.bat) is copied to the target computer.

To ensure the script runs as the target user, a scheduled task is created on the remote machine. The task is triggered by a specific event ID and runs under the user's context. Once the drives are mapped, the task is automatically deleted, and the temporary files (MapShares.bat and paths.txt) are removed from the system.
