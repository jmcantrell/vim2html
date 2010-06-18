#!/usr/bin/env bash

# Filename:      vim2html.sh
# Description:   Convert source code to html using vim
# Maintainer:    Jeremy Cantrell <jmcantrell@gmail.com>
# Last Modified: Thu 2010-06-17 23:18:31 (-0400)

# Vim is really good at recognizing filetypes and highlighting the syntax in a
# myriad of colorschemes. Vim is also good at turning that highlighted code
# into HTML. The only missing piece was making this process parameter driven
# and scriptable. That's what this script is intended to solve.

# IMPORTS {{{1

source bashful-files
source bashful-input
source bashful-messages
source bashful-modes

# FUNCTIONS {{{1

colorscheme_list() #{{{2
{
    {
        find "$VIM_HOME/colors" -name "*.vim"
        find "$HOME/.vim/colors" -name "*.vim"
    } | xargs -i basename {} .vim | sort -u
}

# VARIABLES {{{1

SCRIPT_NAME=$(basename "$0" .sh)
SCRIPT_ARGS="INPUT [OUTPUT]"
SCRIPT_USAGE="Convert source code to html using vim."
SCRIPT_OPTS="
-f FILETYPE       Use FILETYPE as vim filetype.
-n                Output line numbers.
-t                Use tidy to cleanup HTML.
-c COLORSCHEME    Use COLORSCHEME as vim colorscheme.
-l                Use light background.
-L                List available vim colorschemes.
"

VIM_CMD="vim -n -u NONE"
VIM_HOME=/usr/share/vim/vimcurrent
COLORSCHEME=inkpot
BACKGROUND=dark

interactive ${INTERACTIVE:-0}
verbose     ${VERBOSE:-0}

# COMMAND-LINE OPTIONS {{{1

unset OPTIND
while getopts ":hifvqf:ntc:lL" option; do
    case $option in
        f) FILETYPE=$OPTARG ;;
        n) LINE_NUMBERS=1 ;;
        t) TIDY=1 ;;
        c) COLORSCHEME=$OPTARG ;;
        l) BACKGROUND=light ;;

        L) colorscheme_list; exit 0 ;;

        i) interactive 1 ;;
        f) interactive 0 ;;

        v) verbose 1 ;;
        q) verbose 0 ;;

        h) usage 0 ;;
        *) usage 1 ;;
    esac
done && shift $(($OPTIND - 1))

# ERROR CHECKING {{{1

if [[ ! -d $VIM_HOME ]]; then
    VIM_HOME=$(listdir /usr/share/vim -type d -name "vim*" | sort -r | head -n1)
fi

[[ $VIM_HOME ]] || die "Could not find Vim home directory."

INFILE=$1

if [[ ! $INFILE ]]; then
    die "Input file not provided."
fi

if [[ ! -f $INFILE ]]; then
    die "Input file does not exist or is not a regular file."
fi

OUTFILE=$2

if [[ ! $OUTFILE ]]; then
    OUTFILE=${INFILE##*/}.html
fi

if [[ -f $OUTFILE ]]; then
    question -c -p "Overwrite '$OUTFILE'?" || exit 1
fi

# BUILD CONVERSION SCRIPT {{{1

tempfile || exit 1

: >$TEMPFILE

cat >>$TEMPFILE<<-EOF
set nocompatible
syntax on
set t_Co=256
set expandtabs
set tabstop=4
set background=$BACKGROUND
let html_ignore_folding = 1
let html_use_css = 1
EOF

{
    [[ $FILETYPE ]]     && echo "set ft=$FILETYPE"
    [[ $LINE_NUMBERS ]] && echo "set nu"
    [[ $COLORSCHEME ]]  && echo "colorscheme $COLORSCHEME"
} >>$TEMPFILE

cat >>$TEMPFILE<<-EOF
runtime! syntax/2html.vim
w! $OUTFILE
q!
q!
EOF
#}}}

info -c "Converting file '$INFILE' to '$OUTFILE'..."
$VIM_CMD -S "$TEMPFILE" "$INFILE" >/dev/null 2>&1
sed -i "s%<title>.*</title>%<title>$(basename "$INFILE")</title>%" "$OUTFILE"

if [[ $TIDY ]]; then
    info -c "Cleaning HTML file '$OUTFILE'..."
    tidy --tidy-mark no -utf8 -f /dev/null -clean -asxhtml -o "$OUTFILE" "$OUTFILE"
fi
