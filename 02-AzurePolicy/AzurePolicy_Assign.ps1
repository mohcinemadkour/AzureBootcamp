<#
.NOTES
	Script:		AzurePolicy_Assign.ps1
    Author:		Fabien Gilbert (fabien.gilbert@appliedis.com)
    Date:       April of 2019
	Function:	Create Azure Policy Assignments
	
.SYNOPSIS
This script runs commands required to create Azure Policy Assignments.

.DESCRIPTION
This script imports a JSON file that defines Azure Policy Assignments, and creates the assignments

.EXAMPLE
run this script from the same folder as the JSON file
.\AzurePolicy_Assign.ps1
#>
if(!(Get-AzureRmContext)){Write-Error "Connect to Azure";exit}
#Import settings from JSON file
$PolicyAssignmentFile = "AzurePolicy_Settings.json"
$PolicyAssignments = Get-Content -Path $PolicyAssignmentFile | ConvertFrom-Json
if(!($PolicyAssignments)){Write-Error "Could not read JSON Policy Assignment file";exit}
foreach($PolicyAssignment in $PolicyAssignments)
{
    $ScopeId = switch ($PolicyAssignment.ScopeType){
        'Management Group' {Get-AzureRmManagementGroup | Where-Object -Property DisplayName -EQ -Value $PolicyAssignment.ScopeName | Select-Object -ExpandProperty Id}
        'Subscription' {("/subscriptions/" + (Get-AzureRmSubscription -SubscriptionName $PolicyAssignment.ScopeName | Select-Object -ExpandProperty Id))}
        'Resource Group' {Get-AzureRmResourceGroup -Name $PolicyAssignment.ScopeName | Select-Object -ExpandProperty ResourceId}
        'Resource' {Get-AzureRmResource | Where-Object -Property Name -EQ -Value $PolicyAssignment.ScopeName | Select-Object -ExpandProperty ResourceId}        
    }
    $ExistingPolicyAssignment = Get-AzureRmPolicyAssignment -Scope $ScopeId -ErrorAction:SilentlyContinue | Where-Object -Property Name -EQ -Value $PolicyAssignment.PolicyAssignment 
    if(!($ExistingPolicyAssignment)){
        $PolicyDefinition = Get-AzureRmPolicyDefinition -BuiltIn | Where-Object {$_.Properties.DisplayName -eq $PolicyAssignment.PolicyDefinition}
        $PolicyParameters = @{}
        foreach($PP in $PolicyAssignment.PolicyParameters){$PolicyParameters.Add($PP.name,$PP.value)}
        Write-Output ("Assigning Azure Policy " + [char]34 + $PolicyAssignment.PolicyDefinition + [char]34 + " to Scope Id " + [char]34 + $ScopeId + [char]34 + "...")
        New-AzureRmPolicyAssignment -Name $PolicyAssignment.PolicyAssignment -PolicyDefinition $PolicyDefinition -Scope $ScopeId -PolicyParameterObject $PolicyParameters
    }
}