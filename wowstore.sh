#!/bin/bash

# ==============================================================================
# WOW APP STORE - A Beautiful TUI for Ubuntu App Management
# ==============================================================================

# --- VERSION & UPDATE CONFIG ---
VERSION="2.1"
# Using raw.githubusercontent to get the actual code, assuming 'main' branch
UPDATE_URL="https://raw.githubusercontent.com/deadibone/wowstore/main/wowstore.sh"

# --- COLORS & STYLING ---
# Use $'' syntax to ensure escape codes are interpreted correctly by printf
R=$'\033[0;31m'
G=$'\033[0;32m'
Y=$'\033[1;33m'
B=$'\033[0;34m'
M=$'\033[0;35m'
C=$'\033[0;36m'
W=$'\033[1;37m'
BOLD=$'\033[1m'
BG_BLUE=$'\033[44m'
BG_MAG=$'\033[45m'
RESET=$'\033[0m'

# --- DATA STORAGE (V2) ---
DATA_DIR="$HOME/.local/share/wowstore"
INSTALLED_DB="$DATA_DIR/installed.db"
mkdir -p "$DATA_DIR"
touch "$INSTALLED_DB"

# --- ARGUMENT PARSING ---
FORCE_UPDATE=false

if [[ "$1" == "-u" ]]; then
    FORCE_UPDATE=true
elif [[ "$1" == "-r" ]]; then
    echo -e "${M}Uninstalling wowstore from system...${RESET}"
    if [ -f "/usr/local/bin/wowstore" ]; then
        sudo rm /usr/local/bin/wowstore
        echo -e "${G}Successfully removed /usr/local/bin/wowstore${RESET}"
    else
        echo -e "${Y}wowstore is not installed in /usr/local/bin${RESET}"
    fi
    exit 0
fi

# --- SYSTEM CHECKS & SELF-MANAGEMENT ---

check_dependencies() {
    command -v curl >/dev/null 2>&1 || { echo "Installing curl..."; sudo apt update && sudo apt install -y curl; }
    command -v wget >/dev/null 2>&1 || { echo "Installing wget..."; sudo apt update && sudo apt install -y wget; }
    command -v snap >/dev/null 2>&1 || { echo "Snap not found. Some apps may not install."; }
    command -v flatpak >/dev/null 2>&1 || { echo "Flatpak not found. Installing..."; sudo apt install -y flatpak; flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; }
}

self_update() {
    if wget -q --spider --timeout=2 http://github.com; then
        local temp_script=$(mktemp)
        wget -q -O "$temp_script" "${UPDATE_URL}?t=$(date +%s)"
        if [ -s "$temp_script" ]; then
            local remote_ver=$(grep -m1 '^VERSION=' "$temp_script" | cut -d'"' -f2 | tr -d '\r')
            if [ "$FORCE_UPDATE" = true ]; then
                 echo -e "${C}Checking for updates... (Local: $VERSION, Remote: $remote_ver)${RESET}"
            fi
            if [[ -n "$remote_ver" ]] && ( [ "$FORCE_UPDATE" = true ] || dpkg --compare-versions "$remote_ver" gt "$VERSION" ); then
                echo -e "${M}Update triggered (Remote: $remote_ver). Updating self...${RESET}"
                if [ -w "$0" ]; then cp "$temp_script" "$0"; else sudo cp "$temp_script" "$0"; fi
                chmod +x "$0"
                rm "$temp_script"
                echo -e "${G}Update complete! Restarting...${RESET}"
                if [ "$FORCE_UPDATE" = true ]; then exec "$0"; else exec "$0" "$@"; fi
            elif [ "$FORCE_UPDATE" = true ]; then
                echo -e "${G}You are already on the latest version ($VERSION).${RESET}"
                rm "$temp_script"
                exit 0
            fi
            rm "$temp_script"
        fi
    fi
}

