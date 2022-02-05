local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RestockerAddon
---@field MainFrame table Main frame of the addon
---@field EventFrame table Hidden frame for addon events
---@field loaded boolean
---@field merchantIsOpen boolean
---@field addItemWait table<number, any> Item ids waiting for resolution to be added to the buy list
---@field buyIngredients table<string, RsRecipe> Auto buy table contains ingredients to buy if restocking some crafted item
---@field buyIngredientsWait table<number, RsRecipe> Item ids waiting for resolution for auto-buy setup
---@field IsTBC boolean Whether we are running on TBC
---@field IsClassic boolean Whether we are running on Classic or Season of Mastery
---@field IsEra boolean
---@field IsSoM boolean
