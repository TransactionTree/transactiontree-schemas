[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$releaseDir = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $releaseDir '..\..')).Path
$schemaPath = Join-Path $releaseDir 'TTDR-3.3.0.xsd'
$legacySchemaPath = Join-Path $repoRoot 'vrg\3.2.2\TTDR-3.2.2.xsd'
$examplesDir = Join-Path $releaseDir 'examples'
$invalidSecurityDir = Join-Path $releaseDir 'tests\security-invalid'
$validSecurityDir = Join-Path $releaseDir 'tests\security-valid'
$legacyExamplesDir = Join-Path $releaseDir 'tests\legacy'
$namespace = 'https://www.transactiontree.com/framework/schema/vrg/3.3.0/TTDR3.3.0.xsd'
$legacyNamespace = 'https://www.transactiontree.com/framework/schema/vrg/3.2.2/TTDR3.2.2.xsd'

function New-SchemaSettings {
    param(
        [Parameter(Mandatory)] [string] $Schema,
        [Parameter(Mandatory)] [string] $TargetNamespace
    )

    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = [System.Xml.XmlUrlResolver]::new()
    $settings.ValidationType = [System.Xml.ValidationType]::Schema
    $settings.Schemas.XmlResolver = [System.Xml.XmlUrlResolver]::new()
    $null = $settings.Schemas.Add($TargetNamespace, $Schema)
    $settings.Schemas.Compile()
    return $settings
}

