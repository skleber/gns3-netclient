# Copyright (C) 2026 Stephan Kleber. All Rights Reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# System-wide .bashrc for GNS3 Network Client
# Optimized for teaching, network labs, and terminal readability

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Ensure 256-color support
if [ "$TERM" = "dumb" ] || [ -z "$TERM" ]; then
    export TERM=xterm-256color
fi

# Enable color support for ls and other utilities
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# Handy aliases
alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ip='ip -color=auto'
alias ping='ping -c 4'
alias pingc='ping'
alias cls='clear'

# Enable programmable bash completion
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Color prompt: cyan hostname, blue path, white prompt character
if [ "$(id -u)" -eq 0 ]; then
    export PS1='\[\033[01;36m\]netclient\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '
else
    export PS1='\[\033[01;36m\]\u@netclient\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi
