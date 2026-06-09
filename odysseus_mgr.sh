#!/bin/bash

# Exit on error
set -e

# Configuration
ODYSSEUS_DIR="$HOME/odysseus"
REPO_URL="https://github.com/pewdiepie-archdaemon/odysseus.git"
CONFIG_DIR="$HOME/.config"
CONFIG_FILE="$CONFIG_DIR/odysseus-launcher.conf"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# --- Helper Functions ---

save_config() {
    echo "HOST=$1" > "$CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        HOST="127.0.0.1"
    fi
}

check_prereqs() {
    echo "Checking prerequisites..."
    if ! command -v git >/dev/null 2>&1; then
        echo "ERROR: git is not installed."
        exit 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 is not installed."
        exit 1
    fi
    if ! command -v tmux >/dev/null 2>&1; then
        echo "WARNING: tmux is not installed. Cookbook background downloads may not function."
    fi

    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    echo "Python version: $PYTHON_VERSION"
}

update_odysseus() {
    echo "Performing update/installation sequence..."

    if [ ! -d "$ODYSSEUS_DIR" ]; then
        echo "Odysseus not found. Cloning repository..."
        git clone "$REPO_URL" "$ODYSSEUS_DIR"
    else
        echo "Existing installation found. Checking for updates..."
        cd "$ODYSSEUS_DIR"
        if [ ! -d ".git" ]; then
            echo "ERROR: $ODYSSEUS_DIR exists but is not a git repository."
            exit 1
        fi
        git fetch origin
        git pull --ff-only
    fi

    cd "$ODYSSEUS_DIR"

    # Virtual Environment repair/creation
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv venv
    fi

    source venv/bin/activate

    echo "Updating pip and dependencies..."
    python -m pip install --upgrade pip
    pip install -r requirements.txt

    echo "Running setup.py..."
    python setup.py

    echo "Update complete."
}

select_network_mode() {
    load_config
    local current_host=$HOST

    echo
    echo "Network Mode Selection:"
    echo "1) Local Only (127.0.0.1)"
    echo "2) LAN Access (0.0.0.0)"
    echo

    local label="1"
    [ "$current_host" = "0.0.0.0" ] && label="2"

    read -rp "Selection [$label]: " MODE
    MODE=${MODE:-$label}

    case "$MODE" in
        2) HOST="0.0.0.0" ;;
        *) HOST="127.0.0.1" ;;
    esac

    save_config "$HOST"
    echo "Using host: $HOST"
}

launch_odysseus() {
    select_network_mode

    if [ ! -d "$ODYSSEUS_DIR" ]; then
        echo "ERROR: Odysseus is not installed. Please use the Update/Install option first."
        exit 1
    fi

    cd "$ODYSSEUS_DIR"

    if [ ! -d "venv" ]; then
        echo "ERROR: Virtual environment missing. Please run Update first."
        exit 1
    fi

    source venv/bin/activate

    # Determine URL
    if [ "$HOST" = "127.0.0.1" ]; then
        URL="http://127.0.0.1:7000"
    else
        LAN_IP=$(hostname -I | awk '{print $1}')
        URL="http://$LAN_IP:7000"
    fi

    echo
    echo "Starting Odysseus..."
    echo "URL: $URL"
    echo

    # Launch uvicorn in background
    python -m uvicorn app:app --host "$HOST" --port 7000 &
    SERVER_PID=$!

    sleep 5

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$URL" >/dev/null 2>&1 &
    fi

    echo "Odysseus is running. Press Ctrl+C to stop."
    wait $SERVER_PID
}

# --- Main Menu Loop ---

while true; do
    clear
    echo "========================================="
    echo "        Odysseus Manager"
    echo "========================================="
    echo
    echo "1) Install / Update and Launch"
    echo "2) Launch Only (Fast)"
    echo "3) Update Only"
    echo "4) Exit"
    echo

    read -rp "Selection [2]: " ACTION
    ACTION=${ACTION:-2}

    case "$ACTION" in
        1)
            check_prereqs
            update_odysseus
            launch_odysseus
            ;;
        2)
            launch_odysseus
            ;;
        3)
            check_prereqs
            update_odysseus
            echo "Update finished. Returning to menu..."
            sleep 2
            ;;
        4)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid selection."
            sleep 1
            ;;
    esac
done
