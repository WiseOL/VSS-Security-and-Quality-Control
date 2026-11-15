-- Authenticated Steam license-owner checks against the live ULX/ULib ban list.
local REASON = [[Family-shared account detected with existing banned SteamID on record from parent account - automatic 5 minute ban issued, attempt blocked. If you feel this was a mistake, report it on our discord; https://discord.gg/PvjaPGtwX7. If you were trying to access the server with a ban on record, wait until the ban has expired, or appeal it on the discord as well.

Thank you,
The VSS Admin and Dev Team]]
local checked = setmetatable({}, { __mode = "k" })

local function ActiveBan(id)
    local record = ULib.bans[id]
    if not istable(record) then return false end
    -- ULib keeps expired records too. Missing expiry is used by legacy permanent bans.
    local expires = record.unban == nil and 0 or tonumber(record.unban)
    return expires ~= nil and (expires == 0 or expires > os.time())
end

local function ValidID64(id)
    return isstring(id) and #id == 17 and string.match(id, "^7656119%d+$") ~= nil
end

local function Check(ply)
    if not IsValid(ply) or ply:IsBot() or checked[ply] then return end
    if not ply:IsFullyAuthenticated() then return end
    if not ULib or not istable(ULib.bans) or not isfunction(ULib.addBan) then return end
    local borrower64, owner64 = ply:SteamID64(), ply:OwnerSteamID64()
    -- Never infer sharing from missing or not-yet-populated ownership information.
    if not ValidID64(borrower64) or not ValidID64(owner64) then return end
    local ownerID = util.SteamIDFrom64(owner64)
    local borrowerID = util.SteamIDFrom64(borrower64)
    if not string.match(ownerID or "", "^STEAM_0:[01]:%d+$")
        or not string.match(borrowerID or "", "^STEAM_0:[01]:%d+$") then return end
    checked[ply] = true
    if borrower64 == owner64 or not ActiveBan(ownerID) then return end
    -- Never overwrite an existing borrower ban (including a longer or permanent ban).
    if ActiveBan(borrowerID) then
        ply:Kick("An active ban already exists for your account. " .. REASON)
        return
    end
    local message = "[Family Share Guard] " .. string.gsub(ply:Nick(), "[%c]", " ")
        .. " (" .. borrowerID .. ") used license owner " .. ownerID
        .. " with an active ban; automatic 5 minute ban issued."
    ULib.addBan(borrowerID, 5, REASON, ply:Nick(), "Family Share Guard")
    print(message)
    for _, recipient in ipairs(player.GetAll()) do
        if recipient:IsAdmin() or recipient:IsSuperAdmin() then
            recipient:ChatPrint(message)
        end
    end
end

-- Ownership is only usable after full Steam authentication. Keep retrying pending
-- users, including those present during Lua reload; no client-provided IDs are used.
timer.Create("ACFFamilyShareGuard.Check", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do Check(ply) end
end)




