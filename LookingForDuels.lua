--------------------------------------------------------------------------------
--                      L O O K I N G   F O R   D U E L S                     --
--------------------------------------------------------------------------------
--				  Copyright 2017-2019 Dylan Fortune (Crieve-Atiesh)           --
--------------------------------------------------------------------------------
-- Localization
local L = {
	TITLE = "|cffb4b4ffLookingForDuels|r",
	TITLE_NOCOLOR = "LookingForDuels",
	PREFIX = "|cffb4b4ffLFD|r",
	ICON = "Interface\\ICONS\\Ability_Warrior_Challange",
	DESCRIPTION = "Tracks your Duel History and Ranking.",
	MINIMAP_MOUSEOVER_TEXT = "Left Click to Open your Character's Duels tab.\nRight Click to Open the Settings Menu.",
	DUEL_CURRENT_TARGET = "Duel Current Target",
	DUEL_ACCEPT = "Accept Duel",
	DUEL_DECLINE = "Decline Duel",
	SHOW_MINIMAP_BUTTON = "Show the Minimap Button",
	SYNC_TARGET = "Synchronize Target",
	SYNC_ALL = "Synchronize All Data",
	TAB_GENERAL = "General",
	TOGGLE_UI = "Toggle UI",
	TOGGLE_SETTINGS_UI = "Toggle Settings UI",
	TOOLTIP_SHOW_MINIMAP_BUTTON = "Enable this option if you want to see the minimap button. This button allows you to quickly access the settings or information panels.",
	USER_INTERFACE_SETTINGS = "User Interface Settings",
	YOU_LOSE = "YOU LOSE!",
	YOU_LOSE_OUT = "YOU LOSE! (OUT OF BOUNDS)",
	YOU_WIN = "YOU WIN!",
	YOU_WIN_OUT = "YOU WIN! (OUT OF BOUNDS)",
};
local ADDON_PATH = "Interface\\Addons\\LookingForDuels";

-- Bindings
BINDING_HEADER_LFDUELS = L.TITLE;
BINDING_NAME_LFDUELS_DUELTARGET = L.DUEL_CURRENT_TARGET;
BINDING_NAME_LFDUELS_DUEL_ACCEPT = L.DUEL_ACCEPT;
BINDING_NAME_LFDUELS_DUEL_DECLINE = L.DUEL_DECLINE;
BINDING_NAME_LFDUELS_SYNC_TARGET = L.SYNC_TARGET;
BINDING_NAME_LFDUELS_SYNC_ALL = L.SYNC_ALL;
BINDING_NAME_LFDUELS_TOGGLE_UI = L.TOGGLE_UI;
BINDING_NAME_LFDUELS_TOGGLE_SETTINGS_UI = L.TOGGLE_SETTINGS_UI;

-- Frames
local app = select(2, ...);
LookingForDuelsAPI = app;
local events = {};
app.events = events;
local _ = CreateFrame("FRAME", L.TITLE, UIParent);
_:SetScript("OnEvent", function(self, e, ...) (rawget(events, e) or print)(...); end);
_:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", 0, 0);
_:RegisterEvent("VARIABLES_LOADED");
_:RegisterEvent("DUEL_REQUESTED");
_:RegisterEvent("CHAT_MSG_ADDON");
_:SetSize(1, 1);
_:Show();

-- The Settings Frame
local SettingsFrame = CreateFrame("FRAME", _:GetName() .. "-SettingsFrame", UIParent );
SettingsFrame.name = L.TITLE_NOCOLOR;
SettingsFrame.MostRecentTab = nil;
SettingsFrame.Tabs = {};
SettingsFrame:SetBackdrop({
	bgFile = "Interface/RAIDFRAME/UI-RaidFrame-GroupBg", 
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
	tile = false, edgeSize = 16, 
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
});
SettingsFrame:SetBackdropColor(0, 0, 0, 1);
InterfaceOptions_AddCategory(SettingsFrame);
SettingsFrame.CreateCheckBox = function(self, text, OnRefresh, OnClick)
	local cb = CreateFrame("CheckButton", self:GetName() .. "-" .. text, self, "InterfaceOptionsCheckButtonTemplate");
	table.insert(self.MostRecentTab.objects, cb);
	cb:SetScript("OnClick", OnClick);
	cb.OnRefresh = OnRefresh;
	cb.Text:SetText(text);
	return cb;
