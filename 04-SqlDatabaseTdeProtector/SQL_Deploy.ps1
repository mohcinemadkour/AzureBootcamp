<#
.NOTES
	Script:		SQL_Deploy.ps1
    Author:		Fabien Gilbert (fabien.gilbert@appliedis.com)
    Date:       April of 2019
	Function:	Deploy Azure SQL Database with Transparent Data Encryption
	
.SYNOPSIS
This script runs commands required to deploy an Azure SQL Database with TDE Protector

.DESCRIPTION
This script deploys an Azure SQL Database using an ARM template and configure TDE Protector with a Key Vault Key

.EXAMPLE
run this script from the same folder as the JSON files
.\SQL_Deploy.ps1
#>
$SqlTemplateFile = "SQL_Template.json"
$SqlTdeProtectorTemplateFile = "SqlTdeProtector_Template.json"
$SqlParameter = @{"sqlServerName"="bootcampsqlsrv"
                  "sqlDbName"="bootcampsqldb"
                  "sqlServerAdminLogin"="sqlmaster"}
$SqlTdeProtectorParameter = @{"sqlServerName"="bootcampsqlsrv"
                              "keyVaultName"="bootcampkv"
                              "keyName"="sqltdeprotector"}
#"keyVersion"=$TdeKeyVaultKey.Version}
$ResourceGroup = "BOOTCAMP"
#Create SQL login password in KeyVault
$SqlAdminPassword = Get-AzureKeyVaultSecret -VaultName $SqlTdeProtectorParameter.keyVaultName -Name $SqlParameter.sqlServerAdminLogin -ErrorAction:SilentlyContinue | Select-Object -ExpandProperty SecretValue
if(!($SqlAdminPassword)){
    $RandomPassword = [char](Get-Random -Minimum 65 -Maximum 90) + [char](Get-Random -Minimum 97 -Maximum 122) + (Get-Random -Minimum 1 -Maximum 9) + [char](Get-Random -Minimum 37 -Maximum 47) + [char](Get-Random -Minimum 97 -Maximum 122) + (Get-Random -Minimum 1 -Maximum 9) + (Get-Random -Minimum 1 -Maximum 9) + [char](Get-Random -Minimum 65 -Maximum 90) + [char](Get-Random -Minimum 97 -Maximum 122) + [char](Get-Random -Minimum 33 -Maximum 36) + (Get-Random -Minimum 1 -Maximum 9) + [char](Get-Random -Minimum 65 -Maximum 91)   
    $SqlAdminPassword = ConvertTo-SecureString -String $RandomPassword -AsPlainText -Force
    Set-AzureKeyVaultSecret -VaultName $SqlTdeProtectorParameter.keyVaultName -Name $SqlParameter.sqlServerAdminLogin -SecretValue $SqlAdminPassword
}
$SqlParameter.Add("sqlServerAdminLoginPassword",$SqlAdminPassword)
#Deploy SQL Server & Database
New-AzureRmResourceGroupDeployment -Name SQLDB -ResourceGroupName $ResourceGroup -TemplateFile $SqlTemplateFile -TemplateParameterObject $SqlParameter -Verbose

#Create SQL TDE Protector Key Vault Key
$SqlTdeProtectorKeyVaultKey = Get-AzureKeyVaultKey -VaultName $SqlTdeProtectorParameter.keyVaultName -Name $SqlTdeProtectorParameter.keyName -ErrorAction:SilentlyContinue
if(!($SqlTdeProtectorKeyVaultKey)){
    $SqlTdeProtectorKeyVaultKey = Add-AzureKeyVaultKey -VaultName $SqlTdeProtectorParameter.keyVaultName -Name $SqlTdeProtectorParameter.keyName -Destination Software
}
$SqlTdeProtectorParameter.Add("keyVersion",$SqlTdeProtectorKeyVaultKey.Version)
#Give permissions for SQL Service Principal to Access Key
$SqlServPrincipal = Get-AzureRmADServicePrincipal -DisplayName $SqlParameter.sqlServerName
Set-AzureRmKeyVaultAccessPolicy -VaultName $SqlTdeProtectorParameter.keyVaultName -ResourceGroupName $ResourceGroup -ObjectId $SqlServPrincipal.Id -PermissionsToKeys @("Get", "WrapKey", "UnwrapKey")
#Deploy SQL TDE Protector
New-AzureRmResourceGroupDeployment -Name SqlTdeProtector -ResourceGroupName $ResourceGroup -TemplateFile $SqlTdeProtectorTemplateFile -TemplateParameterObject $SqlTdeProtectorParameter -Verbose

#Check status
Get-AzureRmSqlServerKeyVaultKey -ResourceGroupName $ResourceGroup -ServerName $SqlParameter.sqlServerName
Get-AzureRmSqlDatabaseTransparentDataEncryption -ResourceGroupName $ResourceGroup -ServerName $SqlParameter.sqlServerName -DatabaseName $SqlParameter.sqlDbName
Get-AzureRmSqlServerTransparentDataEncryptionProtector -ResourceGroupName $ResourceGroup -ServerName $SqlParameter.sqlServerName
