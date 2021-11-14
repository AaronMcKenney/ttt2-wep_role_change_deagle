--Shamelessly taken from the Sidekick Deagle

SWEP.Base = "weapon_tttbase"

SWEP.Spawnable = true
SWEP.AutoSpawnable = false
SWEP.AdminSpawnable = true

SWEP.HoldType = "pistol"

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

if SERVER then
	AddCSLuaFile()
	
	resource.AddFile("materials/vgui/ttt/icon_role_change_deagle.vmt")
	
	util.AddNetworkString("ttt_role_change_deagle_refilled")
	util.AddNetworkString("ttt_role_change_deagle_miss")
end

if CLIENT then
	SWEP.PrintName = "Role Change Deagle"
	SWEP.Author = "BlackMagicFine"
	
	SWEP.ViewModelFOV = 54
	SWEP.ViewModelFlip = false
	
	SWEP.Category = "Deagle"
	SWEP.Icon = "vgui/ttt/icon_role_change_deagle.vtf"
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "wep_role_change_deagle",
		desc = "wep_role_change_deagle_desc"
	}
end

--Gun stats
SWEP.Primary.Delay = 1
SWEP.Primary.Recoil = 6
SWEP.Primary.Automatic = false
SWEP.Primary.NumShots = 1
SWEP.Primary.Damage = 0
SWEP.Primary.Cone = 0.00001
SWEP.Primary.Ammo = ""
SWEP.Primary.ClipSize = GetConVar("ttt2_role_change_deagle_ammo"):GetInt()
SWEP.Primary.ClipMax = GetConVar("ttt2_role_change_deagle_ammo"):GetInt()
SWEP.Primary.DefaultClip = GetConVar("ttt2_role_change_deagle_ammo"):GetInt()

--Misc.
SWEP.InLoadoutFor = nil
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.UseHands = true
SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = {ROLE_DETECTIVE}
SWEP.LimitedStock = false
SWEP.globalLimited = false
SWEP.NoRandom = true

--Model
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.Weight = 5
SWEP.Primary.Sound = Sound("Weapon_Deagle.Single")

--Iron sights
SWEP.IronSightsPos = Vector(-6.361, -3.701, 2.15)
SWEP.IronSightsAng = Vector(0, 0, 0)

local NUM_PLYS_AT_ROUND_BEGIN = 0
local function GetNumPlayers()
	local num_players = 0
	for _, ply in ipairs(player.GetAll()) do
		if not ply:IsSpec() then
			num_players = num_players + 1
		end
	end
	
	return num_players
end

hook.Add("TTTBeginRound", "RoleChangeDeagleBeginRound", function()
	if SERVER then
		for _, ply in ipairs(player.GetAll()) do
			ply.role_change_deagle_hit = nil
		end
	end
	
	NUM_PLYS_AT_ROUND_BEGIN = GetNumPlayers()
end)

local function RoleChangeDeagleRefilled(wep)
	if not IsValid(wep) then
		return
	end
	
	local text = LANG.GetTranslation("RECHARGED_ROLE_CHANGE_DEAGLE")
	MSTACK:AddMessage(text)
	
	STATUS:RemoveStatus("ttt2_role_change_deagle_reloading")
	net.Start("ttt_role_change_deagle_refilled")
	net.WriteEntity(wep)
	net.SendToServer()
end

--RCD_DEBUG
--local function PrintRoleList(title, role_list)
--	local role_list_str = title .. ": ["
--	for i = 1, #role_list do
--		local role_data = roles.GetByIndex(role_list[i])
--		role_list_str = role_list_str .. role_data.name
--		if i < #role_list then
--			role_list_str = role_list_str .. ", "
--		end
--	end
--	role_list_str = role_list_str .. "]"
--	print(role_list_str)
--end

--Enum to ease headaches for AssignNewRole
local BUCKETS = {INNO = 0, DET = 1, TRA = 2, EVIL = 3, OTHER = 4}