end
SettingsFrame.CreateTab = function(self, text)
	local id = #self.Tabs + 1;
	local tab = CreateFrame('Button', self:GetName() .. '-Tab' .. id, self, 'OptionsFrameTabButtonTemplate');
	if id > 1 then tab:SetPoint("TOPLEFT", self.Tabs[id - 1], "TOPRIGHT", 0, 0); end
	table.insert(self.Tabs, tab);
	self.MostRecentTab = tab;
	tab.objects = {};
	tab:SetID(id);
	tab:SetText(text);
	PanelTemplates_TabResize(tab, 0);
	tab:SetScript('OnClick', OnClickForTab);
	return tab;
end
SettingsFrame.Initialize = function(self)
	PanelTemplates_SetNumTabs(self, #self.Tabs);
	self:Refresh();
end
SettingsFrame.Open = function(self)
	-- Open the Options menu.
	if InterfaceOptionsFrame:IsVisible() then
		InterfaceOptionsFrame_Show();
	else
		InterfaceOptionsFrame_OpenToCategory(self.name);
		InterfaceOptionsFrame_OpenToCategory(self.name);
	end
end
SettingsFrame.Refresh = function(self)
	for i,tab in ipairs(self.Tabs) do
		if tab.OnRefresh then tab:OnRefresh(); end
		for j,o in ipairs(tab.objects) do
			if o.OnRefresh then o:OnRefresh(); end
		end
	end
end

-- Settings Top Bar
local f = SettingsFrame:CreateTexture(nil, "ARTWORK");
f:SetPoint("TOPLEFT", SettingsFrame, "TOPLEFT", 8, -8);
f:SetTexture(L.ICON);
f:SetSize(36, 36);
f:Show();
SettingsFrame.logo = f;

f = SettingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
f:SetPoint("TOPLEFT", SettingsFrame.logo, "TOPRIGHT", 4, -4);
f:SetJustifyH("LEFT");
f:SetText(L.TITLE);
f:SetScale(1.5);
f:Show();
SettingsFrame.title = f;

f = SettingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
f:SetPoint("TOPRIGHT", SettingsFrame, "TOPRIGHT", -8, -8);
f:SetJustifyH("RIGHT");
f:SetText("Crieve-Atiesh\nv" .. GetAddOnMetadata("LookingForDuels", "Version"));
f:Show();
SettingsFrame.version = f;

------------------------------------------
-- The "General" Tab.					--
------------------------------------------
local line;
(function()
local tab = SettingsFrame:CreateTab(L.TAB_GENERAL);
tab:SetPoint("TOPLEFT", SettingsFrame.logo, "BOTTOMRIGHT", 16, 0);
local line = SettingsFrame:CreateTexture(nil, "ARTWORK");
line:SetPoint("LEFT", SettingsFrame, "LEFT", 4, 0);
line:SetPoint("RIGHT", SettingsFrame, "RIGHT", -4, 0);
line:SetPoint("TOP", tab, "BOTTOM", 0, 0);
line:SetColorTexture(1, 1, 1, 0.4);
line:SetHeight(2);

local ModeLabel = SettingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
table.insert(SettingsFrame.MostRecentTab.objects, ModeLabel);
ModeLabel:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 8, -8);
ModeLabel:SetJustifyH("LEFT");
ModeLabel:SetText(L.USER_INTERFACE_SETTINGS);
ModeLabel:Show();

local ShowMinimapButtonCheckBox = SettingsFrame:CreateCheckBox(L.SHOW_MINIMAP_BUTTON,
function(self)
	self:SetChecked(LookingForDuelsData.ShowMinimapButton);
	if LookingForDuelsData.ShowMinimapButton then
		LibStub("LibDBIcon-1.0"):Show("LFDUELS");
	else
		LibStub("LibDBIcon-1.0"):Hide("LFDUELS");
	end
end,
function(self)
	LookingForDuelsData.ShowMinimapButton = self:GetChecked();
	SettingsFrame:Refresh();
end);
ShowMinimapButtonCheckBox:SetATTTooltip(L.TOOLTIP_SHOW_MINIMAP_BUTTON);
ShowMinimapButtonCheckBox:SetPoint("TOPLEFT", ModeLabel, "BOTTOMLEFT", 0, -8);
end)();

