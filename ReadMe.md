# PowerCLI

Repo for all PowerCLI scripts for vSphere automation.
This is my personal repo used in my day today learning
These are not production ready scripts and should not be used in a production enviroment without extensive testing



## Requirements

The provided PowerShell scripts only requirement are:

1. PowerShell V5 at least - If you are not using Windows 10 or Windows Server 2016, you can install the latest Windows Management Framework https://www.microsoft.com/en-us/download/details.aspx?id=54616.
2. PowerCLI

## Install PowerCLI
There is an installer provided for the PowerCLI module, however, now there is an option to install the module directly in PowerShell using the `Install-Module` command. To install PowerCLI, execute the following steps:

- Open a PowerShell windows as Administrator
- Install the module using:

Install-Module -Name VMware.PowerCLI

If you have already installed PowerCLI from the PowerShell gallery, you can run the following command:
Update-Module -Name VMware.PowerCLI.


## Allowing PowerShell Scripts to Run

A good security feature added by Microsoft is stopping PowerShell scripts the ability to run by default. Since we need to run scripts, we have to enable this setting. This can be achieved with the following command:

Set-ExecutionPolicy Unrestricted

Below is a summary of the different configuration that can be specified:

- Restricted - No scripts can be run. Windows PowerShell can be used only in interactive mode.
- AllSigned - Only scripts signed by a trusted publisher can be run.
- RemoteSigned - Downloaded scripts must be signed by a trusted publisher before they can be run.
- Unrestricted - No restrictions; all Windows PowerShell scripts can be run.

## Secrets Vault

Some of these scripts use Secrets a more secure way of storing sensitive information such as username and passwords.

Install-Module Microsoft.PowerShell.SecretManagement
Install-Module Microsoft.PowerShell.SecretStore

Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

Set-Secret -Vault MyVault -Name Example -Secret “TopSecret”

To Unlock the vault we also need to store the Vault secret (Dont Ask). we do this as an encrypted Password file

Get-Credential | Export-CliXml ~/vaultpassword.xml

We retrive the password in our automation script as 

$vaultpassword = (Import-CliXml ~/vaultpassword.xml).Password


