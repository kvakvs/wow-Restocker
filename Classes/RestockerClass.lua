local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RestockerAddon
---@field addItemWait table<number, any> Item ids waiting for resolution to be added to the buy list
---@field buyIngredients table<string, RsRecipe> Auto buy table contains ingredients to buy if restocking some crafted item
---@field buyIngredientsWait table<number, RsRecipe> Item ids waiting for resolution for auto-buy setup
---@field currentlyRestocking boolean
---@field EventFrame table Hidden frame for addon events
---@field framepool table A collection of UI frames
---@field hiddenFrame table An UI frame
---@field IsClassic boolean Whether we are running on Classic or Season of Mastery
---@field IsEra boolean
---@field IsSoM boolean
---@field IsTBC boolean Whether we are running on TBC
---@field itemsRestocked table
---@field loaded boolean
---@field MainFrame table Main frame of the addon
---@field merchantIsOpen boolean
---@field restockedItems boolean

---@class RsSettings
---@field autoBuy boolean
---@field autoOpenAtBank boolean
---@field autoOpenAtMerchant boolean
---@field currentProfile table
---@field framePos table
---@field loginMessage boolean Show restocker hello message
---@field profiles table<string, table>
---@field restockFromBank boolean
