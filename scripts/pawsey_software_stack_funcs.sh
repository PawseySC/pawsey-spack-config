#!/bin/bash
# Functions used by the installation scripts.

function check_installation_environment() {
    # Checks environment variables and sets defaults if needed.
    if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
        SYSTEM="$PAWSEY_CLUSTER"
    fi

    if [ -z ${SYSTEM+x} ]; then
        echo "The 'SYSTEM' variable is not set. Please specify the system you want to
        build Spack for."
        exit 1
    fi

    if [ -z ${INSTALL_PREFIX+x} ]; then
        if [ -z ${BASE_INSTALL_DIR+x} ]; then
            echo "The 'INSTALL_PREFIX' variable and the 'BASE_INSTALL_PREFIX' is not set. 
            Please specify where you want to install the software stack."
            exit 1
        fi
        echo "The 'INSTALL_PREFIX' variable is not set. 
        Using 'BASE_INSTALL_DIR' as fallback with 'SYSTEM' and date tag appended."
        if [ -z ${DATE_TAG+x} ]; then
            DATE_TAG=$( date +%Y.%m )
        fi
        ARCH=$( uname -m )
        if [ "$ARCH" == "x86_64" ]; then
            HOST_ARCH_NAME=""
        elif [ "$ARCH" == "aarch64" ]; then
            HOST_ARCH_NAME="aarch64"
        else
            echo "The architecture '$ARCH' is not supported."
            exit 1
        fi
        export INSTALL_PREFIX="${BASE_INSTALL_DIR}/${SYSTEM}/${HOST_ARCH_NAME}/${DATE_TAG}"
    else
        if [ -z ${DATE_TAG+x} ]; then
            DATE_TAG=$( date +%Y.%m )
            echo "The 'DATE_TAG' variable is not set. Using current date tag '$DATE_TAG'."
        fi

        if [ "${INSTALL_PREFIX%/${DATE_TAG}}" = "${INSTALL_PREFIX}" ]; then
            export INSTALL_PREFIX="${INSTALL_PREFIX}/${DATE_TAG}"
        else
            export INSTALL_PREFIX
        fi
    fi
}

function prepare_system_utility_modules()
{
    # Setonix-Q needs its combined PrgEnv wrapper before Spack evaluates the
    # nvhpc compiler entry.
    if [ "${SYSTEM}" != "setonix-q" ]; then
        return
    fi

    if [ "$( uname -m )" != "aarch64" ]; then
        echo "The setonix-q software stack must be built on aarch64; detected '$( uname -m )'."
        exit 1
    fi

    if [ -z "${utility_module_list//[[:space:]]/}" ]; then
        return
    fi

    . "${PAWSEY_SPACK_CONFIG_REPO}/scripts/install_utility_modules.sh"

    if type module &> /dev/null; then
        module use "${INSTALL_PREFIX}/${utilities_modules_dir}"
    fi
}

function load_system_settings()
{
    if [ -n "${PAWSEY_CLUSTER}" ] && [ -z ${SYSTEM+x} ]; then
        SYSTEM="$PAWSEY_CLUSTER"
    fi

    if [ -z ${SYSTEM+x} ]; then
        echo "The 'SYSTEM' variable is not set. Please specify the system you want to
        build Spack for."
        exit 1
    fi

    local repo_candidate
    local source_file
    local source_candidates=("${BASH_SOURCE[@]}" "$0" "$PWD")

    for source_file in "${source_candidates[@]}"; do
        if [ -z "${source_file}" ] || [ "${source_file}" = "environment" ]; then
            continue
        fi

        if [ -d "${source_file}" ]; then
            repo_candidate="${source_file}"
        else
            repo_candidate=$( cd -- "$( dirname -- "${source_file}" )/.." &> /dev/null && pwd )
        fi

        if [ -f "${repo_candidate}/systems/${SYSTEM}/settings.sh" ]; then
            export PAWSEY_SPACK_CONFIG_REPO="${repo_candidate}"
            . "${PAWSEY_SPACK_CONFIG_REPO}/systems/${SYSTEM}/settings.sh"
            if [ -z "${NCPUS+x}" ] && [ -n "${NPROCS+x}" ]; then
                export NCPUS="${NPROCS}"
            fi
            return
        fi
    done

    echo "Could not find systems/${SYSTEM}/settings.sh."
    exit 1
}

