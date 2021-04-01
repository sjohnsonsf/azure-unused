<#
.SYNOPSIS
  This script is used to identify unused Azure Resources and generate a report. 
.DESCRIPTION
  The script uses the Az PowerShell module to identify unused Virtual Machines, Disks, and Network Interface Cards. 
  The device information is then exported to a CSV file with the relevant properties, such as type, resource group, ID, etc. 
.INPUTS
  None
.OUTPUTS
  #Script report
  .\Report\Az_UnusedResources_[date].csv
.NOTES
  None
#>
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
#Suppress Azure Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
$appid = $Env:AzAppID
$pass = ConvertTo-SecureString -String $Env:AzSecret -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($appid, $pass)

Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $Env:AzTenantID| Out-Null
#----------------------------------------------------------[Declarations]----------------------------------------------------------
$subscriptions = @(
  #Add comma separated subscription IDs
)
$objs = @()
class AzResource {
    [string]$subscription
    [string]$type
    [string]$resourcegroup
    [String]$technical_owner
    [String]$business_owner
    [string]$name
    [String]$id
}
$report_path = Test-Path $PSScriptRoot\Report
#-----------------------------------------------------------[Functions]------------------------------------------------------------
ForEach ($sub in $subscriptions){
    Set-AzContext $sub | Out-Null
    write-host $sub
    $vms = Get-AzVm -Status | Where-Object {$_.PowerState -eq 'VM deallocated'}
    $nics = Get-AzNetworkInterface | Where-Object {!$_.VirtualMachine}
    $mds = Get-AzDisk | Where-Object {!$_.ManagedBy}
    $mds = $mds | `
      Where-Object {$_.Id -notlike "*asr*" } | `
        Where-Object {$_.Id -notlike "*imgage*"} | `
          Where-Object {$_.Id -notlike "*img*" } 
    $ips = Get-AzPublicIpAddress | Where-Object {!$_.IpConfiguration}
    $azresources = @()
    $azresources += ($vms + $nics + $mds + $ips)
    ForEach ($resource in $azresources){
        $obj = [AzResource]::New()
        $obj.subscription = $sub
        $obj.type = $resource.Type
        $obj.resourcegroup = $resource.ResourceGroupName
        $obj.technical_owner = if(($resource.Tags).Keys -notcontains "Technical Owner"){
            "None"
        } elseif(!$resource.Tags["Technical Owner"]) {
            "None"
        } else {
            $resource.Tags["Technical Owner"]
        }
        $obj.business_owner = if(($resource.Tags).Keys -notcontains "Business Owner"){
            "None"
        } elseif(!$resource.Tags["Business Owner"]) {
            "None"
        } else {
            $resource.Tags["Business Owner"]
        }
        $obj.name = ($resource.id).split("/")[-1]
        $obj.id = $resource.id
        $objs += $obj
    }
}
if($report_path -eq $false){
    New-Item -Type Directory $PSScriptRoot\Report
}
$path = ("$PSScriptRoot/Report/Az_UnusedResoures_" +(Get-Date -format yyy-MM-dd-HH-mm)+".csv")
$objs | Export-CSV -Path $path -NoTypeInformation