function Get-Computerdata {

<#
.SYNOPSIS
Retrieves key system information.
.DESCRIPTION
Get-Computerdata uses Windows Management Instrumentation
(WMI) to retrieve information from one or more computers.
Specify computers by name.
.PARAMETER Computer Name
One or more computer names
#>

[CmdletBinding()]
param(
[Parameter (Mandatory=$True, ValueFromPipeline=$True)]
[ValidateNotNullorEmpty()]
[string[]]$ComputerName,
[string]$ErrorLog = 'c:\Error.txt'

)
BEGIN {
  Write-Verbose "Starting Get-Computerdata"
}
PROCESS {
foreach ($computer in $computername) {
Write-Verbose "getting data from $computer"
Try {
$everything_ok = $true
Write-Verbose "Win32_ComputerSystem"
$os = Get-WmiObject -class Win32_OperatingSystem -computerName $computer -ErrorAction Stop
}
Catch {
$everything_ok = $false
$msg="Failed getting system information from $computer.
$($_.Exception.Message)"
Write-Error $msg
if ($LogErrors) {
$computer | Out-File $ErrorLog -Append
}
}
if ($everything_ok){

Write-Verbose "Win32_Bios"
Write-Verbose "Win32_OperatingSystem"
$comp = Get-WmiObject -class Win32_ComputerSystem `
-computerName $computer
$bios = Get-WmiObject -class Win32_BIOS `
-computerName $computer

switch ($comp.AdminPasswordStatus)
        {
            '1'     {$aps = "Disabled"}
            '2'     {$aps = "Enabled"}
            '3'     {$aps = "NA"}
            '4'     {$aps = "Unknown"}
            '0'     {$aps = "Undefined"}     
        } 

$props = @{'ComputerName'=$computer;
'SerialNumber'=$bios.serialnumber;
'Manufacturer'=$comp.manufacturer;
'Model'=$comp.model;
'ServicePackMajorversion'=$os.servicepackmajorversion;
'Workgroup'=$comp.workgroup;
'AdminPasswordStatus'= $aps 
}
$obj = New-Object -TypeName PSObject -Property $props
$obj.PSObject.TypeNames.Insert(0,'MOL.ComputerSystemInfo')
Write-Output $obj
}
}
}
END {Write-Verbose "Ending Get-Computerdata"}
}




Function Get-VolumeInfo {
<#
.SYNOPSIS
Retrieves key information about system drives.
.DESCRIPTION
Get-DriveInfo uses Windows Management Instrumentation
(WMI) to retrieve information from one or more computers about system drives.
.PARAMETER Computer Name
One or more computer names
#>
[cmdletbinding()]
param(
[Parameter(Position=0,ValueFromPipeline=$True)]
[ValidateNotNullorEmpty()]
[string[]]$ComputerName,
[string]$ErrorLog="C:\Errors.txt",
[switch]$LogErrors
)
Begin {
Write-Verbose "Starting Get-VolumeInfo"
}
Process {
foreach ($computer in $computerName) {
Write-Verbose "Getting data from $computer"
Try {
$drives = Get-WmiObject -Class Win32_Volume -computername $Computer -Filter "DriveType=3" -ErrorAction Stop

Foreach ($drive in $drives) {
#format size and freespace
#Define a hashtable to be used for property names and values
$Size="{0:N2}" -f ($drive.capacity/1GB)
$Freespace="{0:N2}" -f ($drive.Freespace/1GB)
$hash=@{
Computername=$computer
Drive=$drive.Name
FreeSpace=$Freespace
Size=$Size
}
#create a custom object from the hash table
$obj = New-Object -TypeName PSObject -Property $hash
$obj.PSObject.TypeNames.Insert(0,'MOL.DiskInfo')
Write-Output $obj

} #foreach
} #Try
Catch {
#create an error message
$msg="Failed to get volume information from $computer.
$($_.Exception.Message)"
Write-Error $msg
Write-Verbose "Logging errors to $errorlog"
$computer | Out-File -FilePath $Errorlog -append
}
} #foreach computer
}
 #Process
End {

}
}


