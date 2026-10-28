# PowerShell Identity Administration Scripts

A collection of interactive PowerShell scripts for common Active Directory group administration and account recovery tasks. Each operation is provided as a separate `.ps1` file.

> **Important:** These scripts make real changes to user accounts, group membership, passwords, and authentication methods when run in an environment where your account has the required permissions. Review the code and test in a disposable lab first. These scripts are examples and are not affiliated with or endorsed by any employer, client, or Microsoft.

## Scripts

| Script | Purpose |
| --- | --- |
| `AddRemoveSecurityGroup.ps1` | Add or remove one user from one Active Directory security group. |
| `AddUserToMultipleGroups.ps1` | Add one user to multiple security groups in one run. |
| `AddMultipleUsersToGroup.ps1` | Add multiple users to one security group in one run. |
| `PasswordReset.ps1` | Reset one Active Directory user's password and request a password change at next sign-in. |
| `PasswordAndMFAReset.ps1` | Interactively reset a password, remove supported Microsoft Entra authentication methods, or do both. |

## Requirements

- Windows PowerShell with the **ActiveDirectory** module available for the AD scripts.
- An account with only the delegated permissions required for the requested operation.
- For MFA operations in `PasswordAndMFAReset.ps1`, the Microsoft Graph PowerShell SDK and permission to consent to/use the `UserAuthenticationMethod.ReadWrite.All` scope. Tenant policies and role requirements may also apply.
- Network access to the relevant Active Directory domain and, for MFA operations, Microsoft Graph.

The scripts do not provision a lab or create sample users. They prompt for identifiers and names from the directory you are connected to.

## Usage

Run the individual script from a PowerShell session that has access to the intended environment. For example:

```powershell
.\AddRemoveSecurityGroup.ps1
```

Follow the interactive prompts. The group scripts show a before-state and report per-item outcomes. The password scripts generate a temporary password and display it in the console; handle it through an approved secure channel and do not save it in transcripts, screenshots, logs, or source control.

## Safety and review notes

- Confirm the target user, group, and requested action before making changes. Use an approved change or service request process.
- Test with non-production accounts in a lab before using any script operationally.
- Use a least-privileged account and follow your organization's approval, audit, and change-management requirements.
- Never commit real usernames, employee IDs, email addresses, tenant IDs, domain names, credentials, tokens, or output from a production run.
- The password reset scripts print the generated temporary password to the console. Do not use them where console output is captured or shared unless that handling is approved.
- `PasswordAndMFAReset.ps1` can remove registered authentication methods. This may disrupt sign-in and require an account recovery process. Confirm the target and recovery plan before use.
- The MFA script skips password and Windows Hello methods and removes supported Authenticator, phone, email, FIDO2, and software OATH methods. Review current Microsoft Graph behavior and tenant policy before operational use.
- These scripts are interactive examples, not a substitute for a controlled production workflow. Review error handling, audit logging, approvals, and rollback/recovery procedures for your environment.

## Repository hygiene

Keep this repository limited to sanitized source code and fictional examples. Do not commit production data, execution transcripts, generated passwords, exported directory records, or client/employer-specific configuration. If adapting these scripts, use clearly fictional values in documentation and demonstrations.

## License

No license is specified. Add a license file before allowing others to reuse, modify, or redistribute this code.
