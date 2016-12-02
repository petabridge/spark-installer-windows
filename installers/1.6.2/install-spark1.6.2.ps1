#
# Copyright (c) Petabridge, LLC
# Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.
#

# First, need to make sure we're running in adminstrator mode or all hell will break loose
$currentUser = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
& {
    if (!$currentUser.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ))
    {
        (Get-Host).UI.RawUI.Backgroundcolor="DarkRed"
        Clear-Host
        Write-Host "Error: Must run this script as an Administrator.`n"
        Write-Host "Please restart this command prompt with elevated permissions before continuing.`n"
        Exit
    }
    else{
          (Get-Host).UI.RawUI.Backgroundcolor="Black"
          Clear-Host
          Write-Host "Starting Installation of Spark 1.6.2 onto your machine.'n"
          Write-Host "This script does not support weird stuff like corporate firewalls and proxies.'n"
          Write-Host "This may take a few minutes.'n"
    }
}

# Time to check environment variables. If there's a previous installation of Spark, Mobius, JDK, or Hadoop we should
# stop and ask the end-user for permission to reset each one individually.

# Check to see if Chocolatey is installed
$chocInstallVariableName = "ChocolateyInstall"
$chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName)
