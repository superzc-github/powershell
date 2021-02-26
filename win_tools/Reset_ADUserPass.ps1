#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
MS AD user password reset tool.
.DESCRIPTION
This script will help you to reset the password of the account in specified AD domain and then there's a optional step for the new password verification
.INPUTS
  N/A
.OUTPUTS
  New password will export to file stored in .\<Account string you input>.txt"
.NOTES
  Author:         ZHAO Chen
.EXAMPLE
  .\Reset_ADUserPass.ps1 -Account "xxxx" -domain "xxxx"
  .\Reset_ADUserPass.ps1 -Account "xxxx" -domain "xxxx" -verify_only True
#>


#####################
#----Param Block----#
#####################
Param (
        #AD user account you want to reset
        $Account,
        #AD domain name your account located
        $domain,
        #Whether only perform credential verification and skip other
        [ValidateSet($true,$false)]
        $verify_only=$false)

########################
#----Function Block----#
########################

#function for AD user password udpate
function verify_cred(){
    param($account,$domain)
    $verfy = Get-ADDomain -Credential $(Get-Credential -UserName "$domain\$account" -Message "Input Password For $domain\$account to Verify") -ErrorAction SilentlyContinue -ErrorVariable ad_err
    if ($ad_err -ine $null){
        write-host "The input credential is not correct." -ForegroundColor red
    }else{
        write-host "The input credential is working well." -ForegroundColor green
    }
}

#function for ad user credential verification
function reset_ADpswd(){
    param($Account,$domain,$oldPass,$newPass)
    try{
        Set-ADAccountPassword -Identity $Account -OldPassword $oldPass -NewPassword $newPass -Server $domain
    }
    catch {
        write-host "Password update process met exception." -ForegroundColor red
        write-host $error[0] -ForegroundColor darkgray
        exit 1
    }
    "The password of $Account in Domain:$domain, has been changed." | write-host -ForegroundColor green
}


#########################
#----Execution Block----#
#########################
if($verify_only -notlike "true"){    
    if ($Account -eq $Null){
        $Account = read-host "Please Input the Account"
    }
    if ($domain -eq $Null){
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
        exit 1;
    }

    write-host "Account:$Account in Domain:$domain,Verified successfully AD Info:" -ForegroundColor green
    "$accInfo" |out-string | write-host -ForegroundColor green

    #password reset processes
    $IsReset= Read-Host "Do you want to change the password of $Account in Domain:$domain ? Yes/No"
    if ($IsReset -eq "Yes"){
        $oldPass=Read-Host -AsSecureString "Please input the CURRENT password of Account:$Account"
        $newPass=Read-Host -AsSecureString "Please copy the NEW password here"
        if ($newPass -ine $null){
            $confirmNew= read-host "Continue? Yes/No"
            if ($confirmNew -eq "Yes"){
                reset_ADpswd $Account $domain $oldPass -newPass $newPass
                $decrypted_new = [System.Net.NetworkCredential]::new("", "$newPass").Password
                "$decrypted_new" | write-host -ForegroundColor green
                $outputFile=".\$Account"+".txt"
                "$decrypted_new" |out-file $outputFile
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
    $run_verify = read-host "Do you need to verify the new password? Yes/No"
}

#password verification
if ($run_verify -notlike "No"){
    verify_cred $Account $domain
}