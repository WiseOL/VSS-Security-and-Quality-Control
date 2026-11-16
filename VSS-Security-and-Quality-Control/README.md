# VSS-Security-and-Quality-Control

Garry's Mod server addon for PvP scanner restrictions and Family Share ban protection.

## Required addons

- ULX and ULib.
- [Valen-Sandbox/Buildmode-ULX](https://github.com/Valen-Sandbox/Buildmode-ULX).
- [Official ACF-Team/ACF-3](https://github.com/ACF-Team/ACF-3), with its required dependencies.
- Your setup also uses [PERSON00331/ACF-VSS-Extension](https://github.com/PERSON00331/ACF-VSS-Extension). The security pack works with official ACF-3 with or without this extension.

The old ACF-3-VSS-FORK is no longer required. Install official ACF-3 plus the VSS extension as separate addons instead of keeping the old fork installed alongside them.

## Installation and updating

1. Extract `VSS-Security-and-Quality-Control` into the server's `garrysmod/addons/` directory.
2. When updating, replace the previous security pack folder. Remove any old `acf_pvp_scanner_guard` addon folder so only one security pack copy is installed.
3. Keep the required addons installed and restart the server.

Expected files:

```text
garrysmod/addons/VSS-Security-and-Quality-Control/
  addon.json
  README.md
  lua/autorun/client/
    acf_pvp_scanner_attempt.lua
  lua/autorun/server/
    acf_pvp_scanner_guard.lua
    acf_family_share_guard.lua
```

No manual client installation or Steam Web API key is needed. The server automatically sends the small scanner-attempt client file through AddCSLuaFile. There are no configuration commands; the features are enabled when this addon loads.

## PvP scanner restriction

Players in build mode can use the official ACF scanner normally. PvP players cannot start a scan or change its target, including admins and superadmins. Every server-received attempt reports the player's name and SteamID privately to online admins/superadmins. There is no alert cooldown. Regular players and operators without admin privileges do not receive these alerts. Custom ULX ranks inheriting admin privileges do receive them.

An active scan ends immediately when Buildmode emits its normal/forced PvP mode-change hook. A fallback checks the actual server-side `ply.buildmode` field before each ACF scanner data update, covering direct state changes such as lifecycle paths. False or unset means PvP. A pending transition to build mode does not permit scanning until it completes.

The attempting user receives ACF's own scanner-ended notification. Existing ACF scanner permission restrictions and damage cooldown behavior remain in effect. Alerts are live chat messages, not a persistent scanner log or offline notification.

The integration wraps server `ACF.Scanning.BeginScanning` and the `ACF_Scanning_ScanEnts` Think callback, uses ACF's `ForceScanningEnd` protocol, and listens to Buildmode's `OnPlayerSwitchModePVPBUILD` hook. A one-second installer accommodates ACF loading order and scanner reloads. Future API changes or another addon replacing the same functions may require an update. Modified clients can retain information they already received; this guard prevents further server scanning in PvP.

## Family Share protection

After full Steam authentication, the server compares the player's SteamID64 with `OwnerSteamID64()`, the account owning the license being used. If they differ and the owner has an active ULX/ULib ban, the borrower receives a five-minute ULib ban with the reason below. This identifies a shared license association; it does not establish that both accounts belong to one person.

Uses ULib's existing persistent ban list, including prior bans. Permanent bans count; expired or removed bans do not. Existing active borrower bans are preserved rather than reduced to five minutes. Removing a parent ban stops future matches, but a borrower ban already issued remains until expiry or an admin removes it. Joining again after five minutes while the parent remains banned results in another five-minute ban.

Only ULX/ULib bans are supported. Missing owner/authentication information is retried and never treated as proof of sharing. Bots are skipped. Each connection is checked once, normally within one second of valid ownership data becoming available. This is a post-authentication kick/ban; it does not monitor newly issued parent bans for users already checked in that session. Missing ULib disables the feature until it becomes available.

Successful automatic bans notify online admins/superadmins and the server console. ULib stores the borrower ban and reason.

### Ban reason

```text
Family-shared account detected with existing banned SteamID on record from parent account - automatic 5 minute ban issued, attempt blocked. If you feel this was a mistake, report it on our discord; https://discord.gg/PvjaPGtwX7. If you were trying to access the server with a ban on record, wait until the ban has expired, or appeal it on the discord as well.

Thank you,
The VSS Admin and Dev Team
```

Edit `REASON` in `acf_family_share_guard.lua` and restart to change this message.

## Source compatibility checked November 14, 2026

- Buildmode-ULX: `58a0f702d5052aa773d38a392708f0dfd831e78e` (previously fetched source).
- Official ACF-3: `d7c128dac6cfe52a6e988f15b354fa9bf897b441`.
- ACF-VSS-Extension: `c95d3f37c21fb2ba1c942767dfe12811a20f9113`.

The extension adds entities/gameplay and does not replace the scanner, its network receiver, or this guard's Buildmode/scanner hooks. No extension-specific scanner adapter is needed. This pack controls access to the existing official scanner; it does not add scanner visualization types for extension entities.

Automated integration checks executed official ACF-3's actual server scanner functions and UpdatePlayer handler together with Buildmode's actual enable/disable routines in a mocked Garry's Mod environment. They covered PvP denial, builder access, immediate mode transitions, direct-state fallback, admin restrictions, staff-only alerts, permission denial, damage cooldown handoff, and the client stop-message protocol. Regression checks covered installer repetition and scanner reloads. Family Share logic was also checked with mocked server APIs. The extension was source-inspected for conflicts, not executed in a live server.

## Live server acceptance checks

A live Garry's Mod multiplayer server was not available. Validate your installed addon combination:

1. With official ACF-3, the VSS extension, and Buildmode loaded, confirm a normal player can scan in `!build` mode after its delay completes. Include contraptions containing VSS extension entities.
2. Use `!pvp` and attempt scanning: it should close, with name/SteamID alerts visible only to admins/superadmins.
3. Have authorized staff force an active scanner user into PvP using `!fpvp`: the scan should close and staff should receive one transition alert.
4. Repeat PvP attempts as an admin: they must also be blocked. Confirm repeated attempts are reported and existing ACF scanner restrictions remain effective.
5. Test Steam Family borrowing from an owner with an active temporary/permanent ULX ban: expect a five-minute borrower ban with the full reason. Remove/expire the owner ban and clear the borrower test ban; a fresh join should then be allowed.
6. Confirm existing longer borrower bans are preserved, and directly owned or unbanned shared licenses do not trigger automatic bans.

## Updating from versions with IP blocking

Replace the entire old security pack folder; merging folders can leave the removed `lua/autorun/server/vss_ip_ban_guard.lua` active. If present on your server, delete that old Lua file and `garrysmod/data/vss_security/known_ips.json` to remove previously stored IP records. Restart the server to clear the old hooks and timer. The updated pack contains no IP collection, storage, or blocking code. Existing SteamID bans remain managed by ULX/ULib.

## Scanner alert delivery fix - November 15, 2026

ULib supports the private delivery used here: its IsAdmin/IsSuperAdmin methods follow group inheritance and `ULib.tsay(recipient, message)` sends only to the specified recipient. Scanner staff alerts now explicitly use that ULib function, falling back to ChatPrint if ULib is unavailable. No broadcast or ULX public logging function is used.

ACF can reject scanner use locally before sending UpdatePlayer to the server. A server-only guard cannot observe those clicks. The automatically distributed client helper wraps the scanner entry function before its local permission/vehicle checks: in PvP it sends one dedicated attempt message instead of the normal scanner request. The server uses the actual sending player and server-side buildmode state, then blocks scanning and alerts staff. It accepts no client-supplied identity or rank. The original server scanner guard remains in place for direct scanner requests and modified clients. Build-mode scans remain unlogged. Clicks that never invoke ACF.Scanning.BeginScanning are outside this reporting path.

Mocked integration tests passed for normal-player/admin reports through ULib.tsay, admin/superadmin-only delivery, rejection of build-mode reports, client interception before local permission checks, one report per normal click, build-mode delegation, immediate transition stops, and scanner reload handling. This addresses a source-visible missed-attempt path; the reported live-server behavior has not been reproduced directly. Verify on the server after updating.

Replace the addon folder, restart the server, and have players reconnect to receive the client helper. Test as a normal player in actual PvP mode with an admin and superadmin online. Ranks must inherit from ULX's admin or superadmin group to qualify; merely having selected ULX command permissions does not make a rank an admin.