local function AssignNewRole(ply)
	if CLIENT then return end
	
	--NOTE: BUCKETS.OTHER is not necessarily just all of the roles on TEAM_NONE.
	--It may contain esoteric roles like the Bodyguard, which is technically on TEAM_INNOCENT despite not necessarily being an innocent role.
	local ply_type = BUCKETS.OTHER
	if ply:GetTeam() == TEAM_INNOCENT and ply:GetBaseRole() ~= ROLE_DETECTIVE then
		ply_type = BUCKETS.INNO
	elseif ply:GetTeam() == TEAM_INNOCENT and ply:GetBaseRole() == ROLE_DETECTIVE then
		ply_type = BUCKETS.DET
	elseif ply:GetTeam() == TEAM_TRAITOR then
		ply_type = BUCKETS.TRA
	elseif ply:GetTeam() ~= TEAM_NONE and ply:GetTeam() ~= TEAM_INNOCENT and ply:GetTeam() ~= TEAM_TRAITOR then
		ply_type = BUCKETS.EVIL
	end
	
	--Viable roles are those that the player could have feasible gotten at the beginning of the round
	--With a catch: all viable roles must be on the same team as the player.
	local role_data_list = roles.GetList()
	local viable_role_list = {}
	for i = 1, #role_data_list do
		local role_data = role_data_list[i]
		if role_data.notSelectable or role_data.index == ROLE_NONE or (ROLE_DEFECTIVE and role_data.index == ROLE_DEFECTIVE) then
			--notSelectable is true for roles spawned under special circumstances, such as the Ravenous or the Graverobber.
			--ROLE_NONE should not be messed with. It would be mildly funny if it were selectable, but would probably bug out the server.
			--Defective should not be selectable, as it will reveal the traitor (since normal innocents can't become detectives via this weapon)
			continue
		end
		
		--role_data.builtin will be true for INNOCENT and TRAITOR, which are always enabled.
		local enabled = true
		local min_players = 0
		if not role_data.builtin then
			enabled = GetConVar("ttt_" .. role_data.name .. "_enabled"):GetBool()
			min_players = GetConVar("ttt_" .. role_data.name .. "_min_players"):GetInt()
		end
		if not enabled or min_players > NUM_PLYS_AT_ROUND_BEGIN then
			continue
		end
		
		if ply_type == BUCKETS.INNO and role_data.defaultTeam == TEAM_INNOCENT and (role_data.index == ROLE_INNOCENT or role_data.baserole == ROLE_INNOCENT) or
			ply_type == BUCKETS.DET and role_data.defaultTeam == TEAM_INNOCENT and (role_data.index == ROLE_DETECTIVE or role_data.baserole == ROLE_DETECTIVE) or
			ply_type == BUCKETS.TRA and role_data.defaultTeam == TEAM_TRAITOR or
			ply_type == BUCKETS.EVIL and ply:GetTeam() == role_data.defaultTeam and role_data.defaultTeam ~= TEAM_NONE and role_data.defaultTeam ~= TEAM_INNOCENT and role_data.defaultTeam ~= TEAM_TRAITOR or
			ply_type == BUCKETS.OTHER and (role_data.defaultTeam == TEAM_NONE or (role_data.defaultTeam == TEAM_INNOCENT and role_data.index ~= ROLE_INNOCENT and role_data.baserole ~= ROLE_INNOCENT and role_data.index ~= ROLE_DETECTIVE and role_data.baserole ~= ROLE_DETECTIVE)) then
			viable_role_list[#viable_role_list + 1] = role_data.index
		end
	end
	
	if #viable_role_list <= 0 then
		--RCD_DEBUG
		--local role_data = roles.GetByIndex(ply:GetSubRole())
		--local role_str = role_data.name
		--print("RCD_DEBUG Role list is empty for " .. ply:GetName() .. " (ROLE: ".. role_str .. ")! Probably because the player has a role that the server wouldn't normally allow.")
		return
	end
	
	local new_role = viable_role_list[math.random(1, #viable_role_list)]
	
	--RCD_DEBUG
	--PrintRoleList("(RCD) Viable Roles for " .. ply:GetName(), viable_role_list)
	--local prev_role_data = roles.GetByIndex(ply:GetSubRole())
	--local prev_role_str = prev_role_data.name
	--local new_role_data = roles.GetByIndex(new_role)
	--local new_role_str = new_role_data.name
	--print("  Role will change from: " .. prev_role_str .. " to " .. new_role_str)
	
	if new_role ~= ply:GetSubRole() then
		ply:SetRole(new_role)
		--Call this whenever a role change has occurred.
		SendFullStateUpdate()
	end
end

local function RoleChangeDeagleCallback(attacker, tr, dmg)
	if CLIENT then return end
	
	--Invalid shot return
	if GetRoundState() ~= ROUND_ACTIVE or not IsValid(attacker) or not attacker:IsPlayer() or not attacker:IsTerror() then
		return
	end
	
	local target = tr.Entity
	local target_is_valid_ply = IsValid(target) and target:IsPlayer() and target:IsTerror()
	if not target_is_valid_ply or (not GetConVar("ttt2_role_change_allow_same"):GetBool() and target.role_change_deagle_hit) then
		--Miss or failed: start cooldown timer and return
		local cooldown = GetConVar("ttt2_role_change_deagle_refill_time"):GetInt()
		if cooldown > 0 then
			net.Start("ttt_role_change_deagle_miss")
			net.Send(attacker)
			
			timer.Create("ttt2_role_change_deagle_refill_timer", cooldown, 1, function()
				--Created so that the server can know when the deagle can next be used.
				return
			end)
		end
		
		if target_is_valid_ply and not GetConVar("ttt2_role_change_allow_same"):GetBool() and target.role_change_deagle_hit then
			LANG.Msg(attacker, "SAME_PLY_ROLE_CHANGE_DEAGLE", {name = target:GetName()}, MSG_MSTACK_WARN)
		end
		
		return
	end
	
	AssignNewRole(target)
	target.role_change_deagle_hit = true
	
	--Check against 1 instead of 0 as the ammo hasn't been deducted yet.
	--Remove deagle here because it requires less code and work.
	local deagle = attacker:GetWeapon("weapon_ttt2_role_change_deagle")
	if IsValid(deagle) and deagle:Clip1() <= 1 then
		deagle:Remove()
	end
	
	return true
end

function SWEP:CanPrimaryAttack()
	if self.Weapon:Clip1() <= 0 or timer.Exists("ttt2_role_change_deagle_refill_timer") then
		self:EmitSound( "Weapon_Pistol.Empty" )
		self:SetNextPrimaryFire( CurTime() + 0.2 )
		self:Reload()
		return false
	end

	return true
end

function SWEP:ShootBullet(dmg, recoil, numbul, cone)
	cone = cone or 0.01
	
	local bullet = {}
	bullet.Num = 1
	bullet.Src = self:GetOwner():GetShootPos()
	bullet.Dir = self:GetOwner():GetAimVector()
	bullet.Spread = Vector(cone, cone, 0)
	bullet.Tracer = 0
	bullet.TracerName = self.Tracer or "Tracer"
	bullet.Force = 10
	bullet.Damage = 0
	bullet.Callback = RoleChangeDeagleCallback
	
	self:GetOwner():FireBullets(bullet)
	self.BaseClass.ShootBullet(self, dmg, recoil, numbul, cone)
end

function SWEP:OnRemove()
	if CLIENT then
		STATUS:RemoveStatus("ttt2_role_change_deagle_reloading")
	end
		
	timer.Stop("ttt2_role_change_deagle_refill_timer")
end

if CLIENT then
	hook.Add("Initialize", "InitializeRoleChangeDeagle", function()
		STATUS:RegisterStatus("ttt2_role_change_deagle_reloading", {
			hud = Material("vgui/ttt/hud_icon_deagle.png"),
			type = "bad"
		})
	end)
	
	net.Receive("ttt_role_change_deagle_miss", function()
		local client = LocalPlayer()
		if not IsValid(client) or not client:IsTerror() or not client:HasWeapon("weapon_ttt2_role_change_deagle") then
			return
		end
		
		local wep = client:GetWeapon("weapon_ttt2_role_change_deagle")
		if not IsValid(wep) then
			return
		end
		
		local cooldown = GetConVar("ttt2_role_change_deagle_refill_time"):GetInt()
		STATUS:AddTimedStatus("ttt2_role_change_deagle_reloading", cooldown, true)
		timer.Create("ttt2_role_change_deagle_refill_timer", cooldown, 1, function()
			if not IsValid(wep) then
				return
			end
			
			RoleChangeDeagleRefilled(wep)
		end)
	end)
else --SERVER
	hook.Add("TTTEndRound", "ResetRoleChangeDeagleForServerOnEndRound", function()
		for _, ply in ipairs(player.GetAll()) do
			ply.role_change_deagle_hit = nil
		end
	end)
	
	net.Receive("ttt_role_change_deagle_refilled", function()
		local wep = net.ReadEntity()
		
		if not IsValid(wep) then
			return
		end
		
		wep:SetClip1(wep:Clip1() + 1)
	end)
end