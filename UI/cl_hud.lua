--[[
---------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_hud.lua
PURPOSE: All HUD functions, callbacks, and GTA V 
		 front-end functions.
---------------------------------------------------
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
---------------------------------------------------
]]
HUD = { }

-- HUD UI modules live in UI/modules/<name>/html/index.html.
-- Each module keeps its own html/, textures/, and sounds/ folders.
-- Add future controller UIs here, then place their files in UI/modules/<name>/.
HUD_UI_MODULES = HUD_UI_MODULES or {
	default = 'ZTEP103',
	wecanx = 'WECANX',
	ui2 = 'UI 2',
	ztep103 = 'ZTEP103',
	pathfinder = 'Pathfinder',
}

-- UI is selected from the active AUDIO scheme in the VCF XML.
-- Example: <SCHEME String="ZTEP103"/> loads UI/modules/ztep103/.
-- Add mappings here only when the scheme name and module folder name differ.
HUD_SCHEME_UI_MODULES = HUD_SCHEME_UI_MODULES or {
	default = 'default',
	ztep103 = 'ztep103',
}

local HUD_temp_hidden = false
local HUD_scale
local HUD_pos 
local HUD_backlight_state = false
local HUD_module = 'default'

local function GetHudSirenToneState(tone)
	tone = tonumber(tone) or 0
	if tone <= 0 then
		return false
	end

	local tone_data = nil
	if SIRENS ~= nil then
		tone_data = SIRENS[tone]
	end

	if type(tone_data) == 'table' then
		for _, value in pairs(tone_data) do
			if type(value) == 'string' then
				local lowered = string.lower(value)
				if string.find(lowered, 'wail', 1, true) then
					return 'siren_t1'
				end
			end
		end
	end

	if tone == 1 then
		return 'siren_t1'
	end

	return 'siren_t2'
end

local function GetStageAwareSwitchState()
	if veh == nil or veh == 0 or not IsVehicleSirenOn(veh) then
		return 'switch_1'
	end

	-- If the current vehicle has a stages profile, the switch is the stage selector:
	-- stage 1 -> switch_2
	-- stage 2 -> switch_3
	-- stage 3+ -> switch_4
	if state_stage ~= nil and state_stage[veh] ~= nil and state_stage[veh].hasStages then
		local stage = tonumber(state_stage[veh].current_stage) or 1

		if stage <= 1 then
			return 'switch_2'
		elseif stage == 2 then
			return 'switch_3'
		else
			return 'switch_4'
		end
	end

	-- No stages setup: the switch is only lights OFF/ON.
	return 'switch_4'
end

local function GetHudSwitchState()
	return GetStageAwareSwitchState()
end

local function ShouldHudDisplayNow()
	return HUD.enabled == true
		and player_is_emerg_driver == true
		and IsHudHidden() ~= 1
		and IsPauseMenuActive() ~= 1
		and not IsWarningMessageActive()
end

