-- Linked IP blocks: ULib remains the source of truth for duration and unbans.
local PATH = "vss_security/known_ips.json"
local known = util.JSONToTable(file.Read(PATH, "DATA") or "") or {}
if not istable(known) then known = {} end

local function IP(address)
    if not isstring(address) then return end
    local value = string.match(address, "^(%d+%.%d+%.%d+%.%d+):%d+$") or address
    local a,b,c,d = string.match(value, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return end
    for _, octet in ipairs({a,b,c,d}) do
        if tonumber(octet) > 255 then return end
    end
    value = table.concat({tonumber(a),tonumber(b),tonumber(c),tonumber(d)}, ".")
    if value == "0.0.0.0" or string.sub(value,1,4) == "127." then return end
    return value
end

local function Save()
    file.CreateDir("vss_security")
    file.Write(PATH, util.TableToJSON(known, true))
end

local function Remember(ply)
    if not IsValid(ply) or ply:IsBot() or not ply:IsFullyAuthenticated() then return end
    local id, address = ply:SteamID(), IP(ply:IPAddress())
    if not address or not string.match(id or "", "^STEAM_0:[01]:%d+$") then return end
    if known[id] ~= address then known[id] = address; Save() end
end

local function Active(record)
    if not istable(record) then return false end
    local expires = record.unban == nil and 0 or tonumber(record.unban)
    return expires ~= nil and (expires == 0 or expires > os.time())
end

local function Match(address)
    if not address or not ULib or not istable(ULib.bans) then return end
    for id, recordedIP in pairs(known) do
        if recordedIP == address and Active(ULib.bans[id]) then
            return ULib.bans[id]
        end
    end
end

local function Message(record)
    return "[VSS Security] Your IP is linked to an active server ban.\n"
        .. (record.reason or "No reason provided.")
end

hook.Add("CheckPassword", "VSSSecurity.LinkedIPBan", function(_, address)
    local record = Match(IP(address))
    if record then return false, Message(record) end
    -- No allow return: preserve passwords, SteamID bans and other connection checks.
end)

local function Enforce()
    for _, ply in ipairs(player.GetAll()) do
        Remember(ply)
        if IsValid(ply) and not ply:IsBot() then
            local record = Match(IP(ply:IPAddress()))
            if record then ply:Kick(Message(record)) end
        end
    end
end

hook.Add("PlayerAuthed", "VSSSecurity.RecordIP", Remember)
hook.Add("ULibPlayerBanned", "VSSSecurity.LinkedIPBan", function(id)
    -- ULib emits this hook after scheduling the banned player's kick.
    -- Capture its IP while the player entity is still available.
    local ply = player.GetBySteamID(id)
    if IsValid(ply) then Remember(ply) end
    if not known[id] then
        print("[VSS Security] No recorded IP for " .. tostring(id)
            .. "; SteamID ban applies, but an IP block cannot be created yet.")
    end
    Enforce()
end)
-- Also captures existing players on hot reload and applies bans loaded/edited later.
timer.Create("VSSSecurity.LinkedIPBan", 1, 0, Enforce)
