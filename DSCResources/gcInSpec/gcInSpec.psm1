
<#
    .SYNOPSIS
        Returns an object with details of InSpec installation
    .DESCRIPTION
        Queries WMI to get currently installed InSpec versions.
        Returns object with installation Status and versions.    
#>
function Get-InstalledInSpecVersions {
    [cmdletbinding()]
    param(
    )

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Checking for InSpec..."
    
    $installedInSpec = Get-CimInstance -ClassName win32_product -Filter "Name LIKE 'InSpec%'"
    $installedInSpec_Version = $installedInSpec.Version
    $installedInSpec = if ($null -eq $installedInSpec_Version) { $false } else { $true }
    
    $returnStatus = New-Object -TypeName PSObject -ArgumentList @{
        Installed = $installedInSpec
        Version  = $installedInSpec_Version
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec installed: $installedInSpec"
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] InSpec versions: $installedInSpec_Version"


    return $returnStatus
}

<#
    .SYNOPSIS
        Download and install InSpec
    .DESCRIPTION
        Downloads the InSpec installation for Windows
        and installs it to the current directory.    
#>
function Install-InSpec {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version]$InSpecVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$WindowsServerVersion
        )
    
    $InSpecPackage_Version = "$($InSpecVersion.Major).$($InSpecVersion.Minor).$($InSpecVersion.Build)"
    # the url requires a revision number. an example would be '3.9.3.1'. let's set this if the user doesn't provide it since it is not included in the display text on the download page for InSpec. the first revision is '1'.
    $InSpecPackage_Name = "InSpec-$InSpecPackage_Version$($InSpecVersion.Revision)-x64.msi"
    $InSpecDownloadUri = "https://packages.chef.io/files/stable/InSpec/$InSpecPackage_Version/windows/$WindowsServerVersion/$InSpecPackage_Name"
    Write-Verbose "download url: $InSpecDownloadUri"
    
    $outFile = "$Env:TEMP/$InSpecPackage_Name"
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Downloading InSpec to $outFile"
    Invoke-WebRequest -Uri $InSpecDownloadUri -TimeoutSec 120 -OutFile $outFile
        
    $msiArguments = @(
        '/i'
        ('"{0}"' -f "$Env:TEMP/$InSpecPackage_Name")
        '/qn'
        "/L*v `"$Env:TEMP/$InSpecPackage_Name.log`""
    )
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Installing InSpec with arguments: $msiArguments"
    Start-Process -FilePath 'C:/Windows/System32/msiexec.exe' -ArgumentList $msiArguments -Wait -NoNewWindow
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
        [string]$InSpecProfilePath,
        [string]$AttributesFilePath
    )

    # InSpec prefers paths with no spaces
    
    # path to the InSpec bat file
    $InSpecExec_Path = "$env:SystemDrive/opscode/InSpec/bin/InSpec.bat"
@"
@ECHO OFF
SET HOMEDRIVE=%SystemDrive%
"%~dp0../embedded/bin/ruby.exe" "%~dpn0" %*
"@ | Set-Content $InSpecExec_Path
      
    $profileName = (Get-ChildItem -Path $InSpecProfilePath).Parent.Name

    $InSpecExec_Arguements = @(
        "exec $InSpecProfilePath"
        "--reporter=json-min:$InSpecProfilePath$profileName.json cli:$InSpecProfilePath$profileName.cli"
        # the license accept parameter might have issues in some versions?  it is not needed in 3.9.3.
        # "--chef-license=accept"
    )

    # add attributes reference if input is provided
    if ('' -ne $AttributesFilePath) {
        $InSpecExec_Arguements += " --attrs $AttributesFilePath"
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Starting the InSpec process with the command $InSpecExec_Path $InSpecExec_Arguements" 
    Start-Process -FilePath $InSpecExec_Path -ArgumentList $InSpecExec_Arguements -Wait -NoNewWindow
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
        [string]$InSpecOutputPath
    )
    
    $profileName = (Get-Item $InSpecOutputPath).Name
    $json = "$InSpecOutputPath$profileName.json"
    $cli = "$InSpecOutputPath$profileName.cli"

    # get JSON file containing InSpec output
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reading json output from $InSpecOutputPath$profileName.json" 
    $InSpecJson = Get-Content $json | ConvertFrom-Json

    # get CLI file containing InSpec output
    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Reading cli output from $InSpecOutputPath$profileName.cli" 
    [string]$InSpecCli = (Get-Content $cli) -replace '/x1b/[[0-9;]*m', ''
    
    # Reasons code/phrase for Get
    $Reasons = @()

    # results are compliant until a failed test is returned
    [bool]$profileCompliant = $true

    # loop through each control and create objects for the array; set compliance
    foreach ($control in $InSpecJson.controls) {

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Processing Reasons data for: $($control.code_desc)"
        
        [bool]$testCompliant   = $true
        [bool]$testSkipped     = $false

        Write-Verbose "[$((get-date).getdatetimeformats()[45])] Control Status: $($control.Status)"
        
        if ('failed' -eq $control.Status) {
            $profileCompliant = $false
            $testCompliant = $false
        }

        if ('skipped' -eq $control.Status) {
            $testSkipped = $true
        }
    }

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] Overall Status: $($profileCompliant)"

    $Reasons += @{
        Code    = 'gcInSpec:gcInSpec:InSpecRawOutput'
        Phrase  = $InSpecCli
    }

    $InSpec = @{
        profileName     = $profileName
        InSpecVersion   = $InSpecJson.version
        Status          = $profileCompliant
        Reasons         = $Reasons
    }
    return $InSpec
}

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $InSpecProfileName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $InSpecVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$WindowsServerVersion
    )

    Write-Verbose "[$((get-date).getdatetimeformats()[45])] required InSpec version: $InSpecVersion"

    $installedInSpec_Version = (Get-InstalledInSpecVersions).version
    if ($installedInSpec_Version -ne $InSpecVersion) {
        Install-InSpec $InSpecVersion $WindowsServerVersion
    }

    $InSpecProfile_Path = "$env:SystemDrive:/ProgramData/GuestConfig/Configuration/$InSpecProfileName/Modules/$InSpecProfileName/"

    Invoke-InSpec $InSpecProfile_Path
    $InSpec = ConvertFrom-InSpec $InSpecProfile_Path

    $get = @{
        InSpecProfileName   = $InSpecProfileName
        InSpecVersion       = $installedInSpec_Version
        Status              = $InSpec.Status
        Reasons             = $InSpec.Reasons
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
        $InSpecProfileName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $InSpecVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$WindowsServerVersion
    )

    $Status = (Get-TargetResource -InSpecProfileName $InSpecProfileName -InSpecVersion $InSpecVersion -WindowsServerVersion $WindowsServerVersion).Status
    return $Status
}

function Set-TargetResource {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $InSpecProfileName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $InSpecVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('2012r2','2016','2019')]
        # '2012r2' aligns to Windows 10
        [string]$WindowsServerVersion
    )

    throw 'Set functionality is not supported in this version of the DSC resource.'
}
