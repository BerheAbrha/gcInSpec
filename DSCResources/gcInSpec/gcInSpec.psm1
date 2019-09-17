
<#
    .SYNOPSIS
        Returns an object with details of InSpec installation
    .DESCRIPTION
        Queries WMI to get currently installed InSpec versions.
        Returns object with installation status and versions.    
#>
function Get-InstalledInSpecVersions {
    [cmdletbinding()]
    param(
    )

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Checking for InSpec..."
    
    $Installed_InSpec = Get-CimInstance -ClassName win32_product -Filter "Name LIKE 'InSpec%'"
    $Installed_InSpec_Version = $Installed_InSpec.Version
    $Installed_InSpec = if ($null -eq $Installed_InSpec_Version) { $false } else { $true }
    
    $returnStatus = New-Object -TypeName PSObject -ArgumentList @{
        Installed = $Installed_InSpec
        Version  = $Installed_InSpec_Version
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec installed: $Installed_InSpec"
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec versions: $Installed_InSpec_Version"


    return $returnStatus
}

<#
    .SYNOPSIS
        Download and install InSpec
    .DESCRIPTION
        Downloads the InSpec installation for Windows
        and installs it to the current directory.    
#>
function Install-Inspec {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version]$InSpec_Version,

        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$OS_Release
        )
    
    $InSpec_Package_Version = "$($InSpec_Version.Major).$($InSpec_Version.Minor).$($InSpec_Version.Build)"
    # the url requires a revision number. an example would be '3.9.3.1'. let's set this if the user doesn't provide it since it is not included in the display text on the download page for InSpec. the first revision is '1'.
    $Inspec_Package_Name = "inspec-$InSpec_Package_Version$($InSpec_Version.Revision)-x64.msi"
    $Inspec_Download_Uri = "https://packages.chef.io/files/stable/inspec/$InSpec_Package_Version/windows/$OS_Release/$Inspec_Package_Name"
    Write-Verbose "download url: $Inspec_Download_Uri"
        
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Downloading InSpec to $gcinspec_module_folder_path\$Inspec_Package_Name"
    Invoke-WebRequest -Uri $Inspec_Download_Uri -TimeoutSec 120 -OutFile "$env:windir\temp\$Inspec_Package_Name"
        
    $msiArguments = @(
        '/i'
        ('"{0}"' -f "$env:windir\temp\$Inspec_Package_Name")
        '/qn'
        "/L*v `"$env:windir\temp\$Inspec_Package_Name.log`""
    )
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Installing InSpec with arguments: $msiArguments"
    Start-Process -FilePath 'C:\Windows\System32\msiexec.exe' -ArgumentList $msiArguments -Wait -NoNewWindow
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec installation process ended"
}

<#
    .SYNOPSIS
        Runs InSpec with parameters
    .DESCRIPTION
        This function executes the .bat file provided with
        InSpec, using parameter input for the path to
        profiles and desitnation for json/cli output.
    
#>
function Invoke-InSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$inspec_profile_path,
        [string]$attributes_file_path
    )

    # InSpec prefers paths with no spaces
    
    # path to the inspec bat file
    $InSpec_Exec_Path = "$env:SystemDrive\opscode\inspec\bin\inspec.bat"
@"
@ECHO OFF
SET HOMEDRIVE=%SystemDrive%
"%~dp0..\embedded\bin\ruby.exe" "%~dpn0" %*
"@ | Set-Content $InSpec_Exec_Path
      
    $name = (Get-ChildItem -Path $inspec_profile_path).Parent.Name

    $run_inspec_exec_arguements = @(
        "exec $inspec_profile_path"
        "--reporter=json-min:$inspec_profile_path$name.json cli:$inspec_profile_path$name.cli"
        # the license accept parameter might have issues in some versions?  it is not needed in 3.9.3.
        # "--chef-license=accept"
    )

    # add attributes reference if input is provided
    if ('' -ne $attributes_file_path) {
        $run_inspec_exec_arguements += " --attrs $attributes_file_path"
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Starting the InSpec process with the command $InSpec_Exec_Path $run_inspec_exec_arguements" 
    Start-Process -FilePath $InSpec_Exec_Path -ArgumentList $run_inspec_exec_arguements -Wait -NoNewWindow
}

<#
    .SYNOPSIS
        Creates a PowerShell object based on InSpec output.
    .DESCRIPTION
        Takes location of json-min and cli output files
        and converts the information to a PowerShell object
        with properties for use in the DSC resource.
    
#>
function ConvertFrom-InSpec {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$inspec_output_path
    )
    
    $name = (Get-Item $inspec_output_path).Name
    $json = "$inspec_output_path$name.json"
    $cli = "$inspec_output_path$name.cli"

    # get JSON file containing InSpec output
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reading json output from $inspec_output_path$name.json" 
    $inspecJson = Get-Content $json | ConvertFrom-Json

    # get CLI file containing InSpec output
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reading cli output from $inspec_output_path$name.cli" 
    [string]$inspecCli = (Get-Content $cli) -replace '\x1b\[[0-9;]*m', ''
    
    # reasons code/phrase for Get
    $reasons = @()

    # results are compliant until a failed test is returned
    [bool]$profile_compliant = $true

    # loop through each control and create objects for the array; set compliance
    foreach ($control in $inspecJson.controls) {

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Processing reasons data for: $($control.code_desc)"
        
        [bool]$test_compliant   = $true
        [bool]$test_skipped     = $false

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Control status: $($control.status)"
        
        if ('failed' -eq $control.status) {
            $profile_compliant = $false
            $test_compliant = $false
        }

        if ('skipped' -eq $control.status) {
            $test_skipped = $true
        }
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Overall status: $($profile_compliant)"

    $reasons += @{
        Code    = 'gcInSpec:gcInSpec:InSpecRawOutput'
        Phrase  = $inspecCli
    }

    $inspec = @{
        name    = $name
        version = $inspecJson.version
        status  = $profile_compliant
        reasons = $reasons
    }
    return $inspec
}

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $version,

        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$OS_Release
    )

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] required InSpec version: $version"

    $Installed_InSpec_Version = (Get-InstalledInSpecVersions).version
    if ($Installed_InSpec_Version -ne $version) {
        Install-Inspec $version $OS_Release
    }

    $inspec_profile_path = "$env:SystemDrive:\ProgramData\GuestConfig\Configuration\$name\Modules\$name\"

    Invoke-InSpec $inspec_profile_path
    $inspec = ConvertFrom-InSpec $inspec_profile_path

    $get = @{
        name    = $name
        version = $Installed_InSpec_Version
        status  = $inspec.status
        Reasons = $inspec.reasons
    }

    return $get
}

function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $version,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$OS_Release
    )

    $status = (Get-TargetResource -name $name -version $version -OS_Release $OS_Release).status
    return $status
}

function Set-TargetResource {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $version,

        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$OS_Release
    )

    throw 'Set functionality is not supported in this version of the DSC resource.'
}
