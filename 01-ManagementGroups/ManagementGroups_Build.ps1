<#
.NOTES
	Script:		ManagementGroups_Build.ps1
    Author:		Fabien Gilbert (fabien.gilbert@appliedis.com)
    Date:       April of 2019
	Function:	Deploy Azure Management Group structure
	
.SYNOPSIS
This script runs commands required to deploy an Azure Management Group structure.

.DESCRIPTION
This script imports a JSON file that defines the Azure Management Group structure, creates the management groups and attaches child subscriptions

.EXAMPLE
run this script from the same folder as the JSON file
.\ManagementGroups_Build.ps1
#>
if(!(Get-AzureRmContext)){Write-Error "Please connect to Azure";exit}
#Import settings from JSON file
$MGStructureFilePath = "ManagementGroups_Settings.json"
$MGStructure = Get-Content -Path $MGStructureFilePath | ConvertFrom-Json
if(!($MGStructure)){Write-Error "Could not read JSON Settings file";exit}
foreach($MG in $MGStructure)
{
    #Create Management Groups
    Write-Output ("`r`nManagement Group " + $MG.ManagementGroupDisplayName)
    $MgObj = Get-AzureRmManagementGroup -GroupName $MG.ManagementGroupName -Expand -ErrorAction:SilentlyContinue
    if(!($MgObj)){
        Write-Output ("`tCreating Management Group Display Name " + $MG.ManagementGroupDisplayName + " Name " + $MG.ManagementGroupName + "...")
        $MgObj = New-AzureRmManagementGroup -GroupName $MG.ManagementGroupName -DisplayName $MG.ManagementGroupDisplayName -ParentId $MG.ManagementGroupParent.Id        
    }
    #Attach child subscriptions to Management Groups
    foreach($MGSub in $MG.ChildSubscriptions){
        if(!($MgObj.Children | Where-Object -Property Name -EQ -Value $MGSub.SubscriptionId))
        {
            Write-Output ("`tAdding child subscription " + $MGSub.SubscriptionName + "...")
            New-AzureRmManagementGroupSubscription -GroupName $MG.ManagementGroupName -SubscriptionId $MGSub.SubscriptionId            
        }        
    }    
}