function Test-XmlFile {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [System.Xml.XmlReaderSettings] $Settings
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $handler = [System.Xml.Schema.ValidationEventHandler]{
        param($sender, $event)
        $errors.Add($event.Message)
    }
    $Settings.add_ValidationEventHandler($handler)
    $reader = [System.Xml.XmlReader]::Create($Path, $Settings)
    try {
        while ($reader.Read()) { }
    }
    finally {
        $reader.Dispose()
        $Settings.remove_ValidationEventHandler($handler)
    }

    if ($errors.Count -gt 0) {
        throw "Schema validation failed for '$Path':`n$($errors -join "`n")"
    }
}

function Test-Luhn {
    param([AllowEmptyString()] [string] $Digits)

    if ($Digits -notmatch '^\d{13,19}$') { return $false }
    $sum = 0
    $alternate = $false
    for ($index = $Digits.Length - 1; $index -ge 0; $index--) {
        $number = [int]::Parse($Digits[$index].ToString())
        if ($alternate) {
            $number *= 2
            if ($number -gt 9) { $number -= 9 }
        }
        $sum += $number
        $alternate = -not $alternate
    }
    return ($sum % 10) -eq 0
}

function Test-SecurityPolicy {
    param([Parameter(Mandatory)] [string] $Path)

    [xml] $document = Get-Content -LiteralPath $Path -Raw
    $prohibitedNames = @(
        'PAN', 'PrimaryAccountNumber', 'TrackData', 'Track1', 'Track2',
        'CVV', 'CVC', 'CID', 'PIN', 'PINBlock', 'EMVCryptogram',
        'ApplicationCryptogram', 'ARQC', 'DateOfBirth', 'DOB',
        'GovernmentID', 'GovernmentId', 'DocumentNumber', 'IdentityDocument',
        'DriverLicense', 'DLNo', 'Passport', 'PassportID', 'Birthday',
        'CardNumber', 'AccountNumber', 'LoyaltyCardNumber',
        'RawCredential', 'Password', 'ClientSecret', 'PrivateKey'
    )
    $unsafeText = '(?i)(date[-_ ]?of[-_ ]?birth|\bdob\s*[:=]|government[-_ ]?id\s*[:=]|track\s*[12]?\s*[:=]|cvv\s*[:=]|cvc\s*[:=]|\bpin\s*[:=]|pin[-_ ]?block\s*[:=]|9f26\s*[:=]|\barqc\s*[:=])'

    foreach ($node in $document.SelectNodes('//*')) {
        if ($node.LocalName -in $prohibitedNames) {
            throw "Security policy failed for '$Path': prohibited element '$($node.LocalName)'."
        }

        # Scan leaf values only. Scanning InnerText on containers concatenates unrelated child
        # values and can manufacture a false PAN candidate that never appeared in the payload.
        if ($node.SelectNodes('./*').Count -eq 0) {
            $text = $node.InnerText.Trim()
            if ($text -match $unsafeText) {
                throw "Security policy failed for '$Path': prohibited sensitive-data marker in '$($node.LocalName)'."
            }
            # Check each exact PAN length separately. A single greedy 13-19 digit match can join
            # a valid PAN to an adjacent numeric token and then miss it when the combined value
            # fails Luhn (for example, "4111...1111 1").
            $seenCandidates = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($digitCount in 13..19) {
                $pattern = '(?<!\d)(?:\d[ -]?){' + ($digitCount - 1) + '}\d(?!\d)'
                foreach ($candidate in [regex]::Matches($text, $pattern)) {
                    $digits = $candidate.Value -replace '[^0-9]', ''
                    if ($seenCandidates.Add($digits) -and (Test-Luhn -Digits $digits)) {
                        throw "Security policy failed for '$Path': '$($node.LocalName)' appears to contain a PAN."
                    }
                }
            }
        }
        if ($node.LocalName -eq 'MaskedAccount' -and $node.InnerText -notmatch '^(?:\d{1,4}|[Xx*•-]+\d{1,4})$') {
            throw "Security policy failed for '$Path': MaskedAccount is not display-safe."
        }
    }
}

function Assert-SchemaRejected {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [System.Xml.XmlReaderSettings] $Settings,
        [Parameter(Mandatory)] [string] $CaseName
    )

    $rejected = $false
    try {
        Test-XmlFile -Path $Path -Settings $Settings
    }
    catch {
        $rejected = $true
    }
    if (-not $rejected) {
        throw "Schema-negative case '$CaseName' unexpectedly validated."
    }
    Write-Host "PASS rejected $CaseName"
}

function Get-StructuralSchemaText {
    param([Parameter(Mandatory)] [string] $Path)

    $readerSettings = [System.Xml.XmlReaderSettings]::new()
    $readerSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $readerSettings.XmlResolver = $null
    $document = [System.Xml.XmlDocument]::new()
    $document.PreserveWhitespace = $false
    $reader = [System.Xml.XmlReader]::Create($Path, $readerSettings)
    try {
        $document.Load($reader)
    }
    finally {
        $reader.Dispose()
    }
    foreach ($comment in @($document.SelectNodes('//comment()'))) {
        $null = $comment.ParentNode.RemoveChild($comment)
    }
    return $document.OuterXml
}

Write-Host 'Compiling TTDR 3.3.0 and TTDR 3.2.2 schemas...'
$settings = New-SchemaSettings -Schema $schemaPath -TargetNamespace $namespace
$legacySettings = New-SchemaSettings -Schema $legacySchemaPath -TargetNamespace $legacyNamespace

$examples = @(Get-ChildItem -LiteralPath $examplesDir -Filter '*.xml' | Sort-Object Name)
if ($examples.Count -eq 0) { throw 'No TTDR 3.3.0 examples were found.' }

foreach ($example in $examples) {
    Test-XmlFile -Path $example.FullName -Settings $settings
    Test-SecurityPolicy -Path $example.FullName
    Write-Host "PASS $($example.Name)"
}

$invalidSecurityFixtures = @(Get-ChildItem -LiteralPath $invalidSecurityDir -Filter '*.xml' | Sort-Object Name)
if ($invalidSecurityFixtures.Count -eq 0) { throw 'No invalid security fixtures were found.' }
foreach ($fixture in $invalidSecurityFixtures) {
    $rejected = $false
    try {
        Test-SecurityPolicy -Path $fixture.FullName
    }
    catch {
        $rejected = $true
    }
    if (-not $rejected) {
        throw "Security fixture '$($fixture.Name)' was not rejected."
    }
    Write-Host "PASS rejected $($fixture.Name)"
}

$validSecurityFixtures = @(Get-ChildItem -LiteralPath $validSecurityDir -Filter '*.xml' | Sort-Object Name)
if ($validSecurityFixtures.Count -eq 0) { throw 'No valid security fixtures were found.' }
foreach ($fixture in $validSecurityFixtures) {
    Test-SecurityPolicy -Path $fixture.FullName
    Write-Host "PASS security-valid $($fixture.Name)"
}

$legacyExamples = @(Get-ChildItem -LiteralPath $legacyExamplesDir -Filter '*.xml' | Sort-Object Name)
if ($legacyExamples.Count -eq 0) { throw 'No TTDR 3.2.2 compatibility examples were found.' }
foreach ($legacyExample in $legacyExamples) {
    Test-XmlFile -Path $legacyExample.FullName -Settings $legacySettings
    Write-Host "PASS legacy $($legacyExample.Name)"
}

$semanticNegativeCount = 0
$semanticTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("ttdr-3.3-negative-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $semanticTemp
try {
    $sourceExample = Join-Path $examplesDir 'restricted-offer-stored-value-sample.xml'

    [xml] $dangling = Get-Content -LiteralPath $sourceExample -Raw
    $danglingNs = [System.Xml.XmlNamespaceManager]::new($dangling.NameTable)
    $danglingNs.AddNamespace('t', $namespace)
    $danglingNode = $dangling.SelectSingleNode('//t:AgeVerification/t:LineReference', $danglingNs)
    $danglingNode.InnerText = 'missing-line-reference'
    $danglingPath = Join-Path $semanticTemp 'dangling-line-reference.xml'
    $dangling.Save($danglingPath)
    Assert-SchemaRejected -Path $danglingPath -Settings $settings -CaseName 'dangling line reference'
    $semanticNegativeCount++

    [xml] $duplicate = Get-Content -LiteralPath $sourceExample -Raw
    $duplicateNs = [System.Xml.XmlNamespaceManager]::new($duplicate.NameTable)
    $duplicateNs.AddNamespace('t', $namespace)
    $line = $duplicate.SelectSingleNode('//t:TransactionData/t:DetailedTransactionData', $duplicateNs)
    $duplicateLine = $line.CloneNode($true)
    $null = $line.ParentNode.InsertAfter($duplicateLine, $line)
    $duplicatePath = Join-Path $semanticTemp 'duplicate-line-reference.xml'
    $duplicate.Save($duplicatePath)
    Assert-SchemaRejected -Path $duplicatePath -Settings $settings -CaseName 'duplicate line reference'
    $semanticNegativeCount++

    [xml] $blankReference = Get-Content -LiteralPath (Join-Path $examplesDir 'car-wash-entitlement-sample.xml') -Raw
    $blankNs = [System.Xml.XmlNamespaceManager]::new($blankReference.NameTable)
    $blankNs.AddNamespace('t', $namespace)
    $blankNode = $blankReference.SelectSingleNode('//t:TransactionData/t:DetailedTransactionData/t:LineReference', $blankNs)
    $blankNode.InnerText = '   '
    $blankPath = Join-Path $semanticTemp 'blank-line-reference.xml'
    $blankReference.Save($blankPath)
    Assert-SchemaRejected -Path $blankPath -Settings $settings -CaseName 'blank line reference'
    $semanticNegativeCount++

    [xml] $oversizedDecimal = Get-Content -LiteralPath (Join-Path $examplesDir 'ev-mobile-sample.xml') -Raw
    $decimalNs = [System.Xml.XmlNamespaceManager]::new($oversizedDecimal.NameTable)
    $decimalNs.AddNamespace('t', $namespace)
    $decimalNode = $oversizedDecimal.SelectSingleNode('//t:EVChargingSession/t:EnergyDelivered/t:Value', $decimalNs)
    $decimalNode.InnerText = '1000000000000000000.000000001'
    $decimalPath = Join-Path $semanticTemp 'oversized-decimal.xml'
    $oversizedDecimal.Save($decimalPath)
    Assert-SchemaRejected -Path $decimalPath -Settings $settings -CaseName 'more than 18 integer digits'
    $semanticNegativeCount++

    [xml] $blankQualifier = Get-Content -LiteralPath $sourceExample -Raw
    $qualifierNs = [System.Xml.XmlNamespaceManager]::new($blankQualifier.NameTable)
    $qualifierNs.AddNamespace('t', $namespace)
    $qualifierNode = $blankQualifier.SelectSingleNode('//t:AgeVerification/t:RegulatedCategory/t:SchemeVersion', $qualifierNs)
    $qualifierNode.InnerText = '   '
    $qualifierPath = Join-Path $semanticTemp 'blank-code-scheme-version.xml'
    $blankQualifier.Save($qualifierPath)
    Assert-SchemaRejected -Path $qualifierPath -Settings $settings -CaseName 'blank code scheme version'
    $semanticNegativeCount++

    [xml] $danglingAudit = Get-Content -LiteralPath $sourceExample -Raw
    $auditNs = [System.Xml.XmlNamespaceManager]::new($danglingAudit.NameTable)
    $auditNs.AddNamespace('t', $namespace)
    $auditNode = $danglingAudit.SelectSingleNode('//t:AuditEvidence/t:LineReference', $auditNs)
    $auditNode.InnerText = 'missing-audit-line-reference'
    $auditPath = Join-Path $semanticTemp 'dangling-audit-line-reference.xml'
    $danglingAudit.Save($auditPath)
    Assert-SchemaRejected -Path $auditPath -Settings $settings -CaseName 'dangling audit line reference'
    $semanticNegativeCount++

    [xml] $blankUnit = Get-Content -LiteralPath (Join-Path $examplesDir 'ev-mobile-sample.xml') -Raw
    $unitNs = [System.Xml.XmlNamespaceManager]::new($blankUnit.NameTable)
    $unitNs.AddNamespace('t', $namespace)
    $unitNode = $blankUnit.SelectSingleNode('//t:EVChargingSession/t:EnergyDelivered/t:UnitCode', $unitNs)
    $unitNode.InnerText = '   '
    $unitPath = Join-Path $semanticTemp 'blank-unit-code.xml'
    $blankUnit.Save($unitPath)
    Assert-SchemaRejected -Path $unitPath -Settings $settings -CaseName 'blank unit code'
    $semanticNegativeCount++

    [xml] $blankSourceVersion = Get-Content -LiteralPath $sourceExample -Raw
    $sourceNs = [System.Xml.XmlNamespaceManager]::new($blankSourceVersion.NameTable)
    $sourceNs.AddNamespace('t', $namespace)
    $sourceVersionNode = $blankSourceVersion.SelectSingleNode('//t:SourceProvenance/t:Version', $sourceNs)
    $sourceVersionNode.InnerText = '   '
    $sourceVersionPath = Join-Path $semanticTemp 'blank-source-version.xml'
    $blankSourceVersion.Save($sourceVersionPath)
    Assert-SchemaRejected -Path $sourceVersionPath -Settings $settings -CaseName 'blank source version'
    $semanticNegativeCount++

    [xml] $incompleteMapping = Get-Content -LiteralPath $sourceExample -Raw
    $mappingNs = [System.Xml.XmlNamespaceManager]::new($incompleteMapping.NameTable)
    $mappingNs.AddNamespace('t', $namespace)
    $mappingVersionNode = $incompleteMapping.SelectSingleNode('//t:SourceProvenance/t:MappingProfileVersion', $mappingNs)
    $null = $mappingVersionNode.ParentNode.RemoveChild($mappingVersionNode)
    $mappingPath = Join-Path $semanticTemp 'incomplete-mapping-profile.xml'
    $incompleteMapping.Save($mappingPath)
    Assert-SchemaRejected -Path $mappingPath -Settings $settings -CaseName 'incomplete mapping profile pair'
    $semanticNegativeCount++

    [xml] $blankEvidenceToken = Get-Content -LiteralPath $sourceExample -Raw
    $evidenceNs = [System.Xml.XmlNamespaceManager]::new($blankEvidenceToken.NameTable)
    $evidenceNs.AddNamespace('t', $namespace)
    $hashNode = $blankEvidenceToken.SelectSingleNode('//t:AgeVerification/t:Evidence/t:SHA256', $evidenceNs)
    $tokenNode = $blankEvidenceToken.CreateElement('Token', $namespace)
    $tokenNode.InnerText = '   '
    $null = $hashNode.ParentNode.ReplaceChild($tokenNode, $hashNode)
    $evidencePath = Join-Path $semanticTemp 'blank-evidence-token.xml'
    $blankEvidenceToken.Save($evidencePath)
    Assert-SchemaRejected -Path $evidencePath -Settings $settings -CaseName 'blank evidence token'
    $semanticNegativeCount++
}
finally {
    Remove-Item -LiteralPath $semanticTemp -Recurse -Force
}

$legacyTypes = Get-StructuralSchemaText -Path (Join-Path $repoRoot 'vrg\3.2.2\TTDRsimpleTypes-3.2.2.xsd')
$currentTypes = Get-StructuralSchemaText -Path (Join-Path $releaseDir 'TTDRsimpleTypes-3.3.0.xsd')
if ($legacyTypes -ne $currentTypes) {
    throw 'TTDRsimpleTypes-3.3.0.xsd differs structurally from the frozen 3.2.2 shared types.'
}

Write-Host "PASS $($examples.Count) examples; $($invalidSecurityFixtures.Count) security rejections; $($validSecurityFixtures.Count) security-positive fixture; $semanticNegativeCount schema-semantic rejections; $($legacyExamples.Count) legacy example; schemas compiled; legacy shared types unchanged."
