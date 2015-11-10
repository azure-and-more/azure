########################################################################
#    Copyright (c) Microsoft. All rights reserved.
#    This code is licensed under the Microsoft Public License.
#    THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF ANY KIND, EITHER
#    EXPRESS OR IMPLIED, INCLUDING ANY IMPLIED WARRANTIES OF FITNESS
#    FOR A PARTICULAR PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
########################################################################

<# 
.SYNOPSIS
    This runbook starts an Orchestrator runbook with or without parameters and gets back any output.

.DESCRIPTION
    This runbook illustrates how to start a runbook in System Center Orchestrator, pass in parameters,
    and get back return data. 

    If the Orchestrator runbook has output, then this runbook will return it as a hashtable with
    key/value pairs, where the key is the output parameter name

.PARAMETER RunbookPath
    String. The full path to the runbook as defined in Orchestrator. For example, \folder1\folder2\runbookname.

.PARAMETER InputParams
    Object. Input parameters formatted as PSCustomObject with key/value pairs.

.PARAMETER JobCheckIntervalInSeconds
    Int. The amount of time, in seconds, to sleep between attempts to check the job for completeness.
    Set this to greater than the expected run time of the job.

.NOTES
    The runbook expects to connect with the web service for an installation of Orchestrator 2012 or 2012 R2.

    The runbook assumes that you have created an Automation Connection asset named "OrchestratorConnection"
    with the information required to connect with the Orchestrator web service.
#>  

workflow Start-ScoRunbook
{
    [OutputType( [hashtable] )]

    # define the input parameters to this runbook
    param (
        [Parameter(Mandatory=$true)]
            [string] $RunbookPath,
        [Parameter(Mandatory=$false)]
            [object] $InputParams,
        [Parameter(Mandatory=$false)]
            [int] $JobCheckIntervalInSeconds
    )
     
    # get the Orchestrator connection asset
    $con = Get-AutomationConnection -Name 'OrchestratorConnection'

    # create a Credential object
    $securepassword = ConvertTo-SecureString -AsPlainText -String $con.UserPassword -Force
    $domainuser = $con.UserDomain + "\" + $con.UserName
    $creds = New-Object -TypeName System.Net.NetworkCredential -ArgumentList ($domainuser, $securepassword)

    # create the URL for the Orchestrator service
    $url = Get-OrchestratorServiceUrl -Server $con.ServerName

    # get the SCO runbook we want to start
    $runbook = Get-OrchestratorRunbook -ServiceUrl $url -Credentials $creds -RunbookPath $RunbookPath
    if ($runbook -eq $null) {
        $msg = "Orchestrator runbook '$RunbookPath' could not be retrieved."
        Write-Error -message $msg
        Throw $msg
    }
    else {
        # start the runbook job
        if ($InputParams -ne $null) {
            # convert the input param names to their associated GUIDs
            $RBInputWithIds = getParamObjectWithIds -RBInputWithNames $InputParams -runbook $runbook
            
            # start the runbook with input parameters and get the job returned
            $job = Start-OrchestratorRunbook -Runbook $runbook -Credentials $creds -Parameters $RBInputWithIds
        }
        else {
            # start the runbook without any input parameters and get the job returned
            $job = Start-OrchestratorRunbook -Runbook $runbook -Credentials $creds
        }
            
        # if a job has been created then get any output
        if ($job -eq $null) {
            $msg = "Orchestrator runbook job is null: no job was created."
            Write-Error -message $msg
            Throw $msg
        }
        else {
        	# get any output
            $out = getJobOutput -Job $job -Creds $creds -JobCheckIntervalInSeconds $JobCheckIntervalInSeconds

            # return the output object if there is output
            if ($out -ne $null) {
                Write-Output $out
            }
        }
    }
    
    #
    # Function that takes an input parameter object that has parameter names and values
    # and replaces the names with the ids
    #
    function getParamObjectWithIds
    {
        param (
            [object] $RBInputWithNames,
            [object] $runbook
        )
        
        # convert the PSCustomObject to a hashtable
        $NamesHt = @{}
        $RBInputWithNames.psobject.properties | Foreach { $NamesHt[$_.Name] = $_.Value }
        
        # get the runbook parameters
        $RBParams = $runbook.Parameters
        
        # create new input parameter hashtable with parameter ids as keys
        $RBInputWithIds = @{}
        foreach($key in @($NamesHt.keys)) {
            foreach ($pm in $RBParams) {  
                if ($pm.Name -eq $key) { 
                    $RBInputWithIds.Add($pm.Id,$NamesHt[$key]) 
                }
            }
        }
        
        # output the new parameter hashtable
        Write-Output $RBInputWithIds
    }
    
    #
    # Function that gets the runbook job output
    #
    function getJobOutput
    {
        param (
            [object] $Job,
            [object] $Creds,
            [int] $JobCheckIntervalInSeconds
        )
        
        # assure the job is complete
        while( ($job.Status -eq "Running") -or ($job.Status -eq "Pending") ) {
            Start-Sleep -s $JobCheckIntervalInSeconds
            $job = Get-OrchestratorJob -jobid $job.Id -serviceurl $job.Url_Service -credentials $creds
        }
        
        # get the runbook instance that has the job data
        $instance = Get-OrchestratorRunbookInstance -Job $job -Credentials $creds
        if ($instance -eq $null) {
            $msg = "Orchestrator runbook instance is null."
            Write-Error -message $msg
            Throw $msg
        }
        else {
            # there are instance parameters only if the runbook has input and/or output parameters
            $instparams = Get-OrchestratorRunbookInstanceParameter -RunbookInstance $instance -Credentials $creds
            if ($instparams -ne $null) {
                # any output will be in a hashtable
                $out = @{}
                # look through the runbook parameters for any that are for output
                foreach ($instparam in $instparams) {
                    if ($instparam.Direction -eq "Out") {
                        # write the output value (always a string, interger, date, or boolean)
                        $out.Add($instparam.Name,$instparam.Value)
                    }
                }
                Write-Output $out
            } else {
                Write-Verbose -message "The runbook has no output." -Verbose
                Write-Output $null
            }
        }
    }
    
}