$ErrorActionPreference = 'Stop'; # stop on all errors

$packageName= 'apache-spark' # arbitrary name for the package, used in messages
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$psFile = Join-Path $toolsDir 'install-spark1.6.2.ps1'

Install-ChocolateyPowershellCommand -PackageName 'install-spark1.6.2.powershell' -PSFileFullPath $psFile
Invoke-Expression -Command 'install-spark1.6.2'

# unzip mobius here because Expand-Archive isn't available in Chocolatey CI environment
# and this is where we know Get-ChocolateyUnzip is available for us
$mobiusInstallFolder = "C:\Mobius"
$output = [IO.Path]::Combine($mobiusInstallFolder, "spark-clr_2.10-1.6.200.zip")
$sparkVersion = "1.6.2"
$targetDir = [IO.Path]::Combine($mobiusInstallFolder, "spark-clr-$sparkVersion")
Get-ChocolateyUnzip -FileFullPath $output -Destination $targetDir