#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
SESSION_NAME="my-workspace"
WORK_DIR="$HOME/Projects/my-project" 

# ==============================================================================
# HELPER: SESSION CONFIGURATION
# ==============================================================================
configure_session() {
    local sess=$1

    # 1. ENABLE MOUSE SUPPORT
    # This allows you to scroll up/down with the wheel.
    # To copy text: HOLD SHIFT + SELECT with mouse.
    tmux set-option -t "$sess" mouse on

    # 2. USE VI KEYS
    # Allows navigating search results or history with h/j/k/l
    tmux set-option -t "$sess" mode-keys vi
    
    # 3. POWERLINE / STATUS BAR SETUP
    # Checks standard locations for Powerline
    POWERLINE_LOC=""
    if [ -f "/usr/share/powerline/bindings/tmux/powerline.conf" ]; then
        POWERLINE_LOC="/usr/share/powerline/bindings/tmux/powerline.conf"
    elif [ -f "$HOME/.local/lib/python3.*/site-packages/powerline/bindings/tmux/powerline.conf" ]; then
        POWERLINE_LOC=$(ls $HOME/.local/lib/python3.*/site-packages/powerline/bindings/tmux/powerline.conf | head -n 1)
    fi

    if [ -n "$POWERLINE_LOC" ]; then
        tmux source-file "$POWERLINE_LOC"
    else
        # FALLBACK THEME (If Powerline isn't installed)
        tmux set-option -t "$sess" status-bg "colour235"
        tmux set-option -t "$sess" status-fg "colour255"
        tmux set-option -t "$sess" status-left-length 100
        tmux set-option -t "$sess" status-right-length 100
        tmux set-option -t "$sess" status-left "#[bg=colour25,fg=colour255,bold] #S #[bg=colour235,fg=colour25,nobold]"
        tmux set-option -t "$sess" status-right "#[fg=colour240]#[bg=colour240,fg=colour255] %Y-%m-%d  %H:%M #[bg=colour240,fg=colour25]#[bg=colour25,fg=colour255,bold] #h "
        tmux set-option -t "$sess" window-status-current-format "#[fg=colour235,bg=colour33]#[fg=colour255,bg=colour33,bold] #I: #W #[fg=colour33,bg=colour235,nobold]"
        tmux set-option -t "$sess" window-status-format "#[fg=colour244,bg=colour235] #I: #W "
    fi
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

# Check if session exists
tmux has-session -t "$SESSION_NAME" 2>/dev/null

if [ $? != 0 ]; then
    echo "Creating new session: $SESSION_NAME"
    
    # Create Detached Session
    tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR" -n "Editor"

    # Apply Config
    configure_session "$SESSION_NAME"

    # --- WINDOW 1: EDITOR ---
    tmux send-keys -t "$SESSION_NAME:Editor" "vim" C-m

    # --- WINDOW 2: SERVER ---
    tmux new-window -t "$SESSION_NAME" -c "$WORK_DIR" -n "Server"
    tmux split-window -v -t "$SESSION_NAME:Server" -c "$WORK_DIR"
    tmux send-keys -t "$SESSION_NAME:Server.0" "echo 'Server Log Pane'" C-m
    tmux send-keys -t "$SESSION_NAME:Server.1" "htop" C-m

    # --- WINDOW 3: TERMINAL ---
    tmux new-window -t "$SESSION_NAME" -c "$WORK_DIR" -n "Shell"
    tmux send-keys -t "$SESSION_NAME:Shell" "git status" C-m

    # Select Editor window by default
    tmux select-window -t "$SESSION_NAME:Editor"
fi

# Attach to session
if [ -n "$TMUX" ]; then
    tmux switch-client -t "$SESSION_NAME"
else
    tmux attach-session -t "$SESSION_NAME"
fi
