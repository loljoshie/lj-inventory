-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local inInventory = false
local currentWeapon = nil
local currentOtherInventory = nil
local Drops = {}
local CurrentDrop = nil
local DropsNear = {}
local CurrentVehicle = nil
local CurrentGlovebox = nil
local CurrentStash = nil
local isCrafting = false
local isHotbar = false
local WeaponAttachments = {}
local showBlur = true

local function HasItem(items, amount)
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = #items
    local count = 0
    local kvIndex = 2
	if isTable and not isArray then
        totalItems = 0
        for _ in pairs(items) do totalItems += 1 end
        kvIndex = 1
    end
    for _, itemData in pairs(PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                local itemKV = {k, v}
                if itemData and itemData.name == itemKV[kvIndex] and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                    count += 1
                end
            end
            if count == totalItems then
                return true
            end
        else -- Single item as string
            if itemData and itemData.name == items and (not amount or (itemData and amount and itemData.amount >= amount)) then
                return true
            end
        end
    end
    return false
end

exports("HasItem", HasItem)

RegisterNUICallback('showBlur', function()
    Wait(50)
    TriggerEvent("lj-inventory:client:showBlur")
end) 
RegisterNetEvent("lj-inventory:client:showBlur", function()
    Wait(50)
    showBlur = not showBlur
end)

-- Functions

local function GetClosestVending()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local object = nil
    for _, machine in pairs(Config.VendingObjects) do
        local ClosestObject = GetClosestObjectOfType(pos.x, pos.y, pos.z, 0.75, GetHashKey(machine), 0, 0, 0)
        if ClosestObject ~= 0 then
            if object == nil then
                object = ClosestObject
            end
        end
    end
    return object
end

local function OpenVending()
    local ShopItems = {}
    ShopItems.label = "Vending Machine"
    ShopItems.items = Config.VendingItem
    ShopItems.slots = #Config.VendingItem
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "Vendingshop_"..math.random(1, 99), ShopItems)
end

