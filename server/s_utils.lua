--[[
    Pixel Logs - Utility Functions
    Version: 1.04122025
]]

local Utils = {}

-- Debug Logging
local debugLogs = {}
local maxDebugLogs = Config.Debug.MaxLogs

-- Avatar Cache
local avatarCache = {}

-- Rate limiting
local lastWebhookTime = 0
local webhookCooldown = 1.0 -- 1 second cooldown between webhooks

-- Helper function to safely get resource metadata
local function GetResourceMetadataSafe(resource, key, index)
    local success, result = pcall(function()
        return GetResourceMetadata(resource, key, index)
    end)
    return success and result or 'Unknown'
end

-- Helper function to safely get convar
local function GetConvarSafe(name, default)
    local success, result = pcall(function()
        return GetConvar(name, default)
    end)
    return success and result or default
end

-- Helper function to safely encode JSON
local function SafeJsonEncode(data)
    local success, result = pcall(function()
        return json.encode(data)
    end)
    return success and result or 'Failed to encode JSON'
end

-- Helper function to safely decode JSON
local function SafeJsonDecode(data)
    local success, result = pcall(function()
        return json.decode(data)
    end)
    return success and result or nil
end

-- Helper function to safely iterate over tables
local function SafeTableIterate(t, func)
    if type(t) ~= 'table' then
        print('^1[Pixel Logs] Warning: Attempted to iterate over non-table value: ' .. type(t) .. '^0')
        return
    end
    
    local success, err = pcall(function()
        for k, v in pairs(t) do
            func(k, v)
        end
    end)
    
    if not success then
        print('^1[Pixel Logs] Error during table iteration: ' .. tostring(err) .. '^0')
    end
end

function Utils.GetPlayerAvatar(source, identifierType, identifier)
    if not Config.Avatars.Enabled then return Config.Avatars.Default end
    
    -- Check cache first
    local cacheKey = identifierType .. ':' .. identifier
    if avatarCache[cacheKey] then
        return avatarCache[cacheKey]
    end
    
    -- Get avatar based on identifier type
    local avatarUrl = Config.Avatars.Default
    
    if Config.Avatars.Types[identifierType] then
        if identifierType == 'steam' then
            -- Extract the Steam ID from the identifier
            local steamId = identifier:gsub('steam:', '')
            
            -- Convert Steam Hex to Steam64 ID
            local steam64 = tonumber(steamId, 16)
            if steam64 then
                steam64 = steam64 + 76561197960265728
                avatarUrl = string.format('https://steamcommunity.com/profiles/%d/?xml=1', steam64)
                
                -- Make HTTP request to get Steam avatar
                PerformHttpRequest(avatarUrl, function(err, text, headers)
                    if not err and text then
                        local avatarHash = text:match('<avatarFull>.-steamcommunity.com/public/images/avatars/(.-)</avatarFull>')
                        if avatarHash then
                            avatarUrl = string.format('https://steamcommunity.com/public/images/avatars/%s', avatarHash)
                            avatarCache[cacheKey] = avatarUrl
                        end
                    end
                end, 'GET', '', {})
            end
            
        elseif identifierType == 'discord' then
            -- Extract the Discord ID from the identifier
            local discordId = identifier:gsub('discord:', '')
            
            -- Use Discord's default avatar with a random color (0-4)
            local colorIndex = math.random(0, 4)
            avatarUrl = string.format('https://cdn.discordapp.com/embed/avatars/%d.png', colorIndex)
            
            -- Note: To get the actual Discord avatar, we would need to use the Discord API
            -- which requires a bot token and additional setup
            
        elseif identifierType == 'fivem' then
            -- Extract the FiveM ID from the identifier
            local fivemId = identifier:gsub('fivem:', '')
            avatarUrl = string.format('https://forum.cfx.re/user_avatar/forum.cfx.re/%s/240.png', fivemId)
        end
    end
    
    -- Cache the result
    avatarCache[cacheKey] = avatarUrl
    return avatarUrl
