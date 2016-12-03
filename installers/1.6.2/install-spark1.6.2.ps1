#
# Copyright (c) Petabridge, LLC
# Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.
#
Param(
    [string]$hadoopInstallFolder = "C:\Hadoop",
    [string]$sparkInstallFolder = "C:\Spark",
    [string]$mobiusInstallFolder = "C:\Mobius",
    [string]$apacheArchiveServer = "archive.apache.org"
)

$hadoopVersion = "2.6.0"
$sparkVersion = "1.6.2"
$versionRegex = [regex]"\b(?:(\d+)\.)?(?:(\d+)\.)?(\*|\d+)\b" # Regex for version numbers

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
          Write-Host "Starting Installation of Spark ($sparkVersion) onto your machine.`n"
          Write-Host "This script does not support weird stuff like corporate firewalls and proxies.`n"
          Write-Host "This may take a few minutes.`n"
    }
}

# Need to be able to reload the PATH of the PowerShell session after any Chocolatey installations
function ReloadPath
{
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}
ReloadPath

# Create tools directory
# Going to need it for our un-taring utility primarily
$scriptDir = Get-ScriptDirectory
$toolsDir = "$scriptDir\tools"


# Time to check environment variables. If there's a previous installation of Spark, Mobius, JDK, or Hadoop we should
# stop and ask the end-user for permission to reset each one individually.


$javaHomeVariableName = "JAVA_HOME"
$minSupportedJdkVersion = "1.8"
$javaHome = [Environment]::GetEnvironmentVariable($javaHomeVariableName)

$sparkHomeVariableName = "SPARK_HOME"
$sparkHome = [Environment]::GetEnvironmentVariable($sparkHomeVariableName)

$hadoopHomeVariableName = "HADOOP_HOME"
$hadoopHome = [Environment]::GetEnvironmentVariable($hadoopHomeVariableName)

$mobiusHomeVariableName = "SPARKCLR_HOME"
$mobiusHome = [Environment]::GetEnvironmentVariable($mobiusHome)



# Uses the "where" command in batch to find a binary that matches a given command name
# Useful for finding items that have been installed to the PATH, but don't have an
# Environment variable set, such as JAVA_HOME
function FindCommandOnPath([string]$p){
    Try{
        return (cmd.exe /c where $p)
    }
    Catch{
        Write-Host "Couldn't find ($p) in PATH."
        return $null
    }
}

# Downloads and installs Chocolatey, if necessary.
# `choco` command should be executable after this has finished running.
function GetOrInstallChoco
{
    # Check to see if Chocolatey is installed
    Write-Host "Checking for Chocolatey installation...`n"
    Try{
        $chocInstallVariableName = "ChocolateyInstall"
        $chocoPath = [Environment]::GetEnvironmentVariable($chocInstallVariableName)
        if ($chocoPath -eq $null -or $chocoPath -eq '') { 
            Write-Host "Chocolatey (https://chocolatey.org/) not detected on this system. Installing...`n"
            (iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))) | Out-Host
            ReloadPath
        }
        else{
            Write-Host "Found Chocolatey at ($chocoPath)"
        }
    }
    Catch{
        Write-Host "Failed to install Chocolatey. Reason: ($_.Exception.Message).`n"
        Exit
    }
    return $true
}


# Downloads Chocolatey, if necessary, and uses it to install JDK 8.0.112
function InstallJdk
{
    GetOrInstallChoco

    Write-Host "Executing choco install jdk8 -y `n"
    choco install jdk8 -y | Out-Host
    ReloadPath
    $rValue = FindCommandOnPath("javac")
    Write-Host "Installation finished. Installed JDK to ($rValue)"
    return $rValue
}

