------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- User Controlled Notifications
-- by Some1fromthedark

-- How to use:

--  To trigger a notification, set the value of pTriggerNotification using Cheat Engine (or another method of your choice) to 1
--    This will display a notification for the default settings (Notification for Sora with no messages to display)
--  To control the style of the notification, you can set the value of pCharacterId using Cheat Engine to the ID of the character you want the style to match
--    You can check the ID for each character in the Character ID constants section
--    The color of the notification will change to the color for that character, and if a character string is not provided it will default to that character's name
--  The notifications support custom text for the name of the character, the stat increase message, and the ability learned message
--    You can enable the use of custom text by setting the value of the corresponding flags (pUseCustomStr0, pUseCustomStr1, and pUseCustomStr2) using Cheat Engine
--	  The custom text to be used should be placed at the corresponding locations in memory (pCustomStr0, pCustomStr1, pCustomStr2) using Cheat Engine
--    Any custom text must be encoded using the appropriate method for the version of the game you are using
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Memory Address Constants (Update these to port to different versions of KH1)
local pGameSavePtr				= 0x00304BE8
local party_offset				= 0x0000048E	-- Relative to GameSave Ptr
local pUnknownArray0			= 0x00459CA0
local pUnknownArray1			= 0x00459CE0
local pBtltbl					= 0x00533BA0
local btltbl_type0_strs_offset	= 0x00000258	-- Relative to Btltbl Ptr
local btltbl_name_start_index	= 0x00000127	-- The index of the first character name string in btltbl type 0 strings
local pLevelUpDisplayCounts		= 0x00656510
local pDisplayUnknownValue0Base	= 0x00656520	-- Constant 1 (int) [uses offset2]
local pDisplayPartyIndBase		= 0x00656528
local pDisplayUnknownValue1Base	= 0x0065652C	-- Constant 0 (int)
local pDisplayValidStrsBase		= 0x00656538
local pDisplayStatStrBase		= 0x0065653C
local pDisplayAbilityStrBase	= 0x00656540
local pDisplayCharStrBase		= 0x00656544
local pDisplayUnknownValue2Base	= 0x00656F10	-- Constant 1.0 (float)
local pDisplayUnknownValue3Base	= 0x00656F14
local pDisplayUnknownValue4Base	= 0x00656F18
local pLevelUpIndicators 		= 0x0065FB20
local pLevelUpIndicatorTest		= 0x0065FB2C

-- Memory addresses controlled by displayLevelUpNotification() for custom strings
local pStr0 = 0x01FFA300
local pStr1 = 0x01FFA320
local pStr2 = 0x01FFA340

-- Character ID constants
local CHAR_ID_SORA		= 0x00
local CHAR_ID_DONALD	= 0x01
local CHAR_ID_GOOFY		= 0x02
local CHAR_ID_TARZAN	= 0x03
local CHAR_ID_POOH		= 0x04
local CHAR_ID_ALADDIN	= 0x05
local CHAR_ID_ARIEL		= 0x06
local CHAR_ID_JACK		= 0x07
local CHAR_ID_PETER_PAN	= 0x08
local CHAR_ID_BEAST		= 0x09

-- User Controlled Addresses for dynamic custom messages
local pTriggerNotification	= 0x01FFA360	-- Currently using a value greater than 1 does NOT trigger multiple notifications
local pCharacterId			= 0x01FFA361
local pUseCustomStr0		= 0x01FFA362	-- Custom Stat Increase Message (Line 1)
local pUseCustomStr1		= 0x01FFA363	-- Custom Ability Learned Message (Line 2)
local pUseCustomStr2		= 0x01FFA364	-- Custom Name
local pCustomStr0			= 0x01FFA370	-- Expects the message to be less than 32 bytes
local pCustomStr1			= 0x01FFA390	-- Expects the message to be less than 32 bytes
local pCustomStr2			= 0x01FFA3B0	-- Expects the message to be less than 32 bytes

