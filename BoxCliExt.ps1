#Powershell module to extend functionality of the Box CLI interface for reporting and admin functions.
#Brad Hodges 2020

#Dev values
$UserBearID = "Brad_hodges"

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
    $BoxUserFolders = box folders:get $BoxFolderID --as-user=$BoxUserID --json | ConvertFrom-Json
    $BoxUserFolderList = $BoxUserFolders."item_collection"."entries"
    Return $BoxUserFolderList
}

#Get collaborations on a folder
Function Get-BoxUserFolderCollaboration {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID, 
        [Parameter(Mandatory=$true,Position=1)]
        [string]$BoxFolderID)
    $BoxFolderCollaboration = box folders:collaborations $BoxFolderID --as-user=$BoxUserID --json | ConvertFrom-Json
    Return $BoxFolderCollaboration
}

Function Get-BoxUserRootFolders {
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$BoxUserID)
    $BoxFolders = Get-BoxFolderList -BoxUserID $BoxUserID -BoxFolderID "0"
    Return $BoxFolders
}

Function Get-BoxUserOwnedFolders {
    Param (
    [Parameter(Mandatory=$true,Position=0)]
    [string]$UserBearID)
    $BoxUserID = Get-BoxUserID -UserBearID $UserBearID
    $BoxFolders = Get-BoxUserRootFolders -BoxUserID $BoxUserID
    $i = 0
    $BoxFoldersOutputList = @()
    $BoxFolderOutput = [PSCustomObject]@{
        FolderName = ""
        ID = ""
        Owner = ""
    }
    Foreach ($BoxFolder in $BoxFolders) {
        #$BoxFolderID = $BoxFolder.id
        #$BoxFolder.name
        $BoxFolderOutput.FolderName = $BoxFolder.name
        $BoxFolderOutput.ID = $BoxFolder.id
        $BoxFolderOutput.Owner = $UserBearID + "@baylor.edu"
        #Create array of objects that are this user's owned folders
        $BoxFolderCollaborations = Get-BoxUserFolderCollaboration -BoxUserID $BoxUserID -BoxFolderID $BoxFolder.id
        foreach ($BoxFolderCollaboration in $BoxFolderCollaborations) {
            $BoxFolderCollaboration.accessible_by.login
            $BoxFolderCollaboration.role
            if ($BoxFolderCollaboration.accessible_by.login -eq ($UserBearID + "@baylor.edu")) {
                $BoxFolderOutput.Owner = ""
            }
        }
        $BoxFoldersOutputList += $BoxFolderOutput
        $i += 1
    }
    Return $BoxFolderOutputList
}

$BoxUserID = Get-BoxUserID -UserBearID $UserBearID
#$BoxFolders = Get-BoxUserRootFolders -BoxUserID $BoxUserID
$BoxFolderOutputList = Get-BoxUserOwnedFolders -UserBearID $UserBearID
$BoxFolderOutputList

<#
Foreach ($BoxFolder in $BoxFolders) {
    $BoxFolderID = $BoxFolder.id
    $BoxFolderCollaboration = Get-BoxUserFolderCollaboration -BoxUserID $BoxUserID -BoxFolderID $BoxFolderID
    $BoxFolderCollaboration
}

<#
$BoxUserFolder = $BoxUserFolderList[3]
#foreach ($BoxUserFolder in $BoxUserFolderList) {
    $BoxUserFolderID = $BoxUserFolder."id"
    $BoxUserFolderID
    $BoxUserFolderName = $BoxUserFolder."name"
    $BoxUserFolderName
    $BoxUserFolderCollaborations = box folders:collaborations $BoxUserFolderID --as-user=$BoxUserID --json | ConvertFrom-Json
    $BoxUserFolderCollaborations
#}

#>