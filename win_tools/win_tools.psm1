
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
    return $newPassword
}
