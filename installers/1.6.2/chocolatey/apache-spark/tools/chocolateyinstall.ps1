$ErrorActionPreference = 'Stop'; # stop on all errors

$packageName= 'apache-spark' # arbitrary name for the package, used in messages
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$psFile = Join-Path $toolsDir 'install-spark1.6.2.ps1'

Install-ChocolateyPowershellCommand -PackageName 'install-spark1.6.2.powershell' -PSFileFullPath $psFile
Invoke-Expression -Command 'install-spark1.6.2'