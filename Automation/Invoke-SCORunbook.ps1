workflow Invoke-SCORunbook{

    $params = @{"ComputerName" = 'EUDC01'}
    $paramsObject = New-Object PSObject -Property $params

    $result = Start-SCORunbook `
                -RunbookPath "\AzureAutomation\GetInstalledSecurityUpdates" `
                -InputParams $paramsObject

    $result
}