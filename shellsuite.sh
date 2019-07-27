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
                    echo "Flags must start with a space."
                    exit 1
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
                    echo "Path must be defined first."
                    exit 1
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
                        echo "Invalid validator option."
                        exit 1
                        ;;
                esac
                ;;
            x)
                readonly DEBUG=1
                set -x
                ;;
            :)
                case ${OPTARG} in
                    t)
                        readonly VALIDATIONTAG="latest"
                        ;;
                    *)
                        echo "${OPTARG} requires an option."
                        exit 1
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
    return
}
cmdline "${ARGS[@]:-}"
if [[ -n ${DEBUG:-} ]] && [[ -n ${VERBOSE:-} ]]; then
    readonly TRACE=1
fi

# Github Token for Travis CI
if [[ ${CI:-} == true ]] && [[ ${TRAVIS_SECURE_ENV_VARS:-} == true ]]; then
    readonly GH_HEADER="Authorization: token ${GH_TOKEN}"
    echo "${GH_HEADER}" > /dev/null 2>&1 || true # Ridiculous workaround for SC2034 where the variable is used in other files called by this script
fi

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
# readonly DETECTED_HOMEDIR=$(eval echo "~${DETECTED_UNAME}" 2> /dev/null || true)

# Terminal Colors
if [[ ${CI:-} == true ]] || [[ -t 1 ]]; then
    readonly SCRIPTTERM=true
fi
tcolor() {
    if [[ -n ${SCRIPTTERM:-} ]]; then
        # http://linuxcommand.org/lc3_adv_tput.php
        local BF=${1:-}
        local CAP
        case ${BF} in
            [Bb]) CAP=setab ;;
            [Ff]) CAP=setaf ;;
            [Nn][Cc]) CAP=sgr0 ;;
            *) return ;;
        esac
        local COLOR_IN=${2:-}
        local VAL
        if [[ ${CAP} != "sgr0" ]]; then
            case ${COLOR_IN} in
                [Bb4]) VAL=4 ;; # Blue
                [Cc6]) VAL=6 ;; # Cyan
                [Gg2]) VAL=2 ;; # Green
                [Kk0]) VAL=0 ;; # Black
                [Mm5]) VAL=5 ;; # Magenta
                [Rr1]) VAL=1 ;; # Red
                [Ww7]) VAL=7 ;; # White
                [Yy3]) VAL=3 ;; # Yellow
                *) return ;;
            esac
        fi
        local COLOR_OUT
        if [[ $(tput colors) -ge 8 ]]; then
            COLOR_OUT=$(eval tput ${CAP:-} ${VAL:-})
        fi
        echo "${COLOR_OUT:-}"
    else
        return
    fi
}
declare -Agr B=(
    [B]=$(tcolor B B)
    [C]=$(tcolor B C)
    [G]=$(tcolor B G)
    [K]=$(tcolor B K)
    [M]=$(tcolor B M)
    [R]=$(tcolor B R)
    [W]=$(tcolor B W)
    [Y]=$(tcolor B Y)
)
declare -Agr F=(
    [B]=$(tcolor F B)
    [C]=$(tcolor F C)
    [G]=$(tcolor F G)
    [K]=$(tcolor F K)
    [M]=$(tcolor F M)
    [R]=$(tcolor F R)
    [W]=$(tcolor F W)
    [Y]=$(tcolor F Y)
)
readonly NC=$(tcolor NC)

# Log Functions
readonly LOG_FILE="/tmp/dockstarter.log"
sudo chown "${DETECTED_PUID:-$DETECTED_UNAME}":"${DETECTED_PGID:-$DETECTED_UGROUP}" "${LOG_FILE}" > /dev/null 2>&1 || true
trace() { if [[ -n ${TRACE:-} ]]; then
    echo -e "${NC:-}$(date +"%F %T") ${F[B]:-}[TRACE ]${NC:-}   $*${NC:-}" | tee -a "${LOG_FILE}" >&2
fi; }
debug() { if [[ -n ${DEBUG:-} ]]; then
    echo -e "${NC:-}$(date +"%F %T") ${F[B]:-}[DEBUG ]${NC:-}   $*${NC:-}" | tee -a "${LOG_FILE}" >&2
fi; }
info() { if [[ -n ${VERBOSE:-} ]]; then
    echo -e "${NC:-}$(date +"%F %T") ${F[B]:-}[INFO  ]${NC:-}   $*${NC:-}" | tee -a "${LOG_FILE}" >&2
fi; }
notice() { echo -e "${NC:-}$(date +"%F %T") ${F[G]:-}[NOTICE]${NC:-}   $*${NC:-}" | tee -a "${LOG_FILE}" >&2; }
warn() { echo -e "${NC:-}$(date +"%F %T") ${F[Y]:-}[WARN  ]${NC:-}   $*${NC:-}" | tee -a "${LOG_FILE}" >&2; }
error() { echo -e "${NC:-}$(date +"%F %T") ${F[R]:-}[ERROR ]${NC:-}   $*${NC:-}" | tee -a "${LOG_FILE}" >&2; }
fatal() {
    echo -e "${NC:-}$(date +"%F %T") ${B[R]:-}${F[W]:-}[FATAL ]${NC:-}   $*${NC:-}" | tee -a "${LOG_FILE}" >&2
    exit 1
}

# Main Function
main() {
    # Arch Check
    readonly ARCH=$(uname -m)
    if [[ ${ARCH} != "x86_64" ]]; then
        fatal "Unsupported architecture."
    fi

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
    notice "Linting all executables and .*sh files with ${VALIDATIONCMD}:${VALIDATIONTAG} ${VALIDATIONFLAGS[*]} ..."
    while IFS= read -r line; do
        if head -n1 "${VALIDATIONPATH}/${line}" | grep -q -E -w "sh|bash|dash|ksh"; then
            eval "${VALIDATIONCMD}:${VALIDATIONTAG} ${VALIDATIONFLAGS[*]} ${VALIDATIONPATH}/${line}" || fatal "Linting ${line}"
            notice "Linting ${line}"
        else
            warn "Skipping ${line}..."
        fi
    done < <(git -C "${VALIDATIONPATH}" ls-tree -r HEAD | grep -E '^1007|.*\..*sh$' | awk '{print $4}')
    notice "${VALIDATOR} validation complete."
}
main
