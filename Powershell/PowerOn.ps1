#################################################################################
# Power On VMs (powerOn.ps1)
#
#
#
# Based on Original Script Created By: Mike Preston, 2012 - With a whole lot of help from Eric Wright 
#                                  (@discoposse)
# http://blog.mwpreston.net/shares/
#
# Variables:  $mysecret - a secret word to make the script run, stops 
#                         the script from running when double clicked in error
#             $vcenter - The IP/DNS of your vCenter Server
#             $vcentervm - name of the virtual vcenter machine
#             $vcenterhost - The ESXI host where the VCenter machine is running - this needs to be the last machine to be shutdown
#             $cluster = "Name of Cluster"
#             $filename - path to csv file to store powered on vms
#			  used for the poweronvms.ps1 script.
#             $cluster - Name of specific cluster to target within vCenter
#
#
# Usage: ./poweroffvms.ps1 "keyword"
#        Intended to be ran in the command section of the APC Powerchute Network
#        Shutdown program before the shutdown sequence has started.
#
#Currently Untested
#################################################################################

$vaultpassword = (Import-CliXml ~/vaultpassword.xml).Password
Unlock-SecretStore -Password $vaultpassword

$vcenter = ""
$vcentervm = ""
$vcenterhost = ""


$username= Get-Secret -Vault LocalStore -Name vcenterusername -AsPlainText
$password = Get-Secret -Vault LocalStore -Name esxi -AsPlainText

$filename = "c:\path\to\poweredonvms.csv"

$myImportantVMs = "SQL", "DNS"

##Need to add a routine to poll the esxi machine to test is up
##
##
##


#connect to vcenter host
Write-Host "Connecting to $vcenterhost" -nonewline
$success = Connect-VIServer $vcenterhost -username root -Password $password
if ($success) { Write-Host "Connected!" -Foregroundcolor Green }
else
{
    Write-Host "Something is wrong, Aborting script" -Foregroundcolor Red
    exit
}

Write-Host "Powering on $vcentervm ..." -nonewline
Start-VM $vcentervm
Sleep 5
Write-Host "DONE" -Foregroundcolor Green  

#Disconnect from vcenter host.
Write-Host "Disconnecting from vCenter - $vcenter ...." -nonewline
$disconnectsuccess = Disconnect-VIServer $vcenter -confirm:$false

#Check for the power on file
Write-Host "Checking to see if Power Off dump file exists....." -nonewline
Sleep 2
if (Test-Path $filename)
{
    Write-Host "File Found" -Foregroundcolor green
    Write-Host ""
    $date = ( get-date ).ToString('yyyyMMdd-HHmmss')
    
    #now we must check to see if vCenter service is running, if not, we need to wait....
    Write-Host "Checking for vCenter Service..." -nonewline
    Sleep 2
    while ((Get-Service vpxd).Status -ne "Running")
    {
        Write-Host "." -nonewline
        Sleep 2
        Write-Host "." -nonewline
        Sleep 2
        Write-Host "." -nonewline
        Sleep 2 
    }
     Write-Host "Service has Started!" -ForegroundColor Green 
    #connect to vcenter
    Sleep 5
    Write-Host "Connecting to vCenter Server..." -nonewline
    Sleep 3
    $success = Connect-VIServer $vcenter -username $username -Password $password
    if ($success) 
    { 
        Write-Host "Connected" -ForegroundColor Green 
    }
    else 
    { 
        Write-Host "ISSUES, aborting script" -Foregroundcolor Red 
        exit
    }

    #Start the most important VM's First such as Active Directory, DNS and DHCP
    Write-Host ""
    Write-Host "Starting the most important VMs first (Phase 1)" -ForegroundColor Green
    Write-Host ""
    foreach ($iVM in $myImportantVMs)
    {
        Write-Host "Powering on $iVM ..." -nonewline
        Start-VM $iVM
        Sleep 5
        Write-Host "DONE" -Foregroundcolor Green   
    }

    #Start the remaining VM's
     Write-Host ""
    Write-Host "Starting the remaining VMs" -ForegroundColor Green
    Write-Host ""
    #read file and start VMs every 5 seconds...
    $vms = Import-CSV $filename
    foreach ($vm in $vms)
    {
        $vmname = $vm.Name
        if ($myImportantVMs -notcontains $vmName)
        {
            Start-VM $vm.Name
            Write-Host "Powering on $vmName " 
            sleep 5
            Write-Host "DONE" 
        }
        else
        {
            Write-Host "Skipping $vmname - already powered on in phase 1" -Foregroundcolor yellow
        }
    }

    #Rename the dumpfile so it does not get triggered again accidently
     Write-Host "Power on completed, I will now rename the dump file...." -nonewline
    $DateStamp = get-date -uformat "%Y-%m-%d@%H-%M-%S"  
    $fileObj = get-item $fileName
    $extOnly = $fileObj.extension
    $nameOnly = $fileObj.Name.Replace( $fileObj.Extension,'')
    rename-item "$fileName" "$nameOnly-$DateStamp$extOnly"
    Write-Host "DONE" -foregroundcolor green
    Write-Host "File has been renamed to $nameOnly-$DateStamp$extOnly"   
}
else
{
    Write-Host "File Not Found - aborting..." -Foregroundcolor green
    exit
}



