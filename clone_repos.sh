#!/bin/bash
set -exo pipefail

REPOS_HOST="pkgs.devel.redhat.com"
REPOS="
containers/3scale-operator
containers/3scale-toolbox
containers/3scale-apicast-operator
containers/3scale-apicast-operator-dev-operator-metadata
containers/3scale-apicast-operator-stage-operator-metadata
containers/3scale-apicast-operator-prod-operator-metadata
"

extract_ssh_user_from_kerberos_user()
{
    local user="${1}"
    # Why we need this:
    # Traditionally, a principal is divided into three parts: the primary,
    # the instance, and the realm.
    # The format of a typical Kerberos V5 principal is primary/instance@REALM.
    # https://web.mit.edu/kerberos/krb5-1.5/krb5-1.5.4/doc/krb5-user/What-is-a-Kerberos-Principal_003f.html
    # Below, we are just keeping the primary, which in our case, matches the
    # ssh username.
    sed -e 's/\/.*$//' <<< "${user}"
}

ssh_cfg_insert_entry_for()
{
    local host="${1}"
    local user="${2}"
    local file="${3}"

    cat >> "${file}" <<SSH
Host ${host}
  User ${user}
SSH
    chmod 0600 "${file}"
}

ssh_cfg_has_entry_for()
{
    local host="${1}"
    local file="${2}"

    grep -qP "^\s*Host\s+${host}\b\s*$" "${file}" 2> /dev/null
}

ssh_cfg_add_user()
{
    local ssh_user="${1}"
    local config_file="${2}"

    mkdir -p ~/.ssh

    if test -e "${config_file}"; then
        if ! test -f "${config_file}" || ! test -w "${config_file}"; then
            echo >&2 "Can't write to ${config_file} for SSH configuration"
            return 1
        fi
    fi

    if ! ssh_cfg_has_entry_for "${REPOS_HOST}" "${config_file}"; then
        ssh_cfg_insert_entry_for "${REPOS_HOST}" "${ssh_user}" "${config_file}"
    fi
}

clone_pkg_repo()
{
    local user="${1}"
    local repo="${2}"

    git clone --recurse-submodules "${REPOS_HOST}:${repo}.git" || (echo >&2 "Failed to clone ${repo}")
}

main()
{
    local user="${1}"

    if test "x${user}" = "x"; then
        echo >&2 "Please specify your Red Hat username"
        return 1
    fi

    local ssh_cfg_file_path="${SSH_CONFIG_FILE:-${HOME}/.ssh/config}"
    local ssh_user="${SSH_USER:-$(extract_ssh_user_from_kerberos_user "${user}")}"

    test "x${ssh_user}" = "x" && {
        echo >&2 "Please specify your SSH username by setting SSH_USER=<user>"
        return 1
    }

    ssh_cfg_add_user "${ssh_user}" "${ssh_cfg_file_path}"

    echo -e "You will need to have your SSH key to clone the repo below.\n" \
      "Copy it over to $(dirname ${ssh_cfg_file_path})"

    for r in ${REPOS}; do
        echo "Cloning: ${r}"
        clone_pkg_repo "${ssh_user}" "${r}"
    done
}

main "$@"
