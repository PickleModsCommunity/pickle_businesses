ActiveBills={}
RegisterNetEvent('pickle_businesses:sendBill',function(id,target,charges)
    local src=source
    if not BusinessInt(target,1,65535) or not GetBusinessEmployee(src,id) or not IsPlayerNearby(src,target)
        or type(charges)~='table' or #charges<1 or #charges>50 then return end
    local count=0
    for _,bill in pairs(ActiveBills) do if bill.employeeId==GetIdentifier(src) then count=count+1 end end
    if count>=20 then return end
    local total=0
    for _,row in ipairs(charges) do
        if type(row)~='table' or not BusinessInt(row.price,0,1000000) or not BusinessInt(row.count or 1,1,1000) then return end
        total=total+row.price*(row.count or 1)
    end
    if not BusinessInt(total,1,2147483647) then return end
    local key=src..':'..GetGameTimer()..':'..math.random(1,1000000000)
    ActiveBills[key]={businessId=id,employeeId=GetIdentifier(src),payer=GetIdentifier(target),total=total,expires=os.time()+300}
    TriggerClientEvent('pickle_businesses:sendBill',target,id,key,charges)
end)
RegisterNetEvent('pickle_businesses:payBill',function(key,method)
    local src=source; local bill=ActiveBills[key]
    if not bill or bill.busy or bill.payer~=GetIdentifier(src) or os.time()>bill.expires or not Businesses[bill.businessId]
        or method~='cash' and method~='card' then return end
    bill.busy=true
    if ChargePaymentMethod(src,method,bill.total)~=true then bill.busy=nil; return end
    ActiveBills[key]=nil
    local pay=0; local employee=GetBusinessEmployee(bill.employeeId,bill.businessId)
    if employee then
        local _,role=GetStoreRoleById(bill.businessId,employee.roleId)
        pay=role and math.floor(bill.total*math.min(100,math.max(0,role.commission or 0))/100) or 0
        if pay>0 then AddStoreEmployeePendingMoney(bill.businessId,bill.employeeId,pay) end
    end
    AddStoreFunds(bill.businessId,method,bill.total-pay)
end)
CreateThread(function() while true do Wait(10000); for key,bill in pairs(ActiveBills) do if os.time()>bill.expires then ActiveBills[key]=nil end end end end)
