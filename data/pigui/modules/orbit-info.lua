-- Copyright © 2008-2020 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

-- local Engine = import('Engine')
local Game = import('Game')
local ui = import('pigui/pigui.lua')
-- local Lang = import("Lang")
-- local lc = Lang.GetResource("core");
-- local lui = Lang.GetResource("ui-core");
-- local utils = import("utils")
-- local Event = import("Event")

local player = nil
local pionillium = ui.fonts.pionillium
-- local pionicons = ui.fonts.pionicons
local colors = ui.theme.colors
local icons = ui.theme.icons

local iconSize = Vector2(16,16)

local font = pionillium.medium
local width = 120 + 120 * (ui.screenWidth / 1200)
local height = font.size * 1.5 * 7
local sepheight = math.max(iconSize.y, font.size) * 3 + 4

local G = 6.67428e-11


local function acosh(x)
	return math.log(x + math.sqrt(x*x-1))
end


local function getOrbitInfo(player, frameBody)
	info = {}
	if frameBody==nil then
		return info
	end
	info.name = frameBody.label
	local path = frameBody.path
	local mu = G * path:GetSystemBody().mass

	local pos = player:GetPositionRelTo(frameBody)
	local vel = player:GetVelocityRelTo(frameBody)
	local r = pos:length()

	local lambda = pos:cross(vel):length()
	local epsilon = vel:lengthSqr() / 2 - mu / r

	info.r = r
	info.r_krit = frameBody:GetPhysicalRadius()

	if lambda > 1e-5 then
		local p = lambda * lambda / mu
		local e = math.sqrt(1 + 2 * epsilon * p / mu)
		local a = p / (1 - e * e)
		-- info.a = a
		info.e = e
		info.r_peri = p / (1 + e)

		local E, b
		if e < 1 then
			E = math.acos((1 - r / a) / e)
			if pos:dot(vel) < 0 then
				E = 2 * math.pi - E
			end
			info.r_apo = p / (1 - e)
			info.M = E + e * math.sin(E)
			info.T = 2 * math.pi * math.sqrt(math.pow(a, 3) / mu)
			b = p / math.sqrt(1 - e * e)
		else
			E = acosh((1 - r / a) / e)
			if pos:dot(vel) < 0 then
				E = -E
			end
			local M = e * math.sinh(E) - E
			info.t_peri = math.sqrt(math.pow(-a, 3) / mu) * M
			b = p / math.sqrt(e * e - 1)
			info.b = b
		end

		if info.r_peri <= info.r_krit then
			if e < 1 and E > math.pi then
				info.impact = true
				if r >= info.r_krit then
					local E_imp = 2 * math.pi - math.acos((1 - info.r_krit / a) / e)
					local delta = Vector2(a * (math.cos(E_imp) - math.cos(E)), b * (math.sin(E_imp) - math.sin(E)))
					info.d_imp = delta:length()
				end
			elseif e >= 1 and E < 0 then
				info.impact = true
				if r >= info.r_krit then
					local E_imp = - acosh((1 - info.r_krit / a) / e)
					local delta = Vector2(a * (math.cosh(E_imp) - math.cosh(E)), b * (math.sinh(E_imp) - math.sinh(E)))
					info.d_imp = delta:length()
				end
			end
		end
	end
	
	info.v1 = math.sqrt(mu / r)
	-- info.v2 = math.sqrt(2) * info.v1
	
	-- info.mass = path:GetSystemBody().mass
	info.lambda = lambda
	info.epsilon = epsilon
	return info
end