-- Coroutine Helper Functions
app.refreshing = {};
local function OnUpdate(self)
	for i=#self.__stack,1,-1 do
		if not self.__stack[i][1](self) then
			table.remove(self.__stack, i);
			if #self.__stack < 1 then
				self:SetScript("OnUpdate", nil);
			end
		end
	end
end
local function Push(self, name, method)
	if not self.__stack then
		self.__stack = {};
		self:SetScript("OnUpdate", OnUpdate);
	elseif #self.__stack < 1 then 
		self:SetScript("OnUpdate", OnUpdate);
	end
	table.insert(self.__stack, { method, name });
end
local function StartCoroutine(name, method)
	if method and not app.refreshing[name] then
		local instance = coroutine.create(method);
		app.refreshing[name] = instance;
		Push(_, name, function()
			-- Check the status of the coroutine
			if instance and coroutine.status(instance) ~= "dead" then
				local ok, err = coroutine.resume(instance);
				if ok then return true;	-- This means more work is required.
				else
					-- Show the error. Returning nothing is the same as canceling the work.
					print(err);
				end
			end
			app.refreshing[name] = nil;
		end);
	end
end
local function StopAllCoroutines()
	for i=#_.__stack,1,-1 do
		table.remove(_.__stack, i);
	end
	_:SetScript("OnUpdate", nil);
end
local function StopCoroutine(name)
	if app.refreshing[name] then
		for i=#_.__stack,1,-1 do
			if _.__stack[i][2] == name then
				table.remove(_.__stack, i);
			end
		end
		app.refreshing[name] = nil;
	end
end

-- Temporary Variables
local CachedDuels, WinsByGUID, LossesByGUID = {}, {}, {};
local RealmName, RealmGUIDs, PlayerData, PlayerGUID = GetRealmName();

-- Color Lib
local CS = CreateFrame("ColorSelect", nil, app._);
local function Colorize(str, color)
	return "|c" .. color .. str .. "|r";
end
local function HexToARGB(hex)
	return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6)), tonumber("0x"..hex:sub(7,8));
end
local function HexToRGB(hex)
	return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6));
end
local function RGBToHex(r, g, b)
	return string.format("ff%02x%02x%02x", 
		r <= 255 and r >= 0 and r or 0, 
		g <= 255 and g >= 0 and g or 0, 
		b <= 255 and b >= 0 and b or 0);
end
local function ConvertColorRgbToHsv(r, g, b)
  CS:SetColorRGB(r, g, b);
  local h,s,v = CS:GetColorHSV()
  return {h=h,s=s,v=v}
end
local red, green = ConvertColorRgbToHsv(1,0,0), ConvertColorRgbToHsv(0,1,0);
local progress_colors = setmetatable({[1] = "ff15abff"}, {
	__index = function(t, p)
		local h;
		p = tonumber(p);
		if abs(red.h - green.h) > 180 then
			local angle = (360 - abs(red.h - green.h)) * p;
			if red.h < green.h then
				h = floor(red.h - angle);
				if h < 0 then h = 360 + h end
			else
				h = floor(red.h + angle);
				if h > 360 then h = h - 360 end
			end
		else
			h = floor(red.h-(red.h-green.h)*p)
		end
		CS:SetColorHSV(h, red.s-(red.s-green.s)*p, red.v-(red.v-green.v)*p);
		local r,g,b = CS:GetColorRGB();
		local color = RGBToHex(r * 255, g * 255, b * 255);
		rawset(t, p, color);
		return color;
	end
});
local function GetNumberWithZeros(number, desiredLength)
	if desiredLength > 0 then
		local str = tostring(number);
		local length = string.len(str);
		local pos = string.find(str,"[.]");
		if not pos then
			str = str .. ".";
			for i=desiredLength,1,-1 do
				str = str .. "0";
			end
		else
			local totalExtra = desiredLength - (length - pos);
			for i=totalExtra,1,-1 do
				str = str .. "0";
			end
			if totalExtra < 1 then
				str = string.sub(str, 1, pos + desiredLength);
			end
		end
		return str;
	else
		return tostring(floor(number));
	end
end
local function GetProgressText(progress, total)
	return tostring(progress) .. " / " .. tostring(total);
end
local function GetProgressColor(p)
	return progress_colors[p];