local function DrawText3Ds(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function FormatWeaponAttachments(itemdata)
    local attachments = {}
    itemdata.name = itemdata.name:upper()
    if itemdata.info.attachments ~= nil and next(itemdata.info.attachments) ~= nil then
        for _, v in pairs(itemdata.info.attachments) do
            attachments[#attachments+1] = {
                attachment = v.item,
                label = v.label,
                image = QBCore.Shared.Items[v.item].image,
                component = v.component
            }
        end
    end
    return attachments
end

local function IsBackEngine(vehModel)
    return BackEngineVehicles[vehModel]
end


local function OpenTrunk()
    local vehicle = QBCore.Functions.GetClosestVehicle()
    LoadAnimDict("amb@prop_human_bum_bin@idle_b")
    TaskPlayAnim(PlayerPedId(), "amb@prop_human_bum_bin@idle_b", "idle_d", 4.0, 4.0, -1, 50, 0, false, false, false)
    if IsBackEngine(GetEntityModel(vehicle)) then
        SetVehicleDoorOpen(vehicle, 4, false, false)
    else
        SetVehicleDoorOpen(vehicle, 5, false, false)
    end
end

---Closes the trunk of the closest vehicle
local function CloseTrunk()
    local vehicle = QBCore.Functions.GetClosestVehicle()
    LoadAnimDict("amb@prop_human_bum_bin@idle_b")
    TaskPlayAnim(PlayerPedId(), "amb@prop_human_bum_bin@idle_b", "exit", 4.0, 4.0, -1, 50, 0, false, false, false)
    if IsBackEngine(GetEntityModel(vehicle)) then
        SetVehicleDoorShut(vehicle, 4, false)
    else
        SetVehicleDoorShut(vehicle, 5, false)
    end
end

---Closes the inventory NUI
local function closeInventory()
    SendNUIMessage({
        action = "close",
    })
end

local function ToggleHotbar(toggle)
    local HotbarItems = {
        [1] = PlayerData.items[1],
        [2] = PlayerData.items[2],
        [3] = PlayerData.items[3],
        [4] = PlayerData.items[4],
        [5] = PlayerData.items[5],
        [41] = PlayerData.items[41],
    }

    SendNUIMessage({
        action = "toggleHotbar",
        open = toggle,
        items = HotbarItems
    })
end


local function openAnim()
    local ped = PlayerPedId()
    LoadAnimDict('pickup_object')
    TaskPlayAnim(ped,'pickup_object', 'putdown_low', 5.0, 1.5, 1.0, 48, 0.0, 0, 0, 0)
    Wait(500)
    StopAnimTask(ped, 'pickup_object', 'putdown_low', 1.0)
end

local function ItemsToItemInfo()
	itemInfos = {
		[1] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 22x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 32x."},
		[2] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 30x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 42x."},
		[3] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 30x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 45x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 28x."},
		[4] = {costs = QBCore.Shared.Items["electronickit"]["label"] .. ": 2x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 52x, "..QBCore.Shared.Items["steel"]["label"] .. ": 40x."},
		[5] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 10x, " ..QBCore.Shared.Items["plastic"]["label"] .. ": 50x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 30x, "..QBCore.Shared.Items["iron"]["label"] .. ": 17x, "..QBCore.Shared.Items["electronickit"]["label"] .. ": 1x."},
		[6] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 36x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 24x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 28x."},
		[7] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 32x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 43x, "..QBCore.Shared.Items["plastic"]["label"] .. ": 61x."},
		[8] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 50x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 37x, "..QBCore.Shared.Items["copper"]["label"] .. ": 26x."},
		[9] = {costs = QBCore.Shared.Items["iron"]["label"] .. ": 60x, " ..QBCore.Shared.Items["glass"]["label"] .. ": 30x."},
		[10] = {costs = QBCore.Shared.Items["aluminum"]["label"] .. ": 60x, " ..QBCore.Shared.Items["glass"]["label"] .. ": 30x."},
		[11] = {costs = QBCore.Shared.Items["iron"]["label"] .. ": 33x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 44x, "..QBCore.Shared.Items["plastic"]["label"] .. ": 55x, "..QBCore.Shared.Items["aluminum"]["label"] .. ": 22x."},
		[12] = {costs = QBCore.Shared.Items["iron"]["label"] .. ": 50x, " ..QBCore.Shared.Items["steel"]["label"] .. ": 50x, "..QBCore.Shared.Items["screwdriverset"]["label"] .. ": 3x, "..QBCore.Shared.Items["advancedlockpick"]["label"] .. ": 2x."},
	}

	local items = {}
	for _, item in pairs(Config.CraftingItems) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		items[item.slot] = {
			name = itemInfo["name"],
			amount = tonumber(item.amount),
			info = itemInfos[item.slot],
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = item.slot,
			costs = item.costs,
			threshold = item.threshold,
			points = item.points,
		}
	end
	Config.CraftingItems = items
end

local function SetupAttachmentItemsInfo()
	itemInfos = {
		[1] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 140x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 250x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 60x"},
		[2] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 165x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 285x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 75x"},
		[3] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 190x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 305x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 85x, " .. QBCore.Shared.Items["smg_extendedclip"]["label"] .. ": 1x"},
		[4] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 205x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 340x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 110x, " .. QBCore.Shared.Items["smg_extendedclip"]["label"] .. ": 2x"},
		[5] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 230x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 365x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 130x"},
		[6] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 255x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 390x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 145x"},
		[7] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 270x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 435x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 155x"},
		[8] = {costs = QBCore.Shared.Items["metalscrap"]["label"] .. ": 300x, " .. QBCore.Shared.Items["steel"]["label"] .. ": 469x, " .. QBCore.Shared.Items["rubber"]["label"] .. ": 170x"},
	}

	local items = {}
	for _, item in pairs(Config.AttachmentCrafting["items"]) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		items[item.slot] = {
			name = itemInfo["name"],
			amount = tonumber(item.amount),
			info = itemInfos[item.slot],
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = item.slot,
			costs = item.costs,
			threshold = item.threshold,
			points = item.points,
		}
	end
	Config.AttachmentCrafting["items"] = items
end


local function GetThresholdItems()
	ItemsToItemInfo()
	local items = {}
	for k in pairs(Config.CraftingItems) do
		if PlayerData.metadata["craftingrep"] >= Config.CraftingItems[k].threshold then
			items[k] = Config.CraftingItems[k]
		end
	end
	return items
end


local function GetAttachmentThresholdItems()
	SetupAttachmentItemsInfo()
	local items = {}
	for k in pairs(Config.AttachmentCrafting["items"]) do
		if PlayerData.metadata["attachmentcraftingrep"] >= Config.AttachmentCrafting["items"][k].threshold then
			items[k] = Config.AttachmentCrafting["items"][k]
		end
	end
	return items
end

local function RemoveNearbyDrop(index)
    if not DropsNear[index] then return end

    local dropItem = DropsNear[index].object
    if DoesEntityExist(dropItem) then
        DeleteEntity(dropItem)
    end

    DropsNear[index] = nil

    if not Drops[index] then return end

    Drops[index].object = nil
    Drops[index].isDropShowing = nil
end

---Removes all drops in the area of the client
local function RemoveAllNearbyDrops()
    for k in pairs(DropsNear) do
        RemoveNearbyDrop(k)
    end
end


local function CreateItemDrop(index)
    local dropItem = CreateObject(Config.ItemDropObject, DropsNear[index].coords.x, DropsNear[index].coords.y, DropsNear[index].coords.z, false, false, false)
    DropsNear[index].object = dropItem
    DropsNear[index].isDropShowing = true
    PlaceObjectOnGroundProperly(dropItem)
    FreezeEntityPosition(dropItem, true)
	if Config.UseTarget then
		exports['qb-target']:AddTargetEntity(dropItem, {
			options = {
				{
					icon = 'fa-solid fa-bag-shopping',
					label = "Open Bag",
					action = function()
						TriggerServerEvent("inventory:server:OpenInventory", "drop", index)
					end,
				}
			},
			distance = 2.5,
		})
	end
end

-- Events

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set("inv_busy", false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback("inventory:server:GetCurrentDrops", function(theDrops)
		Drops = theDrops
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set("inv_busy", true, true)
    PlayerData = {}
    RemoveAllNearbyDrops()
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if Config.UseItemDrop then RemoveAllNearbyDrops() end
end)

RegisterNetEvent('inventory:client:CheckOpenState', function(type, id, label)
    local name = QBCore.Shared.SplitStr(label, "-")[2]
    if type == "stash" then
        if name ~= CurrentStash or CurrentStash == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "trunk" then
        if name ~= CurrentVehicle or CurrentVehicle == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "glovebox" then
        if name ~= CurrentGlovebox or CurrentGlovebox == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "drop" then
        if name ~= CurrentDrop or CurrentDrop == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    end
end)

RegisterNetEvent('inventory:client:ItemBox', function(itemData, type, amount)
    amount = amount or 1
    SendNUIMessage({
        action = "itemBox",
        item = itemData,
        type = type,
        itemAmount = amount
    })
end)

RegisterNetEvent('inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k in pairs(items) do
            itemTable[#itemTable+1] = {
                item = items[k].name,
                label = QBCore.Shared.Items[items[k].name]["label"],
                image = items[k].image,
            }
        end
    end

    SendNUIMessage({
        action = "requiredItem",
        items = itemTable,
        toggle = bool
    })
end)

RegisterNetEvent('inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = "RobMoney",
        TargetId = TargetId,
    })
end)