install_to_path() {
    if [[ "$(basename "$0")" == "wowstore" && -f "/usr/local/bin/wowstore" ]]; then return; fi
    if ! command -v wowstore >/dev/null 2>&1; then
        echo -e "${C}------------------------------------------------------------${RESET}"
        echo -e "${Y}Would you like to install this as the command 'wowstore'?${RESET}"
        echo -e "This allows you to run it from anywhere in the terminal."
        echo -n -e "${BOLD}(y/n) > ${RESET}"
        read -r -n 1 response
        echo 
        if [[ "$response" =~ ^[yY]$ ]]; then
            echo -e "${M}Installing to /usr/local/bin/wowstore...${RESET}"
            sudo cp "$(realpath "$0")" /usr/local/bin/wowstore
            sudo chmod +x /usr/local/bin/wowstore
            echo -e "${G}Success! You can now type 'wowstore' to launch.${RESET}"
            sleep 1.5
        fi
    fi
}

# --- CONFIGURATION ---
APPS_PER_PAGE=10

# --- APP CATALOGUE (MODULAR) ---
# Format: "Name|Description|Type|PackageID|Repo/Command/URL"
# Type options: apt, snap, flatpak, apt-ppa, apt-universe, apt-key, deb-repo, direct-deb

declare -a APP_DB
APP_DB=(
    "Chromium|Open Source Web Browser|apt|chromium-browser|"
    "Brave Browser|Secure, fast & private web browser|apt-key|brave-browser|sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && echo 'deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main' | sudo tee /etc/apt/sources.list.d/brave-browser-release.list"
    "Firefox|Standard Web Browser|apt|firefox|"
    "LibreWolf|Privacy-focused Firefox fork|flatpak|io.gitlab.librewolf-community|"
    "Tor Browser|Anonymity Online|flatpak|com.github.micahflee.torbrowser-launcher|"
    "Minecraft|Official Launcher|direct-deb|minecraft-launcher|https://launcher.mojang.com/download/Minecraft.deb"
    "Minetest|Open Source Voxel Game|apt-ppa|minetest|ppa:minetestdevs/stable"
    "Sober (Roblox)|Roblox Client (Vinegar)|flatpak|org.vinegarhq.Sober|"
    "Heroic Launcher|Epic Games & GOG Launcher|flatpak|com.heroicgameslauncher.hgl|"
    "Lutris|Gaming Platform (Latest)|apt-ppa|lutris|ppa:lutris-team/lutris"
    "Steam|Digital distribution platform|apt-universe|steam-installer|"
    "RetroArch|All-in-one Emulator|flatpak|org.libretro.RetroArch|"
    "PPSSPP|PSP Emulator|flatpak|org.ppsspp.PPSSPP|"
    "Dolphin Emulator|GameCube / Wii Emulator|flatpak|org.DolphinEmu.dolphin-emu|"
    "VS Code|Code editing. Redefined.|apt-key|code|wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && sudo sh -c 'echo \"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" > /etc/apt/sources.list.d/vscode.list' && rm -f packages.microsoft.gpg"
    "Sublime Text|Sophisticated text editor|snap|sublime-text|--classic"
    "PyCharm Community|Python IDE|snap|pycharm-community|--classic"
    "IntelliJ IDEA Com.|Java/Kotlin IDE|snap|intellij-idea-community|--classic"
    "Android Studio|Android Development IDE|flatpak|com.google.AndroidStudio|"
    "Unity Hub|Unity Game Engine|flatpak|com.unity.UnityHub|"
    "Godot 4|Game Engine|flatpak|org.godotengine.Godot|"
    "Postman|API platform for building and using APIs|snap|postman|"
    "Docker|Containerization platform|apt|docker.io|"
    "Git|Distributed version control system|apt-ppa|git|ppa:git-core/ppa"
    "Node.js (LTS)|JavaScript runtime|snap|node|--channel=lts/stable --classic"
    "Python 3|Interpreted high-level programming language|apt|python3|"
    "DB Browser for SQLite|Database visualizer|apt-ppa|sqlitebrowser|ppa:linuxgndu/sqlitebrowser"
    "Extension Manager|Browse/Install GNOME Extensions|flatpak|com.mattjakeman.ExtensionManager|"
    "GNOME Shell Ext.|Standard GNOME Extensions|apt|gnome-shell-extensions|"
    "GNOME Connector|Browser integration for extensions|apt|gnome-browser-connector|"
    "Gnome Tweaks|Customize GNOME desktop|apt|gnome-tweaks|"
    "Flatseal|Manage Flatpak Permissions|flatpak|com.github.tchx84.Flatseal|"
    "Amberol|Music Player|flatpak|io.bassi.Amberol|"
    "Bottles|Run Windows Software|flatpak|com.usebottles.bottles|"
    "Boxes|Virtualization made simple|flatpak|org.gnome.Boxes|"
    "Kooha|Simple screen recorder|flatpak|io.github.seadve.Kooha|"
    "Loupe|Fast image viewer|flatpak|org.gnome.Loupe|"
    "Pika Backup|Simple backups|flatpak|org.gnome.World.PikaBackup|"
    "Impression|Create bootable drives|flatpak|io.gitlab.adhami3310.Impression|"
    "Shortwave|Internet radio|flatpak|de.haeckerfelix.Shortwave|"
    "Tangram|Web apps browser|flatpak|re.sonny.Tangram|"
    "Text Editor|Simple text editor|flatpak|org.gnome.TextEditor|"
    "Weather|Show weather conditions|flatpak|org.gnome.Weather|"
    "Discord|All-in-one voice and text chat|snap|discord|"
    "Telegram|Messaging with a focus on speed|snap|telegram-desktop|"
    "Signal|Encrypted instant messaging|flatpak|org.signal.Signal|"
    "Slack|Collaboration hub|snap|slack|"
    "Zoom|Video conferencing|flatpak|us.zoom.Zoom|"
    "Element|Matrix Client|flatpak|im.riot.Riot|"
    "Teams for Linux|Unofficial Microsoft Teams|flatpak|com.github.IsmaelMartinez.teams_for_linux|"
    "Thunderbird|Email Client|apt|thunderbird|"
    "LibreOffice|Office Suite (Latest)|apt-ppa|libreoffice|ppa:libreoffice/ppa"
    "OnlyOffice|Office Suite|flatpak|org.onlyoffice.desktopeditors|"
    "Obsidian|Knowledge Base|flatpak|md.obsidian.Obsidian|"
    "Logseq|Privacy-first knowledge base|flatpak|com.logseq.Logseq|"
    "Joplin|Note taking app|flatpak|net.cozic.joplin_desktop|"
    "LocalSend|AirDrop Alternative (LAN Share)|flatpak|org.localsend.LocalSend_App|"
    "Proton VPN|High-speed secure VPN|deb-repo|proton-vpn-gnome-desktop|https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb"
    "VLC Media Player|The best open source media player|apt|vlc|"
    "MPV|Minimalist media player|apt|mpv|"
    "Spotify|Music for everyone|snap|spotify|"
    "GIMP|GNU Image Manipulation Program|flatpak|org.gimp.GIMP|"
    "Krita|Digital Painting|flatpak|org.kde.krita|"
    "Inkscape|Vector graphics editor (Latest)|apt-ppa|inkscape|ppa:inkscape.dev/stable"
    "Blender|3D creation suite|snap|blender|"
    "OBS Studio|Open Broadcaster Software|apt-ppa|obs-studio|ppa:obsproject/obs-studio"
    "Kdenlive|Video Editor|flatpak|org.kde.kdenlive|"
    "Audacity|Audio editor and recorder|flatpak|org.audacityteam.Audacity|"
    "HandBrake|Video Transcoder|flatpak|fr.handbrake.ghb|"
    "Darktable|Photography workflow|flatpak|org.darktable.Darktable|"
    "Clementine|Modern music player|apt|clementine|"
    "Stremio|Video streaming|flatpak|com.stremio.Stremio|"
    "Htop|Interactive process viewer|apt|htop|"
    "Neofetch|System information tool|apt|neofetch|"
    "GParted|Partition editor|apt|gparted|"
    "Stacer|System Optimizer|apt-ppa|stacer|ppa:oguzhaninan/stacer"
    "BleachBit|System Cleaner|apt|bleachbit|"
    "Timeshift|System Restore|apt|timeshift|"
    "VirtualBox|Oracle VM VirtualBox|apt|virtualbox|"
    "FileZilla|FTP client|apt|filezilla|"
    "qBittorrent|BitTorrent client|apt-ppa|qbittorrent|ppa:qbittorrent-team/qbittorrent-stable"
    "Transmission|BitTorrent client|apt|transmission|"
)