# This method was developed by the Microsoft team working on the Mobius project.
# See the original source here: https://github.com/Microsoft/Mobius/blob/6e2b820524c8184b19d2650094480c7c3ae0229c/build/localmode/downloadtools.ps1
function Download-File($url, $output)
{
    $output = [System.IO.Path]::GetFullPath($output)
    if (test-path $output)
    {
        if ((Get-Item $output).Length -gt 0)
        {
            Write-Output "[Download-File] $output exists. No need to download."
            return
        }
        else
        {
            Write-Output "[Download-File] [WARNING] $output exists but is empty. We need to download a new copy of the file."
            Remove-Item $output
        }
    }

    $start_time = Get-Date
    $wc = New-Object System.Net.WebClient
    Write-Output "[Download-File] Start downloading $url to $output ..."
    $Global:downloadComplete = $false
    Register-ObjectEvent -InputObject $wc -EventName DownloadFileCompleted `
        -SourceIdentifier Web.DownloadFileCompleted -Action {
        $Global:downloadComplete = $True
    }
    Register-ObjectEvent -InputObject $wc  -EventName DownloadProgressChanged `
        -SourceIdentifier Web.DownloadProgressChanged -Action {
        $Global:Data = $event
    }
    
    $tmpOutput = $output + ".tmp.download"
    if (test-path $tmpOutput) {
        Remove-Item $tmpOutput
    }
    
    $wc.DownloadFileAsync($url, $tmpOutput)
    While (!($Global:downloadComplete)) {
        $percent = $Global:Data.SourceArgs.ProgressPercentage
        $totalBytes = $Global:Data.SourceArgs.TotalBytesToReceive
        $receivedBytes = $Global:Data.SourceArgs.BytesReceived
        If ($percent -ne $null) {
            Write-Progress -Activity ("Downloading file to {0} from {1}" -f $output,$url) -Status ("{0} bytes \ {1} bytes" -f $receivedBytes,$totalBytes)  -PercentComplete $percent
        }
    }
    
    Rename-Item $tmpOutput -NewName $output
    Write-Progress -Activity ("Downloading file to {0} from {1}" -f $output, $url) -Status ("{0} bytes \ {1} bytes" -f $receivedBytes,$totalBytes)  -Completed
    Unregister-Event -SourceIdentifier Web.DownloadFileCompleted
    Unregister-Event -SourceIdentifier Web.DownloadProgressChanged
    $duration = $(Get-Date).Subtract($start_time)
    if ($duration.Seconds -lt 2)
    {
        $mills = $duration.MilliSeconds
        $howlong = "$mills milliseconds"
    }
    else
    {
        $seconds = $duration.Seconds
        $howlong = "$seconds seconds"
    }

    Write-Output "[downloadtools.Download-File] Download completed. Time taken: $howlong"
    
    if ( !(test-path $output) -or (Get-Item $output).Length -eq 0)
    {
        throw [System.IO.FileNotFoundException] "Failed to download file $output from $url"
    }
}

# This method was developed by the Microsoft team working on the Mobius project.
# See the original source here: https://github.com/Microsoft/Mobius/blob/6e2b820524c8184b19d2650094480c7c3ae0229c/build/localmode/downloadtools.ps1
function Unzip-File($zipFile, $targetDir)
{
    if (!(test-path $zipFile))
    {
        Write-Output "[downloadtools.Unzip-File] WARNING!!! $zipFile does not exist. Abort."
        return
    }

    if (!(test-path $targetDir))
    {
        Write-Output "[downloadtools.Unzip-File] $targetDir does not exist. Creating ..."
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Write-Output "[downloadtools.Unzip-File] Created $targetDir."
    }

    $start_time = Get-Date
    Write-Output "[downloadtools.Unzip-File] Extracting $zipFile to $targetDir ..."
    $entries = [IO.Compression.ZipFile]::OpenRead($zipFile).Entries
    $entries | 
        %{
            #compose some target path
            $targetpath = join-path "$targetDir" $_.FullName
            #extract the file (and overwrite)
            [IO.Compression.ZipFileExtensions]::ExtractToFile($_, $targetpath, $true)
        }
    
    $duration = $(Get-Date).Subtract($start_time)
    if ($duration.Seconds -lt 2)
    {
        $mills = $duration.MilliSeconds
        $howlong = "$mills milliseconds"
    }
    else
    {
        $seconds = $duration.Seconds
        $howlong = "$seconds seconds"
    }

    Write-Output "[downloadtools.Unzip-File] Extraction completed. Time taken: $howlong"
}




Write-Host "`n`n------------------------ JDK PREREQUISITES ------------------------`n`n"
Write-Host "Checking for JDK 8.0 installation..."
if($javaHome -eq $null -or $javaHome -eq ''){
    Write-Host "$javaHomeVariableName environment not detected on this system."
    Write-Host "Scanning file system for JDK8 installation."

    $javaHome = FindCommandOnPath("javac")

    
    if($javaHome -eq $null -or $javaHome -eq '' -or $javaHome -contains "Could not find files.`n"){
        Write-Host "Unable to find JDK installation on this system.`n"
        Write-Host "Beginning JDK 8.0 installation...`n"
        $javaHome = InstallJdk
    }

    [Environment]::SetEnvironmentVariable($javaHomeVariableName, $javaHome, 'machine')
    Write-Host "Set ($javaHomeVariableName) to ($javaHome)"
}

Write-Host "Found JDK at ($javaHome)`n"
Write-Host "Checking Java Version`n"

# For some reason, Java write to STDERR insted of STDOUT, so we have to redirect
$jvmVersion = (cmd.exe /c "javac -version" 2>&1) | Out-String
$jvmVersion = $versionRegex.Match($jvmVersion).Groups[0].Value
Write-Host "Found JDK version ($jvmVersion).`n"
if($jvmVersion -ccontains $minSupportedJdkVersion){
    Write-Host "This version of JDK is compatible with Spark ($sparkVersion).`n"
}
else{
    Write-Host "This version of the JDK is not compatible with ($sparkVersion).`n"
    Write-Host "Please upgrade manually to at least JDK ($minSupportedJdkVersion) or uninstall it and re-run this script.`n"
    Exit
}

Write-Host "`n`n------------------------ HADOOP PREREQUISITES ------------------------`n`n"
Write-Host "Checking for Hadoop installation..."
if($hadoopHome -eq $null -or $hadoopHome -eq ''){
    Write-Host "$hadoopHomeVariableName environment not detected on this system."
}