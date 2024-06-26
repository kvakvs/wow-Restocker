--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

RS.profileSelectedForDeletion = ""

local restockerModule = RsModule.restockerModule ---@type RsRestockerModule

---INTERFACE OPTIONS PANEL
---@param name string Addon name
---@deprecated Use AceConfig instead
function RS:CreateOptionsMenu(name)
  local settings = restockerModule.settings
  local optionsPanel = CreateFrame("Frame", "RestockerOptions", UIParent)
  optionsPanel.name = name

  local text = optionsPanel:CreateFontString(nil, "OVERLAY")
  text:SetFontObject("GameFontNormalLarge")
  text:SetText("Restocker Options")
  text:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 20, -30)

  local loginMessage = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
  loginMessage:SetSize(25, 25)
  loginMessage:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 10, -15)
  loginMessage:SetScript("OnClick", function(self, button)
    settings.loginMessage = self:GetChecked()
  end)
  loginMessage:SetChecked(settings.loginMessage)
  optionsPanel.loginMessage = loginMessage

  local loginMessageText = loginMessage:CreateFontString(nil, "OVERLAY")
  loginMessageText:SetFontObject("GameFontNormal")
  loginMessageText:SetPoint("LEFT", loginMessage, "RIGHT", 3, 0)
  loginMessageText:SetText("Display login message")
  optionsPanel.loginMessageText = loginMessageText

  local autoOpenAtMerchant = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
  autoOpenAtMerchant:SetSize(25, 25)
  autoOpenAtMerchant:SetPoint("TOPLEFT", loginMessage, "BOTTOMLEFT", 0, 0)
  autoOpenAtMerchant:SetScript("OnClick", function(self, button)
    settings.autoOpenAtMerchant = self:GetChecked()
  end)
  autoOpenAtMerchant:SetChecked(settings.autoOpenAtMerchant)
  optionsPanel.autoOpenAtMerchant = autoOpenAtMerchant

  local autoOpenAtMerchantText = autoOpenAtMerchant:CreateFontString(nil, "OVERLAY")
  autoOpenAtMerchantText:SetFontObject("GameFontNormal")
  autoOpenAtMerchantText:SetPoint("LEFT", autoOpenAtMerchant, "RIGHT", 3, 0)
  autoOpenAtMerchantText:SetText("Open window at vendor")
  optionsPanel.autoOpenAtMerchantText = autoOpenAtMerchantText

  local autoOpenAtBank = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
  autoOpenAtBank:SetSize(25, 25)
  autoOpenAtBank:SetPoint("TOPLEFT", autoOpenAtMerchant, "BOTTOMLEFT", 0, 0)
  autoOpenAtBank:SetScript("OnClick", function(self, button)
    settings.autoOpenAtBank = self:GetChecked()
  end)
  autoOpenAtBank:SetChecked(settings.autoOpenAtBank)
  optionsPanel.autoOpenAtBank = autoOpenAtBank

  local autoOpenAtBankText = autoOpenAtBank:CreateFontString(nil, "OVERLAY")
  autoOpenAtBankText:SetFontObject("GameFontNormal")
  autoOpenAtBankText:SetPoint("LEFT", autoOpenAtBank, "RIGHT", 3, 0)
  autoOpenAtBankText:SetText("Open window at bank")
  optionsPanel.autoOpenAtBankText = autoOpenAtBankText

  local sortListAlphabetically = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
  sortListAlphabetically:SetSize(25, 25)
  sortListAlphabetically:SetPoint("TOPLEFT", autoOpenAtBank, "BOTTOMLEFT", 0, 0)
  sortListAlphabetically:SetScript("OnClick", function(self, button)
    RS.sortListAlphabetically = self:GetChecked()
    if self:GetChecked() then
      optionsPanel.sortListNumerically:SetChecked(false)
      RS.sortListNumerically = false
    end
    RS:Update()
  end)
  sortListAlphabetically:SetChecked(RS.sortListAlphabetically)
  optionsPanel.sortListAlphabetically = sortListAlphabetically

  local sortListAlphabeticallyText = sortListAlphabetically:CreateFontString(nil, "OVERLAY")
  sortListAlphabeticallyText:SetFontObject("GameFontNormal")
  sortListAlphabeticallyText:SetPoint("LEFT", sortListAlphabetically, "RIGHT", 3, 0)
  sortListAlphabeticallyText:SetText("Sort list alphabetically")
  optionsPanel.sortListAlphabeticallyText = sortListAlphabeticallyText

  local sortListNumerically = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
  sortListNumerically:SetSize(25, 25)
  sortListNumerically:SetPoint("TOPLEFT", sortListAlphabetically, "BOTTOMLEFT", 0, 0)
  sortListNumerically:SetScript("OnClick", function(self, button)
    RS.sortListNumerically = self:GetChecked()
    if self:GetChecked() then
      optionsPanel.sortListAlphabetically:SetChecked(false)
      RS.sortListAlphabetically = false
    end
    RS:Update()
  end)
  sortListNumerically:SetChecked(RS.sortListNumerically)
  optionsPanel.sortListNumerically = sortListNumerically

  local sortListNumericallyText = sortListNumerically:CreateFontString(nil, "OVERLAY")
  sortListNumericallyText:SetFontObject("GameFontNormal")
  sortListNumericallyText:SetPoint("LEFT", sortListNumerically, "RIGHT", 3, 0)
  sortListNumericallyText:SetText("Sort list by amount")
  optionsPanel.sortListNumericallyText = sortListNumericallyText



  -- Profiles
  local profilesHeader = optionsPanel:CreateFontString(nil, "OVERLAY")
  profilesHeader:SetPoint("TOPLEFT", sortListNumerically, "BOTTOMLEFT", -10, -20)
  profilesHeader:SetFontObject("GameFontNormalLarge")
  profilesHeader:SetText("Profiles")

  local addProfileEditBox = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
  addProfileEditBox:SetSize(124, 20)
  addProfileEditBox:SetPoint("TOPLEFT", profilesHeader, "BOTTOMLEFT", 15, -10)
  addProfileEditBox:SetAutoFocus(false)
  optionsPanel.addProfileEditBox = addProfileEditBox

  local addProfileButton = CreateFrame("Button", nil, optionsPanel, "GameMenuButtonTemplate")
  addProfileButton:SetPoint("LEFT", addProfileEditBox, "RIGHT")
  addProfileButton:SetSize(95, 28);
  addProfileButton:SetText("Add profile");
  addProfileButton:SetNormalFontObject("GameFontNormal");
  addProfileButton:SetHighlightFontObject("GameFontHighlight");
  addProfileButton:SetScript("OnClick", function(self, button, down)
    local editBox = self:GetParent().addProfileEditBox
    local text = editBox:GetText()

    RS:AddProfile(text);

    editBox:SetText("")
    editBox:ClearFocus()
  end);
  optionsPanel.addProfileButton = addProfileButton

  local deleteProfileMenu = CreateFrame("Frame", "RestockerDeleteProfileMenu", optionsPanel, "UIDropDownMenuTemplate")
  deleteProfileMenu:SetPoint("TOPLEFT", addProfileEditBox, "BOTTOMLEFT", -24, -5)
  deleteProfileMenu.displayMode = "MENU"
  deleteProfileMenu.info = {}
  deleteProfileMenu.initialize = function(self, level)
    if not level then
      return
    end

    for profileName, _ in pairs(settings.profiles) do
      local info = UIDropDownMenu_CreateInfo()

      info.text = profileName
      info.arg1 = profileName
      info.func = RS.selectProfileForDeletion
      info.checked = false

      UIDropDownMenu_AddButton(info, 1)
    end
  end
  optionsPanel.deleteProfileMenu = deleteProfileMenu

  local deleteProfileButton = CreateFrame("Button", nil, optionsPanel, "GameMenuButtonTemplate")
  deleteProfileButton:SetPoint("LEFT", deleteProfileMenu, "RIGHT", 108, 3)
  deleteProfileButton:SetSize(95, 28);
  deleteProfileButton:SetText("Delete profile");
  deleteProfileButton:SetNormalFontObject("GameFontNormal");
  deleteProfileButton:SetHighlightFontObject("GameFontHighlight");
  deleteProfileButton:SetScript("OnClick", function(self, button, down)
    RS:DeleteProfile(RS.profileSelectedForDeletion)
  end);
  optionsPanel.deleteProfileButton = deleteProfileButton

  RS.optionsPanel = optionsPanel
  InterfaceOptions_AddCategory(optionsPanel)
end

function RS.selectProfileForDeletion(self, arg1, arg2, checked)
  RS.profileSelectedForDeletion = arg1
  UIDropDownMenu_SetText(RS.optionsPanel.deleteProfileMenu, RS.profileSelectedForDeletion)
end