# --- SORTING APP DB ---
IFS=$'\n' APP_DB=($(sort -f -t'|' -k1 <<<"${APP_DB[*]}"))
unset IFS

# --- GLOBAL VARIABLES & STATE ---
CURRENT_PAGE=1
SEARCH_TERM=""
FILTERED_INDICES=()
VIEW_MODE="BROWSE" # "BROWSE" or "LIBRARY"

# --- LIBRARY FUNCTIONS (V2) ---
declare -A INSTALLED_MAP
declare -a INSTALLED_LIST

load_installed() {
    INSTALLED_LIST=()
    INSTALLED_MAP=()
    if [[ -f "$INSTALLED_DB" ]]; then
        while IFS='|' read -r name type pkg; do
            if [[ -n "$name" ]]; then
                # Clean up carriage returns/spaces just in case
                name=$(echo "$name" | xargs)
                INSTALLED_LIST+=("$name|$type|$pkg")
                INSTALLED_MAP["$name"]=1
            fi
        done < "$INSTALLED_DB"
    fi
}

track_install() {
    local name="$1"
    local type="$2"
    local pkg="$3"
    # Remove existing to update info
    if [[ -f "$INSTALLED_DB" ]]; then
        grep -v "^$name|" "$INSTALLED_DB" > "${INSTALLED_DB}.tmp" 2>/dev/null 
        mv "${INSTALLED_DB}.tmp" "$INSTALLED_DB"
    fi
    echo "$name|$type|$pkg" >> "$INSTALLED_DB"
    load_installed
}

