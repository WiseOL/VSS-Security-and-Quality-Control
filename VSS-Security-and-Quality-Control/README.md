# VSS-Security-and-Quality-Control

Server-only Garry's Mod addon providing ACF scanner restrictions in PvP and automatic five-minute bans for Steam Family borrowers using an actively banned license owner's game.

## Installation
Extract the VSS-Security-and-Quality-Control folder into your server's garrysmod/addons/ folder, then restart the server. Keep ULX/ULib, Buildmode-ULX, and ACF-3-VSS-FORK installed. No changes to either dependency or client installation are needed.

Expected path: garrysmod/addons/VSS-Security-and-Quality-Control/lua/autorun/server/acf_pvp_scanner_guard.lua

## Behavior
- Players in build mode can scan normally.
- PvP scanner attempts are blocked server-side, and ACF's own stop message closes the scanner UI.
- Every server-received attempt sends a private chat message containing the player's name and SteamID to online admins and superadmins only. There is no alert cooldown or admin exemption.
- Active scanning stops before the next scanner data update when a player enters PvP, including forced transitions. Admins receive one transition alert.
- The attempting player sees ACF's scanner-ended notification. Regular players receive no admin alerts.
- Admin recipients use IsAdmin()/IsSuperAdmin(), including custom ranks inheriting admin privileges. Operators do not receive alerts. Chat alerts are not saved to a persistent file or delivered to offline admins.
- Actual server ply.buildmode determines permission; pending mode changes do not count. False or unset means PvP. Without Buildmode installed, all players are treated as PvP.
- Existing ACF scanner damage cooldown behavior is preserved.

## Compatibility
Source inspected:
https://github.com/Valen-Sandbox/Buildmode-ULX at 58a0f702d5052aa773d38a392708f0dfd831e78e
https://github.com/PERSON00331/ACF-3-VSS-FORK at f261a700b1410193d4a5b983d4ae3d36fab6b74e

Wraps server ACF.Scanning.BeginScanning and the ACF_Scanning_ScanEnts Think callback. Rechecks installation every second to support ACF loading order and reloads. Future scanner API changes or another addon replacing these functions may require an update. Modified clients can retain information already received; this addon prevents further server scanning in PvP.

## Validation on your server
A live Garry's Mod server was not available for testing.
1. With an admin, superadmin, and regular user online, use !pvp and attempt scanning. Confirm it closes, and only staff receive the named alert.
2. Use !build, wait for the configured delay, and confirm scanning works.
3. Have authorized staff use !fpvp on an active scanner user. Confirm scanning stops and staff receive one transition alert.
4. Attempt scanning as an admin in PvP: confirm it is blocked too.
5. Repeat attempts and confirm every server request is reported; regular users and operators must not receive staff alerts.

## Family Share ban guard

The Family Share feature is implemented in `lua/autorun/server/acf_family_share_guard.lua`.

After a joining player fully authenticates with Steam, the server compares their SteamID64 with `OwnerSteamID64()` (the account owning the license in use). If they differ and the license owner has an active ULX/ULib ban, the borrower receives a five-minute ULib ban with the requested Discord appeal reason. No Steam Web API key is needed. This is a license-owner association, not proof that two accounts belong to one person.

Uses the existing `ULib.bans` list, which ULib persists, so previous and new ULX/ULib bans work without a duplicate ban-history database. Permanent bans match; expired and removed bans do not. Unbanning the parent stops future matches, but a borrower's already-issued five-minute ban runs until expiry or an admin removes it. Retrying after five minutes while the parent is still banned results in another five-minute ban. Existing active borrower bans are preserved and the borrower is kicked, rather than replacing their ban.

Only ULX/ULib bans are supported. Bans stored exclusively in another admin system or a raw engine ban file are not imported. Missing authentication/owner information is retried and never treated as proof of sharing. Missing ULib disables this feature until it is available. Bots are skipped. Each authenticated connection is checked once, normally within one second of valid ownership information becoming available. This is a post-authentication kick/ban, not a preconnection rejection; it does not monitor new parent bans for users already checked in the same session.

Successful automatic bans are announced only to online admins/superadmins and the server console. The borrower ban/reason is stored by ULib. Scanner behavior remains unchanged.

### Family Share acceptance checks
1. Use a test Steam Family borrower whose license owner has a temporary active ULX ban. Join and confirm a five-minute borrower ban with the full configured reason in ULX's ban list.
2. Repeat with a permanently banned owner. Confirm the same five-minute action.
3. Remove/expire the parent ban and clear the test borrower ban. Rejoin: no automatic ban should occur.
4. Join using a directly owned license or an unbanned owner's license: no automatic ban.
5. Confirm a pre-existing longer/permanent borrower ban is never reduced to five minutes.
6. Check alert visibility with admin, superadmin, operator, and regular user accounts.

