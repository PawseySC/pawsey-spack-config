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
{% if verbose %}
LmodMessage("Autoloading {{ module |replace("astro-applications/", "") |replace("bio-applications/", "") |replace("py-keras-applications/", "pawsey-temporary-string/") |replace("applications/", "") |replace("pawsey-temporary-string/", "py-keras-applications/") |replace("libraries/", "") |replace("programming-languages/", "") |replace("utilities/", "") |replace("visualisation/", "") |replace("python-packages/", "") |replace("benchmarking/", "") |replace("developer-tools/", "") |replace("dependencies/", "") |replace("project-apps/", "") |replace("user-apps/", "") }}")
{% endif %}
load("{{ module |replace("astro-applications/", "") |replace("bio-applications/", "") |replace("py-keras-applications/", "pawsey-temporary-string/") |replace("applications/", "") |replace("pawsey-temporary-string/", "py-keras-applications/") |replace("libraries/", "") |replace("programming-languages/", "") |replace("utilities/", "") |replace("visualisation/", "") |replace("python-packages/", "") |replace("benchmarking/", "") |replace("developer-tools/", "") |replace("dependencies/", "") |replace("project-apps/", "") |replace("user-apps/", "") }}")
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
{% if spec.name == 'nextflow' %}setenv("NXF_HOME", os.getenv("MYSOFTWARE").."/.nextflow")
setenv("NXF_SINGULARITY_CACHEDIR", os.getenv("MYSOFTWARE").."/.nextflow_singularity")
{% endif %}
{% if spec.name == 'openjdk' %}setenv("GRADLE_USER_HOME", os.getenv("MYSOFTWARE").."/.gradle")
{% endif %}
{% if spec.name == 'singularity' %}setenv("SINGULARITY_CACHEDIR", os.getenv("MYSOFTWARE").."/.singularity")
-- Singularity configuration START
-- LD_LIBRARY_PATH addition 
-- add CRAY PATHS START
local singularity_ld_path = "/opt/cray/pe/mpich/default/ofi/gnu/9.1/lib-abi-mpich:/opt/cray/pe/mpich/default/gtl/lib:/opt/cray/xpmem/default/lib64:/opt/cray/pe/pmi/default/lib:/opt/cray/pe/pals/default/lib"
singularity_ld_path = singularity_ld_path .. ":/opt/cray/pe/gcc-libs:
-- add CRAY PATHS END
-- add MPI START
-- for Cassini nics and SS>=11
-- add libfabric, might need version changes
singularity_ld_path = singularity_ld_path .. ":/opt/cray/libfabric/1.15.2.0/lib64/"
-- add MPI END
-- add CURRENT HOST LD PATH START
singularity_ld_path = singularity_ld_path .. ":$LD_LIBRARY_PATH"
-- add CURRENT HOST LD PATH END
setenv("SINGULARITYENV_LD_LIBRARY_PATH", singularity_ld_path)

-- BIND_PATH addition
-- add LOCAL FILESYSTEM START 
local singularity_bindpath = "/askapbuffer,/scratch,/software"
-- add LOCAL FILESYSTEM END
-- add CRAY PATHS START
singularity_bindpath = singularity_bindpath .. ",/var/opt/cray/pe,/etc/opt/cray/pe,/opt/cray,/etc/alternatives/cray-dvs,/etc/alternatives/cray-xpmem"
-- commented out below, adding lib64. Could be useful
-- singularity_bindpath = singularity_bindpath .. ",/lib64/libc.so.6,/lib64/libpthread.so.0,/lib64/librt.so.1,/lib64/libdl.so.2,/lib64/libz.so.1,/lib64/libselinux.so.1,/lib64/libm.so.6"
-- add CRAY PATHS END
-- add MPI START 
-- for Cassini nics and SS>=11
-- added several different libraries to ensure that mpi works
singularity_bindpath = singularity_bindpath .. ",/usr/lib64/libcxi.so.1,/usr/lib64/libcurl.so.4,/usr/lib64/libjson-c.so.3"
singularity_bindpath = singularity_bindpath .. ",/usr/lib64/libnghttp2.so.14,/usr/lib64/libidn2.so.0,/usr/lib64/libssh.so.4,/usr/lib64/libpsl.so.5,/usr/lib64/libssl.so.1.1,/usr/lib64/libcrypto.so.1.1,/usr/lib64/libgssapi_krb5.so.2,/usr/lib64/libldap_r-2.4.so.2,/usr/lib64/liblber-2.4.so.2,/usr/lib64/libunistring.so.2,/usr/lib64/libkrb5.so.3,/usr/lib64/libk5crypto.so.3,/lib64/libcom_err.so.2,/usr/lib64/libkrb5support.so.0,/lib64/libresolv.so.2,/usr/lib64/libsasl2.so.3,/usr/lib64/libkeyutils.so.1,/usr/lib64/libpcre.so.1"
singularity_bindpath = singularity_bindpath .. ",/usr/lib64/libmunge.so.2"
-- this has to be conditional, path exists only in compute nodes
if isDir("/var/spool/slurmd") then
  singularity_bindpath = singularity_bindpath .. ",/var/spool/slurmd"
  singularity_bindpath = singularity_bindpath .. ",/var/run/munge"
end
-- add MPI END 
setenv("SINGULARITY_BINDPATH",singularity_bindpath)

-- LD_PRELOAD addition 
-- add MPI START
-- preload xpmem for fast mpi communication
local singularity_ld_preload = "/opt/cray/xpmem/default/lib64/libxpmem.so.0"
-- singularity_ld_preload = singularity_ld_preload .. ":/lib64/libc.so.6:/lib64/libpthread.so.0:/lib64/librt.so.1:/lib64/libdl.so.2:/lib64/libz.so.1:/lib64/libselinux.so.1:/lib64/libm.so.6"
-- for Cassini nics and SS>=11
singularity_ld_preload = singularity_ld_preload .. ":/usr/lib64/libcxi.so.1:/usr/lib64/libcurl.so.4:/usr/lib64/libjson-c.so.3"
singularity_ld_preload = singularity_ld_preload .. ":/usr/lib64/libnghttp2.so.14:/usr/lib64/libidn2.so.0:/usr/lib64/libssh.so.4:/usr/lib64/libpsl.so.5:/usr/lib64/libssl.so.1.1:/usr/lib64/libcrypto.so.1.1:/usr/lib64/libgssapi_krb5.so.2:/usr/lib64/libldap_r-2.4.so.2:/usr/lib64/liblber-2.4.so.2:/usr/lib64/libunistring.so.2:/usr/lib64/libkrb5.so.3:/usr/lib64/libk5crypto.so.3:/lib64/libcom_err.so.2:/usr/lib64/libkrb5support.so.0:/lib64/libresolv.so.2:/usr/lib64/libsasl2.so.3:/usr/lib64/libkeyutils.so.1:/usr/lib64/libpcre.so.1"
singularity_ld_preload = singularity_ld_preload .. ":/usr/lib64/libmunge.so.2"
-- add MPI END
prepend_path("SINGULARITYENV_LD_PRELOAD", singularity_ld_preload)
{% endif %}
{% if spec.name == 'r' %}setenv("R_LIBS_USER", os.getenv("MYSOFTWARE").."/joey/r/%v")
{% endif %}
{% if spec.name == 'python' %}setenv("PYTHONUSERBASE", os.getenv("MYSOFTWARE").."/joey/python")
prepend_path("PATH", os.getenv("PYTHONUSERBASE").."/bin")
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
