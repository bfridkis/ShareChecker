$allShares = New-Object System.Collections.Generic.List[System.Object]
$errorList = New-Object System.Collections.Generic.List[System.Object]
$outputString = $outputStringResults = $null

Get-ADObject -LDAPFilter "(objectClass=computer)" | Sort-Object name | Select-Object -ExpandProperty Name | Set-Variable -Name compsList

$compsList | ForEach-Object { 
    $thisComp = $_
    Try {
        $cim = New-CimSession -ComputerName $_ -ErrorAction Stop
        Get-SmbShare -CimSession $cim -ErrorAction Stop | ForEach-object { $allShares.Add($_) }
    }
    Catch { $errorList.Add( @{ 'Hostname' = $thisComp ; 'Exception' = $_.Exception.Message } ) }
}
        
$nonDefaultShares = $allShares | Where-Object { $_.Name[-1] -ne "$" } | Select-Object PSComputerName, Name, Path, Description

$outputFileName = "ShareCheckerOutput-$(Get-Date -Format MMddyyyy_HHmmss).csv"

if ($nonDefaultShares.Count -gt 0) { $nonDefaultShares | Export-CSV -Path $outputFileName -NoTypeInformation -Append }
else { Add-Content -Path $outputFileName -Value "No non-default shares found.`r`n" }

$resourceLackingErrorList = $errorList | Select-Object @{ n = 'Unavailable Hosts' ; e = {$_.Hostname}},
                                                       @{ n = 'Exception' ; e = {$_.Exception}} |
                                         Where-Object { $_."Exception" -like "*The service cannot find the resource identified by the resource URI and selectors." }

$errorList = $errorList | Where-Object { $_."Exception" -notlike "*The service cannot find the resource identified by the resource URI and selectors." }

if ($resourceLackingErrorList) {
    $outputString = "`r`n** Output For Machines without Get-SmbShare Command (i.e. PS Version < 5.0) **`r`n"
    Add-Content -Path $outputFileName -Value $outputString
    $resourceLackingErrorList | ForEach-Object { 
        $path = "\\" + "$($_."Unavailable Hosts")"
        $outputStringResults += net view "$path"
    }  
    Add-Content -Path $outputFileName -Value $outputStringResults
}

if ($errorList) {
    $outputString = "** Unreachable Nodes **"
    Add-Content -Path $outputFileName -Value $outputString
    $errorList | Select-Object @{ n = 'Unavailable Hosts' ; e = {$_.Hostname}},
                               @{ n = 'Exceptions Generated' ; e = {$_.Exception}} |
                 Sort-Object "Unavailable Hosts" | ConvertTo-CSV -NoTypeInformation | Add-Content -Path $outputFileName
}