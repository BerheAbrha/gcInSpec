#requires –runasadministrator
# 
# This script installs Chef Inspec on Windows
# 

$Script:InSpec_Version = [version]'4.3.2.1'

function Get-InstalledInSpecVersions {
    [cmdletbinding()]
    param()

    Write-Output "[$((get-date).getdatetimeformats()[45])] Checking for InSpec..."
    
    $Installed_InSpec = Get-CimInstance win32_product -Filter "Name LIKE 'InSpec%'"
    $Installed_InSpec_Versions = $Installed_InSpec | ForEach-Object { $_.Version }
    $Installed_InSpec = if ($null -eq $Installed_InSpec_Versions) { $false } else { $true }
    
    $returnStatus = New-Object -TypeName PSObject -ArgumentList @{
        Installed = $Installed_InSpec
        Versions  = $Installed_InSpec_Versions
    }
    return $returnStatus
}

function Install-Inspec {
    [cmdletbinding()]
    param()
    
    if ($false -eq (Get-InstalledInSpecVersions).Installed) {
        $InSpec_Package_Version = "$($InSpec_Version.Major).$($InSpec_Version.Minor).$($InSpec_Version.Build)"
        $Inspec_Package_Name = "inspec-$InSpec_Package_Version-$($InSpec_Version.Revision)-x64.msi"
        $Inspec_Download_Uri = "https://packages.chef.io/files/stable/inspec/$InSpec_Package_Version/windows/2016/$Inspec_Package_Name"
        
        Write-Output "[$((get-date).getdatetimeformats()[45])] Downloading InSpec to $pwd\$Inspec_Package_Name"
        #Invoke-WebRequest -Uri $Inspec_Download_Uri -TimeoutSec 120 -RetryIntervalSec 5 -MaximumRetryCount 12 -OutFile "$pwd\$Inspec_Package_Name"
        
        $msiArguments = @(
            '/i'
            ('"{0}"' -f "$pwd\$Inspec_Package_Name")
            '/qn'
            "/L*v `"$pwd\$Inspec_Package_Name.log`""
            "INSTALLLOCATION=`"$pwd`""
        )
        Write-Output "[$((get-date).getdatetimeformats()[45])] Installing InSpec with arguments: $msiArguments"
        Start-Process "C:\Windows\System32\msiexec.exe" -ArgumentList $msiArguments -Wait -NoNewWindow
        Write-Output "[$((get-date).getdatetimeformats()[45])] InSpec installation process ended"
    }
}

Install-Inspec

$status = Get-InstalledInSpecVersions

if ($false -eq $status.Installed) {
    throw "[$((get-date).getdatetimeformats()[45])] A failure occured and InSpec could not be installed."
}
else {
    Write-Output "[$((get-date).getdatetimeformats()[45])] InSpec versions available on this machine: $($status.Versions)."
}
