<#--------------------------------------------------------------------------------------------------------------
Description: The script is used to check software list which installed on the computer
Author: Tom
Date: 2018-12-11
----------------------------------------------------------------------------------------------------------------#>
#Define
$reportname=$env:computername+'-'+$env:username
$report=(Split-Path -Parent $MyInvocation.MyCommand.Definition)+"\reports\$reportname.csv"
if (!(Test-Path $report))
    {New-Item -Path $report -ItemType Directory -Force

#Check software installed


$InstalledSoftware = (Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ | Get-ItemProperty)
$InstalledSoftware += (Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ | Get-ItemProperty)

IF (Test-path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\) 
{$InstalledSoftware += (Get-ChildItem HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\ | Get-ItemProperty) }
$InstalledSoftware | Where {$_.DisplayName -ne $Null -AND $_.SystemComponent -ne "1" -AND $_.ParentKeyName -eq $Null}|
Sort-Object -Property DisplayName -Unique |Select-Object DisplayName,DisplayVersion,InstallDate,@{n='Computername';e={$env:computername}} |
Export-Csv -Path $report -Encoding UTF8 -NoTypeInformation
