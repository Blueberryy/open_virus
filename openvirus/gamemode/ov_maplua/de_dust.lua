-- Fix up de_dust for Virus gameplay


function OVMap_PostCleanupMap()

	for _, ent in pairs( ents.FindByClass( "prop_physics*" ) ) do
	
		ent:Remove()
	
    end

end
hook.Add( "PostCleanupMap", "OVMap_PostCleanupMap", OVMap_PostCleanupMap )
