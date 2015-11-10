workflow Invoke-SCORunbook{

    $params = @{"ComputerName" = 'EUDC01'}
    $paramsObject = New-Object PSObject -Property $params

    $result = Start-SCORunbook `
                -RunbookPath "\AzureAutomation\Get-InstalledSecurityUpdates" `
                -InputParams $paramsObject

    $result
}