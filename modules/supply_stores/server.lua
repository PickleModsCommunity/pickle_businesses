RegisterNetEvent("pickle_businesses:purchaseSupply", function(businessId, supplyId, method, quantity)
    local source = source
    local business = Businesses[businessId]
    if not business then return end
    local employee = GetBusinessEmployee(source, businessId)
    if not employee then return false end
    if method ~= "cash" and method ~= "card" then return end
    if not BusinessInt(quantity,1,1000) or not BusinessAtSupplier(source) then return end
    local zoneName = business.zone
    local zoneIndex, zone = GetBusinessZoneIndexByName(zoneName)
    if not zone then return end
    local supply = zone.supplies[supplyId]
    if not supply then return end
    local total = supply.price * quantity
    local cash = GetPaymentMethodAmount(source, method)
    if cash < total then
        return ShowNotification(source, _L("supply_store_insufficient_funds", NumberWithCommas(total - cash)))
    end
    if not Inventory.CanCarryItem(source,supply.name,quantity*supply.count) or not BusinessInt(total,1,2147483647) then return end
    if ChargePaymentMethod(source,method,total)~=true then return end
    if Inventory.AddItem(source,supply.name,quantity*supply.count)~=true then AddPaymentMethodAmount(source,method,total); return end
    ShowNotification(source, _L("supply_store_success", GetItemLabel(supply.name), quantity, NumberWithCommas(total)))
end)