Core = {
    ResourceName = GetCurrentResourceName()
}

Core.Print = function(...)
    local payload = table.pack(...)
    print("^5[" .. Core.ResourceName .. "] ^7" .. table.concat(payload, " ") .. "^0")
end

Core.Debug = function(...)
    if not Config.Debug then return end
    local payload = table.pack(...)
    print("^5[DEBUG] ^5" .. table.concat(payload, " ") .. "^0")
end

Core.Error = function(...)
    local payload = table.pack(...)
    print("^5[ERROR] ^1" .. table.concat(payload, " ") .. "^0")
end
