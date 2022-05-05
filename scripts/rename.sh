#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e 2>/dev/null ||:
set +C 2>/dev/null ||:
set +f 2>/dev/null ||:
set -u 2>/dev/null ||:

# zsh: Force word splitting.
setopt SH_WORD_SPLIT 2>/dev/null ||:
# zsh: Don't exit when a glob doesn't match.
unsetopt NOMATCH 2>/dev/null ||:
# zsh: Don't treat ! specially.
unsetopt BANG_HIST 2>/dev/null ||:

# description:
#   Replaces each sequence of unsafe characters in the input with a dash (-),
#   and removes trailing dashes and dots. This is the same algorithm that Git
#   uses to format commit messages in patch file names.
# input:
#   The input to process.
# outputs:
#   The sanitized output.
# shellcheck disable=SC2120
sanitize() {
    if [ 0 -lt "$#" ]; then
        printf 'sanitize: Too many arguments (%d > 0)\n' "$#" >&2
        return 1
    fi

    sed -e 's/[^.0-9A-Z_a-z][^.0-9A-Z_a-z]*/-/g;$s/[-.][-.]*$//'
}

# description:
#   Formats an integer as a four-digit decimal string.
# params:
#   number: integer
#     The number to format.
# outputs:
#   The formatted string.
format_number() {
    if [ 1 -ne "$#" ]; then
        if [ 1 -gt "$#" ]; then
            printf 'format_number: Not enough arguments (%d < 1)\n' "$#" >&2
        elif [ 1 -lt "$#" ]; then
            printf 'format_number: Too many arguments (%d > 1)\n' "$#" >&2
        fi
        return 1
    fi

    if [ x = "x$1" ]; then
        printf 'format_number: Invalid argument value: "%s"\n' "$1" >&2
        return 2
    fi

    printf '%04d\n' "$1"
}

# description:
#   Removes leading zeroes from a string.
# params:
#   input: string
#     The input to remove leading zeroes from.
# outputs:
#   The processed string.
remove_leading_zeroes() {
    if [ 1 -ne "$#" ]; then
        if [ 1 -gt "$#" ]; then
            printf 'remove_leading_zeroes: Not enough arguments (%d < 1)\n' "$#" >&2
        elif [ 1 -lt "$#" ]; then
            printf 'remove_leading_zeroes: Too many arguments (%d > 1)\n' "$#" >&2
        fi
        return 1
    fi

    printf '%s\n' "${1#"${1%?"${1#*[!0]}"}"}"
}

# description:
#   Formats a file name for a commit the same way git does.
# params:
#   [prefix]: string
#     A prefix for the file name.
#   [number]: integer
#     The patch number.
#   [subject]: string
#     The patch subject.
#   [postfix]: string
#     The file extension to use, including the dot.
# outputs:
#   The resulting file name.
make_patch_file_name() {
    if [ 4 -lt "$#" ]; then
        printf 'make_patch_file_name: Too many arguments (%d > 4)\n' "$#" >&2
        return 1
    fi

    if [ x != "x$2" ]; then
        set -- "$1" "$(format_number "$2" 2>/dev/null)-" "$3" "$4"
        if [ 'x-' = "x$2" ]; then
            return 1
        fi
    fi

    if [ x != "x$3" ]; then
        set -- "$1" "$2" "$(printf '%s\n' "$3" | sanitize)" "$4"
        if [ x = "x$3" ]; then
            return 1
        fi
    fi

    printf "%s%s%.$((64-${#1}-${#2}-${#4}-1))s%s\n" "$1" "$2" "$3" "$4"
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
        printf 'yn: Not enough arguments (%d < 1)\n' "$#" >&2
        return 1
    elif [ 2 -lt "$#" ]; then
        printf 'yn: Too many arguments (%d > 2)\n' "$#" >&2
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
        printf '%s %s ' "$1" "$3" >/dev/tty || :
        IFS=' ' read -r answer </dev/tty || return 1
        case "${answer}" in
            *[![:space:]]*Y*|*[![:space:]]*y*|*Y*[![:space:]]*|*y*[![:space:]]*)
                :;;
            Y|y) return 0;;
            *[![:space:]]*N*|*[![:space:]]*n*|*N*[![:space:]]*|*n*[![:space:]]*)
                :;;
            N|n) return 1;;
            *[![:space:]]*) :;;
            *)
                if [ x != "x$2" ]; then
                    return "$2"
                fi
        esac
        printf 'Please answer with y, n, or no input\n' >/dev/tty
    done
)

