# Tmux
export TMUX_CONF=~/.config/tmux/tmux.conf
if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
  tmux attach-session -t default || tmux new-session -s default
fi
