# Oracle Integration Tests

This directory contains comprehensive integration tests for Oracle Database functionality on the Windows 2025 server environment.

## 📁 Test Files

### Core Integration Tests

- **`Test-OracleListener.ps1`** - Tests Oracle listener response on localhost
- **`Test-OracleClientLogin.ps1`** - Tests Oracle client login capabilities to local instance
- **`Test-OracleIntegration.ps1`** - Master test runner for all Oracle integration tests

## 🚀 Quick Start

### Run All Oracle Integration Tests

```powershell
# Run complete Oracle integration test suite
.\Test-OracleIntegration.ps1

# Run with specific Oracle credentials
.\Test-OracleIntegration.ps1 -TestUsername "system" -TestPassword "your_password"

# Run only listener tests
.\Test-OracleIntegration.ps1 -ListenerOnly

# Run only login tests
.\Test-OracleIntegration.ps1 -LoginOnly
```

### Run Individual Tests

```powershell
# Test Oracle listener response
.\Test-OracleListener.ps1

# Test Oracle client login
.\Test-OracleClientLogin.ps1 -TestUsername "system" -TestPassword "your_password"
```

## 🧪 Test Details

### Test 1: Oracle Listener Response (`Test-OracleListener.ps1`)

This test verifies that the Oracle listener is responding on localhost:

**What it tests:**
- ✅ Oracle service status (OracleServiceXE, OracleXETNSListener)
- ✅ TCP connection to Oracle port (default: 1521)
- ✅ Port listening verification using netstat
- ✅ TNSPing connectivity test to Oracle service

**Parameters:**
```powershell
-OracleHost      # Oracle host (default: localhost)
-OraclePort      # Oracle port (default: 1521)
-ServiceName     # Oracle service name (default: XE)
-TimeoutSeconds  # Connection timeout (default: 30)
```

**Example output:**
```
=== Oracle Listener Integration Test ===
Host: localhost
Port: 1521
Service: XE

Test 1: Oracle Service Status
✓ Oracle services are running

Test 2: TCP Connection to Oracle Port
✓ TCP connection to localhost:1521 successful

Test 3: Port Listening Verification
✓ Oracle listener is listening on port 1521

Test 4: TNSPing Listener Test
✓ TNSPing to service 'XE' successful
  Response time: 15 ms

=== Oracle Listener Test: PASSED ===
```

### Test 2: Oracle Client Login (`Test-OracleClientLogin.ps1`)

This test verifies that Oracle clients can successfully login to the local instance:

**What it tests:**
- ✅ SQL*Plus connection and authentication
- ✅ ODBC connection capability (if available)
- ✅ ODP.NET connection capability (if available)
- ✅ Database query execution
- ✅ User session information retrieval

**Parameters:**
```powershell
-TestUsername    # Oracle username (default: system)
-TestPassword    # Oracle password (if not provided, tries common defaults)
-ServiceName     # Oracle service name (default: XE)
-ConnectionString # Custom connection string (optional)
-CreateTestUser  # Create a test user for testing (optional)
-TimeoutSeconds  # Connection timeout (default: 30)
```

**Authentication Methods Tested:**
1. **SQL*Plus** - Native Oracle command-line tool
2. **ODBC** - Open Database Connectivity (if drivers installed)
3. **ODP.NET** - Oracle Data Provider for .NET (if assemblies available)

**Example output:**
```
=== Oracle Client Login Integration Test ===
Username: system

Test 1: SQL*Plus Connection Test
✓ SQL*Plus connection successful
Database Information:
  CurrentUser: SYSTEM
  CurrentTime: 2025-07-18 14:30:15
  Version: 21.3.0

Test 2: ODBC Connection Test
✓ ODBC connection successful
  Status: ODBC Connection successful
  Current User: SYSTEM

Test 3: ODP.NET Connection Test
✓ ODP.NET connection successful using Oracle.ManagedDataAccess (Managed)
  Status: ODP.NET Connection successful
  Current User: SYSTEM

=== Oracle Client Login Test: PASSED ===
```

### Master Test Runner (`Test-OracleIntegration.ps1`)

Orchestrates all Oracle integration tests with comprehensive reporting:

**Features:**
- ✅ Sequential test execution with proper error handling
- ✅ Comprehensive logging and reporting
- ✅ JSON test results export
- ✅ Continue-on-failure option
- ✅ Test prerequisites validation
- ✅ Environment information collection

**Parameters:**
```powershell
-ListenerOnly        # Run only listener tests
-LoginOnly          # Run only login tests
-ContinueOnFailure  # Continue running tests even if some fail
-TimeoutSeconds     # Global timeout for all tests
```

