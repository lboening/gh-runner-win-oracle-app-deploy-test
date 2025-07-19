# Quality Check Configuration Examples

This directory contains examples of configuration files for customizing the quality checks workflow.

## Markdownlint Configuration (.markdownlint.json)

Create this file in your repository root to customize markdown linting rules:

```json
{
  "default": true,
  "MD001": true,
  "MD003": { "style": "atx" },
  "MD007": { "indent": 2 },
  "MD013": { 
    "line_length": 120, 
    "code_blocks": false, 
    "tables": false,
    "headings": false
  },
  "MD022": true,
  "MD024": { "allow_different_nesting": true },
  "MD025": { "front_matter_title": "" },
  "MD026": { "punctuation": ".,;:!?" },
  "MD029": { "style": "ordered" },
  "MD033": { 
    "allowed_elements": [
      "br", "sub", "sup", "img", 
      "details", "summary", "div", "span"
    ] 
  },
  "MD034": false,
  "MD036": false,
  "MD040": true,
  "MD041": false,
  "MD046": { "style": "fenced" },
  "MD049": { "style": "underscore" },
  "MD050": { "style": "asterisk" }
}
```

## PSScriptAnalyzer Configuration (PSScriptAnalyzer-Settings.psd1)

Create this file to customize PowerShell analysis rules:

```powershell
@{
    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
            Whitelist = @('cd', 'cp', 'mv', 'rm', 'ls', 'cat', 'man')
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
            CommandAllowList = @('Join-Path', 'Split-Path', 'Test-Path')
        }
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckSeparator = $true
            CheckParameter = $false
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
        }
        PSUseSingularNouns = @{
            Enable = $false  # Often too restrictive for practical use
        }
    }
    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions',
        'PSReviewUnusedParameter'  # Add rules to exclude
    )
    IncludeRules = @(
        # Specify only certain rules to run
    )
    Severity = @('Error', 'Warning', 'Information')
}
```

## Markdown Link Check Configuration (.markdown-link-check.json)

Customize link checking behavior:

```json
{
  "ignorePatterns": [
    {
      "pattern": "^https://portal.azure.com"
    },
    {
      "pattern": "^https://github.com/.*/issues/.*"
    },
    {
      "pattern": "^https://github.com/.*/pull/.*"
    },
    {
      "pattern": "^mailto:"
    },
    {
      "pattern": "^file:"
    },
    {
      "pattern": "^#"
    }
  ],
  "httpHeaders": [
    {
      "urls": ["https://docs.microsoft.com", "https://learn.microsoft.com"],
      "headers": {
        "User-Agent": "Mozilla/5.0 (compatible; Markdown Link Check)",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      }
    }
  ],
  "timeout": "10s",
  "retryOn429": true,
  "retryCount": 3,
  "fallbackRetryDelay": "30s",
  "aliveStatusCodes": [200, 201, 202, 204, 206, 300, 301, 302, 303, 304, 307, 308, 999],
  "replacementPatterns": [
    {
      "pattern": "^/docs/",
      "replacement": "https://docs.microsoft.com/"
    }
  ]
}
```

## Workflow Environment Variables

Customize the workflow behavior by modifying environment variables:

```yaml
env:
  # PowerShell configuration
  PSScriptAnalyzerVersion: '1.21.0'
  # Markdown configuration  
  MarkdownlintVersion: '0.37.0'
  # Custom settings
  MAX_LINE_LENGTH: '120'
  FAIL_ON_WARNINGS: 'false'
  SKIP_LINK_CHECK: 'false'
```

## Customizing Quality Gates

You can modify the workflow to enforce different quality standards:

### Strict Mode (Fail on Warnings)
```yaml
- name: Check for warnings
  if: env.warning-count > 0
  run: |
    echo "::error::Warnings found. Failing build in strict mode."
    exit 1
```

### Ignore Specific Files
```yaml
- name: Find PowerShell files
  run: |
    Get-ChildItem -Path . -Recurse -Include "*.ps1", "*.psm1", "*.psd1" | 
      Where-Object { 
        $_.FullName -notlike "*\.git\*" -and 
        $_.FullName -notlike "*\node_modules\*" -and
        $_.FullName -notlike "*\tests\*" -and
        $_.FullName -notlike "*\temp\*"
      } | ForEach-Object { $_.FullName } | Out-File "powershell-files.txt"
```

### Custom Reporting
```yaml
- name: Generate custom report
  run: |
    # Create custom metrics
    $Metrics = @{
      TotalFiles = $TotalFiles
      CodeCoverage = "85%"
      QualityScore = if ($AllIssues.Count -eq 0) { "A+" } else { "B" }
    }
    $Metrics | ConvertTo-Json | Out-File "quality-metrics.json"
```

## Integration with Other Tools

### SonarQube Integration
```yaml
- name: SonarQube Scan
  uses: sonarqube-quality-gate-action@master
  with:
    scanMetadataReportFile: target/sonar/report-task.txt
```

### CodeQL Integration
```yaml
- name: Initialize CodeQL
  uses: github/codeql-action/init@v3
  with:
    languages: javascript

- name: Perform CodeQL Analysis
  uses: github/codeql-action/analyze@v3
```

### Dependency Checking
```yaml
- name: Run Snyk to check for vulnerabilities
  uses: snyk/actions/powershell@master
  with:
    args: --severity-threshold=high
```

## Troubleshooting Common Issues

### False Positive Rules
Add rule suppressions in your PowerShell code:
```powershell
# Suppress specific rule for this line
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param($UnusedParam)

# Suppress for entire function
function Get-Something {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    param()
}
```

### Markdown Line Length Issues
Use HTML for long links:
```markdown
<!-- Instead of -->
[Very long link text that exceeds the line length limit](https://very-long-url-that-makes-the-line-too-long.com)

<!-- Use -->
<a href="https://very-long-url-that-makes-the-line-too-long.com">Very long link text that exceeds the line length limit</a>
```

### Performance Optimization
For large repositories, consider:
```yaml
# Limit scope to changed files only
- name: Get changed files
  id: changed-files
  uses: tj-actions/changed-files@v40
  with:
    files: |
      **/*.ps1
      **/*.md

- name: Run analysis on changed files only
  if: steps.changed-files.outputs.any_changed == 'true'
  run: |
    echo "${{ steps.changed-files.outputs.all_changed_files }}" > files-to-check.txt
```
