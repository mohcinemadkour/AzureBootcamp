<#
.NOTES
	Script:		KeyVault_Deploy.ps1
    Author:		Fabien Gilbert (fabien.gilbert@appliedis.com)
    Date:       April of 2019
	Function:	Create Azure Key Vault
	
.SYNOPSIS
This script runs commands required to deploy an Azure Key Vault using an ARM template.

.DESCRIPTION
This script runs commands required to deploy an Azure Key Vault using an ARM template.

.EXAMPLE
run this script from the same folder as the JSON files
.\KeyVault_Deploy.ps1
#>
$TemplateFile = "KeyVault_Template.json"
$TemplateParameter = "KeyVault_Parameters.json"
$ResourceGroup = "BOOTCAMP"
if(!(Get-AzureRmContext)){Write-Error "Connect to Azure";exit}
New-AzureRmResourceGroupDeployment -Name KeyVault -ResourceGroupName $ResourceGroup -TemplateFile $TemplateFile -TemplateParameterFile $TemplateParameter -Verbose