track_remove() {
    local name="$1"
    if [[ -f "$INSTALLED_DB" ]]; then
        # Use grep -v to filter out the line. 
        # Do NOT link with && mv, because if grep -v produces empty output (empty db), exit code is 1
        grep -v "^$name|" "$INSTALLED_DB" > "${INSTALLED_DB}.tmp" 2>/dev/null
        mv "${INSTALLED_DB}.tmp" "$INSTALLED_DB"
    fi
    load_installed
}

# --- INITIALIZATION ---
load_installed
init_filter() {
    FILTERED_INDICES=()
    if [[ "$VIEW_MODE" == "BROWSE" ]]; then
        local i=0
        for app in "${APP_DB[@]}"; do
            if [[ -z "$SEARCH_TERM" ]]; then
                FILTERED_INDICES+=($i)
            else
                local name=$(echo "$app" | cut -d'|' -f1)
                local desc=$(echo "$app" | cut -d'|' -f2)
                if echo "$name $desc" | grep -iq "$SEARCH_TERM"; then
                    FILTERED_INDICES+=($i)
                fi
            fi
            ((i++))
        done
    else
        # Library Mode
        local i=0
        for app in "${INSTALLED_LIST[@]}"; do
            if [[ -z "$SEARCH_TERM" ]]; then
                FILTERED_INDICES+=($i)
            else
                local name=$(echo "$app" | cut -d'|' -f1)
                if echo "$name" | grep -iq "$SEARCH_TERM"; then
                    FILTERED_INDICES+=($i)
                fi
            fi
            ((i++))
        done
    fi
}

# --- GUI FUNCTIONS ---

draw_header() {
    clear
    echo -e "${BG_MAG}${W}${BOLD}  WOW APP STORE  ${RESET} ${C}v${VERSION}${RESET}"
    if [[ "$VIEW_MODE" == "BROWSE" ]]; then
        echo -e "${M}------------------------------------------------------------${RESET}"
        echo -e " ${C}MODE:${RESET} ${W}${BOLD}BROWSE${RESET}  ${Y}[L] Go to Library${RESET}"
    else
        echo -e "${M}------------------------------------------------------------${RESET}"
        echo -e " ${C}MODE:${RESET} ${G}${BOLD}LIBRARY (Installed)${RESET}  ${Y}[L] Go to Browse${RESET}"
    fi
    
    echo -e "${M}------------------------------------------------------------${RESET}"
    if [[ -n "$SEARCH_TERM" ]]; then
        echo -e "${Y}Search: '${W}$SEARCH_TERM${Y}'${RESET}"
    fi
    printf "${BOLD}%-4s %-22s %-10s %-30s${RESET}\n" "ID" "Name" "Type" "Status/Desc"
    echo -e "${B}------------------------------------------------------------${RESET}"
}

