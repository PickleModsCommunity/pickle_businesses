local currentBusinessUI = nil
local placingMarket = false

local function SortArrayByProperty(keyName, a, b)
    a = tostring(a[keyName])
    b = tostring(b[keyName])
    local patt = '^(.-)%s*(%d+)$'
    local _,_, col1, num1 = a:find(patt)
    local _,_, col2, num2 = b:find(patt)
    if (col1 and col2) and col1 == col2 then
       return tonumber(num1) < tonumber(num2)
    end
    return a < b
end

function KeyToArray(keyName, sortName, data) 
    local tbl = {}
    for k,v in pairs(data) do 
        tbl[#tbl + 1] = v
        tbl[#tbl][keyName] = k
    end
    table.sort(tbl, function(a, b) return SortArrayByProperty(sortName, a, b) end)
    return tbl
end

function OpenBusinessStore(key)
    local business = Businesses[key]
    if not business then return end
    currentBusinessUI = key
    lib.callback("pickle_businesses:getStoreData", "", function(player_inventory, employees, admin)
        isAdmin = admin
        SendNUIMessage({
            type = "openStore",
            index = key,
            data = {
                config = {
                    language = Language[Config.Language],
                    img_folder = Config.ItemImageFolder
                },
                acceptsDirtyCash = DoesZoneAcceptDirtyCash(business.zone),
                admin = admin,
                label = business.label or "Untitled Business",
                money = business.money or 0,
                dirty_money = business.dirty_money or 0,
                items = KeyToArray("name", "label", Inventory.Items),
                game_info = business.game_info or {},
                player_inventory = player_inventory,
                store_listings = business.store_listings or {},
                trade_listings = business.trade_listings or {},
                trade_inventory = business.trade_inventory or {},
                daily_sales = business.daily_sales or {},
                recent_sales = business.recent_sales or {},
                recent_trades = business.recent_trades or {},
                employees = employees or {},
                roles = business.roles or {},
                source = GetPlayerServerId(PlayerId())
            }
        })
        SetNuiFocus(true, true)
    end, key)
end

function OpenMarketSubmenu(businessId)
    local business = Businesses[businessId]
    if not business then return end
    options = {}
    options[#options + 1] = {
        title = _L("market_access"),
        icon = "store",
        onSelect = function()
            OpenBusinessStore(businessId)
        end
    }
    options[#options + 1] = {
        title = _L("market_remove"),
        icon = "trash",
        onSelect = function()
            if Customize_GenericConfirm(_L("market_remove_confirm")) then
                TriggerServerEvent("pickle_businesses:removeBusiness", businessId)
            else
                OpenMarketSubmenu(businessId)
            end
        end
    }
    lib.registerContext({
        id = 'pb_market_submenu',
        title = _L("billing_charge_title"),
        -- canClose = false,
        onExit = function()
            lib.hideContext()
            SetTimeout(100, function()
                OpenMarketSubmenu(businessId)
            end)
        end,
        options = options
    })
    lib.showContext('pb_market_submenu')
end

function DisplayMarketLocations(businessId)
    local business = Businesses[businessId]
    if not business then return end
    local locations = business.game_info.locations
    local index = 1
    local location = locations[index]
    LocalBusinessLocations[businessId][index] = {
        id = index,
        coords = location.coords,
        rotation = location.rotation,
        model = location.model,
    }
    LocalBusinessLocations[businessId][index].interact = CreateInteraction({
        label = _L("business_interact_market"),
        coords = vector3(location.coords.x, location.coords.y, location.coords.z),
        interactOffset = Config.InteractOffsetModels[location.model],
        heading = location.rotation.z,
        model = location.model and {hash = location.model, modelType = "prop"} or nil,
    }, function()
        if isAdmin or business.owner == identifier then
            OpenMarketSubmenu(businessId)
        else
            OpenBusinessStore(businessId)
        end
    end)
end

RegisterNetEvent("pickle_businesses:updateListings", function(businessId, listings)
    Businesses[businessId].store_listings = listings
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateStoreListings",
        index = businessId,
        data = {
            store_listings = listings
        }
    })
    lib.callback("pickle_businesses:getInventory", "", function(player_inventory)
        SendNUIMessage({
            type = "updatePlayerInventory",
            index = businessId,
            data = {
                player_inventory = player_inventory
            }
        })
    end)
end)

RegisterNetEvent("pickle_businesses:updateRecentSales", function(businessId, sales)
    Businesses[businessId].recent_sales = sales
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateRecentSales",
        index = businessId,
        data = {
            recent_sales = sales
        }
    })
end)