Automated mocked Lua checks cover these branches; live Steam Family / Garry's Mod acceptance testing is still required.
## Updating from the previous addon name

Remove the previous `garrysmod/addons/acf_pvp_scanner_guard/` installation before installing this renamed folder, then restart the server. Install only one copy of the addon.

## Family Share ban reason

```text
Family-shared account detected with existing banned SteamID on record from parent account - automatic 5 minute ban issued, attempt blocked. If you feel this was a mistake, report it on our discord; https://discord.gg/PvjaPGtwX7. If you were trying to access the server with a ban on record, wait until the ban has expired, or appeal it on the discord as well.

Thank you,
The VSS Admin and Dev Team
```

## Files

- `addon.json`: addon display name and metadata.
- `lua/autorun/server/acf_pvp_scanner_guard.lua`: PvP scanner restriction and private staff alerts.
- `lua/autorun/server/acf_family_share_guard.lua`: authenticated license-owner ban check.
- `README.md`: installation, behavior, compatibility, and acceptance checks.

The feature filenames and internal hook names are retained for compatibility. To change the ban message, edit `REASON` in `acf_family_share_guard.lua` and restart the server.

## Linked IP bans

Every active ULX/ULib SteamID ban also blocks the account's last recorded IPv4 address. This includes automatic Family Share bans. Anyone sharing that IP is rejected on connection or kicked if already connected. The addon uses a connection hook rather than issuing independent engine `addip` bans, keeping expiry and unbans tied to the original ULib record.

Authenticated account/IP mappings are saved in `garrysmod/data/vss_security/known_ips.json` and survive restarts. No configuration is required. Only the most recently recorded IP per SteamID is used. Ports are stripped; loopback, missing, and unsupported IPv6 addresses are not recorded or blocked.

Temporary IP blocks expire at the original ban's expiry. Permanent bans keep their linked IP blocked until removed. Removing the SteamID ban removes that ban's IP block immediately; another active ban associated with the same IP can still block it. This does not create new SteamID bans for other accounts on the same IP.

Existing bans gain linked IP protection when a recorded IP is available. Offline bans for accounts never observed by this addon remain SteamID-only, and a console message reports the missing mapping when a new ban is issued. Steam does not provide an offline player's IP. Bans made exclusively through raw engine commands or another ban system are not covered; use ULX/ULib for all bans you want linked. Missing ULib leaves IP enforcement inactive.

IP blocking uses the ban reason from the matching record. The addon records authenticated account IPs locally and does not send them to clients. CheckPassword hooks in other addons that return an unconditional allow can bypass connection checks; the periodic connected-player check also enforces the block.

### IP ban acceptance checks
1. Join with a test account, then issue a temporary ULX ban. Confirm a second account on the same IP cannot connect.
2. Confirm the original account still has its SteamID ban and its original duration/reason.
3. Unban the original account: the IP should be allowed unless another active ban links to it.
4. Repeat using a short temporary ban and confirm the IP becomes available after expiry.
5. Restart the server and confirm a permanent ban still blocks its recorded IP.
6. Issue an offline ban on an account that has never joined with this addon installed: expect SteamID enforcement only and a missing-IP console message.

`lua/autorun/server/vss_ip_ban_guard.lua` implements this feature. Live multiplayer acceptance testing remains required.

## Scanner compatibility recheck - November 7, 2026

Fetched the current default branches from both linked repositories. Buildmode-ULX remains at `58a0f702d5052aa773d38a392708f0dfd831e78e`; ACF-3-VSS-FORK is at `f261a700b1410193d4a5b983d4ae3d36fab6b74e`. The relevant ACF scanner and hook source is unchanged from the previously inspected version.

The integration now also listens to Buildmode's `OnPlayerSwitchModePVPBUILD` hook to end active scans immediately when normal or forced PvP transitions complete. The pre-update Think check still catches direct `ply.buildmode` changes during other lifecycle paths.

Compatibility checks passed in a mocked Garry's Mod environment executing the actual upstream Buildmode enable/disable routines, ACF server scanner functions, and UpdatePlayer request handler. Checks covered PvP denial, builder scanning, forced/normal transition hook behavior, direct-field fallback, staff-only alerts, admin restriction, existing scanner permission denial, damage cooldown handoff, and the client stop-message protocol. Separate regression checks passed for repeated installation and scanner reloads. This verifies source/API integration; live multiplayer testing is still required.