RegisterNetEvent('inventory:client:OpenInventory', function(PlayerAmmo, inventory, other)
    if not IsEntityDead(PlayerPedId()) then
        if Config.Progressbar.Enable then
            QBCore.Functions.Progressbar('open_inventory', 'Opening Inventory...', math.random(Config.Progressbar.minT, Config.Progressbar.maxT), false, true, { -- Name | Label | Time | useWhileDead | canCancel
                disableMovement = false,
                disableCarMovement = false,
                disableMouse = false,
                disableCombat = false,
            }, {}, {}, {}, function() -- Play When Done
                ToggleHotbar(false)
                if showBlur == true then
                    TriggerScreenblurFadeIn(1000)
                end
                SetNuiFocus(true, true)
                if other then
                    currentOtherInventory = other.name
                end
                SendNUIMessage({
                    action = "open",
                    inventory = inventory,
                    slots = Config.MaxInventorySlots,
                    other = other,
                    maxweight = Config.MaxInventoryWeight,
                    Ammo = PlayerAmmo,
                    maxammo = Config.MaximumAmmoValues,
                })
                inInventory = true
                end, function() -- Play When Cancel
            end)
        else
            Wait(500)
            ToggleHotbar(false)
            if showBlur == true then
                TriggerScreenblurFadeIn(1000)
            end
            SetNuiFocus(true, true)
            if other then
                currentOtherInventory = other.name
            end
            SendNUIMessage({
                action = "open",
                inventory = inventory,
                slots = Config.MaxInventorySlots,
                other = other,
                maxweight = Config.MaxInventoryWeight,
                Ammo = PlayerAmmo,
                maxammo = Config.MaximumAmmoValues,
            })
            inInventory = true
        end
    end
end)

