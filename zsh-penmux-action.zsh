#!/usr/bin/env zsh
#
# Action command
#
_penmux_action() {
    if [[ "${#}" -lt 1 ]]; then
        { >&2 echo "No command given"; return 1 }
    fi

    local _cmd="${1}"
    shift 1

    case "${_cmd}" in
        create)
            _penmux_action_create ${@}
            ;;
        rename)
            _penmux_action_rename ${@}
            ;;
        *)
            { >&2 echo "Unknown command '${_cmd}' given"; return 1 }
            ;;
    esac
}

_penmux_action_create() {
    zparseopts -E -D -a tmux_flags \
        n=no_log -no_log=no_log \
        b=tmux_flags \
        d=tmux_flags \
        h=tmux_flags \
        v=tmux_flags \
        f=tmux_flags

    zparseopts -F -A args -M \
        session_name: s:=session_name -session:=session_name \
        task_name: t:=task_name -task:=task_name \
        task_id: i:=task_id -task_id:=task_id \
        action_name: a:=action_name -action:=action_name \
        || return 1

    (($+args[-action_name])) || { >&2 echo "Action '-a | --action' is required"; return 1 }
    _penmux_args_find_session ${(kv)args} || return 1
    _penmux_args_find_task ${(kv)args} || return 1

    _penmux_if_action_duplicate "${args[-session_name]}" "${args[-task_name]}" "${args[-action_name]}" && {
        >&2 echo "Action '${args[-action_name]}' already exists"
        return 1
    } 
    _pane="$(tmux split-window ${=tmux_flags} -t "${args[-task_id]}" -P -F "#D")"
    tmux select-pane -t "${_pane}" -T "${args[-action_name]}"

    if [[ "${no_log}" != "" ]]; then
        # TODO: rewrite
        _add_tmux_env_list "${SESSION_NAME}" PENMUX_LOG_ACTIONS "${_pane}"
    fi
}

_penmux_action_rename() {
    local ACTION_NAME="${1}"
    local SESSION_NAME="$(_get_session_name)"
    local PANE_ID="$(_get_action_id)"

    if [[ "${2}" != "" ]]; then
        PANE_ID="${2}"
        SESSION_NAME="$(_get_session_name_by_pid "${PANE_ID}")"
    fi

    if [[ "${SESSION_NAME}" == "" ]]; then
        { >&2 echo "Invalid pand id. Session not found"; return 1 }
    fi

    _penmux_if_session_valid "${SESSION_NAME}" || { >&2 echo "Invalid session '${SESSION_NAME}'"; return 1 }
    _penmux_if_action_duplicate_by_id "${PANE_ID}" "${ACTION_NAME}" && { >&2 echo "Action already exiting"; return 1 }
    tmux select-pane -t "${PANE_ID}" -T "${ACTION_NAME}"
}

#
# Helper functions
#
_penmux_if_action_duplicate() {
    local _session_name="${1}"
    local _task_name="${2}"
    local _action_name="${3}"

    local _pane="$(tmux list-panes -aF "#T" -f "#{==:#S#W#T,${_session_name}${_task_name}${_action_name}}")"

    if [[ "${_pane}" == "" ]]; then
        return 1
    fi
    return 0
}

_penmux_if_action_duplicate_by_id() {
    local _pane_id="${1}"
    local _action_name="${2}"

    local _swt="$(tmux list-panes -aF "#S #W" -f "#{==:#{pane_id},${_pane_id}}")"

    _penmux_if_action_duplicate ${=_swt} "${_action_name}"
}

_penmux_if_action_duplicate_by_task() {
    local _session_name="${1}"
    local _task_name="${2}"

    _penmux_if_action_duplicate ${=_swt}
}
