# Quality Checks Workflow

This GitHub Actions workflow performs comprehensive quality checks on both Markdown and PowerShell files in the repository.

## Overview

The workflow runs automatically on:

- Pushes to `main` and `develop` branches
- Pull requests to `main` and `develop` branches
- Manual triggers via `workflow_dispatch`

## Jobs

### 1. Markdown Quality Checks (`markdown-quality`)

**Platform**: Ubuntu Latest

**Tools Used**:

- **markdownlint-cli** - Lints markdown files for style and syntax
- **markdown-link-check** - Validates external and internal links
- **remark-cli** - Additional markdown linting with consistency checks

**Configuration**:

- Line length limit: 120 characters (excluding code blocks and tables)
- ATX-style headers required
- Allows HTML elements: `<br>`, `<sub>`, `<sup>`, `<img>`, `<details>`, `<summary>`
- Ignores certain link patterns (Azure portal, GitHub issues/PRs, mailto links)

**Outputs**:

- `markdownlint-results.txt` - Detailed linting issues
- `link-check-results.txt` - Link validation results
- `remark-results.txt` - Additional linting results
- `markdown-quality-summary.md` - Consolidated report

### 2. PowerShell Quality Checks (`powershell-quality`)

**Platform**: Windows Latest

**Tools Used**:

- **PSScriptAnalyzer** - PowerShell static analysis and best practices
- **PowerShell AST Parser** - Syntax validation
- **Custom checks** - Additional best practice validations

**Analysis Includes**:

- Style and formatting consistency
- Best practice violations
- Security issues (hardcoded credentials detection)
- Syntax validation
- Error handling patterns
- Write-Host usage (recommends Write-Output)

**Severity Levels**:

- **Error**: Critical issues that should be fixed
- **Warning**: Important issues that should be addressed
- **Information**: Style and best practice suggestions

**Outputs**:

- `psscriptanalyzer-results.json` - Machine-readable results
- `psscriptanalyzer-results.txt` - Human-readable table format
- `psscriptanalyzer-report.md` - Detailed analysis report
- `powershell-additional-checks.md` - Custom validation results
- `powershell-quality-summary.md` - Consolidated report

### 3. Security Scan (`security-scan`)

**Platform**: Ubuntu Latest

**Tools Used**:

- **Trivy** - Vulnerability scanner for files and dependencies

**Features**:

- Scans for known vulnerabilities
- Uploads results to GitHub Security tab (SARIF format)
- Checks configuration files and scripts

### 4. Quality Summary (`quality-summary`)

**Platform**: Ubuntu Latest

**Purpose**:

- Aggregates results from all quality check jobs
- Creates a comprehensive quality report
- Posts summary comments on pull requests
- Uploads combined artifacts

## Artifacts

All job artifacts are retained for 30 days (quality summary for 90 days):

### Markdown Quality Reports

- `markdown-quality-summary.md`
- `markdownlint-results.txt`
- `link-check-results.txt`
- `remark-results.txt`
- `markdown-files.txt`

### PowerShell Quality Reports

- `powershell-quality-summary.md`
- `psscriptanalyzer-report.md`
- `psscriptanalyzer-results.json`
- `psscriptanalyzer-results.txt`
- `powershell-additional-checks.md`
- `powershell-files.txt`
- `PSScriptAnalyzer-Settings.psd1`

### Security Reports

- `trivy-results.sarif`

### Combined Reports

- `quality-summary-report` (quality-summary.md)

## Configuration

### Markdownlint Configuration

The workflow creates a `.markdownlint.json` configuration file with project-specific rules:

```json
{
  "default": true,
  "MD013": { "line_length": 120, "code_blocks": false, "tables": false },
  "MD033": { "allowed_elements": ["br", "sub", "sup", "img", "details", "summary"] },
  "MD041": false
}
```

### PSScriptAnalyzer Configuration

The workflow creates a `PSScriptAnalyzer-Settings.psd1` file with:

- Consistent indentation (4 spaces)
- Brace placement rules
- Whitespace consistency
- Pipeline indentation
- Custom rule exceptions

### Link Check Configuration

External link checking with:

- 10-second timeout
- Retry on HTTP 429 (rate limiting)
- Custom user agent for Microsoft docs
- Ignores Azure portal and GitHub issue links

## Usage

### Local Development

To run similar checks locally:

```powershell
# PowerShell analysis
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse

# Markdown linting (requires Node.js)
npm install -g markdownlint-cli markdown-link-check
markdownlint **/*.md
markdown-link-check README.md
```

### Pull Request Integration

The workflow automatically:

1. Runs on all pull requests
2. Posts a quality report comment
3. Updates the comment on subsequent pushes
4. Fails the check if critical issues are found

### Status Interpretation

**Markdown Quality**:

- ✅ **PASSED**: No linting issues, all links valid
- ⚠️ **WARNINGS**: Style issues found, links may have problems
- ❌ **FAILED**: Critical linting or link issues

**PowerShell Quality**:

- ✅ **ALL CHECKS PASSED**: No issues found
- ⚠️ **WARNINGS FOUND**: Style or best practice issues
- ❌ **CRITICAL ISSUES FOUND**: Syntax errors or critical violations

## Troubleshooting

### Common Issues

1. **Markdown line length violations**
   - Solution: Break long lines or exclude code blocks from rule

2. **PowerShell Write-Host usage**
   - Solution: Replace with Write-Output for better testability

3. **Link check failures**
   - Solution: Update broken links or add to ignore patterns

4. **PSScriptAnalyzer false positives**
   - Solution: Add suppression comments or update settings

### Workflow Failures

Check the workflow logs for specific error details:

1. Go to Actions tab in GitHub
2. Select the failed workflow run
3. Click on the failing job
4. Expand the failed step to see error details

### Customization

To customize the quality checks:

1. Fork the repository
2. Modify `.github/workflows/quality-checks.yml`
3. Update configuration sections as needed
4. Test with a pull request

## Dependencies

The workflow automatically installs all required dependencies:

- Node.js packages (markdownlint, link checking tools)
- PowerShell modules (PSScriptAnalyzer)
- Security scanning tools (Trivy)

No manual setup is required in the repository.
