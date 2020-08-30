#Powershell module to extend functionality of the Box CLI interface for reporting and admin functions.
#Brad Hodges 2020

#Check for functional Box CLI

#Functions to do:
#C
#Create Box folder
#Create Box group
#R
#Get Box user
#Get user status
#Get Box user storage cap
#Get content from deactivated Box account
#Get collaborators on a Box folder
#U
#Invite collaborator to Box folder
#Set Box user storage cap
#Remove collaborator from folder
#Add user to Box group
#Remove user from Box group
#D
#Delete Box user

#Script processes
#Deactivate Box users from list
#Delete Box users from list
#Get list of Box user folders
#Get list of user's storage per top-level folder
#Get list of user's collaborators per top-level folder
#Enterprise storage report
#Folder collabrations shared between two users
#Add list of users to Box group
#External collaboration reporting
#Set Box user storage caps from a list
#Delete a Box user's trash items older than X days

#Get Box userID
Function Get-BoxUserID {
    Param (
            [Parameter(Mandatory=$true,Position=0)]
            [string]$BoxUserName)
    Write-Debug "Get-BoxUserID $BoxUserName"
    $BoxUser = box users --filter=$BoxUserName --json | ConvertFrom-Json
    $BoxUserID = $BoxUser."id"
    Return $BoxUserID
}

#Get list of items in a Box folder.  Pass in 0 for $BoxFolderID to get root folder of a user
Function Get-BoxFolderList {
    Param (
            [Parameter(Mandatory=$true,Position=0)]
            [string]$BoxUserID,
            [Parameter(Mandatory=$true, Position=1)]
            [string]$BoxFolderID)
    Write-Debug "Get-BoxFolderList $BoxUserID $BoxFolderID"
    $BoxUserFolders = box folders:items $BoxFolderID --as-user=$BoxUserID --json | ConvertFrom-Json
    Return $BoxUserFolders
}

