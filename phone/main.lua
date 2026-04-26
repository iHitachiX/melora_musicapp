function RegisterApp()
    local resourceName = GetCurrentResourceName()
    local url = GetResourceMetadata(resourceName, "ui_page", 0)

    exports['17mov_Phone']:AddApplication({
        name = Config.AppName,
        label = _('app_label'),
        description = _('app_description'),
        ui = url:find("http") and url or ("https://cfx-nui-%s/%s"):format(resourceName, url),
        icon = ("https://cfx-nui-%s//web/build/icon.svg"):format(resourceName),
        iconBackground = {
            angle = 45,
            colors = { '#1db954', '#072913' },
        },
        default = false,
        preInstalled = true,
        resourceName = resourceName,
        rating = 4.5,
    })
end

CreateThread(function()
    if GetResourceState("17mov_Phone") == "started" then
        RegisterApp()
    end
end)

RegisterNetEvent("17mov_Phone:Client:Ready", function()
    RegisterApp()
end)

if Config.DevMode then
    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            exports['17mov_Phone']:RemoveApplication({
                name = Config.AppName,
                resourceName = resourceName,
            })
        end
    end)
end