function set_spack_config_repo()
{
    load_system_settings
    prepare_system_utility_modules
}

function set_compilation_sets_for_arch()
{
    # Set compilation sets based on architecture of the system on which the script is run.
    # This is used to determine which compilers and architectures to use when installing software.
    # Allows for launching of installation process on 
    local host_arch
    host_arch="$( uname -m )"

    if [ "${SYSTEM}" = "setonix-q" ] && [ "${host_arch}" != "aarch64" ]; then
        echo "The setonix-q software stack must be built on aarch64; detected '${host_arch}'."
        exit 1
    fi

    if [ "${host_arch}" == "x86_64" ]; then
        export mainarch="zen3"
        export archs=("zen2" "zen3")
        export maincompiler="gcc@${gcc_version}"
        export compilers=("gcc@${gcc_version}" "cce@${cce_version}" "aocc@${aocc_version}")
	export pythoncompilers=("gcc@${gcc_version}" "cce@${cce_version}")
    elif [ "${host_arch}" == "aarch64" ]; then
        export mainarch="neoverse_v2"
        export archs=("neoverse_v2")
        export maincompiler="gcc@${gcc_version}"
        export compilers=("gcc@${gcc_version}" "nvhpc@${nvidia_version}")
	export pythoncompilers=("gcc@${gcc_version}")
    else
        echo "The architecture '${host_arch}' is not supported."
        exit 1
    fi   
}

function set_modulepaths_for_arch()
{

    if [ "$( uname -m )" == "x86_64" ]; then
        module load cpe/25.03
        module load gcc-native/${gcc_version}
        module use ${INSTALL_PREFIX}/staff_modulefiles
        # we need the python module to be available in order to run spack
        module --ignore-cache load pawseyenv/${pawseyenv_version}
        # swap is needed for the pawsey_temp module to work
        #module swap PrgEnv-gnu PrgEnv-cray
        #module swap PrgEnv-cray PrgEnv-gnu
        module use $INSTALL_PREFIX/modules/${mainarch}/gcc/${gcc_version}/programming-languages
        module load spack/${spack_version}
    elif [ "$( uname -m )" == "aarch64" ]; then
        if [ "${SYSTEM}" != "setonix-q" ]; then
            echo "The aarch64 module path setup is only configured for SYSTEM=setonix-q."
            exit 1
        fi

        module use ${INSTALL_PREFIX}/staff_modulefiles
        # we need the python module to be available in order to run spack
        module --ignore-cache load pawseyenv/${pawseyenv_version}
        # CUDA-free base: the plain GNU programming environment keeps the CUDA
        # toolkit out of the base that every build inherits, so pure %gcc CPU
        # builds (e.g. openblas) do not pick up CUDA. nvhpc (GPU) builds
        # family-swap to the stock NVIDIA PE via the compiler entry; gcc+CUDA
        # packages get CUDA from the `cuda` external in packages.yaml.
        module load PrgEnv-gnu
        # Pin the GNU compiler; plain PrgEnv-gnu otherwise defaults to a newer
        # gcc-native (e.g. 14.2) than the gcc@${gcc_version} compiler entry.
        module load gcc-native/${gcc_version%%.*}
        # Target the Grace ARM CPU (the cluster default is craype-x86-milan).
        module load craype-arm-grace
        # The gcc Spack module tree (which holds the python module that `module
        # load spack` pulls in) is exposed via the pawseyenv + gcc-native
        # handshake (LMOD_CUSTOM_COMPILER_GNU_* prepended to MODULEPATH), so no
        # explicit `module use` of the programming-languages trees is needed.
        module load spack/${spack_version}
    else
        echo "The architecture '$( uname -m )' is not supported."
        exit 1
    fi
}

