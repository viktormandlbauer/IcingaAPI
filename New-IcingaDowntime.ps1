<#
.SYNOPSIS
This function schedules a downtime for Icinga services or hosts.

.DESCRIPTION
This function schedules a downtime for Icinga services or hosts. It uses the Icinga API to schedule a downtime for the specified hosts and/or services. The function retrieves the Icinga API configuration from the local file system.

.PARAMETER Hostname
Specifies one or more host names for which to schedule the downtime.

.PARAMETER Service
Specifies one or more service names for which to schedule the downtime.

.PARAMETER Servicegroup
Specifies the service group name for which to schedule the downtime.

.PARAMETER Hostgroup
Specifies the host group name for which to schedule the downtime.

.PARAMETER Author
Specifies the author who is scheduling the downtime. The default is the current user.

.PARAMETER Comment
Specifies the comment that describes the reason for the downtime.

.PARAMETER StartTime
Specifies the start time of the downtime. The default is the current time.

.PARAMETER EndTime
Specifies the end time of the downtime. This parameter is mandatory.

.PARAMETER Flexible
Specifies whether the downtime is flexible or not. If the downtime is flexible, the monitoring system will start checking the hosts/services again as soon as possible after the specified end time.

.PARAMETER AllServices
Specifies whether all services should be scheduled for downtime.

.EXAMPLE
PS C:> New-IcingaDowntime -Hostname webserver01,webserver02 -Service HTTP -EndTime (Get-Date).AddHours(2) -Comment "Scheduled maintenance"

This example schedules downtime for the HTTP service on the webserver01 and webserver02 hosts for the next two hours. The comment explains that the downtime is scheduled maintenance.

.EXAMPLE
PS C:> New-IcingaDowntime -Servicegroup DatabaseServices -EndTime (Get-Date).AddHours(4) -Flexible

This example schedules downtime for all services in the DatabaseServices service group for the next four hours. The downtime is flexible.