function displayLevelUpNotification(char_id, stat_str, ability_str, char_str)
	-- make sure the character id is valid
	if char_id ~= nil and char_id >= 0 and char_id <= 9 then
		-- Get current copy of Game Save Ptr and make sure it is valid
		local pGameSave = ReadInt(pGameSavePtr)
		if pGameSave ~= 0 then
			-- Get the party index of the character (ignoring party index 3)
			local pPartyArray = pGameSave + party_offset
			local party_ind = -1
			local pStatStr = 0
			local pAbilityStr = 0
			local pCharStr = 0
			for i = 0,2 do
				if ReadByte(pPartyArray + i) == char_id then
					party_ind = i
					break
				end
			end
			-- Validate input strings
			local str_count = 0
			if type(stat_str) == "number" then	-- A memory address for a string
				pStatStr = stat_str
			elseif type(stat_str) == "string" then	-- A string to store in pStr0
				if stat_str ~= nil and #stat_str < 32 then
					WriteString(pStr0, stat_str)
					-- WriteString doesn't null terminate the string, so we must
					WriteByte(pStr0 + #stat_str, 0)
					pStatStr = pStr0
				end
			end
			-- If the string is valid, increment the string count
			if pStatStr ~= 0 then
				str_count = str_count + 1
			end
			if type(ability_str) == "number" then	-- A memory address for a string
				pAbilityStr = ability_str
			elseif type(ability_str) == "string" then	-- A string to store in pStr1
				if ability_str ~= nil and #ability_str < 32 then
					WriteString(pStr1, ability_str)
					-- WriteString doesn't null terminate the string, so we must
					WriteByte(pStr1 + #ability_str, 0)
					pAbilityStr = pStr1
				end
			end
			-- If the string is valid, increment the string count
			if pAbilityStr ~= 0 then
				str_count = str_count + 1
			end
			if type(char_str) == "number" then	-- A memory address for a string
				pCharStr = char_str
			elseif type(char_str) == "string" then	-- A string to store in pStr2
				if char_str ~= nil and #char_str < 32 then
					WriteString(pStr2, char_str)
					-- WriteString doesn't null terminate the string, so we must
					WriteByte(pStr2 + #char_str, 0)
					pCharStr = pStr2
				end
			else	-- Use the default string for the character from the BTLTBL
				local str_ind = btltbl_name_start_index + char_id
				pCharStr = ReadInt(pBtltbl + btltbl_type0_strs_offset + str_ind * 4)
			end
			-- Check if there is an existing notification being displayed?
			local index = party_ind * 4
			local pIndicator = pLevelUpIndicators + index
			local pCount = pLevelUpDisplayCounts + index
			local test_value = ReadInt(pLevelUpIndicatorTest)
			if ReadInt(pIndicator) ~= test_value then
				WriteInt(pIndicator, test_value)
				WriteInt(pCount, 0)
			end
			index = ReadInt(pCount)
			-- If there are already 5 notifications for this character, don't display this one
			if index < 5 then
				-- Increment the number of notifications
				WriteInt(pCount, index + 1)
				local offset  = index * 0x0A00 + party_ind * 0x3200
				local offset2 = party_ind * 0x0C80 + index * 0x0280
				-- These offsets should allow us to trigger multiple notifications at once, but it isn't working so just set them to 0 which works for a single notification
				offset = 0
				offset2 = 0
				-- Write Values to memory to trigger notification
				WriteInt(pDisplayPartyIndBase + offset, party_ind)
				WriteInt(pDisplayValidStrsBase + offset, str_count)
				WriteInt(pDisplayStatStrBase + offset, pStatStr)
				WriteInt(pDisplayAbilityStrBase + offset, pAbilityStr)
				WriteInt(pDisplayCharStrBase + offset, pCharStr)
				WriteInt(pDisplayUnknownValue2Base + offset, 0x3F800000)
				WriteInt(pDisplayUnknownValue0Base + offset2, 1)
				WriteInt(pDisplayUnknownValue1Base + offset, 0)
				local pUnknownValue = pUnknownArray0 + 0x30
				if char_id < 3 then
					pUnknownValue = pUnknownArray0 + char_id * 0x10
				end
				WriteInt(pDisplayUnknownValue3Base + offset, pUnknownValue)
				pUnknownValue = pUnknownArray1 + 0x30
				if char_id < 3 then
					pUnknownValue = pUnknownArray1 + char_id * 0x10
				end
				WriteInt(pDisplayUnknownValue4Base + offset, pUnknownValue)
			end
		end
	end
end

function _OnInit()
	
end

function _OnBoot()
	
end

function _OnFrame()
	-- Check the trigger address
	local trigger_count = ReadByte(pTriggerNotification)
	if trigger_count > 0 then
		-- For each trigger
		for i = 1,trigger_count do
			-- Get the character id (user controlled)
			local notification_char_id = ReadByte(pCharacterId)
			-- Default values for messages
			--local custom_stat_message = "\x32\x49\x50\x50\x53\x01\x41\x53\x56\x50\x48\x5F" -- Hello World!
			local custom_stat_message = nil
			local custom_ability_message = nil
			local custom_char_message = nil
			-- Check the user controlled flags to see if we are using the user controlled messages or the default messages
			if ReadByte(pUseCustomStr0) ~= 0 then
				custom_stat_message = pCustomStr0
			end
			if ReadByte(pUseCustomStr1) ~= 0 then
				custom_ability_message = pCustomStr1
			end
			if ReadByte(pUseCustomStr2) ~= 0 then
				custom_char_message = pCustomStr2
			end
			-- Display the notification
			displayLevelUpNotification(notification_char_id, custom_stat_message, custom_ability_message, custom_char_message)
		end
		-- Reset the trigger value
		WriteByte(pTriggerNotification, 0)
	end
end
