#
# Copyright (c) Petabridge, LLC
# Licensed under the Apache 2.0 license. See LICENSE file in the project root for full license information.
#
Param(
    [string]$hadoopInstallFolder = "C:\Hadoop",
    [string]$sparkInstallFolder = "C:\Spark",
    [string]$mobiusInstallFolder = "C:\Mobius"
)

$hadoopVersion = "2.6"
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

# Load IO.Compression.FileSystem for unzip capabilities
Add-Type -assembly "system.io.compression.filesystem"

# Create tools directory
# Going to need it for our un-taring utility primarily
$scriptDir = (Get-Item -Path ".\" -Verbose).FullName
$toolsDir = [IO.Path]::Combine($scriptDir, "tools")
$tarToolExe = [IO.Path]::Combine($toolsDir, "TarTool.exe")


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


# Downloads internal binaries needed for things like un-TARing files
# and allowing Hadoop to work
function DownloadInternalTools(){
     # create the /tools directory off the PWD
    if(!(Test-Path $toolsDir)){
        Write-Host "Creating $toolsDir"
        New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    }
    else{
        Write-Host "$toolsDir already exists."
    }

     # TarTool
    $tarToolExe = "$toolsDir\TarTool.exe"
    if (!(Test-Path $tarToolExe))
    {
        Write-Host "Downloading TarTool.exe for untarring Spark / Hadoop binaries"
        $url = "http://download-codeplex.sec.s-msft.com/Download/Release?ProjectName=tartool&DownloadId=79064&FileTime=128946542158770000&Build=21031"
        $output="$toolsDir\TarTool.zip"
        Download-File $url $output
        Expand-Archive $output -DestinationPath $toolsDir -Force
    }
    else
    {
        Write-Output "$tarToolExe exists already. No download and extraction needed"
    }
}

# This method was developed by the Microsoft team working on the Mobius project.
# See the original source here: https://github.com/Microsoft/Mobius/blob/6e2b820524c8184b19d2650094480c7c3ae0229c/build/localmode/downloadtools.ps1
function Untar-File($tarFile, $targetDir)
{
    Write-Host "Using $tarToolExe for .tar.gz extraction.`n"
    if (!(test-path $tarFile))
    {
        Write-Output "[Untar-File] WARNING!!! $tarFile does not exist. Abort."
        return
    }

    if (!(test-path $targetDir))
    {
        Write-Output "[Untar-File] $targetDir does not exist. Creating ..."
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Write-Output "[Untar-File] Created $targetDir."
    }

    $start_time = Get-Date

    Write-Output "[Untar-File] Extracting $tarFile to $targetDir ..."
    Invoke-Expression "& `"$tarToolExe`" $tarFile $targetDir"
    
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

    Write-Output "[Untar-File] Extraction completed. Time taken: $howlong"
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

    try{
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
    finally{
        # need to cleanup event handlers no matter what
        Unregister-Event -SourceIdentifier Web.DownloadFileCompleted
        Unregister-Event -SourceIdentifier Web.DownloadProgressChanged
    }        
}




Write-Host "`n`n------------------------ JDK PREREQUISITES ------------------------`n`n"
Write-Host "Checking for JDK 8.0 installation..."


function GetJdkHomeDirectory([string]$javacExeLocation){
    return [IO.Directory]::GetParent(([IO.Path]::GetDirectoryName($javacExeLocation)))
}

# Downloads Chocolatey, if necessary, and uses it to install JDK 8.0.112
function InstallJdk
{
    GetOrInstallChoco

    Write-Host "Executing choco install jdk8 -y `n"
    choco install jdk8 -y | Out-Host
    ReloadPath
    $rValue =  FindCommandOnPath("javac")
    Write-Host "Installation finished. Installed JDK to ($rValue)"
    return GetJdkHomeDirectory($rValue)
}

if($javaHome -eq $null -or $javaHome -eq ''){
    Write-Host "$javaHomeVariableName environment not detected on this system."
    Write-Host "Scanning file system for JDK8 installation."

    $javaHome = GetJdkHomeDirectory(FindCommandOnPath("javac"))

    
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
    Write-Host "$hadoopHomeVariableName environment not detected on this system.`n"
    Write-Host "Checking for tools...`n"
    DownloadInternalTools

    # Create high-level Hadoop folder
    if(!(Test-Path $hadoopInstallFolder)){
        Write-Host "$hadoopInstallFolder does not exist. Creating..."
        New-Item -ItemType Directory -Force -Path $hadoopInstallFolder | Out-Null
    } else{
        Write-Host "$hadoopInstallFolder already exists."
    }

    <#
    # Download the Hadoop distribution from Apache    
    $url = "http://apache.claz.org/hadoop/core/hadoop-2.6.5/hadoop-2.6.5.tar.gz"
    $output = [IO.Path]::Combine($hadoopInstallFolder, "hadoop-2.6.5.tar.gz")
    $targetDir = [IO.Path]::Combine($hadoopInstallFolder)
    Write-Host "Downloading official Hadoop 2.6* solution from $url to $output"
    Download-File $url $output
    Untar-File $output $targetDir
    #>
    
    $hadoopHome = [IO.Path]::Combine($hadoopInstallFolder, "hadoop-2.6.5")
    New-Item -ItemType Directory -Force -Path $hadoopHome | Out-Null

    $hadoopBinFolder = [IO.Path]::Combine($hadoopHome, "bin")
    New-Item -ItemType Directory -Force -Path $hadoopBinFolder | Out-Null

    [Environment]::SetEnvironmentVariable($hadoopHomeVariableName, $hadoopHome, 'machine')
    Write-Host "Set ($hadoopHomeVariableName) to ($hadoopHome)"

    $winutilsExe = [IO.Path]::Combine($hadoopHome, "bin", "winutils.exe")
    if (!(Test-Path $winutilsExe))
    {
        Write-Host "Downloading Hadoop winutils.exe (needed for Windows interop)"
        $url = "https://github.com/MobiusForSpark/winutils/blob/master/hadoop-2.6.0/bin/winutils.exe?raw=true"
        $output=$winutilsExe
        Download-File $url $output
    }
    else{
        Write-Host "Found $winutilsExe. Skipping download.`n"
    }

}else{
    Write-Host "Found Hadoop binaries at $hadoopHome ."
    Write-Host "Please ensure that they are Hadoop version $hadoopVersion and that this guide has been followed for Windows."
    Write-Host "https://wiki.apache.org/hadoop/WindowsProblems .`n"
}

Write-Host "`n`n------------------------ SPARK PREREQUISITES ------------------------`n`n"
Write-Host "Checking for Spark installation..."
if($sparkHome -eq $null -or $sparkHome -eq ''){
    Write-Host "$sparkHomeEnvironmentVariableName environment not detected on this system.`n"
    Write-Host "Checking for tools...`n"
    DownloadInternalTools

    # Create high-level Spark folder
    if(!(Test-Path $sparkInstallFolder)){
        Write-Host "$sparkInstallFolder does not exist. Creating..."
        New-Item -ItemType Directory -Force -Path $sparkInstallFolder | Out-Null
    } else{
        Write-Host "$sparkInstallFolder already exists."
    }

    # Download the Spark distribution from Apache    
    $url = "http://archive.apache.org/dist/spark/spark-1.6.2/spark-1.6.2-bin-hadoop2.6.tgz"
    $output = [IO.Path]::Combine($sparkInstallFolder, "spark-$sparkVersion-bin-hadoop$hadoopVersion.tgz")
    $targetDir = $sparkInstallFolder
    Write-Host "Downloading official Spark $sparkVersion solution from $url to $output"
    Download-File $url $output
    Untar-File $output $targetDir
    
    $sparkHome = [IO.Path]::Combine($sparkInstallFolder, "spark-$sparkVersion-bin-hadoop$hadoopVersion")
    [Environment]::SetEnvironmentVariable($sparkHomeVariableName, $sparkHome, 'machine')
    Write-Host "Set ($sparkHomeVariableName) to ($sparkHome)"

}else{
    Write-Host "Found Spark binaries at $sparkHome ."
}

Write-Host "`n`n------------------------ MOBIUS PREREQUISITES ------------------------`n`n"
Write-Host "Checking for Mobius (Spark CLR) installation..."
if($mobiusHome -eq $null -or $mobiusHome -eq ''){
    Write-Host "$mobiusHomeEnvironmentVariableName environment not detected on this system.`n"
    Write-Host "Installing..."

    # Create high-level Mobius folder
    if(!(Test-Path $mobiusInstallFolder)){
        Write-Host "$mobiusInstallFolder does not exist. Creating..."
        New-Item -ItemType Directory -Force -Path $mobiusInstallFolder | Out-Null
    } else{
        Write-Host "$mobiusInstallFolder already exists."
    }

    # Download Mobius 1.6.2 release from Github
    $url = "https://github.com/Microsoft/Mobius/releases/download/v1.6.200/spark-clr_2.10-1.6.200.zip"
    $output = [IO.Path]::Combine($mobiusInstallFolder, "spark-clr_2.10-1.6.200.zip")
    Write-Host "Downloading official Mobius $sparkVersion distribution from Github..."
    Download-File $url $output
    $targetDir = [IO.Path]::Combine($mobiusInstallFolder, "spark-clr-$sparkVersion")
    Expand-Archive $output -DestinationPath $targetDir -Force

    $mobiusHome = [IO.Path]::Combine($targetDir, "runtime") # set the runtime folder as the home for Mobius
    [Environment]::SetEnvironmentVariable($mobiusHomeVariableName, $mobiuskHome, 'machine')
    Write-Host "Set ($mobiusHomeVariableName) to ($mobiusHome)"

} else{
    Write-Host "Found Mobius binaries at $mobiusHome.`n"
}

Write-Host "Installation complete.`n"
Write-Host "Warning: RELOAD this shell or launch a new one so the new environment variables get picked up.`n"
Write-Host "You should now be able to execute any Spark command by executing the files in $sparkHome\bin or $mobiusHome\bin.`n"