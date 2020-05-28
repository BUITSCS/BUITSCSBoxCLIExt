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

#Get list of Box subfolders.  Pass in 0 for $BoxFolderID to get root folder of a user
Function Get-BoxFolderList {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$BoxFolderID)
    Write-Debug "Get-BoxFolderList $BoxUserID $BoxFolderID"
    $BoxUserFolders = box folders:get $BoxFolderID --as-user=$BoxUserID --json | ConvertFrom-Json
    $BoxUserFolderList = $BoxUserFolders."item_collection"."entries"
    Write-Debug $BoxUserFolderList[3]
    Return $BoxUserFolderList
}

#Get collaborations on a folder
Function Get-BoxUserFolderCollaboration {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID, 
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxFolderID)
    Write-Debug "Get-BoxUserFolderCollaboration $BoxUserID $BoxFolderID"
    $BoxFolderCollaboration = box folders:collaborations $BoxFolderID --as-user=$BoxUserID --json | ConvertFrom-Json
    Return $BoxFolderCollaboration
}

Function Get-BoxUserRootFolders {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID)
    Write-Debug "Get-BoxUserRootFolders $BoxUserID"
    $BoxFolders = Get-BoxFolderList -BoxUserID $BoxUserID -BoxFolderID "0"
    Return $BoxFolders
}

#Return folder names and collaboration levels
#TODO: Add loose files
Function Get-BoxUserFolders {
    Param (
    [Parameter(Mandatory=$true,Position=0)]
    [string]$UserBearID,
    [Parameter(Mandatory=$true,Position=1)]
    [string]$BoxUserID)
    Write-Debug "Get-BoxUserFolders $UserBearID $BoxUserID"
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
        Owner = $False
    }
    Foreach ($BoxFolder in $BoxFolders) {
        if ($BoxFolder.type -eq "folder") {
            $BoxFolderID = $BoxFolder.id
            $BoxFolderCollaborations = Get-BoxUserFolderCollaboration -BoxUserID $BoxUserID -BoxFolderID $BoxFolderID
            $BoxUserFoundInList = $False
            $BoxUserFolderCollabLevel = ""
            $BoxFolderOutput = [PSCustomObject]@{
                Name = ""
                Type = ""
                ID = ""
                CollabLevel = ""
                Owner = $False
            }
            Write-Debug $BoxFolder.name
            #If the collaborations list is null, this is a folder owned by the user that isn't shared.
            if ($null -eq $BoxFolderCollaborations) {
                $BoxFolderOutput.Name = $BoxFolder.name
                $BoxFolderOutput.ID = $BoxFolder.id
                $BoxFolderOutput.Type = "folder"
                $BoxFolderOutput.CollabLevel = "owner"
                $BoxFolderOutput.Owner = $True
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
                    $BoxFolderOutput.Type = "folder"
                    $BoxFolderOutput.CollabLevel = "owner"
                    $BoxFolderOutput.Owner = $True
                    Write-Debug "User isn't found in the list of collaborators for this folder, so they're the owner: $BoxFolderOutput"
                }
                #If this user is found in the list, record their collaboration level
                else {
                    $BoxFolderOutput.Name = $BoxFolder.name
                    $BoxFolderOutput.ID = $BoxFolder.id
                    $BoxFolderOutput.Type = "folder"
                    $BoxFolderOutput.Owner = $False
                    $BoxFolderOutput.CollabLevel = $BoxUserFolderCollabLevel
                    Write-Debug "User found in the list of collaborators for this folder, so they're an invited collaborator: $BoxFolderOutput"
                }
            }
            $BoxFoldersOutputList += $BoxFolderOutput
        }
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
            Write-Debug $TrashItemDetails.parent
            $TrashItemOutput.ParentID = $TrashItemDetails.parent.id
            $TrashItemOutput.ParentName = $TrashItemDetails.parent.name
        }
        $TrashListOutput += $TrashItemOutput
    }

    Return $TrashListOutput
}

#Dev values
$DebugPreference = 'Continue'
$EmailDomain = "@baylor.edu"
#$UserBearID = "joshua_ogden"
#$TestUserID = "211497569" #joshua_ogden ID
#$UserBearID = "Allen_Page"
#$TestUserID = "12646907509" #allen_page ID
#$UserBearID = "Chelsea_Lin1"
#$TestUserID = "3916309915" #chelsea_lin1 ID
$UserBearID = "Brad_Hodges"
$TestUserID = "203020963" #Brad_Hodges ID
$SharedOwnedFolderID = "51629651991" #Folder name: test
$SharedFolderID = "8342900509" #Folder name: Application Services Group
$NonsharedFolderID = "1802641245" #Folder name: Grad School
$SharedOwnedFileID = "" #File name: 
$SharedFileID = "" #File name: 
$NonsharedFileID = "" #File name: 

#$BoxUserTrash = Get-BoxUserTrashList -BoxUserID $TestUserID -UserBearID $UserBearID
#$BoxUserTrash

$BoxOwnedFolders = Get-BoxUserFolders -UserBearID $UserBearID -BoxUserID $TestUserID
$BoxOwnedFolders
