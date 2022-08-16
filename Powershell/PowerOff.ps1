#################################################################################
# Power off VMs (poweroffvms.ps1)
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
# Usage: ./poweroff.ps1 "keyword"
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
$cluster = ""

#Secrets from Secrets Vault
$username= Get-Secret -Vault LocalStore -Name vcenterusername -AsPlainText
$password = Get-Secret -Vault LocalStore -Name esxi -AsPlainText
#

#Where to store the csv file
$filename = "c:\path\to\poweredonvms.csv"

#safety switch for production
$mysecret = "downdowndown"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

#Need to use the certificate instead
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore

#check for safetyswitch so we dont shut down accidently
$keyword=$args[0]
if ($keyword -ne $mysecret)
{
    Write-Host "You haven't passed the proper detonation sequence...ABORTING THE SCRIPT" -ForegroundColor red
    exit
}
Write-Host ""

#Connect to VCenter
Write-Host "Connecting to vCenter - $vcenter ...." -nonewline
$success = Connect-VIServer $vcenter -username $username -Password $password
if ($success) 
{ 
    Write-Host "Connected!" -Foregroundcolor Green 
}
else
{
    Write-Host "Something is wrong, Aborting script" -Foregroundcolor Red
    exit
}

#Get a list of all VM's that are powered on - used for powering them back on
Get-VM -Location $cluster | where-object {$_.PowerState -eq "PoweredOn" } | Select Name | Export-CSV $filename

#####################################
#Is this needed for a shutdown?
#change DRS Automation level to partially automated...
##Write-Host "Changing cluster DRS Automation Level to Partially Automated" -Foregroundcolor green
##Get-Cluster $cluster | Set-Cluster -DrsAutomation PartiallyAutomated -confirm:$false

#change the HA Level
##Write-Host ""
##Write-Host "Disabling HA on the cluster..." -Foregroundcolor green
##Write-Host ""
##Get-Cluster $cluster | Set-Cluster -HAEnabled:$false -confirm:$false


#####################################

#get VMs except for the VCenter VM
Write-Host ""
Write-Host "Retrieving a list of powered on guests...." -Foregroundcolor Green
Write-Host ""
$poweredonguests = Get-VM -Location $cluster | where-object {$_.PowerState -eq "PoweredOn" } | where{$_.Name -ne $vcentervm} 

#Power down the guest VM's
ForEach ( $guest in $poweredonguests )
{
    Write-Host "Processing $guest ...." -ForegroundColor Green
    Write-Host "Checking for VMware tools install" -Foregroundcolor Green
    ###Write-Host $guest.ID
    $guestinfo = get-view -Id $guest.ID
    if ($guestinfo.config.Tools.ToolsVersion -eq 0)
    {
        Write-Host "No VMware tools detected in $guest , hard power this one" -ForegroundColor Yellow
        #Stop-VM $guest -confirm:$false
    }
    else
    {
       write-host "VMware tools detected.  I will attempt to gracefully shutdown $guest"
       #$vmshutdown = $guest | shutdown-VMGuest -Confirm:$false
    }  
}

#Wait a minute or so for shutdowns to complete
Write-Host ""
Write-Host "Giving VMs 10 minutes before resulting in hard poweroff"
Write-Host ""
Sleep 600

#Second pass to see if anything is still powered on and hard power it off (We are running out of battery backup)
Write-Host "Beginning Phase 2 - anything left on....night night..." -ForegroundColor red
Write-Host ""

#get our list of guests still powered on...
$poweredonguests = Get-VM -Location $cluster | where-object {$_.PowerState -eq "PoweredOn" } | where{$_.Name -ne $vcentervm} 
ForEach ( $guest in $poweredonguests )
{
    Write-Host "Processing $guest ...." -ForegroundColor Green
    #no checking for toosl, we just need to blast it down...
    write-host "Shutting down $guest - I don't care, it just needs to be off..." -ForegroundColor Yellow
    Stop-VM $guest -confirm:$false
}

#wait 30 seconds before initiating host power down
Write-Host "Waiting 30 seconds and then proceding with host power off"
Write-Host ""
Sleep 30

#Get all the hosts in the cluster where the Vcenter is not ben ran
$esxhosts = Get-VMHost -Location $cluster | where {$_.Name -ne $vcenterhost}
#Shutdown the hosts except for the one hosting the VCenter
foreach ($esxhost in $esxhosts)
{
    Write-Host "Shutting down $esxhost" -ForegroundColor Green
    $esxhost | Foreach {Get-View $_.ID} | Foreach {$_.ShutdownHost_Task($TRUE)}

}

#Disconnect from vcenter and connect directly to last host.
Write-Host "Disconnecting from vCenter - $vcenter ...." -nonewline
$disconnectsuccess = Disconnect-VIServer $vcenter -confirm:$false


#connect to lasthost
Write-Host "Connecting to $vcenterhost" -nonewline
$success = Connect-VIServer $vcenterhost -username root -Password $password
if ($success) { Write-Host "Connected!" -Foregroundcolor Green }
else
{
    Write-Host "Something is wrong, Aborting script" -Foregroundcolor Red
    exit
}

#Get our list of guests still powered on this host (VCenter)
$poweredonguests = Get-VM -Location $cluster | where-object {$_.PowerState -eq "PoweredOn" } | where{$_.Name -ne $vcentervm} 
ForEach ( $guest in $poweredonguests )
{
    Write-Host "Processing $guest ...." -ForegroundColor Green
    write-host "Attempting to shutdown $guest gracefully"
    $vmshutdown = $guest | shutdown-VMGuest -Confirm:$false
}

#Wait 120 seconds
Write-Host "Waiting 2 minutes and then proceding with host power off"
Write-Host ""
Sleep 120

Write-Host "Shutting down $esxhost" -ForegroundColor Green
$esx = Get-VMHost $esxhost | Get-View
$hostshutdown = $esx.ShutdownHost_Task($true)

