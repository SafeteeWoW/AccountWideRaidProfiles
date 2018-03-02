local addonName = "AccountWideRaidProfiles"
local dbName = "AccountWideRaidProfilesDB"

local addon = LibStub("AceAddon-3.0"):NewAddon(addonName,"AceHook-3.0", "AceEvent-3.0", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local CVAR_FRAME_STYLE = "useCompactPartyFrames"
local DEFAULT_CUF_PROFILE_NAME = "Primary"

local RAID_CONTAINER_WIDTH = 300
local MINIMUM_RAID_CONTAINER_HEIGHT = 86

local MINIMUM_RAID_BLOCK_WIDTH  = 72
local MAXIMUM_RAID_BLOCK_WIDTH  = 144
local MINIMUM_RAID_BLOCK_HEIGHT = 36
local MAXIMUM_RAID_BLOCK_HEIGHT = 72

local ADDON_INACTIVE_PROFILE = "ADDON_INACTIVE"

local ADDON_RELOAD_DIALOG = "ACCOUNT_WIDE_RAID_PROFILES_RELOAD_DIALOG"

local function ShallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end



StaticPopupDialogs[ADDON_RELOAD_DIALOG] = {
    text = "Account Wide Raid Profiles has applied changes to the raid profile settings. Reloading the user interface is required to avoid tainting the raid frame. Do you want to reload now?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        ReloadUI()
    end, 
    OnCancel = function(self)
       addon:Print("The user interface is not reloaded. The addon has applied new raid profile settings, but has tainted the raid frame that may cause it not responding to user input. To fix it, enter \"\/reload\" in chat.")
        end,
    timeout = 0,
    hideOnEscape = 1,
}

function addon:OnInitialize()
   addon:RegisterEvent("COMPACT_UNIT_FRAME_PROFILES_LOADED")
   self.needReload = false
   self.disableOptionPanelUpdate = false
   self.inCombat = false
   self.isOptionOpen = false
   self.db = LibStub("AceDB-3.0"):New(dbName)
   self.initialized = false
   local addonOption = addon:SetUpOptionsPanel(addonOption)
   LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, addonOption, {"awrp"})
   self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName)
   addon:HookAll()
end



function addon:COMPACT_UNIT_FRAME_PROFILES_LOADED(...)
   if (not self.db.profile.profiles) then 
      addon:StoreAll()
      self.initialized  = true
   else
      if (addon:IsAddonActive()) then
         local tempProfile = {}
         addon:StoreAllToProfile(tempProfile)
         if not addon:isProfilesEqual(self.db.profile, tempProfile) then
		 addon:LoadAll()
            addon:ReloadDialog()
         else
            self.initialized  = true
         end
      else
         addon:StoreAll()
         self.initialized  = true
      end
      self.initialized  = true
   end
   addon:HookAll()
end

function addon:ShowRaidFrameWhenSolo()
   if ((not self.inCombat) and (not IsInGroup()) and GetCVar(CVAR_FRAME_STYLE) == '1' ) then
      CompactRaidFrameContainer:Show()
      CompactRaidFrameManager:Show()
   end
end

function addon:HideRaidFrameWhenSolo()
   if ((not self.inCombat) and (not IsInGroup()) and GetCVar(CVAR_FRAME_STYLE) == '1' ) then
      CompactRaidFrameContainer:Hide()
      CompactRaidFrameManager:Hide()
   end
end

function addon:OnOptionShow()
   self.isOptionOpen = true
end 

function addon:OnOptionHide()
   self.isOptionOpen = false
   if (self.needReload) then
      self.needReload = false
	 addon:HideRaidFrameWhenSolo()
      addon:ReloadDialog()
   end
end

