
function Invoke-InSpec {
    param(
        [Parameter(Mandatory=$true)]
        [string]$policy_folder_path,
        [Parameter(Mandatory=$true)]
        [string]$inspec_output_file_path,
        [Parameter(Mandatory=$true)]
        [string]$inspec_cli_output_file_path,
        [string]$attributes_file_path
    )
    $InSpec_Exec_Path = "$pwd\inspec\bin\inspec.bat"

    $run_inspec_exec_arguements = @(
        "exec $policy_folder_path"
        "--reporter=json-min:$inspec_output_file_path cli:$inspec_cli_output_file_path"
        "--chef-license=CHEF_LICENSE"
    )

    if ($null -eq $attributes_file_path)
    {
        $run_inspec_exec_arguements += " --attrs $attributes_file_path"
    }

    Write-Output "[$((get-date).getdatetimeformats()[45])] Starting the InSpec process with the command $InSpec_Exec_Path $run_inspec_exec_arguements" 
    Start-Process $InSpec_Exec_Path -Property $run_inspec_exec_arguements -Wait -NoNewWindow
}

function ConvertFrom-InSpec {
    [cmdletbinding()]
    param(
    [Parameter(Mandatory=$true)]
    [string]$inspec_output_file_path
    )
    $inspecResults = Get-Content $inspec_output_file_path | ConvertFrom-Json -Depth 10
    
    $statistics = New-Object -TypeName PSObject -Property @{
        Duration = $inspecResults.statistics.duration
    }
    
    $controls = @()
    foreach ($control in $inspecResults.controls) {
        [bool]$test_compliant = $true
        [bool]$test_skipped   = $false

        if ("failed" -eq $control.status) {
            $test_compliant = $false
        }

        if("skipped" -eq $control.status) {
            $test_skipped = $true
        }

        if ($false -eq $test_compliant -and $false -eq $test_skipped) {
            $reason_phrase = "InSpec policy test failed."
        }

        if ($null -ne $control.code_desc) {
            $reason_phrase +=  " Test description: $($control.code_desc)"
        }
        else {
            Write-Verbose "Policy test failed, but no code description found for the reason phrase."
        }
        
        if ($null -ne $control.message) {
            $reason_phrase +=  "Test message: $($control.message)"
        }
        else {
            Write-Verbose "Policy test failed, but no message found for the reason phrase."
        }

        $controls += New-Object -TypeName PSObject -Property @{
            id              = $control.id
            profile_id      = $control.profile_id
            profile_sha256  = $control.profile_sha256
            status          = $control.status
            code_desc       = $control.code_desc
            message         = $control.message
            reason_phrase   = $reason_phrase
        }
    }

    $inspecObject = New-Object -TypeName PSObject -Property @{
        Version     = $inspecResults.version
        Statistics  = $statistics
        Controls    = $controls
    }
    return $inspecObject
}