RegisterNetEvent("pickle_businesses:updateDailySales", function(businessId, sales)
    Businesses[businessId].daily_sales = sales
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateDailySales",
        index = businessId,
        data = {
            daily_sales = sales
        }
    })
end)

RegisterNetEvent("pickle_businesses:updateRoles", function(businessId, roles)
    Businesses[businessId].roles = roles
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateRoles",
        index = businessId,
        data = {
            roles = roles
        }
    })
end)

RegisterNetEvent("pickle_businesses:customInformation", function(dataPack) 
    for i=1, #dataPack do 
        if dataPack[i].type == "updateRecentSales" then
            TriggerEvent("pickle_businesses:updateRecentSales", dataPack[i].index, dataPack[i].data)
        elseif dataPack[i].type == "updateDailySales" then
            TriggerEvent("pickle_businesses:updateDailySales", dataPack[i].index, dataPack[i].data)
        elseif dataPack[i].type == "updateListings" then
            TriggerEvent("pickle_businesses:updateListings", dataPack[i].index, dataPack[i].data)
        end
    end
end)

RegisterNetEvent("pickle_businesses:updateTradeInventory", function(businessId, inventory)
    Businesses[businessId].trade_inventory = inventory
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateTradeInventory",
        index = businessId,
        data = {
            trade_inventory = inventory
        }
    })
end)

RegisterNetEvent("pickle_businesses:updateEmployees", function(businessId, employees)
    local newEmployees = {}
    local isEmployee = (Businesses[businessId].employees[identifier] ~= nil)
    for i=1, #employees do 
        newEmployees[employees[i].identifier] = employees[i]
    end
    Businesses[businessId].employees = newEmployees
    if (isEmployee and not newEmployees[identifier]) or (not isEmployee and newEmployees[identifier]) then
        DisplayBusinessLocations(businessId)
    end
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateEmployees",
        index = businessId,
        data = {
            employees = employees
        }
    })
end)

RegisterNetEvent("pickle_businesses:updateTradeListings", function(businessId, trade_listings)
    Businesses[businessId].trade_listings = trade_listings
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateTradeListings",
        index = businessId,
        data = {
            trade_listings = trade_listings
        }
    })
end)

RegisterNetEvent("pickle_businesses:updateBusinessBalance", function(businessId, key, value)
    Businesses[businessId][key] = value
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateBusinessBalance",
        index = businessId,
        data = {
            currency = key,
            value = value
        }
    })
end)

RegisterNetEvent("pickle_businesses:updateBusinessSettings", function(businessId, settings)
    Businesses[businessId].label = settings.label
    Businesses[businessId].game_info = settings.game_info
    if currentBusinessUI ~= businessId then return end
    SendNUIMessage({
        type = "updateBusinessSettings",
        index = businessId,
        data = {
            label = settings.label,
            game_info = settings.game_info
        }
    })
end)

RegisterNetEvent("pickle_businesses:placeMarket", function(marketType)
    local market = Config.PlaceableMarkets[marketType]
    if not market then return print("^1[ERROR] MARKET " .. marketType .. " DOESN'T EXIST!^0") end
    if placingMarket then return end
    placingMarket = true
    local object = nil
    local endCoords = nil
    local model = market.model
    local rotation = {x = 0, y = 0, z = 0}
    CreateThread(function()
        local ticksLeft = 0
        local cancelled = false
        while placingMarket do
            ticksLeft = ticksLeft - 1
            if ticksLeft == 0 or endCoords == nil then
                CreateThread(function()
                    local coords = GetRaycastCoords()
                    if coords and #(coords - GetEntityCoords(PlayerPedId())) < 10.0 then
                        endCoords = coords
                    end
                    ticksLeft = 5
                end)
            end
            if endCoords then
                if not object then
                    minZ = GetModelDimensions(model).z
                    object = CreateLocalProp(model, endCoords.x, endCoords.y, endCoords.z, true, false, false)
                    SetEntityCollision(object, false, false)
                    SetEntityAsMissionEntity(object, true, true)
                    FreezeEntityPosition(object, true)
                end 
                SetEntityCoords(object, endCoords.x, endCoords.y, endCoords.z - minZ, false, false, false, false)
                SetEntityRotation(object, rotation.x, rotation.y, rotation.z, 2, true)
            end
            ShowInteractText("[E] Place Market | Left Arrow: Rotate Left | Right Arrow: Rotate Right")
            if IsControlPressed(1, 174) then
                rotation.z = rotation.z + 0.5
            elseif IsControlPressed(1, 175) then
                rotation.z = rotation.z - 0.5
            end
            if IsControlPressed(1, 51) or IsControlJustPressed(1, 201) then
                break
            elseif IsControlPressed(1, 177) then
                cancelled = true
                break
            end
            Wait(0)
        end
        placingMarket = false
        DeleteEntity(object)
        if cancelled then return end
        if not endCoords then return end
        TriggerServerEvent("pickle_businesses:placeMarket", marketType, vector3(endCoords.x, endCoords.y, endCoords.z), vector3(rotation.x, rotation.y, rotation.z))
    end)
end)

