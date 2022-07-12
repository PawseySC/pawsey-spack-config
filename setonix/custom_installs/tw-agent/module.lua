-- -*- lua -*-
-- Module file created by Pawsey
--

whatis([[Name : tw-agent]])
whatis([[Version : TOOL_VERSION]])

whatis([[Short description : Tower Agent allows Nextflow Tower to launch pipelines on HPC clusters that do not allow direct access through an SSH client. ]])
help([[Tower Agent allows Nextflow Tower to launch pipelines on HPC clusters that do not allow direct access through an SSH client.]])

setenv("PAWSEY_TW_AGENT_HOME","TOOL_INSTALL_DIR")

prepend_path("PATH","TOOL_INSTALL_DIR/bin")

-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
    if (myModuleUsrName() ~= myModuleFullName()) then
      LmodError(
          "Default module versions are disabled by your systems administrator.\n\n",
          "\tPlease load this module as <name>/<version>.\n"
      )
    end
end

