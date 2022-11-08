local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

local bankModule = RsModule.bankModule ---@type RsBankModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local eventsModule = RsModule.eventsModule ---@type RsEventsModule

---Create an amount edit box, aligning to the left of alignFrame
local function rsAmountEditBox(frame, alignFrame)
  local settings = restockerModule.settings
  local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate");

  editBox:SetSize(40, 20)
  editBox:SetPoint("RIGHT", alignFrame, "LEFT", 3, 0);
  editBox:SetAutoFocus(false);
  editBox:SetScript("OnEnterPressed", function(self)
    local amount = self:GetText()
    local parent = self:GetParent()
    local text = parent.text:GetText()

    if amount == "" then
      amount = 0;
    end

    for _, item in ipairs(settings.profiles[settings.currentProfile]) do
      if item.itemName == text then
        item.amount = tonumber(amount)
      end
    end
    editBox:ClearFocus()
    self:SetText(tonumber(amount));
    RS:Update()
    if bankModule.bankIsOpen then
      eventsModule.OnBankOpen(true)
    end

  end);
  editBox:SetScript("OnKeyUp",
      function(self)
        local amount = self:GetText()
        local parent = self:GetParent()
        local text = parent.text:GetText()

        if amount == "" then
          amount = 0;
        end

        for _, item in ipairs(settings.profiles[settings.currentProfile]) do
          if item.itemName == text then
            item.amount = tonumber(amount)
          end
        end
      end)

  editBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Amount to restock")
    GameTooltip:AddLine("Press Enter when finished editing")
    GameTooltip:Show()
  end)
  editBox:SetScript("OnLeave", function(self, motion)
    GameTooltip:Hide()
  end)

  frame.editBox = editBox
  frame.isInUse = true
  frame:Show()

  return editBox;
end

-- Add a small edit box defaulting to empty value, aligning to the left of alignFrame.
---Will check faction reaction on vendor if not empty.
local function rsRequireReactionEditBox(frame, alignFrame)
  local settings = restockerModule.settings
  local reactionBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate");

  reactionBox:SetSize(20, 20)
  reactionBox:SetPoint("RIGHT", alignFrame, "LEFT", 0, 0);
  reactionBox:SetAutoFocus(false);
  reactionBox:SetTextColor(0.8, 0.5, 0.3)

  reactionBox:SetScript("OnEnterPressed",
      function(self)
        local reaction = self:GetText()
        local parent = self:GetParent()
        local text = parent.text:GetText()

        if reaction == "" then
          reaction = 0;
        end

        for _, item in ipairs(settings.profiles[settings.currentProfile]) do
          if item.itemName == text then
            item.reaction = tonumber(reaction)
          end
        end
        reactionBox:ClearFocus()
        self:SetText(tonumber(reaction));
        RS:Update()
      end);
  reactionBox:SetScript("OnKeyUp",
      function(self)
        local reaction = self:GetText()
        local parent = self:GetParent()
        local text = parent.text:GetText()

        if reaction == "" then
          reaction = 0;
        end

        for _, item in ipairs(settings.profiles[settings.currentProfile]) do
          if item.itemName == text then
            item.reaction = tonumber(reaction)
          end
        end
      end)

  -- Tooltip
  reactionBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Required vendor reputation (default 0 or empty)")
    GameTooltip:AddLine("Check player's reputation standing with the vendor before you buy")
    GameTooltip:AddLine("Neutral=4, Friendly=5, Honored=6, Revered=7, Exalted=8")
    GameTooltip:AddLine("Press Enter when finished editing")
    GameTooltip:Show()
  end)
  reactionBox:SetScript("OnLeave", function(self, motion)
    GameTooltip:Hide()
  end)

  -- Save the value
  frame.reactionBox = reactionBox
  frame:Show()

  return reactionBox;
end

---Create a X button which on click will remove the restocking item row
local function rsDeleteButton(frame)
  local settings = restockerModule.settings
  local delBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton");

  delBtn:SetPoint("RIGHT", frame, "RIGHT", 8, 0);
  delBtn:SetSize(30, 30);
  delBtn:SetScript("OnClick",
      function(self)
        local parent = self:GetParent();
        local text = parent.text:GetText();

        for i, item in ipairs(settings.profiles[settings.currentProfile]) do
          if item.itemName == text then
            tremove(settings.profiles[settings.currentProfile], i)
            RS:Update();
            break
          end
        end
      end);
  return delBtn;
end

---Create UI row for items
function RS:addListFrame()
  local frame = CreateFrame("Frame", nil, RS.hiddenFrame)
  frame.index = #RS.framepool + 1
  frame:SetSize(RS.MainFrame.scrollChild:GetWidth(), 20);

  if #RS.framepool == 0 then
    frame:SetPoint("TOP", RS.MainFrame.scrollChild, "TOP")
  else
    frame:SetPoint("TOP", RS.framepool[#RS.framepool], "BOTTOM")
  end

  RS.MainFrame.scrollChild:SetHeight(#RS.framepool * 20)

  -- ITEM TEXT
  local text = frame:CreateFontString(nil, "OVERLAY");
  text:SetFontObject("GameFontHighlight");
  text:SetPoint("LEFT", frame, "LEFT");
  frame.text = text

  -- BUTTON
  local delBtn = rsDeleteButton(frame)

  -- EDITBOX
  local amountBox = rsAmountEditBox(frame, delBtn)
  local reactionBox = rsRequireReactionEditBox(frame, amountBox)

  tinsert(RS.framepool, frame)
  return frame
end

function RS:addListFrames()
  local settings = restockerModule.settings

  for _, item in ipairs(settings.profiles[settings.currentProfile]) do
    local frame = RS:addListFrame()
    frame.text:SetText(item.itemName)
    frame.editBox:SetText(item.amount)
  end
end
