<#
.NOTES
	Script:		StorageAccount_Build.ps1
    Author:		Fabien Gilbert (fabien.gilbert@appliedis.com)
    Date:       April of 2019
	Function:	Deploy Azure Storage Account with BYOK encryption
	
.SYNOPSIS
This script runs commands required to deploy an Azure Storage Account and enable "Bring Your Own Key" encryption.

.DESCRIPTION
This script deploys an Azure Storage Account using an ARM template and configure encryption using a Key Vault Key.

.EXAMPLE
run this script from the same folder as the JSON files
.\StorageAccount_Build.ps1
#>
$TemplateFile = "StorageAccount_Template.json"
$TemplateParameter = @{"StorageAccountName"="azbootcampstore"}
$ResourceGroup = "BOOTCAMP"
$KeyVault = "bootcampkv"
$KeyVaultKey = "storageaccount"
#Build storage account
New-AzureRmResourceGroupDeployment -Name StorageAccount -ResourceGroupName $ResourceGroup -TemplateFile $TemplateFile -TemplateParameterObject $TemplateParameter -Verbose

#Create Key Vault Encryption Key
$StorageAccountKeyVaultKey = Get-AzureKeyVaultKey -VaultName $KeyVault -Name $KeyVaultKey -ErrorAction:SilentlyContinue
if(!($StorageAccountKeyVaultKey)){
    $StorageAccountKeyVaultKey = Add-AzureKeyVaultKey -VaultName $KeyVault -Name $KeyVaultKey -Destination Software
}
#Assign Identity to Storage Account
Set-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -Name $TemplateParameter.StorageAccountName -AssignIdentity
$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -AccountName $TemplateParameter.StorageAccountName
#Add storage account principal to Key Vault Access Policy
Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault -ObjectId $storageAccount.Identity.PrincipalId  -PermissionsToKeys wrapkey,unwrapkey,get
#Set storage account with BYOK encryption
$keyVaultObj = Get-AzureRmKeyVault -VaultName $KeyVault
Set-AzureRmStorageAccount -ResourceGroupName $storageAccount.ResourceGroupName -AccountName $storageAccount.StorageAccountName -KeyvaultEncryption -KeyName $StorageAccountKeyVaultKey.Name -KeyVersion $StorageAccountKeyVaultKey.Version -KeyVaultUri $keyVaultObj.VaultUri