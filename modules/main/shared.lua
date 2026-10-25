function NumberWithCommas(x)
    return _L("money_number", tostring(x):reverse():gsub("(%d%d%d)", "%1,"):gsub(",(%-?)$", "%1"):reverse())
end

function GetBusinessLocation(businessId, locationId)
    local business = Businesses[businessId]
    if not business then return end
    for i=1, #business.game_info.locations do
        if business.game_info.locations[i].id == locationId then
            return i, business.game_info.locations[i]
        end
    end
end

function DoesZoneAcceptDirtyCash(zoneName)
    local zoneIndex, zone = GetBusinessZoneIndexByName(zoneName)
    return (zone and zone.acceptsDirtyCash == true) or false
end

function GetBusinessZoneIndexByName(zoneName)
    for i=1, #Config.BusinessZones do 
        if Config.BusinessZones[i].name == zoneName then
            return i, Config.BusinessZones[i]
        end
    end
end

function GetBusinessZoneNameByIndex(index)
    return Config.BusinessZones[index].name
end

function GetBusinessZones(isMenuQuery)
    local zones = {}
    if isMenuQuery then
        for i=1, #Config.BusinessZones do
            zones[#zones + 1] = Config.BusinessZones[i].label
        end
    else
        zones = Config.BusinessZones
    end
    return zones
end