## 🔧 Configuration

### Oracle Environment Variables

The tests automatically detect Oracle installations but work best when these are set:

```powershell
$env:ORACLE_HOME = "C:\oraclexe\app\oracle\product\21.3.0\dbhomeXE"
$env:TNS_ADMIN = "$env:ORACLE_HOME\network\admin"
$env:ORACLE_SID = "XE"
```

### Default Oracle Passwords Tested

When no password is provided, the tests try these common defaults:
- `oracle`
- `password`
- `123456`
- `xe`
- `system`
- `admin`

### Oracle Client Requirements

For full test coverage, ensure these are installed:
- **Oracle Instant Client** or **Oracle Database XE**
- **Oracle ODBC Driver** (optional, for ODBC tests)
- **Oracle Data Provider for .NET** (optional, for ODP.NET tests)

## 📊 Test Results and Logging

### Log Files

Tests create detailed logs in `C:\Logs\`:
- `OracleIntegrationTest_YYYYMMDD_HHMMSS.log` - Main test log
- `OracleIntegrationTest_YYYYMMDD_HHMMSS_Results.json` - JSON results

### Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

### Test Results JSON Structure

```json
{
  "Success": true,
  "ExitCode": 0,
  "Output": "Test output...",
  "Error": "",
  "TestName": "Oracle Listener Response"
}
```

## 🛠️ Integration with Main Validation

### From Environment Validation Script

```powershell
# Include integration tests in environment validation
.\scripts\validation\Test-Environment.ps1 -IncludeIntegration
```

### From Application Validation Script

```powershell
# Include Oracle integration tests
.\scripts\validation\Test-Applications.ps1 -IncludeOracleIntegration
```

## 🔍 Troubleshooting

### Common Issues

1. **"Oracle service not found"**
   - Ensure Oracle XE is installed
   - Check service name: `Get-Service -Name "*Oracle*"`

2. **"TNSPing utility not found"**
   - Set `ORACLE_HOME` environment variable
   - Verify Oracle client tools are installed

3. **"ORA-01017: invalid username/password"**
   - Check default passwords or provide correct password
   - Verify user account is not locked: `ALTER USER system ACCOUNT UNLOCK;`

4. **"TNS-12541: TNS:no listener"**
   - Check Oracle listener service: `Get-Service OracleXETNSListener`
   - Verify listener.ora configuration

5. **"Connection timeout"**
   - Check Windows Firewall settings
   - Verify Oracle port (1521) is open
   - Increase timeout with `-TimeoutSeconds`

### Debug Mode

Enable verbose logging for detailed diagnostics:

```powershell
.\Test-OracleIntegration.ps1 -Verbose
```

### Manual Verification Commands

```powershell
# Check Oracle services
Get-Service -Name "*Oracle*"

# Test TNS connectivity
tnsping XE

# Check listening ports
netstat -an | findstr 1521

# Test SQL*Plus connection
sqlplus system/password@XE
```

## 📋 Test Scenarios

### Scenario 1: Fresh Oracle Installation

```powershell
# Test immediately after Oracle XE installation
.\Test-OracleIntegration.ps1 -TestUsername "system"
```

### Scenario 2: Custom Oracle Configuration

```powershell
# Test with custom port and service
.\Test-OracleIntegration.ps1 -OraclePort 1522 -ServiceName "CUSTOM" -TestUsername "myuser" -TestPassword "mypass"
```

### Scenario 3: Automated CI/CD Pipeline

```powershell
# Non-interactive test suitable for automation
.\Test-OracleIntegration.ps1 -ContinueOnFailure -TestUsername "system" -TestPassword "automation_password"
```

### Scenario 4: Network Connectivity Testing

```powershell
# Test Oracle on remote host
.\Test-OracleIntegration.ps1 -OracleHost "oracle-server.domain.com" -TestUsername "system" -TestPassword "password"
```

## 🤝 Contributing

When adding new Oracle integration tests:

1. Follow the existing logging patterns using `Write-Log`
2. Include comprehensive error handling
3. Support both verbose and quiet modes
4. Add timeout handling for network operations
5. Return structured results for the master test runner
6. Update this README with new test descriptions

## 📞 Support

For Oracle-specific issues:

1. Check Oracle alert logs: `$ORACLE_HOME\diag\rdbms\xe\xe\trace\alert_xe.log`
2. Verify Oracle installation: `sqlplus / as sysdba`
3. Check listener status: `lsnrctl status`
4. Review Oracle documentation for error codes
