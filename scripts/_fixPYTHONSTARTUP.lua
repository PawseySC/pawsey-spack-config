-- AEG: Temporary fix for problem reported in ticket GS-31936
--        After extensive testing, it was found that the three levels of pushenv stacking are needed
--        When unloading the module, the top level of the pushenv stack will be restored to host environment

-- io.stderr:write("[DEBUG] Entry PYTHONSTARTUP value: ", tostring(os.getenv("PYTHONSTARTUP")), "\n")
-- io.stderr:write("[DEBUG] Entry __LMOD_STACK_PYTHONSTARTUP value: ", tostring(os.getenv("__LMOD_STACK_PYTHONSTARTUP")), "\n")
local py_startup = os.getenv("PYTHONSTARTUP")
if py_startup then
   pushenv("PYTHONSTARTUP", "")          -- For some reason, this first stacking is needed
   pushenv("PYTHONSTARTUP", py_startup)  -- Stacking entry value
   pushenv("PYTHONSTARTUP", "whatever1") -- Dummy stacking (will be lost when unset)
   -- io.stderr:write("[DEBUG] Stacking1 value: ", tostring(os.getenv("PYTHONSTARTUP")), "\n")
else
   pushenv("PYTHONSTARTUP", "")          -- For some reason, this first stacking is needed
   pushenv("PYTHONSTARTUP", "")          -- Stack entry value
   pushenv("PYTHONSTARTUP", "whatever2") -- Dummy stacking (will be lost when unset)
   -- io.stderr:write("[DEBUG] Stacking2 value: ", tostring(os.getenv("PYTHONSTARTUP")), "\n")
end
unsetenv("PYTHONSTARTUP") -- Unset when module is active, and also puts the entry value top of stack for restore
-- io.stderr:write("[DEBUG] Entry PYTHONSTARTUP value: ", tostring(os.getenv("PYTHONSTARTUP")), "\n")
-- io.stderr:write("[DEBUG] Entry __LMOD_STACK_PYTHONSTARTUP value: ", tostring(os.getenv("__LMOD_STACK_PYTHONSTARTUP")), "\n")