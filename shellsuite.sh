#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Usage Information
#/ Usage: shellsuite.sh [OPTION]
#/
#/ This is the main ShellSuite script.
#/
#/  -p --path
#/  -v --validator
#/  -f --flags
#/  -t --tag (optional)
#/
usage() {
    grep --color=never -Po '^#/\K.*' "${SCRIPTNAME}" || echo "Failed to display usage information."
    exit
}

# Command Line Arguments
readonly ARGS=("$@")

# Script Information
# https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself/246128#246128
get_scriptname() {
    # https://stackoverflow.com/questions/35006457/choosing-between-0-and-bash-source/35006505#35006505
    local SOURCE=${BASH_SOURCE[0]:-$0}
    while [[ -L ${SOURCE} ]]; do # resolve ${SOURCE} until the file is no longer a symlink
        local DIR
        DIR=$(cd -P "$(dirname "${SOURCE}")" > /dev/null 2>&1 && pwd)
        SOURCE=$(readlink "${SOURCE}")
        [[ ${SOURCE} != /* ]] && SOURCE="${DIR}/${SOURCE}" # if ${SOURCE} was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    echo "${SOURCE}"
}
readonly SCRIPTPATH=$(cd -P "$(dirname "$(get_scriptname)")" > /dev/null 2>&1 && pwd)
readonly SCRIPTNAME="${SCRIPTPATH}/$(basename "$(get_scriptname)")"

# User/Group Information
readonly DETECTED_PUID=${SUDO_UID:-$UID}
readonly DETECTED_UNAME=$(id -un "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_PGID=$(id -g "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_UGROUP=$(id -gn "${DETECTED_PUID}" 2> /dev/null || true)
readonly DETECTED_HOMEDIR=$(eval echo "~${DETECTED_UNAME}" 2> /dev/null || true)

# Terminal Colors
if [[ ${CI:-} == true ]] || [[ -t 1 ]]; then
    # Reference for colornumbers used by most terminals can be found here: https://jonasjacek.github.io/colors/
    # The actual color depends on the color scheme set by the current terminal-emulator
    # For capabilities, see terminfo(5)
    if [[ $(tput colors) -ge 8 ]]; then
        BLU=$(tput setaf 4)
        GRN=$(tput setaf 2)
        RED=$(tput setaf 1)
        YLW=$(tput setaf 3)
        NC=$(tput sgr0)
    fi
fi
readonly BLU=${BLU:-}
readonly GRN=${GRN:-}
readonly RED=${RED:-}
readonly YLW=${YLW:-}
readonly NC=${NC:-}

# Log Functions
readonly LOG_FILE="/tmp/shellsuite.log"
sudo chown "${DETECTED_PUID:-$DETECTED_UNAME}":"${DETECTED_PGID:-$DETECTED_UGROUP}" "${LOG_FILE}" > /dev/null 2>&1 || true
info() { echo -e "${NC}$(date +"%F %T") ${BLU}[INFO]${NC}       $*${NC}" | tee -a "${LOG_FILE}" >&2; }
warning() { echo -e "${NC}$(date +"%F %T") ${YLW}[WARNING]${NC}    $*${NC}" | tee -a "${LOG_FILE}" >&2; }
error() { echo -e "${NC}$(date +"%F %T") ${RED}[ERROR]${NC}      $*${NC}" | tee -a "${LOG_FILE}" >&2; }
fatal() {
    echo -e "${NC}$(date +"%F %T") ${RED}[FATAL]${NC}      $*${NC}" | tee -a "${LOG_FILE}" >&2
    exit 1
}

# Command Line Function
cmdline() {
    # http://www.kfirlavi.com/blog/2012/11/14/defensive-bash-programming/
    # http://kirk.webfinish.com/2009/10/bash-shell-script-to-use-getopts-with-gnu-style-long-positional-parameters/
    local ARG=
    local LOCAL_ARGS
    for ARG; do
        local DELIM=""
        case "${ARG}" in
            #translate --gnu-long-options to -g (short options)
            --flags) LOCAL_ARGS="${LOCAL_ARGS:-}-f " ;;
            --path) LOCAL_ARGS="${LOCAL_ARGS:-}-p " ;;
            --tag) LOCAL_ARGS="${LOCAL_ARGS:-}-t " ;;
            --validator) LOCAL_ARGS="${LOCAL_ARGS:-}-v " ;;
            --debug) LOCAL_ARGS="${LOCAL_ARGS:-}-x " ;;
            #pass through anything else
            *)
                [[ ${ARG:0:1} == "-" ]] || DELIM='"'
                LOCAL_ARGS="${LOCAL_ARGS:-}${DELIM}${ARG}${DELIM} "
                ;;
        esac
    done

    #Reset the positional parameters to the short options
    eval set -- "${LOCAL_ARGS:-}"

    while getopts ":f:p:v:t:x" OPTION; do
        case ${OPTION} in
            f)
                if [[ ${OPTARG:0:1} != " " ]]; then
                    fatal "Flags must start with a space."
                fi
                readonly VALIDATIONFLAGS=${OPTARG[*]}
                ;;
            p)
                readonly VALIDATIONPATH=${OPTARG[*]}
                ;;
            t)
                readonly VALIDATIONTAG=${OPTARG[*]}
                ;;
            v)
                if [[ -z ${VALIDATIONPATH:-} ]]; then
                    fatal "Path must be defined first."
                fi
                readonly VALIDATOR=${OPTARG}
                case ${VALIDATOR} in
                    bashate)
                        readonly VALIDATIONCMD="docker run --rm -v ${VALIDATIONPATH}:${VALIDATIONPATH} textclean/bashate"
                        readonly VALIDATIONCHECK="--show"
                        ;;
                    shellcheck)
                        readonly VALIDATIONCMD="docker run --rm -v ${VALIDATIONPATH}:${VALIDATIONPATH} koalaman/shellcheck"
                        readonly VALIDATIONCHECK="--version"
                        ;;
                    shfmt)
                        readonly VALIDATIONCMD="docker run --rm -v ${VALIDATIONPATH}:${VALIDATIONPATH} mvdan/shfmt"
                        readonly VALIDATIONCHECK="--version"
                        ;;
                    *)
                        fatal "Invalid validator option."
                        ;;
                esac
                ;;
            x)
                readonly DEBUG='-x'
                set -x
                ;;
            :)
                case ${OPTARG} in
                    t)
                        readonly VALIDATIONTAG="latest"
                        ;;
                    *)
                        fatal "${OPTARG} requires an option."
                        ;;
                esac
                exit
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done
    return 0
}

# Main Function
main() {
    # Arch Check
    readonly ARCH=$(uname -m)
    if [[ ${ARCH} != "x86_64" ]]; then
        fatal "Unsupported architecture."
    fi

    # Set command line variables
    cmdline "${ARGS[@]:-}"

    # Confirm variables are set
    if [[ -z ${VALIDATIONPATH:-} ]]; then
        fatal "Path must be defined."
    fi
    if [[ -z ${VALIDATIONCMD:-} ]]; then
        fatal "Validator must be defined."
    fi
    if [[ -z ${VALIDATIONTAG:-} ]]; then
        readonly VALIDATIONTAG="latest"
    fi
    if [[ -z ${VALIDATIONFLAGS:-} ]]; then
        fatal "Flags must be defined."
    fi
    if [[ -z ${VALIDATIONCHECK:-} ]]; then
        fatal "Check must be defined."
    fi

    # Check that the validator is usable
    eval "${VALIDATIONCMD}:${VALIDATIONTAG} ${VALIDATIONCHECK}" || fatal "Failed to check ${VALIDATOR} version."

    # https://github.com/caarlos0/shell-ci-build
    info "Linting all executables and .*sh files with ${VALIDATIONCMD}:${VALIDATIONTAG} ${VALIDATIONFLAGS[*]} ..."
    while IFS= read -r line; do
        if head -n1 "${VALIDATIONPATH}/${line}" | grep -q -E -w "sh|bash|dash|ksh"; then
            eval "${VALIDATIONCMD}:${VALIDATIONTAG} ${VALIDATIONFLAGS[*]} ${VALIDATIONPATH}/${line}" || fatal "Linting ${line}"
            info "Linting ${line}"
        else
            warning "Skipping ${line}..."
        fi
    done < <(git -C "${VALIDATIONPATH}" ls-tree -r HEAD | grep -E '^1007|.*\..*sh$' | awk '{print $4}')
    info "${VALIDATOR} validation complete."
}
main
