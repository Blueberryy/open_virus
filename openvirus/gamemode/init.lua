-- Initialize the gamemode!

include( "shared.lua" )
include( "player.lua" )

if ( file.Exists( "openvirus/gamemode/ov_maplua/"..game.GetMap()..".lua", "LUA" ) ) then

	include( "ov_maplua/"..game.GetMap()..".lua" )

end

AddCSLuaFile( "cl_scoreboard.lua" )


-- ConVars
local ov_sv_infection_serverside_only = CreateConVar( "ov_sv_infection_serverside_only", "0", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Disable client-sided infecting and forces server-side infecting instead. Doesn't help people with lag problems." )
local ov_sv_infection_clientside_valid_distance = CreateConVar( "ov_sv_infection_clientside_valid_distance", "256", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "With client-side infection, we make sure the distance between players is considered valid. This can prevent client-side scripts from being able to cheat." )
local ov_sv_infected_blood = CreateConVar( "ov_sv_infected_blood", "1", FCVAR_ARCHIVE, "Enable the infected blood effects." )
local ov_sv_survivor_css_hands = CreateConVar( "ov_sv_survivor_css_hands", "1", FCVAR_ARCHIVE, "Hands will be forced as CS:S hands for survivors." )
local ov_sv_enable_player_radar = CreateConVar( "ov_sv_enable_player_radar", "1", FCVAR_NOTIFY, "Players can see the radar." )
local ov_sv_enable_player_ranking = CreateConVar( "ov_sv_enable_player_ranking", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Announce player ranks during the game." )
local ov_sv_survivor_mystery_weapons = CreateConVar( "ov_sv_survivor_mystery_weapons", "0", FCVAR_NOTIFY, "Survivors get their weapons when the round begins." )


-- Functions down here
-- Called when the game is initialized
function GM:Initialize()

	-- Global variables
	OV_Game_WaitingForPlayers = true
	OV_Game_PreRound = false
	OV_Game_InRound = false
	OV_Game_LastSurvivor = false
	OV_Game_EndRound = false
	OV_Game_Round = 0
	OV_Game_MaxRounds = 10
	OV_Game_MinimumPlayers = 4

	OV_Game_MainRoundTimerCount = 90

	OV_Game_WeaponLoadout = {}
	OV_Game_WeaponLoadout_Primary = {}
	OV_Game_WeaponLoadout_Secondary = {}
	OV_Game_WeaponLoadout_Shotguns = {}
	OV_Game_WeaponLoadout_RemoveSelected = ""

	OV_Game_LastRandomChosenInfected = {}

	OV_Game_PlayerRank_Table = {}
	OV_Game_PlayerRank_First = 0
	OV_Game_PlayerRank_Second = 0
	OV_Game_PlayerRank_Third = 0

	SetGlobalBool( "OV_Game_PreventEnraged", false ) -- Used to prevent further enraged states

	-- Network Strings
	util.AddNetworkString( "OV_UpdateRoundStatus" )
	util.AddNetworkString( "OV_SendTimerCount" )
	util.AddNetworkString( "OV_SendDamageValue" )
	util.AddNetworkString( "OV_ClientsideInfect" )
	util.AddNetworkString( "OV_SendInfoText" )
	util.AddNetworkString( "OV_SetMusic" )
	util.AddNetworkString( "OV_ClientInitializedMusic" )
	util.AddNetworkString( "OV_SettingsEnabled" )

	-- Set the default deploy speed to 1
	game.ConsoleCommand( "sv_defaultdeployspeed 1\n" )

	-- Set alltalk to 1
	game.ConsoleCommand( "sv_alltalk 1\n" )

	-- ConCommands
	concommand.Add( "invwep", function( ply, cmd, args, argstring ) if ( IsValid( ply ) && ply:Alive() && ( ply:Team() == TEAM_SURVIVOR ) ) then ply:SelectWeapon( argstring ) end end )
	concommand.Add( "ov_net_update", function( ply )
	
		if ( OV_Game_InRound ) then
		
			net.Start( "OV_UpdateRoundStatus" )
				net.WriteBool( OV_Game_WaitingForPlayers )
				net.WriteBool( OV_Game_PreRound )
				net.WriteBool( OV_Game_InRound )
				net.WriteBool( OV_Game_EndRound )
				net.WriteInt( OV_Game_Round, 8 )
				net.WriteInt( OV_Game_MaxRounds, 8 )
			net.Send( ply )
		
			if ( timer.Exists( "OV_RoundTimer" ) ) then
			
				net.Start( "OV_SendTimerCount" )
					net.WriteFloat( timer.TimeLeft( "OV_RoundTimer" ) )
				net.Broadcast()
			
			end
		
			net.Start( "OV_SettingsEnabled" )
				net.WriteBool( ov_sv_enable_player_radar:GetBool() )
				net.WriteBool( ov_sv_enable_player_ranking:GetBool() )
			net.Send( ply )
		
		end
	
	end )

end


-- Can players hear another player using voice
function GM:PlayerCanHearPlayersVoice( listener, talker )

	return true

end


-- Client has sent us information that they want to infect someone
function OV_ClientsideInfect( len, ply )

	if ( ov_sv_infection_serverside_only:GetBool() ) then return end
	if ( !OV_Game_InRound ) then return end

	local target_ply = net.ReadEntity()
	if ( IsValid( ply ) && ply:Alive() && ( ply:Team() == TEAM_INFECTED ) && ply:GetInfectionStatus() && IsValid( target_ply ) && target_ply:IsPlayer() && target_ply:Alive() && ( target_ply:Team() == TEAM_SURVIVOR ) ) then
	
		-- Validate the distance between the players
		if ( ply:GetPos():Distance( target_ply:GetPos() ) <= ov_sv_infection_clientside_valid_distance:GetFloat() ) then
		
			target_ply:InfectPlayer( ply )
		
		end
	
	end

end
net.Receive( "OV_ClientsideInfect", OV_ClientsideInfect )


-- Client has initialized music
function OV_ClientInitializedMusic( len, ply )

	if ( !OV_Game_EndRound && IsValid( ply ) ) then
	
		OV_SetMusic( 0, ply )
	
		if ( OV_Game_WaitingForPlayers ) then
		
			OV_SetMusic( 1, ply )
		
		elseif ( OV_Game_PreRound ) then
		
			OV_SetMusic( 2, ply )
		
		elseif ( OV_Game_InRound ) then
		
			if ( OV_Game_LastSurvivor ) then
			
				OV_SetMusic( 4, ply )
			
			else
			
				OV_SetMusic( 3, ply )
			
			end
		
		end
	
	end

end
net.Receive( "OV_ClientInitializedMusic", OV_ClientInitializedMusic )


-- Global function to set music
function OV_SetMusic( int, ply )

	-- Send to a specific player instead
	if ( IsValid( ply ) && ply:IsPlayer() ) then
	
		net.Start( "OV_SetMusic" )
			net.WriteInt( int, 4 )
		net.Send( ply )
	
		return
	
	end

	net.Start( "OV_SetMusic" )
		net.WriteInt( int, 4 )
	net.Broadcast()

end


-- Called every tick
function GM:Think()

	-- Infected cannot infect players instantly when they spawn
	if ( OV_Game_InRound || OV_Game_EndRound ) then
	
		for _, ply in pairs( team.GetPlayers( TEAM_INFECTED ) ) do
		
			if ( IsValid( ply ) && ply:Alive() && !ply:GetInfectionStatus() && ( ply.timeInfectionStatus < CurTime() ) ) then
				
				ply:SetInfectionStatus( 1 )
				
			end
		
		end
	
	end

	-- Player adrenaline status needs to run out eventually
	if ( OV_Game_PreRound || OV_Game_InRound || OV_Game_EndRound ) then
	
		for _, ply in pairs( team.GetPlayers( TEAM_SURVIVOR ) ) do
		
			if ( IsValid( ply ) && ply:GetAdrenalineStatus() && ( ply.timeAdrenalineStatus < CurTime() ) ) then
			
				ply:SetAdrenalineStatus( 0 )
			
			end
		
		end
	
	end

	-- Enraged players must be cancelled
	if ( !GetGlobalBool( "OV_Game_PreventEnraged" ) && ( OV_Game_InRound || OV_Game_EndRound ) && ( team.NumPlayers( TEAM_INFECTED ) > 1 ) ) then
	
		for _, ply in pairs( team.GetPlayers( TEAM_INFECTED ) ) do
		
			if ( IsValid( ply ) && ply:GetEnragedStatus() ) then
			
				ply:SetEnragedStatus( 0 )
			
			end
		
		end
	
		SetGlobalBool( "OV_Game_PreventEnraged", true )
	
	end

	-- Last survivor engaged
	if ( OV_Game_InRound && !OV_Game_LastSurvivor && ( team.NumPlayers( TEAM_SURVIVOR ) <= 1 ) ) then
	
		for _, ply in pairs( team.GetPlayers( TEAM_SURVIVOR ) ) do
		
			if ( IsValid( ply ) && ply:Alive() ) then
			
				OV_Game_LastSurvivor = true
			
				OV_SetMusic( 0 )
			
				net.Start( "OV_SendInfoText" )
					net.WriteString( string.upper( ply:Name() ).." IS THE LAST SURVIVOR" )
					net.WriteColor( Color( 255, 255, 255 ) )
					net.WriteInt( 5, 4 )
				net.Broadcast()
			
				OV_SetMusic( 4 )
				BroadcastLua( "surface.PlaySound( \"openvirus/vo/ov_vo_lastchance.wav\" )" )
			
			end
		
		end
	
	end

	-- Bots do not have clientside infection check or we are forcing serverside infection
	if ( OV_Game_InRound && ( ( #player.GetBots() > 0 ) || ov_sv_infection_serverside_only:GetBool() ) ) then
	
		for _, ply in pairs( player.GetAll() ) do
		
			if ( IsValid( ply ) && ( ply:IsBot() || ov_sv_infection_serverside_only:GetBool() ) && ply:Alive() && ( ply:Team() == TEAM_INFECTED ) && ply:GetInfectionStatus() ) then
			
				for _, ent in pairs( ents.FindInSphere( ply:EyePos() - Vector( 0, 0, 16 ), 8 ) ) do
				
					if ( IsValid( ent ) && ent:IsPlayer() && ( ent:Health() > 0 ) && ( ent:Team() == TEAM_SURVIVOR ) ) then
					
						ent:InfectPlayer( ply )
					
					end
				
				end
			
			end
		
		end
	
	end

	-- Select a random person to be infected
	if ( OV_Game_InRound && ( team.NumPlayers( TEAM_INFECTED ) < 1 ) ) then
	
		for _, ply in pairs( team.GetPlayers( TEAM_SURVIVOR ) ) do
		
			if ( ( team.NumPlayers( TEAM_INFECTED ) < 1 ) && IsValid( ply ) && ( !table.HasValue( OV_Game_LastRandomChosenInfected, ply:SteamID() ) || ply:IsBot() ) ) then
			
				if ( math.random( 1, team.NumPlayers( TEAM_SURVIVOR ) ) == ( team.NumPlayers( TEAM_SURVIVOR ) ) ) then
				
					BroadcastLua( "surface.PlaySound( \"openvirus/effects/ov_stinger.wav\" )" )
				
					ply:InfectPlayer()
				
					table.insert( OV_Game_LastRandomChosenInfected, ply:SteamID() )
				
				end
			
			end
		
		end
	
	end

end


-- Called when an entity takes damage
function GM:EntityTakeDamage( ent, info )

	-- Infected blood effects
	if ( ov_sv_infected_blood:GetBool() && IsValid( ent ) && ent:IsPlayer() && ent:Alive() && ( ent:Team() == TEAM_INFECTED ) ) then
	
		local bloodeffect = EffectData()
		bloodeffect:SetOrigin( info:GetDamagePosition() )
		util.Effect( "infectedblood", bloodeffect )
	
	end

end


-- Called when the player is hurt
function GM:PlayerHurt( ply, attacker, health, dmg )

	-- Send damage values to the client
	if ( IsValid( attacker ) && attacker:IsPlayer() && ( attacker:Health() > 0 ) && ( attacker:Team() == TEAM_SURVIVOR ) ) then
	
		net.Start( "OV_SendDamageValue" )
			net.WriteInt( dmg, 16 )
			net.WriteVector( ply:LocalToWorld( ply:OBBCenter() + Vector( 0, 0, 32 ) ) )
		net.Send( attacker )
	
		attacker:SendLua( "surface.PlaySound( \"buttons/blip1.wav\" )" )
	
	end

	-- Infected health is shown briefly
	if ( IsValid( ply ) && ply:Alive() && ( ply:Team() == TEAM_INFECTED ) ) then
	
		ply:SetNWInt( "InfectedLastHurt", CurTime() + 4 )
	
	end

end


-- 4 players or over this should begin
function GM:BeginWaitingSession()

	-- Stop the music
	OV_SetMusic( 0 )

	net.Start( "OV_UpdateRoundStatus" )
		net.WriteBool( OV_Game_WaitingForPlayers )
		net.WriteBool( OV_Game_PreRound )
		net.WriteBool( OV_Game_InRound )
		net.WriteBool( OV_Game_EndRound )
		net.WriteInt( OV_Game_Round, 8 )
		net.WriteInt( OV_Game_MaxRounds, 8 )
	net.Broadcast()

	timer.Create( "OV_RoundTimer", 15, 1, function() GAMEMODE:BeginPreRound() end )

	net.Start( "OV_SendTimerCount" )
		net.WriteFloat( timer.TimeLeft( "OV_RoundTimer" ) )
	net.Broadcast()

	-- Start some music
	OV_SetMusic( 1 )

end


-- The PreRound moment before we start the actual game
function GM:BeginPreRound()

	-- Stop the music
	OV_SetMusic( 0 )

	-- Add to the round counter
	OV_Game_Round = OV_Game_Round + 1

	-- Set up a new set of weapons for players
	OV_Game_WeaponLoadout = {
		"weapon_ov_m3",
		"weapon_ov_pistol",
		"weapon_ov_flak",
		"weapon_ov_dualpistol",
		"weapon_ov_laserpistol",
		"weapon_ov_silencedpistol",
		"weapon_ov_p90",
		"weapon_ov_laserrifle",
		"weapon_ov_xm1014",
		"weapon_ov_mp5",
		"weapon_ov_smg1",
		"weapon_ov_sniper",
		"weapon_ov_slam",
		"weapon_ov_adrenaline"
	}

	-- List primary weapons
	OV_Game_WeaponLoadout_Primary = {
		"weapon_ov_pistol",
		"weapon_ov_dualpistol",
		"weapon_ov_laserpistol",
		"weapon_ov_silencedpistol"
	}

	-- List secondary weapons
	OV_Game_WeaponLoadout_Secondary = {
		"weapon_ov_p90",
		"weapon_ov_laserrifle",
		"weapon_ov_mp5",
		"weapon_ov_smg1"
	}

	-- List shotgun weapons
	OV_Game_WeaponLoadout_Shotguns = {
		"weapon_ov_m3",
		"weapon_ov_xm1014"
	}

	-- Remove some primary weapons
	for removenum = 1, ( #OV_Game_WeaponLoadout_Primary - 2 ) do
	
		OV_Game_WeaponLoadout_RemoveSelected = table.Random( OV_Game_WeaponLoadout_Primary )
		table.RemoveByValue( OV_Game_WeaponLoadout, OV_Game_WeaponLoadout_RemoveSelected )
		table.RemoveByValue( OV_Game_WeaponLoadout_Primary, OV_Game_WeaponLoadout_RemoveSelected )
	
	end

	-- Remove some secondary weapons
	for removenum = 1, ( #OV_Game_WeaponLoadout_Secondary - math.random( 1, 2 ) ) do
	
		OV_Game_WeaponLoadout_RemoveSelected = table.Random( OV_Game_WeaponLoadout_Secondary )
		table.RemoveByValue( OV_Game_WeaponLoadout, OV_Game_WeaponLoadout_RemoveSelected )
		table.RemoveByValue( OV_Game_WeaponLoadout_Secondary, OV_Game_WeaponLoadout_RemoveSelected )
	
	end

	-- Remove some shotguns
	for removenum = 1, ( #OV_Game_WeaponLoadout_Shotguns - math.random( 0, 1 ) ) do
	
		OV_Game_WeaponLoadout_RemoveSelected = table.Random( OV_Game_WeaponLoadout_Shotguns )
		table.RemoveByValue( OV_Game_WeaponLoadout, OV_Game_WeaponLoadout_RemoveSelected )
		table.RemoveByValue( OV_Game_WeaponLoadout_Shotguns, OV_Game_WeaponLoadout_RemoveSelected )
	
	end

	-- Random special weapons
	if ( table.HasValue( OV_Game_WeaponLoadout, "weapon_ov_laserrifle" ) && ( math.random( 1, 4 ) >= 4 ) ) then table.RemoveByValue( OV_Game_WeaponLoadout, "weapon_ov_laserrifle" ) table.insert( OV_Game_WeaponLoadout, "weapon_ov_laserriflehybrid" ) end
	if ( math.random( 1, 6 ) > 1 ) then table.RemoveByValue( OV_Game_WeaponLoadout, "weapon_ov_flak" ) end
	if ( table.HasValue( OV_Game_WeaponLoadout, "weapon_ov_flak" ) || ( math.random( 1, 8 ) > 1 ) ) then table.RemoveByValue( OV_Game_WeaponLoadout, "weapon_ov_sniper" ) end

	-- Here we will clean up the map
	game.CleanUpMap()

	OV_Game_WaitingForPlayers = false
	OV_Game_PreRound = true
	OV_Game_InRound = false
	OV_Game_LastSurvivor = false
	OV_Game_EndRound = false

	OV_Game_PlayerRank_First = 0
	OV_Game_PlayerRank_Second = 0
	OV_Game_PlayerRank_Third = 0

	SetGlobalBool( "OV_Game_PreventEnraged", false )

	net.Start( "OV_UpdateRoundStatus" )
		net.WriteBool( OV_Game_WaitingForPlayers )
		net.WriteBool( OV_Game_PreRound )
		net.WriteBool( OV_Game_InRound )
		net.WriteBool( OV_Game_EndRound )
		net.WriteInt( OV_Game_Round, 8 )
		net.WriteInt( OV_Game_MaxRounds, 8 )
	net.Broadcast()

	timer.Create( "OV_RoundTimer", math.random( 20, 25 ), 1, function() GAMEMODE:BeginMainRound() end )

	-- Close Scoreboard for players
	BroadcastLua( "GAMEMODE:ScoreboardHide()" )

	-- Respawn all players
	for _, ply in pairs( player.GetAll() ) do
	
		ply:Freeze( false )
	
		ply:SetTeam( TEAM_SURVIVOR )
		ply:SetColor( Color( 255, 255, 255 ) )
		ply:SetEnragedStatus( 0 )
		ply:SetInfectionStatus( 0 )
		ply:SetAdrenalineStatus( 0 )
		ply:SetNWFloat( "OV_TimeSurvived", 0 )
	
		ply:SetFrags( 0 )
		ply:SetDeaths( 0 )
	
		ply:RemoveAllItems()
	
		ply:Spawn()
	
	end

	-- Indicate that the infection is about to spread
	net.Start( "OV_SendInfoText" )
		net.WriteString( "THE INFECTION IS ABOUT TO SPREAD" )
		net.WriteColor( Color( 255, 255, 255 ) )
		net.WriteInt( 5, 4 )
	net.Broadcast()

	-- Indicate that this is the last round
	if ( OV_Game_Round >= OV_Game_MaxRounds ) then
	
		net.Start( "OV_SendInfoText" )
			net.WriteString( "THIS IS THE LAST ROUND" )
			net.WriteColor( Color( 255, 255, 255 ) )
			net.WriteInt( 5, 4 )
		net.Broadcast()
	
	end

	-- Start some music
	OV_SetMusic( 2 )

end


-- Begin the main Round
function GM:BeginMainRound()

	-- Do not begin the main round if we are below minimum player requirement
	if ( player.GetCount() < OV_Game_MinimumPlayers ) then
	
		timer.Create( "OV_RoundTimer", 1, 1, function() GAMEMODE:BeginMainRound() end )
		return
	
	end

	-- Stop music
	OV_SetMusic( 0 )

	-- Give weapons to players in mystery weapons mode
	if ( ov_sv_survivor_mystery_weapons:GetBool() ) then
	
		for _, ply in pairs( player.GetAll() ) do
		
			if ( IsValid( ply ) && ply:Alive() && ( ply:Team() == TEAM_SURVIVOR ) ) then
			
				hook.Call( "PlayerLoadout", GAMEMODE, ply )
			
			end
		
		end
	
	end

	OV_Game_PreRound = false
	OV_Game_InRound = true

	net.Start( "OV_UpdateRoundStatus" )
		net.WriteBool( OV_Game_WaitingForPlayers )
		net.WriteBool( OV_Game_PreRound )
		net.WriteBool( OV_Game_InRound )
		net.WriteBool( OV_Game_EndRound )
		net.WriteInt( OV_Game_Round, 8 )
		net.WriteInt( OV_Game_MaxRounds, 8 )
	net.Broadcast()

	timer.Create( "OV_RoundTimer", OV_Game_MainRoundTimerCount, 1, function() GAMEMODE:EndMainRound() end )

	net.Start( "OV_SendTimerCount" )
		net.WriteFloat( timer.TimeLeft( "OV_RoundTimer" ) )
	net.Broadcast()

	-- Start some music
	OV_SetMusic( 3 )

	-- Clean up the last chosen infected table
	if ( #OV_Game_LastRandomChosenInfected >= player.GetCount() ) then
	
		OV_Game_LastRandomChosenInfected = {}
	
	end
	
	-- Update settings
	net.Start( "OV_SettingsEnabled" )
		net.WriteBool( ov_sv_enable_player_radar:GetBool() )
		net.WriteBool( ov_sv_enable_player_ranking:GetBool() )
	net.Broadcast()

	-- Allow for events to happen after the round has started
	hook.Call( "PostBeginMainRound", GAMEMODE )

end


-- End the main Round
function GM:EndMainRound()

	-- Stop music
	OV_SetMusic( 0 )

	for _, ply in pairs( player.GetAll() ) do
	
		ply:Freeze( true )
		if ( ply:GetAdrenalineStatus() ) then ply:SetAdrenalineStatus( 0 ) end
	
	end

	OV_Game_InRound = false
	OV_Game_EndRound = true

	net.Start( "OV_UpdateRoundStatus" )
		net.WriteBool( OV_Game_WaitingForPlayers )
		net.WriteBool( OV_Game_PreRound )
		net.WriteBool( OV_Game_InRound )
		net.WriteBool( OV_Game_EndRound )
		net.WriteInt( OV_Game_Round, 8 )
		net.WriteInt( OV_Game_MaxRounds, 8 )
	net.Broadcast()

	timer.Create( "OV_RoundTimer", 15, 1, function() GAMEMODE:BeginPreRound() end )

	net.Start( "OV_SendTimerCount" )
		net.WriteFloat( timer.TimeLeft( "OV_RoundTimer" ) )
	net.Broadcast()

	if ( team.NumPlayers( TEAM_SURVIVOR ) > 0 ) then
	
		net.Start( "OV_SendInfoText" )
			net.WriteString( "THE SURVIVORS WIN" )
			net.WriteColor( Color( 255, 255, 255 ) )
			net.WriteInt( 5, 4 )
		net.Broadcast()
	
		OV_SetMusic( 6 )
		BroadcastLua( "surface.PlaySound( \"openvirus/vo/ov_vo_survivorswin.wav\" )" )
	
	else
	
		net.Start( "OV_SendInfoText" )
			net.WriteString( "THE INFECTION HAS SPREAD" )
			net.WriteColor( Color( 255, 255, 255 ) )
			net.WriteInt( 5, 4 )
		net.Broadcast()
	
		OV_SetMusic( 5 )
		BroadcastLua( "surface.PlaySound( \"openvirus/vo/ov_vo_infectedwin.wav\" )" )
	
	end

	-- Reached the max amount of rounds
	if ( OV_Game_Round >= OV_Game_MaxRounds ) then
	
		-- Remove the RoundTimer
		if ( timer.Exists( "OV_RoundTimer" ) ) then
		
			timer.Remove( "OV_RoundTimer" )
		
		end
	
		timer.Simple( 20, function() OV_LoadNextMap() end )
	
	end

	-- Open Scoreboard for players
	timer.Simple( 2, function() BroadcastLua( "GAMEMODE:ScoreboardShow()" ) end )

	-- Reset ranking on clients
	if ( ov_sv_enable_player_ranking:GetBool() ) then BroadcastLua( "OV_Game_PlayerRank_Position = 0" ) end

	-- Allow for events to happen after the round has ended
	hook.Call( "PostEndMainRound", GAMEMODE )

end


-- Function used for loading the next map
function OV_LoadNextMap()

	-- MapVote integration (thanks for the idea Wolvindra)
	if ( MapVote ) then
	
		MapVote.Start( nil, nil, nil, nil )
		return
	
	end

	-- Load up the next map
	game.LoadNextMap()

end


-- During this phase we check for players until we continue
function OV_Game_WaitingForPlayers_GetPlayerCount()

	-- At 4 players or over we should start
	if ( player.GetCount() >= OV_Game_MinimumPlayers ) then
	
		GAMEMODE:BeginWaitingSession()
		timer.Remove( "OV_Game_WaitingForPlayers_GetPlayerCount" )
	
	end

end
timer.Create( "OV_Game_WaitingForPlayers_GetPlayerCount", 1, 0, OV_Game_WaitingForPlayers_GetPlayerCount )


-- Ranking system
function GM:PlayerRankCheckup()

	-- Fail if ov_sv_enable_player_ranking is false
	if ( !ov_sv_enable_player_ranking:GetBool() ) then return end

	-- Fail if we are not in a round
	if ( !OV_Game_InRound ) then return end

	-- Set up our table for sorting
	for _, ply in pairs( player.GetAll() ) do
	
		if ( ply:Team() != TEAM_SPECTATOR ) then
		
			OV_Game_PlayerRank_Table[ ply:UserID() ] = -ply:EntIndex() + ( ply:Frags() * 50 )
		
		end
	
	end

	-- Get the player ranking and announce stuff if we can
	for k, v in pairs( table.SortByKey( OV_Game_PlayerRank_Table ) ) do
	
		if ( k == 1 ) then
		
			-- First place
			if ( IsValid( Player( v ) ) && ( v != OV_Game_PlayerRank_First ) ) then
			
				OV_Game_PlayerRank_First = v
				PrintMessage( HUD_PRINTTALK, Player( v ):Name().." has reached 1st place!" )
			
				net.Start( "OV_SendInfoText" )
					net.WriteString( "AWESOME! YOU'VE REACHED 1ST PLACE" )
					net.WriteColor( Color( 255, 255, 255 ) )
					net.WriteInt( 3, 4 )
				net.Send( Player( v ) )
			
			end
		
		elseif ( k == 2 ) then
		
			-- Second place
			if ( IsValid( Player( v ) ) && ( v != OV_Game_PlayerRank_Second ) ) then
			
				OV_Game_PlayerRank_Second = v
				PrintMessage( HUD_PRINTTALK, Player( v ):Name().." is now in 2nd place." )
			
				net.Start( "OV_SendInfoText" )
					net.WriteString( "YOU'RE IN 2ND PLACE" )
					net.WriteColor( Color( 255, 255, 255 ) )
					net.WriteInt( 3, 4 )
				net.Send( Player( v ) )
			
			end
		
		elseif ( k == 3 ) then
		
			-- Third place
			if ( IsValid( Player( v ) ) && ( v != OV_Game_PlayerRank_Third ) ) then
			
				OV_Game_PlayerRank_Third = v
				PrintMessage( HUD_PRINTTALK, Player( v ):Name().." is now in 3rd place." )
			
				net.Start( "OV_SendInfoText" )
					net.WriteString( "YOU'RE IN 3RD PLACE" )
					net.WriteColor( Color( 255, 255, 255 ) )
					net.WriteInt( 3, 4 )
				net.Send( Player( v ) )
			
			end
		
		end
	
	end

	-- Free up the table
	OV_Game_PlayerRank_Table = {}

end


-- Show Help
function GM:ShowHelp( ply )

	ply:SendLua( "GAMEMODE:ShowHelp()" )

end
