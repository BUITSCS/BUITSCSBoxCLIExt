#Powershell module to extend functionality of the Box CLI interface for reporting and admin functions.
#Brad Hodges 2020

#Dev values
$UserBearID = "Kathy_Reich"

#Check for functional Box CLI

#Get Box user
$BoxUser = box users --filter=$UserBearID
$BoxUserID = $BoxUser["id"]

#Report on user folders
$BoxUserFolders = box folders:get 0 --as-user=$BoxUserID
$BoxUserFolders
