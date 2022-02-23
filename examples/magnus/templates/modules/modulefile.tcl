#%Module1.0
## Module file created by spack (https://github.com/spack/spack) on {{ timestamp }}
##
## {{ spec.short_spec }}
##
{% if configure_options %}
## Configure options: {{ configure_options }}
##
{% endif %}


{% block header %}

{% if short_description %}
module-whatis "{{ Name : spec.name }}"
module-whatis "{{ Short description : short_description }}"
module-whatis "Version : {{ spec.version }}"
module-whatis "Compiler : {{ spec.compiler }}"
module-whatis "Flags : {{ spec.compiler_flags }}"
module-whatis "Target : {{ spec.target }}"
module-whatis "Build date : {{ spec.installation_time }}"
module-whatis "Spack configuration : {{ spec.variants }}"
module-whatis "Path : {{ spec.prefix }}"
{% endif %}

{% if configure_options %}
module-whatis "Configure options : {{ configure_options }}"
{% endif %}

{% if long_description %}
proc ModulesHelp { } {
{{ long_description| textwrap(72)| quote()| prepend_to_line('puts stderr ')| join() }}
}
{% endif %}

{% endblock %}

{% block autoloads %}
{% for module in autoload %}
if {{ '{' }} [ module-info mode load ] && ![ is-loaded {{ module }} ] {{ '}' }} {{ '{' }}
{% if verbose %}
    puts stderr "Autoloading {{ module }}"
{% endif %}
    module load {{ module }}
{{ '}' }}
{% endfor %}
{ }

##question is if tcl whether python updates paths and user base 
##{% if spec.name == 'python' %} 
##setenv("PYTHONUSERBASE", os.getenv("MYSOFTWARE").."/python")
##prepend_path("PATH", os.getenv("PYTHONUSERBASE").."/bin")
##{% endif %}
{% endblock %}


{#  #}

{% block prerequisite %}
{% for module in prerequisites %}
prereq {{ module }}
{% endfor %}
{% endblock %}
{#  #}
{% block conflict %}
{% for name in conflicts %}
conflict {{ name }}
{% endfor %}
{% endblock %}

{% block environment %}
{% for command_name, cmd in environment_modifications %}
{% if cmd.separator != ':' %}
{# A non-standard separator is required #}
{% if command_name == 'PrependPath' %}
prepend-path --delim "{{ cmd.separator }}" {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'AppendPath' %}
append-path --delim "{{ cmd.separator }}" {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'RemovePath' %}
remove-path --delim "{{ cmd.separator }}" {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'SetEnv' %}
setenv --delim "{{ cmd.separator }}" {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'UnsetEnv' %}
unsetenv {{ cmd.name }}
{% endif %}
{% else %}
{# We are using the usual separator #}
{% if command_name == 'PrependPath' %}
prepend-path {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'AppendPath' %}
append-path {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'RemovePath' %}
remove-path {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'SetEnv' %}
setenv {{ cmd.name }} "{{ cmd.value }}"
{% elif command_name == 'UnsetEnv' %}
unsetenv {{ cmd.name }}
{% endif %}
{#  #}
{% endif %}
{% endfor %}
{% endblock %}

{% block footer %}
{# In case the module needs to be extended with custom TCL code #}
{% endblock %}
