<#
.SYNOPSIS
Removes a downtime object from Icinga 2 API endpoint.

.DESCRIPTION
The Remove-IcingaDowntime function removes downtime objects from Icinga 2 API endpoint based on the provided parameters. The function requires at least one of the parameters to be specified. If no parameters are provided, the function will not execute.

.PARAMETER Downtime
The downtime parameter expects an array of strings that represent the name of the downtime objects to be removed.

.PARAMETER Hostname
The hostname parameter expects an array of strings that represent the name of the hosts to remove downtime for.

.PARAMETER Author
The author parameter expects an array of strings that represent the author of the downtime objects to be removed.

.EXAMPLE
Remove-IcingaDowntime -Downtime 'downtime_name'
Removes the downtime object with the name 'downtime_name' from the Icinga 2 API endpoint.

.EXAMPLE
Remove-IcingaDowntime -Hostname 'host_name'
Removes all downtime objects for the host with the name 'host_name' from the Icinga 2 API endpoint.

.EXAMPLE
Remove-IcingaDowntime -Author 'author_name'
Removes all downtime objects with the author 'author_name' from the Icinga 2 API endpoint.

.INPUTS
None

.OUTPUTS
The output is an array of PSObjects that contains the name of the downtime objects that were removed from the Icinga 2 API endpoint.

.NOTES
This function requires the Icinga 2 API endpoint to be registered using the Register-IcingaApiEndpoint function. The endpoint is stored as a clixml file in the $env:APPDATA\IcingaPowershell\IcingaApiEndpoint.xml file.

.LINK
https://icinga.com/docs/icinga-2/latest/doc/06-downtimes/
#>
function Remove-IcingaDowntime {
    [CmdletBinding()]
    param (
        
        [Parameter(ParameterSetName = 'Downtime')]
        [string[]]
        $Downtime,

        [Parameter(ParameterSetName = 'Hostname')]
        [string[]]
        $Hostname,

        [Parameter(ParameterSetName = 'Author')]
        [string[]]
        $Author
    )

    BEGIN {
        
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

        $data = @()
    }
    PROCESS {
        
        $apiEndpoint = "https://$($IcingaHost):$($IcingaPort)/v1/actions/remove-downtime"
        
        $httpHeaders = @{
            "X-HTTP-Method-Override" = "POST"
            "accept"                 = "application/json"
        }
    
        if ($PSBoundParameters.ContainsKey('Downtime')) {
            foreach ($d in $Downtime) {   
                $data += @{
                    "downtime" = $Downtime
                    "pretty"   = $true
                } | ConvertTo-Json
            }
        }
        elseif ($PSBoundParameters.ContainsKey('Hostname')) {
            foreach ($h in $Hostname) {   
                $data += @{
                    "type"   = "Host"
                    "filter" = "host.name==`"$h`""
                    "pretty" = $true
                } | ConvertTo-Json
            }
        }
        elseif ($PSBoundParameters.ContainsKey('Author')) {
            foreach ($a in $Author) {   
                $data += @{
                    "type"   = "Downtime"
                    "filter" = "downtime.author ==`"$a`""
                    "pretty" = $true
                } | ConvertTo-Json
            }
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
                        Object = ($status -split "'")[1]
                    }
                }
            }
        }
    }
    END {
        return $result
    }
}