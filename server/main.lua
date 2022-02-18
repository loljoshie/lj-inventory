-- Variables

local QBCore = exports['qb-core']:GetCoreObject()
local Drops = {}
local Trunks = {}
local Gloveboxes = {}
local Stashes = {}
local ShopItems = {}

-- Functions

local function recipeContains(recipe, fromItem)
	for k, v in pairs(recipe.accept) do
		if v == fromItem.name then
			return true
		end
	end

	return false
end

local function hasCraftItems(source, CostItems, amount)
	local Player = QBCore.Functions.GetPlayer(source)
	for k, v in pairs(CostItems) do
		if Player.Functions.GetItemByName(k) ~= nil then
			if Player.Functions.GetItemByName(k).amount < (v * amount) then
				return false
			end
		else
			return false
		end
	end
	return true
end

local function IsVehicleOwned(plate)
    local result = MySQL.Sync.fetchScalar('SELECT 1 from player_vehicles WHERE plate = ?', {plate})
    if result then return true else return false end
end

-- Shop Items
local function SetupShopItems(shop, shopItems)
	local items = {}
	if shopItems ~= nil and next(shopItems) ~= nil then
		for k, item in pairs(shopItems) do
			local itemInfo = QBCore.Shared.Items[item.name:lower()]
			if itemInfo then
				items[item.slot] = {
					name = itemInfo["name"],
					amount = tonumber(item.amount),
					info = item.info ~= nil and item.info or "",
					label = itemInfo["label"],
					description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
					weight = itemInfo["weight"],
					type = itemInfo["type"],
					unique = itemInfo["unique"],
					useable = itemInfo["useable"],
					price = item.price,
					image = itemInfo["image"],
					slot = item.slot,
				}
			end
		end
	end
	return items
end

-- Stash Items
local function GetStashItems(stashId)
	local items = {}
	local result = MySQL.Sync.fetchScalar('SELECT items FROM stashitems WHERE stash = ?', {stashId})
	if result then
		local stashItems = json.decode(result)
		if stashItems then
			for k, item in pairs(stashItems) do
				local itemInfo = QBCore.Shared.Items[item.name:lower()]
				if itemInfo then
					items[item.slot] = {
						name = itemInfo["name"],
						amount = tonumber(item.amount),
						info = item.info ~= nil and item.info or "",
						label = itemInfo["label"],
						description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
						weight = itemInfo["weight"],
						type = itemInfo["type"],
						unique = itemInfo["unique"],
						useable = itemInfo["useable"],
						image = itemInfo["image"],
						slot = item.slot,
					}
				end
			end
		end
	end
	return items
end

local function SaveStashItems(stashId, items)
	if Stashes[stashId].label ~= "Stash-None" then
		if items ~= nil then
			for slot, item in pairs(items) do
				item.description = nil
			end
			MySQL.Async.insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
				['stash'] = stashId,
				['items'] = json.encode(items)
			})
			Stashes[stashId].isOpen = false
		end
	end
end

local function AddToStash(stashId, slot, otherslot, itemName, amount, info)
	local amount = tonumber(amount)
	local ItemData = QBCore.Shared.Items[itemName]
	if not ItemData.unique then
		if Stashes[stashId].items[slot] ~= nil and Stashes[stashId].items[slot].name == itemName then
			Stashes[stashId].items[slot].amount = Stashes[stashId].items[slot].amount + amount
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Stashes[stashId].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	else
		if Stashes[stashId].items[slot] ~= nil and Stashes[stashId].items[slot].name == itemName then
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Stashes[stashId].items[otherslot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = otherslot,
			}
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Stashes[stashId].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	end
end

local function RemoveFromStash(stashId, slot, itemName, amount)
	local amount = tonumber(amount)
	if Stashes[stashId].items[slot] ~= nil and Stashes[stashId].items[slot].name == itemName then
		if Stashes[stashId].items[slot].amount > amount then
			Stashes[stashId].items[slot].amount = Stashes[stashId].items[slot].amount - amount
		else
			Stashes[stashId].items[slot] = nil
			if next(Stashes[stashId].items) == nil then
				Stashes[stashId].items = {}
			end
		end
	else
		Stashes[stashId].items[slot] = nil
		if Stashes[stashId].items == nil then
			Stashes[stashId].items[slot] = nil
		end
	end
end

-- Trunk items
local function GetOwnedVehicleItems(plate)
	local items = {}
	local result = MySQL.Sync.fetchScalar('SELECT items FROM trunkitems WHERE plate = ?', {plate})
	if result then
		local trunkItems = json.decode(result)
		if trunkItems then
			for k, item in pairs(trunkItems) do
				local itemInfo = QBCore.Shared.Items[item.name:lower()]
				if itemInfo then
					items[item.slot] = {
						name = itemInfo["name"],
						amount = tonumber(item.amount),
						info = item.info ~= nil and item.info or "",
						label = itemInfo["label"],
						description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
						weight = itemInfo["weight"],
						type = itemInfo["type"],
						unique = itemInfo["unique"],
						useable = itemInfo["useable"],
						image = itemInfo["image"],
						slot = item.slot,
					}
				end
			end
		end
	end
	return items
end

local function SaveOwnedVehicleItems(plate, items)
	if Trunks[plate].label ~= "Trunk-None" then
		if items ~= nil then
			for slot, item in pairs(items) do
				item.description = nil
			end
			MySQL.Async.insert('INSERT INTO trunkitems (plate, items) VALUES (:plate, :items) ON DUPLICATE KEY UPDATE items = :items', {
				['plate'] = plate,
				['items'] = json.encode(items)
			})
			Trunks[plate].isOpen = false
		end
	end
end

