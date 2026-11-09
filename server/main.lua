local ESX = exports.es_extended:getSharedObject()
local shops, stats = {}, {}
local function admin(src) local x = ESX.GetPlayerFromId(src); return x and Config.PermissionGroups[x.getGroup()] == true end
local function tell(src, msg, kind) TriggerClientEvent('ed_shopcreator:notify', src, msg, kind or 'inform') end
local function text(v, fallback, limit) if type(v) ~= 'string' then return fallback end; v = v:gsub('[\r\n]', ' '):sub(1, limit); return v ~= '' and v or fallback end
local function num(v, fallback, lo, hi) v = tonumber(v); if not v then return fallback end; return math.floor(math.max(lo, math.min(hi, v))) end
local function normalize(data, id)
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then return nil end
    local x,y,z = tonumber(data.coords.x),tonumber(data.coords.y),tonumber(data.coords.z)
    if not x or not y or not z then return nil end
    local s = {id=id,name=text(data.name,'Shop',64),coords={x=x,y=y,z=z},heading=tonumber(data.heading) or 0,npc=data.npc==true,npcModel=text(data.npcModel,Config.NpcModels[1],64),blip=data.blip~=false,blipSprite=num(data.blipSprite,Config.DefaultBlip.sprite,1,999),blipColour=num(data.blipColour,Config.DefaultBlip.colour,0,85),blipScale=math.max(.1,math.min(2,tonumber(data.blipScale) or Config.DefaultBlip.scale)),categories={},items={},jobs={},hours={enabled=data.hours and data.hours.enabled==true,open=num(data.hours and data.hours.open,0,0,23),close=num(data.hours and data.hours.close,24,1,24)}}
    if type(data.categories)=='table' then for _,c in ipairs(data.categories) do if type(c)=='table' then local key=text(c.name,'',40); if key~='' then s.categories[#s.categories+1]={name=key,label=text(c.label,key,40)} end end end end
    if type(data.items)=='table' then for _,i in ipairs(data.items) do if type(i)=='table' and type(i.name)=='string' and i.name:match('^[%w_%-]+$') then s.items[#s.items+1]={name=i.name,price=num(i.price,1,0,Config.MaxPrice),category=text(i.category,'general',40),count=num(i.count,99,1,999)} end end end
    if type(data.jobs)=='table' then for job,grade in pairs(data.jobs) do if type(job)=='string' and job:match('^[%w_%-]+$') then s.jobs[job]=num(grade,0,0,100) end end end
    if #s.items==0 then return nil end
    return s
end
local function persist() SaveResourceFile(GetCurrentResourceName(),Config.DataFile,json.encode({shops=shops,stats=stats},{indent=true}),-1) end
local function register(s)
    local inventory={}
    for _,i in ipairs(s.items) do inventory[#inventory+1]={name=i.name,price=i.price,count=i.count,metadata={category=i.category}} end
    exports.ox_inventory:RegisterShop(s.id,{name=s.name,inventory=inventory,locations={vec3(s.coords.x,s.coords.y,s.coords.z)},groups=next(s.jobs) and s.jobs or nil})
end
local function publish() TriggerClientEvent('ed_shopcreator:shops',-1,shops) end
local function loadData()
    local raw=LoadResourceFile(GetCurrentResourceName(),Config.DataFile)
    if not raw then return end
    local ok,data=pcall(json.decode,raw)
    if ok and type(data)=='table' then
        stats=type(data.stats)=='table' and data.stats or {}
        for id,s in pairs(type(data.shops)=='table' and data.shops or {}) do local valid=normalize(s,id); if valid then shops[id]=valid end end
    end
end
local function hourAllowed(shop)
    if not shop.hours or not shop.hours.enabled then return true end
    local hour=os.date('*t').hour
    local open,close=shop.hours.open,shop.hours.close
    if open==close then return false end
    if open<close then return hour>=open and hour<close end
    return hour>=open or hour<close
end
CreateThread(function()
    loadData()
    while GetResourceState('ox_inventory')~='started' do Wait(500) end
    Wait(500)
    for _,s in pairs(shops) do local ok,err=pcall(register,s); if not ok then print(('[ed_shopcreator] Register failed for %s: %s'):format(s.id,err)) end end
    publish()
end)
lib.callback.register('ed_shopcreator:admin',function(src) return admin(src) end)
lib.callback.register('ed_shopcreator:getStats',function(src,id) if not admin(src) then return nil end; return id and stats[id] or stats end)
RegisterNetEvent('ed_shopcreator:requestShops',function() TriggerClientEvent('ed_shopcreator:shops',source,shops) end)
RegisterNetEvent('ed_shopcreator:saveShop',function(data)
    local src=source
    if not admin(src) then return tell(src,'You are not authorized.','error') end
    if type(data)~='table' then return end
    local id=(type(data.id)=='string' and shops[data.id]) and data.id or ('ed_shop_%d_%d'):format(os.time(),math.random(100,999))
    if not shops[id] and (function() local n=0; for _ in pairs(shops) do n=n+1 end; return n end)()>=Config.MaxShops then return tell(src,'Shop limit reached.','error') end
    local s=normalize(data,id)
    if not s then return tell(src,'Shop data is invalid or has no valid items.','error') end
    local previous=shops[id]
    shops[id]=s
    local ok,err=pcall(register,s)
    if not ok then shops[id]=previous; return tell(src,'ox_inventory registration failed: '..tostring(err),'error') end
    persist(); publish(); tell(src,'Shop saved.','success')
end)
RegisterNetEvent('ed_shopcreator:deleteShop',function(id)
    local src=source
    if not admin(src) then return tell(src,'You are not authorized.','error') end
    if type(id)~='string' or not shops[id] then return end
    shops[id]=nil; stats[id]=nil; persist(); publish()
    tell(src,'Shop removed from the creator. Restart ox_inventory to clear its registered shop.','success')
end)
if GetResourceState('ox_inventory')=='started' then
    exports.ox_inventory:registerHook('buyItem',function(payload)
        local shop=shops[payload.shopType]
        if not shop then return end
        if not hourAllowed(shop) then return false end
        local entry=stats[shop.id] or {sales=0,units=0,revenue=0,items={}}
        local count=tonumber(payload.count) or 1
        local price=tonumber(payload.totalPrice) or 0
        entry.sales=entry.sales+1; entry.units=entry.units+count; entry.revenue=entry.revenue+price
        entry.items[payload.itemName]=(entry.items[payload.itemName] or 0)+count
        stats[shop.id]=entry
        persist()
    end)
end
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() then persist() end end)