draw_list() {
    local total_items=${#FILTERED_INDICES[@]}
    local start_index=$(( (CURRENT_PAGE - 1) * APPS_PER_PAGE ))
    local end_index=$(( start_index + APPS_PER_PAGE - 1 ))
    
    if [[ $start_index -ge $total_items && $total_items -gt 0 ]]; then
        CURRENT_PAGE=1
        start_index=0
        end_index=$(( APPS_PER_PAGE - 1 ))
    fi

    local count=0
    for i in "${FILTERED_INDICES[@]}"; do
        if [[ $count -ge $start_index && $count -le $end_index ]]; then
            local entry=""
            local name=""
            local type=""
            local desc=""
            local status=""
            
            if [[ "$VIEW_MODE" == "BROWSE" ]]; then
                entry="${APP_DB[$i]}"
                name=$(echo "$entry" | cut -d'|' -f1)
                desc=$(echo "$entry" | cut -d'|' -f2)
                type=$(echo "$entry" | cut -d'|' -f3)
                
                if [[ ${#desc} -gt 25 ]]; then desc="${desc:0:22}..."; fi
                
                # Check installed status
                if [[ -n "${INSTALLED_MAP["$name"]}" ]]; then
                    status="${G}[✔] Installed${RESET}"
                    name="${G}$name${RESET}"
                else
                    status="$desc"
                fi
            else
                # Library Mode
                entry="${INSTALLED_LIST[$i]}"
                name=$(echo "$entry" | cut -d'|' -f1)
                type=$(echo "$entry" | cut -d'|' -f2)
                desc="Manage this app"
                status="${G}Ready${RESET}"
            fi
            
            # Color code types
            local type_color=$W
            case $type in
                "snap") type_color=$G ;;
                "flatpak") type_color=$B ;;
                "deb-repo"|"direct-deb") type_color=$R ;;
                *) type_color=$Y ;;
            esac

            printf "${C}%-4s${RESET} ${BOLD}%-22s${RESET} ${type_color}%-10s${RESET} %-30s\n" "$((i+1))" "$name" "$type" "$status"
        fi
        ((count++))
    done
    
    echo -e "${B}------------------------------------------------------------${RESET}"
    local total_pages=$(( (total_items + APPS_PER_PAGE - 1) / APPS_PER_PAGE ))
    [ $total_pages -eq 0 ] && total_pages=1
    echo -e "Page: ${W}$CURRENT_PAGE / $total_pages${RESET} | Total: ${W}$total_items${RESET}"
}

draw_footer() {
    echo -e "${M}------------------------------------------------------------${RESET}"
    echo -e "${Y}[←]${RESET} Prev  ${Y}[→]${RESET} Next  ${Y}[S]${RESET} Search  ${Y}[L]${RESET} Mode  ${Y}[Q]${RESET} Quit"
    if [[ "$VIEW_MODE" == "BROWSE" ]]; then
        echo -e "${G}Install:${RESET} Type ID(s) then Enter"
    else
        echo -e "${R}Manage:${RESET} Type ID(s) to Uninstall/Update"
    fi
    echo -n -e "${BOLD}Action > ${INPUT_BUFFER}${RESET}"
}

# --- UI HELPERS ---
draw_install_screen() {
    local percent=$1; local msg=$2
    local bar_width=40
    local completed=$(( bar_width * percent / 100 ))
    local remaining=$(( bar_width - completed ))
    clear
    echo -e "${BG_MAG}${W}${BOLD}  WOW APP STORE  ${RESET} ${C}Processing...${RESET}"
    echo -e "${M}------------------------------------------------------------${RESET}\n\n"
    echo -ne "    ${BOLD}[${G}"
    for ((i=0; i<completed; i++)); do echo -n "#"; done
    echo -ne "${RESET}"
    for ((i=0; i<remaining; i++)); do echo -n "."; done
    echo -ne "${BOLD}] ${percent}%${RESET}\n\n"
    echo -e "    ${C}Status:${RESET} ${W}${msg}${RESET}\n\n"
    echo -e "${M}------------------------------------------------------------${RESET}"
}

