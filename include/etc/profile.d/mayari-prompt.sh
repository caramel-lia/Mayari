# Mayari shell prompt + welcome banner (interactive shells only)
export PS1='\[\e[1;35m\][mayari]\[\e[0m\] \[\e[1;34m\]\u@\h\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '
if [ -n "$PS1" ] && [ -f /etc/mayari/motd ] && [ -z "$MAYARI_MOTD_SHOWN" ]; then
  export MAYARI_MOTD_SHOWN=1
  cat /etc/mayari/motd
fi
