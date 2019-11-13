--------------------------------------------------------------------------------
--                      L O O K I N G   F O R   D U E L S                     --
--------------------------------------------------------------------------------
--				  Copyright 2017-2019 Dylan Fortune (Crieve-Atiesh)           --
--------------------------------------------------------------------------------
local app = select(2, ...);
LookingForDuelsAPI = app;	
local events = {};
app.events = events;
local _ = CreateFrame("FRAME", nil, UIParent);
_:SetScript("OnEvent", function(self, e, ...) (rawget(events, e) or print)(...); end);
_:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", 0, 0);
_:RegisterEvent("PLAYER_LOGIN");
_:RegisterEvent("DUEL_REQUESTED");
_:RegisterEvent("DUEL_INBOUNDS");
_:RegisterEvent("DUEL_OUTOFBOUNDS");
_:RegisterEvent("DUEL_FINISHED");
_:SetSize(1, 1);
_:Show();

-- Persistent Data Storage
local LookingForDuelsData = {};
local LookingForDuelsDataPerCharacter = {};

-- Temporary Data Storage
local CurrentOpponentName, CurrentOpponent, IsDueling;

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
	--print("Push->" .. name);
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
local function StopCoroutine(name)
	if app.refreshing[name] then
		debug.sethook(app.refreshing[name], function()
			error("Coroutine Ended Externally");
		end, "l");
		app.refreshing[name] = nil;
	end
end

-- Functionality
function ProcessDuel()
	-- Acquire the GUID of the Player. [Global Persistence]
	local guid = rawget(LookingForDuelsData.CachedCharacterGUIDS, CurrentOpponentName);
	if guid then
		CurrentOpponent = rawget(LookingForDuelsData.CachedCharacterData, guid);
	else
		CurrentOpponent = nil;
	end
	
	-- Scan for Target data until the player name matches the opponent.
	print("Scanning for Target...");
	while not CurrentOpponent do
		if UnitName("target") == CurrentOpponentName then
			guid = UnitGUID("target");
			if guid then
				-- Build a Cached Character Profile for the Target
				opponent = {
					["lvl"] = UnitLevel("target"),
					["class"] = select(3, UnitClass("target")),
					["race"] = select(3, UnitRace("target")),
					["faction"] = UnitFactionGroup("target"),
				};
				rawset(LookingForDuelsData.CachedCharacterGUIDS, CurrentOpponentName, guid);
				rawset(LookingForDuelsData.CachedCharacterData, guid, opponent);
				CurrentOpponent = opponent;
			else
				coroutine.yield();
			end
		else
			coroutine.yield();
		end
	end
	
	local classInfo = C_CreatureInfo.GetClassInfo(opponent.class);
	local raceInfo = C_CreatureInfo.GetRaceInfo(opponent.race);
	print("Target Acquired: |c" .. (RAID_CLASS_COLORS[classInfo.classFile].colorStr or "ff1eff00") .. CurrentOpponentName .. "|r (Level " .. (opponent.lvl or "??") .. " " .. (raceInfo.raceName or "??").. " " .. (classInfo.className or "??") .. ")");
	
	-- While the Duel is going on with the same player, wait.
	while IsDueling and CurrentOpponent == opponent do
		-- print("IsDueling");
		coroutine.yield();
	end
	
	print("Duel Ended");
end


-- Event Handlers
events.PLAYER_LOGIN = function()
	print("PLAYER_LOGIN - Initialize Variables here");
	if not LookingForDuelsData.CachedCharacterData then
		LookingForDuelsData.CachedCharacterData = {};
	end
	if not LookingForDuelsData.CachedCharacterGUIDS then
		LookingForDuelsData.CachedCharacterGUIDS = {};
	end
end
events.DUEL_REQUESTED = function(playerName)
	print("DUEL_REQUESTED, initialize a coroutine for this duel", playerName);
	if playerName then
		IsDueling = true;
		CurrentOpponentName = select(1, UnitName(playerName)) or playerName;
		StopCoroutine("ProcessDuel");
		StartCoroutine("ProcessDuel", ProcessDuel);
	end
end
events.DUEL_INBOUNDS = function()
	print("DUEL_INBOUNDS, reset warning that you're going out of bounds");
end
events.DUEL_OUTOFBOUNDS = function()
	print("DUEL_OUTOFBOUNDS, tell coroutine you're going out of bounds");
end
events.DUEL_FINISHED = function()
	print("DUEL_FINISHED, check health of both participants immediately");
	IsDueling = false;
end