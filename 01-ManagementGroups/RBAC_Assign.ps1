<#
.NOTES
	Script:		RBAC_Assign.ps1
    Author:		Fabien Gilbert (fabien.gilbert@appliedis.com)
    Date:       April of 2019
	Function:	Configure Azure RBAC
	
.SYNOPSIS
This script runs commands required to configure Azure Role-Based Access Control.

.DESCRIPTION
This script imports a JSON file that defines the Roles, Scopes and Assignments, and creates the assignments

.EXAMPLE
run this script from the same folder as the JSON file
.\RBAC_Assign.ps1
#>
if(!(Get-AzureRmContext)){Write-Error "Connect to Azure";exit}
#Import settings from JSON file
$RoleAssignmentFilePath = "RBAC_Settings.json"
$RoleAssignments = Get-Content -Path $RoleAssignmentFilePath | ConvertFrom-Json
if(!($RoleAssignments)){Write-Error "Could not read RBAC Assignments JSON file";exit}
foreach($RoleAssignment in $RoleAssignments){    
    #Select Subscription
    if($RoleAssignment.Subscription -and (Get-AzureRmContext).Subscription.Name -ne $RoleAssignment.Subscription){Set-AzureRmContext -SubscriptionName $RoleAssignment.Subscription}
    foreach($AssignmentScope in $RoleAssignment.Resources){
        Write-Output ("`r`nScope Name " + $AssignmentScope.'Scope Name')
        #Get assignment Scope Id
        $ScopeId = $null
        switch ($AssignmentScope.'Scope Type') {
            'Management Group' {$ScopeId=Get-AzureRmManagementGroup | Where-Object -Property DisplayName -EQ -Value $AssignmentScope.'Scope Name' | Select-Object -ExpandProperty Id}
            'Subscription' {$ScopeId=("/subscriptions/" + (Get-AzureRmSubscription -SubscriptionName $AssignmentScope.'Scope Name' | Select-Object -ExpandProperty Id))}
            'Resource Group' {$ScopeId=Get-AzureRmResourceGroup -Name $AssignmentScope.'Scope Name' | Select-Object -ExpandProperty ResourceId}
            'Resource' {$ScopeId=Get-AzureRmResource | Where-Object -Property Name -EQ -Value $AssignmentScope.'Scope Name' | Select-Object -ExpandProperty ResourceId}
        }
        #Assign Access Control
        if(!($ScopeId)){Write-Error "Scope Id could not be found";exit}
        foreach($RoleAssignment in $AssignmentScope.'Role Assignments'){
            Write-Output ("`tGroup Name " + $RoleAssignment.'Group Name')            
            if(!(Get-AzureRmRoleAssignment -Scope $ScopeId -ObjectId $RoleAssignment.'Group Id' -RoleDefinitionName $RoleAssignment.'Role Definition Name')){
                Write-Output ("`t`tAssigning Role " + $RoleAssignment.'Role Definition Name' + "...")
                New-AzureRmRoleAssignment -Scope $ScopeId -RoleDefinitionName $RoleAssignment.'Role Definition Name' -ObjectId $RoleAssignment.'Group Id'
            }
        }
    }     
}