RegisterNetEvent('inventory:client:UpdatePlayerInventory', function(isError)
    SendNUIMessage({
        action = "update",
        inventory = PlayerData.items,
        maxweight = Config.MaxInventoryWeight,
        slots = Config.MaxInventorySlots,
        error = isError,
    })
end)

RegisterNetEvent('inventory:client:CraftItems', function(itemName, itemCosts, amount, toSlot, points)
    local ped = PlayerPedId()
    SendNUIMessage({
        action = "close",
    })
    isCrafting = true
    QBCore.Functions.Progressbar("repair_vehicle", "Crafting..", (math.random(2000, 5000) * amount), false, true, {
		disableMovement = true,
		disableCarMovement = true,
		disableMouse = false,
		disableCombat = true,
	}, {
		animDict = "mini@repair",
		anim = "fixing_a_player",
		flags = 16,
	}, {}, {}, function() -- Done
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        TriggerServerEvent("inventory:server:CraftItems", itemName, itemCosts, amount, toSlot, points)
        TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'add')
        isCrafting = false
	end, function() -- Cancel
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        QBCore.Functions.Notify("Failed", "error")
        isCrafting = false
	end)
end)

RegisterNetEvent('inventory:client:CraftAttachment', function(itemName, itemCosts, amount, toSlot, points)
    local ped = PlayerPedId()
    SendNUIMessage({
        action = "close",
    })
    isCrafting = true
    QBCore.Functions.Progressbar("repair_vehicle", "Crafting..", (math.random(2000, 5000) * amount), false, true, {
		disableMovement = true,
		disableCarMovement = true,
		disableMouse = false,
		disableCombat = true,
	}, {
		animDict = "mini@repair",
		anim = "fixing_a_player",
		flags = 16,
	}, {}, {}, function() -- Done
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        TriggerServerEvent("inventory:server:CraftAttachment", itemName, itemCosts, amount, toSlot, points)
        TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'add')
        isCrafting = false
	end, function() -- Cancel
		StopAnimTask(ped, "mini@repair", "fixing_a_player", 1.0)
        QBCore.Functions.Notify("Failed", "error")
        isCrafting = false
	end)
end)

RegisterNetEvent('inventory:client:PickupSnowballs', function()
    local ped = PlayerPedId()
    LoadAnimDict('anim@mp_snowball')
    TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 3.0, 3.0, -1, 0, 1, 0, 0, 0)
    QBCore.Functions.Progressbar("pickupsnowball", "Collecting snowballs..", 1500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(ped)
        TriggerServerEvent('inventory:server:snowball', 'add')
        TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items["snowball"], "add")
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify("Canceled", "error")
    end)
end)

RegisterNetEvent('inventory:client:UseSnowball', function(amount)
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, `weapon_snowball`, amount, false, false)
    SetPedAmmo(ped, `weapon_snowball`, amount)
    SetCurrentPedWeapon(ped, `weapon_snowball`, true)
end)

