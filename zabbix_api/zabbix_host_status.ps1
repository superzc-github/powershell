<#
.SYNOPSIS
  Zabbix Host Monitoring Switch
.DESCRIPTION
  Use this script to enable\disable zabbix host's monitoring per group via zabbix API calls.
.INPUTS
  None, you cannot pipe objects
.OUTPUTS
  None, dont have output files
#>


###########################
#-----Parameter Block-----#
###########################
[CmdletBinding()] #make sure script can use PS common parameters for display verbose logs
param (
    #Action run to zabbix for enable(unsuppress)\disable(suppress) monitoring.
    #Input options: "suppress","unsuppress","query".
    [validateset("suppress","unsuppress","query")][string]$Action,
    #The zabbix group(environment) name you will run to.
    [string]$zabbix_group,
    #The user name using for zabbix API calls.
    [string]$zabbix_user,
    #The password using for zabbix API calls.
    [string]$zabbix_pass,
    #The zabbix API url you will call.
    [string]$zabbix_api_url
)
$action = $Action.ToUpper()


##########################
#-----Function Block-----#
##########################

#function to print general outputs
function logit(){
    param(
        $inputs,
        [string]$color="white"
    )
    if($inputs -eq $null){
        $inputs=''
    }
    if(($inputs.GetType()).Name -like "String"){
        $output = "[$(get-date)] " + $inputs
    }else{
        $output = @("[$(get-date)] ",($inputs |out-string))
    }
    $output |out-string | write-host -ForegroundColor $color
}

#function to print verbose outputs\information for debug
function verbose_log(){
    param(
        $inputs
    )
    if($inputs -eq $null){
        $inputs=''
    }
    if(($inputs.GetType()).Name -like "*String*"){
        $output = "[$(get-date)] " + $inputs
    }else{
        $output = @("[$(get-date)] ",($inputs |out-string))
    }
    $output |out-string | Write-verbose
}

#function for making zabbix API call and return result
function zabbix_api(){
    param(
        [string]$zabbix_api_url,
        $req_body_json
    )
    $response = Invoke-WebRequest -uri "$zabbix_api_url" -Headers @{"Content-Type" = "application/json"} -method POST -body $req_body_json
    return ($response | ConvertFrom-Json).result
}

#function for zabbix session token fetching via zabbix API
function zabbix_auth(){
    param(
        [string]$zabbix_user,
        [string]$zabbix_pass,
        [string]$zabbix_api_url
    )
    $req_body =  @{
        "jsonrpc"= "2.0"
        "method"= "user.login"
        "params"= @{
            "user"= $zabbix_user
            "password"= $zabbix_pass
        }
        "id"= 1
    } | ConvertTo-Json -Depth 5
    $token = zabbix_api -zabbix_api_url "$zabbix_api_url" -req_body_json $req_body
    return $token
}

function zabbix_logout(){
    param(
        [string]$token,
        [string]$zabbix_api_url
    )
    $req_body =  @{
        "jsonrpc"= "2.0"
        "method"= "user.logout"
        "params"= @{}
        "auth" = $token
        "id"= 1
    } | ConvertTo-Json -Depth 5
    $token = zabbix_api -zabbix_api_url "$zabbix_api_url" -req_body_json $req_body
    return $token
}

#function for get hosts information list via zabbix API
function zabbix_get-host(){
    param(
        [string]$token,
        [string]$zabbix_api_url,
        [string]$hostname
    )
    $req_body =  @{
        "jsonrpc"= "2.0"
        "method"= "host.get"
        "params"= @{
            output = "extend"
            selectGroups = "extend"
        }
        "auth" = $token
        "id"= 2
    } | ConvertTo-Json -Depth 5
    $hosts = zabbix_api -zabbix_api_url "$zabbix_api_url" -req_body_json $req_body
    return $hosts
}

#function for enable\disable monitoring of zabbix hosts via zabbix API
function zabbix_switch(){
    param(
        [string]$token,
        [string]$action,
        [string]$zabbix_api_url,
        [array]$hostids
    )
    switch($action){
        'suppress' { $status = 1 }
        'unsuppress' { $status = 0 }
    }
    $hostids_json = $hostids |%{@{'hostid'= $_} }
    $req_body =  @{
        "jsonrpc"= "2.0"
        "method"= "host.massupdate"
        "params"= @{
            hosts = $hostids_json
            status = $status
        }
        "auth" = $token
        id = 1
    } | ConvertTo-Json -Depth 5
    $hosts = zabbix_api -zabbix_api_url "$zabbix_api_url" -req_body_json $req_body
    return $hosts
}


###########################
#-----Execution Block-----#
###########################

#init exit code variable at begaining
$ext_code = 0

#zabbix operations start
logit "Getting zabbix token for API calls..." 'darkgray'
$zabbix_token = zabbix_auth -zabbix_user $zabbix_user -zabbix_pass $zabbix_pass -zabbix_api_url $zabbix_api_url
if (($zabbix_token |out-string).trim() -notlike ""){
    logit "Fetch $zabbix_group group host list from zabbix..." 'darkgray'
    $get_zabbix_hosts = zabbix_get-host -token $zabbix_token -zabbix_api_url $zabbix_api_url | ? {$_.groups.name -contains $zabbix_group}
    if($action -like "query"){
        logit ($get_zabbix_hosts |select host,@{n='enabled';e={switch($_.status){0 {"true"} 1 {"false"}}}},hostid,groups)
    }else{
        if (($get_zabbix_hosts |out-string).trim() -notlike ""){
            verbose_log "Fetched zabbix hosts:"
            verbose_log ($get_zabbix_hosts |select host,status,hostid,groups)
            logit "Suppressing fetched zabbix hosts..." 'darkgray'
            $zabbix_switch = zabbix_switch -token $zabbix_token -action $Action -zabbix_api_url $zabbix_api_url -hostids $get_zabbix_hosts.hostid
            verbose_log "Suppressed hostsid:"
            verbose_log "$($zabbix_switch.hostids)"
            logit "$Action job done, will logout from zabbix..." 'darkgray'
            $zabbix_logout = zabbix_logout $zabbix_token $zabbix_api_url
            if($zabbix_logout){
                logit "Logout succeeded." 'darkgray'
            }else{
                logit "Can't logout, it will auto logout when session expire..." 'darkgray'
            }
            logit "Analyzing Zabbix $Action result..." 'darkgray'
            $success_hosts = ($get_zabbix_hosts |?{$zabbix_switch.hostids -contains $_.hostid}).host
            $failed_hosts = ($get_zabbix_hosts |?{$zabbix_switch.hostids -notcontains $_.hostid}).host
            logit "Zabbix $Action has been done for host(s) below:" 'darkgray'
            logit $success_hosts -color 'darkgray'
            if ($failed_hosts -ine $null){
                logit "[WARNINIG]Zabbix $Action got failures with below hosts:" 'red'
                logit $failed_hosts 'red'
                $ext_code = 1
            }else{
                logit "[DONE]Zabbix $Action done." 'green'
            }
        }else{
            logit "[ERROR]Fetched $zabbix_group environment host list is null, can't continue" 'red'
        }
    }
}else{
    logit "[ERROR]Fetched zabbix token is null, can't continue." 'red'
    $ext_code = 1
}

#summary script result with exit code
if ($ext_code -ine 0){
    logit "[FAILED]Zabbix $Action job got failure." 'red'
}else{
    logit "[SUCCESS]Zabbix $Action job successed." 'green'
}
verbose_log "exit code: $ext_code"

exit $ext_code
