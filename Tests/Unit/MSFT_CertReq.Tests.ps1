[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
[CmdletBinding()]
param ()

$script:DSCModuleName   = 'CertificateDsc'
$script:DSCResourceName = 'MSFT_CertReq'

#region HEADER
# Integration Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit
#endregion

# Begin Testing
try
{
    InModuleScope $script:DSCResourceName {
        $definedRuntimeTypes = ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object -FilterScript { $null -ne $_.DefinedTypes}).GetTypes()
        $validThumbprint = (
            $definedRuntimeTypes | Where-Object -FilterScript {
                $_.BaseType.BaseType -eq [System.Security.Cryptography.HashAlgorithm] -and
                ($_.Name -cmatch 'Managed$' -or $_.Name -cmatch 'Provider$')
            } | Select-Object -First 1 | ForEach-Object -Process {
                (New-Object $_).ComputeHash([String]::Empty) | ForEach-Object -Process {
                    '{0:x2}' -f $_
                }
            }
        ) -join ''
        $invalidThumbprint            = $validThumbprint + 1
        $caServerFQDN                 = 'rootca.contoso.com'
        $caRootName                   = 'contoso-CA'
        $validSubject                 = 'Test Subject'
        $invalidSubject               = 'Invalid Test Subject'
        $validIssuer                  = "CN=$caRootName, DC=contoso, DC=com"
        $invalidIssuer                = 'CN=InvalidTest, DC=invalid, DC=com'
        $keyLength                    = '2048'
        $exportable                   = $true
        $providerName                 = '"Microsoft RSA SChannel Cryptographic Provider"'
        $oid                          = '1.3.6.1.5.5.7.3.1'
        $keyUsage                     = '0xa0'
        $certificateTemplate          = 'WebServer'
        $certificateDCTemplate        = 'DomainControllerAuthentication'
        $invalidCertificateTemplate   = 'Invalid Template'
        $subjectAltUrl                = 'contoso.com'
        $subjectAltName               = "dns=$subjectAltUrl"
        $friendlyName                 = "Test Certificate"
        $invalidFriendlyName          = 'Invalid Certificate'

        $validCert = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = "CN=$validSubject"
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            FriendlyName = $friendlyName
        }

        $validCertWithoutSubject = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = ''
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            FriendlyName = $friendlyName
        }

        $invalidCert = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $invalidThumbprint
            Subject      = "CN=$invalidSubject"
            Issuer       = $invalidIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            FriendlyName = $invalidFriendlyName
        }

        Add-Member -InputObject $validCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $expiringCert = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = "CN=$validSubject"
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(30) # Expires after
            FriendlyName = $friendlyName
        }

        Add-Member -InputObject $expiringCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $expiredCert = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = "CN=$validSubject"
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(-1) # Expires after
            FriendlyName = $friendlyName
        }
        Add-Member -InputObject $expiredCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $sanOid = New-Object -TypeName System.Security.Cryptography.Oid -Property @{FriendlyName = 'Subject Alternative Name'}
        $sanExt = @{
            oid      = $(,$sanOid)
            Critical = $false
        }
        Add-Member -InputObject $sanExt -MemberType ScriptMethod -Name Format -Force -Value {
            return "DNS Name=$subjectAltUrl"
        }

        $validCertSubjectDifferentOrder = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = 'E=xyz@contoso.com, CN=xyz.contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country'
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            FriendlyName = $friendlyName
        }
        Add-Member -InputObject $validCertSubjectDifferentOrder -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $validSANCert = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = "CN=$validSubject"
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            Extensions   = $sanExt
            FriendlyName = $friendlyName
        }
        Add-Member -InputObject $validSANCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $incorrectSanExt = @{
            oid      = $(,$sanOid)
            Critical = $false
        }
        Add-Member -InputObject $incorrectSanExt -MemberType ScriptMethod -Name Format -Force -Value {
            return "DNS Name=incorrect.com"
        }

        $incorrectSANCert = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = "CN=$validSubject"
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            Extensions   = $incorrectSanExt
            FriendlyName = $friendlyName
        }
        Add-Member -InputObject $incorrectSANCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $emptySANCert    = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = "CN=$validSubject"
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            Extensions   = @()
            FriendlyName = $friendlyName
        }
        Add-Member -InputObject $emptySANCert -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $incorrectFriendlyName = New-Object -TypeName PSObject -Property @{
            Thumbprint   = $validThumbprint
            Subject      = "CN=$validSubject"
            Issuer       = $validIssuer
            NotBefore    = (Get-Date).AddDays(-30) # Issued on
            NotAfter     = (Get-Date).AddDays(31) # Expires after
            FriendlyName = 'This name will not match'
        }
        Add-Member -InputObject $incorrectFriendlyName -MemberType ScriptMethod -Name Verify -Value {
            return $true
        }

        $caType         = 'Enterprise'
        $cepURL         = 'DummyURL'
        $cesURL         = 'DummyURL'

        $testUsername   = 'DummyUsername'
        $testPassword   = 'DummyPassword'
        $testCredential = New-Object System.Management.Automation.PSCredential $testUsername, (ConvertTo-SecureString $testPassword -AsPlainText -Force)

        $mock_getCertificateTemplateName_validCertificateTemplate = { $certificateTemplate }
        $mock_getCertificateTemplateName_invalidCertificateTemplate = { $invalidCertificateTemplate }
        $mock_getCertificateTemplateName_validDCCertificateTemplate = { $certificateDCTemplate }
        $mock_GetChildItem_validCertWithoutSubject = { $validCertWithoutSubject }
        $mock_getChildItem_validCert = { $validCert }
        $mock_getChildItem_expiredCert = { $expiredCert }
        $mock_getChildItem_expiringCert = { $expiringCert }
        $mock_getChildItem_validSANCert = { $validSANCert }
        $mock_getChildItem_validCertSubjectDifferentOrder = { $validCertSubjectDifferentOrder }
        $mock_getChildItem_incorrectSANCert = { $incorrectSANCert }
        $mock_getChildItem_emptySANCert = { $emptySANCert }
        $mock_getChildItem_incorrectFriendlyName = { $incorrectFriendlyName }
        $mock_getCertificateSan_subjectAltName = { $subjectAltName }

        $paramsStandard = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $false
            FriendlyName          = $friendlyName
            KeyType               = 'RSA'
        }

        $paramsStandardDomainController = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateDCTemplate
            Credential            = $testCredential
            AutoRenew             = $false
            FriendlyName          = $friendlyName
        }

        $paramsInvalid = @{
            Subject               = $invalidSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $false
            FriendlyName          = $invalidFriendlyName
        }

        $paramsAutoDiscovery = @{
            Subject               = $validSubject
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $false
            FriendlyName          = $friendlyName
        }

        $paramsAutoRenew = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $true
            FriendlyName          = $friendlyName
        }

        $paramsNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $null
            AutoRenew             = $false
            FriendlyName          = $friendlyName
        }

        $paramsStandardMachineContext = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $false
            FriendlyName          = $friendlyName
            UseMachineContext     = $true
        }

        $paramsAutoRenewNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $null
            AutoRenew             = $true
            FriendlyName          = $friendlyName
        }

        $paramsKeyLength4096AutoRenewNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = '4096'
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $null
            AutoRenew             = $true
            FriendlyName          = $friendlyName
        }

        $paramsSubjectDifferentOrder = @{
            Subject               = 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country'
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $True
            FriendlyName          = $friendlyName
        }

        $paramsSubjectAltName = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            SubjectAltName        = $subjectAltName
            AutoRenew             = $false
            FriendlyName          = $friendlyName
        }

        $paramsSubjectAltNameNoCred = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $null
            SubjectAltName        = $subjectAltName
            AutoRenew             = $false
            FriendlyName          = $friendlyName
        }

        $paramsStandaloneWebEnrollment = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $false
            CAType                = 'Standalone'
            CepURL                = $cepURL
            CesURL                = $cesURL
            FriendlyName          = $friendlyName
        }

        $paramsEnterpriseWebEnrollment = @{
            Subject               = $validSubject
            CAServerFQDN          = $caServerFQDN
            CARootName            = $caRootName
            KeyLength             = $keyLength
            Exportable            = $exportable
            ProviderName          = $providerName
            OID                   = $oid
            KeyUsage              = $keyUsage
            CertificateTemplate   = $certificateTemplate
            Credential            = $testCredential
            AutoRenew             = $false
            CAType                = $caType
            CepURL                = $cepURL
            CesURL                = $cesURL
            FriendlyName          = $friendlyName
        }

        $paramRsaValid = @{
            KeyType   = 'RSA'
            KeyLength = '2048'
        }

        $paramRsaInvalid = @{
            KeyType   = 'RSA'
            KeyLength = '384'
        }

        $paramEcdhValid = @{
            KeyType   = 'ECDH'
            KeyLength = '384'
        }

        $paramEcdhInvalid = @{
            KeyType   = 'ECDH'
            KeyLength = '2048'
        }

        $certInf = @"
