--[[
English base language translation for qb-inventory
Translation done by wanderrer (Martin Riggs#0807 on Discord)
]]--
local Translations = {
    progress = {
        ["crafting"] = "Crafting...",
        ["snowballs"] = "Collecting snowballs..",
    },
    notify = {
        ["failed"] = "Failed",
        ["canceled"] = "Canceled",
        ["vlocked"] = "Vehicle Locked",
        ["notowned"] = "You do not own this item!",
        ["missitem"] = "You don\'t have this item!",
        ["nonb"] = "No one nearby!",
        ["noaccess"] = "Not Accessible",
        ["nosell"] = "You can\'t sell this item..",
        ["itemexist"] = "Item doesn\'t exist??",
        ["notencash"] = "You don\'t have enough cash..",
        ["noitem"] = "You don\'t have the right items..",
        ["gsitem"] = "You can\'t give yourself an item?",
        ["tftgitem"] = "You are too far away to give items!",
        ["infound"] = "Item you tried giving not found!",
        ["iifound"] = "Incorrect item found try again!",
        ["gitemrec"] = "You Received ",
        ["gitemfrom"] = " From ",
        ["gitemyg"] = "You gave ",
        ["gitinvfull"] = "The other players inventory is full!",
        ["giymif"] = "Your inventory is full!",
        ["gitydhei"] = "You do not have enough of the item",
        ["gitydhitt"] = "You do not have enough items to transfer",
        ["navt"] = "Not a valid type..",
        ["anfoc"] = "Arguments not filled out correctly..",
        ["yhg"] = "You Have Given ",
        ["cgitem"] = "Can\'t give item!",
        ["idne"] = "Item Does Not Exist",
        ["pdne"] = "Player Is Not Online",
    },
    inf_mapping = {
        ["opn_inv"] = "Open Inventory",
        ["tog_slots"] = "Toggles keybind slots",
        ["use_item"] = "Uses the item in slot ",
    },
    menu = {
        ["vending"] = "Vending Machine",
        ["craft"] = "Craft",
        ["o_bag"] = "Open Bag",
    },
    interaction = {
        ["craft"] = "~g~E~w~ - Craft",
    },
    label = {
        ["craft"] = "Crafting",
        ["a_craft"] = "Attachment Crafting",
    },
}
Lang = Locale:new({phrases = Translations, warnOnMissing = true})