#Get list of items in a Box folder with owner of each.  Pass in 0 for $BoxFolderID to get root folder of a user
Function Get-BoxFolderListV2 {
    Param (
            [Parameter(Mandatory=$true,Position=0)]
            [string]$BoxUserID,
            [Parameter(Mandatory=$true, Position=1)]
            [string]$BoxFolderID)
    Write-Debug "Get-BoxFolderListV2 $BoxUserID $BoxFolderID"
    $BoxFolderRequestURL = "https://api.box.com/2.0/folders/$BoxFolderID/items?fields=owned_by,name,size`"&`"limit=1000"
    $BoxUserFoldersReturn = box request $BoxFolderRequestURL --as-user=$BoxUserID --json | ConvertFrom-Json
    $BoxUserFolders = $BoxUserFoldersReturn.body.entries
    Return $BoxUserFolders
}

#Get collaborations on a folder
Function Get-BoxUserItemCollaboration {
    Param (
            [Parameter(Mandatory=$true,Position=0)]
            [string]$BoxUserID, 
            [Parameter(Mandatory=$true,Position=1)]
            [string]$BoxItemID,
            [Parameter(Mandatory=$true,Position=2)]
            [string]$BoxItemType)
    Write-Debug "Get-BoxUserItemCollaboration $BoxUserID $BoxItemID $BoxItemType"
    if ($BoxItemType -eq "folder") {
        $BoxItemCollaboration = box folders:collaborations $BoxItemID --as-user=$BoxUserID --json | ConvertFrom-Json
    }
    elseif ($BoxItemType -eq "file") {
        $BoxItemCollaboration = box files:collaborations $BoxItemID --as-user=$BoxUserID --json | ConvertFrom-Json
    }
    Return $BoxItemCollaboration
}

Function Get-BoxUserRootFolders {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserRootFolders $BoxUserID"
    $BoxFolders = Get-BoxFolderListV2 -BoxUserID $BoxUserID -BoxFolderID "0"
    Return $BoxFolders
}

#Return list of folder items: name, type, id, owner
Function Get-BoxUserFolders {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserFolders $BoxUserName $BoxUserID"
    $BoxFolders = Get-BoxUserRootFolders -BoxUserID $BoxUserID
    $BoxFoldersOutputList = @()
    $UserEmail = $BoxUserName + $EmailDomain
    $BoxUserFolderCollabLevel = ""
    $BoxFolderOutput = [PSCustomObject]@{
        ItemName = ""
        Type = ""
        ID = ""
        Size = ""
        Owner = ""
    }
    Foreach ($BoxFolder in $BoxFolders) {
        Write-Debug $BoxFolder
        $BoxFolderID = $BoxFolder.id
        $BoxUserFoundInList = $False
        $BoxUserFolderCollabLevel = ""
        $BoxFolderOutput = [PSCustomObject]@{
            Name = ""
            Type = ""
            ID = ""
            Size = ""
            Owner = ""
        }
        $BoxFolderOutput.Name = $BoxFolder.name
        $BoxFolderOutput.ID = $BoxFolder.id
        $BoxFolderOutput.Type = $BoxFolder.type
        $BoxFolderOutput.Owner = $BoxFolder.owned_by.login
        $BoxFolderOutput.Size = $BoxFolder.size
        Write-Debug $BoxFolderOutput

        $BoxFoldersOutputList += $BoxFolderOutput
    }
    Return $BoxFoldersOutputList
}

#Return list of folder items: name, type, id, collaboration level
Function Get-BoxUserFoldersFullCollab {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserFoldersFullCollab $BoxUserName $BoxUserID"
    $BoxFolders = Get-BoxUserRootFolders -BoxUserID $BoxUserID
    $BoxFoldersOutputList = @()
    $BoxFolderCollaboratorList = @()
    $BoxUserFoundInList = $False
    $UserEmail = $BoxUserName + $EmailDomain
    $BoxUserFolderCollabLevel = ""
    $BoxFolderOutput = [PSCustomObject]@{
        ItemName = ""
        Type = ""
        ID = ""
        CollabLevel = ""
    }
    Foreach ($BoxFolder in $BoxFolders) {
        #if ($BoxFolder.type -eq "folder") {
            $BoxFolderID = $BoxFolder.id
            $BoxFolderCollaborations = Get-BoxUserItemCollaboration -BoxUserID $BoxUserID -BoxItemID $BoxFolderID -BoxItemType $BoxFolder.type
            $BoxUserFoundInList = $False
            $BoxUserFolderCollabLevel = ""
            $BoxFolderOutput = [PSCustomObject]@{
                Name = ""
                Type = ""
                ID = ""
                CollabLevel = ""
            }
            Write-Debug $BoxFolder.name
            #If the collaborations list is null, this is a folder owned by the user that isn't shared.
            if ($null -eq $BoxFolderCollaborations) {
                $BoxFolderOutput.Name = $BoxFolder.name
                $BoxFolderOutput.ID = $BoxFolder.id
                $BoxFolderOutput.Type = $BoxFolder.type
                $BoxFolderOutput.CollabLevel = "owner"
                $BoxUserFolderCollabLevel = "owner"
                Write-Debug "Null Collaboration list - non-shared folder: $BoxFolderOutput"
            }
            #If the collaborations list isn't null, check if the user is the owner
            else {
                #Go through each collaboration
                foreach ($BoxFolderCollaboration in $BoxFolderCollaborations) {
                    #Go through each collaborator
                    foreach ($BoxFolderCollaborator in $BoxFolderCollaboration) {
                        if ($BoxFolderCollaborator.accessible_by.login -eq $UserEmail) {
                            $BoxUserFoundInList = $True
                            $BoxUserFolderCollabLevel = $BoxFolderCollaborator.role
                        }
                    }
                }
                #If this user isn't found in the list, this user is the owner
                if (!$BoxUserFoundInList) {
                    $BoxFolderOutput.Name = $BoxFolder.name
                    $BoxFolderOutput.ID = $BoxFolder.id
                    $BoxFolderOutput.Type = $BoxFolder.type
                    $BoxFolderOutput.CollabLevel = "owner"
                    Write-Debug "User isn't found in the list of collaborators for this folder, so they're the owner: $BoxFolderOutput"
                }
                #If this user is found in the list, record their collaboration level
                else {
                    $BoxFolderOutput.Name = $BoxFolder.name
                    $BoxFolderOutput.ID = $BoxFolder.id
                    $BoxFolderOutput.Type = $BoxFolder.type
                    $BoxFolderOutput.CollabLevel = $BoxUserFolderCollabLevel
                    Write-Debug "User found in the list of collaborators for this folder, so they're an invited collaborator: $BoxFolderOutput"
                }
            }
            $BoxFoldersOutputList += $BoxFolderOutput
        #}
    }
    Return $BoxFoldersOutputList
}

#Return list of an item in a user's trash
Function Get-BoxUserTrashItemDetails {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxTrashID,
        [Parameter(Mandatory=$true,Position=2)]
        [string]$BoxTrashedItemType)
        Write-Debug "Get-BoxUserTrashItemDetails $BoxUserID $BoxTrashID $BoxTrashedItemType"
        $BoxTrashedItem = box trash:get $BoxTrashedItemType $BoxTrashID --as-user=$BoxUserID --json | ConvertFrom-Json
        Return $BoxTrashedItem
}

#Return list of user's trash contents
Function Get-BoxUserTrashList {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserName)
    Write-Debug "Get-BoxUserTrashList $BoxUserID"
    $UserTrashList = box trash --as-user=$BoxUserID --json | ConvertFrom-Json
    $UserEmail = $BoxUserName + $EmailDomain
    $TrashListOutput = @()
    $TrashItemOutput = [PSCustomObject]@{
        Name = ""
        Owner = ""
        Type = ""
        ID = ""
        Size = ""
        ParentID = ""
        ParentName = ""
        TrashedDate = ""
    }
    foreach ($TrashItem in $UserTrashList) {
        #Write-Debug $TrashItem
        $TrashItemOutput = [PSCustomObject]@{
            Name = ""
            Owner = ""
            Type = ""
            ID = ""
            Size = ""
            ParentID = ""
            ParentName = ""
            TrashedDate = ""
        }
        $TrashItemDetails = Get-BoxUserTrashItemDetails -BoxUserID $BoxUserID -BoxTrashID $TrashItem."id" -BoxTrashedItemType $TrashItem."type"
        #Write-Debug $TrashItemDetails
        #Write-Debug $TrashItemDetails.owned_by.login
        $TrashItemOutput.Name = $TrashItemDetails.name
        $TrashItemOutput.Owner = $TrashItemDetails.owned_by.login
        $TrashItemOutput.Type = $TrashItemDetails.type
        $TrashItemOutput.ID = $TrashItemDetails.id
        $TrashItemOutput.Size = $TrashItemDetails.size
        $TrashItemOutput.TrashedDate = $TrashItemDetails.trashed_at
        if ($null -ne $TrashItemDetails.parent) {
            $TrashItemOutput.ParentID = $TrashItemDetails.parent.id
            $TrashItemOutput.ParentName = $TrashItemDetails.parent.name
        }
        $TrashListOutput += $TrashItemOutput
    }

    Return $TrashListOutput
}

#Return list of Box user trash items
Function Get-BoxUserTrashListV2 {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserTrashListV2 $BoxUserName $BoxUserID"
    $BoxTrashListRequestURL = "https://api.box.com/2.0/folders/trash/$BoxFolderID/items?fields=id,type,name,owned_by,size,trashed_at,parent`"&`"limit=1000"
    $BoxUserTrashListReturn = box request $BoxTrashListRequestURL --as-user=$BoxUserID --json | ConvertFrom-Json
    $BoxUserTrashList = $BoxUserTrashListReturn.body.entries
    $TrashListOutput = @()
    $TrashItemOutput = [PSCustomObject]@{
        Name = ""
        Owner = ""
        Type = ""
        ID = ""
        Size = ""
        ParentID = ""
        ParentName = ""
        TrashedDate = ""
    }
    foreach ($BoxUserTrashItem in $BoxUserTrashList) {
        $TrashItemOutput.Name = $BoxUserTrashItem.name
        $TrashItemOutput.Owner = $BoxUserTrashItem.owned_by.login
        $TrashItemOutput.Type = $BoxUserTrashItem.type
        $TrashItemOutput.ID = $BoxUserTrashItem.id
        $TrashItemOutput.Size = $BoxUserTrashItem.size
        $TrashItemOutput.ParentID = $BoxUserTrashItem.parent.id
        $TrashItemOutput.ParentName = $BoxUserTrashItem.parent.name
        $TrashItemOutput.TrashedDate = $BoxUserTrashItem.trashed_at
        $TrashListOutput += $TrashItemOutput
    }
    Return $TrashListOutput
}

