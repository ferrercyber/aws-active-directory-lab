# AWS Active Directory Lab

Self-hosted Windows Server 2022 Active Directory domain controller on AWS EC2, demonstrating user management, password resets, account lockouts, and offboarding via ADUC and PowerShell.

**Domain:** ferrercyber.local
**Server:** DC01 (Windows Server 2022, t3.micro)

## What I Built

I built a fully working Active Directory environment from scratch on AWS to practice the kinds of tasks a HelpDesk technician handles every day. The lab simulates a small enterprise with 10 users distributed across three departments, complete with security groups, password and lockout policies, and a real offboarding workflow. Everything was deployed on a single Windows Server 2022 EC2 instance, configured as the first domain controller in a new forest.

## Skills Demonstrated

- AWS EC2, VPC, Security Groups, IAM
- Active Directory Domain Services
- PowerShell scripting
- Group Policy
- User lifecycle management

## Step 1: AWS Account Security

Before touching any infrastructure, I locked down the account itself. I enabled MFA on the root account, then created a separate IAM admin user (ferrer-admin) for day-to-day work so I wouldn't be operating as root. I also set up a zero-spend billing alert so AWS would email me the second any unexpected charges hit the account. RDP access to the eventual server was restricted to my home IP only, not the open internet.


## Step 2: Launched the EC2 Windows Server

I launched a t3.micro instance running Windows Server 2022. The instance was placed in the default VPC, attached to a custom security group that only allowed RDP from my home IP. After a few minutes, the instance was running with all status checks passed and ready to connect to via Remote Desktop.

## Step 3: Initial Server Configuration

After RDP'ing into the new instance, I renamed the server from its random AWS-generated hostname to DC01, set the time zone, and confirmed the server was running Windows Server 2022 Datacenter on t3.micro hardware.
<img width="2559" height="1400" alt="LocalServerView" src="https://github.com/user-attachments/assets/0e7d8866-2d34-4fb0-a1cf-43e29b6b46c9" />

## Step 4: Installed Active Directory Domain Services
Rather than clicking through the Server Manager wizard, I installed the AD DS role via a single PowerShell command. PowerShell installation is faster, scriptable, and produces a clean audit trail showing exactly what was changed.

```powershell
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
```

The command completed in about two minutes and returned `Success: True`.

<img width="975" height="508" alt="ActiveDirectoryDownload" src="https://github.com/user-attachments/assets/5dfc3e9d-9bf3-45ce-a403-4bc52eca1e48" />

---

## Step 5: Promoted DC01 to a Domain Controller

With the AD DS role installed, I promoted the server to a domain controller using `Install-ADDSForest`. This created a brand new forest (`ferrercyber.local`) with `DC01` as the first DC, installed DNS, and set up the directory database. The server automatically rebooted when promotion finished.

```powershell
Install-ADDSForest `
    -DomainName "ferrercyber.local" `
    -DomainNetbiosName "FERRERCYBER" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDns:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "<redacted>" -AsPlainText -Force) `
    -Force
