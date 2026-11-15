-- Server integration for Valen-Sandbox/Buildmode-ULX and official ACF-Team/ACF-3.
local REASON = "The ACF scanner is disabled in PvP mode. Switch to build mode to scan."
local function Restricted(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply.buildmode
end
local function Alert(ply, action)
    local name = string.gsub(ply:Nick(), "[%c]", " ")
    local message = "[ACF Scanner Guard] " .. name .. " (" .. ply:SteamID() .. ") " .. action
    for _, recipient in ipairs(player.GetAll()) do
        if recipient:IsAdmin() or recipient:IsSuperAdmin() then
            recipient:ChatPrint(message)
        end
    end
end
local function Stop(scanning, ply)
    scanning.EndScanning(ply)
    net.Start("ACF_Scanning_NetworkPacket")
    net.WriteString("ForceScanningEnd")
    net.WriteString(REASON)
    net.Send(ply)
end
-- Buildmode-ULX emits this after normal and forced PvP transitions.
-- Keep the Think guard too: spawn protection/death paths can change the field directly.
hook.Add("OnPlayerSwitchModePVPBUILD", "ACFPvPScannerGuard.ModeChanged", function(ply, inBuild)
    local scanning = ACF and ACF.Scanning
    if inBuild ~= false or not Restricted(ply) or not scanning
        or not isfunction(scanning.IsPlayerScanning)
        or not isfunction(scanning.EndScanning) then return end
    if scanning.IsPlayerScanning(ply) then
        Stop(scanning, ply)
        Alert(ply, "entered PvP with an active ACF scanner; scanning stopped.")
    end
end)
local wrappedBegin, wrappedThink
local function Install()
    local scanning = ACF and ACF.Scanning
    if not scanning or not isfunction(scanning.BeginScanning)
        or not isfunction(scanning.EndScanning)
        or not isfunction(scanning.IsPlayerScanning) then return end
    if scanning.BeginScanning ~= wrappedBegin then
        local original = scanning.BeginScanning
        wrappedBegin = function(ply, ...)
            if Restricted(ply) then
                Alert(ply, "attempted to use the ACF scanner in PvP; blocked.")
                Stop(scanning, ply)
                return
            end
            return original(ply, ...)
        end
        scanning.BeginScanning = wrappedBegin
    end
    local think = hook.GetTable().Think
    local original = think and think.ACF_Scanning_ScanEnts
    if isfunction(original) and original ~= wrappedThink then
        -- Enforce before ACF sends scan data, independent of hook iteration order.
        wrappedThink = function(...)
            for _, ply in ipairs(player.GetAll()) do
                if Restricted(ply) and scanning.IsPlayerScanning(ply) then
                    Stop(scanning, ply)
                    Alert(ply, "entered PvP with an active ACF scanner; scanning stopped.")
                end
            end
            return original(...)
        end
        hook.Add("Think", "ACF_Scanning_ScanEnts", wrappedThink)
    end
end
-- ACF uses its own loader. Retry to accommodate startup and scanner reloads.
hook.Add("InitPostEntity", "ACFPvPScannerGuard.Install", Install)
timer.Create("ACFPvPScannerGuard.Install", 1, 0, Install)
Install()


