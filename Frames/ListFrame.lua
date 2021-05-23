---@type RestockerAddon
local _, RS = ...;

function RS:addListFrame()

  local frame = CreateFrame("Frame", nil, RS.hiddenFrame)
  frame.index = #RS.framepool + 1
  frame:SetSize(RS.addon.scrollChild:GetWidth(), 20);
  if #RS.framepool == 0 then
    frame:SetPoint("TOP", RS.addon.scrollChild, "TOP")
  else
    frame:SetPoint("TOP", RS.framepool[#RS.framepool], "BOTTOM")
  end
  RS.addon.scrollChild:SetHeight(#RS.framepool * 20)
  -- ITEM TEXT
  local text = frame:CreateFontString(nil, "OVERLAY");
  text:SetFontObject("GameFontHighlight");
  text:SetPoint("LEFT", frame, "LEFT");
  frame.text   = text

  -- BUTTON
  local delBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
  delBtn:SetPoint("RIGHT", frame, "RIGHT", 8, 0);
  delBtn:SetSize(30, 30);
  delBtn:SetScript("OnClick", function(self)
    local parent = self:GetParent();
    local text   = parent.text:GetText();

    for i, item in ipairs(Restocker.profiles[Restocker.currentProfile]) do
      if item.itemName == text then
        tremove(Restocker.profiles[Restocker.currentProfile], i)
        RS:Update();
        break
      end
    end

  end);

  -- EDITBOX
  local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate");
  editBox:SetSize(40, 20)
  editBox:SetPoint("RIGHT", delBtn, "LEFT", 3, 0);
  editBox:SetAutoFocus(false);
  editBox:SetScript("OnEnterPressed", function(self)
    local amount = self:GetText()
    local parent = self:GetParent()
    local text   = parent.text:GetText()

    if amount == "" then
      amount = 0;
    end

    for _, item in ipairs(Restocker.profiles[Restocker.currentProfile]) do
      if item.itemName == text then
        item.amount = tonumber(amount)
      end
    end
    editBox:ClearFocus()
    self:SetText(tonumber(amount));
    RS:Update()
    if RS.bankIsOpen then
      RS:BANKFRAME_OPENED(true)
    end

  end);
  editBox:SetScript("OnKeyUp", function(self)
    local amount = self:GetText()
    local parent = self:GetParent()
    local item   = parent.text:GetText()

    if amount == "" then
      amount = 0;
    end

    self:SetText(tonumber(amount));

    for _, item in ipairs(Restocker.profiles[Restocker.currentProfile]) do
      if item.itemName == text then
        item.amount = tonumber(amount)
      end
    end
  end)
  frame.editBox = editBox
  frame.isInUse = true
  frame:Show()

  tinsert(RS.framepool, frame)
  return frame
end

function RS:addListFrames()
  for _, item in ipairs(Restocker.profiles[Restocker.currentProfile]) do
    local frame = RS:addListFrame()
    frame.text:SetText(item.itemName)
    frame.editBox:SetText(item.amount)
  end
end