function addon:HookAll()
   addon:UnhookAll()
   self.db.RegisterCallback(self, "OnProfileReset", "ResetProfiles")
   self.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfiles")
   self.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfiles")


   addon:RegisterEvent("PLAYER_REGEN_DISABLED")
   addon:RegisterEvent("PLAYER_REGEN_ENABLED")
   addon:SecureHookScript(self.optionsFrame, "OnShow", "OnOptionShow")
   addon:SecureHookScript(self.optionsFrame, "OnHide", "OnOptionHide")

   if (addon:IsAddonActive() and self.initialized) then
      addon:SecureHook("SetRaidProfileSavedPosition","StorePosition")
      addon:SecureHook("CompactUnitFrameProfiles_ApplyProfile", "StoreAll")
      addon:SecureHook("SetCVar", "StoreFrameStyleChanges")
   end
end

function addon:GetActiveRaidProfileId()
   for i=1, GetNumRaidProfiles() do
      if self.db.profile.lastProfile == self.db.profile.profiles[i] then
         return i
      end
   end
   return 1
end

function addon:PLAYER_REGEN_DISABLED()
   self.inCombat = true
end

function addon:PLAYER_REGEN_ENABLED()
   self.inCombat = false
end

-- Unsecure function. Need reload somewhere after calling this function.
function addon:UnlockFrame()
   if (not self.inCombat) then
 CompactRaidFrameManagerDisplayFrameLockedModeToggle:SetText(UNLOCK)
      CompactRaidFrameManagerDisplayFrameLockedModeToggle.lockMode = false
      CompactRaidFrameManager_UpdateContainerLockVisibility(CompactRaidFrameManager)
      CompactRaidFrameContainer_UpdateDisplayedUnits(CompactRaidFrameContainer)
      CompactRaidFrameContainer_TryUpdate(CompactRaidFrameContainer)
      RaidOptionsFrame_UpdatePartyFrames() 
      CompactRaidFrameManager_UpdateShown(CompactRaidFrameManager)
      if (self.isOptionOpen) then
         addon:ShowRaidFrameWhenSolo()
      end
   end
end

function addon:RefreshProfiles()
   self.needReload = true
   addon:UnhookAll()
   if (not self.db.profile.profiles) then
      addon:ResetProfiles()
   else
      addon:LoadAll()
   end
   if (self.isOptionOpen) then
      addon:ShowRaidFrameWhenSolo()
   end
   addon:HookAll()
end

function addon:ResetProfiles()
   self.needReload = true
   addon:UnhookAll()
   local profiles = {}
   for i=1, GetNumRaidProfiles() do
      tinsert(profiles, GetRaidProfileName(i))
   end
   for i=1, #profiles do
      DeleteRaidProfile(profiles[i])
   end
   CreateNewRaidProfile(DEFAULT_CUF_PROFILE_NAME)
   SetActiveRaidProfile(DEFAULT_CUF_PROFILE_NAME)
   SetCVar(CVAR_FRAME_STYLE, false)
   addon:StoreAll()
   addon:HookAll()
   if (self.isOptionOpen) then
      addon:ShowRaidFrameWhenSolo()
   end
end

function addon:IsAddonActive()
   return true -- Change this in the future
end

----------------------- Load and store raid prorfiles ---------------------------

function addon:LoadAll(...)
   if (addon:IsAddonActive()) then
      addon:UnhookAll()
      local profiles = {}
      for i=1, GetNumRaidProfiles() do
         tinsert(profiles, GetRaidProfileName(i))
      end
      for i=1, #profiles do
         DeleteRaidProfile(profiles[i])
      end
      
      SetCVar(CVAR_FRAME_STYLE, self.db.profile.frameStyle)
      
      profiles = self.db.profile.profiles
      local options = self.db.profile.options
      local positions = self.db.profile.positions
      
      for i=1, #profiles do
         local profile = profiles[i]
         CreateNewRaidProfile(profile)
         for option, value in pairs(options[i]) do
            SetRaidProfileOption(profile, option, value)
         end
         SetRaidProfileSavedPosition(profile, unpack(positions[i]))
      end
      
      SetActiveRaidProfile(self.db.profile.lastProfile)

      CompactUnitFrameProfiles_ValidateProfilesLoaded(CompactUnitFrameProfiles)
      addon:UpdateOptionsPanel()
   end
end

function addon:StoreFrameStyleChanges(glStr, value)
   if glStr == CVAR_FRAME_STYLE and not self.isOptionOpen then
      self.db.profile.frameStyle = value
   end