```

After the reboot, I logged back in as `FERRERCYBER\Administrator` — the domain admin instead of the local admin.

---

## Step 6: Verified the Domain Controller

I ran `Get-ADDomain` to confirm everything came up correctly. The output confirmed the domain name, NetBIOS name, and that all the FSMO roles (PDC Emulator, RID Master, Infrastructure Master) had been assigned to `DC01.ferrercyber.local`. This is the proof that the forest was created successfully and the DC was operating as expected.

<img width="1417" height="551" alt="ADDomainOutput" src="https://github.com/user-attachments/assets/8f0627fe-7054-4cb8-9d74-0e513fd33479" />

---

## Step 7: Confirmed DC Health with dcdiag

Next I ran `dcdiag /v` to validate the DC against Microsoft's full suite of health checks — replication, FSMO roles, DNS, partition references, and so on. Every test passed, confirming the domain controller was healthy and ready for use.

<img width="2466" height="1056" alt="dcdiagsummary" src="https://github.com/user-attachments/assets/eea1ee15-055c-461b-b857-879e307b65ac" />


---

## Step 8: Built the Organizational Unit Structure

I designed an OU hierarchy that mirrors how a small enterprise actually organizes Active Directory:

- **Employees** — active user accounts, split into IT, Sales, and Operations sub-OUs
- **Groups** — all security groups kept separate from user objects
- **Service Accounts** — placeholder for non-human accounts
- **Disabled Users** — terminated employees moved here during offboarding

All OUs were created via PowerShell so the structure was consistent and reproducible.

```powershell
New-ADOrganizationalUnit -Name "Employees" -Path "DC=ferrercyber,DC=local"
New-ADOrganizationalUnit -Name "Sales" -Path "OU=Employees,DC=ferrercyber,DC=local"
# ...and so on for each OU
```

<img width="1203" height="782" alt="ADUCOUTree" src="https://github.com/user-attachments/assets/20b55af3-7eae-4e65-bc96-4e63c86fc867" />


---

## Step 9: Bulk-Provisioned Users from CSV

Onboarding 10 users through the ADUC GUI would have taken too long. Instead, I built a CSV file of new hires and used a PowerShell loop with `New-ADUser` to provision them all at once. The script reads the CSV, places each user in the correct departmental OU, assigns a temporary password, and forces them to change it at next logon.

The full script is included in the `scripts/` folder.

<img width="1035" height="531" alt="PSUserScript" src="https://github.com/user-attachments/assets/473f34c4-9d5f-4d78-a5d9-ba1e0b4ed2e3" />


---

## Step 10: Verified Users Landed in the Correct OUs

After the bulk import, I confirmed in ADUC that each user was placed in the correct departmental OU based on the CSV data. (Maria Lopez was created earlier via the ADUC GUI as a comparison to the bulk method.)

<img width="1201" height="786" alt="ADUCUsers3" src="https://github.com/user-attachments/assets/20990296-dcb8-4dae-973d-7a75596ac158" />


<img width="1207" height="785" alt="ADUCUsers" src="https://github.com/user-attachments/assets/f4e24768-1aeb-4b98-939b-232b48ab73a2" />


---

## Step 11: Created Security Groups and Populated Membership

I created departmental security groups in the dedicated `Groups` OU — `Sales-Team`, `IT-Team`, `Operations-Team`, and `Helpdesk-Admins`. Instead of manually adding users to each group, I dynamically pulled all users from each departmental OU and piped them into `Add-ADGroupMember`. This keeps the script reusable — if Sales adds a new hire later and the script is re-run, they'll be auto-added to the group.

```powershell
$salesUsers = Get-ADUser -Filter * -SearchBase "OU=Sales,OU=Employees,DC=ferrercyber,DC=local"
Add-ADGroupMember -Identity "Sales-Team" -Members $salesUsers
```

<img width="400" height="450" alt="SalesMembers" src="https://github.com/user-attachments/assets/f3903d70-8ffa-4e66-b848-d1bece007960" />


---

## Step 12: Password Reset via ADUC (GUI Method)

The most common HelpDesk ticket is "I forgot my password." I demonstrated the standard ADUC workflow: right-click the user → Reset Password → enter a temporary password → check "User must change password at next logon" → OK. That last checkbox ensures the temp password issued by HelpDesk can't be reused indefinitely.

<img width="1203" height="786" alt="AlexPWReset" src="https://github.com/user-attachments/assets/37311107-d2cc-4d9b-89f4-4914ff36f93f" />


---

## Step 13: Password Reset via PowerShell (Automation)

I also built a reusable PowerShell function (`Reset-UserPassword`) that wraps the same reset workflow into a single command with built-in error handling. Running `Reset-UserPassword -Username ajohnson` resets the password, sets the change-at-next-logon flag, and prints a clean confirmation. The function is in the `scripts/` folder.

<img width="960" height="501" alt="ResetUserPasswordFunction" src="https://github.com/user-attachments/assets/d466e047-ece5-4326-8754-658e94d04d02" />


---

## Step 14: Configured the Account Lockout Policy

I configured the Default Domain Policy via Group Policy Management Editor to lock any account after 5 failed login attempts, with a 15-minute lockout duration. This is the standard control that prevents brute-force password attacks and forces attackers (or users with sticky caps lock) to wait between guesses.

| Setting | Value |
|---|---|
| Account lockout threshold | 5 invalid logon attempts |
| Account lockout duration | 15 minutes |
| Reset account lockout counter after | 15 minutes |
| Allow Administrator account lockout | Enabled |

After saving the policy, I ran `gpupdate /force` to apply it immediately.

<img width="781" height="559" alt="AccountLockoutPolicy" src="https://github.com/user-attachments/assets/13231667-1995-4ba8-8f6f-b806fb031e00" />


---

## Step 15: Triggered a Lockout to Test the Policy

To prove the policy actually enforces, I deliberately locked the `ajohnson` account by sending 7 failed authentication attempts. Querying AD afterward confirmed both `badPwdCount: 5` and `LockedOut: True` — the policy was working as designed.

<img width="1022" height="318" alt="AJohnsonLockout" src="https://github.com/user-attachments/assets/fce45122-c1d5-4a29-b2a0-b4a99d2c348a" />


---

## Step 16: Unlocked the Account

This is the most common lockout ticket workflow in any AD environment, in three commands:

1. `Search-ADAccount -LockedOut` — finds all currently locked accounts
2. `Unlock-ADAccount -Identity ajohnson` — unlocks the specific account
3. `Search-ADAccount -LockedOut` — confirms the unlock worked (returns nothing)

The first query returns Alex Johnson's full account record. The unlock returns silently (PowerShell's standard "no news is good news" pattern). The second query returns nothing — confirming the account is no longer locked.

<img width="727" height="471" alt="AJohnsonLockout2" src="https://github.com/user-attachments/assets/ee2219f5-81f7-4592-828c-0781a355ff07" />


---

## Step 17: End-to-End Offboarding Workflow

The most enterprise-mature piece of this lab is the offboarding script. When a real employee leaves, several things need to happen together — and if any step is missed, it creates a security gap. I scripted all five steps into a single command:

1. **Disable the account** so the user can't log in
2. **Scramble the password** to a random 20-character string so even if the account is re-enabled, no one knows the password
3. **Remove all group memberships** to revoke access to shared resources
4. **Move the user to the Disabled Users OU** to visually separate offboarded accounts from active ones
5. **Stamp the description field with the offboarding date** for audit trail

<img width="1180" height="491" alt="OffboardUserInput" src="https://github.com/user-attachments/assets/6f94cda8-2d95-4d86-8cfe-061e65293aab" />


---

## Step 18: Verified the Offboarded User

After running the script, I opened ADUC and confirmed the result. Liam Martinez now lives in the Disabled Users OU, his account icon shows the disabled-arrow overlay, and the description field is auto-stamped with the offboarding date. All five offboarding actions executed correctly in a single command.

<img width="1203" height="783" alt="LiamMartinezOffboard" src="https://github.com/user-attachments/assets/ea22c4dc-28ee-444e-960b-8ad7206bf2f9" />


---

## HelpDesk Runbook: Password Reset


### Procedure (PowerShell — preferred)

1. Verify user identity per company policy (employee ID, manager callback, etc.)
2. Open PowerShell as Administrator
3. Load the function: `. .\scripts\Reset-UserPassword.ps1`
4. Run: `Reset-UserPassword -Username <samAccountName>`
5. Communicate the temporary password through an approved secure channel
6. Confirm the user has successfully logged in

### Procedure (GUI fallback)

1. Open Active Directory Users and Computers (`dsa.msc`)
2. Navigate to the user's OU
3. Right-click the user → Reset Password
4. Enter temporary password, check "User must change password at next logon", click OK
5. Communicate temp password via secure channel


---

## Lessons Learned

A few real things I ran into while building this that taught me something useful:

- **AWS public IPs are ephemeral.** Stopping and starting an EC2 instance releases the assigned public IP and a new one is issued on restart. For a lab, downloading a fresh RDP file each session is fine. In production, an Elastic IP would be allocated for a stable endpoint — at the cost of ~$3.60/month when not attached.

- **ADUC caches OU views aggressively.** After bulk-creating users, they showed up in PowerShell queries (`Get-ADUser -SearchBase`) but not in ADUC until I forced a refresh with F5. After that I started trusting PowerShell over the GUI for verification — querying the directory directly is always more reliable than trusting the cached view.

- **Triggering lockouts artificially is harder than it sounds.** Local `net use` attempts on the DC itself didn't increment the bad password counter. Using forced credential-based authentication attempts via `New-Object PSCredential` worked. In a real environment, lockouts happen organically from end-user workstations — synthetic lockout testing is a HelpDesk-specific lab challenge.


---

## Security Notes

- IAM admin user separated from root account
- MFA enforced on the IAM admin user
- RDP restricted via security group to a single home IP (port 3389, source `/32`)
- Zero-spend billing alert configured to catch any unexpected charges
- No long-lived access keys generated (console-only IAM user)


---

## Scripts

The PowerShell scripts used in this lab are in the `scripts/` folder:

- `Bulk-UserImport.ps1` — provisions users from CSV
- `Reset-UserPassword.ps1` — resets password and forces change at logon
- `Offboard-User.ps1` — complete offboarding workflow
- `Test-AccountLockout.ps1` — triggers a lockout for testing the policy
- `new_hires.csv` — sample CSV for the bulk import script
