-- CMEYER: Fix for lmod exectuables being added to FPATH in the `/opt/cray/pe/lmod/lmod/init/bash` file assigned to BASH_ENV:
-- Read ticket GS-32798

return function(patch_dir)

   local new_bash_env = patch_dir .. "/pawsey_init_bash"

   local bash_env = os.getenv("BASH_ENV")
   if bash_env then
      pushenv("BASH_ENV", "")            -- For some reason, this first stacking is needed
      pushenv("BASH_ENV", bash_env)      -- Stacking entry value
      pushenv("BASH_ENV", new_bash_env)  -- The value to be used when module is loaded
   else
      pushenv("BASH_ENV", "")            -- For some reason, this first stacking is needed
      pushenv("BASH_ENV", "")            -- Stack entry value
      pushenv("BASH_ENV", new_bash_env)  -- The value to be used when module is loaded
   end
end