function spack_install_manifest_tool()
{
    echo "${PAWSEY_SPACK_CONFIG_REPO}/scripts/spack_install_manifest.py"
}

function initialize_spack_install_manifest()
{
    : "${INSTALLATION_METADATA_DIR:=${INSTALL_PREFIX}/installation_metadata}"
    : "${SPACK_INSTALL_MANIFEST:=${INSTALLATION_METADATA_DIR}/spack_install_manifest.json}"

    mkdir -p "${INSTALLATION_METADATA_DIR}"
    "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" init \
        --metadata-root "${INSTALLATION_METADATA_DIR}" \
        --system "${SYSTEM}" \
        --date-tag "${DATE_TAG}" \
        --install-prefix "${INSTALL_PREFIX}" \
        --spack-version "${spack_version}"
}

function ensure_spack_install_manifest_run()
{
    : "${INSTALLATION_METADATA_DIR:=${INSTALL_PREFIX}/installation_metadata}"
    : "${SPACK_INSTALL_MANIFEST:=${INSTALLATION_METADATA_DIR}/spack_install_manifest.json}"

    if [ ! -f "${INSTALLATION_METADATA_DIR}/receipts/deployment.json" ]; then
        initialize_spack_install_manifest
    fi
}

function reset_spack_install_receipt()
{
    local source_type=$1
    local source_name=$2

    ensure_spack_install_manifest_run || return 1
    "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" reset-receipt \
        --metadata-root "${INSTALLATION_METADATA_DIR}" \
        --source-type "${source_type}" \
        --source-name "${source_name}"
}

function seal_spack_install_receipt()
{
    local source_type=$1
    local source_name=$2

    ensure_spack_install_manifest_run || return 1
    "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" seal-receipt \
        --metadata-root "${INSTALLATION_METADATA_DIR}" \
        --source-type "${source_type}" \
        --source-name "${source_name}"
}