RegisterNetEvent('inventory:client:UseWeapon', function(weaponData, shootbool)
    local ped = PlayerPedId()
    local weaponName = tostring(weaponData.name)
    local weaponHash = joaat(weaponData.name)
    local weaponinhand = GetCurrentPedWeapon(PlayerPedId())
    if currentWeapon == weaponName and weaponinhand then
        TriggerEvent('weapons:client:DrawWeapon', nil)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        RemoveAllPedWeapons(ped, true)
        TriggerEvent('weapons:client:SetCurrentWeapon', nil, shootbool)
        currentWeapon = nil
    elseif weaponName == "weapon_stickybomb" or weaponName == "weapon_pipebomb" or weaponName == "weapon_smokegrenade" or weaponName == "weapon_flare" or weaponName == "weapon_proxmine" or weaponName == "weapon_ball"  or weaponName == "weapon_molotov" or weaponName == "weapon_grenade" or weaponName == "weapon_bzgas" then
        TriggerEvent('weapons:client:DrawWeapon', weaponName)
        GiveWeaponToPed(ped, weaponHash, 1, false, false)
        SetPedAmmo(ped, weaponHash, 1)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    elseif weaponName == "weapon_snowball" then
        TriggerEvent('weapons:client:DrawWeapon', weaponName)
        GiveWeaponToPed(ped, weaponHash, 10, false, false)
        SetPedAmmo(ped, weaponHash, 10)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerServerEvent('inventory:server:snowball', 'remove')
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    else
        TriggerEvent('weapons:client:DrawWeapon', weaponName)
        TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, shootbool)
        local ammo = tonumber(weaponData.info.ammo) or 0

        if weaponName == "weapon_fireextinguisher" then
            ammo = 4000
        end

        GiveWeaponToPed(ped, weaponHash, ammo, false, false)
        SetPedAmmo(ped, weaponHash, ammo)
        SetCurrentPedWeapon(ped, weaponHash, true)

        if weaponData.info.attachments then
            for _, attachment in pairs(weaponData.info.attachments) do
                GiveWeaponComponentToPed(ped, weaponHash, joaat(attachment.component))
            end
        end

        currentWeapon = weaponName
    end
end)

RegisterNetEvent('inventory:client:CheckWeapon', function(weaponName)
    if currentWeapon ~= weaponName:lower() then return end
    local ped = PlayerPedId()
    TriggerEvent('weapons:ResetHolster')
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    RemoveAllPedWeapons(ped, true)
    currentWeapon = nil
end)

RegisterNetEvent('inventory:client:AddDropItem', function(dropId, player, coords)
    local forward = GetEntityForwardVector(GetPlayerPed(GetPlayerFromServerId(player)))
    local x, y, z = table.unpack(coords + forward * 0.5)
    Drops[dropId] = {
        id = dropId,
        coords = {
            x = x,
            y = y,
            z = z - 0.3,
        },
    }
end)

RegisterNetEvent('inventory:client:RemoveDropItem', function(dropId)
    Drops[dropId] = nil
    if Config.UseItemDrop then
        RemoveNearbyDrop(dropId)
    else
        DropsNear[dropId] = nil
    end
end)

RegisterNetEvent('inventory:client:DropItemAnim', function()
    local ped = PlayerPedId()
    SendNUIMessage({
        action = "close",
    })
    RequestAnimDict("pickup_object")
    while not HasAnimDictLoaded("pickup_object") do
        Wait(7)
    end
    TaskPlayAnim(ped, "pickup_object" ,"pickup_low" ,8.0, -8.0, -1, 1, 0, false, false, false )
    Wait(2000)
    ClearPedTasks(ped)
end)

RegisterNetEvent('inventory:client:SetCurrentStash', function(stash)
    CurrentStash = stash
end)


RegisterNetEvent('inventory:client:craftTarget',function()
    local crafting = {}
    crafting.label = "Crafting"
    crafting.items = GetThresholdItems()
    TriggerServerEvent("inventory:server:OpenInventory", "crafting", math.random(1, 99), crafting)
end)

-- Commands

RegisterCommand('closeinv', function()
    closeInventory()
end, false)

RegisterNetEvent("qb-inventory:client:closeinv", function()
    closeInventory()
end)