Function Get-ServiceInfo {
<#
.SYNOPSIS
Retrieves key information about running serviuces.
.DESCRIPTION
Get-RunningService uses Windows Management Instrumentation
(WMI) to retrieve information from one or more computers about system running services.
.PARAMETER Computer Name
One or more computer names
#>
[cmdletbinding()]
param(
[Parameter(Position=0,ValueFromPipeline=$True)]
[ValidateNotNullorEmpty()]
[string[]]$ComputerName,
[string]$ErrorLog="C:\Errors.txt",
[switch]$LogErrors
)
Begin {
Write-Verbose "Starting Get-ServiceInfo"
#if -LogErrors and error log exists, delete it.
if ( (Test-Path -path $errorLog) -AND $LogErrors) {
Remove-Item $errorlog
}
}
Process {
foreach ($computer in $computerName) {
Write-Verbose "Getting services from $computer"
Try {
$services = Get-WmiObject -Class Win32_Service | where {$_.State -eq 'Running'} -ErrorAction Stop
foreach ($service in $services) {
Write-Verbose "Processing service $($service.name)"
#get the associated process
Write-Verbose "Getting process for $($service.name)"
$process=Get-WMIObject -class Win32_Process -computername $Computer -Filter "ProcessID='$($service.processid)'" -ErrorAction Stop

$props=@{
Computername=$service.PSComputerName
Name=$service.name
Displayname=$service.DisplayName
ThreadCount=$process.ThreadCount
ProcessName=$process.Name
VmSize=$process.VirtualSize
peakPageFile=$process.PeakPageFileUsage
}
#create a custom object from the hash table
$obj = New-Object -TypeName PSObject -Property $props
$obj.PSObject.TypeNames.Insert(0,'MOL.ServiceProcessInfo')
Write-Output $obj

} #foreach service
}
Catch {
#create an error message
$msg="Failed to get service data from $computer.
$($_.Exception.Message)"
Write-Error $msg
if ($LogErrors) {
Write-Verbose "Logging errors to $errorlog"
$computer | Out-File -FilePath $Errorlog -append
}
}
} #foreach computer
} #process
End {
Write-Verbose "Ending Get-ServiceInfo"
}
}

Function Get-RemoteSmbShare {

<#
.SYNOPSIS
Retrieves a list of current shared folders from each specified computer.
.DESCRIPTION
Get-RemoteSmbShare uses uses invoke-command and get-smbshare to get information abut current shared folders for each specified computer.
.PARAMETER ComputerName
One or more computer names
.PARAMETER ErrorFile
A file to save any errors occured while running Get-RemoteSmbShare
.EXAMPLE
Get-RemoteSmbShare -ComputerName localhost, localhost
.EXAMPLE
Get-Content names.txt | Get-RemoteSmbShare
#>

[CmdletBinding()]
param(
[Parameter (Mandatory=$True, ValueFromPipeline=$True)]
[ValidateCount(1,5)]
[Alias('HostName')]
[string[]]$ComputerName,
[string]$ErrorFile = 'c:\Errors.txt'

)

Begin {}

Process{
foreach ($computer in $computerName){
Try{ 
$shares = Invoke-Command -ComputerName $ComputerName {Get-SmbShare}  -ErrorAction Stop
foreach ($share in $shares){

$props= @{
'Description'=$share.Description;
'Path' = $share.Path;
'Name' = $share.Name;
'ComputerName'=$computer;

}
$obj = New-Object -TypeName PSObject -Property $props
Write-Output $obj

}
}
Catch {
#create an error message
$msg="Failed to get  data from $computer.
$($_.Exception.Message)"
Write-Error $msg
if ($LogErrors) {
Write-Verbose "Logging errors to $errorlog"
$computer | Out-File -FilePath $Errorlog -append
}
}
} #foreach computer
}
End{}


}