function load_spack_install_manifest_hashes()
{
    local manifest_path=$1
    local role=$2
    local destination_name=$3
    local hashes_file

    if [[ ! ${destination_name} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "Invalid destination array name '${destination_name}'."
        return 1
    fi
    hashes_file=$(mktemp "${INSTALLATION_METADATA_DIR}/.manifest-hashes.XXXXXX") || return 1
    if ! "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" hashes \
        --manifest "${manifest_path}" --role "${role}" > "${hashes_file}"; then
        rm -f "${hashes_file}"
        return 1
    fi
    if ! mapfile -t "${destination_name}" < "${hashes_file}"; then
        rm -f "${hashes_file}"
        return 1
    fi
    rm -f "${hashes_file}"
}

function install_and_record_spack_root()
{
    local source_type=$1
    local source_name=$2
    local requested_spec=$3
    local install_mode=${4:-root}
    local temporary_spec_file
    local root_hash
    local concrete_spec_file
    local quoted_spec_file
    local install_command

    ensure_spack_install_manifest_run || return 1
    temporary_spec_file=$(mktemp "${INSTALLATION_METADATA_DIR}/.concrete-spec.XXXXXX.json") || return 1

    if ! spack spec --json ${SPACK_SPEC_ARGS:-} "${requested_spec}" > "${temporary_spec_file}"; then
        echo "Concretization failed for ${requested_spec}."
        rm -f "${temporary_spec_file}"
        return 1
    fi

    if ! root_hash=$("${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" store-spec \
        --metadata-root "${INSTALLATION_METADATA_DIR}" \
        --spec-file "${temporary_spec_file}"); then
        echo "Could not preserve the concrete spec for ${requested_spec}."
        rm -f "${temporary_spec_file}"
        return 1
    fi
    rm -f "${temporary_spec_file}"
    root_hash=${root_hash#/}
    concrete_spec_file="${INSTALLATION_METADATA_DIR}/concrete_specs/${root_hash}.json"

    printf -v quoted_spec_file '%q' "${concrete_spec_file}"
    install_command="spack install ${SPACK_INSTALL_ARGS:-} -j${NCPUS}"
    if [ "${install_mode}" = "dependencies-only" ]; then
        install_command+=" --only dependencies"
    elif [ "${install_mode}" != "root" ]; then
        echo "Unsupported installation mode '${install_mode}' for ${requested_spec}."
        return 1
    fi
    install_command+=" -f ${quoted_spec_file}"

    if ! sg "${INSTALL_GROUP}" -c "${install_command}"; then
        echo "Installation failed for ${requested_spec} (${root_hash})."
        return 1
    fi

    if [ "${install_mode}" = "root" ] && \
       ! spack find --format '{hash}' "/${root_hash}" | awk 'NF' | grep -Fxq "${root_hash}"; then
        echo "Spack reported success, but root /${root_hash} is not installed."
        return 1
    fi

    "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" record \
        --metadata-root "${INSTALLATION_METADATA_DIR}" \
        --source-type "${source_type}" \
        --source-name "${source_name}" \
        --requested-spec "${requested_spec}" \
        --spec-file "${concrete_spec_file}" \
        --install-mode "${install_mode}"
}

function record_concretized_environment()
{
    local envpath=$1
    local env=$2
    local install_mode=${3:-root}
    local lock_file="${envpath}/spack.lock"
    local root_hash
    local requested_spec
    local stored_hash
    local temporary_spec_file
    local concrete_spec_file
    local lock_roots_file
    local recorded_roots=0

    lock_roots_file=$(mktemp) || return 1
    if ! "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" lock-roots \
        --lock-file "${lock_file}" > "${lock_roots_file}"; then
        rm -f "${lock_roots_file}"
        return 1
    fi

    while IFS=$'\t' read -r root_hash requested_spec; do
        [ -n "${root_hash}" ] || continue
        if ! temporary_spec_file=$(mktemp "${INSTALLATION_METADATA_DIR}/.concrete-spec.XXXXXX.json"); then
            rm -f "${lock_roots_file}"
            return 1
        fi
        if ! "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" export-lock-spec \
            --lock-file "${lock_file}" \
            --hash "${root_hash}" \
            --output "${temporary_spec_file}"; then
            rm -f "${temporary_spec_file}"
            rm -f "${lock_roots_file}"
            return 1
        fi
        if ! stored_hash=$("${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" store-spec \
            --metadata-root "${INSTALLATION_METADATA_DIR}" \
            --spec-file "${temporary_spec_file}"); then
            rm -f "${temporary_spec_file}"
            rm -f "${lock_roots_file}"
            return 1
        fi
        rm -f "${temporary_spec_file}"
        stored_hash=${stored_hash#/}
        if [ "${stored_hash}" != "${root_hash}" ]; then
            echo "Stored spec hash ${stored_hash} does not match lock root ${root_hash}."
            rm -f "${lock_roots_file}"
            return 1
        fi
        concrete_spec_file="${INSTALLATION_METADATA_DIR}/concrete_specs/${root_hash}.json"

        if [ "${install_mode}" = "root" ] && \
           ! spack find --format '{hash}' "/${root_hash}" | awk 'NF' | grep -Fxq "${root_hash}"; then
            echo "Environment root /${root_hash} is not installed."
            rm -f "${lock_roots_file}"
            return 1
        fi

        "${SPACK_PYTHON:-python3}" "$(spack_install_manifest_tool)" record \
            --metadata-root "${INSTALLATION_METADATA_DIR}" \
            --source-type environment \
            --source-name "${env}" \
            --requested-spec "${requested_spec}" \
            --spec-file "${concrete_spec_file}" \
            --install-mode "${install_mode}" || {
                rm -f "${lock_roots_file}"
                return 1
            }
        ((recorded_roots += 1))
    done < "${lock_roots_file}"
    rm -f "${lock_roots_file}"

    if ((recorded_roots == 0)); then
        echo "Environment ${env} contains no concrete lockfile roots to record."
        return 1
    fi
}

function build_environment() {
    # Build an environment given its directory and name.
    local envdir=$1
    local env=$2
    local testing_only=0
    local previous_dir=$PWD
    local install_mode=root
    local extracted_specs
    if [ ! -z ${3+x} ]; then
        testing_only=$3
    fi
    echo "Installing environment $env..."
    cd "${envdir}/${env}" || return 1
    if ! spack env activate "${envdir}/${env}"; then
        cd "${previous_dir}" || true
        return 1
    fi
    # standard practice is to concretize in environments, but this can result in lots of duplicates
    # thus only do if explicitly requested
    if [ ! -z ${SPACK_ENV_CONCRETIZE+x} ]; then
        echo "Using environment concretization for $env"
        if ! spack concretize -f ${SPACK_CONCRETIZE_ARGS}; then
            spack env deactivate || true
            cd "${previous_dir}" || true
            return 1
        fi
        if (( $testing_only != 0 )); then
            echo "Testing only - not installing for $env"
            spack env deactivate
            cd "${previous_dir}" || true
            return
        fi
        if [ "${env}" == "roms" ] || [ "${env}" == "wrf" ] ; then
            install_mode=dependencies-only
            sg "${INSTALL_GROUP}" -c "spack install ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS} --only dependencies" || {
                spack env deactivate || true
                cd "${previous_dir}" || true
                return 1
            }
        else
            sg "${INSTALL_GROUP}" -c "spack install ${SPACK_SPEC_ARGS} ${SPACK_INSTALL_ARGS} -j${NCPUS}" || {
                spack env deactivate || true
                cd "${previous_dir}" || true
                return 1
            }
        fi
        spack env deactivate
        record_concretized_environment "${envdir}/${env}" "${env}" "${install_mode}" || {
            cd "${previous_dir}" || true
            return 1
        }
    else
        # Instead of installing the environment concretization, which tends to
        # produce duplicates, extract each requested root and concretize it
        # once against the progressively populated installation store.
        echo "Using basic spec extraction and spec and install outside environment for $env"
        rm -f spack.specs.txt spack.specs.output.txt
        local str=" - "
        if ! extracted_specs=$(spack find -c -r); then
            spack env deactivate || true
            cd "${previous_dir}" || true
            return 1
        fi
        printf '%s\n' "${extracted_specs}" | \
            awk  "/^$str/{print}" | sed "s: - ::g" > spack.specs.txt
        spack env deactivate
        if [ ! -s spack.specs.txt ]; then
            echo "Environment ${env} contains no extracted root specs."
            cd "${previous_dir}" || true
            return 1
        fi
        if (( $testing_only != 0 )); then
            echo "Testing only - not installing for $env"
        fi
        echo "Number of specs to be processed for $env: $(wc -l spack.specs.txt)"
        while IFS= read -r p; do
            echo "Package $p ..."
            if (( $testing_only != 0 )); then
                spack spec ${SPACK_SPEC_ARGS} ${p} >> spack.specs.output.txt
            else
                if [ "${env}" == "roms" ] || [ "${env}" == "wrf" ] ; then
                    install_mode=dependencies-only
                else
                    install_mode=root
                fi
                install_and_record_spack_root environment "${env}" "${p}" "${install_mode}" || {
                    cd "${previous_dir}" || true
                    return 1
                }
            fi
        done < spack.specs.txt
    fi
    if ((testing_only == 0)); then
        seal_spack_install_receipt environment "${env}" || {
            cd "${previous_dir}" || true
            return 1
        }
    fi
    cd "${previous_dir}" || return 1
}


# export relevant functions
export -f check_installation_environment
export -f prepare_system_utility_modules
export -f load_system_settings
export -f set_spack_config_repo
export -f set_compilation_sets_for_arch
export -f set_modulepaths_for_arch
export -f spack_install_manifest_tool
export -f initialize_spack_install_manifest
export -f ensure_spack_install_manifest_run
export -f reset_spack_install_receipt
export -f seal_spack_install_receipt
export -f load_spack_install_manifest_hashes
export -f install_and_record_spack_root
export -f record_concretized_environment
export -f build_environment
