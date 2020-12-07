
Function get-randompwd ()
{
    param(
    [Parameter(Mandatory=$true)][ValidateRange(1,128)][int]$Lenght
    )
    Add-Type -AssemblyName System.Web
    $PassComplexCheck = $false
    $start = get-date
    $timeout = 5 #seconds
    do {
        $newPassword=[System.Web.Security.Membership]::GeneratePassword($Lenght,1)
        If ( ($newPassword -cmatch "[A-Z\p{Lu}\s]") `
            -and ($newPassword -cmatch "[a-z\p{Ll}\s]") `
            -and ($newPassword -match "[\d]") `
            -and ($newPassword -match "[^\w]")
            ){
                $PassComplexCheck = $True
            }else{
                $newPassword = $null
            }
            if(($(get-date) - $start).TotalSeconds -ge $timeout){
                "not be able to generate a password match complex until timeout: $timeout seconds." |write-error
                break
            }
    } While ($PassComplexCheck -eq $false)
    return ($newPassword.replace('$','@'))
}

function Create-NewLocalAdmin {
    [CmdletBinding()]
    param(
        [string]$NewLocalAdmin,
        [string]$Password,
        [double]$Active_minutes
    )
    $expire_date = $(get-date).AddMinutes($Active_minutes)
    $secure_pass = ConvertTo-SecureString -String $Password -AsPlainText -Force
    New-LocalUser "$NewLocalAdmin" -Password $secure_pass -FullName "$NewLocalAdmin" -AccountExpires $expire_date -PasswordNeverExpires -Description "Temporary local admin"
    Write-Verbose "$NewLocalAdmin local user crated"
    Add-LocalGroupMember -Group "Administrators" -Member "$NewLocalAdmin"
    Write-Verbose "$NewLocalAdmin added to the local administrator group"

}
$NewLocalAdmin = Read-Host "New local admin username:"
$Password = Read-Host -AsSecureString "Create a password for $NewLocalAdmin"
Create-NewLocalAdmin -NewLocalAdmin $NewLocalAdmin -Password $Password -Verbose
