$ErrorActionPreference = 'Stop'; # stop on all errors

$packageName= 'apache-spark' # arbitrary name for the package, used in messages
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileLocation = Join-Path $toolsDir 'install-spark1.6.2.ps1'

Start-ChocolateyProcessAsAdmin "& `'$fileLocation`'"