RegisterCommand('inventory', function()
    if IsNuiFocused() then return end
    if not isCrafting and not inInventory then
        if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
            local ped = PlayerPedId()
            local curVeh = nil
            local VendingMachine = nil
            if not Config.UseTarget then VendingMachine = GetClosestVending() end

            if IsPedInAnyVehicle(ped, false) then -- Is Player In Vehicle
                local vehicle = GetVehiclePedIsIn(ped, false)
                CurrentGlovebox = QBCore.Functions.GetPlate(vehicle)
                curVeh = vehicle
                CurrentVehicle = nil
            else
                local vehicle = QBCore.Functions.GetClosestVehicle()
                if vehicle ~= 0 and vehicle ~= nil then
                    local pos = GetEntityCoords(ped)
					          local dimensionMin, dimensionMax = GetModelDimensions(GetEntityModel(vehicle))
					          local trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, (dimensionMin.y), 0.0)
                    if (IsBackEngine(GetEntityModel(vehicle))) then
                        trunkpos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, (dimensionMax.y), 0.0)
                    end
                    if #(pos - trunkpos) < 1.5 and not IsPedInAnyVehicle(ped) then
                        if GetVehicleDoorLockStatus(vehicle) < 2 then
                            CurrentVehicle = QBCore.Functions.GetPlate(vehicle)
                            curVeh = vehicle
                            CurrentGlovebox = nil
                        else
                            QBCore.Functions.Notify("Vehicle locked.", "error")
                            return
                        end
                    else
                        CurrentVehicle = nil
                    end
                else
                    CurrentVehicle = nil
                end
            end

            if CurrentVehicle then -- Trunk
                local vehicleClass = GetVehicleClass(curVeh)
                local maxweight
                local slots
                if vehicleClass == 0 then
                    maxweight = 38000
                    slots = 30
                elseif vehicleClass == 1 then
                    maxweight = 50000
                    slots = 40
                elseif vehicleClass == 2 then
                    maxweight = 75000
                    slots = 50
                elseif vehicleClass == 3 then
                    maxweight = 42000
                    slots = 35
                elseif vehicleClass == 4 then
                    maxweight = 38000
                    slots = 30
                elseif vehicleClass == 5 then
                    maxweight = 30000
                    slots = 25
                elseif vehicleClass == 6 then
                    maxweight = 30000
                    slots = 25
                elseif vehicleClass == 7 then
                    maxweight = 30000
                    slots = 25
                elseif vehicleClass == 8 then
                    maxweight = 15000
                    slots = 15
                elseif vehicleClass == 9 then
                    maxweight = 60000
                    slots = 35
                elseif vehicleClass == 12 then
                    maxweight = 120000
                    slots = 35
                elseif vehicleClass == 13 then
                    maxweight = 0
                    slots = 0
                elseif vehicleClass == 14 then
                    maxweight = 120000
                    slots = 50
                elseif vehicleClass == 15 then
                    maxweight = 120000
                    slots = 50
                elseif vehicleClass == 16 then
                    maxweight = 120000
                    slots = 50
                else
                    maxweight = 60000
                    slots = 35
                end
                local other = {
                    maxweight = maxweight,
                    slots = slots,
                }
                TriggerServerEvent("inventory:server:OpenInventory", "trunk", CurrentVehicle, other)
                OpenTrunk()
            elseif CurrentGlovebox then
                TriggerServerEvent("inventory:server:OpenInventory", "glovebox", CurrentGlovebox)
            elseif CurrentDrop ~= 0 then
                TriggerServerEvent("inventory:server:OpenInventory", "drop", CurrentDrop)
            elseif VendingMachine then
                local ShopItems = {}
                ShopItems.label = "Vending Machine"
                ShopItems.items = Config.VendingItem
                ShopItems.slots = #Config.VendingItem
                TriggerServerEvent("inventory:server:OpenInventory", "shop", "Vendingshop_"..math.random(1, 99), ShopItems)
            else
                openAnim()
                TriggerServerEvent("inventory:server:OpenInventory")
            end
        end
    end
end, false)

RegisterKeyMapping('inventory', 'Open Inventory', 'keyboard', 'TAB')

RegisterCommand('hotbar', function()
    isHotbar = not isHotbar
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
        ToggleHotbar(isHotbar)
    end
end)

RegisterKeyMapping('hotbar', 'Toggles keybind slots', 'keyboard', 'z')

for i = 1, 6 do
    RegisterCommand('slot' .. i,function()
        if not PlayerData.metadata["isdead"] and not PlayerData.metadata["inlaststand"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() and not LocalPlayer.state.inv_busy then
            if i == 6 then
                i = Config.MaxInventorySlots
            end
            TriggerServerEvent("inventory:server:UseItemSlot", i)
        end
    end, false)
    RegisterKeyMapping('slot' .. i, 'Uses the item in slot ' .. i, 'keyboard', i)
end

RegisterNetEvent('qb-inventory:client:giveAnim', function()
    LoadAnimDict('mp_common')
	TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, 0, 0, 0)
end)

