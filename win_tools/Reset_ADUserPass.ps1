<#
This script will help you to change the password of the account in specified domain
If you get an question please contact Edo Zhao (v-edz)
#>


Param ($Account,$domain)
if ($Account -eq $Null)
{
$Account = read-host "Please Input the Account"
}
if ($domain -eq $Null)
{
$domain=read-host "Please Input the Doamin"
}

#verify account info
Try{
$accInfo= Get-ADUser -Identity $Account -Server $domain
}
catch{
write-host "Account:$Account in Domain:$domain, Verification failed." -ForegroundColor red
write-host "Please confirm the account or domain name." -ForegroundColor red
write-host "Error Message:" -ForegroundColor darkgray
write-host $error[0] -ForegroundColor darkgray
break;
}

write-host "Account:$Account in Domain:$domain,Verified successfully AD Info:" -ForegroundColor green
"$accInfo" |out-string | write-host -ForegroundColor green

$IsReset= Read-Host "Do you want to change the password of $Account in Domain:$domain ? Yes/No"

#reset perform
if ($IsReset -eq "Yes")
{
$oldPass=Read-Host "Please input the current password of Account:$Account"
$newPass=Read-Host "Please copy the new password to here"
if ($newPass -ine $null)
{
"The new password you just input is:" | write-host -ForegroundColor yellow
"$newPass" | write-host -ForegroundColor yellow
$confirmNew= read-host "Continue? Yes/No"
if ($confirmNew -eq "Yes")
{
try{
Set-ADAccountPassword -Identity $Account -OldPassword (ConvertTo-SecureString -AsPlainText "$oldPass" -Force) -NewPassword (ConvertTo-SecureString -AsPlainText "$newPass" -Force) -Server $domain
}
catch {
write-host "Password change process met exception." -ForegroundColor red
write-host $error[0] -ForegroundColor darkgray
break;
}
"The password of $Account in Domain:$domain, has been set to:" | write-host -ForegroundColor green
"$newPass" | write-host -ForegroundColor green
$outputFile=".\$Account"+".txt"
$output="$newPass"
$output > $outputFile
"You can also backup the new password in file: $outputFile" | write-host -ForegroundColor darkgray
"Please don't forget to delete $outputFile after backup." | write-host -ForegroundColor darkgray
$time=get-date 
$time | write-host -ForegroundColor darkgray

}
else{
write-host "Didn't get confirm from user, no change was performed." -ForegroundColor yellow
break;
}
}
else {
write-host "The new password you just input was null." -ForegroundColor yellow
}

}
else{
write-host "Didn't get confirm from user, no change was performed." -ForegroundColor yellow
break;
}