local function formatOrbitInfo(info)
	if info.name then
		val,unit = ui.Format.Speed(info.v1)
		info.v1_fmt = val .. " " .. unit
		-- val,unit = ui.Format.Speed(info.v2)
		-- info.v2_fmt = val .. " " .. unit
		local val,unit = ui.Format.Distance(info.r_krit)
		info.r_krit_fmt = val .. " " .. unit
		local val,unit = ui.Format.Distance(info.r)
		info.r_fmt = val .. " " .. unit

		if info.e then
			-- local val,unit = ui.Format.Distance(info.a)
			-- info.a_fmt = val .. " " .. unit
			info.e_fmt = string.format("%.6g", info.e)
			local val,unit = ui.Format.Distance(info.r_peri)
			info.r_peri_fmt = val .. " " .. unit
			if info.e < 1 then
				local val,unit = ui.Format.Distance(info.r_apo)
				info.r_apo_fmt = val .. " " .. unit
				if not info.impact then
					info.M_fmt = string.format("%.4f", info.M)
					info.T_fmt = ui.Format.Duration(info.T,3)
				end
			else
				local val,unit = ui.Format.Distance(info.b)
				info.b_fmt = val .. " " .. unit
				if not info.impact then
					info.t_peri_fmt = ui.Format.Duration(info.t_peri,3)
				end
			end
			if info.impact then
				if info.d_imp then
					local val,unit = ui.Format.Distance(info.d_imp)
					info.d_imp_fmt = val .. " " .. unit
					-- info.E_imp_fmt = string.format("%.8g", info.E_imp)
				else
					info.d_imp_fmt = "--"
				end
			end
		end
		info.epsilon_fmt = string.format("%.6e", info.epsilon)
		info.lambda_fmt = string.format("%.6e", info.lambda)
	else
		info.name = "--"
	end
end


local function displayOrbitInfo()
	local player = Game.player
	local current_view = Game.CurrentView()
	if current_view == "world" then
		local info = getOrbitInfo(player, player.frameBody)
		if info.name == nil then
			return
		end
		formatOrbitInfo(info)
		
		ui.setNextWindowSize(Vector2(width, height), "Always")
		ui.setNextWindowPos(Vector2(ui.screenWidth - width, ui.screenHeight - height - sepheight), "Always")
		ui.window("OrbitInfo", {"NoTitleBar", "NoResize", "NoFocusOnAppearing", "NoBringToFrontOnFocus"},
					 function()
						 ui.withFont(font.name, font.size, function()
											 ui.columns(2, "", false)
											 ui.text(info.name)
											 
											 ui.text("v1")
											 ui.sameLine()
											 ui.text(info.v1_fmt)

											 ui.text("rk")
											 ui.sameLine()
											 ui.text(info.r_krit_fmt)

											 ui.text("r")
											 ui.sameLine()
											 ui.text(info.r_fmt)

											 if not info.e then
												 ui.text("")
											 elseif info.impact then
												 ui.text("di")
												 ui.sameLine()
												 ui.text(info.d_imp_fmt)
											 elseif info.e < 1 then
												 ui.text("M")
												 ui.sameLine()
												 ui.text(info.M_fmt)
											 else
												 ui.text("tp")
												 ui.sameLine()
												 ui.text(info.t_peri_fmt)
											 end
											 ui.text(info.epsilon_fmt)

											 ui.nextColumn()
											 ui.text("")

											 if not info.e then
												 ui.text("")
												 ui.text("")
												 ui.text("")
												 ui.text("")
											 else
												 ui.text("e")
												 ui.sameLine()
												 ui.text(info.e_fmt)

												 ui.text("pe")
												 ui.sameLine()
												 ui.text(info.r_peri_fmt)

												 if info.e < 1 then
													 ui.text("ap")
													 ui.sameLine()
													 ui.text(info.r_apo_fmt)
													 if not info.impact then
														 ui.text("T")
														 ui.sameLine()
														 ui.text(info.T_fmt)
													 else
														 ui.text("reentry")
													 end
												 else
													 ui.text("b")
													 ui.sameLine()
													 ui.text(info.b_fmt)
													 if not info.impact then
														 ui.text("")
													 else
														 ui.text("reentry")
													 end
												 end
											 end
											 ui.text(info.lambda_fmt)
						 end)
		end)
	end
end

ui.registerModule("game", displayOrbitInfo)

return {}
