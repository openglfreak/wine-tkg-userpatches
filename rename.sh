#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# description:
#   Replaces each sequence of unsafe characters in the input with a dash (-).
# input:
#   The input to process.
# outputs:
#   The sanitized output.
sanitize() {
    if [ 0 -lt "$#" ]; then
        printf 'sanitize: Too many arguments (%i > 0)\n' "$#" >&2
        return 1
    fi

    sed -e 's/[^-_0-9A-Za-z\.][^-_0-9A-Za-z\.]*/-/g'
}

# description:
#   Formats a number as a four-digit decimal string.
# params:
#   expr: string
#     The number to format, as an expression in the format `bc` expects.
# outputs:
#   The formatted string.
format_number() {
    if [ 1 -ne "$#" ]; then
        if [ 1 -gt "$#" ]; then
            printf 'format_number: Not enough arguments (%i < 1)\n' "$#" >&2
        elif [ 1 -lt "$#" ]; then
            printf 'format_number: Too many arguments (%i > 1)\n' "$#" >&2
        fi
        return 1
    fi

    set -- "$(printf '%s\n' "$1" | bc)" || return
    # shellcheck disable=SC2026
    if [ x''x != x"$1"x ]; then
        printf '%04i\n' "$1"
    fi
}

# description:
#   Asks the user a yes/no question.
# params:
#   question: string
#     The question to ask the user.
#   [default]: 0 or 1
#     The default choice, 1 (no) if not given.
# input:
#   User input.
# outputs:
#   The prompt.
# returns:
#   The user's choice, 0 for yes and 1 for no.
yn() (
    if [ 1 -gt "$#" ]; then
        printf 'yn: Not enough arguments (%i < 1)\n' "$#" >&2
        return 1
    elif [ 2 -lt "$#" ]; then
        printf 'yn: Too many arguments (%i > 2)\n' "$#" >&2
        return 1
    fi

    if [ 2 -eq "$#" ]; then
        case "$2" in
            0) set -- "$1" 0 '[Y/n]';;
            1) set -- "$1" 1 '[y/N]';;
            *)
                # shellcheck disable=SC2016
                printf 'yn: Malformed argument ($2: %s)\n' "$2" >&2
                return 2
        esac
    else
        set -- "$1" 1 '[y/N]'
    fi

    while :; do
        printf '%s %s ' "$1" "$3" || :
        IFS=' ' read -r answer || return 1
        case "${answer}" in
            *[![:space:]]*Y*|*[![:space:]]*y*|*Y*[![:space:]]*|*y*[![:space:]]*)
                :;;
            Y|y) return 0;;
            *[![:space:]]*N*|*[![:space:]]*n*|*N*[![:space:]]*|*n*[![:space:]]*)
                :;;
            N|n) return 1;;
            *[![:space:]]*) :;;
            *)
                # shellcheck disable=SC2015,SC2026
                [ x''x != x"$2"x ] && return "$2" || :
        esac
        printf 'Please answer with y, n, or no input\n'
    done
)

_get_subject() {
    sed -n -e '/^Subject: /,/^\([^ ]\|$\)/p' -- ${1+"$1"} | \
    sed -n -e '1s/^Subject: //;1,/^\([^ ]\|$\)/p' | \
    head -n -1 | \
    sed -e ':s N;s/\n */ /;b s'
}

_get_patch_number() {
    printf '%s\n' "$1" | sed -n -e 's/^.*\([0-9][0-9]*\)\/[0-9][0-9]*.*$/\1/p'
}

_sanitize_commit_msg() {
    sed -e 's/\.$//' | sanitize
}

main() (
    for patch in ps[0-9][0-9][0-9][0-9]-*; do
        case "${patch}" in ps999[0-9]-*)
            continue
        esac

        if [ 1 -ne "$(grep -c '^Subject: ' -- "${patch}")" ]; then
            printf 'Error: Patch contains multiple Subjects: %s\n' "${patch}" >&2
            continue
        fi

        patchset_number="${patch#ps[0-9][0-9][0-9][0-9]}"
        patchset_number="${patch%$patchset_number}"
        patchset_number="${patchset_number#ps}"

        file_extension="${patch##*.}"

        subject="$(_get_subject "$patch")"
        case "${subject}" in
            '[PATCH'*|'[RFC PATCH'*)
                subject_patch="${subject%%\] *}]"
                subject_commit_msg="${subject#*\] }";;
            *)
                subject_patch=
                subject_commit_msg="${subject}"
        esac

        patch_number="$(_get_patch_number "${subject_patch}")"
        sanitized_commit_msg="$(printf '%s\n' "${subject_commit_msg}" \
            | _sanitize_commit_msg)"

        filename="ps$(format_number "${patchset_number}")"
        formatted_patch_number="$(format_number "${patch_number}")"
        # shellcheck disable=SC2026
        if [ x''x != x"${formatted_patch_number}"x ]; then
            filename="${filename}-p${formatted_patch_number}"
        fi
        filename="${filename}-${sanitized_commit_msg}"
        filename="$(printf '%s\n' "${filename}" | cut -c-72)"
        filename="${filename}.${file_extension}"

        if [ x"${patch}"x != x"${filename}"x ]; then
            if yn "Rename ${patch} to ${filename}?"; then
                printf 'Renaming %s\n' "${patch}"
                mv -- "${patch}" "${filename}"
            else
                printf 'Skipping %s\n' "${patch}"
            fi
        fi
    done
)

main