run_silent() {
    local cmd="$1"; local logfile="/tmp/wowstore_install.log"
    eval "$cmd" >> "$logfile" 2>&1
    return $?
}

# --- INSTALLATION LOGIC ---
process_install_queue() {
    local ids_to_process=("$@")
    local LOGFILE="/tmp/wowstore_install.log"
    local BATCH_APT=(); local BATCH_SNAP=(); local BATCH_FLATPAK=(); local DIRECT_DEBS=() 
    local update_apt_needed=false

    echo "" > "$LOGFILE"
    echo -e "\n${C}Authenticating...${RESET}"
    if ! sudo -v; then echo -e "${R}Auth failed.${RESET}"; read -r; return; fi

    for id in "${ids_to_process[@]}"; do
        id=$(echo "$id" | xargs)
        local index=$((id - 1))
        if [[ $index -lt 0 || $index -ge ${#APP_DB[@]} ]]; then continue; fi

        local entry="${APP_DB[$index]}"
        local name=$(echo "$entry" | cut -d'|' -f1)
        local type=$(echo "$entry" | cut -d'|' -f3)
        local pkg=$(echo "$entry" | cut -d'|' -f4)
        local extra=$(echo "$entry" | cut -d'|' -f5)

        case $type in
            "snap") BATCH_SNAP+=("$pkg $extra|$name|$type|$pkg") ;;
            "flatpak") BATCH_FLATPAK+=("$pkg|$name|$type|$pkg") ;;
            "apt") BATCH_APT+=("$pkg|$name|$type|$pkg") ;;
            "apt-universe") 
                sudo add-apt-repository universe -y >> "$LOGFILE" 2>&1; update_apt_needed=true
                BATCH_APT+=("$pkg|$name|$type|$pkg") ;;
            "apt-ppa")
                sudo add-apt-repository -y "$extra" >> "$LOGFILE" 2>&1; update_apt_needed=true
                BATCH_APT+=("$pkg|$name|$type|$pkg") ;;
            "apt-key")
                eval "$extra" >> "$LOGFILE" 2>&1; update_apt_needed=true
                BATCH_APT+=("$pkg|$name|$type|$pkg") ;;
            "deb-repo")
                local tmp_deb="/tmp/wow_repo.deb"; wget -q -O "$tmp_deb" "$extra"
                sudo dpkg -i "$tmp_deb" >> "$LOGFILE" 2>&1; rm -f "$tmp_deb"; update_apt_needed=true
                BATCH_APT+=("$pkg|$name|$type|$pkg") ;;
            "direct-deb") DIRECT_DEBS+=("$name|$extra|$type|$pkg") ;;
        esac
    done

    # Calc steps
    local total_steps=0; local current_step=0
    [ "$update_apt_needed" = true ] && ((total_steps++))
    [ ${#BATCH_APT[@]} -gt 0 ] && ((total_steps++))
    ((total_steps += ${#DIRECT_DEBS[@]})); ((total_steps += ${#BATCH_SNAP[@]})); ((total_steps += ${#BATCH_FLATPAK[@]}))
    if [ $total_steps -eq 0 ]; then return; fi

    if [ "$update_apt_needed" = true ]; then
        ((current_step++)); draw_install_screen $((current_step*100/total_steps)) "Updating Repositories..."
        run_silent "sudo apt update"
    fi

    if [ ${#BATCH_APT[@]} -gt 0 ]; then
        ((current_step++)); draw_install_screen $((current_step*100/total_steps)) "Installing System Packages..."
        # Extract just pkg names for apt command
        local apt_pkgs=""
        for item in "${BATCH_APT[@]}"; do apt_pkgs+="$(echo "$item" | cut -d'|' -f1) "; done
        
        if run_silent "sudo apt install -y $apt_pkgs"; then
            for item in "${BATCH_APT[@]}"; do track_install "$(echo "$item" | cut -d'|' -f2)" "$(echo "$item" | cut -d'|' -f3)" "$(echo "$item" | cut -d'|' -f4)"; done
        else
            clear; echo -e "${R}APT Error. Log:${RESET}"; cat "$LOGFILE"; read -r; return
        fi
    fi

    for item in "${DIRECT_DEBS[@]}"; do
        ((current_step++)); draw_install_screen $((current_step*100/total_steps)) "Installing $(echo "$item" | cut -d'|' -f1)..."
        local d_url=$(echo "$item" | cut -d'|' -f2); local d_file="/tmp/$(basename "$d_url")"
        wget -q -O "$d_file" "$d_url"
        if run_silent "sudo dpkg -i \"$d_file\" && sudo apt-get install -f -y"; then
            track_install "$(echo "$item" | cut -d'|' -f1)" "$(echo "$item" | cut -d'|' -f3)" "$(echo "$item" | cut -d'|' -f4)"
        else
            clear; echo -e "${R}Install Error. Log:${RESET}"; cat "$LOGFILE"; rm "$d_file"; read -r; return
        fi
        rm -f "$d_file"
    done

    for item in "${BATCH_SNAP[@]}"; do
        ((current_step++)); local name=$(echo "$item" | cut -d'|' -f2)
        draw_install_screen $((current_step*100/total_steps)) "Installing Snap: $name..."
        if run_silent "sudo snap install $(echo "$item" | cut -d'|' -f1)"; then
            track_install "$name" "$(echo "$item" | cut -d'|' -f3)" "$(echo "$item" | cut -d'|' -f4)"
        else
            clear; echo -e "${R}Snap Error. Log:${RESET}"; cat "$LOGFILE"; read -r; return
        fi
    done

    for item in "${BATCH_FLATPAK[@]}"; do
        ((current_step++)); local name=$(echo "$item" | cut -d'|' -f2)
        draw_install_screen $((current_step*100/total_steps)) "Installing Flatpak: $name..."
        run_silent "sudo apt install -y gnome-software-plugin-flatpak"
        if run_silent "flatpak install --user -y flathub $(echo "$item" | cut -d'|' -f1)"; then
            track_install "$name" "$(echo "$item" | cut -d'|' -f3)" "$(echo "$item" | cut -d'|' -f4)"
        else
            clear; echo -e "${R}Flatpak Error. Log:${RESET}"; cat "$LOGFILE"; read -r; return
        fi
    done

    draw_install_screen 100 "Done!"
    sleep 1
}

# --- UNINSTALL/UPDATE LOGIC ---
process_library_queue() {
    local ids_to_process=("$@")
    local LOGFILE="/tmp/wowstore_install.log"
    
    # Prompt for action
    echo -e "\n\n${C}Selected ${#ids_to_process[@]} app(s).${RESET}"
    echo -e "${Y}[1]${RESET} Update / Reinstall"
    echo -e "${R}[2]${RESET} Uninstall"
    echo -e "${W}[3]${RESET} Cancel"
    echo -n -e "${BOLD}Choose > ${RESET}"
    read -r action

    if [[ "$action" == "3" || -z "$action" ]]; then return; fi

    echo "" > "$LOGFILE"
    echo -e "\n${C}Authenticating...${RESET}"
    if ! sudo -v; then echo -e "${R}Auth failed.${RESET}"; read -r; return; fi

    local total_steps=${#ids_to_process[@]}
    local current_step=0

    for id in "${ids_to_process[@]}"; do
        ((current_step++))
        id=$(echo "$id" | xargs)
        local index=$((id - 1))
        if [[ $index -lt 0 || $index -ge ${#INSTALLED_LIST[@]} ]]; then continue; fi

        local entry="${INSTALLED_LIST[$index]}"
        local name=$(echo "$entry" | cut -d'|' -f1)
        local type=$(echo "$entry" | cut -d'|' -f2)
        local pkg=$(echo "$entry" | cut -d'|' -f3)

        if [[ "$action" == "2" ]]; then
            # UNINSTALL
            draw_install_screen $((current_step*100/total_steps)) "Uninstalling $name..."
            local success=false
            
            case $type in
                "snap") run_silent "sudo snap remove $pkg" && success=true ;;
                "flatpak") run_silent "flatpak uninstall --user -y $pkg" && success=true ;;
                "apt"|"apt-universe"|"apt-ppa"|"apt-key"|"deb-repo"|"direct-deb") 
                    run_silent "sudo apt remove -y $pkg" && success=true ;;
            esac

            if [ "$success" = true ]; then
                track_remove "$name"
            else
                clear; echo -e "${R}Error removing $name. Log:${RESET}"; cat "$LOGFILE"; read -r
            fi
        
        elif [[ "$action" == "1" ]]; then
            # UPDATE / REINSTALL
            draw_install_screen $((current_step*100/total_steps)) "Updating/Reinstalling $name..."
            case $type in
                "snap") run_silent "sudo snap refresh $pkg || sudo snap install $pkg" ;;
                "flatpak") run_silent "flatpak update -y $pkg || flatpak install --user -y flathub $pkg" ;;
                "apt"|"apt-universe"|"apt-ppa"|"apt-key"|"deb-repo"|"direct-deb") 
                    run_silent "sudo apt install --only-upgrade -y $pkg || sudo apt install -y $pkg" ;;
            esac
        fi
    done
    
    draw_install_screen 100 "Tasks Completed"
    sleep 1
    # Reload list to reflect changes
    init_filter
}

# --- MAIN LOOP ---

# Start with checks
check_dependencies
self_update
install_to_path
init_filter

INPUT_BUFFER="" # Initialize buffer

while true; do
    draw_header
    draw_list
    draw_footer
    
    # Read one character silently
    IFS= read -rsn1 key
    
    # Handle Enter (Empty key)
    if [[ -z "$key" ]]; then
        if [[ -n "$INPUT_BUFFER" ]]; then
            regex='^[0-9, ]+$'
            if [[ "$INPUT_BUFFER" =~ $regex ]]; then
                IFS=',' read -ra ADDR <<< "$INPUT_BUFFER"
                if [[ "$VIEW_MODE" == "BROWSE" ]]; then
                    process_install_queue "${ADDR[@]}"
                else
                    process_library_queue "${ADDR[@]}"
                fi
                INPUT_BUFFER=""
                # Reset search if needed to show updated status
                init_filter
            else
                INPUT_BUFFER=""
            fi
        fi
        continue
    fi

    # Handle Backspace
    if [[ "$key" == $'\x7f' || "$key" == $'\x08' ]]; then
        if [[ -n "$INPUT_BUFFER" ]]; then INPUT_BUFFER="${INPUT_BUFFER%?}"; fi
        continue
    fi

    # Handle Escape Sequences (Arrows)
    if [[ "$key" == $'\e' ]]; then
        read -rsn2 -t 0.01 next
        if [[ "$next" == "[C" ]]; then 
            total_items=${#FILTERED_INDICES[@]}
            max_page=$(( (total_items + APPS_PER_PAGE - 1) / APPS_PER_PAGE ))
            if [[ $CURRENT_PAGE -lt $max_page ]]; then ((CURRENT_PAGE++)); fi
        elif [[ "$next" == "[D" ]]; then 
            if [[ $CURRENT_PAGE -gt 1 ]]; then ((CURRENT_PAGE--)); fi
        fi
        continue
    fi

    # Handle Single Key Commands (Only if buffer is empty, to allow typing numbers)
    if [[ -z "$INPUT_BUFFER" ]]; then
        if [[ "$key" == "s" || "$key" == "S" ]]; then
            echo -e "\n\n${C}Enter search term (leave empty to reset):${RESET}"
            read -r term; SEARCH_TERM="$term"; CURRENT_PAGE=1; init_filter; continue
        elif [[ "$key" == "l" || "$key" == "L" ]]; then
            if [[ "$VIEW_MODE" == "BROWSE" ]]; then VIEW_MODE="LIBRARY"; else VIEW_MODE="BROWSE"; fi
            CURRENT_PAGE=1; SEARCH_TERM=""; init_filter; continue
        elif [[ "$key" == "q" || "$key" == "Q" ]]; then
            echo -e "\n${C}Goodbye!${RESET}"; exit 0
        fi
    fi

    # Handle Digits, Comma, Space (Input Buffer)
    if [[ "$key" =~ [0-9,\ ] ]]; then
        INPUT_BUFFER+="$key"
        continue
    fi
done
