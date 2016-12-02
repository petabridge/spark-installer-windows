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

$javaHomeVariableName = "JAVA_HOME"
$javaHome = [Environment]::GetEnvironmentVariable($javaHomeVariableName)

$sparkHomeVariableName = "SPARK_HOME"
$sparkHome = [Environment]::GetEnvironmentVariable($sparkHomeVariableName)

$hadoopHomeVariableName = "HADOOP_HOME"
$hadoopHome = [Environment]::GetEnvironmentVariable($hadoopHomeVariableName)

$mobiusHomeVariableName = "SPARKCLR_HOME"
$mobiusHome = [Environment]::GetEnvironmentVariable($mobiusHome)

# Need to be able to reload the PATH of the PowerShell session after any Chocolatey installations
function ReloadPath
{
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Downloads and installs Chocolatey, if necessary.
# `choco` command should be executable after this has finished running.
function GetOrInstallChoco
{
    # Check to see if Chocolatey is installed
    Write-Host "Checking for Chocolatey installation...'n"
    $chocInstallVariableName = "ChocolateyInstall"
    $chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName)
    if ($chocoPath -eq $null -or $chocoPath -eq '') { 
        Write-Host "Chocolatey (https://chocolatey.org/) not detected on this system. Installing...'n"
        (iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))) | Out-Host
        ReloadPath
    }
    else{
        Write-Host "Found Chocolatey at ($chocoPath)"
    }
    return $true
}


# Downloads Chocolatey, if necessary, and uses it to install JDK 8.0.112
function InstallJdk
{
    GetOrInstallChoco

    Write-Host "Executing choco install jdk8 -y 'n"
    choco install jdk8 -y | Out-Host
    ReloadPath
    $rValue = where "javac"
    Write-Host "Installation finished. Installed JDK to ($rValue)'n"
    return $rValue
}





Write-Host "'n'n------------------------ JDK PREREQUISITES ------------------------'n'n"
Write-Host "Checking for JDK 8.0 installation...'n"
if($javaHome -eq $null -or $javaHome -eq ''){
    Write-Host "JAVA_HOME environment not detected on this system.'n"
    Write-Host "Scanning file system for JDK8 installation.'n"
    $javaHome = where "javac"
    if($javaHome -eq $null -or $javaHome -eq '' -or $javaHome -contains "Could not find files"){
        Write-Host "Unable to find JDK installation on this system'n"
        Write-Host "Beginning JDK 8.0 installation...'n"
        $javaHome = InstallJdk

        [Environment]::SetEnvironmentVariable($javaHomeVariableName, $javaHome, 'machine')
        Write-Host "Set ($javaHomeVariableName) to ($javaHome)'n"
        
    }
    else{
        Write-Host "Found JDK at ($javaHome)"
        Write-Host "Checking Java Versiion"
    }   
    
}