end
local function GetProgressColorText(progress, total)
	if total and total > 0 then
		local percent = progress / total;
		return "|c" .. GetProgressColor(percent) .. GetProgressText(progress, total) .. " (" .. GetNumberWithZeros(percent * 100, 2) .. "%) |r";
	end
end

-- Class Prototypes
local DefaultSettings = { __index = {
	BattleAudioEnabled = true,
	BattleAudioOptions = {
		"battle1.ogg"
	},
	DefeatAudioEnabled = true,
	DefeatAudioOptions = {
		"defeat1.ogg"
	},
	OutOfBoundsAudioEnabled = true,
	OutOfBoundsAudioOptions = {
		"outofbounds1.ogg"
	},
	ShowMinimapButton = true,
	SoundEffectsChannel = "SFX",
	VictoryAudioEnabled = true,
	VictoryAudioOptions = {
		"victory1.ogg"
	},
}};
local DuelClass = { __index = function(t, key)
	if key == "text" then
		local winner, loser = t.winner, t.loser;
		if winner and loser then
			return winner.text .. " vs. " .. loser.text .. " (" .. t.datetime .. ")";
		end
		return RETRIEVING_DATA;
	elseif key == "winner" then
		return rawget(LookingForDuelsData.CachedCharacterData, t.winnerGUID);
	elseif key == "loser" then
		return rawget(LookingForDuelsData.CachedCharacterData, t.loserGUID);
	elseif key == "winnerGUID" then
		return "???";
	elseif key == "loserGUID" then
		return "???";
	elseif key == "outofrange" then
		return false;
	elseif key == "timestamp" then
		return 0;
	elseif key == "datetime" then
		return date("%c", t.timestamp);
	end
end};
local OpponentClass = { __index = function(t, key)
	if key == "name" then
		return "???";
	elseif key == "lvl" then
		local name = t.name;
		if name then
			local lvl = UnitLevel(t.name);
			if lvl then
				rawset(t, key, name);
				return lvl;
			end
			return 1;
		end
		return 0;
	elseif key == "class" then
		local name = t.name;
		if name then
			local class = select(3, UnitClass(name));
			if class then
				rawset(t, key, class);
				return class;
			end
		end
	elseif key == "race" then
		local name = t.name;
		if name then
			local race = select(3, UnitRace(name));
			if race then
				rawset(t, key, race);
				return race;
			end
		end
	elseif key == "faction" then
		local name = t.name;
		if name then
			local faction = UnitFactionGroup("target");
			if faction then
				rawset(t, key, faction);
				return faction;
			end
		end
	elseif key == "realm" then
		return RealmName;
	elseif key == "text" then
		local classInfo = C_CreatureInfo.GetClassInfo(t.class);
		local raceInfo = C_CreatureInfo.GetRaceInfo(t.race);
		return "|c" .. (RAID_CLASS_COLORS[classInfo.classFile].colorStr or "ff1eff00") .. t.name .. " (Level " .. (t.lvl or "??") .. " " .. (raceInfo.raceName or "??").. " " .. (classInfo.className or "??") .. ")|r";
	end
end};
function CreateOpponent(target)
	return setmetatable({
		["name"] = UnitName(target),
		["lvl"] = UnitLevel(target),
		["class"] = select(3, UnitClass(target)),
		["race"] = select(3, UnitRace(target)),
		["faction"] = UnitFactionGroup(target),
	}, OpponentClass);
end

-- Functionality
function Print(...)
	print(L.PREFIX .. ":", ...);
end
function PlayAddonMusic(music)
	if music then
		PlayMusic(ADDON_PATH .. "\\media\\audio\\" .. music);
	end
