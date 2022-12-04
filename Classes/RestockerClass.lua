--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---A row of controls one row per item to restock or stash
---@class RsReusableFrame: WowControl
---@field isInUse boolean
---@field index number
---@field text WowFontString The item name label
---@field editBox WowControl The item count editbox
---@field reactionBox WowControl The required vendor reputation standing

---@class RestockerAddon
---@field RegisterEvent function
---@field buying boolean Currently buying is in progress
---@field minorChange boolean Bank open event sets this; Unused
---@field addItemWait {[number|string]: boolean|nil} Item ids waiting for resolution to be added to the buy list
---@field addonName string
---@field BAG_ICON string
---@field buyIngredients table<string, RsRecipe> Auto buy table contains ingredients to buy if restocking some crafted item
---@field buyIngredientsWait table<number, RsRecipe> Item ids waiting for resolution for auto-buy setup
---@field commands RsCommands
---@field defaults RsAddonDefaults
---@field EventFrame WowControl Hidden frame for addon events
---@field framepool RsReusableFrame[] A collection of UI frames
---@field HaveTBC boolean Whether we are running on or after TBC
---@field HaveWotLK boolean
---@field hiddenFrame WowControl An UI frame
---@field loaded boolean
---@field MainFrame table Main frame of the addon
---@field merchantIsOpen boolean
---@field onUpdateFrame table Hidden frame for addon events
---@field optionsPanel table
---@field Print function
---@field restockedItems boolean
---@field slashPrefix string
---@field sortListAlphabetically boolean
---@field sortListNumerically boolean
---@field framepool table[]
---@field profileSelectedForDeletion string
---@field ICON_FORMAT string

---@shape RsCommands
---@field show string
---@field profile {[string]: string}

---@shape RsAddonDefaults
---@field prefix string
---@field color string
---@field slash string

---@alias RsProfile RsBuyCommand[]

---@shape RsProfileCollection
---@field [string] RsProfile|nil
---@field default RsProfile|nil

---@class RsSettings
---@field autoBuy boolean
---@field autoOpenAtBank boolean
---@field autoOpenAtMerchant boolean
---@field currentProfile string
---@field framePos table
---@field loginMessage boolean Show restocker hello message
---@field profiles RsProfileCollection
---@field restockFromMerchant boolean
---@field restockSell boolean
---@field restockToBank boolean
---@field restockFromBank boolean
-- See RS.sortListAlphabetically -@field sortListAlphabetically boolean
-- See RS.sortListNumerically -@field sortListNumerically boolean

---@shape RsInventorySlotNumber
---@field bag number
---@field slot number