[NewRequest]
Subject = "CN=$validSubject"
KeySpec = 1
KeyLength = $keyLength
Exportable = $($exportable.ToString().ToUpper())
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = $providerName
ProviderType = 12
RequestType = CMC
KeyUsage = $keyUsage
FriendlyName = "$friendlyName"
[RequestAttributes]
CertificateTemplate = "$certificateTemplate"
[EnhancedKeyUsageExtension]
OID = $oid
"@

        $certInfNoTemplate = @"
[NewRequest]
Subject = "CN=$validSubject"
KeySpec = 1
KeyLength = $keyLength
Exportable = $($exportable.ToString().ToUpper())
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = $providerName
ProviderType = 12
RequestType = CMC
KeyUsage = $keyUsage
FriendlyName = "$friendlyName"
[EnhancedKeyUsageExtension]
OID = $oid
"@

        $certInfRenew = @"
[NewRequest]
Subject = "CN=$validSubject"
KeySpec = 1
KeyLength = $keyLength
Exportable = $($exportable.ToString().ToUpper())
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = $providerName
ProviderType = 12
RequestType = CMC
KeyUsage = $keyUsage
FriendlyName = "$friendlyName"
RenewalCert = $validThumbprint
[RequestAttributes]
CertificateTemplate = "$certificateTemplate"
[EnhancedKeyUsageExtension]
OID = $oid
"@

        $certInfKeyRenew = @"
