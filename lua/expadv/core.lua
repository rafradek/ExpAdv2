/* --- --------------------------------------------------------------------------------
	@: Create the Expression Advanced Namespace.
   --- */

EXPADV = { }
MsgN( "Expression advanced Two - Installing..." )
include( "net.lua" )
include( "von.lua" )

/* --- --------------------------------------------------------------------------------
	@: Debugging Stuff
   --- */

local DebugMsg = CreateConVar( "expadv_debug", "0", {FCVAR_REPLICATED} )

function EXPADV.Msg( ... )
	if DebugMsg:GetInt( ) <= 0 then return end
	MsgN( ... )
end

function describe(object, Message, first, ...)
	if Message then
		if first then Message = string.format(Message, first, ...) end
		MsgN(Message)
	end

	local Type = string.lower(type(object))
	MsgN("TYPE: ", Type)

	if Type == "nil" then
		return
	elseif Type == "string" then
		MsgN("LENGH: ", #object)
		MsgN("VALUE: ", object)
	elseif Type == "number" then
		MsgN("VALUE: ", object)
	elseif Type == "table" then
		MsgN("Size: ", #object)
		MsgN("Count: ", table.Count(object))
		MsgN("POINTER: ", object)
	end
end
/* --- --------------------------------------------------------------------------------
	@: Sometimes We might need to convert objects into native.
   --- */

local Cache, ToLua, ToLuaTable = { }

EXPADV.__Cache = Cache

function ToLua( Value, bNoTables, bNoFunctions )
	if !Value then return "nil" end
	
	local Type = type(Value)
	
	if Type == "number" then
		return Value
	elseif Type == "string" then
		return string.format( "%q", Value )
	elseif Type == "boolean" then
		return Value and "true" or "false"
	elseif Type == "table" and !bNoTables then
		return ToLuaTable( Value )
	elseif Type == "function" and !NoTables and !bNoFunctions then
		local Index = #Cache + 1
		Cache[Index] = Value
		return "EXPADV.__Cache[" .. Index .. "]"
	end
end

EXPADV.ToLua = ToLua

/* --- --------------------------------------------------------------------------------
	@: We need config files.
   --- */

function ToLuaTable( Table )
	local Lua = "{"
	
	for Key, Value in pairs(Table) do
		local kLua = ToLua( Key, true )
		local vLua = ToLua( Value )
		
		if !kLua then
			error("TableToLua invalid Key of type " .. type(Key))
		elseif !vLua then
			error("TableToLua invalid Value of type " .. type(Value))
		end
		
		Lua = string.format( "%s[%s] = %s, ", Lua, kLua, vLua )
	end
	
	return Lua .. "}"
end

EXPADV.ToLuaTable = ToLuaTable

/* --- --------------------------------------------------------------------------------
	@: We need config files.
   --- */

EXPADV.Config = { }
EXPADV.CL_Settings = { }

function EXPADV.LoadConfig( )
	local Config = { }

	if SERVER then

		if file.Exists( "expadv.txt", "DATA" ) then
			Config = util.KeyValuesToTable( file.Read( "expadv.txt", "DATA" ) )
		end
	
		Config.enabledcomponents = Config.enabledcomponents or { }
		Config.components = Config.components or { }
		Config.settings = Config.settings or { }
		EXPADV.Config = Config

		EXPADV.Msg( "ExpAdv: Loaded config file, sucessfully." )
		EXPADV.CallHook( "PostLoadConfig", Config )

	elseif CLIENT then
		if file.Exists( "cl_expadv.txt", "DATA" ) then
			Config = util.KeyValuesToTable( file.Read( "cl_expadv.txt", "DATA" ) )
		end
	
		Config.components = Config.components or { }
		Config.settings = Config.settings or { }
		EXPADV.CL_Settings = Config

		EXPADV.Msg( "ExpAdv: Loaded config file, sucessfully." )
		EXPADV.CallHook( "PostLoadUserSettings", Config )
	end	
end

-- Saves the config file.
function EXPADV.SaveConfig( )
	if SERVER then
		EXPADV.CallHook( "PreSaveConfig", EXPADV.Config )
		file.Write( "expadv.txt", util.TableToKeyValues( EXPADV.Config ) )
	elseif CLIENT then
		EXPADV.CallHook( "PreSaveUserSettings", EXPADV.CL_Settings )
		file.Write( "cl_expadv.txt", util.TableToKeyValues( EXPADV.CL_Settings ) )
	end
end

-- Creates a new setting on the config.
function EXPADV.CreateSetting( Name, Default ) -- String, Obj
	Name = string.lower( Name )

	EXPADV.Config.settings[ Name ] = EXPADV.Config.settings[ Name ] or Default
end

-- Reads a setting from the config.
function EXPADV.ReadSetting( Name, Default ) -- String, Obj
	if !EXPADV.Config or !EXPADV.Config.settings then return Default end
	return EXPADV.Config.settings[ string.lower( Name ) ] or Default
end

-- Creates a new user setting.
function EXPADV.CreateUserSetting( Name, Default ) -- String, Obj
	if SERVER then return end
	Name = string.lower( Name )
	EXPADV.CL_Settings.settings[ Name ] = EXPADV.CL_Settings.settings[ Name ] or Default
end

-- Reads a user setting.
function EXPADV.ReadUserSetting( Name, Default ) -- String, Obj
	if SERVER then return Default end
	if !EXPADV.CL_Settings or !EXPADV.CL_Settings.settings then return Default end
	return EXPADV.CL_Settings.settings[ string.lower( Name ) ] or Default
end

/* --- --------------------------------------------------------------------------------
	@: We need a con command to :D
   --- */

if SERVER then
	local function PrintFromCommand( Player, Msg, A, ... )
		if A then Msg = string.format( Msg, A, ... ) end
		if !IsValid( Player ) then return MsgN( Msg ) end
		Player:ChatPrint( Msg )
	end

	local function SaveAndSendConfig( )
		EXPADV.SaveConfig( )
		EXPADV.SendConfig( )
	end

	local function Command( Player, _, Args )
		local A, B, C = Args[1], Args[2], Args[3]

		if !A or ( IsValid(Player) and !Player:IsAdmin( ) ) then return end

		A = string.lower( A )

		if A == "reload" then
			EXPADV.LoadCore( )
			return PrintFromCommand( Player, "Reloaded Expression Advanced 2" )
		elseif A == "reload_sents" then
			EXPADV.LoadSents()
		end

		if B then B = string.lower( B ) end

		local Config = EXPADV.Config
		if !Config or !Config.components or !Config.settings then return end

		if Config.enabledcomponents[A] ~= nil then
			if !B then
				local D = Config.enabledcomponents[ A ] and "Enabled" or "Disabled"
				return PrintFromCommand( Player, "Component: %s is %s", A, D )
			elseif B == "enable" then
				Config.enabledcomponents[ A ] = 1
				SaveAndSendConfig( )
				return PrintFromCommand( Player, "Component: %s will be enabled after reload.", A, D )
			elseif B == "disable" then
				Config.enabledcomponents[ A ] = 0
				SaveAndSendConfig( )
				return PrintFromCommand( Player, "Component: %s will be disabled after reload.", A, D )
			elseif Config.components[A] then
				local Component = Config.components[A]

				if !Component[B] then
					return PrintFromCommand( Player, "%s.%s: is not a valid setting.", A, B )
				elseif C then
					Component[B] = tonumber(C) or C
					SaveAndSendConfig( )
				end

				return PrintFromCommand( Player, "%s.%s is set to %s", A, B, tostring( Component[B] ) )
			end
		end

		if Config.settings[A] then
			if B then
				Config.settings[A] = tonumber(B) or B
				SaveAndSendConfig( )
			end

			return PrintFromCommand( Player, "%s: %s", A, Config.settings[ string.lower( A ) ] )
		end

		return PrintFromCommand( Player, "No such command %s", A )
	end

	concommand.Add( "sv_expadv", Command )

elseif CLIENT then

	local function AutoComplete( _, Line )
		local A = string.Trim( Line, " " )
		
		local Config = EXPADV.Config
		if !Config then return end

		if A == "" then
			local AC = { "expadv reload", "expadv reload_sents" }

			if Config.settings then
				for Key, _ in pairs( Config.settings ) do
					AC[#AC + 1] = "expadv " .. Key
				end
			end

			if Config.enabledcomponents then
				for Key, _ in pairs( Config.enabledcomponents ) do
					AC[#AC + 1] = "expadv " .. Key
				end
			end

			if Config.components then
				for Key, _ in pairs( Config.components ) do
					if !Config.enabledcomponents[Key] then
						AC[#AC + 1] = "expadv " .. Key
					end
				end
			end

			return AC
		end

		A = string.lower( A )

		if Config.enabledcomponents and Config.enabledcomponents[A] then
			local AC = { string.format( "expadv %s enable", A ), string.format( "expadv %s disable", A ) }

			if Config.components[A] then
				for Key, _ in pairs( Config.components[A] ) do
					AC[#AC + 1] = string.format( "expadv %s %s", A, Key )
				end
			end

			return AC
		end
	end

	local function Command( Player, _, Args )
		RunConsoleCommand( "cmd", "sv_expadv", unpack( Args ) )
	end

	concommand.Add( "expadv", Command, AutoComplete, "Changes a configeration setting for expression advanced 2." )
end


/* --- --------------------------------------------------------------------------------
	@: Exceptions
   --- */

local Temp_Exceptions = { }

-- Registers a new exception type.
function EXPADV.AddException( Component, Exception ) -- Table, String
	Temp_Exceptions[ #Temp_Exceptions + 1 ] = { Component = Component, Exception = Exception }
end

/* --- --------------------------------------------------------------------------------
	@: We have files to load, lets load them.
   --- */

function EXPADV.CleanCore( )
	EXPADV.EXPADV_BaseComponent = nil

	EXPADV.Components = nil
	EXPADV.Operators = nil
	EXPADV.Class_Operators = nil
	EXPADV.Functions = nil
	EXPADV.Events = nil
	EXPADV.Features = nil
	EXPADV.Directives = nil
	EXPADV.Events = nil
	EXPADV.Editor = nil
	EXPADV.Compiler = nil
end

function EXPADV.IncludeCore( )
	include( "expadv/components.lua" )
	include( "expadv/classes.lua" )
	include( "expadv/operators.lua" )
	include( "expadv/events.lua" )
	include( "expadv/features.lua" )
	include( "expadv/directives.lua" )
	include( "expadv/context.lua" )
	include( "expadv/monitors.lua" )
	include( "expadv/cppi.lua" )
end

/* --- --------------------------------------------------------------------------------
	@: Lets loads the core.
   --- */

function EXPADV.AddComponentFile( FileName )
	EXPADV.SharedOperators( )
	EXPADV.Msg( "Loading Component: " .. FileName )
	include( "expadv/components/" .. FileName .. ".lua" )

	if CLIENT then return end

	AddCSLuaFile( "expadv/components/" .. FileName .. ".lua" )
end

function EXPADV.LoadCustomComponents( )

	hook.Run( "expadv.components" )

	local Files = file.Find( "expadv/components/custom/*.lua", "LUA" ) 
	for _, fName in pairs( Files or { } ) do
		local File = "expadv/components/custom/" .. fName
		
		EXPADV.SharedOperators( )
		EXPADV.Msg( "Loading Custom Component: " .. fName )

		include( File )
		if SERVER then AddCSLuaFile( File ) end
	end
end

function EXPADV.LoadCore( )

	MsgN( "Expression advanced Two - Loading." )

	if EXPADV.IsLoaded then
		EXPADV.CallHook( "UnloadCore" )
		EXPADV.IsLoaded = nil
	end

	EXPADV.LoadConfig( )

	EXPADV.CleanCore( )

	EXPADV.IncludeCore( )

	EXPADV.AddComponentFile( "core" )
	EXPADV.AddComponentFile( "number" )
	EXPADV.AddComponentFile( "string" )
	EXPADV.AddComponentFile( "color" )
	EXPADV.AddComponentFile( "vector" )
	EXPADV.AddComponentFile( "angle" )
	EXPADV.AddComponentFile( "quaternion" )
	EXPADV.AddComponentFile( "entity" )
	EXPADV.AddComponentFile( "physics" )
	EXPADV.AddComponentFile( "player" )
	EXPADV.AddComponentFile( "pod" )
	EXPADV.AddComponentFile( "sound" )
	EXPADV.AddComponentFile( "hologram" )
	EXPADV.AddComponentFile( "motionsensor" )
	EXPADV.AddComponentFile( "stream" )
	EXPADV.AddComponentFile( "render" )
	EXPADV.AddComponentFile( "table" )
	EXPADV.AddComponentFile( "array" )
	EXPADV.AddComponentFile( "threads" )
	EXPADV.AddComponentFile( "utility" )
	EXPADV.AddComponentFile( "wire" )
	EXPADV.AddComponentFile( "egp" )
	EXPADV.AddComponentFile( "files" )
	EXPADV.AddComponentFile( "navigation" )
	EXPADV.AddComponentFile( "derma" )
	EXPADV.AddComponentFile( "keyboard" )
	EXPADV.AddComponentFile( "context" )
	EXPADV.AddComponentFile( "android" )
	EXPADV.AddComponentFile( "constraintcore" )
	EXPADV.AddComponentFile( "bot" )

	EXPADV.CallHook( "AddComponents" )

	EXPADV.LoadCustomComponents( )

	EXPADV.LoadComponents( )

	EXPADV.LoadClasses( )

	EXPADV.LoadFeatures( )

	EXPADV.LoadOperators( )

	EXPADV.LoadFunctions( )
	
	EXPADV.LoadEvents( )

	EXPADV.LoadDirectives( )

	EXPADV.Exceptions = { stack = "stack" }

	for I = 1, #Temp_Exceptions do
		local Exception = Temp_Exceptions[I]

		if Exception.Component and !Exception.Component.Enabled then
			continue
		end

		EXPADV.Exceptions[ Exception.Exception ] = Exception.Exception
	end
	
	include( "expadv/compiler/main.lua" )

	EXPADV.SaveConfig( )

	EXPADV.LoadEditor( )

	if SERVER then
		EXPADV.SendConfig( nil, true )

		hook.Add( "PlayerInitialSpawn", "expadv.sendconfig", function( Player )
			EXPADV.SendConfig( Player, true )
		end )
	end
	
	EXPADV.IsLoaded = true

	EXPADV.CallHook( "PostLoadCore" )

	MsgN( "Expression advanced Two - Loading complete." )
end

/* --- --------------------------------------------------------------------------------
	@: Lets loads the old editor.
   --- */

function EXPADV.LoadEditor( )
	
	if CLIENT then
		include( "expadv/editor/ea_filemenu.lua" )
		include( "expadv/editor/ea_button.lua" )
		include( "expadv/editor/ea_closebutton.lua" )
		include( "expadv/editor/ea_editor.lua" )
		include( "expadv/editor/ea_editorpanel.lua" )
		include( "expadv/editor/ea_filenode.lua" )
		include( "expadv/editor/ea_frame.lua" )
		include( "expadv/editor/ea_hscrollbar.lua" )
		include( "expadv/editor/ea_imagebutton.lua" )
		include( "expadv/editor/ea_toolbar.lua" )
		include( "expadv/editor/syntaxer.lua" )
		include( "expadv/editor/pastebin.lua" )
		include( "expadv/editor/ea_search.lua" )
		include( "expadv/editor/ea_codecompletion.lua" )
		include( "expadv/editor.lua" )
		
		include( "expadv/editor/manual.lua" )
	end

	include( "expadv/editor/shared.lua" )
end

/* --- --------------------------------------------------------------------------------
	@: Hooks.
   --- */

   -- Think( )													| Void | Called once per think, this is for convenience.
   -- PostLoadCore( )											| Void | Called after the core has finished loading.
   -- UnloadCore( )												| Void | Called before the core reloads.
   -- PostLoadConfig( Config )									| Void | Called after the main config has loaded.
   -- PreSaveConfig( Config )									| Void | Called before saving the main config file.
   -- PostLoadComponents( ) 									| Void | Called once all components have been loaded.
   -- EnableComponent( Component ) 								| Void | Called after a component enables.
   -- PreLoadOperators( )										| Void | Called before operators are loaded.
   -- PostLoadOperators( )										| Void | Called after operators are loaded.
   -- PreLoadFunctions( )										| Void | Called before functions are loaded.
   -- PostLoadFunctions( )										| Void | Called after functions are loaded.
   -- PreLoadClasses( )											| Void | Called before classes are loaded.
   -- PostLoadClasses( )										| Void | Called after classes are loaded.
   -- PostLoadClassAliases( )									| Void | Called after classes and class aliases are loaded.
   -- PreRegisterClass( Short, Class )							| Void | Called once per class, before class loading begins (classes can be created here).
   -- PostRegisterClass( Name, Class )							| Void | Called after each class has been registered and loaded.
   -- PreLoadCompiler( BaseCompiler )							| Void | Called before the compiler is loaded.
   -- PostLoadCompiler( BaseCompiler )							| Void | Called after the compiler is loaded.
   -- PreCompileScript( Compiler, Script, Files ) 				| Void | Called before the compiler starts main compiler process.
   -- BuildCompilerTokens( TokenArray )							| Void | Called before the compiler builds it token list.
   -- RegisterContext( Context )*								| Void | Called when a context is registered to the core.
   -- UnregisterContext( Context )*								| Void | Called when a context is unregistered from the core.
   -- StartUp( Context )*										| Void | Called before the initial root execution.
   -- ShutDown( Context )*										| Void | Called after the context has shutdown.
   -- Update( Context )*										| Void | Called every tick, when a context has ran that tick.
   -- ClientLoaded( Entity, Player )							| Void | Called server side once a client confirms an entity has loaded its script.
   -- BuildHologramModels( Table )								| Void | Called when the hologram model look up is made.
   -- OpenContextMenu( Entity, ContextMenu, Trace, Option )		| Void | Called when an ExpAdv2 context menu is created.
   -- AddComponents( )											| Void | Called when its time to add custom components.
   -- PostLoadFeatures											| Void | Called when its time to add features.
   -- AddMonitors												| Void | Called when its time to add monitors.
   
   --  function Component:OnPostLoadAliases( ) end
   --  hook.Add( "Expadv.PostLoadAliases", ... )
   -- @GitHub: Please request hooks, and return behavours via issue page.

function EXPADV.CallHook( Name, ... )
	if EXPADV.Components then
		for _, Component in pairs( EXPADV.Components ) do
			if !Component.Enabled then continue end -- Shouldn't be possible!

			local Hook = Component["On" .. Name]
			
			if !Hook then continue end

			local Results = { Hook( Component, ... ) }
			if Results[1] ~= nil then return unpack( ... ) end
		end
	end
	
	return hook.Run( "Expadv." .. Name, ... )
end

/* --- --------------------------------------------------------------------------------
	@: Convenience hooks.
   --- */
   
hook.Add( "Think", "expadv.Hook", function( )
	local Ok, Msg = pcall( EXPADV.CallHook, "Think" )
	
	if !Ok then
		EXPADV.Msg( "ExpAdv2 - Error in main Think hook: ", Msg )
	end
end )

/* --- --------------------------------------------------------------------------------
	@: Quota Managment
   --- */

hook.Add( "Expadv.PostLoadConfig", "expadv.quota", function( )
	EXPADV.CreateSetting( "hookrate", 500 )
	EXPADV.CreateSetting( "tickquota", 250000 )
	EXPADV.CreateSetting( "softquota", 100000 )
	EXPADV.CreateSetting( "hardquota", 1000000 )
	EXPADV.CreateSetting( "memorylimit", 5 )
	EXPADV.CreateSetting( "net_max_bytes", 50000 )
end )

local function update( )
	expadv_luahook   = EXPADV.ReadSetting( "hookrate", 500 )
	expadv_tickquota = EXPADV.ReadSetting( "tickquota", 250000 )
	expadv_softquota = EXPADV.ReadSetting( "softquota", 100000 )
	expadv_hardquota = EXPADV.ReadSetting( "hardquota", 1000000 )
	expadv_memorylimit = EXPADV.ReadSetting( "memorylimit", 5 ) * 1024
	expadv_netlimit = EXPADV.ReadSetting( "net_max_bytes", 50000 )
end

update()

timer.Create( "expadv.quota", 1, 0, update )

/* --- --------------------------------------------------------------------------------
	@: Lets prevent net message spam :D
   --- */

function EXPADV.DoNetMessage(Context, func, ...)
	local Bytes = (Context.Data.net_bytes or 0) + net.BytesWritten()
	
	if Bytes <= expadv_netlimit then
		Context.Data.net_bytes = Bytes
		return true, func(...)
	end

	return false
end

hook.Add("Expadv.UpdateContext", "expadv.netlimit",
	function(Context)
		Context.Data.net_bytes = nil
	end)

/* --- --------------------------------------------------------------------------------
	@: Editor Animation.
   --- */

if SERVER then
	concommand.Add( "expadv_editor_open", function( Player )
		if !IsValid( Player ) or !Player:IsPlayer( ) then return end
		Player:SetNWBool( "expadv_editor_open", true )
	end )

	concommand.Add( "expadv_editor_close", function( Player )
		if !IsValid( Player ) or !Player:IsPlayer( ) then return end
		Player:SetNWBool( "expadv_editor_open", false )
	end )
end

if CLIENT then
		local RollDelta = 0
		local Emitter = ParticleEmitter( vector_origin )

		timer.Create( "expadv.editor.animate", 1, 0, function( )
			for _, Ply in pairs( player.GetAll( ) ) do
				if Ply:GetNWBool( "expadv_editor_open", false ) and Ply ~= LocalPlayer( ) then
					local BoneIndx = Ply:LookupBone("ValveBiped.Bip01_Head1") or Ply:LookupBone("ValveBiped.HC_Head_Bone") or 0
					local BonePos, BoneAng = Ply:GetBonePosition( BoneIndx )
					
					for I = 1, math.random( 0, 2 ) do
						local Particle = Emitter:Add("omicron/lemongear", BonePos + Vector(0, 0, 10) )
					
						if Particle then
							Particle:SetColor( 255, 255, 255 )
							Particle:SetVelocity( Vector( math.random(-8, 8), math.random(-8, 8), math.random(5, 15) ) )

							Particle:SetDieTime( 3 )
							Particle:SetLifeTime( 0 )

							Particle:SetStartSize( math.random(1, 3) )
							Particle:SetEndSize( math.random(2, 10) )

							Particle:SetStartAlpha( 255 )
							Particle:SetEndAlpha( 0 )

							Particle:SetRollDelta( RollDelta )
						end
					end
				end
			end
		end )
end

/* --- --------------------------------------------------------------------------------
	@: Updates.
   --- */

EXPADV.Ver = tonumber(file.Read("expadv/ver.lua", "LUA") or 0) or 0

if SERVER then CreateConVar( "expadv2_ver", EXPADV.Ver, FCVAR_NOTIFY ) end

function EXPADV.CheckForUpdates(ShowStatus)
	http.Fetch( "https://raw.githubusercontent.com/Rusketh/ExpAdv2/master/lua/expadv/ver.lua", function( Ver )
		EXPADV.GitVer = tonumber(Ver) or 0

		if !ShowStatus then return end

		Msg( "\nExpression Advanced 2" )
		Msg( "\n\tCurrent Ver: ", EXPADV.Ver )
		Msg( "\n\t Latest Ver: ", EXPADV.GitVer or "Unkown" )

		if EXPADV.GitVer == 0 then
			MsgN( "\n\tCould not check for updates.\n")
		elseif EXPADV.GitVer == 0 then
			MsgN( "\n\tCould not check for updates.\n")
		elseif EXPADV.GitVer == EXPADV.Ver then
			MsgN( "\n\tNo updates avalible.\n")
		elseif EXPADV.GitVer > EXPADV.Ver then
			MsgN( "\n\t", EXPADV.GitVer - EXPADV.Ver," updates avalible.\n")
		end
	end )
end

hook.Add( "Expadv.PostLoadCore", "expadv.updates", function( )
	EXPADV.CheckForUpdates( true )
end )

if CLIENT then
	concommand.Add( "expadv_ver", function( Player )
		EXPADV.CheckForUpdates( true )
	end )
end

/* --- --------------------------------------------------------------------------------
	@: API.
   --- */

if CLIENT then
	hook.Add( "GComputeLoaded", "expadv.GCompute", function( )
		--include( "expadv/api/gcompute.lua")
	end )
end

/* --- --------------------------------------------------------------------------------
	@: Load Core.
   --- */

if SERVER then
	hook.Add( "Initialize", "expadv.Loadcore", function( )
		EXPADV.LoadCore( )
	end )
end

MsgN( "Expression advanced Two - Installing complete." )