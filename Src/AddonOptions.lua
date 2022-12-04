---@class RsAddonOptionsModule
---@field language {[string]:string} TODO: Move this to languages module
local addonOptionsModule = RsModule.addonOptionsModule

local RS = RS_ADDON ---@type RestockerAddon
local restockerModule = RsModule.restockerModule
local kvOptionsModule = KvModuleManager.optionsModule

addonOptionsModule.language = --[[---@type {[string]:string} ]] {
  ["options.category.General"] = "General",

  ["options.short.loginMessage"] = "Display login message",
  ["options.long.loginMessage"] = "Print a message in chat when Restocker is loaded and activated. Disable this to reduce chat noise",

  ["options.short.autoOpenAtMerchant"] = "Open Restocker at merchant",
  ["options.long.autoOpenAtMerchant"] = "When visiting a merchant, Restocker window will open",

  ["options.short.autoOpenAtBank"] = "Open Restocker at bank",
  ["options.long.autoOpenAtBank"] = "When visiting a banker, Restocker window will open",

  ["options.short.sortList"] = "Sort items list",
  ["options.long.sortList"] = "Choose whether item list will be sorted by item name or by item id (numeric)",
  ["options.sortList.alphabetic"] = "Alphabetically (by name)",
  ["options.sortList.numeric"] = "Numerically (by item id)",

  ["options.category.Restocking"] = "Restocking",

  ["options.short.restockFromMerchant"] = "Restock from merchants",
  ["options.long.restockFromMerchant"] = "When visiting a merchant, attempt to buy missing items (given the reputation standing with the vendor is good enough)",

  ["options.short.restockSell"] = "Sell extra to merchants",
  ["options.long.restockSell"] = "When visiting a merchant and the player has too many of that item, extras will be sold. Use 0 as quantity to always sell all.",

  ["options.short.restockToBank"] = "Stash extra to bank",
  ["options.long.restockToBank"] = "When visiting a bank, extra items will be sent to the bank bags. Use 0 as quantity to stash all.",

  ["options.short.restockFromBank"] = "Restock from bank",
  ["options.long.restockFromBank"] = "When visiting a bank, take items from bank attempting to maintain the necessary quantity in bags",
}

---@param key string
---@return string
local function _t(key)
  return addonOptionsModule.language[key] or "→" .. key
end

---@param name string
---@param dict table|nil
---@param key string|nil
---@param notify function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateCheckbox(name, dict, key, notify)
  return kvOptionsModule:TemplateCheckbox(name, dict or restockerModule.settings, key or name, notify, _t)
end

---@param name string
---@param onClick function Call this when button is pressed
function addonOptionsModule:TemplateButton(name, onClick)
  return kvOptionsModule:TemplateButton(name, onClick, _t)
end

---@param values table|function Key is sent to the setter, value is the string displayed
---@param dict table|nil
---@param key string|nil
---@param notifyFn function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateMultiselect(name, values, dict, notifyFn, setFn, getFn)
  return kvOptionsModule:TemplateMultiselect(name, values, dict or restockerModule.settings, notifyFn, setFn, getFn, _t)
end

---@param values table|function Key is sent to the setter, value is the string displayed
---@param dict table|nil
---@param style string|nil "dropdown" or "radio"
---@param notifyFn function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateSelect(name, values, style, dict, notifyFn, setFn, getFn)
  return kvOptionsModule:TemplateSelect(name, values, style, dict or restockerModule.settings, notifyFn, setFn, getFn, _t)
end

---@param dict table|nil
---@param key string|nil
---@param notify function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateInput(type, name, dict, key, notify)
  return kvOptionsModule:TemplateInput(type, name, dict or restockerModule.settings, key or name, notify, _t)
end

---@param dict table|nil
---@param key string|nil
---@param notify function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateRange(name, rangeFrom, rangeTo, step, dict, key, notify)
  return kvOptionsModule:TemplateRange(name, rangeFrom, rangeTo, step, dict or restockerModule.settings, key or name, notify, _t)
end

function addonOptionsModule:CreateGeneralOptions()
  return {
    type = "group",
    name = "1. " .. _t("options.category.General"),
    args = {
      displayLoginMessage = self:TemplateCheckbox("loginMessage", nil, nil, nil),
      autoOpenMerchant = self:TemplateCheckbox("autoOpenAtMerchant", nil, nil, nil),
      autoOpenBank = self:TemplateCheckbox("autoOpenAtBank", nil, nil, nil),
      sortList = self:TemplateSelect("sortList", {
        ["alphabetic"] = _t("options.sortList.alphabetic"),
        ["numeric"] = _t("options.sortList.numeric"),
      }, "radio", nil, nil,
          function(info, value)
            RS.sortListAlphabetically = value == "alphabetic"
            RS.sortListNumerically = value ~= "alphabetic"
            RS:Update()
          end,
          function(info)
            if RS.sortListAlphabetically then
              return "alphabetic"
            end
            return "numeric"
          end),
    }
  }
end

function addonOptionsModule:CreateRestockingOptions()
  return {
    type = "group",
    name = "2. " .. _t("options.category.Restocking"),
    args = {
      restockFromMerchant = self:TemplateCheckbox("restockFromMerchant", nil, nil, nil),
      restockSell = self:TemplateCheckbox("restockSell", nil, nil, nil),
      restockToBank = self:TemplateCheckbox("restockToBank", nil, nil, nil),
      restockFromBank = self:TemplateCheckbox("restockFromBank", nil, nil, nil),
    }
  }
end

function addonOptionsModule:CreateOptionsTable()
  kvOptionsModule.optionsOrder = 0

  return {
    type = "group",
    args = {
      generalOptions = self:CreateGeneralOptions(),
      restockingOptions = self:CreateRestockingOptions(),
    } -- end args
  } -- end
end

---Called from options' Default button
function addonOptionsModule:ResetDefaultOptions()
  restockerModule.settings.loginMessage = true
  restockerModule.settings.autoOpenAtMerchant = false
  restockerModule.settings.autoOpenAtBank = false
  restockerModule.settings.restockFromBank = true
  restockerModule.settings.restockToBank = false
  restockerModule.settings.restockFromMerchant = true
  restockerModule.settings.restockSell = false
end