#Empty trash for a Box user.  Only deletes items that were owned by the user.
Function Empty-BoxUserTrash {
        Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserName)

    Write-Debug "Empty-BoxUserTrash $BoxUserID $BoxUserName"
    $UserEmail = $BoxUserName + $EmailDomain
    $BoxUserTrashList = Get-BoxUserTrashList -BoxUserID $TestUserID -BoxUserName $BoxUserName

    #Go through each item in this user's trash and delete if the user is the owner
    foreach ($BoxUserTrashItem in $BoxUserTrashList) {
        Write-Debug $BoxUserTrashItem
        if ($BoxUserTrashItem.Owner -eq $UserEmail) {
            #Write to output that we're deleting this item
            Delete-BoxUserTrashItem -BoxUserID $BoxUserID -BoxUserName $BoxUserName -BoxTrashItemID $BoxUserTrashItem.id -BoxTrashItemType $BoxUserTrashItem.type
        }
    }

}

#Delete an item out of Box trash
Function Delete-BoxUserTrashItem {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=2)]
        [string]$BoxTrashItemID,
        [Parameter(Mandatory=$true,Position=3)]
        [string]$BoxTrashItemType)

    Write-Debug "Delete-BoxUserTrashItem $BoxUserID $BoxUserName $BoxTrashItemID $BoxTrashItemType"
    $BoxTrashDeleteReturn = box trash:delete $BoxTrashItemType $BoxTrashItemID --as-user=$BoxUserID --json | ConvertFrom-Json
    Return $BoxTrashDeleteReturn
}