end
function PlayRandomMusic(audioTable)
	if audioTable then PlayAddonMusic(audioTable[math.random(1, #audioTable)]); end
end
function PlayAddonSound(soundEffect)
	if soundEffect then PlaySoundFile(ADDON_PATH .. "\\media\\audio\\" .. soundEffect, LookingForDuelsData.SoundEffectsChannel); end
end
function PlayRandomSound(audioTable)
	if audioTable then PlayAddonSound(audioTable[math.random(1, #audioTable)]); end
end
function PlayBattleMusic()
	if LookingForDuelsData.BattleAudioEnabled then
		PlayRandomMusic(LookingForDuelsData.BattleAudioOptions);
	end
end
function PlayDefeatSound()
	if LookingForDuelsData.DefeatAudioEnabled then
		PlayRandomSound(LookingForDuelsData.DefeatAudioOptions);
	end
end
function PlayVictorySound()
	if LookingForDuelsData.VictoryAudioEnabled then
		PlayRandomSound(LookingForDuelsData.VictoryAudioOptions);
	end
end
local function SendGroupAddonMessage(msg)
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then
		C_ChatInfo.SendAddonMessage("LFDUELS", msg, "INSTANCE_CHAT")
	elseif IsInRaid() then
		C_ChatInfo.SendAddonMessage("LFDUELS", msg, "RAID")
	elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
		C_ChatInfo.SendAddonMessage("LFDUELS", msg, "PARTY")
	end
end
local function SendTargetAddonMessage(msg, target)
	C_ChatInfo.SendAddonMessage("LFDUELS", msg, "WHISPER", target or UnitName("target"));
end
local function AttachTooltip(self)
	if not self.LFDUELSPROCESSING and not InCombatLockdown() then
		self.LFDUELSPROCESSING = true;
		local numLines = self:NumLines();
		if numLines > 0 then
			-- Does the tooltip have a target?
			local target = select(2, self:GetUnit());
			if target and UnitIsPlayer(target) then
				-- Yes.
				target = UnitGUID(target);
				if target then
					local wins, losses = WinsByGUID[target] or 0, LossesByGUID[target] or 0;
					local total = wins + losses;
					if total > 0 then
						self:AddDoubleLine(L.TITLE, GetProgressColorText(wins, total));
					end
				end
			end
		end
	end
end
local function ClearTooltip(self)
	self.LFDUELSPROCESSING = nil;
end
function CacheDuel(duelString, newData)
	if not CachedDuels[duelString] then
		local timestamp, winner, loser, out = strsplit("_", duelString);
		-- print(timestamp .. " : " .. winner .. " : " .. loser .. " : " .. (out and 1 or 0));
		local duel = setmetatable({
			["winnerGUID"] = winner,
			["loserGUID"] = loser,
			["timestamp"] = timestamp,
			["outofrange"] = out and true or false
		}, DuelClass);
		CachedDuels[duelString] = duel;
		WinsByGUID[winner] = (WinsByGUID[winner] or 0) + 1;
		LossesByGUID[loser] = (LossesByGUID[loser] or 0) + 1;
		if newData then
			SendGroupAddonMessage("!\tduels\t" .. duelString);
			print(duel.text);
		end
	end
end
function CleanUpDuel()
	StopMusic();
	if LookingForDuelsData.IsDueling or LookingForDuelsData.IsPending then
		Print(ERR_DUEL_CANCELLED);
	end
	LookingForDuelsData.IsDueling = nil;
	LookingForDuelsData.IsPending = nil;
	LookingForDuelsData.CurrentOpponentName = nil;
	LookingForDuelsData.WinCondition = nil;
	LookingForDuelsData.WinRetreatCondition = nil;
	LookingForDuelsData.LoseCondition = nil;
	LookingForDuelsData.LoseRetreatCondition = nil;
	LookingForDuelsData.OutOfBounds = nil;
	LookingForDuelsData.Victory = nil;
	LookingForDuelsData.ClearData = nil;
	_:UnregisterEvent("CHAT_MSG_SYSTEM");
	_:UnregisterEvent("DUEL_INBOUNDS");
	_:UnregisterEvent("DUEL_OUTOFBOUNDS");
	_:UnregisterEvent("DUEL_FINISHED");
end
function ConfirmDuel()
	AcceptDuel();
	StaticPopup_Hide("DUEL_REQUESTED");
end
function DeclineDuel()
	CancelDuel();
	StaticPopup_Hide("DUEL_REQUESTED");
end
function DuelTarget()
	DeclineDuel();
	StartDuel();
end
local function MinimapButtonOnClick(self, button)
	if button == "RightButton" then
		ToggleSettingsUI()
	else
		ToggleUI();
	end
end
local function MinimapButtonOnEnter(self)
	local wins, losses = WinsByGUID[PlayerGUID] or 0, LossesByGUID[PlayerGUID] or 0;
	local total = wins + losses;
	GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	GameTooltip:ClearLines();
	GameTooltip:AddDoubleLine(L.TITLE, total == 0 and "No duels found." or GetProgressColorText(wins, total));
	GameTooltip:AddLine(L.DESCRIPTION, 0.4, 0.8, 1, 1);
	GameTooltip:AddLine(L.MINIMAP_MOUSEOVER_TEXT, 1, 1, 1);
	GameTooltip:Show();
end
local function MinimapButtonOnLeave()
	GameTooltip:Hide();
end
function ProcessDuel()
	-- Acquire the GUID of the Opponent. [Global Persistence]
	local startTime, CurrentOpponentName, CurrentOpponent = time(), LookingForDuelsData.CurrentOpponentName, nil;
	local guid = rawget(RealmGUIDs, CurrentOpponentName);
	if guid then CurrentOpponent = rawget(LookingForDuelsData.CachedCharacterData, guid); end
	
	-- Scan for Target data until the player name matches the opponent.
	while not CurrentOpponent do
		if UnitIsPlayer("target") and UnitName("target") == CurrentOpponentName then
			guid = UnitGUID("target");
			if guid then
				-- Build a Cached Character Profile for the Target
				CurrentOpponent = CreateOpponent("target");
				rawset(RealmGUIDs, CurrentOpponentName, guid);
				rawset(LookingForDuelsData.CachedCharacterData, guid, CurrentOpponent);
			else
				coroutine.yield();
			end
		else
			coroutine.yield();
		end
	end
	
	-- Notify the Player that the Duel is Starting
	Print(CurrentOpponent.text);
	LookingForDuelsData.WinCondition = string.format(DUEL_WINNER_KNOCKOUT, PlayerData.name, CurrentOpponentName);
	LookingForDuelsData.WinRetreatCondition = string.format(DUEL_WINNER_RETREAT, PlayerData.name, CurrentOpponentName);
	LookingForDuelsData.LoseCondition = string.format(DUEL_WINNER_KNOCKOUT, CurrentOpponentName, PlayerData.name);
	LookingForDuelsData.LoseRetreatCondition = string.format(DUEL_WINNER_RETREAT, CurrentOpponentName, PlayerData.name);
	_:RegisterEvent("CHAT_MSG_SYSTEM");
	_:RegisterEvent("DUEL_OUTOFBOUNDS");
	
	-- If the Duel hasn't already been started, then wait for it to start.
	if not LookingForDuelsData.IsDueling then
		-- While the Duel is pending, wait.
		LookingForDuelsData.IsPending = true;
		_:RegisterEvent("DUEL_FINISHED");
		while LookingForDuelsData.IsPending do
			if InCombatLockdown() then
				-- We're in Combat, are we Hostile to the target?
				if UnitIsPlayer("target") and UnitIsEnemy("player", "target") and UnitName("target") == CurrentOpponentName then
					LookingForDuelsData.IsPending = nil;
					break;
				else
					coroutine.yield();
				end
			else
				coroutine.yield();
			end
			if LookingForDuelsData.ClearData then
				CleanUpDuel();
				return 0;
			end
		end
		LookingForDuelsData.IsDueling = true;
		_:UnregisterEvent("DUEL_FINISHED");
	end
	
	-- Play that sick Battle Music!
	PlayBattleMusic();
	
	-- While the Duel is going on, wait.
	while LookingForDuelsData.IsDueling do
		coroutine.yield();
		if LookingForDuelsData.ClearData then
			CleanUpDuel();
			return 0;
		end
	end
	
	-- Calculate the best time to use for the identifier.
	local endTime = time();
	local modEndTime = endTime % 10;
	
	-- Did you Win or Lose?
	local identifier = endTime - modEndTime + (modEndTime < 3 and -5 or 0);
	-- print(startTime .. " -> " .. endTime .. " = ID# " .. identifier);
	if LookingForDuelsData.Victory then
		identifier = identifier .. "_" .. PlayerGUID .. "_" .. guid;
		Print(LookingForDuelsData.OutOfBounds and L.YOU_WIN_OUT or L.YOU_WIN);
		PlayVictorySound();
	else
		identifier = identifier .. "_" .. guid .. "_" .. PlayerGUID;
		Print(LookingForDuelsData.OutOfBounds and L.YOU_LOSE_OUT or L.YOU_LOSE);
		PlayDefeatSound();
	end
	
	-- Record the Duel
	if LookingForDuelsData.OutOfBounds then identifier = identifier .. "_OUT"; end
	table.insert(LookingForDuelsData.Duels, identifier);
	CacheDuel(identifier, true);
	
	-- The Duel has Ended, let's cut the music and clean up the persistent data.
	CleanUpDuel();
end
function SyncAll()
	SendGroupAddonMessage("?\tsync");
end
function SyncTarget()
	SendTargetAddonMessage("?\tsync");
end
function ToggleUI()
	Print("Placeholder function for ToggleUI.");
end
function ToggleSettingsUI()
	SettingsFrame:Open();
end

-- Exposed Functions [Private Local Function Visibility without Direct Accessibility]
LookingForDuelsAPI.ConfirmDuel = function() ConfirmDuel(); end
LookingForDuelsAPI.DeclineDuel = function() DeclineDuel(); end
LookingForDuelsAPI.DuelTarget = function() DuelTarget(); end
LookingForDuelsAPI.SyncAll = function() SyncAll(); end
LookingForDuelsAPI.SyncTarget = function() SyncTarget(); end
LookingForDuelsAPI.ToggleUI = function() ToggleUI(); end
LookingForDuelsAPI.ToggleSettingsUI = function() ToggleSettingsUI(); end

-- Hooks
local originalStartDuel = StartDuel;
StartDuel = function(target)
	events.DUEL_REQUESTED(target);
	originalStartDuel(target);
end

-- Event Handlers
events.VARIABLES_LOADED = function()
	if not LookingForDuelsData then LookingForDuelsData = {}; end
	setmetatable(LookingForDuelsData, DefaultSettings);
	if not LookingForDuelsData.CachedCharacterData then
		LookingForDuelsData.CachedCharacterData = {};
	else
		for guid,data in pairs(LookingForDuelsData.CachedCharacterData) do
			setmetatable(data, OpponentClass);
		end
	end
	if not LookingForDuelsData.CachedCharacterGUIDS then
		LookingForDuelsData.CachedCharacterGUIDS = {};
	else
		-- Remove all non-tables (name-guid pairs) from this dictionary
		for name,guid in pairs(LookingForDuelsData.CachedCharacterGUIDS) do
			if type(guid) ~= "table" then
				LookingForDuelsData.CachedCharacterGUIDS[name] = nil;
			end
		end
	end
	if not LookingForDuelsData.Duels then
		LookingForDuelsData.Duels = {};
	else
		for i,duelString in ipairs(LookingForDuelsData.Duels) do
			CacheDuel(duelString);
		end
	end
	
	-- Create a Temporary Table for the Current Realm for faster lookups.
	RealmGUIDs = LookingForDuelsData.CachedCharacterGUIDS[RealmName];
	if not RealmGUIDs then
		RealmGUIDs = {};
		LookingForDuelsData.CachedCharacterGUIDS[RealmName] = RealmGUIDs;
	end
	
	-- Create an Entry for the Player
	PlayerData, PlayerGUID = CreateOpponent("player"), UnitGUID("player");
	rawset(RealmGUIDs, PlayerData.name, PlayerGUID);
	rawset(LookingForDuelsData.CachedCharacterData, PlayerGUID, PlayerData);
	C_ChatInfo.RegisterAddonMessagePrefix("LFDUELS");
	
	-- If a Duel was previously active, let's check to see if you're still dueling.
	if LookingForDuelsData.CurrentOpponentName then
		events.DUEL_REQUESTED(LookingForDuelsData.CurrentOpponentName);
	else
		CleanUpDuel();
	end
	
	-- Create the Minimap Icon
	LibStub("LibDBIcon-1.0"):Register("LFDUELS", 
	LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(L.TITLE, {
		type = "launcher",
		icon = L.ICON,
		OnClick = MinimapButtonOnClick,
		OnEnter = MinimapButtonOnEnter,
		OnLeave = MinimapButtonOnLeave,
	}), setmetatable({}, { __index = function(t, key)
		if key == "hide" then
			return not LookingForDuelsData.ShowMinimapButton;
		end
	end}));
	SettingsFrame:Initialize();
end
events.CHAT_MSG_ADDON = function(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
	if prefix == "LFDUELS" then
		-- print(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
		local args = { strsplit("\t", text) };
		local cmd = args[1];
		if cmd then
			-- Command to Request Data
			if cmd == "!" then	-- Command to Receive Data
				if args[2] == "duels" then
					for i,duelString in ipairs({ strsplit(":", args[3]) }) do
						CacheDuel(duelString);
					end
				end
			elseif cmd == "?" then
				if args[2] == "sync" then
					local length, totallength, msg = 0, 0;
					for i,duelString in ipairs(LookingForDuelsData.Duels) do
						length = string.len(duelString);
						if totallength + length >= 236 then
							SendTargetAddonMessage("!\tduels\t" .. msg, sender);
							totallength = 0;
							msg = nil;
						elseif msg then
							msg = msg .. ":" .. duelString;
							totallength = totallength + length + 1;
						else
							msg = duelString;
							totallength = length;
						end
					end
					if totallength + length >= 236 then
						SendTargetAddonMessage("!\tduels\t" .. msg, sender);
						totallength = 0;
						msg = nil;
					end
				end
			end
		end
	end
end
events.CHAT_MSG_SYSTEM = function(msg, ...)
	if LookingForDuelsData.IsDueling then
		if msg == LookingForDuelsData.WinCondition then
			LookingForDuelsData.Victory = true;
			LookingForDuelsData.OutOfBounds = nil;
			LookingForDuelsData.IsDueling = false;
		elseif msg == LookingForDuelsData.LoseCondition then
			LookingForDuelsData.Victory = nil;
			LookingForDuelsData.OutOfBounds = nil;
			LookingForDuelsData.IsDueling = false;
		elseif msg == LookingForDuelsData.WinRetreatCondition then
			LookingForDuelsData.Victory = true;
			LookingForDuelsData.OutOfBounds = true;
			LookingForDuelsData.IsDueling = false;
		elseif msg == LookingForDuelsData.LoseRetreatCondition then
			LookingForDuelsData.Victory = nil;
			LookingForDuelsData.OutOfBounds = true;
			LookingForDuelsData.IsDueling = false;
		end
	else
		-- We must be waiting for the Duel to Start.
		if string.find(msg, DUEL_COUNTDOWN) then
			LookingForDuelsData.IsPending = nil;
		end
	end
end
events.DUEL_REQUESTED = function(playerName)
	if not playerName or playerName == "" then playerName = UnitName("target"); end
	if playerName then
		LookingForDuelsData.CurrentOpponentName = select(1, UnitName(playerName)) or playerName;
		StopCoroutine(LookingForDuelsData.CurrentOpponentName);
		StartCoroutine(LookingForDuelsData.CurrentOpponentName, ProcessDuel);
	end
end
events.DUEL_INBOUNDS = function()
	LookingForDuelsData.OutOfBounds = nil;
	if LookingForDuelsData.OutOfBoundsAudioEnabled then
		StopMusic();
		PlayBattleMusic();
	end
	_:UnregisterEvent("DUEL_INBOUNDS");
end
events.DUEL_OUTOFBOUNDS = function()
	_:RegisterEvent("DUEL_INBOUNDS");
	LookingForDuelsData.OutOfBounds = true;
	if LookingForDuelsData.OutOfBoundsAudioEnabled then
		PlayRandomMusic(LookingForDuelsData.OutOfBoundsAudioOptions);
	end
end
events.DUEL_FINISHED = function()
	LookingForDuelsData.ClearData = true;
end

-- Tooltips
GameTooltip:HookScript("OnTooltipSetUnit", AttachTooltip);
GameTooltip:HookScript("OnTooltipCleared", ClearTooltip);

-- Slash Commands
SLASH_LFDUELS1 = "/lfd";
SLASH_LFDUELS2 = "/lfduel";
SLASH_LFDUELS3 = "/lfduels";
SLASH_LFDUELS4 = "/lookingforduel";
SLASH_LFDUELS5 = "/lookingforduels";
SlashCmdList["LFDUELS"] = function(cmd)
	if cmd and cmd ~= "" then
		if cmd == "start" or cmd == "duel" then
			DuelTarget();
			return 0;
		elseif cmd == "sync" or cmd == "u" then
			SyncTarget();
			return 0;
		elseif cmd == "syncall" or cmd == "sync all" or cmd == "all" then
			SyncAll();
			return 0;
		elseif cmd == "clean" or cmd == "clear" then
			LookingForDuelsData.ClearData = true;
			return 0;
		elseif cmd == "settings" then
			ToggleSettingsUI();
			return 0;
		end
	end
	ToggleUI();
end