_print_help() {
    cat <<EOF
Usage: ${0##*/} [option]...

Options:
  -y, --yes     Answer yes to all questions
  -n, --no      Answer no to all questions
  -d, --dry-run Perform a dry run, no files will be renamed
  -h, --help    Display this help text and exit
EOF
}

_get_subject() {
    sed -n -e '/^Subject: /,/^\([^ ]\|$\)/p' -- ${1+"$1"} | \
    sed -n -e '1s/^Subject: //;1,/^\([^ ]\|$\)/p' | \
    head -n -1 | \
    sed -e ':s N;s/\n */ /;b s'
}

_get_patch_number() {
    printf '%s\n' "$1" | \
    sed -n -e 's/^.*[^0-9]\([0-9][0-9]*\)\/[0-9][0-9]*.*$/\1/p'
}

_tty_filename() {
    ls -Fdpq1 "$1"
}

main() (
    answer=
    dry_run=false
    for arg; do
        case "${arg}" in
            -h|--help) _print_help; return 0;;
            -y|--yes) answer=y;;
            -n|--no) answer=n;;
            -d|--dry-run) dry_run=true;;
            *)
                printf 'Error: Unknown parameter: %s\n' "${arg}" >&2
                return 1
        esac
    done

    for patch in [0-9][0-9][0-9][0-9]-* ps[0-9][0-9][0-9][0-9]-*; do
        [ -e "${patch}" ] || continue
        [ -d "${patch}" ] && continue
        case "${patch}" in ps999[0-9]-*|999[0-9]-*)
            continue
        esac

        subject_count="$(grep -c '^Subject: ' -- "${patch}")" ||:
        if [ 1 -ne "${subject_count}" ]; then
            if [ 1 -lt "${subject_count}" ]; then
                printf 'Error: Patch contains multiple Subjects: %s\n' "$(_tty_filename "${patch}")" >&2
            else
                printf 'Error: Patch contains no Subjects: %s\n' "$(_tty_filename "${patch}")" >&2
            fi
            continue
        fi

        patchset_number=
        case "${patch}" in ps[0-9][0-9][0-9][0-9]-*)
            patchset_number="${patch#ps[0-9][0-9][0-9][0-9]}"
            patchset_number="${patch%"$patchset_number"}"
            patchset_number="${patchset_number#ps}"
        esac

        file_extension="${patch##*.}"

        subject="$(_get_subject "$patch")"
        patch_number=
        case "${subject}" in
            \[*)
                subject_patch="${subject%%\] *}]"
                subject_commit_msg="${subject#*\] }"
                patch_number="$(_get_patch_number "${subject_patch}")"
                unset subject_patch;;
            *)
                subject_commit_msg="${subject}"
        esac

        prefix=
        if [ x != "x${patchset_number}" ]; then
            patchset_number="$(remove_leading_zeroes "${patchset_number}")"
            patchset_number="${patchset_number:-0}"
            patchset_number="$(format_number "${patchset_number}" 2>/dev/null)"
            prefix="ps${patchset_number}-${patch_number:+p}"
        fi
        if [ x != "x${patch_number}" ]; then
            patch_number="$(remove_leading_zeroes "${patch_number}")"
            patch_number="${patch_number:-0}"
        fi
        filename="$(make_patch_file_name "${prefix}" "${patch_number}" \
            "${subject_commit_msg}" "${file_extension+.${file_extension}}")"

        if [ "x${patch}" = "x${filename}" ]; then
            continue
        fi

        if [ xn != "x${answer}" ] && {
            [ xy = "x${answer}" ] || yn "Rename $(_tty_filename "${patch}") to ${filename}?"
        }; then
            printf 'Renaming %s to %s\n' "$(_tty_filename "${patch}")" "${filename}"
            [ xfalse != "x${dry_run}" ] || mv -- "${patch}" "${filename}"
        else
            printf 'Skipping %s\n' "$(_tty_filename "${patch}")"
        fi
    done
)

main ${1+"$@"}
