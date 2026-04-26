Locales = {}

-- Load all locale files
local localeFiles = {
    'en',
    'de',
}

for _, locale in ipairs(localeFiles) do
    local localeData = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.lua'):format(locale))
    if localeData then
        local chunk, err = load(localeData, ('locales/%s.lua'):format(locale), 't')
        if chunk then
            chunk()
        end
    end
end

-- Get locale string
function _(key, ...)
    local locale = Config.Locale or 'en'
    local str = Locales[locale] and Locales[locale][key] or Locales['en'][key] or key
    
    if ... then
        return str:format(...)
    end
    return str
end

-- Get current locale code
function GetLocale()
    return Config.Locale or 'en'
end
