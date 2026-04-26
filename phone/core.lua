Core.NuiLoaded = false

Core.SendNuiMessage = function(action, payload)
    while not Core.NuiLoaded do
        if not exports['17mov_Phone']:IsPhoneOpen() then
            return
        end
        Wait(100)
    end

    exports['17mov_Phone']:SendAppMessage(
        Config.AppName,
        {
            action = action,
            payload = payload,
        }
    )
end

RegisterNUICallback('Core:NuiLoaded', function(data, cb)
    Core.NuiLoaded = true
    cb({})
end)