end

function addon:StorePosition(...)
   args = {...}
   for i=1, #self.db.profile.positions do
      if self.db.profile.profiles[i] == args[1] then
         self.db.profile.positions[i] = {select(2,unpack(args))}
      end
   end
   if (not self.disableOptionPanelUpdate) then
      addon:UpdateOptionsPanel()
   end
end

function addon:StoreAllToProfile(db)
   local profiles = {}
   for i=1, GetNumRaidProfiles() do
      tinsert(profiles, GetRaidProfileName(i))
   end
   
   db.frameStyle = GetCVar(CVAR_FRAME_STYLE)
   db.profiles = profiles
   db.options = {}
   db.positions = {}
   db.lastProfile = GetActiveRaidProfile()

   for i=1, #profiles do
      local profile = profiles[i]
      db.options[i] = GetRaidProfileFlattenedOptions(profile)
      db.positions[i] = {GetRaidProfileSavedPosition(profile)}
   end

   if (not self.disableOptionPanelUpdate) then
      addon:UpdateOptionsPanel()
   end
end

function addon:StoreAll()
   addon:StoreAllToProfile(self.db.profile)
end

function addon:isProfilesEqual(p1, p2)
   if ((not p1) or (not p2)) then return false end
   if (p1.frameStyle ~= p2.frameStyle) then return false end
   if (#p1.profiles ~= #p2.profiles) then return false end
   if (#p1.options ~= #p2.options) then return false end
   if (#p1.positions ~= #p2.positions) then return false end

   for i=1, #p1.profiles do
      if (p1.profiles[i] ~= p2.profiles[i]) then return false end
      if (#p1.options[i] ~= #p2.options[i]) then return false end
      if (#p1.positions[i] ~= #p2.positions[i]) then return false end
      for  j,_ in pairs(p1.options[i]) do
         if (p1.options[i][j] ~= p2.options[i][j]) then
            return false
      end end
      for j=1,#p1.positions[i] do
         a = p1.positions[i][j]
         b = p2.positions[i][j]
         na = tonumber(a)
         nb = tonumber(b)
         if ((not na) and (not nb) and (a ~= b)) then
            return false
         end
         if (na and nb and math.abs(na-nb) > 1) then
            return false
      end end
   end
   
   return true
end

function addon:ReloadDialog()
	StaticPopup_Show(ADDON_RELOAD_DIALOG)
end

---------------------------- Option panel ----------------------------------------------
function addon:UpdateOptionsPanel()
   local addonOption = addon:SetUpOptionsPanel(addonOption)
   LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, addonOption, {"awrp", addonName})
   LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
end

function addon:SetUpOptionsPanel()
   local option = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
   option = ShallowCopy(option)
   option.name = "Account Wide Raid Profiles"
   option.desc = "Manage Profiles and extra options of Account Wide Raid Profiles"
   option.args = ShallowCopy(option.args)
   option.args.rp =  {
      type = "execute",
      name = "rp",
      desc = "Open blizzard raid profile settings.",
      guiHidden = true,
      func = function()
         InterfaceOptionsFrame_OpenToCategory(_G["CompactUnitFrameProfiles"])
         end
   }
   option.args.config =  {
      type = "execute",
      name = "config",
      desc = "Open addon config panel.",
      guiHidden = true,
      func = function()
         InterfaceOptionsFrame_OpenToCategory(addonName)
         InterfaceOptionsFrame_OpenToCategory(addonName)
         end
   }
   option.args.space0 = {
    name = "",
    type = 'description',
    width = 'full',
    cmdHidden = true,
    order = 100,
   }
   option.args.configButton = {
      order = 110,
      type = "execute",
      name = "Open Raid Profile Option",
      desc = "Open Blizzard raid profile option.",
      width = "double",
      cmdHidden = true,
      func = function()
         InterfaceOptionsFrame_OpenToCategory(_G["CompactUnitFrameProfiles"])
      end
   }
   option.args.descChange = {
    name = "The raid frame is always shown when you adjust it in this panel.\n",
    type = 'description',
    width = 'full',
    cmdHidden = true,
    order = 111,
   }
   option.args.currentProfile = {
      order = 112,
      type = "description",
      name = function(info) return "Current Raid Profile: " .. " " 
                        .. NORMAL_FONT_COLOR_CODE 
                        .. GetActiveRaidProfile()
                        .. FONT_COLOR_CODE_CLOSE .."\n" end,
      width = "double",
   }
   option.args.frameStyle = {
      order = 113,
      type = "toggle",
      name = "Use Raid-Style Party Frames",
      desc = "Use Party Frames in the same style as the Raid Frames. These frames obey your Raid Frame options.",
      get = function(info) return GetCVar(CVAR_FRAME_STYLE) == "1" end,
      set = function(info, val) 
      			if val then 
      				SetCVar(CVAR_FRAME_STYLE, "1")
      				if CompactUnitFrameProfilesRaidStylePartyFrames then
						CompactUnitFrameProfilesRaidStylePartyFrames:SetChecked(true)
      				end
      			else 
      				SetCVar(CVAR_FRAME_STYLE, "0")
      				if CompactUnitFrameProfilesRaidStylePartyFrames then
						CompactUnitFrameProfilesRaidStylePartyFrames:SetChecked(false)
      				end
       			end 
       end,
      width = "double",
   }
   option.args.isAttached = 
   {
      order = 114,
      type = "toggle",
      name = "Attach frame",
      desc = "If Raid frame attaches to the raid panel on the left edge of the screen.",
      get = function(info) return addon:GetOption(info[#info]) end,
      set = function(info, val) addon:SetOption(info[#info], val) end,
      width = "normal"
   }
   option.args.xOffset = {
      order = 115,
      name = "x Offset",
      desc = "Pixels between the left of the screen and the topleft corner of the frame container.",
      type = "range",
      min = 0,
      step = 1,
      disabled = function(...) return addon:GetOption("isAttached") end,
      max = math.floor(GetScreenWidth()-RAID_CONTAINER_WIDTH),
      width = "normal",
      get = function(info) return addon:GetOption(info[#info]) end,
      set = function(info, val) addon:SetOption(info[#info], val) end
   }
   option.args.yOffset = {
      order = 120,
      name = "y Offset",
      desc = "Pixels between the bottom of the screen and the topleft corner of the frame container.",
      type = "range",
      min = MINIMUM_RAID_CONTAINER_HEIGHT,
      step = 1,
      disabled = function(...) return addon:GetOption("isAttached") end,
      max = math.floor(GetScreenHeight()),
      get = function(info) return addon:GetOption(info[#info]) end,
      set = function(info, val) addon:SetOption(info[#info], val) end
   }
   option.args.spacer3 = {
    name = "",
    type = 'description',
    width = 'full',
    cmdHidden = true,
    order = 125,
   }
   option.args.frameHeight = {
      order = 130,
      name = "Frame Height",
      desc = "Height of the frame block.",
      type = "range",
      min = MINIMUM_RAID_BLOCK_HEIGHT,
      step = 1,
      max = MAXIMUM_RAID_BLOCK_HEIGHT,
      get = function(info) return addon:GetOption(info[#info]) end,
      set = function(info, val) addon:SetOption(info[#info], val) end
   }
   option.args.frameWidth = {
      order = 135,
      name = "Frame Width",
      desc = "Width of the frame block.",
      type = "range",
      min = MINIMUM_RAID_BLOCK_WIDTH,
      step = 1,
      max = MAXIMUM_RAID_BLOCK_WIDTH,
      get = function(info) return addon:GetOption(info[#info]) end,
      set = function(info, val) addon:SetOption(info[#info], val) end
   }
   option.args.containerHeight = {
      order = 140,
      name = "Container Height",
      desc = "Pixels of the height of the frame container.",
      type = "range",
      min = MINIMUM_RAID_CONTAINER_HEIGHT,
      step = 1,
      max = math.floor(math.min(GetScreenHeight()-90,addon:GetOption("yOffset"))),
      get = function(info) return addon:GetOption(info[#info]) end,
      set = function(info, val) addon:SetOption(info[#info], val) end
   }
   return option
end

function addon:GetOption(optionName)

   local manager = CompactRaidFrameManager
   local top = manager.containerResizeFrame:GetTop()
   local bottom = manager.containerResizeFrame:GetBottom()
   local isAttached = (select(2, manager.containerResizeFrame:GetPoint(1)) == manager)
   local left = manager.containerResizeFrame:GetLeft()
   
   if (optionName == "isAttached") then
      return isAttached
   elseif (optionName == "xOffset") then
      return math.floor(left)
   elseif (optionName == "yOffset") then
      return math.floor(top)
   elseif (optionName == "containerHeight") then
      return math.floor(top-bottom)
   elseif (optionName == "frameWidth") then
      return self.db.profile.options[addon:GetActiveRaidProfileId()]["frameWidth"]
   elseif (optionName == "frameHeight") then
      return self.db.profile.options[addon:GetActiveRaidProfileId()]["frameHeight"]
   end
end

function addon:SetOption(optionName, value)
   if not self.inCombat then
      self.disableOptionPanelUpdate = true

      self.needReload = true
      if (optionName == "frameWidth") then
         SetRaidProfileOption(GetActiveRaidProfile(), "frameWidth", value)
         CompactUnitFrameProfiles_ApplyCurrentSettings()
      elseif (optionName == "frameHeight") then
         SetRaidProfileOption(GetActiveRaidProfile(), "frameHeight", value)
         CompactUnitFrameProfiles_ApplyCurrentSettings()
      else
         local manager = CompactRaidFrameManager
         if (optionName == "isAttached") then
            manager.dynamicContainerPosition = value
         end
         if ( manager.dynamicContainerPosition ) then
            SetRaidProfileSavedPosition(GetActiveRaidProfile(), true)
         else
            local topPoint, topOffset
            local bottomPoint, bottomOffset
            local leftPoint, leftOffset
            
            local screenHeight = GetScreenHeight()
            local top = manager.containerResizeFrame:GetTop()
            local topDifference = 0
            if (optionName == "yOffset") then
               topDifference  = value - top        
               top = value
            end
            if ( top > screenHeight / 2 ) then
               topPoint = "TOP"
               topOffset = screenHeight - top
            else
               topPoint = "BOTTOM"
               topOffset = top
            end
            
            local bottom = manager.containerResizeFrame:GetBottom()
            if (optionName == "yOffset") then
               bottom = bottom + topDifference
               if (bottom < 0) then
                  bottom = 0
               end
            elseif (optionName == "containerHeight") then
               bottom = top - value
            end
            if ( bottom > screenHeight / 2 ) then
               bottomPoint = "TOP"
               bottomOffset = screenHeight - bottom
            else
               bottomPoint = "BOTTOM"
               bottomOffset = bottom
            end
            
            local isAttached = (select(2, manager.containerResizeFrame:GetPoint(1)) == manager)
            if (optionName == "isAttached") then
              isAttached = value
            end
            if ( isAttached ) then
               leftPoint = "ATTACHED"
               leftOffset = 0
            else
               local screenWidth = GetScreenWidth()
               local left = manager.containerResizeFrame:GetLeft()
               if (optionName == "xOffset") then
                  left = value
               end
               if ( left > screenWidth / 2 ) then
                  leftPoint = "RIGHT"
                  leftOffset = screenWidth - left
               else
                  leftPoint = "LEFT"
                  leftOffset = left
               end
            end
      
            SetRaidProfileSavedPosition(GetActiveRaidProfile(), false
               , topPoint, topOffset, bottomPoint, bottomOffset, leftPoint, leftOffset)
         end
         CompactRaidFrameManager_ResizeFrame_LoadPosition(CompactRaidFrameManager)
      end
      self.disableOptionPanelUpdate = false
      addon:UnlockFrame()
      addon:UpdateOptionsPanel()
   else
      addon:Print("Cannot change options in combat.")
   end
end