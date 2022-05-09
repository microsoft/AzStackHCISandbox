#Credentials
$ADSPN_DisplayName="HCI-SPN"


Import-Module "Az.resources"

 # Functions # 
function get-azadcreds {
    param (
        $azcred,
        $region 
    )
    
    #login to Azure
    $azcred=Get-AzContext

    if (-not (Get-AzContext)){
        $azcred=Login-AzAccount -UseDeviceAuthentication
    }

#select context
    $context=Get-AzContext -ListAvailable
    if (($context).count -gt 1){
        $context=$context | Out-GridView -OutputMode Single
        $context | Set-AzContext
    }

#location (all locations where HostPool can be created)
    $region=(Get-AzLocation | Where-Object Providers -Contains "Microsoft.DesktopVirtualization" | Out-GridView -OutputMode Single -Title "Please select Location for AVD Host Pool metadata").Location

}

function create-customHCIrole {
    (
        $displayName,
        $description 
    )
### Create Azure AD Custom Role ##
New-AzureADMSPermissionGrantPolicy -Id "AzSHCI-registration-consent-policy" -DisplayName "Azure Stack HCI registration admin app consent policy" -Description "Azure Stack HCI registration admin app consent policy" 

New-AzureADMSPermissionGrantConditionSet -PolicyId "AzSHCI-registration-consent-policy" -ConditionSetType "includes" -PermissionType "application" -ResourceApplication "1322e676-dee7-41ee-a874-ac923822781c" -Permissions "bbe8afc9-f3ba-4955-bb5f-1cfb6960b242","8fa5445e-80fb-4c71-a3b1-9a16a81a1966","493bd689-9082-40db-a506-11f40b68128f","2344a320-6a09-4530-bed7-c90485b5e5e2"

$displayName = "Azure Stack HCI Registration Administrator "
$description = "Custom AD role to allow registering Azure Stack HCI "
$templateId = (New-Guid).Guid
$allowedResourceAction =
@(
       "microsoft.directory/applications/createAsOwner",
       "microsoft.directory/applications/delete",
       "microsoft.directory/applications/standard/read",
       "microsoft.directory/applications/credentials/update",
       "microsoft.directory/applications/permissions/update",
       "microsoft.directory/servicePrincipals/appRoleAssignedTo/update",
       "microsoft.directory/servicePrincipals/appRoleAssignedTo/read",
       "microsoft.directory/servicePrincipals/appRoleAssignments/read",
       "microsoft.directory/servicePrincipals/createAsOwner",
       "microsoft.directory/servicePrincipals/credentials/update",
       "microsoft.directory/servicePrincipals/permissions/update",
       "microsoft.directory/servicePrincipals/standard/read",
       "microsoft.directory/servicePrincipals/managePermissionGrantsForAll.AzSHCI-registration-consent-policy"
)
$rolePermissions = @{'allowedResourceActions'= $allowedResourceAction}

$customADRole = New-AzureADMSRoleDefinition -RolePermissions $rolePermissions -DisplayName $displayName -Description $description -TemplateId $templateId -IsEnabled $true


}













## Create Service Principal Account ###

New-AzADServicePrincipal -DisplayName $ADSPN_DisplayName -Role $customADRole -Scope $context.subscription.id -OutVariable sp






get-azadcreds

create-customHCIrole 