end

function Utils.GetPlayerIdentifiers(source)
    local identifiers = {}
    local numIds = GetNumPlayerIdentifiers(source)
    
    for i = 0, numIds - 1 do
        local identifier = GetPlayerIdentifier(source, i)
        if identifier then
            local type = identifier:match('^([^:]+):')
            if type then
                identifiers[type] = identifier
            end
        end
    end
    
    return identifiers
end

function Utils.FormatMessage(messageType, message, data)
    local messageConfig = Config.Messages[messageType]
    if not messageConfig then
        exports['pixel_logs']:CatchError('Invalid message type: ' .. tostring(messageType), 'FormatMessage')
        return message
    end
    
    local formatted = message
    if data and type(data) == 'table' then
        for key, value in pairs(data) do
            formatted = formatted:gsub('{' .. key .. '}', tostring(value))
        end
    end
    
    return formatted
end

function Utils.CreateEmbed(messageType, message, source, customColor, data)
    local messageConfig = Config.Messages[messageType]
    if not messageConfig then
        exports['pixel_logs']:CatchError('Invalid message type: ' .. tostring(messageType), 'CreateEmbed')
        return nil
    end
    
    local embed = {
        color = customColor or Config.Colors[messageType] or 16777215,
        title = messageConfig.title,
        description = message,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = {
            text = 'Server Logs'
        }
    }
    
    if source then
        local identifiers = Utils.GetPlayerIdentifiers(source)
        local avatarUrl = Config.Avatars.Default
        
        -- Try to get player avatar
        if Config.Avatars.Enabled then
            for identifierType, enabled in pairs(Config.Avatars.Types) do
                if enabled and identifiers[identifierType] then
                    avatarUrl = Utils.GetPlayerAvatar(source, identifierType, identifiers[identifierType])
                    break
                end
            end
        end
        
        -- Add avatar to embed
        embed.thumbnail = {
            url = avatarUrl
        }
        
        -- Add identifier fields
        local identifierFields = {}
        for identifierType, enabled in pairs(Config.Identifiers) do
            if enabled and identifiers[identifierType] then
                identifierFields[#identifierFields + 1] = {
                    name = identifierType:upper(),
                    value = identifiers[identifierType],
                    inline = true
                }
            end
        end
        
        -- Add message fields
        if messageConfig.fields then
            local fields = {}
            
            -- Add message-specific fields
            for _, field in ipairs(messageConfig.fields) do
                local value = field.value
                if data and type(data) == 'table' then
                    for k, v in pairs(data) do
                        value = value:gsub('{' .. k .. '}', tostring(v))
                    end
                end
                fields[#fields + 1] = {
                    name = field.name,
                    value = value,
                    inline = field.inline
                }
            end
            
            -- Add identifier fields
            for _, field in ipairs(identifierFields) do
                fields[#fields + 1] = field
            end
            
            embed.fields = fields
        end
    end
    
    return embed
end

-- Debug Logging Functions
function Utils.AddDebugLog(type, message, data)
    if not Config.Debug.Enabled then return end
    
    -- Skip sending embeds for webhook errors to prevent circular references
    if type == 'error' and message and message:match('Failed to send webhook') then
        -- Just log to console for webhook errors to prevent loops
        print(string.format('^1[pixel_logs] Webhook Error: %s^0', message))
        return
    end
    
    local log = {
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
        type = type,
        message = message,
        data = data
    }
    
    table.insert(debugLogs, log)
    
    -- Remove oldest log if we exceed the maximum
    if #debugLogs > maxDebugLogs then
        table.remove(debugLogs, 1)
    end
    
    -- Only send embed for errors or when explicitly requested
    if type == 'error' or (data and data.sendEmbed) then
        -- Create detailed debug embed
        local embed = {
            color = 16711680, -- Red color
            title = 'Debug Log',
            description = string.format('**Type:** %s\n**Message:** %s\n**Timestamp:** %s', type, message, log.timestamp),
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            fields = {
                {
                    name = 'Resource',
                    value = GetCurrentResourceName(),
                    inline = true
                },
                {
                    name = 'Server ID',
                    value = GetConvar('sv_hostname', 'Unknown'),
                    inline = true
                }
            }
        }
        
        -- Add data fields if present
        if data then
            for k, v in pairs(data) do
                if k ~= 'sendEmbed' then -- Skip the sendEmbed flag
                    if type(v) == 'table' then
                        table.insert(embed.fields, {
                            name = k,
                            value = '```json\n' .. SafeJsonEncode(v) .. '\n```',
                            inline = false
                        })
                    else
                        table.insert(embed.fields, {
                            name = k,
                            value = tostring(v),
                            inline = true
                        })
                    end
                end
            end
        end
        
        -- Use debug webhook if specified, otherwise use default webhook
        local webhook = Config.Debug.Webhook ~= '' and Config.Debug.Webhook or Config.DiscordWebhook
        
        -- Send the embed using the appropriate webhook
        local originalWebhook = Config.DiscordWebhook
        Config.DiscordWebhook = webhook
        Utils.SendEmbedToDiscord(embed)
        Config.DiscordWebhook = originalWebhook
    end
end

function Utils.GetDebugLog(index)
    return debugLogs[index]
end

function Utils.GetAllDebugLogs()
    return debugLogs
end

function Utils.SendEmbedToDiscord(embed)
    if not embed then return end
    
    -- Ensure embed has required fields
    embed.timestamp = embed.timestamp or os.date('!%Y-%m-%dT%H:%M:%SZ')
    embed.footer = embed.footer or {text = 'Server Logs'}
    
    -- Prepare the webhook payload
    local payload = {
        username = Config.DiscordUsername,
        avatar_url = Config.DiscordAvatar,
        embeds = {embed}
    }
    
    -- Encode the payload
    local jsonPayload = SafeJsonEncode(payload)
    if not jsonPayload then
        print('^1[pixel_logs] Error: Failed to encode webhook payload^0')
        return
    end
    
    -- Prepare headers
    local headers = {
        ['Content-Type'] = 'application/json'
    }
    
    -- Add proxy configuration if enabled
    local options = {}
    if Config.Proxy.Enabled and Config.Proxy.URL ~= '' then
        options = {
            proxy = Config.Proxy.URL,
            proxyAuth = Config.Proxy.Username ~= '' and Config.Proxy.Password ~= '' and 
                       string.format('%s:%s', Config.Proxy.Username, Config.Proxy.Password) or nil
        }
    end
    
    -- Send the webhook request
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers)
        -- HTTP 204 is a success code (No Content)
        if err == 204 then
            -- Success, do nothing
            return
        end
        
        -- Handle actual errors
        if err then
            -- Log to console only, not to Discord to prevent loops
            print(string.format('^1[pixel_logs] Error: Failed to send webhook: %s^0', tostring(err)))
            
            -- If we hit rate limit (429), log a warning
            if err == 429 then
                print('^3[pixel_logs] Warning: Discord rate limit reached. Some logs may be delayed.^0')
            end
        end
    end, 'POST', jsonPayload, headers, options)
end

-- Export the Utils table
exports('GetUtils', function()
    return Utils
end)

-- Export individual functions
exports('GetPlayerIdentifiers', Utils.GetPlayerIdentifiers)
exports('FormatMessage', Utils.FormatMessage)
exports('CreateEmbed', Utils.CreateEmbed)
exports('AddDebugLog', Utils.AddDebugLog)
exports('GetDebugLog', Utils.GetDebugLog)
exports('GetAllDebugLogs', Utils.GetAllDebugLogs)
exports('SendEmbedToDiscord', Utils.SendEmbedToDiscord)

return Utils 