.NOTES
This function requires that the Icinga API configuration is registered with the Register-IcingaApiEndpoint function. If no Icinga API endpoint is registered, an error is thrown.
#>
function New-IcingaDowntime {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'Filter')]
        [string[]]
        $Hostname,

        [Parameter(ParameterSetName = 'Filter')]        
        [string[]]
        $Service,

        [Parameter(ParameterSetName = 'Servicegroup')]
        [string]
        $Servicegroup,

        [Parameter(ParameterSetName = 'Hostgroup')]
        [string]
        $Hostgroup,

        [string]
        $Author = $env:USERNAME,

        [string]
        $Comment = "Downtime scheduled with powershell module",

        [DateTime]
        $StartTime = (Get-Date),
        
        [Parameter(Mandatory)]
        [DateTime]
        $EndTime,

        [switch]
        $Flexible,

        [switch]
        $AllServices
    )
    BEGIN {
        
        # Retrieve Icinga Api Configuration
        try {
            Write-Verbose "Using $env:APPDATA\IcingaPowershell\IcingaApiEndpoint.xml"
            $ApiEndpointConfig = Import-Clixml "$env:APPDATA\IcingaPowershell\IcingaApiEndpoint.xml"
        }
        catch {
            Write-Error "No Icinga Api Endpoint registered. Use Register-IcingaApiEndpoint to register an endpoint."        
            exit -1
        }

        $IcingaHost = $ApiEndpointConfig.IcingaHost
        $IcingaPort = $ApiEndpointConfig.IcingaPort
        $IcingaUsername = $ApiEndpointConfig.Credentials.UserName
        $IcingaPassword = (New-Object PSCredential 0, $ApiEndpointConfig.Credentials.Password).GetNetworkCredential().Password

        Write-Verbose "Imported Icinga API configuration: "
        Write-Verbose $IcingaHost
        Write-Verbose $IcingaPort
        Write-Verbose $IcingaUsername
        Write-Verbose $IcingaPassword

        # Define Api Endpoint
        $apiEndpoint = "https://$($IcingaHost):$($IcingaPort)/v1/actions/schedule-downtime"
        
        # Timezone handling for Unix Time Epoch
        $timezone = [System.TimeZoneInfo]::Local
        $isDaylightSavingTime = $timezone.IsDaylightSavingTime($StartTime)
        $offset = if ($isDaylightSavingTime) { 2 } else { 1 }
        $StartTime = $StartTime.AddHours(-$offset)
        $isDaylightSavingTime = $timezone.IsDaylightSavingTime($EndTime)
        $offset = if ($isDaylightSavingTime) { 2 } else { 1 }
        $EndTime = $EndTime.AddHours(-$offset)

        # Calculating Unix Time Epoch
        $epoch_time_start = [int](New-TimeSpan -Start (Get-Date "01/01/1970") -End $StartTime).TotalSeconds
        $epoch_time_end = [int](New-TimeSpan -Start (Get-Date "01/01/1970") -End $EndTime).TotalSeconds

        # Set HTTP Header
        $httpHeaders = @{
            "X-HTTP-Method-Override" = "POST"
            "accept"                 = "application/json"
        }
    }
    PROCESS {

        # Generate HTTP Body
        $data = @()

        # Filter for host and service
        if ($PSBoundParameters.ContainsKey('Hostname') -and $PSBoundParameters.ContainsKey('Service')) {
            foreach ($h in $Hostname) {
                foreach ($srv in $Service) {
                    $data += @{
                        "type"       = "Service"
                        "filter"     = "host.name==`"$h`" && service.name==`"$srv`""
                        "start_time" = $epoch_time_start
                        "end_time"   = $epoch_time_end
                        "author"     = $Author
                        "comment"    = $Comment
                        "fixed"      = -not $Flexible
                    } | ConvertTo-Json
                }
            }
        }

        # Filter for host
        elseif ($PSBoundParameters.ContainsKey('Hostname')) {
            foreach ($h in $Hostname) {
                $data += @{
                    "type"         = "Host"
                    "all_services" = $true
                    "filter"       = "host.name==`"$h`""
                    "start_time"   = $epoch_time_start
                    "end_time"     = $epoch_time_end
                    "author"       = $Author
                    "comment"      = $Comment
                    "fixed"        = -not $Flexible
                } | ConvertTo-Json
            }
        }

        # Filter for service
        elseif ($PSBoundParameters.ContainsKey('Service')) {
            foreach ($srv in $Service) {
                $data += @{
                    "type"       = "Service"
                    "filter"     = "service.name==`"$srv`""
                    "start_time" = $epoch_time_start
                    "end_time"   = $epoch_time_end
                    "author"     = $Author
                    "comment"    = $Comment
                    "fixed"      = -not $Flexible
                } | ConvertTo-Json
            }
        }

        # Filter for Servicegroup
        elseif ($PSBoundParameters.ContainsKey('Servicegroup')) {
            $data += @{
                "type"       = "Service"
                "filter"     = "`"$Servicegroup`" in service.groups"
                "start_time" = $epoch_time_start
                "end_time"   = $epoch_time_end
                "author"     = $Author
                "comment"    = $Comment
                "fixed"      = -not $Flexible
            } | ConvertTo-Json
        }

        # Filter for Hostgroup
        elseif ($PSBoundParameters.ContainsKey('Hostgroup')) {
            $data += @{
                "type"       = "Service"
                "filter"     = "`"$Hostgroup`" in host.groups"
                "start_time" = $epoch_time_start
                "end_time"   = $epoch_time_end
                "author"     = $Author
                "comment"    = $Comment
                "fixed"      = -not $Flexible
            } | ConvertTo-Json
        }
        
        # API Calls and save response as pscustomobject to array
        $result = @()
        foreach ($body in $data) {
            try {
                $response = Invoke-RestMethod -Headers $httpHeaders -SkipCertificateCheck -Method Post -Uri $apiEndpoint -Body $body -Credential (New-Object System.Management.Automation.PSCredential($IcingaUsername, (ConvertTo-SecureString -String $IcingaPassword -AsPlainText -Force))) -SkipHttpErrorCheck
            }
            
            # Error Handling 
            catch [System.Net.Http.HttpRequestException] {
                Write-Error $Error[0].Exception.Message
            }
    
            if ($response.results.code -ne 200) {
                if ($null -eq $response.error) {
                    Write-Error "Object not found - check filter"
                }
                else {
                    Write-Error $response.status
                }
            }

            # Success 
            else {
                foreach ($status in $response.results.status) {
                    $result += [PSCustomObject]@{
                        Object   = ($status -split "'")[3]
                        Downtime = ($status -split "'")[1]
                    }
                }
            }
        }
    }
    END {
        return $result   
    }
}