-- NUI

RegisterNUICallback('RobMoney', function(data, cb)
    TriggerServerEvent("police:server:RobPlayer", data.TargetId)
    cb('ok')
end)

RegisterNUICallback('Notify', function(data, cb)
    QBCore.Functions.Notify(data.message, data.type)
    cb('ok')
end)

RegisterNUICallback('GetWeaponData', function(cData, cb)
    local data = {
        WeaponData = QBCore.Shared.Items[cData.weapon],
        AttachmentData = FormatWeaponAttachments(cData.ItemData)
    }
    cb(data)
end)

RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = QBCore.Shared.Items[data.WeaponData.name]
    print(data.AttachmentData.attachment:gsub("(.*).*_",''))
    data.AttachmentData.attachment = data.AttachmentData.attachment:gsub("(.*).*_",'')
    QBCore.Functions.TriggerCallback('weapons:server:RemoveAttachment', function(NewAttachments)
        if NewAttachments ~= false then
            local attachments = {}
            RemoveWeaponComponentFromPed(ped, GetHashKey(data.WeaponData.name), GetHashKey(data.AttachmentData.component))
            for _, v in pairs(NewAttachments) do
                attachments[#attachments+1] = {
                    attachment = v.item,
                    label = v.label,
                    image = QBCore.Shared.Items[v.item].image
                }
            end
            local DJATA = {
                Attachments = attachments,
                WeaponData = WeaponData,
            }
            cb(DJATA)
        else
            RemoveWeaponComponentFromPed(ped, GetHashKey(data.WeaponData.name), GetHashKey(data.AttachmentData.component))
            cb({})
        end
    end, data.AttachmentData, data.WeaponData)
end)

RegisterNUICallback('getCombineItem', function(data, cb)
    cb(QBCore.Shared.Items[data.item])
end)

RegisterNUICallback("CloseInventory", function()
    if currentOtherInventory == "none-inv" then
        CurrentDrop = nil
        CurrentVehicle = nil
        CurrentGlovebox = nil
        CurrentStash = nil
        SetNuiFocus(false, false)
        inInventory = false
        TriggerScreenblurFadeOut(1000)
        ClearPedTasks(PlayerPedId())
        return
    end
    if CurrentVehicle ~= nil then
        CloseTrunk()
        TriggerServerEvent("inventory:server:SaveInventory", "trunk", CurrentVehicle)
        CurrentVehicle = nil
    elseif CurrentGlovebox ~= nil then
        TriggerServerEvent("inventory:server:SaveInventory", "glovebox", CurrentGlovebox)
        CurrentGlovebox = nil
    elseif CurrentStash ~= nil then
        TriggerServerEvent("inventory:server:SaveInventory", "stash", CurrentStash)
        CurrentStash = nil
    else
        TriggerServerEvent("inventory:server:SaveInventory", "drop", CurrentDrop)
        CurrentDrop = nil
    end
    Wait(50)
    TriggerScreenblurFadeOut(1000)
    SetNuiFocus(false, false)
    inInventory = false
end)

RegisterNUICallback("UseItem", function(data, cb)
    TriggerServerEvent("inventory:server:UseItem", data.inventory, data.item)
    cb('ok')
end)

RegisterNUICallback("combineItem", function(data, cb)
    Wait(150)
    TriggerServerEvent('inventory:server:combineItem', data.reward, data.fromItem, data.toItem)
    cb('ok')
end)

RegisterNUICallback('combineWithAnim', function(data, cb)
    local ped = PlayerPedId()
    local combineData = data.combineData
    local aDict = combineData.anim.dict
    local aLib = combineData.anim.lib
    local animText = combineData.anim.text
    local animTimeout = combineData.anim.timeOut
    QBCore.Functions.Progressbar("combine_anim", animText, animTimeout, false, true, {
        disableMovement = false,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = aDict,
        anim = aLib,
        flags = 16,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, aDict, aLib, 1.0)
        TriggerServerEvent('inventory:server:combineItem', combineData.reward, data.requiredItem, data.usedItem)
    end, function() -- Cancel
        StopAnimTask(ped, aDict, aLib, 1.0)
        QBCore.Functions.Notify("Failed", "error")
    end)
    cb('ok')
end)