local function GetHudModuleList()
	local modules = {}
	for module_name, _ in pairs(HUD_UI_MODULES) do
		modules[#modules + 1] = module_name
	end
	table.sort(modules)
	return table.concat(modules, ', ')
end

local function NormalizeHudModuleName(value)
	if value == nil then
		return nil
	end

	local module_name = string.lower(tostring(value))
	module_name = module_name:gsub('^%s+', ''):gsub('%s+$', '')
	module_name = module_name:gsub('%s+', '_')
	module_name = module_name:gsub('[^%w_-]', '')

	if module_name == '' then
		return nil
	end

	return module_name
end

local function IsHudModuleValid(module_name)
	return module_name ~= nil and HUD_UI_MODULES[module_name] ~= nil
end

local function ResolveHudModuleFromScheme(scheme_name)
	local normalized_scheme = NormalizeHudModuleName(scheme_name)
	if normalized_scheme == nil then
		return 'default'
	end

	local mapped_module = HUD_SCHEME_UI_MODULES[normalized_scheme] or normalized_scheme
	mapped_module = NormalizeHudModuleName(mapped_module) or 'default'

	if IsHudModuleValid(mapped_module) then
		return mapped_module
	end

	return 'default'
end

function HUD:GetHudModule()
	return HUD_module
end

function HUD:GetHudModuleFromCurrentScheme()
	local scheme_name = nil

	if AUDIO ~= nil then
		local scheme_index = tonumber(AUDIO.scheme_index) or 1

		if type(AUDIO.schemes) == 'table' then
			scheme_name = AUDIO.schemes[scheme_index]
		end

		if scheme_name == nil then
			scheme_name = AUDIO.scheme
		end
	end

	return ResolveHudModuleFromScheme(scheme_name)
end

function HUD:ApplyHudModuleFromScheme(silent)
	local module_name = self:GetHudModuleFromCurrentScheme()

	if module_name == HUD_module then
		return true
	end

	return self:SetHudModule(module_name, true, silent)
end

function HUD:SetHudModule(module_name, skip_save, silent)
	if module_name == nil then
		return false
	end

	module_name = string.lower(tostring(module_name))

	if not IsHudModuleValid(module_name) then
		if skip_save then
			module_name = 'default'
		else
			HUD:ShowNotification('~b~LVC: ~r~UI invalide~s~: ' .. module_name .. '. UIs: ' .. GetHudModuleList(), true)
			return false
		end
	end

	HUD_module = module_name

	-- Important: cache the real visibility before loading/swapping modules.
	-- Without this, the iframe can replay an old visible HUD while the player is on foot.
	HUD:SetItemState('hud', ShouldHudDisplayNow())

	SendNUIMessage({
		_type = 'ui:setModule',
		module = HUD_module,
	})

	-- Give the iframe time to load, then replay the important HUD state.
	CreateThread(function()
		Wait(300)

		if HUD_pos ~= nil then
			HUD:SetHudPosition(HUD_pos)
		end

		if HUD_scale ~= nil then
			HUD:SetHudScale(HUD_scale)
		else
			SendNUIMessage({ _type = 'hud:getHudScale' })
		end

		if HUD_backlight_state then
			HUD:SetItemState('time', 'night')
		else
			HUD:SetItemState('time', 'day')
		end

		HUD:SetHudState(HUD.enabled or false, true)

		if veh ~= nil and veh ~= 0 then
			HUD:RefreshHudItemStates()
		end
	end)

	if not silent and not skip_save then
		HUD:ShowNotification('~b~LVC: ~g~UI changée~s~: ' .. HUD_module, true)
	end

	return true
end

RegisterCommand('lvcsetui', function(source, args)
	local module_name = args[1]

	if module_name == nil or module_name == '' then
		HUD:ShowNotification('~b~LVC: ~s~Utilisation test: /lvcsetui [' .. GetHudModuleList() .. ']. Auto = SCHEME XML.', true)
		return
	end

	HUD:SetHudModule(module_name)
end)

RegisterCommand('lvcuis', function()
	HUD:ShowNotification('~b~LVC UIs: ~s~' .. GetHudModuleList() .. ' ~c~(auto via SCHEME XML)', true)
end)

---------------------------------------------------------------------
--[[Gets initial HUD scale from JS]]
CreateThread(function()
	Wait(500)
	HUD:ApplyHudModuleFromScheme(true)
	HUD:SetHudModule(HUD_module, true, true)
	Wait(500)
	SendNUIMessage({
	  _type = 'hud:getHudScale',
	})
end)

---------------------------------------------------------------------
--[[Handles HUD back light control.]]
CreateThread(function()
	while true do
		while player_is_emerg_driver and HUD:GetHudBacklightMode() == 1 do
			local _, veh_lights, veh_headlights  = GetVehicleLightsState(veh)
			if (veh_lights == 1 or veh_headlights == 1) and HUD:GetHudBacklightState() == false and not actv_horn then
				HUD:SetHudBacklightState(true)
			elseif (veh_lights == 0 and veh_headlights == 0) and HUD:GetHudBacklightState() == true then
				HUD:SetHudBacklightState(false)
			end
			Wait(500)
		end
		Wait(1000)
	end
end)

---------------------------------------------------------------------
--[[Handles hiding hud when hud is hidden or game is paused.]]
CreateThread(function()
	while true do
		if HUD.enabled or HUD_temp_hidden then
			if (not player_is_emerg_driver) or (IsHudHidden() == 1) or (IsPauseMenuActive() == 1) or (IsWarningMessageActive()) then
				if not HUD_temp_hidden then
					HUD:SetHudState(false, true)
					HUD_temp_hidden = true
				end
			elseif player_is_emerg_driver and (IsHudHidden() ~= 1) and (IsPauseMenuActive() ~= 1) and (not IsWarningMessageActive()) and HUD_temp_hidden then
				HUD:SetHudState(true, true)
				HUD_temp_hidden = false
			end
		end
		Wait(500)
	end
end)

------------------------------------------------
--[[Getter for HUD State (whether hud is enabled).]]
function HUD:GetHudState()
	return self.enabled
end

--[[Setter for HUD State temp changes the state temporarily for pausing/hud hiding.]]
function HUD:SetHudState(state, temporary)
	local temporary = temporary or false
	if not temporary then
		self.enabled = state
	end

	-- HUD.enabled is the saved preference. The NUI visibility must still be
	-- gated to the current context so the controller never appears on foot.
	local display_state = state == true
	if display_state then
		display_state = ShouldHudDisplayNow()
	end

	HUD:SetItemState('hud', display_state)
end

------------------------------------------------
--[[Getter for HUD scale. Updates local save from JS and returns.]]
function HUD:GetHudScale()
	SendNUIMessage({
	  _type = 'hud:getHudScale'
	})
	return HUD_scale
end

--[[Setter for HUD scale. Updates JS & CSS.]]
function HUD:SetHudScale(scale)
	if scale ~= nil then
		SendNUIMessage({
		  _type = 'hud:setHudScale',
		  scale = scale,
		})
	end
end

--[[Callback for JS -> LUA to set HUD_scale with current CSS]]
RegisterNUICallback('hud:sendHudScale', function(scale, cb)
	HUD_scale = scale
end )

------------------------------------------------
--[[Toggles HUD images based on their state on/off]]
function HUD:SetItemState(item, state)
	-- Older code can still send switch true/false.
	-- Convert it to the current stage-aware switch state before sending to NUI.
	if item == 'switch' and type(state) == 'boolean' then
		state = GetHudSwitchState()
	end

	-- Handsfree has visual priority over every normal siren state.
	-- Only manual siren is allowed to override it visually.
	if item == 'siren'
		and state_handsfree ~= nil
		and veh ~= nil
		and veh ~= 0
		and state_handsfree[veh] == true
		and state ~= 'siren_wail'
		and state ~= 'siren_yelp' then
		state = 'siren_hf'
	end

	SendNUIMessage({
	  _type = 'hud:setItemState',
	  item  = item,
	  state = state
	})
end

------------------------------------------------
--[[HUD Backlight Modes: 1 - auto, 2 - off, 3 - on]]
function HUD:GetHudBacklightMode()
	return self.backlight_mode
end

function HUD:SetHudBacklightMode(mode)
	if mode ~= nil then
		self.backlight_mode = mode
		
		if mode == 2 then
			HUD:SetHudBacklightState(false)
		elseif mode == 3 then
			HUD:SetHudBacklightState(true)	
		end
	end
end

function HUD:GetHudBacklightState()
	return HUD_backlight_state
end

function HUD:SetHudBacklightState(state)
	if state ~= nil then
		HUD_backlight_state = state
		if state then
			HUD:SetItemState('time', 'night')
		else
			HUD:SetItemState('time', 'day')
		end
		
		HUD:RefreshHudItemStates()
	end
end

------------------------------------------------
--[[Verifies HUD item states are correct]]
local function GetHudAlleyState()
	if veh == nil or veh == 0 or state_alley == nil or state_alley[veh] == nil then
		return nil
	end

	return state_alley[veh]
end

function HUD:RefreshHudItemStates()
	if actv_manu then
		if actv_horn then
			HUD:SetItemState('siren', 'siren_yelp')
		else
			HUD:SetItemState('siren', 'siren_wail')
		end
	elseif state_handsfree ~= nil and state_handsfree[veh] == true then
		HUD:SetItemState('siren', 'siren_hf')
	elseif state_lxsiren[veh] ~= nil and state_lxsiren[veh] > 0 then
		HUD:SetItemState('siren', GetHudSirenToneState(state_lxsiren[veh]))
	elseif state_auxiliary[veh] ~= nil and state_auxiliary[veh] > 0 then
		HUD:SetItemState('siren', GetHudSirenToneState(state_auxiliary[veh]))
	elseif actv_lxsrnmute_temp then
		HUD:SetItemState('siren', 'siren_t2')
	else
		HUD:SetItemState('siren', false)
	end
	
	if actv_manu then
		HUD:SetItemState('horn', false)
	elseif state_airmanu[veh] ~= nil and state_airmanu[veh] > 0 then
		HUD:SetItemState('horn', true)
	else
		HUD:SetItemState('horn', false)
	end
	
	local alley_state = GetHudAlleyState()
	local alley_front_active = alley_state ~= nil and alley_state.front == true
	local alley_left_active = alley_state ~= nil and alley_state.left == true
	local alley_right_active = alley_state ~= nil and alley_state.right == true

	if (state_tkd ~= nil and state_tkd[veh] ~= nil and state_tkd[veh]) or alley_front_active then
		HUD:SetItemState('tkd', true)
	else
		HUD:SetItemState('tkd', false)
	end

	HUD:SetItemState('leftalley', alley_left_active)
	HUD:SetItemState('rightalley', alley_right_active)

	
	if key_lock then
		HUD:SetItemState('lock', true)
	else
		HUD:SetItemState('lock', false)
	end

	
	if state_ta ~= nil and state_ta[veh] ~= nil then
		HUD:SetItemState('ta', state_ta[veh])
	else
		HUD:SetItemState('ta', 0)
	end	
	
	HUD:SetItemState('switch', GetHudSwitchState())
end

------------------------------------------------
--[[Setter for HUD position, used when loading save data.]]
function HUD:SetHudPosition(data)
	HUD_pos = data
	SendNUIMessage({
	  _type = 'hud:setHudPosition',
	  pos = HUD_pos,
	})	
end

--[[Getter for HUD position, used when saving data.]]
function HUD:GetHudPosition()
	return HUD_pos
end

--[[Sets HUD position based off backup stored in JS, in case HUD is off screen.]]
function HUD:ResetPosition()
	SendNUIMessage({
	  _type = 'hud:resetPosition',
	})
end

--[[Callback for JS -> LUA to set HUD_pos with current position to save.]]
RegisterNUICallback( 'hud:setHudPositon', function(data, cb)
	HUD_pos = data
	STORAGE:SaveHUDSettings()
end )

------------------------------------------------
--[[Sets NUI focus for move mode.]]
function HUD:SetMoveMode(state)
	SetNuiFocus( state, state )
end

--[[Sets NUI focus to false when right-click, esc, etc. are clicked.]]
RegisterNUICallback( 'hud:setMoveState', function(state, cb)
	SetNuiFocus(state, state)
	STORAGE:SaveHUDSettings()
end )

------------------------------------------------
--On screen GTA V notification
function HUD:ShowNotification(text, override)
	override = override or false
	if debug_mode or override then
		SetNotificationTextEntry('STRING')
		AddTextComponentString(text)
		DrawNotification(false, true)
	end
end

------------------------------------------------
--Drawn On Screen Text at X, Y
function HUD:ShowText(x, y, align, text, scale, label)
	scale = scale or 0.4
	SetTextJustification(align)
	SetTextFont(0)
	SetTextProportional(1)
	SetTextScale(0.0, scale)
	SetTextColour(128, 128, 128, 255)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	if text ~= nil then
		SetTextEntry('STRING')
		AddTextComponentString(text)
	else
		SetTextEntry(label)
	end
	DrawText(x, y)
	ResetScriptGfxAlign()
end

------------------------------------------------
--Full screen Confirmation Message
function HUD:FrontEndAlert(title, subtitle, options)
	AddTextEntry('FACES_WARNH2', title)
	AddTextEntry('QM_NO_0', subtitle)
	local result = -1
	while result == -1 do
		SetWarningMessageWithAlert('FACES_WARNH2', 'QM_NO_0', 0, 0, '', 0, -1, 0, '', '', false, 0)
		HUD:ShowText(0.5, 0.75, 0, options, 0.75)
		if IsDisabledControlJustReleased(2, 202) then
			return false
		end		
		if IsDisabledControlJustReleased(2, 201) then
			return true
		end
		Wait(0)
	end
end

------------------------------------------------
--Get User Input from Keyboard
function HUD:KeyboardInput(input_title, existing_text, max_length)
	AddTextEntry('custom_keyboard_title', input_title)
	DisplayOnscreenKeyboard(1, 'custom_keyboard_title', '', existing_text, '', '', '', max_length) 

	while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
		Wait(0)
	end
		
	if UpdateOnscreenKeyboard() ~= 2 then
		local result = GetOnscreenKeyboardResult() 
		Wait(500) 
		if result ~= '' then
			return result 
		else 
			return nil
		end
	else
		Wait(500)
		return nil 
	end
end