#Return the total size of a user's file storage
Function Get-BoxUserAccountSize {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserStorageSize $BoxUserName $BoxUserID"

}

#Return the total size of a user's trash storage
Function Get-BoxUserTrashSize {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserTrashSize $BoxUserName $BoxUserID"
    $UserBoxTrashList = Get-BoxUserTrashListV2 -BoxUserID $BoxUserID -BoxUserName $BoxUserName

    $UserTrashSize = 0
    #Go through each trash item in the trash list and count the total size
    foreach ($TrashItem in $UserBoxTrashList) {
        Write-Debug $TrashItem.name #$TrashItem.size
        $UserTrashSize += $TrashItem.size
    }

    Return $UserTrashSize
}

#Export 
Function Export-BoxUserFolders {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true,Position=2)]
        [string]$FilePath)
    Write-Debug "Export-BoxUserFolders $BoxUserName $BoxUserID $FilePath"

    $ReportRun = "Get-BoxUserFolders"
    $FileTimestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $OutputFile = "$FolderPath$BoxUserName-$ReportRun-$FileTimeStamp.csv"
    $BoxUserFolders = Get-BoxUserFolders -BoxUserName $BoxUserName -BoxUserID $BoxUserID
    $BoxUserFolders | Export-Csv -Path $OutputFile
    Return $BoxUserFolders
}

#Deactivate a single Box user
Function Deactivate-BoxUser {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Deactivate-BoxUser $BoxUserName $BoxUserID"
    $UserDeactivationReturn = box users:update $BoxUserID --status=inactive --json | ConvertFrom-Json
    Write-Debug $UserDeactivationReturn
    Return $UserDeactivationReturn
}

#Activate a single Box user
Function Activate-BoxUser {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserName,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Activate-BoxUser $BoxUserName $BoxUserID"
    $UserActivationReturn = box users:update $BoxUserID --status=active --json | ConvertFrom-Json
    Write-Debug $UserActivationReturn
    Return $UserActivationReturn
}

#Deactivate a list of Box users passed in as an array of objects
Function Deactivate-BoxUserList {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [object[]]$BoxUserList)
    $UserCount = $BoxUserList.Length
    Write-Debug "Deactivate-BoxUserList $UserCount Users"
    $BoxUserListDeactivateReturn = @()
    foreach ($BoxUser in $BoxUserList) {
        $BoxUserDeactivateReturn = Deactivate-BoxUser -BoxUserID $BoxUser.BoxUserID -BoxUserName $BoxUser.BoxUserName
        $BoxUserListDeactivateReturn += $BoxUserDeactivateReturn
    }
    Return $BoxUserListDeactivateReturn
}

Function Create-BoxGroup {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxGroupName,
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateSet("admins_only","admins_and_members","all_managed_users")]
        [string]$BoxGroupInvite = "admins_only",
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet("admins_only","admins_and_members","all_managed_users")]
        [string]$BoxGroupMemberView = "admins_only")
    
    Write-Debug "Create-BoxGroup"
    $GroupCreationReturn = box groups:create --invite=$BoxGroupInvite --view-members=$BoxGroupMemberView $BoxGroupName --json | ConvertFrom-Json
    Return $GroupCreationReturn
}

