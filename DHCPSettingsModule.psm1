###################################################################
###################################################################
### This script is thought to determine if DHCP works correctly ###
### author: Corporate Software, Philip Marti                    ###
###################################################################
###################################################################

function Get-DHCPStatus {

    # Create the output-object
    $Adapter = Get-Adapter
    $IPObjects = Get-IPAddressCIDR
    $GatewayObjects = Get-DefaultGateway
    $DNSObjects = Get-DNSServer
    $i = 0

    foreach ($a in $Adapter) {
        $allOtherInterfaces = $Adapter | Where-Object {$_.InterfaceAlias -ne $a.Name}
        Disable-NetAdapter -Name $allOtherInterfaces.InterfaceAlias -Confirm:$false
        Start-Sleep -Seconds 60 #Hopefully enough time for the adapter to connect
        Write-Host $i

        # initialize some variables
        $InterfaceAlias = $a.Name
        $ip = $null
        $netmask = $null
        $lease = $null
        $gateway = $null
        $dns = $null
        $release = $null
        $renew = $null
        $output = $null

        # Make some calculations and assignments
        
        foreach ($ipobj in $IPObjects) {
            if ($ipobj.InterfaceAlias -eq $a.Name) {
                $ip = $ipobj.IPAddress
                $netmask = $ipobj.PrefixLength
                $lease = $ipobj.ValidLifetime
            }
        }

        foreach ($gw in $GatewayObjects) {
            if ($gw.InterfaceAlias -eq $a.Name) {
                $gateway = $gw.DefaultGateway
            }
        }

        foreach ($dnsobj in $DNSObjects) {
            if ($dnsobj.InterfaceAlias -eq $a.Name) {
                $dns = $dnsobj.IPv4Address
            }
        }

        # check if the release of the ip address is working
        ipconfig.exe /release $a.Name > $null
        $IPObjects_2 = Get-IPAddressCIDR
        foreach ($ipobj in $IPObjects_2) {
            if ($ipobj.InterfaceAlias -eq $a.Name) {
                $ip_a = $ipobj.IPAddress
            }
        } 
        if ($ip_a -eq "" -or $ip_a -like "169.254.*" -or $ip_a -eq $null) {
            $release = $true
        }
        else {
            $release = $false
        }

        # check if the renew of the ip address is working
        $ip_a = $null
        ipconfig.exe /renew $a.Name > $null
        $IPObjects_3 = Get-IPAddressCIDR
        foreach ($ipobj in $IPObjects_3) {
            if ($ipobj.InterfaceAlias -eq $a.Name) {
                $ip_a = $ipobj.IPAddress
            }
        } 
        if ($ip_a -eq "" -or $ip_a -like "169.254.*" -or $ip_a -eq $null) {
            $renew = $false
        }
        else {
            $renew = $true
        }

        #create the object
        #if ($ip -ne $null -and $netmask -ne $null) {
        [array]$output += [PSCustomObject]@{
            InterfaceAlias  = $InterfaceAlias
            IpAddress       = $ip
            PrefixLength    = $netmask
            ValidLifetime   = $lease
            DefaultGateway  = $gateway
            DNSServer       = $dns
            ReleasePossible = $release
            RenewPossible   = $renew
        }
        #}
        Enable-NetAdapter -Name $allOtherInterfaces.InterfaceAlias
        $i ++
    }
    Write-Host $i+$i
    return $output
}

### Helping Functions ###

# Get all adapters which are in ["Ethernet", "Wi-Fi", "WLAN"]
function Get-Adapter {
    [array]$adapternames = @("Ethernet", "Wi-Fi", "WLAN")
    [array]$AdapterName = Get-NetAdapter -Name $adapternames -ErrorAction SilentlyContinue
    return $AdapterName
}

# Get the InterfaceAliases, IPv4-Addresses and subnet masks, which were applied by dhcp
function Get-IPAddressCIDR {
    $adapter = Get-Adapter
    [array]$Interface_IPAddress_Subnetmask = $null # objects with properties [InterfaceAlias, IPv4Address, Subnetmask (CIDR-Notation)]
    [array]$wishedInterface = $null # All interfaces which received their Lease from DHCP and their IPAddressFamily is not IPv6
    $IPObject = $null # Element of the Interface_IPAddress_Subnetmask Array

    $wishedInterface = Get-NetIPAddress -InterfaceAlias $adapter.Name -PrefixOrigin "Dhcp" -AddressFamily "IPv4"
    foreach ($interface in $wishedInterface) {
        $IPObject = [PSCustomObject]@{
            InterfaceAlias = $interface.InterfaceAlias
            IPAddress      = $interface.IPv4Address
            PrefixLength   = $interface.PrefixLength
            ValidLifetime  = $interface.ValidLifetime
        }
        [array]$Interface_IPAddress_Subnetmask += $IPObject
    }
    return $Interface_IPAddress_Subnetmask
}

# Get the pair DefaultGateway, InterfaceAlias
function Get-DefaultGateway {
    [array]$Interface_DefaultGateway = $null
    $gateway = $null
    Get-NetIPConfiguration | ForEach-Object {
        $gateway = [PSCustomObject]@{
            InterfaceAlias = ($_.IPv4DefaultGateway).InterfaceAlias
            DefaultGateway = ($_.IPv4DefaultGateway).NextHop
        }
        [array]$Interface_DefaultGateway += $gateway
    }
    return $Interface_DefaultGateway
}

# Get the pair DNSServer, InterfaceAlias
function Get-DNSServer {
    [array]$Interface_DNS = $null
    $DNSInterfaces = Get-DnsClientServerAddress

    foreach ($interface in $DNSInterfaces) {
        if ($interface.ServerAddresses -like "*.*") {
            $address = ($interface.ServerAddresses).trim("{", "}")
        }
        else {
            $address = ""
        }

        if ($address -ne "") {
            $DNSObject = [PSCustomObject]@{
                InterfaceAlias = ($interface).InterfaceAlias
                IPv4Address    = $address
            }
            $Interface_DNS += $DNSObject
        }
    }
    return $Interface_DNS
}