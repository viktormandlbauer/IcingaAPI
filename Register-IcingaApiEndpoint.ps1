<#
.SYNOPSIS
Registers an Icinga API endpoint for later use by other Icinga-related functions.

.DESCRIPTION
This function stores the necessary information for connecting to an Icinga API endpoint, including the hostname, port, and authentication credentials. The information is saved to an XML file in the user's AppData\Roaming\IcingaPowershell folder, which can be used later by other Icinga-related functions that require an API connection.

.PARAMETER IcingaHost
The hostname or IP address of the Icinga server.

.PARAMETER IcingaPort
The port number used by the Icinga API.

.PARAMETER IcingaUsername
The username to use for authentication with the Icinga API.

.PARAMETER IcingaPassword
The password to use for authentication with the Icinga API.

.EXAMPLE
Register-IcingaApiEndpoint -IcingaHost 'icinga.example.com' -IcingaPort 5665 -IcingaUsername 'admin' -IcingaPassword 'P@ssw0rd!'
Registers the Icinga API endpoint at icinga.example.com:5665 with the username 'admin' and password 'P@ssw0rd!', and saves the information to an XML file.

.NOTES
This function requires the user to have write access to the AppData\Roaming\IcingaPowershell folder. If the folder does not exist, it will be created. The function does not check whether the provided credentials are valid, or whether the Icinga API endpoint is reachable.
#>
function Register-IcingaApiEndpoint {
    [CmdletBinding()]
    param (
        [string]
        $IcingaHost,

        [int]
        $IcingaPort,

        [string]
        $IcingaUsername,
        
        [string]
        $IcingaPassword
    )

    if (-not (Test-Path "$env:APPDATA\IcingaPowershell")) {
        New-Item -Path "$env:APPDATA\IcingaPowershell" -ItemType Directory    
    }
    $Credentials = (New-Object System.Management.Automation.PSCredential($IcingaUsername, (ConvertTo-SecureString -String $IcingaPassword -AsPlainText -Force)))

    [PSCustomObject]@{
        IcingaHost  = $IcingaHost
        IcingaPort  = $IcingaPort
        Credentials = $Credentials
    } | Export-Clixml -Path "$env:APPDATA\IcingaPowershell\IcingaApiEndpoint.xml" -Force
}