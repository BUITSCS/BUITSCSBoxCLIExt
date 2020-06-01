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

#Get Box userID
Function Get-BoxUserID {
    Param (
            [Parameter(Mandatory=$true,Position=0)]
            [string]$UserBearID)
    Write-Debug "Get-BoxUserID $UserBearID"
    $BoxUser = box users --filter=$UserBearID --json | ConvertFrom-Json
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
    $BoxFolderRequestURL = "https://api.box.com/2.0/folders/$BoxFolderID/items?fields=owned_by,name,size`"&`"limit=10000"
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
        [string]$UserBearID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserFolders $UserBearID $BoxUserID"
    $BoxFolders = Get-BoxUserRootFolders -BoxUserID $BoxUserID
    $BoxFoldersOutputList = @()
    $BoxUserFoundInList = $False
    $UserEmail = $UserBearID + $EmailDomain
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
        [string]$UserBearID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserFoldersFullCollab $UserBearID $BoxUserID"
    $BoxFolders = Get-BoxUserRootFolders -BoxUserID $BoxUserID
    $BoxFoldersOutputList = @()
    $BoxFolderCollaboratorList = @()
    $BoxUserFoundInList = $False
    $UserEmail = $UserBearID + $EmailDomain
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
        [string]$UserBearID)
    Write-Debug "Get-BoxUserTrashList $BoxUserID"
    $UserTrashList = box trash --as-user=$BoxUserID --json | ConvertFrom-Json
    $UserEmail = $UserBearID + $EmailDomain
    $TrashListOutput = @()
    $TrashItemOutput = [PSCustomObject]@{
        Name = ""
        Owner = ""
        Type = ""
        ID = ""
        Size = ""
        FolderItems = ""
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

#Empty trash for a Box user.  Only deletes items that were owned by the user.
Function Empty-BoxUserTrash {
        Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$UserBearID)

    Write-Debug "Empty-BoxUserTrash $BoxUserID $UserBearID"
    $UserEmail = $UserBearID + $EmailDomain
    $BoxUserTrashList = Get-BoxUserTrashList -BoxUserID $TestUserID -UserBearID $UserBearID

    #Go through each item in this user's trash and delete if the user is the owner
    foreach ($BoxUserTrashItem in $BoxUserTrashList) {
        Write-Debug $BoxUserTrashItem
        if ($BoxUserTrashItem.Owner -eq $UserEmail) {
            #Write to output that we're deleting this item
            Delete-BoxUserTrashItem -BoxUserID $BoxUserID -UserBearID $UserBearID -BoxTrashItemID $BoxUserTrashItem.id -BoxTrashItemType $BoxUserTrashItem.type
        }
    }

}

#Delete an item out of Box trash
Function Delete-BoxUserTrashItem {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$UserBearID,
        [Parameter(Mandatory=$true,Position=2)]
        [string]$BoxTrashItemID,
        [Parameter(Mandatory=$true,Position=3)]
        [string]$BoxTrashItemType)

    Write-Debug "Delete-BoxUserTrashItem $BoxUserID $UserBearID $BoxTrashItemID $BoxTrashItemType"
    $BoxTrashDeleteReturn = box trash:delete $BoxTrashItemType $BoxTrashItemID --as-user=$BoxUserID --json | ConvertFrom-Json
    Return $BoxTrashDeleteReturn
}

#Dev values
#$DebugPreference = 'Continue'
$EmailDomain = "@baylor.edu"
#$UserBearID = "joshua_ogden"
#$TestUserID = "211497569" #joshua_ogden ID
#$UserBearID = "Allen_Page"
#$TestUserID = "12646907509" #allen_page ID
$UserBearID = "Chelsea_Lin1"
$TestUserID = "3916309915" #chelsea_lin1 ID
#$UserBearID = "Gina_Green"
#$TestUserID = "227157899" #Gina_Green ID (58 items in trash list in admin console 5/28)
#$UserBearID = "Brad_Hodges"
#$TestUserID = "203020963" #Brad_Hodges ID
#$UserBearID = "Madeline_Todd"
#$TestUserID = "235548264" #Madeline_Todd ID
$SharedOwnedFolderID = "51629651991" #Folder name: test
$SharedFolderID = "8342900509" #Folder name: Application Services Group
$NonsharedFolderID = "1802641245" #Folder name: Grad School
$SharedOwnedFileID = "" #File name: 
$SharedFileID = "646461273328" #File name: macOS 10.15.4 GPU freezing issue.csv
$NonsharedFileID = "647259224879" #File name: macOS 10.15.4 GPU freezing issue.xlsx
$OwnedTrashFileID = "267052929086" #File name: Hands presents.png User: Madeline_Todd
$NonOwnedTrashFileID = "" #File name:  User: Madeline_Todd
$OwnedTrashFolderID = "21697728072" #Folder name: Downloads  User: Madeline_Todd
$NonOwnedTrashFolderID = "" #File name:  User: Brad_Hodges

<#
#$BoxDeleteTrashItemReturn = Delete-BoxUserTrashItem -BoxUserID $TestUserID -UserBearID $UserBearID -BoxTrashItemID $OwnedTrashFileID -BoxTrashItemType "file"
$BoxDeleteTrashItemReturn = Delete-BoxUserTrashItem -BoxUserID $TestUserID -UserBearID $UserBearID -BoxTrashItemID $OwnedTrashFolderID -BoxTrashItemType "folder"
$BoxDeleteTrashItemReturn

$BoxUserTrash = Get-BoxUserTrashList -BoxUserID $TestUserID -UserBearID $UserBearID
$BoxUserTrash | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
$BoxUserTrash.Length
#>

$BoxOwnedFolders = Get-BoxUserFolders -UserBearID $UserBearID -BoxUserID $TestUserID
$BoxOwnedFolders | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
$BoxOwnedFolders.Length
