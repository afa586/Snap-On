<#--------------------------------------------------------------------------------------------------------------------
Author: Tom
Date:2019-04-16
Description:The script is used start bitlocker, if it don't have TPM will use the password defined in $SecureString
-------------------------------------------------------------------------------------------------------------------#>
#Define
$x = Split-Path -Parent $MyInvocation.MyCommand.Definition #get current path
$Log = "$x\Logs\" + $env:computername + ".txt" #set log file address
$PSLog = "$x\Logs\" + $env:computername + "-PS.txt" #set PS log file address
if (!(Test-Path "$x\Logs"))
    {New-Item -Path "$x\Logs" -ItemType Directory -Force}
    
try { Start-Transcript -path $PSLog } catch {}
$EncryptLog = "$x\Logs\EncryptLog.csv" #set encrypted computer log file address
$SecureString = ConvertTo-SecureString "Snapon@2019" -AsPlainText -Force #Define password
$partitions=@('D:') #Define the drive need to encrypt, C drive will be encrypted automatically by default
$TPM = (Get-Tpm).TpmPresent #Check if TPM exist

$ProtectionStatus = (Get-BitLockerVolume -MountPoint C:).ProtectionStatus
$VolumeStatus = (Get-BitLockerVolume -MountPoint C:).VolumeStatus
if ($ProtectionStatus -eq "on" -or $VolumeStatus -eq "EncryptionInProgress")
    {New-Object psobject -Property @{ComputerName = $env:computername;Partition = "C:";Status = $VolumeStatus;Time = Get-Date} |select * |Export-Csv -Path $EncryptLog -Append -NoTypeInformation}
else
    {
    Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector |Out-File $Log
    if (!$TPM)
        {Add-BitLockerKeyProtector -MountPoint "C:" -PasswordProtector -Password $SecureString |Out-File $Log -Append}
    else {manage-bde -protectors -add C: -TPM |Out-File $Log -Append}
    manage-bde.exe -on C: -s -used |Out-File $Log -Append
    }

foreach ($partition in $partitions)
{
    if (Test-Path $partition)
        {
        $ProtectionStatus = (Get-BitLockerVolume -MountPoint $partition).ProtectionStatus
        $VolumeStatus = (Get-BitLockerVolume -MountPoint $partition).VolumeStatus
       if ($ProtectionStatus -eq "on" -or $VolumeStatus -eq "EncryptionInProgress")
            {New-Object psobject -Property @{ComputerName = $env:computername;Partition = $partition;Status = $VolumeStatus;Time = Get-Date} |select * |Export-Csv -Path $EncryptLog -Append -NoTypeInformation}
        else
            {
            Add-BitLockerKeyProtector -MountPoint $partition -RecoveryPasswordProtector |Out-File $Log -Append
            Add-BitLockerKeyProtector -MountPoint $partition -PasswordProtector -Password $SecureString |Out-File $Log -Append
            manage-bde.exe -on $partition -used |Out-File $Log -Append
            manage-bde -autounlock -enable $partition |Out-File $Log -Append
            }
        }
}
try { Stop-Transcript } catch {}



 
