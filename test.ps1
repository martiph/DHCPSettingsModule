$Adapter = Get-Adapter
foreach ($a in $Adapter) {
    $allOtherInterfaces = $Adapter | Where-Object {$_.InterfaceAlias -ne $a.InterfaceAlias}
    Disable-NetAdapter -Name $allOtherInterfaces.InterfaceAlias -Confirm:$false
    Start-Sleep -Seconds 10
    Get-Adapter
    Enable-NetAdapter -Name $allOtherInterfaces.InterfaceAlias
}