RegisterNUICallback("marketBuyAction", function(data, cb)
    if data.action == "add_item" then
        TriggerServerEvent("pickle_businesses:addStoreListing", currentBusinessUI, data.item, data.price, data.quantity)
    elseif data.action == "move_item" then
        TriggerServerEvent("pickle_businesses:moveStoreListing", currentBusinessUI, data.from, data.to)
    elseif data.action == "edit_item" then
        TriggerServerEvent("pickle_businesses:editStoreListing", currentBusinessUI, data.sku, data.price, data.quantity)
    elseif data.action == "purchase" then
        lib.callback("pickle_businesses:purchaseCart", "", function(result)
            cb(result)
        end, currentBusinessUI, data.cart, data.paymentMethod)
    end
    if data.action~="purchase" then cb(true) end
end)

RegisterNUICallback("marketTradeAction", function(data, cb)
    if data.action == "add_listing" then
        TriggerServerEvent("pickle_businesses:addTradeListing", currentBusinessUI, data.tradeData)
    elseif data.action == "update_listing" then
        TriggerServerEvent("pickle_businesses:updateTradeListing", currentBusinessUI, data.sku, data.tradeData)
    elseif data.action == "delete_listing" then
        TriggerServerEvent("pickle_businesses:deleteTradeListing", currentBusinessUI, data.sku)
    elseif data.action == "accept_trade" then 
        TriggerServerEvent("pickle_businesses:acceptTrade", currentBusinessUI, data.sku)
    end
    if true then cb(true) end
end)

RegisterNUICallback("marketManageAction", function(data, cb)
    if data.action == "add_item" then
        TriggerServerEvent("pickle_businesses:addTradeInventory", currentBusinessUI, data.item, data.quantity)
    elseif data.action == "edit_item" then
        TriggerServerEvent("pickle_businesses:editTradeInventory", currentBusinessUI, data.sku, data.quantity)
    elseif data.action == "add_role" then
        TriggerServerEvent("pickle_businesses:addRole", currentBusinessUI, data.roleData)
    elseif data.action == "edit_role" then
        TriggerServerEvent("pickle_businesses:editRole", currentBusinessUI, data.roleId, data.roleData)
    elseif data.action == "delete_role" then
        TriggerServerEvent("pickle_businesses:deleteRole", currentBusinessUI, data.roleId)
    elseif data.action == "promote_role" then
        TriggerServerEvent("pickle_businesses:moveRole", currentBusinessUI, data.roleId, true)
    elseif data.action == "demote_role" then
        TriggerServerEvent("pickle_businesses:moveRole", currentBusinessUI, data.roleId, false)
    elseif data.action == "add_employee" then
        TriggerServerEvent("pickle_businesses:addEmployee", currentBusinessUI, data.source, data.roleId)
    elseif data.action == "edit_employee" then
        TriggerServerEvent("pickle_businesses:editEmployee", currentBusinessUI, data.identifier, data.roleId)
    elseif data.action == "delete_employee" then
        TriggerServerEvent("pickle_businesses:deleteEmployee", currentBusinessUI, data.identifier)
    elseif data.action == "save_settings" then
        TriggerServerEvent("pickle_businesses:saveSettings", currentBusinessUI, {
            label = data.label,
            business = data.business,
            purchase = data.purchase,
            trade = data.trade,
        })
    elseif data.action == "getNearbyPlayers" then 
        lib.callback("pickle_businesses:getNearbyPlayers", "", function(players)
            cb(players)
        end)
    elseif data.action == "deposit" or data.action == "withdraw" then
        TriggerServerEvent("pickle_businesses:balanceTransaction", currentBusinessUI, data.action, data.currency, data.amount)
    end
    if data.action~="getNearbyPlayers" then cb(true) end
end)

RegisterNUICallback("closeMenu", function(data, cb)
    SetNuiFocus(false, false)
end)

RegisterNetEvent("onResourceStart", function(name)
    if name == GetCurrentResourceName() then
        Wait(1000)
        TriggerServerEvent("pickle_businesses:initializePlayer")
    end
    if true then cb(true) end
end)