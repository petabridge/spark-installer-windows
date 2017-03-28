$ErrorActionPreference = 'Stop'; # stop on all errors

$packageName= 'apache-spark' # arbitrary name for the package, used in messages
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://raw.githubusercontent.com/petabridge/spark-installer-windows/master/installers/1.6.2/install-spark1.6.2.ps1'
$fileLocation = Join-Path $toolsDir 'install-spark1.6.2.ps1'

Get-ChocolateyWebFile $packageName $fileLocation $url
Start-ChocolateyProcessAsAdmin "& `'$fileLocation`'"