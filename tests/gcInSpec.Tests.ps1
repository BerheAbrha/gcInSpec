Import-Module $PSScriptRoot/../DSCResources/gcInSpec/gcInSpec.psm1 -Force
$script:resourceModuleName = 'gcInSpec'
if (!$Env:TEMP) { $Env:TEMP = $TestDrive }

Describe "$script:resourceModuleName Tests" {

    BeforeAll {        
        $modulePath = Split-Path -Path $PSScriptRoot -Parent
        $moduleResourcesPath = Join-Path -Path $modulePath -ChildPath 'DscResources'
        $resourceFolderPath = Join-Path -Path $moduleResourcesPath -ChildPath $script:resourceModuleName
        $resourceModulePath = Join-Path -Path $resourceFolderPath -ChildPath "$script:resourceModuleName.psm1"
        Import-Module $resourceModulePath -Force
        Import-Module PSDesiredStateConfiguration
    }
    
    InModuleScope 'gcInSpec' {

        Context 'gcInSpec\Get-InstalledInSpecVersions' {

            Context 'when InSpec is installed' {

                It 'Should find that InSpec is installed' {
                    if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' } } }
                    $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                    Mock 'Get-CimInstance' -MockWith { return $product } `
                        -Verifiable `
                        -ParameterFilter { $ClassName -eq 'win32_product' }
                    (Get-InstalledInSpecVersions).Installed | Should -BeTrue
                }
            
                It 'Should find the correct InSpec version' {
                    if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' } } }
                    $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                    Mock Get-CimInstance -Verifiable { return $product } `
                        -ParameterFilter { $ClassName -eq 'win32_product' }
                    (Get-InstalledInSpecVersions).Version | Should -Be 'some_version'
                }
            }

            Context 'when InSpec is not installed' {

                It 'Should find that InSpec is not installed' {
                    if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $false; version = $null } } }
                    $product = New-Object -TypeName psobject -Property @{installed = $false; version = $null }
                    Mock Get-CimInstance -Verifiable { return $product } `
                        -ParameterFilter { $ClassName -eq 'win32_product' }
                    (Get-InstalledInSpecVersions).Installed | Should -BeFalse
                }
            
                It 'Should return null for InSpec version' {
                    if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $false; version = $null } } }
                    $product = New-Object -TypeName psobject -Property @{installed = $false; version = $null }
                    Mock Get-CimInstance -Verifiable { return $product } `
                        -ParameterFilter { $ClassName -eq 'win32_product' }
                    (Get-InstalledInSpecVersions).Version | Should -BeNullOrEmpty
                }
            }
        }

        Context 'gcInSpec\Install-Inspec' {

            It 'Should attempt to download InSpec' {
                if (!$IsWindows) { function Start-Process { } }
                Mock Invoke-WebRequest -Verifiable
                Mock -CommandName 'Start-Process' -ModuleName 'gcInSpec' -Verifiable `
                    -ParameterFilter { $FilePath -eq 'C:\Windows\System32\msiexec.exe' }
                Install-InSpec -InSpecVersion '0.0.0' -WindowsServerVersion '2019'
            }

            It 'Should start Windows installer' {
                if (!$IsWindows) { function Start-Process { } }
                Mock Invoke-WebRequest -Verifiable
                Mock -CommandName 'Start-Process' -ModuleName 'gcInSpec' -Verifiable `
                    -ParameterFilter { $FilePath -eq 'C:\Windows\System32\msiexec.exe' }
                Install-InSpec -InSpecVersion '0.0.0' -WindowsServerVersion '2019'
            }
        }

        Context 'gcInSpec\Invoke-InSpec' {

            It 'Should create a bat file' {
                Mock -Command 'Set-Content' -Verifiable 
                Mock -Command 'Get-ChildItem'
                Mock -Command 'Start-Process' -Verifiable
                Invoke-InSpec -InSpecProfilePath "$PSScriptRoot\examples\var_release_environment_inspec_controls"
                Assert-MockCalled Set-Content
            }

            It 'Should run the bat file' {
                Mock -Command 'Set-Content' -Verifiable 
                Mock -Command 'Get-ChildItem'
                Mock -Command 'Start-Process' -Verifiable
                Invoke-InSpec -InSpecProfilePath "$PSScriptRoot\examples\var_release_environment_inspec_controls"
                Assert-MockCalled Start-Process
            }
        }

        Context 'gcInSpec\ConvertFrom-InSpec' {

            It 'Should take InSpec output and return it as a reason hashtable' {
                $return = ConvertFrom-InSpec -InSpecOutputPath "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"
                $return | Should -BeOfType 'Hashtable'
            }

            It 'Should have a property: name' {
                $return = ConvertFrom-InSpec -InSpecOutputPath "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"
                $return | ForEach-Object name | Should -Be $test_InSpecProfileName
            }
            
            It 'Should have a property: version' {
                $return = ConvertFrom-InSpec -InSpecOutputPath "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"
                $return | ForEach-Object version | Should -Be $test_InspecVersion
            }
            
            It 'Should have a property: status' {
                $return = ConvertFrom-InSpec -InSpecOutputPath "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"
                $return | ForEach-Object status | Should -BeTrue
            }
            
            It 'Should have a property: reasons' {
                $return = ConvertFrom-InSpec -InSpecOutputPath "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"
                $return | ForEach-Object reasons | Should -BeOfType 'hashtable'
            }

            It 'Should have a reasons code' {
                $return = ConvertFrom-InSpec -InSpecOutputPath "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"
                $return.reasons[0] | ForEach-Object Code | Should -Be 'gcInSpec:gcInSpec:InSpecRawOutput'
            }

            It 'Should have a reasons phrase' {
                $return = ConvertFrom-InSpec -InSpecOutputPath "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"
                $return.reasons[0] | ForEach-Object Phrase | Should -Not -BeNullOrEmpty
            }
        }
        
        Context 'gcInSpec\Set-TargetResource' {

            It 'Should always throw' {
                { Set-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion } | Should -Throw
            }
        }

        Context 'gcInSpec\Get-TargetResource' {
            
            Context 'when the system is in the desired state' {

                It 'Should return the state as true' {
                    Mock Get-InstalledInSpecVersions { return @{Installed = $true; Version = $test_InspecVersion } } -Verifiable
                    Mock Install-InSpec -Verifiable
                    Mock Invoke-InSpec -Verifiable
                    Mock ConvertFrom-InSpec { new-object -TypeName PSObject -Property @{
                            InSpecProfileName = $test_InSpecProfileName
                            InSpecVersion     = $test_InspecVersion
                            status            = $true
                            reasons           = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable
                    $test_InspecVersion = '3.9.3'
                    $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                    $test_InSpecProfileName = 'wmi_service_inspec_controls'
                    $result = Get-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                    $result.status | Should -BeTrue
                }
    
                It 'Should return the same values as passed as parameters' {
                    Mock Get-InstalledInSpecVersions { return @{Installed = $true; Version = $test_InspecVersion } } -Verifiable
                    Mock Install-InSpec -Verifiable
                    Mock Invoke-InSpec -Verifiable
                    Mock ConvertFrom-InSpec { new-object -TypeName PSObject -Property @{
                            InSpecProfileName = $test_InSpecProfileName
                            InSpecVersion     = $test_InspecVersion
                            status            = $true
                            reasons           = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable
                    $test_InspecVersion = '3.9.3'
                    $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                    $test_InSpecProfileName = 'wmi_service_inspec_controls'
                    $result = Get-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                    $result.InSpecProfileName | Should -Be $test_InSpecProfileName
                }
    
                It 'Should return values for Reasons' {
                    Mock Get-InstalledInSpecVersions { return @{Installed = $true; Version = $test_InspecVersion } } -Verifiable
                    Mock Install-InSpec -Verifiable
                    Mock Invoke-InSpec -Verifiable
                    Mock ConvertFrom-InSpec { new-object -TypeName PSObject -Property @{
                            InSpecProfileName = $test_InSpecProfileName
                            InSpecVersion     = $test_InspecVersion
                            status            = $true
                            reasons           = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable
                    $test_InspecVersion = '3.9.3'
                    $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                    $test_InSpecProfileName = 'wmi_service_inspec_controls'
                    $result = Get-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                    $result.Reasons | Should -Not -BeNullOrEmpty
                }
            }

            Context 'when the system is not in the desired state' {

                It 'Should return the state as false' {
                    if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' } } }
                    $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                    Mock 'Get-CimInstance' -MockWith { return $product } `
                        -ParameterFilter { $ClassName -eq 'win32_product' }
                    Mock 'Invoke-WebRequest'
                    Mock -Command 'Get-ChildItem'
                    Mock -Command 'Set-Content'
                    Mock -Command 'Start-Process'
                    Mock 'ConvertFrom-InSpec' { new-object -TypeName PSObject -Property @{
                            name    = $test_InSpecProfileName
                            version = $test_InspecVersion
                            status  = $false
                            reasons = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable
                    $test_InspecVersion = '3.9.3'
                    $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                    $test_InSpecProfileName = 'wmi_service_inspec_controls'
                    $result = Get-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                    $result.status | Should -BeFalse
                }
    
                It 'Should return the same values as passed as parameters' {
                    if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' } } }
                    $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                    Mock 'Get-CimInstance' -MockWith { return $product } `
                        -ParameterFilter { $ClassName -eq 'win32_product' }
                    Mock 'Invoke-WebRequest'
                    Mock -Command 'Get-ChildItem'
                    Mock -Command 'Set-Content'
                    Mock -Command 'Start-Process'
                    Mock 'ConvertFrom-InSpec' -MockWith { new-object -TypeName PSObject -Property @{
                            name    = $test_InSpecProfileName
                            version = $test_InspecVersion
                            status  = $false
                            reasons = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable
                    $test_InspecVersion = '3.9.3'
                    $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                    $test_InSpecProfileName = 'wmi_service_inspec_controls'
                    $result = Get-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                    $result.InSpecProfileName | Should -Be $test_InSpecProfileName
                }
    
                It 'Should return values for Reasons' {
                    if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' } } }
                    $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                    Mock 'Get-CimInstance' -MockWith { return $product } `
                        -ParameterFilter { $ClassName -eq 'win32_product' }
                    Mock 'Invoke-WebRequest'
                    Mock -Command 'Get-ChildItem'
                    Mock -Command 'Set-Content'
                    Mock -Command 'Start-Process'
                    Mock 'ConvertFrom-InSpec' { new-object -TypeName PSObject -Property @{
                            name    = $test_InSpecProfileName
                            version = $test_InspecVersion
                            status  = $false
                            reasons = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable
                    $test_InspecVersion = '3.9.3'
                    $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                    $test_InSpecProfileName = 'wmi_service_inspec_controls'
                    $result = Get-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                    $result.Reasons | Should -Not -BeNullOrEmpty
                }
            }

            Context 'gcInSpec\Test-TargetResource when the system is in the desired state' {

                Context 'when the system is in the desired state' {

                    It 'Should pass Test' {
                        if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' } } }
                        $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                        Mock 'Get-CimInstance' -MockWith { return $product } `
                            -ParameterFilter { $ClassName -eq 'win32_product' }
                        Mock 'Invoke-WebRequest'
                        Mock -Command 'Get-ChildItem'
                        Mock -Command 'Set-Content'
                        Mock -Command 'Start-Process'
                        Mock 'ConvertFrom-InSpec' { new-object -TypeName PSObject -Property @{
                                InSpecProfileName = $test_InSpecProfileName
                                InSpecVersion     = $test_InspecVersion
                                status            = $true
                                reasons           = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                            } } -Verifiable
                        $test_InspecVersion = '3.9.3'
                        $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                        $test_InSpecProfileName = 'wmi_service_inspec_controls'
                        $result = Test-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                        $result | Should -BeTrue
                    }
                }

                Context 'when the system is not in the desired state' {

                    It 'Should fail Test' {
                        if (!$IsWindows) { function Get-CimInstance { New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' } } }
                        $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                        Mock 'Get-CimInstance' -MockWith { return $product } `
                            -ParameterFilter { $ClassName -eq 'win32_product' }
                        Mock 'Invoke-WebRequest'
                        Mock -Command 'Get-ChildItem'
                        Mock -Command 'Set-Content'
                        Mock -Command 'Start-Process'
                        Mock 'ConvertFrom-InSpec' { new-object -TypeName PSObject -Property @{
                                InSpecProfileName = $test_InSpecProfileName
                                InSpecVersion     = $test_InspecVersion
                                status            = $false
                                reasons           = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                            } } -Verifiable
                        $test_InspecVersion = '3.9.3'
                        $test_WindowsServerVersion = '2019' # 2012r2 aligns to Windows 10 for InSpec supported versions
                        $test_InSpecProfileName = 'wmi_service_inspec_controls'
                        $result = Test-TargetResource -InSpecProfileName $test_InSpecProfileName -InSpecVersion $test_InspecVersion -WindowsServerVersion $test_WindowsServerVersion
                        $result | Should -BeFalse
                    }

                }
            }
        }
    }
}