Function Add-UserListToBoxGroup {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [object[]]$BoxUserList,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxGroupID,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet("member","admin")]
        [string]$BoxGroupRole = "member")
    
    Write-Debug "Add-UserListToBoxGroup"
    if ($BoxGroupRole -eq "admin") {
        $BoxGroupAdminPermission = "--no-can-create-accounts --no-can-edit-accounts --no-can-instant-login --no-can-run-reports"
    }
    foreach ($BoxUserName in $BoxUserList) {
        $BoxUserID = Get-BoxUserID -BoxUserName $BoxUserName
        Write-Debug "Adding $BoxUserName $BoxUserID to group $BoxGroupID"
        if ($BoxGroupRole -eq "admin") {
            box groups:memberships:add --role=$BoxGroupRole --no-can-create-accounts --no-can-edit-accounts --no-can-instant-login --no-can-run-reports $BoxUserID $BoxGroupID --json | ConvertFrom-Json
        }
        else {
            box groups:memberships:add --role=$BoxGroupRole $BoxUserID $BoxGroupID --json | ConvertFrom-Json
        }
    }
}

#Dev values
$DebugPreference = 'Continue'
$EmailDomain = "" # @domain.com
$OutputFolder = ""

#Test values
$BoxUserName = "" # A Box username
$BoxUserName2 = ""
$BoxUserName3 = ""
$BoxUserName4 = ""
$BoxGroupName = ""
$SharedOwnedFolderID = ""
$SharedFolderID = ""
$NonsharedFolderID = ""
$SharedOwnedFileID = ""
$SharedFileID = ""
$NonsharedFileID = ""
$OwnedTrashFileID = ""
$NonOwnedTrashFileID = ""
$OwnedTrashFolderID = ""
$NonOwnedTrashFolderID = ""

$TestUserID = Get-BoxUserID -BoxUserName $BoxUserName

#Test Create-BoxGroup and Add-UserListToBoxGroup
<#
for ($i=1; $i -le 30; $i++){
    if ($i -lt 10) {
        $num = "0" + $i.ToString()
    }
    else {
        $num = $i.ToString()
    }
    
    $BoxGroupName = $BoxGroupTestName + $num
    #>
    $BoxUserList = @($BoxUserName, $BoxUserName2, $BoxUserName3, $BoxUserName4)

    $BoxGroupCreateReturn = Create-BoxGroup -BoxGroupName $BoxGroupName
    $BoxGroupCreateReturn
    Add-UserListToBoxGroup -BoxUserList $BoxUserList -BoxGroupID $BoxGroupCreateReturn.id -BoxGroupRole admin
#}

<#
#Test Deactivate-BoxUser and Activate-BoxUser
if ($BoxUserName -ne "Brad_Hodges") {
    $DeactivationReturn = Deactivate-BoxUser -BoxUserID $TestUserID -BoxUserName $BoxUserName
    $DeactivationReturn
    $ActivationReturn = Activate-BoxUser -BoxUserID $TestUserID -BoxUserName $BoxUserName
    $ActivationReturn
}
#>

<#
#Test Get-BoxUserTrashListV2
$BoxUserTrashList = Get-BoxUserTrashListV2 -BoxUserID $TestUserID -BoxUserName $BoxUserName
$BoxUserTrashList #| ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
$BoxUserTrashList.Length
#>

<#
#Test Get-BoxUserTrashSize
$BoxUserTrashSize = Get-BoxUserTrashSize -BoxUserID $TestUserID -BoxUserName $BoxUserName
$BoxUserTrashSize
#>

<#
#Test Delete-BoxUserTrashItem
#$BoxDeleteTrashItemReturn = Delete-BoxUserTrashItem -BoxUserID $TestUserID -BoxUserName $BoxUserName -BoxTrashItemID $OwnedTrashFileID -BoxTrashItemType "file"
$BoxDeleteTrashItemReturn = Delete-BoxUserTrashItem -BoxUserID $TestUserID -BoxUserName $BoxUserName -BoxTrashItemID $OwnedTrashFolderID -BoxTrashItemType "folder"
$BoxDeleteTrashItemReturn
#>

<#
#Test Get-BoxUserTrashList
$BoxUserTrash = Get-BoxUserTrashList -BoxUserID $TestUserID -BoxUserName $BoxUserName
$BoxUserTrash | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
$BoxUserTrash.Length
#>


#Test Export-BoxUserFolders
#Export-BoxUserFolders -BoxUserName $BoxUserName -BoxUserID $TestUserID -FilePath $OutputFolder


<#
#Test Get-BoxUserFolders
$BoxOwnedFolders = Get-BoxUserFolders -BoxUserName $BoxUserName -BoxUserID $TestUserID
$BoxOwnedFolders | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
$BoxOwnedFolders | Export-Csv -Path $OutputFile
$BoxOwnedFolders | ForEach {[PSCustomObject]$_.owner} | Format-Table -AutoSize
$BoxOwnedFolders.Length
#>