RegisterNUICallback("SetInventoryData", function(data, cb)
    TriggerServerEvent("inventory:server:SetInventoryData", data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

RegisterNUICallback("PlayDropSound", function(_, cb)
    PlaySound(-1, "CLICK_BACK", "WEB_NAVIGATION_SOUNDS_PHONE", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback("PlayDropFail", function(_, cb)
    PlaySound(-1, "Place_Prop_Fail", "DLC_Dmod_Prop_Editor_Sounds", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback("GiveItem", function(data, cb)
    local player, distance = QBCore.Functions.GetClosestPlayer(GetEntityCoords(PlayerPedId()))
    if player ~= -1 and distance < 3 then
        if data.inventory == 'player' then
            local playerId = GetPlayerServerId(player)
            SetCurrentPedWeapon(PlayerPedId(),'WEAPON_UNARMED',true)
            TriggerServerEvent("inventory:server:GiveItem", playerId, data.item.name, data.amount, data.item.slot)
        else
            QBCore.Functions.Notify("You do not own this item!", "error")
        end
    else
        QBCore.Functions.Notify("No one nearby!", "error")
    end
    cb('ok')
end)


-- Threads

CreateThread(function()
    while true do
        local sleep = 100
        if DropsNear ~= nil then
			local ped = PlayerPedId()
			local closestDrop = nil
			local closestDistance = nil
            for k, v in pairs(DropsNear) do

                if DropsNear[k] ~= nil then
                    if Config.UseItemDrop then
                        if not v.isDropShowing then
                            CreateItemDrop(k)
                        end
                    else
                        sleep = 0
                        DrawMarker(20, v.coords.x, v.coords.y, v.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.15, 120, 10, 20, 155, false, false, false, 1, false, false, false)
                    end

					local coords = (v.object ~= nil and GetEntityCoords(v.object)) or vector3(v.coords.x, v.coords.y, v.coords.z)
					local distance = #(GetEntityCoords(ped) - coords)
					if distance < 2 and (not closestDistance or distance < closestDistance) then
						closestDrop = k
						closestDistance = distance
					end
                end
            end


			if not closestDrop then
				CurrentDrop = 0
			else
				CurrentDrop = closestDrop
			end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if Drops ~= nil and next(Drops) ~= nil then
            local pos = GetEntityCoords(PlayerPedId(), true)
            for k, v in pairs(Drops) do
                if Drops[k] ~= nil then
                    local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                    if dist < Config.MaxDropViewDistance then
                        DropsNear[k] = v
                    else
                        if Config.UseItemDrop and DropsNear[k] then
                            RemoveNearbyDrop(k)
                        else
                            DropsNear[k] = nil
                        end
                    end
                end
            end
        else
            DropsNear = {}
        end
        Wait(500)
    end
end)


    --qb-target
    RegisterNetEvent("inventory:client:Crafting", function(dropId)
        local crafting = {}
        crafting.label = "Crafting"
        crafting.items = GetThresholdItems()
        TriggerServerEvent("inventory:server:OpenInventory", "crafting", math.random(1, 99), crafting)
    end)
    
    
    RegisterNetEvent("inventory:client:WeaponAttachmentCrafting", function(dropId)
        local crafting = {}
        crafting.label = "Attachment Crafting"
        crafting.items = GetAttachmentThresholdItems()
        TriggerServerEvent("inventory:server:OpenInventory", "attachment_crafting", math.random(1, 99), crafting)
    end)
    
    local toolBoxModels = {
        `prop_toolchest_05`,
        `prop_tool_bench02_ld`,
        `prop_tool_bench02`,
        `prop_toolchest_02`,
        `prop_toolchest_03`,
        `prop_toolchest_03_l2`,
        `prop_toolchest_05`,
        `prop_toolchest_04`,
    }
    exports['qb-target']:AddTargetModel(toolBoxModels, {
            options = {
                {
                    event = "inventory:client:WeaponAttachmentCrafting",
                    icon = "fas fa-wrench",
                    label = "Weapon Attachment Crafting", 
                },
                {
                    event = "inventory:client:Crafting",
                    icon = "fas fa-wrench",
                    label = "Item Crafting", 
                },
            },
        distance = 1.0
    })
