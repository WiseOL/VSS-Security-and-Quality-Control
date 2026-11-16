-- Report PvP clicks before ACF's local permission checks can swallow them.
local wrappedBegin
local function Install()
    local scanning = ACF and ACF.Scanning
    if not scanning or not isfunction(scanning.BeginScanning) then return end
    if scanning.BeginScanning == wrappedBegin then return end
    local original = scanning.BeginScanning
    wrappedBegin = function(...)
        local ply = LocalPlayer()
        if IsValid(ply) and not ply:GetNWBool("_Kyle_Buildmode", false) then
            -- No claimed identity, rank, mode or target: server verifies the sender.
            net.Start("VSSSecurity.ScannerAttempt")
            net.SendToServer()
            return
        end
        return original(...)
    end
    scanning.BeginScanning = wrappedBegin
end
hook.Add("InitPostEntity", "ACFPvPScannerGuard.ClientInstall", Install)
timer.Create("ACFPvPScannerGuard.ClientInstall", 1, 0, Install)
Install()
