<#------------------------------------------------------------------------------------------------------
Author: Tom
Date: 2020-12-15
Description: The script is used to monitor network
--------------------------------------------------------------------------------------------------------#>

#Define

$Path = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Serverlist = "$Path\list.csv"
$Servers = Import-Csv $serverlist



###Block to monitor network###

$ScriptBlock =
{

Param($Server,$Path,$Serverlist)
    $smtpserver = 'Type in SMTP server here'
    $From = 'MonitorAsiaIT@tom.com'
    $Historyfolder = "$Path\History\$Server"
    if (Test-Path $Historyfolder) {Write-Host "History folder exist"}
    else {New-Item -Path $Historyfolder -ItemType Directory -Force}
    $db='http://10.145.204.47:8086/write?db=snapon' #Type in influxdb address here
    $Loststatus0 = "Good"
    $Latencystatus0 = "Good"
    $Networkstatus0 = "Good"
    $Losts = @(0,0,0,0,0) #Use to caculate average lost in 5 times
    $i = 0

While ($true)
    {
    if ($i -eq 4)
    {$i = 0}
    else {$i += 1}
    $Currentserver = Import-Csv $serverlist |?{$_.Address -eq $Server}
    $Receiver = $Currentserver.Receiver -split " "
    $Description = $Currentserver.Description
    $Source = $Currentserver.Source
    if ($env:computername -ne "kunsw16logs1") {$Logs = $Historyfolder}
    $LostAlert = $Currentserver.LostAlert  #Alert for package lost
    $LatencyAlert = $Currentserver.LatencyAlert #Alert for average latency
    $Count = $Currentserver.PingCount
    $Date = Get-Date -Format "yyyy-MM-dd" 
    $Historylog =  "$Path\History\$Server\$Date-$Server.csv"  
    $Testresult = Test-Connection $server -Count $Count -ErrorAction SilentlyContinue |Measure-Object ResponseTime -Average
    $Lost = ($Count - ($Testresult.Count))*100/$Count
    $Losts[$i] = $Lost
    $LostA = ($Losts |Measure-Object -Average).Average
    $CountA = 5*($Count)

    $Average = $Testresult.Average
    $Average1 = '{0:N2}' -f $Average
    New-Object PSObject -Property @{Time = Get-Date;Lost = $Lost;Latency = $Average;LostA = $LostA} |Export-Csv -Path $Historylog -Append -NoTypeInformation #Archive history
    #1 |select @{n = "Time";e = {Get-Date}},@{n = "Lost";e = {$Lost}},@{n = "Latency";e = {$Average}} |Export-Csv -Path $Historylog -Append -NoTypeInformation #Archive history
    $body="Network-$Source,Hostname=$server Average=$Average" 
    #$body
    Invoke-WebRequest $db -Method POST -Body $body >$Null #Upload to Grafana
    $body="Network-$Source,Hostname=$server Lost=$Lost"
    #$body
    Invoke-WebRequest $db -Method POST -Body $body >$Null #Upload to Grafana

    if ($LostA -le $LostAlert) 
    {
    $Loststatus = "Good"
    $LostAColor = "green"
    }
    else
    {
    $Loststatus = "Bad"
    $LostAColor = "red"
    }  #Set lost status, use average lost to caculate

    if ($Lost -ne 100)
    {
    $Networkstatus = "Good"
    $LostColor = "black"
    }
    else
    {
    $Networkstatus = "Bad"
    $LostColor = "red"
    }  #Set Network status

    if ($Average -le $LatencyAlert)
    {
    $Latencystatus = "Good"
    $LatencyColor = "green"
    }
    else
    {
    $Latencystatus = "Bad"
    $LatencyColor = "red"
    } #Set latency status

###Create message body###
    $Body =
@"
    <html>
    <style>TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
    TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:#99CCFF}
    TD{border-width: 1px;padding: 2px;border-style: solid;border-color: black}
    </style>
    <body>
    <table>

    <tr><th>Items</th><th>Value</th><th>Alert Value</th><th>Ping Count</th></tr>

    <tr>
    <td>Lost(%)</td>
    <td><font color=$LostColor><b>$Lost</b></font></td>
    <td>$LostAlert</td>
    <td>$Count</td>
    </tr>

    <tr>
    <td>Average Lost(%)</td>
    <td><font color=$LostAColor><b>$LostA</b></font></td>
    <td>$LostAlert</td>
    <td>$CountA</td>
    </tr>

    <tr>
    <td>Latency</td>
    <td><font color=$LatencyColor><b>$Average1</b></font></td>
    <td>$LatencyAlert</td>
    <td>$Count</td>
    </tr>

    </table>
    </br>
    Logs: $Historyfolder
    </body>
    </html>
"@

    ###Send mail message if network status changed###
    if ($Loststatus0 -ne $Loststatus )
        {
        if ($Loststatus -eq "Good")
            {
            $Subject = "(OK) Package lost from $Source to  $Server($Description) is Good"
            $Priority = "Normal"
            $Alerttime = "Recovered"
            }
        else
            {
            $Subject = "(Alert) Package lost from $Source to  $Server($Description) is Bad"
            $Priority = "High"
            $Alerttime = Get-Date
            }
        
        Send-MailMessage -From $From -to $Receiver -Subject $Subject -SmtpServer $smtpserver -body $Body -Priority $Priority -BodyAsHtml
        }
    if ($Latencystatus0 -ne $Latencystatus )
        {
        if ($Latencystatus -eq "Good")
            {
            $Subject = "(OK) Network Latency from $Source to  $Server($Description) is Good"
            $Priority = "Normal"
            $Alerttime = "Recovered"
            }
        else
            {
            $Subject = "(Alert) Network Latency from $Source to  $Server($Description) is Bad"
            $Priority = "High"
            $Alerttime = Get-Date
            }
      
        Send-MailMessage -From $From -to $Receiver -Subject $Subject -SmtpServer $smtpserver -body $Body -Priority $Priority -BodyAsHtml
        }
    if ($Networkstatus0 -ne $Networkstatus )
        {
        if ($Networkstatus -eq "Good")
            {
            $Subject = "(OK) Network from $Source to  $Server($Description) is Up"
            $Priority = "Normal"
            $Alerttime = "Recovered"
            }
        else
            {
            $Subject = "(Alert) Network from $Source to  $Server($Description) is Down"
            $Priority = "High"
            $Alerttime = Get-Date
            }
       
        Send-MailMessage -From $From -to $Receiver -Subject $Subject -SmtpServer $smtpserver -body $Body -Priority $Priority -BodyAsHtml
        }   
        
    ###Set current network status as last status###
    $Loststatus0 = $Loststatus  
    $Latencystatus0 = $Latencystatus
    $Networkstatus0 = $Networkstatus

    ###Send alert if network was not recovered in a long time
    if ($Alerttime -ne "Recovered")
        {
        $Timediff = ((Get-Date) - $Alerttime).TotalMinutes
        if ($Timediff -ge 30 )
            {
            $Subject = "(Alert) Network from $Source to  $Server($Description) is bad for a long time"
            $Priority = "High"
            Send-MailMessage -From $From -to $Receiver -Subject $Subject -SmtpServer $smtpserver -body $Body -Priority $Priority -BodyAsHtml
            $Alerttime = Get-Date
            }
        }
    }
    
}

foreach ($server in $servers)
{
    $Address = $server.Address
    Start-Job -ScriptBlock $ScriptBlock -ArgumentList "$Address","$path","$Serverlist" -Name $Address
    #Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList "$Address","$path","$Serverlist"
}
Wait-Job -Name "*"