[NewRequest]
Subject = "CN=$validSubject"
KeySpec = 1
KeyLength = 4096
Exportable = $($exportable.ToString().ToUpper())
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = $providerName
ProviderType = 12
RequestType = CMC
KeyUsage = $keyUsage
FriendlyName = "$friendlyName"
RenewalCert = $validThumbprint
[RequestAttributes]
CertificateTemplate = "$certificateTemplate"
[EnhancedKeyUsageExtension]
OID = $oid
"@

        $certInfSubjectAltName = @"
[NewRequest]
Subject = "CN=$validSubject"
KeySpec = 1
KeyLength = $keyLength
Exportable = $($exportable.ToString().ToUpper())
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = $providerName
ProviderType = 12
RequestType = CMC
KeyUsage = $keyUsage
FriendlyName = "$friendlyName"
[RequestAttributes]
CertificateTemplate = "$certificateTemplate"
[EnhancedKeyUsageExtension]
OID = $oid
[Extensions]
2.5.29.17 = "{text}$subjectAltName"
"@

        $pathCertLocalMachineMy_parameterFilter = {
            $Path -eq 'Cert:\LocalMachine\My'
        }
        $pathCertReqTestOut_parameterFilter = {
            $Path -eq 'CertReq-Test.out'
        }
        $pathCertReqTestReq_parameterFilter = {
            $Path -eq 'CertReq-Test.req'
        }
        $pathCertReqTestCer_parameterFilter = {
            $Path -eq 'CertReq-Test.cer'
        }
        $pathTemp_parameterFilter = {
            $Path -eq $env:Temp
        }

        function Start-Win32Process
        {
            param
            (
                [Parameter()]
                $Path,

                [Parameter()]
                $Arguments,

                [Parameter()]
                [System.Management.Automation.PSCredential]
                $Credential
            )
        }

        function Wait-Win32ProcessStop
        {
            param
            (
                [Parameter()]
                $Path,

                [Parameter()]
                $Arguments,

                [Parameter()]
                [System.Management.Automation.PSCredential]
                $Credential
            )
        }

        Describe 'MSFT_CertReq\Get-TargetResource' {
            BeforeAll {
                Mock -CommandName Get-ChildItem `
                    -Mockwith { $validCert } `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                Mock -CommandName Get-CertificateSan `
                    -MockWith { $subjectAltName }

                Mock -CommandName Find-CertificateAuthority -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CAServerFQDN = 'rootca.contoso.com'
                            CARootName = 'contoso-CA'
                    }
                }
            }

            Context 'When called without auto discovery' {
                $result = Get-TargetResource @paramsStandard -Verbose

                It 'Should return a hashtable' {
                    $result | Should -BeOfType System.Collections.Hashtable
                }

                It 'Should contain the input values' {
                    $result.Subject              | Should -BeExactly $validSubject
                    $result.CAServerFQDN         | Should -BeNullOrEmpty
                    $result.CARootName           | Should -BeExactly $caRootName
                    $result.KeyLength            | Should -BeNullOrEmpty
                    $result.Exportable           | Should -BeNullOrEmpty
                    $result.ProviderName         | Should -BeNullOrEmpty
                    $result.OID                  | Should -BeNullOrEmpty
                    $result.KeyUsage             | Should -BeNullOrEmpty
                    $result.CertificateTemplate  | Should -BeExactly $certificateTemplate
                    $result.SubjectAltName       | Should -BeNullOrEmpty
                    $result.FriendlyName         | Should -BeExactly $friendlyName
                }
            }

            Context 'When called with auto discovery' {
                $result = Get-TargetResource @paramsAutoDiscovery -Verbose

                It 'Should return a hashtable' {
                    $result | Should -BeOfType System.Collections.Hashtable
                }

                It 'Should contain the input values and the CA should be auto-discovered' {
                    $result.Subject              | Should -BeExactly $validSubject
                    $result.CAServerFQDN         | Should -BeExactly $caServerFQDN
                    $result.CARootName           | Should -BeExactly $caRootName
                    $result.KeyLength            | Should -BeNullOrEmpty
                    $result.Exportable           | Should -BeNullOrEmpty
                    $result.ProviderName         | Should -BeNullOrEmpty
                    $result.OID                  | Should -BeNullOrEmpty
                    $result.KeyUsage             | Should -BeNullOrEmpty
                    $result.CertificateTemplate  | Should -BeExactly $certificateTemplate
                    $result.SubjectAltName       | Should -BeNullOrEmpty
                    $result.FriendlyName         | Should -BeExactly $friendlyName
                }

                It 'Should call the mocked function Find-CertificateAuthority once' {
                    Assert-MockCalled -CommandName Find-CertificateAuthority -Exactly -Times 1
                }
            }

            Mock -CommandName Get-ChildItem -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' } `
                -Mockwith { $invalidCert }

            Context 'When called without valid cert' {
                $results = Get-TargetResource @paramsInvalid -Verbose

                It 'Should return null' {
                    $results | Should -BeNullOrEmpty
                }
            }
        }


        #region Set-TargetResource
        Describe "$dscResourceName\Set-TargetResource" -Tag 'Set' {
            BeforeAll {
                Mock -CommandName Test-Path -MockWith { $true } `
                    -ParameterFilter $pathCertReqTestReq_parameterFilter

                Mock -CommandName Test-Path -MockWith { $true } `
                    -ParameterFilter $pathCertReqTestCer_parameterFilter

                Mock -CommandName Test-Path -MockWith { $true } `
                    -ParameterFilter $pathCertReqTestOut_parameterFilter

                Mock -CommandName Join-Path -MockWith { 'CertReq-Test' }

                Mock -CommandName CertReq.exe
            }

            Context 'When autorenew is false, credentials not passed' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInf
                    }

                It 'Should not throw' {
                    { Set-TargetResource @paramsNoCred -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path  -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }
                }
            }

            Context 'When autorenew is true, credentials not passed and certificate does not exist' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInf
                    }

                Mock -CommandName Get-ChildItem

                It 'Should not throw' {
                    { Set-TargetResource @paramsAutoRenewNoCred -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When autorenew is true, credentials not passed and valid certificate exists' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInf
                    }

                Mock -CommandName Get-ChildItem -Mockwith { $validCert }

                It 'Should not throw' {
                    { Set-TargetResource @paramsAutoRenewNoCred -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When autorenew is true, credentials not passed and expiring certificate exists' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInfRenew
                    }

                Mock -CommandName Get-ChildItem -Mockwith { $expiringCert }

                It 'Should not throw' {
                    { Set-TargetResource @paramsAutoRenewNoCred -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInfRenew
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3
                }
            }

            Context 'When autorenew is true, credentials not passed and expired certificate exists' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInfRenew
                    }

                Mock -CommandName Get-ChildItem -Mockwith { $expiredCert }

                It 'Should not throw' {
                    { Set-TargetResource @paramsAutoRenewNoCred -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInfRenew
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When autorenew is true, credentials not passed, keylength passed and expired certificate exists' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInfKeyRenew
                    }

                Mock -CommandName Get-ChildItem -Mockwith { $expiredCert }

                It 'Should not throw' {
                    { Set-TargetResource @paramsKeyLength4096AutoRenewNoCred -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInfKeyRenew
                        }

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When autorenew is false, credentials not passed, certificate request creation failed' {
                Mock -CommandName Test-Path -MockWith { $false } `
                    -ParameterFilter $pathCertReqTestReq_parameterFilter

                Mock -CommandName Test-Path -MockWith { $false } `
                    -ParameterFilter $pathCertReqTestCer_parameterFilter

                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInf
                    }

                Mock -CommandName Get-ChildItem

                $errorRecord = Get-InvalidOperationRecord `
                    -Message ($LocalizedData.CertificateReqNotFoundError -f 'CertReq-Test.req')

                It 'Should throw CertificateReqNotFoundError exception' {
                    { Set-TargetResource @paramsNoCred -Verbose } | Should -Throw $errorRecord
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 0 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 1

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 0 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When autorenew is false, credentials not passed, certificate creation failed' {
                Mock -CommandName Test-Path -MockWith { $false } `
                    -ParameterFilter $pathCertReqTestCer_parameterFilter

                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf'
                    }

                Mock -CommandName Get-ChildItem

                $errorRecord = Get-InvalidOperationRecord `
                    -Message ($LocalizedData.CertificateCerNotFoundError -f 'CertReq-Test.cer')

                It 'Should throw CertificateCerNotFoundError exception' {
                    { Set-TargetResource @paramsNoCred -Verbose } | Should -Throw $errorRecord
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 2

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 0 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When autorenew is false, credentials passed' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf'
                    }

                Mock -CommandName Get-ChildItem

                Mock -CommandName Get-Content -Mockwith { 'Output' } `
                    -ParameterFilter $pathCertReqTestOut_parameterFilter

                Mock -CommandName Remove-Item `
                    -ParameterFilter $pathCertReqTestOut_parameterFilter

                Mock -CommandName Import-Module

                Mock -CommandName Start-Win32Process -ModuleName MSFT_CertReq

                Mock -CommandName Wait-Win32ProcessStop -ModuleName MSFT_CertReq

                It 'Should not throw' {
                    { Set-TargetResource @paramsStandard -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestOut_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 2

                    Assert-MockCalled -CommandName Get-Content -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestOut_parameterFilter

                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestOut_parameterFilter

                    Assert-MockCalled -CommandName Start-Win32Process -ModuleName MSFT_CertReq -Exactly -Times 1

                    Assert-MockCalled -CommandName Wait-Win32ProcessStop -ModuleName MSFT_CertReq -Exactly -Times 1

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 0 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When autorenew is false, credentials passed, passed ' {
                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                Mock -CommandName Get-Content -Mockwith { 'Output' } `
                    -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                Mock -CommandName Remove-Item `
                    -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                Mock -CommandName Import-Module

                Mock -CommandName Start-Win32Process -ModuleName MSFT_CertReq

                Mock -CommandName Wait-Win32ProcessStop -ModuleName MSFT_CertReq

                It 'Should not throw' {
                    { Set-TargetResource @paramsStandardMachineContext -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.req' }

                    Assert-MockCalled -CommandName Test-Path  -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.cer' }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly 2

                    Assert-MockCalled -CommandName Start-Win32Process -ModuleName MSFT_CertReq -Exactly 1 `
                        -ParameterFilter { $Arguments -like "*-adminforcemachine*" }

                    Assert-MockCalled -CommandName Wait-Win32ProcessStop -ModuleName MSFT_CertReq -Exactly -Times 1

                    Assert-MockCalled -CommandName Test-Path  -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                    Assert-MockCalled -CommandName Get-Content -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.out' }
                }
            }

            Context 'When autorenew is false, credeintals passed, no .out file' {
                Mock -CommandName Test-Path -MockWith { $false } `
                    -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                Mock -CommandName Get-ChildItem -Mockwith { } `
                    -ParameterFilter { $Path -eq 'Cert:\LocalMachine\My' }

                Mock -CommandName Get-Content -Mockwith { 'Output' } `
                    -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                Mock -CommandName Remove-Item `
                    -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                Mock -CommandName Import-Module

                Mock -CommandName New-InvalidOperationException

                Mock -CommandName Start-Win32Process -ModuleName MSFT_CertReq

                Mock -CommandName Wait-Win32ProcessStop -ModuleName MSFT_CertReq

                It 'Should not throw' {
                    { Set-TargetResource @paramsStandard -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.req' }

                    Assert-MockCalled -CommandName Test-Path  -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.cer' }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly 2

                    Assert-MockCalled -CommandName Start-Win32Process -ModuleName MSFT_CertReq -Exactly -Times 1

                    Assert-MockCalled -CommandName Wait-Win32ProcessStop -ModuleName MSFT_CertReq -Exactly -Times 1

                    Assert-MockCalled -CommandName Test-Path  -Exactly -Times 1 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                    Assert-MockCalled -CommandName Get-Content -Exactly 0 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                    Assert-MockCalled -CommandName Remove-Item -Exactly 0 `
                        -ParameterFilter { $Path -eq 'CertReq-Test.out' }

                    Assert-MockCalled -CommandName New-InvalidOperationException -Exactly 1
                }
            }

            Mock -CommandName Set-Content `
                -ParameterFilter {
                    $Path -eq 'CertReq-Test.inf' -and `
                    $Value -eq $certInfSubjectAltName
                }

            Context 'When autorenew is false, subject alt name passed, credentials not passed' {
                Mock -CommandName Set-Content `
                    -ParameterFilter {
                        $Path -eq 'CertReq-Test.inf' -and `
                        $Value -eq $certInfSubjectAltName
                    }

                Mock -CommandName Get-ChildItem

                It 'Should not throw' {
                    { Set-TargetResource @paramsSubjectAltNameNoCred -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInfSubjectAltName
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 0 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When standalone CA, URL for CEP and CES passed, credentials passed, inf not containing template' {
                Mock -CommandName Set-Content -ParameterFilter {
                    $Path -eq 'CertReq-Test.inf'
                }

                Mock -CommandName Get-ChildItem

                It 'Should not throw' {
                    { Set-TargetResource @paramsStandaloneWebEnrollment -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInfNoTemplate
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 0 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                }
            }

            Context 'When enterprise CA, URL for CEP and CES passed, credentials passed' {
                Mock -CommandName Set-Content -ParameterFilter {
                    $Path -eq 'CertReq-Test.inf'
                }

                Mock -CommandName Get-ChildItem

                It 'Should not throw' {
                    { Set-TargetResource @paramsEnterpriseWebEnrollment -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 3

                    Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 0 `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter
                    }
            }

            Context 'When auto-discovered CA, autorenew is false, credentials passed' {
                Mock -CommandName Set-Content -ParameterFilter {
                    $Path -eq 'CertReq-Test.inf'
                }

                Mock -CommandName Get-ChildItem

                Mock -CommandName Get-Content -Mockwith { 'Output' } `
                    -ParameterFilter $pathCertReqTestOut_parameterFilter

                Mock -CommandName Remove-Item `
                    -ParameterFilter $pathCertReqTestOut_parameterFilter

                Mock -CommandName Import-Module

                Mock -CommandName Start-Win32Process

                Mock -CommandName Wait-Win32ProcessStop

                Mock -CommandName Find-CertificateAuthority -MockWith {
                    return New-Object -TypeName psobject -Property @{
                        CARootName = "ContosoCA"
                        CAServerFQDN = "ContosoVm.contoso.com"
                    }
                }

                It 'Should not throw' {
                    { Set-TargetResource @paramsAutoDiscovery -Verbose } | Should -Not -Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Join-Path -Exactly -Times 1 `
                        -ParameterFilter $pathTemp_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestReq_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestCer_parameterFilter

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestOut_parameterFilter

                    Assert-MockCalled -CommandName Set-Content -Exactly -Times 1 `
                        -ParameterFilter {
                            $Path -eq 'CertReq-Test.inf' -and `
                            $Value -eq $certInf
                        }

                    Assert-MockCalled -CommandName CertReq.exe -Exactly -Times 2

                    Assert-MockCalled -CommandName Start-Win32Process -ModuleName MSFT_CertReq -Exactly -Times 1

                    Assert-MockCalled -CommandName Wait-Win32ProcessStop -ModuleName MSFT_CertReq -Exactly -Times 1

                    Assert-MockCalled -CommandName Test-Path -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestOut_parameterFilter

                    Assert-MockCalled -CommandName Get-Content -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestOut_parameterFilter

                    Assert-MockCalled -CommandName Remove-Item -Exactly -Times 1 `
                        -ParameterFilter $pathCertReqTestOut_parameterFilter

                    Assert-MockCalled -CommandName Find-CertificateAuthority -Exactly -Times 1
                }
            }
        }

        Describe 'MSFT_CertReq\Test-TargetResource' {
            Context 'When a valid certificate does not exist and a certificate with an empty Subject exists in the Store' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_GetChildItem_validCertWithoutSubject

                It 'Should return false' {
                    Test-TargetResource @paramsStandard -Verbose | Should -Be $false
                }
            }

            Context 'When a valid certificate does not exist' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter

                It 'Should return false' {
                    Test-TargetResource @paramsStandard -Verbose | Should -Be $false
                }
            }

            Context 'When a valid certificate already exists' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock `
                    -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter

                It 'Should return false' {
                    Test-TargetResource @paramsStandard -Verbose | Should -Be $false
                }
            }

            Context 'When a valid certificate already exists and is not about to expire' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_getChildItem_validCert

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                Mock -CommandName Get-CertificateSan `
                    -MockWith $mock_getCertificateSan_subjectAltName

                It 'Should return true' {
                    Test-TargetResource @paramsStandard -Verbose | Should -Be $true
                }
            }

            Context 'When an expired certificate exists and autorenew set' {
                It 'Should return true' {
                    Mock -CommandName Get-ChildItem `
                        -ParameterFilter {
                            $Path -eq 'Cert:\LocalMachine\My'
                        } `
                        -Mockwith $mock_getChildItem_expiredCert

                    Mock -CommandName Get-CertificateTemplateName `
                        -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                    Mock -CommandName Get-CertificateSan `
                        -MockWith $mock_getCertificateSan_subjectAltName

                    Test-TargetResource @paramsStandard -Verbose | Should -Be $false
                }
            }

            Context 'When a valid certificate already exists and is about to expire and autorenew set' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_getChildItem_expiringCert

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                Test-TargetResource @paramsAutoRenew -Verbose | Should -Be $false
            }

            Context 'When a valid certificate already exists and X500 subjects are in a different order but match' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_getChildItem_validCertSubjectDifferentOrder

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                It 'Should return true' {
                    Test-TargetResource @paramsSubjectDifferentOrder -Verbose | Should -Be $true
                }
            }

            Context 'When a valid certificate already exists and DNS SANs match' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_getChildItem_validSANCert

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                It 'Should return true' {
                    Test-TargetResource @paramsSubjectAltName -Verbose | Should -Be $true
                }
            }

            Context 'When a certificate exists but contains incorrect DNS SANs' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_getChildItem_incorrectSANCert

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                It 'Should return false' {
                    Test-TargetResource @paramsSubjectAltName -Verbose | Should -Be $false
                }
            }

            Context 'When a certificate exists but does not contain specified DNS SANs' {
                Mock -CommandName Find-CertificateAuthority -MockWith {
                    return New-Object -TypeName psobject -Property @{
                        CARootName = "ContosoCA"
                        CAServerFQDN = "ContosoVm.contoso.com"
                    }
                }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_getChildItem_emptySANCert

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                It 'Should return false' {
                    Test-TargetResource @paramsSubjectAltName -Verbose | Should -Be $false
                }
            }

            Context 'When a certificate exists but does not match the Friendly Name' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                    -Mockwith $mock_getChildItem_incorrectFriendlyName

                Mock -CommandName Get-CertificateTemplateName `
                    -MockWith $mock_getCertificateTemplateName_validCertificateTemplate

                It 'Should return false' {
                    Test-TargetResource @paramsStandard -Verbose | Should -Be $false
                }
            }


            Context 'When a certificate exists but does not match the Certificate Template' {
                It 'Should return false' {
                    Mock -CommandName Get-ChildItem `
                        -ParameterFilter {
                            $Path -eq 'Cert:\LocalMachine\My'
                        } `
                        -Mockwith $mock_getChildItem_validCert

                    Mock -CommandName Get-CertificateTemplateName `
                        -MockWith $mock_getCertificateTemplateName_invalidCertificateTemplate

                    Test-TargetResource @paramsStandard -Verbose | Should -Be $false
                }
            }

            Context 'When a Domain Controller certificate template is used, A valid certificate already exists and is not about to expire' {
                It 'Should return true' {
                    Mock -CommandName Get-ChildItem `
                        -ParameterFilter $pathCertLocalMachineMy_parameterFilter `
                        -Mockwith $mock_getChildItem_validCert

                    Mock -CommandName Get-CertificateTemplateName `
                        -MockWith $mock_getCertificateTemplateName_validDCCertificateTemplate

                    Mock -CommandName Get-CertificateSan `
                        -MockWith $mock_getCertificateSan_subjectAltName

                    Test-TargetResource @paramsStandardDomainController -Verbose | Should -Be $true
                }
            }

            Context 'When auto-discover of the CA is enabled' {
                Mock -CommandName Find-CertificateAuthority `
                    -MockWith {
                        return New-Object -TypeName psobject -Property @{
                            CARootName = "ContosoCA"
                            CAServerFQDN = "ContosoVm.contoso.com"
                        }
                    }

                Mock -CommandName Get-ChildItem `
                    -ParameterFilter $pathCertLocalMachineMy_parameterFilter

                It 'Should return false' {
                    Test-TargetResource @paramsAutoDiscovery -Verbose | Should -Be $false
                }

                It 'Should execute the auto-discovery function' {
                    Assert-MockCalled -CommandName Find-CertificateAuthority -Exactly -Times 1
                }
            }
        }

        Describe "$dscResourceName\Assert-ResourceProperty"{
            Context 'When RSA key type and key length is valid' {
                It 'Should not throw' {
                    { Assert-ResourceProperty @paramRsaValid -Verbose } | Should -Not -Throw
                }
            }

            Context 'When RSA key type and key length is invalid' {
                $errorRecord = Get-InvalidArgumentRecord `
                -Message (($LocalizedData.InvalidKeySize) -f '384','RSA') -ArgumentName 'KeyLength'

                It 'Should not throw' {
                    { Assert-ResourceProperty @paramRsaInvalid -Verbose } | Should -Throw $errorRecord
                }
            }

            Context 'When ECDH key type and key length is valid' {
                It 'Should not throw' {
                    { Assert-ResourceProperty @paramEcdhValid -Verbose } | Should -Not -Throw
                }
            }

            Context 'When ECDH key type and key length is invalid' {
                $errorRecord = Get-InvalidArgumentRecord `
                -Message (($LocalizedData.InvalidKeySize) -f '2048','ECDH') -ArgumentName 'KeyLength'

                It 'Should not throw' {
                    { Assert-ResourceProperty @paramEcdhInvalid -Verbose } | Should -Throw $errorRecord
                }
            }
        }

        Describe 'MSFT_CertReq\Compare-CertificateSubject' {
            Context 'When called with matching subjects containing with single X500 paths' {
                It 'Should return a true' {
                    Compare-CertificateSubject `
                        -ReferenceSubject 'CN=TestSubject' `
                        -DifferenceSubject 'CN=TestSubject' | Should -Be $true
                }
            }

            Context 'When called without matching subjects containing with single X500 paths' {
                It 'Should return a false' {
                    Compare-CertificateSubject `
                        -ReferenceSubject 'CN=TestSubject' `
                        -DifferenceSubject 'CN=SubjectTest' | Should -Be $false
                }
            }

            Context 'When called with matching subjects containing with X500 paths in the same order' {
                It 'Should return a true' {
                    Compare-CertificateSubject `
                        -ReferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' `
                        -DifferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' | Should -Be $true
                }
            }

            Context 'When called with matching subjects containing with X500 paths in different order' {
                It 'Should return a true' {
                    Compare-CertificateSubject `
                        -ReferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' `
                        -DifferenceSubject 'E=xyz@contoso.com, CN=xyz.contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' | Should -Be $true
                }
            }

            Context 'When called with different subjects containing with X500 paths in the same order' {
                It 'Should return a false' {
                    Compare-CertificateSubject `
                        -ReferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' `
                        -DifferenceSubject 'CN=xyz.contoso.com, E=test@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' | Should -Be $false
                }
            }

            Context 'When called with different subjects containing with X500 paths in the same order but missing element' {
                It 'Should return a false' {
                    Compare-CertificateSubject `
                        -ReferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' `
                        -DifferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, C=country' | Should -Be $false
                }
            }

            Context 'When called with a null ReferenceSubject' {
                It 'Should return a false' {
                    Compare-CertificateSubject `
                        -ReferenceSubject $null `
                        -DifferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, C=country' | Should -Be $false
                }
            }

            Context 'When called with an empty ReferenceSubject' {
                It 'Should return a false' {
                    Compare-CertificateSubject `
                        -ReferenceSubject '' `
                        -DifferenceSubject 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, C=country' | Should -Be $false
                }
            }
        }

        Describe 'MSFT_CertReq\Compare-CertificateIssuer' {
            Context 'When called with certificate issuer with single X500 paths matching the CA root name' {
                It 'Should return a true' {
                    Compare-CertificateIssuer `
                        -Issuer 'CN=xyz.contoso.com' `
                        -CARootName 'xyz.contoso.com' | Should -Be $true
                }
            }

            Context 'When called with certificate issuer with multiple X500 paths matching the CA root name' {
                It 'Should return a true' {
                    Compare-CertificateIssuer `
                        -Issuer 'CN=xyz.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' `
                        -CARootName 'xyz.contoso.com' | Should -Be $true
                }
            }

            Context 'When called with certificate issuer with single X500 paths not matching the CA root name' {
                It 'Should return a false' {
                    Compare-CertificateIssuer `
                        -Issuer 'CN=abc.contoso.com' `
                        -CARootName 'xyz.contoso.com' | Should -Be $false
                }
            }

            Context 'When called with certificate issuer with multiple X500 paths not matching the CA root name' {
                It 'Should return a true' {
                    Compare-CertificateIssuer `
                        -Issuer 'CN=abc.contoso.com, E=xyz@contoso.com, OU=Organisation Unit, O=Organisation, L=Locality, S=State, C=country' `
                        -CARootName 'xyz.contoso.com' | Should -Be $false
                }
            }
        }
    }
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $testEnvironment
    #endregion
}
