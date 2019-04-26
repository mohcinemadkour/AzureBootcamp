#Deploy VM with Disk Encryption and Key Vault Certificate
#Written by Fabien Gilbert in March of 2019
#
$TemplateFile = "VM_MasterTemplate.json"
$TemplateParameterFile = "VM_Parameter.json"
$VmResourceGroup = "BOOTCAMP"
$AutomationAccountResourceGroup = "BOOTCAMP"
$AutomationAccountName = "BOOTCAMPAUTO1"
$VmKeyEncryptionKeyName = "WebVmDisks"
$TemplateParameter = Get-Content -Path $TemplateParameterFile | ConvertFrom-Json
#Check if local admin password exists in KeyVault, if not create random one.
$VmAdminPassword = Get-AzureKeyVaultSecret -VaultName $TemplateParameter.parameters.KeyVaultName.value -Name $TemplateParameter.parameters.VmLocalUsername.value -ErrorAction:SilentlyContinue | Select-Object -ExpandProperty SecretValue
if(!($VmAdminPassword)){
    $RandomPassword = [char](Get-Random -Minimum 65 -Maximum 90) + [char](Get-Random -Minimum 97 -Maximum 122) + (Get-Random -Minimum 1 -Maximum 9) + [char](Get-Random -Minimum 37 -Maximum 47) + [char](Get-Random -Minimum 97 -Maximum 122) + (Get-Random -Minimum 1 -Maximum 9) + (Get-Random -Minimum 1 -Maximum 9) + [char](Get-Random -Minimum 65 -Maximum 90) + [char](Get-Random -Minimum 97 -Maximum 122) + [char](Get-Random -Minimum 33 -Maximum 36) + (Get-Random -Minimum 1 -Maximum 9) + [char](Get-Random -Minimum 65 -Maximum 91)
    Write-Output ("Username " + $TemplateParameter.parameters.VmLocalUsername.value + " password " + $RandomPassword)
    $VmAdminPassword = ConvertTo-SecureString -String $RandomPassword -AsPlainText -Force
    Set-AzureKeyVaultSecret -VaultName $TemplateParameter.parameters.KeyVaultName.value -Name $TemplateParameter.parameters.VmLocalUsername.value -SecretValue $VmAdminPassword
}
#Get AD Domain Join password from Key Vault
$DomainJoinPassword = Get-AzureKeyVaultSecret -VaultName $TemplateParameter.parameters.KeyVaultName.value -Name $TemplateParameter.parameters.AdDomainJoinUsername.value -ErrorAction:SilentlyContinue | Select-Object -ExpandProperty SecretValue
#Create Key Vault Key Encryption Key
$VmKeyEncryptionKey = Get-AzureKeyVaultKey -VaultName $TemplateParameter.parameters.KeyVaultName.value -Name $VmKeyEncryptionKeyName -ErrorAction:SilentlyContinue
if(!($VmKeyEncryptionKey)){
    $VmKeyEncryptionKey = Add-AzureKeyVaultKey -VaultName $TemplateParameter.parameters.KeyVaultName.value -Name $VmKeyEncryptionKeyName -Destination Software
}
#Get Automation account info
$AutomationAccountRegistration = Get-AzureRmAutomationAccount -ResourceGroupName $AutomationAccountResourceGroup -Name $AutomationAccountName | Get-AzureRmAutomationRegistrationInfo
<#Compile DSC configuration with certificate thumbprint
$ConfigData = @{"AllNodes"=@(@{
                "NodeName"= "bootcampweb"
                "SiteName"= "bootcampweb"
                "SiteContents"= "F:\inetpub\breakfastweb"                                                                                
                "SslCertThumbprint"= "E61A9A7A7ECCF4371DB9E3AZ00E0ABBBF1322F9E"})}
Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $AutomationAccountResourceGroup -AutomationAccountName $AutomationAccountName -ConfigurationName WebServerConfig -ConfigurationData $ConfigData
#Get compilation status
Get-AzureRmAutomationDscCompilationJob -ResourceGroupName $AutomationAccountResourceGroup -AutomationAccountName $AutomationAccountName -ConfigurationName WebServerConfig | Select ConfigurationName, CreationTime, Status, StatusDetails
#>#Start VM Deployment
New-AzureRmResourceGroupDeployment -Verbose -ResourceGroupName $VmResourceGroup -Name WebserverDeploy -TemplateFile $TemplateFile -VmLocalPassword $VmAdminPassword -AdDomainJoinPassword $DomainJoinPassword -AutomationRegistrationUrl $AutomationAccountRegistration.Endpoint -AutomationRegistrationKey $AutomationAccountRegistration.PrimaryKey -TemplateParameterFile $TemplateParameterFile -keyEncryptionKeyURL $VmKeyEncryptionKey.id
