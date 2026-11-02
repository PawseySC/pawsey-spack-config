-- -*- lua -*-
-- Module file created by spack (https://github.com/spack/spack) on {{ timestamp }}
--
-- {{ spec.short_spec }}
--

{% block header %}
{% if short_description %}
whatis([[Name : {{ spec.name }}]])
whatis([[Short description : {{ short_description }}]])
whatis([[Version : {{ spec.version }}]])
whatis([[Compiler : {{ spec.compiler }}]])
whatis([[Flags : {{ spec.compiler_flags }}]])
whatis([[Target : {{ spec.target }}]])
whatis([[Build date : {{ spec.installation_time }}]])
whatis([[Spack configuration : {{ spec.variants }}]])
whatis([[Path : {{ spec.prefix }}]])
{% endif %}
{% if configure_options %}
whatis([[Configure options : {{ configure_options }}]])
{% endif %}

{% if long_description %}
help([[{{ long_description| textwrap(72)| join() }}]])
{% endif %}
{% endblock %}

{% block provides %}
{# Prepend the path I unlock as a provider of #}
{# services and set the families of services I provide #}
{% if has_modulepath_modifications %}
-- Services provided by the package
{% for name in provides %}
family("{{ name }}")
{% endfor %}

-- Loading this module unlocks the path below unconditionally
{% for path in unlocked_paths %}
prepend_path("MODULEPATH", "{{ path }}")
{% endfor %}

{# Try to see if missing providers have already #}
{# been loaded into the environment #}
{% if has_conditional_modifications %}
-- Try to load variables into path to see if providers are there
{% for name in missing %}
local {{ name }}_name = os.getenv("LMOD_{{ name|upper() }}_NAME")
local {{ name }}_version = os.getenv("LMOD_{{ name|upper() }}_VERSION")
{% endfor %}

-- Change MODULEPATH based on the result of the tests above
{% for condition, path in conditionally_unlocked_paths %}
if {{ condition }} then
  local t = pathJoin({{ path }})
  prepend_path("MODULEPATH", t)
end
{% endfor %}

-- Set variables to notify the provider of the new services
{% for name in provides %}
setenv("LMOD_{{ name|upper() }}_NAME", "{{ name_part }}")
setenv("LMOD_{{ name|upper() }}_VERSION", "{{ version_part }}")
{% endfor %}
{% endif %}
{% endif %}
{% endblock %}

{% block autoloads %}
{% for module in autoload %}
{% set module_name = module |replace("astro-applications/", "") |replace("bio-applications/", "") |replace("py-keras-applications/", "pawsey-temporary-string/") |replace("applications/", "") |replace("pawsey-temporary-string/", "py-keras-applications/") |replace("libraries/", "") |replace("programming-languages/", "") |replace("utilities/", "") |replace("visualisation/", "") |replace("python-packages/", "") |replace("benchmarking/", "") |replace("developer-tools/", "") |replace("dependencies/", "") |replace("project-apps/", "") |replace("user-apps/", "") %}
{% if verbose %}
LmodMessage("Autoloading {{ module_name }}")
{% endif %}
depends_on("{{ module_name }}")
{% endfor %}
{% endblock %}

{% block environment %}
{% for command_name, cmd in environment_modifications %}
{% if command_name == 'PrependPath' %}
prepend_path("{{ cmd.name }}", "{{ cmd.value }}", "{{ cmd.separator }}")
{% elif command_name == 'AppendPath' %}
append_path("{{ cmd.name }}", "{{ cmd.value }}", "{{ cmd.separator }}")
{% elif command_name == 'RemovePath' %}
remove_path("{{ cmd.name }}", "{{ cmd.value }}", "{{ cmd.separator }}")
{% elif command_name == 'SetEnv' %}
setenv("{{ cmd.name }}", "{{ cmd.value }}")
{% elif command_name == 'UnsetEnv' %}
unsetenv("{{ cmd.name }}")
{% endif %}
{% endfor %}
{% endblock %}
{% if spec.name in ['nextflow', 'openjdk', 'singularity', 'singularityce', 'r', 'python'] %}
local user_software = os.getenv("MYSOFTWARE")
{% endif %}
{% if spec.name == 'nextflow' %}setenv("NXF_HOME", user_software.."/.nextflow")
setenv("NXF_SINGULARITY_CACHEDIR", user_software.."/.nextflow_singularity")
{% endif %}
{% if spec.name == 'openjdk' %}setenv("GRADLE_USER_HOME", user_software.."/.gradle")
{% endif %}
{% if spec.name == 'singularity' or spec.name == 'singularityce' %}setenv("SINGULARITY_CACHEDIR", user_software.."/.singularity")
{% endif %}
{% if spec.name == 'r' %}setenv("R_LIBS_USER", user_software.."/ella/DATE_TAG/r/%v")
{% endif %}
{% if spec.name == 'python' %}local python_userbase = pathJoin(user_software, "ella/DATE_TAG/python")
setenv("PYTHONUSERBASE", python_userbase)
prepend_path("PATH", pathJoin(python_userbase, "bin"))
{% endif %}

{% block footer %}
-- Enforce explicit usage of versions by requiring full module name
if (mode() == "load") then
  if (myModuleUsrName() ~= myModuleFullName()) then
    LmodError(
        "Default module versions are disabled by your systems administrator.\n\n",
        "\tPlease load this module as <name>/<version>.\n"
    )
  end
end

-- Access is granted only to specific groups
if not isDir("{{ spec.prefix }}") then
    LmodError (
        "You don't have the necessary rights to run \"{{ spec.name }}\".\n\n",
        "\tPlease raise a help ticket if you need further information on how to get access to it.\n"
    )
end
{% endblock %}
