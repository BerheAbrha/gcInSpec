$errorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$script:resourceModuleName = 'gcInSpec'

Describe "$script:resourceModuleName Tests" {

    BeforeAll {        
        $modulePath = Split-Path -Path $PSScriptRoot -Parent
        $moduleResourcesPath = Join-Path -Path $modulePath -ChildPath 'DscResources'
        $resourceFolderPath = Join-Path -Path $moduleResourcesPath -ChildPath $script:resourceModuleName
        $resourceModulePath = Join-Path -Path $resourceFolderPath -ChildPath "$script:resourceModuleName.psm1"
        Import-Module -Name $resourceModulePath -Force
    }
    
    InModuleScope 'gcInSpec' {

        # IMPORTANT VARIABLES

        $script:test_inspec_version = '3.9.3'
        $script:test_os_release = '2012r2' # 2012r2 aligns to Windows 10 for InSpec supported versions
        $script:mock_profile_name = 'wmi_service_inspec_controls'

        Context 'gcInSpec\Get-InstalledInSpecVersions' {

            Context 'when InSpec is installed' {
                $product = New-Object -TypeName psobject -Property @{installed = $true; version = 'some_version' }
                Mock Get-CimInstance -Verifiable { return $product } `
                    -ParameterFilter { $ClassName -eq 'win32_product' }

                It 'Should find that InSpec is installed' {
                    (Get-InstalledInSpecVersions).Installed | Should -BeTrue
                    Assert-MockCalled Get-CimInstance
                }
            
                It 'Should find the correct InSpec version' {
                    (Get-InstalledInSpecVersions).Version | Should -Be 'some_version'
                    Assert-MockCalled Get-CimInstance
                }
            }

            Context 'when InSpec is not installed' {
                $product = New-Object -TypeName psobject -Property @{installed = $false; version = $null }
                Mock Get-CimInstance -Verifiable { return $product } `
                    -ParameterFilter { $ClassName -eq 'win32_product' }

                It 'Should find that InSpec is not installed' {
                    (Get-InstalledInSpecVersions).Installed | Should -BeFalse
                    Assert-MockCalled Get-CimInstance
                }
            
                It 'Should return null for InSpec version' {
                    (Get-InstalledInSpecVersions).Version | Should -BeNullOrEmpty
                    Assert-MockCalled Get-CimInstance
                }
            }
        }

        Context 'gcInSpec\Install-Inspec' {
            Mock Invoke-WebRequest -Verifiable
            Mock -CommandName 'Start-Process' -ModuleName 'gcInSpec' -Verifiable `
                -ParameterFilter { $FilePath -eq 'C:\Windows\System32\msiexec.exe' }

            It 'Should attempt to download InSpec' {
                Install-InSpec -InSpec_Version '0.0.0' -OS_Release '2019'
                Assert-MockCalled Invoke-WebRequest
            }

            It 'Should start Windows installer' {
                Install-InSpec -InSpec_Version '0.0.0' -OS_Release '2019'
                Assert-MockCalled Start-Process
            }
        }

        Context 'gcInSpec\Invoke-InSpec' {
            Mock -Command 'Set-Content' -Verifiable 
            Mock -Command 'Get-ChildItem'
            Mock -Command 'Start-Process' -Verifiable

            It 'Should create a bat file' {
                Invoke-InSpec -inspec_profile_path "$PSScriptRoot\examples\var_release_environment_inspec_controls"
                Assert-MockCalled Set-Content
            }

            It 'Should run the bat file' {
                Invoke-InSpec -inspec_profile_path "$PSScriptRoot\examples\var_release_environment_inspec_controls"
                Assert-MockCalled Start-Process
            }
        }

        Context 'gcInSpec\ConvertFrom-InSpec' {

            $return = ConvertFrom-InSpec -inspec_output_path "$PSScriptRoot\sample_output\wmi_service_inspec_controls\"

            It 'Should take InSpec output and return it as a reason hashtable' {
                $return | Should -BeOfType 'Hashtable'
            }

            It 'Should have a property: name' {
                $return | ForEach-Object name | Should -Be $script:mock_profile_name
            }
            
            It 'Should have a property: version' {
                $return | ForEach-Object version | Should -Be $script:test_inspec_version
            }
            
            It 'Should have a property: status' {
                $return | ForEach-Object status | Should -BeTrue
            }
            
            It 'Should have a property: reasons' {
                $return | ForEach-Object reasons | Should -BeOfType 'hashtable'
            }

            It 'Should have a reasons code' {
                $return.reasons[0] | ForEach-Object Code | Should -Be 'gcInSpec:gcInSpec:InSpecRawOutput'
            }

            It 'Should have a reasons phrase' {
                $return.reasons[0] | ForEach-Object Phrase | Should -Not -BeNullOrEmpty
            }
        }
        
        Context 'gcInSpec\Set-TargetResource' {

            It 'Should always throw' {
                { Set-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release } | Should Throw
            }
        }

        Context 'gcInSpec\Get-TargetResource' {

            Mock Get-InstalledInSpecVersions { return @{Installed = $true; Version = $script:test_inspec_version } } -Verifiable
            Mock Install-InSpec -Verifiable
            Mock Invoke-InSpec -Verifiable
            
            Context 'when the system is in the desired state' {
                
                Mock ConvertFrom-InSpec { new-object -TypeName PSObject -Property @{
                        name    = $script:mock_profile_name
                        version = $script:test_inspec_version
                        status  = $true
                        reasons = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                    } } -Verifiable

                It 'Should return the state as true' {
                    $result = Get-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                    $result.status | Should -BeTrue
                }
    
                It 'Should return the same values as passed as parameters' {
                    $result = Get-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                    $result.Name | Should -Be $script:mock_profile_name
                }
    
                It 'Should return values for Reasons' {
                    $result = Get-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                    $result.Reasons | Should -Not -BeNullOrEmpty
                }
            }

            Context 'when the system is not in the desired state' {

                Mock ConvertFrom-InSpec { new-object -TypeName PSObject -Property @{
                        name    = $script:mock_profile_name
                        version = $script:test_inspec_version
                        status  = $false
                        reasons = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                    } } -Verifiable

                It 'Should return the state as false' {
                    $result = Get-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                    $result.status | Should -BeFalse
                }
    
                It 'Should return the same values as passed as parameters' {
                    $result = Get-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                    $result.Name | Should -Be $script:mock_profile_name
                }
    
                It 'Should return values for Reasons' {
                    $result = Get-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                    $result.Reasons | Should -Not -BeNullOrEmpty
                }
            }

            Context 'gcInSpec\Test-TargetResource when the system is in the desired state' {

                Context 'when the system is in the desired state' {
            
                    Mock ConvertFrom-InSpec { new-object -TypeName PSObject -Property @{
                            name    = $script:mock_profile_name
                            version = $script:test_inspec_version
                            status  = $true
                            reasons = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable

                    It 'Should pass Test' {
                        $result = Test-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                        $result | Should -BeTrue
                    }
                }

                Context 'when the system is not in the desired state' {

                    Mock ConvertFrom-InSpec { new-object -TypeName PSObject -Property @{
                            name    = $script:mock_profile_name
                            version = $script:test_inspec_version
                            status  = $false
                            reasons = @(@{Code = 'gcInSpec:gcInSpec:InSpecRawOutput'; Phrase = 'test phrase' })
                        } } -Verifiable

                    It 'Should fail Test' {
                        $result = Test-TargetResource -Name $script:mock_profile_name -Version $script:test_inspec_version -OS_Release $script:test_os_release
                        $result | Should -BeFalse
                    }

                }
            }
        }

        #>
    }
}
