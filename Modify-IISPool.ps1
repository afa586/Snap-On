<#####################################################################################################
The script is used to modify password for IIS pool
Author: Tom
Date: 2022-03-23
######################################################################################################>


###Define
$Account = "SNAPONGLOBAL\epicorserv"
$x = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ListReport = "$x\Reports\ListReport.csv"
$ChangeReport = "$x\Reports\ChangeReport.csv"
#$Servers = @("kunsw16rpts1.snaponglobal.com","shanw12apps1.snaponglobal.com","shanw16apps1.snaponglobal.com","singw16apps1.snaponglobal.com","singw16apps2.snaponglobal.com")
$Servers = Get-Content "$x\Servers.txt"
if (!(Test-Path "$x\Reports"))
    {New-Item -Path "$x\Reports" -ItemType Directory -Force}
$Guide =
@"
To use the script you need type in server list in servers.txt first

To list all application pools which run as the account:
Type in account name in account text box-->click List button

To change password:
Type in account name-->Type in password-->Click Change button

"@


###Function to list IIS pool#########################
Function List
{
$Account = ($TextBox2.text).trim()
$Results = @()
$ScriptBlock =
{
Import-Module WebAdministration
Get-ItemProperty IIS:\AppPools\* "ProcessModel" |?{$_.username -like "*$Using:Account*"} |select @{n = 'IISPoolName';e= {$_.PSChildName}},userName,password
}
    foreach ($Server in $Servers)
    {
    $Results += Invoke-Command -ComputerName $Server -ScriptBlock $ScriptBlock
    }
$TextBox1.Text = $Results|select PSComputerName,IISPoolName,userName,password |Out-String
$Results |select PSComputerName,IISPoolName,userName |Export-Csv -Path $ListReport -NoTypeInformation
$TextBox1.Text += "You can find the report in $ListReport"
}

###Function to change IIS pool##############################
Function Change
{
$Password = ($TextBox3.Text).Trim()
if (!$Password)
    {[System.Windows.Forms.MessageBox]::Show("Please type in a password first!")}
else
    {
    $Results = @()
    $ScriptBlock =
    {
    Import-Module WebAdministration
    Get-ItemProperty IIS:\AppPools\* "ProcessModel" |?{$_.username -like "*$Using:Account*"} |select @{n = 'IISPoolName';e= {$_.PSChildName}},userName
    }
        foreach ($Server in $Servers)
        {
        $ApplicationPools = Invoke-Command -ComputerName $Server -ScriptBlock $ScriptBlock
            foreach ($ApplicationPool in $ApplicationPools)
            {
             $Block = {
             $PoolName = $Using:ApplicationPool.IISPoolName
             Import-Module WebAdministration
             Set-ItemProperty "IIS:\AppPools\$PoolName" -name processModel -value @{userName=$Using:Account;password=$Using:Password;identitytype=3}
             }
                try
                {
                Invoke-Command -ComputerName $Server -ScriptBlock $Block -ErrorAction Stop
                $Status = "Successful"
                }
                catch {$Status = "Failed $_"}  #Show error message when error happen
             $Results += $ApplicationPool | select PsComputername,IISPoolName,@{n="Result";e={$Status}}   
            }
        }
    $TextBox1.Text = $Results |Out-String
    $Results | Export-Csv -Path $ChangeReport -NoTypeInformation
    $TextBox1.Text += "You can find the report in $ChangeReport"
    }
}


###Main Windows Form Start#################################################################################

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = New-Object System.Drawing.Point(800,400)
$Form.text                       = "Change IIS Application Pool"
$Form.TopMost                    = $false

$Panel1                          = New-Object system.Windows.Forms.Panel
$Panel1.height                   = 300
$Panel1.width                    = 780
$Panel1.location                 = New-Object System.Drawing.Point(5,5)

$Panel2                          = New-Object system.Windows.Forms.Panel
$Panel2.height                   = 50
$Panel2.width                    = 780
$Panel2.location                 = New-Object System.Drawing.Point(5,330)


###Create TextBox###
$TextBox1                       = New-Object System.Windows.Forms.TextBox
$TextBox1.location              = New-Object System.Drawing.Point(10,10)
$TextBox1.Font                  = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
$TextBox1.width                 = 750
$TextBox1.Multiline             = $true
$TextBox1.Height                = 280
$TextBox1.ScrollBars            = "Vertical" 
$TextBox1.Text                  = $Guide

$TextBox2                       = New-Object System.Windows.Forms.TextBox
$TextBox2.location              = New-Object System.Drawing.Point(50,10)
$TextBox2.Font                  = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$TextBox2.width                 = 160
$TextBox2.Text                  = $Account

$TextBox3                       = New-Object System.Windows.Forms.TextBox
$TextBox3.location              = New-Object System.Drawing.Point(300,10)
$TextBox3.Font                  = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$TextBox3.width                 = 180

###Create Labels###
$Label1                         = New-Object System.Windows.Forms.Label
$Label1.location                = New-Object System.Drawing.Point(5,10)
$Label1.Font                    = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$Label1.Text                    = "Account:"

$Label2                         = New-Object System.Windows.Forms.Label
$Label2.location                = New-Object System.Drawing.Point(250,10)
$Label2.Font                    = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$Label2.Text                    = "Password:"



###Create Buttons###
$Button1                         = New-Object system.Windows.Forms.Button
$Button1.text                    = "List"
$Button1.width                   = 60
#$Button1.height                  = 20
$Button1.location                = New-Object System.Drawing.Point(580,10)
$Button1.Font                    = New-Object System.Drawing.Font('Microsoft Sans Serif',7)

$Button2                         = New-Object system.Windows.Forms.Button
$Button2.text                    = "Change"
$Button2.width                   = 60
#$Button2.height                  = 20
$Button2.location                = New-Object System.Drawing.Point(650,10)
$Button2.Font                    = New-Object System.Drawing.Font('Microsoft Sans Serif',7)


$Form.controls.AddRange(@($Panel1,$Panel2))
$Panel1.controls.AddRange($TextBox1)
$Panel2.controls.AddRange(@($TextBox2,$TextBox3,$Button1,$Button2,$Label1,$Label2))



$Panel1.BorderStyle              = 'Fixed3D'
$Panel2.BorderStyle              = 'Fixed3D'


$Button1.Add_Click({List }) # List
$Button2.Add_Click({Change }) # Change


              

$Form.Add_Shown({$Form.Activate()})
[void] $Form.ShowDialog()

###Main Windows Form End#################################################################################