local function AddToTrunk(plate, slot, otherslot, itemName, amount, info)
	local amount = tonumber(amount)
	local ItemData = QBCore.Shared.Items[itemName]

	if not ItemData.unique then
		if Trunks[plate].items[slot] ~= nil and Trunks[plate].items[slot].name == itemName then
			Trunks[plate].items[slot].amount = Trunks[plate].items[slot].amount + amount
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Trunks[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	else
		if Trunks[plate].items[slot] ~= nil and Trunks[plate].items[slot].name == itemName then
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Trunks[plate].items[otherslot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = otherslot,
			}
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Trunks[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	end
end

local function RemoveFromTrunk(plate, slot, itemName, amount)
	if Trunks[plate].items[slot] ~= nil and Trunks[plate].items[slot].name == itemName then
		if Trunks[plate].items[slot].amount > amount then
			Trunks[plate].items[slot].amount = Trunks[plate].items[slot].amount - amount
		else
			Trunks[plate].items[slot] = nil
			if next(Trunks[plate].items) == nil then
				Trunks[plate].items = {}
			end
		end
	else
		Trunks[plate].items[slot]= nil
		if Trunks[plate].items == nil then
			Trunks[plate].items[slot] = nil
		end
	end
end

-- Glovebox items
local function GetOwnedVehicleGloveboxItems(plate)
	local items = {}
	local result = MySQL.Sync.fetchScalar('SELECT items FROM gloveboxitems WHERE plate = ?', {plate})
	if result then
		local gloveboxItems = json.decode(result)
		if gloveboxItems then
			for k, item in pairs(gloveboxItems) do
				local itemInfo = QBCore.Shared.Items[item.name:lower()]
				if itemInfo then
					items[item.slot] = {
						name = itemInfo["name"],
						amount = tonumber(item.amount),
						info = item.info ~= nil and item.info or "",
						label = itemInfo["label"],
						description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
						weight = itemInfo["weight"],
						type = itemInfo["type"],
						unique = itemInfo["unique"],
						useable = itemInfo["useable"],
						image = itemInfo["image"],
						slot = item.slot,
					}
				end
			end
		end
	end
	return items
end

local function SaveOwnedGloveboxItems(plate, items)
	if Gloveboxes[plate].label ~= "Glovebox-None" then
		if items ~= nil then
			for slot, item in pairs(items) do
				item.description = nil
			end
			MySQL.Async.insert('INSERT INTO gloveboxitems (plate, items) VALUES (:plate, :items) ON DUPLICATE KEY UPDATE items = :items', {
				['plate'] = plate,
				['items'] = json.encode(items)
			})
			Gloveboxes[plate].isOpen = false
		end
	end
end

local function AddToGlovebox(plate, slot, otherslot, itemName, amount, info)
	local amount = tonumber(amount)
	local ItemData = QBCore.Shared.Items[itemName]

	if not ItemData.unique then
		if Gloveboxes[plate].items[slot] ~= nil and Gloveboxes[plate].items[slot].name == itemName then
			Gloveboxes[plate].items[slot].amount = Gloveboxes[plate].items[slot].amount + amount
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Gloveboxes[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	else
		if Gloveboxes[plate].items[slot] ~= nil and Gloveboxes[plate].items[slot].name == itemName then
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Gloveboxes[plate].items[otherslot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = otherslot,
			}
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Gloveboxes[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info ~= nil and info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	end
end

local function RemoveFromGlovebox(plate, slot, itemName, amount)
	if Gloveboxes[plate].items[slot] ~= nil and Gloveboxes[plate].items[slot].name == itemName then
		if Gloveboxes[plate].items[slot].amount > amount then
			Gloveboxes[plate].items[slot].amount = Gloveboxes[plate].items[slot].amount - amount
		else
			Gloveboxes[plate].items[slot] = nil
			if next(Gloveboxes[plate].items) == nil then
				Gloveboxes[plate].items = {}
			end
		end
	else
		Gloveboxes[plate].items[slot]= nil
		if Gloveboxes[plate].items == nil then
			Gloveboxes[plate].items[slot] = nil
		end
	end
end

-- Drop items
local function AddToDrop(dropId, slot, itemName, amount, info)
	local amount = tonumber(amount)
	if Drops[dropId].items[slot] ~= nil and Drops[dropId].items[slot].name == itemName then
		Drops[dropId].items[slot].amount = Drops[dropId].items[slot].amount + amount
	else
		local itemInfo = QBCore.Shared.Items[itemName:lower()]
		Drops[dropId].items[slot] = {
			name = itemInfo["name"],
			amount = amount,
			info = info ~= nil and info or "",
			label = itemInfo["label"],
			description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = slot,
			id = dropId,
		}
	end
end

local function RemoveFromDrop(dropId, slot, itemName, amount)
	if Drops[dropId].items[slot] ~= nil and Drops[dropId].items[slot].name == itemName then
		if Drops[dropId].items[slot].amount > amount then
			Drops[dropId].items[slot].amount = Drops[dropId].items[slot].amount - amount
		else
			Drops[dropId].items[slot] = nil
			if next(Drops[dropId].items) == nil then
				Drops[dropId].items = {}
				--TriggerClientEvent("inventory:client:RemoveDropItem", -1, dropId)
			end
		end
	else
		Drops[dropId].items[slot] = nil
		if Drops[dropId].items == nil then
			Drops[dropId].items[slot] = nil
			--TriggerClientEvent("inventory:client:RemoveDropItem", -1, dropId)
		end
	end
end

local function CreateDropId()
	if Drops ~= nil then
		local id = math.random(10000, 99999)
		local dropid = id
		while Drops[dropid] ~= nil do
			id = math.random(10000, 99999)
			dropid = id
		end
		return dropid
	else
		local id = math.random(10000, 99999)
		local dropid = id
		return dropid
	end
end

local function CreateNewDrop(source, fromSlot, toSlot, itemAmount)
	local Player = QBCore.Functions.GetPlayer(source)
	local itemData = Player.Functions.GetItemBySlot(fromSlot)
	local coords = GetEntityCoords(GetPlayerPed(source))
	if Player.Functions.RemoveItem(itemData.name, itemAmount, itemData.slot) then
		TriggerClientEvent("inventory:client:CheckWeapon", source, itemData.name)
		local itemInfo = QBCore.Shared.Items[itemData.name:lower()]
		local dropId = CreateDropId()
		Drops[dropId] = {}
		Drops[dropId].items = {}

		Drops[dropId].items[toSlot] = {
			name = itemInfo["name"],
			amount = itemAmount,
			info = itemData.info ~= nil and itemData.info or "",
			label = itemInfo["label"],
			description = itemInfo["description"] ~= nil and itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = toSlot,
			id = dropId,
		}
		TriggerEvent("qb-log:server:CreateLog", "drop", "New Item Drop", "red", "**".. GetPlayerName(source) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..source.."*) dropped new item; name: **"..itemData.name.."**, amount: **" .. itemAmount .. "**")
		TriggerClientEvent("inventory:client:DropItemAnim", source)
		TriggerClientEvent("inventory:client:AddDropItem", -1, dropId, source, coords)
		if itemData.name:lower() == "radio" then
			TriggerClientEvent('Radio.Set', source, false)
		end
	else
		TriggerClientEvent("QBCore:Notify", source, "You don't have this item!", "error")
		return
	end
end

-- Events

RegisterNetEvent('inventory:server:addTrunkItems', function(plate, items)
	Trunks[plate] = {}
	Trunks[plate].items = items
end)

RegisterNetEvent('inventory:server:combineItem', function(item, fromItem, toItem)
	local src = source
	local ply = QBCore.Functions.GetPlayer(src)

	-- Check that inputs are not nil
	-- Most commonly when abusing this exploit, this values are left as
	if fromItem == nil  then return end
	if toItem == nil then return end

	-- Check that they have the items
	local fromItem = ply.Functions.GetItemByName(fromItem)
	local toItem = ply.Functions.GetItemByName(toItem)

	if fromItem == nil  then return end
	if toItem == nil then return end

	-- Check the recipe is valid
	local recipe = QBCore.Shared.Items[toItem.name].combinable

	if recipe and recipe.reward ~= item then return end
	if not recipeContains(recipe, fromItem) then return end

	TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
	ply.Functions.AddItem(item, 1)
	ply.Functions.RemoveItem(fromItem.name, 1)
	ply.Functions.RemoveItem(toItem.name, 1)
end)

RegisterNetEvent('inventory:server:CraftItems', function(itemName, itemCosts, amount, toSlot, points)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local amount = tonumber(amount)
	if itemName ~= nil and itemCosts ~= nil then
		for k, v in pairs(itemCosts) do
			Player.Functions.RemoveItem(k, (v*amount))
		end
		Player.Functions.AddItem(itemName, amount, toSlot)
		Player.Functions.SetMetaData("craftingrep", Player.PlayerData.metadata["craftingrep"]+(points*amount))
		TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
	end
end)

RegisterNetEvent('inventory:server:CraftAttachment', function(itemName, itemCosts, amount, toSlot, points)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local amount = tonumber(amount)
	if itemName ~= nil and itemCosts ~= nil then
		for k, v in pairs(itemCosts) do
			Player.Functions.RemoveItem(k, (v*amount))
		end
		Player.Functions.AddItem(itemName, amount, toSlot)
		Player.Functions.SetMetaData("attachmentcraftingrep", Player.PlayerData.metadata["attachmentcraftingrep"]+(points*amount))
		TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
	end
end)

RegisterNetEvent('inventory:server:SetIsOpenState', function(IsOpen, type, id)
	if not IsOpen then
		if type == "stash" then
			Stashes[id].isOpen = false
		elseif type == "trunk" then
			Trunks[id].isOpen = false
		elseif type == "glovebox" then
			Gloveboxes[id].isOpen = false
		end
	end
end)

RegisterNetEvent('inventory:server:OpenInventory', function(name, id, other)
	local src = source
	local ply = Player(src)
	local Player = QBCore.Functions.GetPlayer(src)
	if not ply.state.inv_busy then
		if name ~= nil and id ~= nil then
			local secondInv = {}
			if name == "stash" then
				if Stashes[id] ~= nil then
					if Stashes[id].isOpen then
						local Target = QBCore.Functions.GetPlayer(Stashes[id].isOpen)
						if Target ~= nil then
							TriggerClientEvent('inventory:client:CheckOpenState', Stashes[id].isOpen, name, id, Stashes[id].label)
						else
							Stashes[id].isOpen = false
						end
					end
				end
				local maxweight = 1000000
				local slots = 50
				if other ~= nil then
					maxweight = other.maxweight ~= nil and other.maxweight or 1000000
					slots = other.slots ~= nil and other.slots or 50
				end
				secondInv.name = "stash-"..id
				secondInv.label = "Stash-"..id
				secondInv.maxweight = maxweight
				secondInv.inventory = {}
				secondInv.slots = slots
				if Stashes[id] ~= nil and Stashes[id].isOpen then
					secondInv.name = "none-inv"
					secondInv.label = "Stash-None"
					secondInv.maxweight = 1000000
					secondInv.inventory = {}
					secondInv.slots = 0
				else
					local stashItems = GetStashItems(id)
					if next(stashItems) ~= nil then
						secondInv.inventory = stashItems
						Stashes[id] = {}
						Stashes[id].items = stashItems
						Stashes[id].isOpen = src
						Stashes[id].label = secondInv.label
					else
						Stashes[id] = {}
						Stashes[id].items = {}
						Stashes[id].isOpen = src
						Stashes[id].label = secondInv.label
					end
				end
			elseif name == "trunk" then
				if Trunks[id] ~= nil then
					if Trunks[id].isOpen then
						local Target = QBCore.Functions.GetPlayer(Trunks[id].isOpen)
						if Target ~= nil then
							TriggerClientEvent('inventory:client:CheckOpenState', Trunks[id].isOpen, name, id, Trunks[id].label)
						else
							Trunks[id].isOpen = false
						end
					end
				end
				secondInv.name = "trunk-"..id
				secondInv.label = "Trunk-"..id
				secondInv.maxweight = other.maxweight ~= nil and other.maxweight or 60000
				secondInv.inventory = {}
				secondInv.slots = other.slots ~= nil and other.slots or 50
				if (Trunks[id] ~= nil and Trunks[id].isOpen) or (QBCore.Shared.SplitStr(id, "PLZI")[2] ~= nil and Player.PlayerData.job.name ~= "police") then
					secondInv.name = "none-inv"
					secondInv.label = "Trunk-None"
					secondInv.maxweight = other.maxweight ~= nil and other.maxweight or 60000
					secondInv.inventory = {}
					secondInv.slots = 0
				else
					if id ~= nil then
						local ownedItems = GetOwnedVehicleItems(id)
						if IsVehicleOwned(id) and next(ownedItems) ~= nil then
							secondInv.inventory = ownedItems
							Trunks[id] = {}
							Trunks[id].items = ownedItems
							Trunks[id].isOpen = src
							Trunks[id].label = secondInv.label
						elseif Trunks[id] ~= nil and not Trunks[id].isOpen then
							secondInv.inventory = Trunks[id].items
							Trunks[id].isOpen = src
							Trunks[id].label = secondInv.label
						else
							Trunks[id] = {}
							Trunks[id].items = {}
							Trunks[id].isOpen = src
							Trunks[id].label = secondInv.label
						end
					end
				end
			elseif name == "glovebox" then
				if Gloveboxes[id] ~= nil then
					if Gloveboxes[id].isOpen then
						local Target = QBCore.Functions.GetPlayer(Gloveboxes[id].isOpen)
						if Target ~= nil then
							TriggerClientEvent('inventory:client:CheckOpenState', Gloveboxes[id].isOpen, name, id, Gloveboxes[id].label)
						else
							Gloveboxes[id].isOpen = false
						end
					end
				end
				secondInv.name = "glovebox-"..id
				secondInv.label = "Glovebox-"..id
				secondInv.maxweight = 10000
				secondInv.inventory = {}
				secondInv.slots = 5
				if Gloveboxes[id] ~= nil and Gloveboxes[id].isOpen then
					secondInv.name = "none-inv"
					secondInv.label = "Glovebox-None"
					secondInv.maxweight = 10000
					secondInv.inventory = {}
					secondInv.slots = 0
				else
					local ownedItems = GetOwnedVehicleGloveboxItems(id)
					if Gloveboxes[id] ~= nil and not Gloveboxes[id].isOpen then
						secondInv.inventory = Gloveboxes[id].items
						Gloveboxes[id].isOpen = src
						Gloveboxes[id].label = secondInv.label
					elseif IsVehicleOwned(id) and next(ownedItems) ~= nil then
						secondInv.inventory = ownedItems
						Gloveboxes[id] = {}
						Gloveboxes[id].items = ownedItems
						Gloveboxes[id].isOpen = src
						Gloveboxes[id].label = secondInv.label
					else
						Gloveboxes[id] = {}
						Gloveboxes[id].items = {}
						Gloveboxes[id].isOpen = src
						Gloveboxes[id].label = secondInv.label
					end
				end
			elseif name == "shop" then
				secondInv.name = "itemshop-"..id
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = SetupShopItems(id, other.items)
				ShopItems[id] = {}
				ShopItems[id].items = other.items
				secondInv.slots = #other.items
			elseif name == "traphouse" then
				secondInv.name = "traphouse-"..id
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = other.slots
			elseif name == "crafting" then
				secondInv.name = "crafting"
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = #other.items
			elseif name == "attachment_crafting" then
				secondInv.name = "attachment_crafting"
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = #other.items
			elseif name == "otherplayer" then
				local OtherPlayer = QBCore.Functions.GetPlayer(tonumber(id))
				if OtherPlayer ~= nil then
					secondInv.name = "otherplayer-"..id
					secondInv.label = "Player-"..id
					secondInv.maxweight = QBCore.Config.Player.MaxWeight
					secondInv.inventory = OtherPlayer.PlayerData.items
					if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
						secondInv.slots = QBCore.Config.Player.MaxInvSlots
					else
						secondInv.slots = QBCore.Config.Player.MaxInvSlots - 1
					end
					Wait(250)
				end
			else
				if Drops[id] ~= nil and not Drops[id].isOpen then
					secondInv.name = id
					secondInv.label = "Dropped-"..tostring(id)
					secondInv.maxweight = 100000
					secondInv.inventory = Drops[id].items
					secondInv.slots = 30
					Drops[id].isOpen = src
					Drops[id].label = secondInv.label
				else
					secondInv.name = "none-inv"
					secondInv.label = "Dropped-None"
					secondInv.maxweight = 100000
					secondInv.inventory = {}
					secondInv.slots = 0
					--Drops[id].label = secondInv.label
				end
			end
			TriggerClientEvent("inventory:client:OpenInventory", src, {}, Player.PlayerData.items, secondInv)
		else
			TriggerClientEvent("inventory:client:OpenInventory", src, {}, Player.PlayerData.items)
		end
	else
		TriggerClientEvent('QBCore:Notify', src, 'Not Accessible', 'error')
	end
end)

RegisterNetEvent('inventory:server:SaveInventory', function(type, id)
	if type == "trunk" then
		if (IsVehicleOwned(id)) then
			SaveOwnedVehicleItems(id, Trunks[id].items)
		else
			Trunks[id].isOpen = false
		end
	elseif type == "glovebox" then
		if (IsVehicleOwned(id)) then
			SaveOwnedGloveboxItems(id, Gloveboxes[id].items)
		else
			Gloveboxes[id].isOpen = false
		end
	elseif type == "stash" then
		SaveStashItems(id, Stashes[id].items)
	elseif type == "drop" then
		if Drops[id] ~= nil then
			Drops[id].isOpen = false
			if Drops[id].items == nil or next(Drops[id].items) == nil then
				Drops[id] = nil
				TriggerClientEvent("inventory:client:RemoveDropItem", -1, id)
			end
		end
	end
end)

RegisterNetEvent('inventory:server:UseItemSlot', function(slot)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local itemData = Player.Functions.GetItemBySlot(slot)

	if itemData ~= nil then
		local itemInfo = QBCore.Shared.Items[itemData.name]
		if itemData.type == "weapon" then
			if itemData.info.quality ~= nil then
				if itemData.info.quality > 0 then
					TriggerClientEvent("inventory:client:UseWeapon", src, itemData, true)
				else
					TriggerClientEvent("inventory:client:UseWeapon", src, itemData, false)
				end
			else
				TriggerClientEvent("inventory:client:UseWeapon", src, itemData, true)
			end
			TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
		elseif itemData.useable then
			TriggerClientEvent("QBCore:Client:UseItem", src, itemData)
			TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
		end
	end
end)

RegisterNetEvent('inventory:server:UseItem', function(inventory, item)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if inventory == "player" or inventory == "hotbar" then
		local itemData = Player.Functions.GetItemBySlot(item.slot)
		if itemData ~= nil then
			TriggerClientEvent("QBCore:Client:UseItem", src, itemData)
		end
	end
end)

RegisterNetEvent('inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local fromSlot = tonumber(fromSlot)
	local toSlot = tonumber(toSlot)

	if (fromInventory == "player" or fromInventory == "hotbar") and (QBCore.Shared.SplitStr(toInventory, "-")[1] == "itemshop" or toInventory == "crafting") then
		return
	end

	if fromInventory == "player" or fromInventory == "hotbar" then
		local fromItemData = Player.Functions.GetItemBySlot(fromSlot)
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					--Player.PlayerData.items[fromSlot] = toItemData
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "otherplayer" then
				local playerId = tonumber(QBCore.Shared.SplitStr(toInventory, "-")[2])
				local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
				local toItemData = OtherPlayer.PlayerData.items[toSlot]
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					--Player.PlayerData.items[fromSlot] = toItemData
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						OtherPlayer.Functions.RemoveItem(itemInfo["name"], toAmount, fromSlot)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "robbing", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount.. "** with player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | id: *"..OtherPlayer.PlayerData.source.."*)")
					end
				else
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					TriggerEvent("qb-log:server:CreateLog", "robbing", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** to player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | id: *"..OtherPlayer.PlayerData.source.."*)")
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				OtherPlayer.Functions.AddItem(itemInfo["name"], fromAmount, toSlot, fromItemData.info)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "trunk" then
				local plate = QBCore.Shared.SplitStr(toInventory, "-")[2]
				local toItemData = Trunks[plate].items[toSlot]
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					--Player.PlayerData.items[fromSlot] = toItemData
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveFromTrunk(plate, fromSlot, itemInfo["name"], toAmount)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "trunk", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
					end
				else
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					TriggerEvent("qb-log:server:CreateLog", "trunk", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToTrunk(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "glovebox" then
				local plate = QBCore.Shared.SplitStr(toInventory, "-")[2]
				local toItemData = Gloveboxes[plate].items[toSlot]
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					--Player.PlayerData.items[fromSlot] = toItemData
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveFromGlovebox(plate, fromSlot, itemInfo["name"], toAmount)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "glovebox", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
					end
				else
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					TriggerEvent("qb-log:server:CreateLog", "glovebox", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToGlovebox(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "stash" then
				local stashId = QBCore.Shared.SplitStr(toInventory, "-")[2]
				local toItemData = Stashes[stashId].items[toSlot]
				Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					--Player.PlayerData.items[fromSlot] = toItemData
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						--RemoveFromStash(stashId, fromSlot, itemInfo["name"], toAmount)
						RemoveFromStash(stashId, toSlot, itemInfo["name"], toAmount)
						Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - stash: *" .. stashId .. "*")
					end
				else
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					TriggerEvent("qb-log:server:CreateLog", "stash", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - stash: *" .. stashId .. "*")
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToStash(stashId, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "traphouse" then
				-- Traphouse
				local traphouseId = QBCore.Shared.SplitStr(toInventory, "-")[2]
				local toItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, toSlot)
				local IsItemValid = exports['qb-traphouse']:CanItemBeSaled(fromItemData.name:lower())
				if IsItemValid then
					Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
					TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
					if toItemData ~= nil then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
						if toItemData.name ~= fromItemData.name then
							exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo["name"], toAmount)
							Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
							TriggerEvent("qb-log:server:CreateLog", "traphouse", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - traphouse: *" .. traphouseId .. "*")
						end
					else
						local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
						TriggerEvent("qb-log:server:CreateLog", "traphouse", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - traphouse: *" .. traphouseId .. "*")
					end
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					exports['qb-traphouse']:AddHouseItem(traphouseId, toSlot, itemInfo["name"], fromAmount, fromItemData.info, src)
				else
					TriggerClientEvent('QBCore:Notify', src, "You can\'t sell this item..", 'error')
				end
			else
				-- drop
				toInventory = tonumber(toInventory)
				if toInventory == nil or toInventory == 0 then
					CreateNewDrop(src, fromSlot, toSlot, fromAmount)
				else
					local toItemData = Drops[toInventory].items[toSlot]
					Player.Functions.RemoveItem(fromItemData.name, fromAmount, fromSlot)
					TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
					if toItemData ~= nil then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
						if toItemData.name ~= fromItemData.name then
							Player.Functions.AddItem(toItemData.name, toAmount, fromSlot, toItemData.info)
							RemoveFromDrop(toInventory, fromSlot, itemInfo["name"], toAmount)
							TriggerEvent("qb-log:server:CreateLog", "drop", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - dropid: *" .. toInventory .. "*")
						end
					else
						local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
						TriggerEvent("qb-log:server:CreateLog", "drop", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - dropid: *" .. toInventory .. "*")
					end
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					AddToDrop(toInventory, toSlot, itemInfo["name"], fromAmount, fromItemData.info)
					if itemInfo["name"] == "radio" then
						TriggerClientEvent('Radio.Set', src, false)
					end
				end
			end
		else
			TriggerClientEvent("QBCore:Notify", src, "You don\'t have this item!", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "otherplayer" then
		local playerId = tonumber(QBCore.Shared.SplitStr(fromInventory, "-")[2])
		local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
		local fromItemData = OtherPlayer.PlayerData.items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				OtherPlayer.Functions.RemoveItem(itemInfo["name"], fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", OtherPlayer.PlayerData.source, fromItemData.name)
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						OtherPlayer.Functions.AddItem(itemInfo["name"], toAmount, fromSlot, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "robbing", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** from player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | *"..OtherPlayer.PlayerData.source.."*)")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "robbing", "Retrieved Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) took item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** from player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | *"..OtherPlayer.PlayerData.source.."*)")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				local toItemData = OtherPlayer.PlayerData.items[toSlot]
				OtherPlayer.Functions.RemoveItem(itemInfo["name"], fromAmount, fromSlot)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					--Player.PlayerData.items[fromSlot] = toItemData
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						OtherPlayer.Functions.RemoveItem(itemInfo["name"], toAmount, toSlot)
						OtherPlayer.Functions.AddItem(itemInfo["name"], toAmount, fromSlot, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				OtherPlayer.Functions.AddItem(itemInfo["name"], fromAmount, toSlot, fromItemData.info)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, "Item doesn\'t exist??", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "trunk" then
		local plate = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = Trunks[plate].items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				RemoveFromTrunk(plate, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						AddToTrunk(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "trunk", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** plate: *" .. plate .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "trunk", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from plate: *" .. plate .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "trunk", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** plate: *" .. plate .. "*")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				local toItemData = Trunks[plate].items[toSlot]
				RemoveFromTrunk(plate, fromSlot, itemInfo["name"], fromAmount)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					--Player.PlayerData.items[fromSlot] = toItemData
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveFromTrunk(plate, toSlot, itemInfo["name"], toAmount)
						AddToTrunk(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToTrunk(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, "Item doesn\'t exist??", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "glovebox" then
		local plate = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = Gloveboxes[plate].items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				RemoveFromGlovebox(plate, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						AddToGlovebox(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "glovebox", "Swapped", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src..")* swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** plate: *" .. plate .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "glovebox", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from plate: *" .. plate .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "glovebox", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** plate: *" .. plate .. "*")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				local toItemData = Gloveboxes[plate].items[toSlot]
				RemoveFromGlovebox(plate, fromSlot, itemInfo["name"], fromAmount)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					--Player.PlayerData.items[fromSlot] = toItemData
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveFromGlovebox(plate, toSlot, itemInfo["name"], toAmount)
						AddToGlovebox(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToGlovebox(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, "Item doesn\'t exist??", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "stash" then
		local stashId = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = Stashes[stashId].items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				RemoveFromStash(stashId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						AddToStash(stashId, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
						TriggerEvent("qb-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** stash: *" .. stashId .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "stash", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from stash: *" .. stashId .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "stash", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** stash: *" .. stashId .. "*")
				end
				SaveStashItems(stashId, Stashes[stashId].items)
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				local toItemData = Stashes[stashId].items[toSlot]
				RemoveFromStash(stashId, fromSlot, itemInfo["name"], fromAmount)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					--Player.PlayerData.items[fromSlot] = toItemData
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveFromStash(stashId, toSlot, itemInfo["name"], toAmount)
						AddToStash(stashId, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info)
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToStash(stashId, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, "Item doesn\'t exist??", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "traphouse" then
		local traphouseId = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, fromSlot)
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						exports['qb-traphouse']:AddHouseItem(traphouseId, fromSlot, itemInfo["name"], toAmount, toItemData.info, src)
						TriggerEvent("qb-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** stash: *" .. traphouseId .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "stash", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from stash: *" .. traphouseId .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "stash", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** stash: *" .. traphouseId .. "*")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				local toItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, toSlot)
				exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						exports['qb-traphouse']:RemoveHouseItem(traphouseId, toSlot, itemInfo["name"], toAmount)
						exports['qb-traphouse']:AddHouseItem(traphouseId, fromSlot, itemInfo["name"], toAmount, toItemData.info, src)
					end
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				exports['qb-traphouse']:AddHouseItem(traphouseId, toSlot, itemInfo["name"], fromAmount, fromItemData.info, src)
			end
		else
			TriggerClientEvent("QBCore:Notify", src, "Item doesn't exist??", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "itemshop" then
		local shopType = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local itemData = ShopItems[shopType].items[fromSlot]
		local itemInfo = QBCore.Shared.Items[itemData.name:lower()]
		local bankBalance = Player.PlayerData.money["bank"]
		local price = tonumber((itemData.price*fromAmount))

		if QBCore.Shared.SplitStr(shopType, "_")[1] == "Dealer" then
			if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
				price = tonumber(itemData.price)
				if Player.Functions.RemoveMoney("cash", price, "dealer-item-bought") then
					itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
					Player.Functions.AddItem(itemData.name, 1, toSlot, itemData.info)
					TriggerClientEvent('qb-drugs:client:updateDealerItems', src, itemData, 1)
					TriggerClientEvent('QBCore:Notify', src, itemInfo["label"] .. " bought!", "success")
					TriggerEvent("qb-log:server:CreateLog", "dealers", "Dealer item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
				else
					TriggerClientEvent('QBCore:Notify', src, "You don\'t have enough cash..", "error")
				end
			else
				if Player.Functions.RemoveMoney("cash", price, "dealer-item-bought") then
					Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
					TriggerClientEvent('qb-drugs:client:updateDealerItems', src, itemData, fromAmount)
					TriggerClientEvent('QBCore:Notify', src, itemInfo["label"] .. " bought!", "success")
					TriggerEvent("qb-log:server:CreateLog", "dealers", "Dealer item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. "  for $"..price)
				else
					TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash..", "error")
				end
			end
		elseif QBCore.Shared.SplitStr(shopType, "_")[1] == "Itemshop" then
			if Player.Functions.RemoveMoney("cash", price, "itemshop-bought-item") then
                if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
                end
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('qb-shops:client:UpdateShop', src, QBCore.Shared.SplitStr(shopType, "_")[2], itemData, fromAmount)
				TriggerClientEvent('QBCore:Notify', src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			elseif bankBalance >= price then
				Player.Functions.RemoveMoney("bank", price, "itemshop-bought-item")
                if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
                end
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('qb-shops:client:UpdateShop', src, QBCore.Shared.SplitStr(shopType, "_")[2], itemData, fromAmount)
				TriggerClientEvent('QBCore:Notify', src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			else
				TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash..", "error")
			end
		else
			if Player.Functions.RemoveMoney("cash", price, "unkown-itemshop-bought-item") then
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('QBCore:Notify', src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			elseif bankBalance >= price then
				Player.Functions.RemoveMoney("bank", price, "unkown-itemshop-bought-item")
				Player.Functions.AddItem(itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('QBCore:Notify', src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			else
				TriggerClientEvent('QBCore:Notify', src, "You don\'t have enough cash..", "error")
			end
		end
	elseif fromInventory == "crafting" then
		local itemData = Config.CraftingItems[fromSlot]
		if hasCraftItems(src, itemData.costs, fromAmount) then
			TriggerClientEvent("inventory:client:CraftItems", src, itemData.name, itemData.costs, fromAmount, toSlot, itemData.points)
		else
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
			TriggerClientEvent('QBCore:Notify', src, "You don't have the right items..", "error")
		end
	elseif fromInventory == "attachment_crafting" then
		local itemData = Config.AttachmentCrafting["items"][fromSlot]
		if hasCraftItems(src, itemData.costs, fromAmount) then
			TriggerClientEvent("inventory:client:CraftAttachment", src, itemData.name, itemData.costs, fromAmount, toSlot, itemData.points)
		else
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
			TriggerClientEvent('QBCore:Notify', src, "You don't have the right items..", "error")
		end
	else
		-- drop
		fromInventory = tonumber(fromInventory)
		local fromItemData = Drops[fromInventory].items[fromSlot]
		local fromAmount = tonumber(fromAmount) ~= nil and tonumber(fromAmount) or fromItemData.amount
		if fromItemData ~= nil and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = Player.Functions.GetItemBySlot(toSlot)
				RemoveFromDrop(fromInventory, fromSlot, itemInfo["name"], fromAmount)
				if toItemData ~= nil then
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						Player.Functions.RemoveItem(toItemData.name, toAmount, toSlot)
						AddToDrop(fromInventory, toSlot, itemInfo["name"], toAmount, toItemData.info)
						if itemInfo["name"] == "radio" then
							TriggerClientEvent('Radio.Set', src, false)
						end
						TriggerEvent("qb-log:server:CreateLog", "drop", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** - dropid: *" .. fromInventory .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "drop", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** - from dropid: *" .. fromInventory .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "drop", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** -  dropid: *" .. fromInventory .. "*")
				end
				Player.Functions.AddItem(fromItemData.name, fromAmount, toSlot, fromItemData.info)
			else
				toInventory = tonumber(toInventory)
				local toItemData = Drops[toInventory].items[toSlot]
				RemoveFromDrop(fromInventory, fromSlot, itemInfo["name"], fromAmount)
				--Player.PlayerData.items[toSlot] = fromItemData
				if toItemData ~= nil then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					--Player.PlayerData.items[fromSlot] = toItemData
					local toAmount = tonumber(toAmount) ~= nil and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveFromDrop(toInventory, toSlot, itemInfo["name"], toAmount)
						AddToDrop(fromInventory, fromSlot, itemInfo["name"], toAmount, toItemData.info)
						if itemInfo["name"] == "radio" then
							TriggerClientEvent('Radio.Set', src, false)
						end
					end
				else
					--Player.PlayerData.items[fromSlot] = nil
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToDrop(toInventory, toSlot, itemInfo["name"], fromAmount, fromItemData.info)
				if itemInfo["name"] == "radio" then
					TriggerClientEvent('Radio.Set', src, false)
				end
			end
		else
			TriggerClientEvent("QBCore:Notify", src, "Item doesn't exist??", "error")
		end
	end
end)

RegisterNetEvent('qb-inventory:server:SaveStashItems', function(stashId, items)
    MySQL.Async.insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
        ['stash'] = stashId,
        ['items'] = json.encode(items)
    })
end)

RegisterServerEvent("inventory:server:GiveItem", function(target, inventory, item, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local OtherPlayer = QBCore.Functions.GetPlayer(tonumber(target))
    local dist = #(GetEntityCoords(GetPlayerPed(src))-GetEntityCoords(GetPlayerPed(target)))
	if Player == OtherPlayer then return TriggerClientEvent('QBCore:Notify', src, "You can't give yourself an item?") end
	if dist > 2 then return TriggerClientEvent('QBCore:Notify', src, "You are too far away to give items!") end
	if amount <= item.amount then
		if amount == 0 then
			amount = item.amount
		end
		if Player.Functions.RemoveItem(item.name, amount, item.slot) then
			if OtherPlayer.Functions.AddItem(item.name, amount, false, item.info) then
				TriggerClientEvent('inventory:client:ItemBox',target, QBCore.Shared.Items[item.name], "add")
				TriggerClientEvent('QBCore:Notify', target, "You Received "..amount..' '..item.label.." From "..Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname)
				TriggerClientEvent("inventory:client:UpdatePlayerInventory", target, true)
				TriggerClientEvent('inventory:client:ItemBox',src, QBCore.Shared.Items[item.name], "remove")
				TriggerClientEvent('QBCore:Notify', src, "You gave " .. OtherPlayer.PlayerData.charinfo.firstname.." "..OtherPlayer.PlayerData.charinfo.lastname.. " " .. amount .. " " .. item.label .."!")
				TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
				TriggerClientEvent('qb-inventory:client:giveAnim', src)
				TriggerClientEvent('qb-inventory:client:giveAnim', target)
			else
				TriggerClientEvent('QBCore:Notify', src,  "The other players inventory is full!", "error")
				TriggerClientEvent('QBCore:Notify', target,  "Your inventory is full!", "error")
				TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
				TriggerClientEvent("inventory:client:UpdatePlayerInventory", target, false)
			end
		else
			TriggerClientEvent('QBCore:Notify', src,  "You do not have enough of the item!", "error")
		end
	else
		TriggerClientEvent('QBCore:Notify', src, "You do not have enough items to transfer")
	end
end)

-- callback

QBCore.Functions.CreateCallback('qb-inventory:server:GetStashItems', function(source, cb, stashId)
	cb(GetStashItems(stashId))
end)

-- command

QBCore.Commands.Add("resetinv", "Reset Inventory (Admin Only)", {{name="type", help="stash/trunk/glovebox"},{name="id/plate", help="ID of stash or license plate"}}, true, function(source, args)
	local invType = args[1]:lower()
	table.remove(args, 1)
	local invId = table.concat(args, " ")
	if invType ~= nil and invId ~= nil then
		if invType == "trunk" then
			if Trunks[invId] ~= nil then
				Trunks[invId].isOpen = false
			end
		elseif invType == "glovebox" then
			if Gloveboxes[invId] ~= nil then
				Gloveboxes[invId].isOpen = false
			end
		elseif invType == "stash" then
			if Stashes[invId] ~= nil then
				Stashes[invId].isOpen = false
			end
		else
			TriggerClientEvent('QBCore:Notify', source,  "Not a valid type..", "error")
		end
	else
		TriggerClientEvent('QBCore:Notify', source,  "Arguments not filled out correctly..", "error")
	end
end, "admin")

QBCore.Commands.Add("rob", "Rob Player", {}, false, function(source, args)
	TriggerClientEvent("police:client:RobPlayer", source)
end)

QBCore.Commands.Add("giveitem", "Give An Item (Admin Only)", {{name="id", help="Player ID"},{name="item", help="Name of the item (not a label)"}, {name="amount", help="Amount of items"}}, true, function(source, args)
	local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
	local amount = tonumber(args[3])
	local itemData = QBCore.Shared.Items[tostring(args[2]):lower()]
	if Player ~= nil then
		if amount > 0 then
			if itemData ~= nil then
				-- check iteminfo
				local info = {}
				if itemData["name"] == "id_card" then
					info.citizenid = Player.PlayerData.citizenid
					info.firstname = Player.PlayerData.charinfo.firstname
					info.lastname = Player.PlayerData.charinfo.lastname
					info.birthdate = Player.PlayerData.charinfo.birthdate
					info.gender = Player.PlayerData.charinfo.gender
					info.nationality = Player.PlayerData.charinfo.nationality
				elseif itemData["name"] == "driver_license" then
					info.firstname = Player.PlayerData.charinfo.firstname
					info.lastname = Player.PlayerData.charinfo.lastname
					info.birthdate = Player.PlayerData.charinfo.birthdate
					info.type = "Class C Driver License"
				elseif itemData["type"] == "weapon" then
					amount = 1
					info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
				elseif itemData["name"] == "harness" then
					info.uses = 20
				elseif itemData["name"] == "markedbills" then
					info.worth = math.random(5000, 10000)
				elseif itemData["name"] == "labkey" then
					info.lab = exports["qb-methlab"]:GenerateRandomLab()
				elseif itemData["name"] == "printerdocument" then
					info.url = "https://cdn.discordapp.com/attachments/870094209783308299/870104331142189126/Logo_-_Display_Picture_-_Stylized_-_Red.png"
				end

				if Player.Functions.AddItem(itemData["name"], amount, false, info) then
					TriggerClientEvent('QBCore:Notify', source, "You Have Given " ..GetPlayerName(tonumber(args[1])).." "..amount.." "..itemData["name"].. "", "success")
				else
					TriggerClientEvent('QBCore:Notify', source,  "Can't give item!", "error")
				end
			else
				TriggerClientEvent('QBCore:Notify', source,  "Item Does Not Exist", "error")
			end
		else
			TriggerClientEvent('QBCore:Notify', source,  "Invalid Amount", "error")
		end
	else
		TriggerClientEvent('QBCore:Notify', source,  "Player Is Not Online", "error")
	end
end, "admin")

QBCore.Commands.Add("randomitems", "Give Random Items (God Only)", {}, false, function(source, args)
	local Player = QBCore.Functions.GetPlayer(source)
	local filteredItems = {}
	for k, v in pairs(QBCore.Shared.Items) do
		if QBCore.Shared.Items[k]["type"] ~= "weapon" then
			filteredItems[#filteredItems+1] = v
		end
	end
	for i = 1, 10, 1 do
		local randitem = filteredItems[math.random(1, #filteredItems)]
		local amount = math.random(1, 10)
		if randitem["unique"] then
			amount = 1
		end
		if Player.Functions.AddItem(randitem["name"], amount) then
			TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[randitem["name"]], 'add')
            Wait(500)
		end
	end
end, "god")

-- item

QBCore.Functions.CreateUseableItem("snowball", function(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	local itemData = Player.Functions.GetItemBySlot(item.slot)
	if Player.Functions.GetItemBySlot(item.slot) ~= nil then
        TriggerClientEvent("inventory:client:UseSnowball", source, itemData.amount)
    end
end)

QBCore.Functions.CreateUseableItem("driver_license", function(source, item)
	for k, v in pairs(QBCore.Functions.GetPlayers()) do
		local PlayerPed = GetPlayerPed(source)
		local TargetPed = GetPlayerPed(v)
		local dist = #(GetEntityCoords(PlayerPed) - GetEntityCoords(TargetPed))
		if dist < 3.0 then
			TriggerClientEvent('chat:addMessage', v,  {
					template = '<div class="chat-message advert"><div class="chat-message-body"><strong>{0}:</strong><br><br> <strong>First Name:</strong> {1} <br><strong>Last Name:</strong> {2} <br><strong>Birth Date:</strong> {3} <br><strong>Licenses:</strong> {4}</div></div>',
					args = {
						"Drivers License",
						item.info.firstname,
						item.info.lastname,
						item.info.birthdate,
						item.info.type
					}
				}
			)
		end
	end
end)

QBCore.Functions.CreateUseableItem("id_card", function(source, item)
	for k, v in pairs(QBCore.Functions.GetPlayers()) do
		local PlayerPed = GetPlayerPed(source)
		local TargetPed = GetPlayerPed(v)
		local dist = #(GetEntityCoords(PlayerPed) - GetEntityCoords(TargetPed))
		if dist < 3.0 then
			local gender = "Man"
			if item.info.gender == 1 then
				gender = "Woman"
			end
			TriggerClientEvent('chat:addMessage', v,  {
					template = '<div class="chat-message advert"><div class="chat-message-body"><strong>{0}:</strong><br><br> <strong>Civ ID:</strong> {1} <br><strong>First Name:</strong> {2} <br><strong>Last Name:</strong> {3} <br><strong>Birthdate:</strong> {4} <br><strong>Gender:</strong> {5} <br><strong>Nationality:</strong> {6}</div></div>',
					args = {
						"ID Card",
						item.info.citizenid,
						item.info.firstname,
						item.info.lastname,
						item.info.birthdate,
						gender,
						item.info.nationality
					}
				}
			)
		end
	end
end)
