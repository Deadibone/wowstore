#!/bin/bash

# ==============================================================================
# WOW APP STORE - A Beautiful TUI for Ubuntu App Management
# ==============================================================================

# --- VERSION & UPDATE CONFIG ---
VERSION="1.6"
# Using raw.githubusercontent to get the actual code, assuming 'main' branch
UPDATE_URL="https://raw.githubusercontent.com/deadibone/wowstore/main/wowstore.sh"

# --- COLORS & STYLING ---
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
M='\033[0;35m'
C='\033[0;36m'
W='\033[1;37m'
BOLD='\033[1m'
BG_BLUE='\033[44m'
BG_MAG='\033[45m'
RESET='\033[0m'

# --- SYSTEM CHECKS & SELF-MANAGEMENT ---

check_dependencies() {
    command -v curl >/dev/null 2>&1 || { echo "Installing curl..."; sudo apt update && sudo apt install -y curl; }
    command -v wget >/dev/null 2>&1 || { echo "Installing wget..."; sudo apt update && sudo apt install -y wget; }
    command -v snap >/dev/null 2>&1 || { echo "Snap not found. Some apps may not install."; }
    command -v flatpak >/dev/null 2>&1 || { echo "Flatpak not found. Installing..."; sudo apt install -y flatpak; flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; }
}

self_update() {
    # 1. Check Internet Connection (timeout 2s)
    wget -q --spider --timeout=2 http://github.com
    if [ $? -eq 0 ]; then
        # 2. Download remote script to temp
        local temp_script=$(mktemp)
        wget -q -O "$temp_script" "$UPDATE_URL"

        # 3. Check if download succeeded and has content
        if [ -s "$temp_script" ]; then
            # 4. Extract remote version
            local remote_ver=$(grep -m1 '^VERSION=' "$temp_script" | cut -d'"' -f2)
            
            if [[ -n "$remote_ver" && "$remote_ver" != "$VERSION" ]]; then
                echo -e "${M}New version found ($remote_ver). Updating self...${RESET}"
                
                # Check if we have write permissions to current script
                if [ -w "$0" ]; then
                    cp "$temp_script" "$0"
                else
                    echo "Sudo required to update installed script..."
                    sudo cp "$temp_script" "$0"
                fi
                
                chmod +x "$0"
                rm "$temp_script"
                echo -e "${G}Update complete! Restarting...${RESET}"
                exec "$0" "$@"
            fi
            rm "$temp_script"
        fi
    fi
}

install_to_path() {
    # Check if we are already running as the installed command
    if [[ "$(basename "$0")" == "wowstore" && -f "/usr/local/bin/wowstore" ]]; then
        return
    fi

    # Check if 'wowstore' is already in path
    if ! command -v wowstore >/dev/null 2>&1; then
        echo -e "${C}------------------------------------------------------------${RESET}"
        echo -e "${Y}Would you like to install this as the command 'wowstore'?${RESET}"
        echo -e "This allows you to run it from anywhere in the terminal."
        echo -n -e "${BOLD}(y/n) > ${RESET}"
        read -r -n 1 response
        echo # Newline
        
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
    # --- GAMING ---
    "Minecraft|Official Launcher|direct-deb|minecraft-launcher|https://launcher.mojang.com/download/Minecraft.deb"
    "Sober (Roblox)|Roblox Client (Vinegar)|flatpak|org.vinegarhq.Sober|"
    "Heroic Launcher|Epic Games & GOG Launcher|flatpak|com.heroicgameslauncher.hgl|"
    "Lutris|Open Source Gaming Platform|apt-universe|lutris|"
    "Steam|Digital distribution platform|apt-universe|steam-installer|"
    
    # --- DEV TOOLS ---
    "VS Code|Code editing. Redefined.|apt-key|code|wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && sudo sh -c 'echo \"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" > /etc/apt/sources.list.d/vscode.list' && rm -f packages.microsoft.gpg"
    "Sublime Text|Sophisticated text editor|snap|sublime-text|--classic"
    "PyCharm Community|Python IDE|snap|pycharm-community|--classic"
    "IntelliJ IDEA Com.|Java/Kotlin IDE|snap|intellij-idea-community|--classic"
    "Postman|API platform for building and using APIs|snap|postman|"
    "Docker|Containerization platform|apt|docker.io|"
    "Git|Distributed version control system|apt-ppa|git|ppa:git-core/ppa"
    "Node.js (LTS)|JavaScript runtime|snap|node|--channel=lts/stable --classic"
    "Python 3|Interpreted high-level programming language|apt|python3|"
    "Godot 4|Game Engine|flatpak|org.godotengine.Godot|"

    # --- GNOME / DESKTOP ---
    "Extension Manager|Browse/Install GNOME Extensions|flatpak|com.mattjakeman.ExtensionManager|"
    "GNOME Shell Ext.|Standard GNOME Extensions|apt|gnome-shell-extensions|"
    "GNOME Connector|Browser integration for extensions|apt|gnome-browser-connector|"
    "Gnome Tweaks|Customize GNOME desktop|apt|gnome-tweaks|"
    "Amberol|Music Player|flatpak|io.bassi.Amberol|"
    "Apostrophe|Distraction free markdown editor|flatpak|org.gnome.gitlab.somas.Apostrophe|"
    "Authenticator|2FA Code Generator|flatpak|com.belmoussaoui.Authenticator|"
    "Blanket|Listen to ambient sounds|flatpak|com.rafaelmardojai.Blanket|"
    "Bottles|Run Windows Software|flatpak|com.usebottles.bottles|"
    "Boxes|Virtualization made simple|flatpak|org.gnome.Boxes|"
    "Builder|IDE for GNOME|flatpak|org.gnome.Builder|"
    "Calculator|Perform arithmetic calculations|flatpak|org.gnome.Calculator|"
    "Calendar|Manage your schedule|flatpak|org.gnome.Calendar|"
    "Characters|Find and copy special characters|flatpak|org.gnome.Characters|"
    "Clocks|Clocks for world times|flatpak|org.gnome.clocks|"
    "Connections|Remote desktop client|flatpak|org.gnome.Connections|"
    "Contacts|Manage your contacts|flatpak|org.gnome.Contacts|"
    "Decoder|Scan and generate QR codes|flatpak|com.belmoussaoui.Decoder|"
    "Dialect|Translate text|flatpak|app.drey.Dialect|"
    "Drawing|Simple drawing utility|flatpak|com.github.maoschanz.drawing|"
    "Easy Effects|Audio effects for PipeWire|flatpak|com.github.wwmm.easyeffects|"
    "Epiphany (Web)|GNOME Web Browser|flatpak|org.gnome.Epiphany|"
    "Evince|Document Viewer|flatpak|org.gnome.Evince|"
    "Eye of GNOME|Image Viewer|flatpak|org.gnome.eog|"
    "Foliate|E-book reader|flatpak|com.github.johnfactotum.Foliate|"
    "Fragments|BitTorrent Client|flatpak|de.haeckerfelix.Fragments|"
    "Gaphor|Simple modeling tool|flatpak|org.gaphor.Gaphor|"
    "Geary|Email client|flatpak|org.gnome.Geary|"
    "Icon Library|Find symbolic icons|flatpak|org.gnome.design.IconLibrary|"
    "Identity|Compare images and videos|flatpak|org.gnome.gitlab.YaLTeR.Identity|"
    "Impression|Create bootable drives|flatpak|io.gitlab.adhami3310.Impression|"
    "Kooha|Simple screen recorder|flatpak|io.github.seadve.Kooha|"
    "Komikku|Manga reader|flatpak|info.febvre.Komikku|"
    "Lorem|Generate placeholder text|flatpak|org.gnome.design.Lorem|"
    "Loupe|Fast image viewer|flatpak|org.gnome.Loupe|"
    "Maps|Find places around the world|flatpak|org.gnome.Maps|"
    "Metadata Cleaner|View and clean metadata|flatpak|fr.romainvigier.MetadataCleaner|"
    "Mousai|Identify songs|flatpak|io.github.seadve.Mousai|"
    "NewsFlash|Feed reader|flatpak|com.gitlab.newsflash|"
    "Obfuscate|Redact private info from images|flatpak|com.belmoussaoui.Obfuscate|"
    "Paper Clip|Edit PDF metadata|flatpak|io.github.diegoivan.pdf_metadata_editor|"
    "Pika Backup|Simple backups|flatpak|org.gnome.World.PikaBackup|"
    "Planify|Task manager|flatpak|io.github.alainm23.planify|"
    "Polari|IRC Client|flatpak|org.gnome.Polari|"
    "Secrets|Password manager|flatpak|org.gnome.World.Secrets|"
    "Shortwave|Internet radio|flatpak|de.haeckerfelix.Shortwave|"
    "Simple Scan|Scan Documents|flatpak|org.gnome.SimpleScan|"
    "Solanum|Pomodoro timer|flatpak|org.gnome.Solanum|"
    "Sound Recorder|Record sound|flatpak|org.gnome.SoundRecorder|"
    "Tangram|Web apps browser|flatpak|re.sonny.Tangram|"
    "Text Editor|Simple text editor|flatpak|org.gnome.TextEditor|"
    "Text Pieces|Text transformation tool|flatpak|com.github.maoschanz.TextPieces|"
    "Totem|Video Player|flatpak|org.gnome.Totem|"
    "Tour|GNOME Tour and Greeter|flatpak|org.gnome.Tour|"
    "Video Trimmer|Trim videos|flatpak|org.gnome.gitlab.YaLTeR.VideoTrimmer|"
    "Warp|Secure file transfer|flatpak|app.drey.Warp|"
    "Weather|Show weather conditions|flatpak|org.gnome.Weather|"
    "Workbench|Learn and prototype with GNOME|flatpak|re.sonny.Workbench|"
    
    # --- ESSENTIALS & INTERNET ---
    "Proton VPN|High-speed secure VPN|deb-repo|proton-vpn-gnome-desktop|https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb"
    "Chromium|Open Source Web Browser|apt|chromium-browser|"
    "Brave Browser|Secure, fast & private web browser|apt-key|brave-browser|sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && echo 'deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main' | sudo tee /etc/apt/sources.list.d/brave-browser-release.list"
    "Discord|All-in-one voice and text chat|snap|discord|"
    "Telegram|Messaging with a focus on speed|snap|telegram-desktop|"
    "Signal|Encrypted instant messaging|flatpak|org.signal.Signal|"
    "Slack|Collaboration hub|snap|slack|"
    "Zoom|Video conferencing|flatpak|us.zoom.Zoom|"
    "LocalSend|AirDrop Alternative (LAN Share)|flatpak|org.localsend.LocalSend_App|"
    "OnlyOffice|Office Suite|flatpak|org.onlyoffice.desktopeditors|"
    "LibreOffice|Office Suite|apt|libreoffice|"
    "Thunderbird|Email Client|apt|thunderbird|"
    
    # --- MEDIA & CREATIVE ---
    "VLC Media Player|The best open source media player|apt|vlc|"
    "MPV|Minimalist media player|apt|mpv|"
    "Spotify|Music for everyone|snap|spotify|"
    "GIMP|GNU Image Manipulation Program|apt|gimp|"
    "Krita|Digital Painting|flatpak|org.kde.krita|"
    "OBS Studio|Open Broadcaster Software|apt-ppa|obs-studio|ppa:obsproject/obs-studio"
    "Kdenlive|Video Editor|flatpak|org.kde.kdenlive|"
    "Blender|3D creation suite|snap|blender|"
    "Inkscape|Vector graphics editor|apt|inkscape|"
    "Audacity|Audio editor and recorder|flatpak|org.audacityteam.Audacity|"
    "HandBrake|Video Transcoder|flatpak|fr.handbrake.ghb|"
    "Clementine|Modern music player|apt|clementine|"
    "Stremio|Video streaming|flatpak|com.stremio.Stremio|"
    
    # --- SYSTEM ---
    "Htop|Interactive process viewer|apt|htop|"
    "Neofetch|System information tool|apt|neofetch|"
    "GParted|Partition editor|apt|gparted|"
    "FileZilla|FTP client|apt|filezilla|"
    "VirtualBox|Oracle VM VirtualBox|apt|virtualbox|"
    "BleachBit|System Cleaner|apt|bleachbit|"
    "Timeshift|System Restore|apt|timeshift|"
    "qBittorrent|BitTorrent client|apt-ppa|qbittorrent|ppa:qbittorrent-team/qbittorrent-stable"
)

# --- SORTING APP DB ALPHABETICALLY ---
# Uses case-insensitive sort based on the first field (Name)
IFS=$'\n' APP_DB=($(sort -f -t'|' -k1 <<<"${APP_DB[*]}"))
unset IFS

# --- GLOBAL VARIABLES ---
CURRENT_PAGE=1
SEARCH_TERM=""
FILTERED_INDICES=()

# --- INITIALIZATION ---
init_filter() {
    FILTERED_INDICES=()
    local i=0
    for app in "${APP_DB[@]}"; do
        if [[ -z "$SEARCH_TERM" ]]; then
            FILTERED_INDICES+=($i)
        else
            # Case insensitive search
            local name=$(echo "$app" | cut -d'|' -f1)
            local desc=$(echo "$app" | cut -d'|' -f2)
            if echo "$name $desc" | grep -iq "$SEARCH_TERM"; then
                FILTERED_INDICES+=($i)
            fi
        fi
        ((i++))
    done
}

# --- GUI FUNCTIONS ---

draw_header() {
    clear
    echo -e "${BG_MAG}${W}${BOLD}  WOW APP STORE  ${RESET} ${C}v${VERSION}${RESET}"
    echo -e "${M}------------------------------------------------------------${RESET}"
    if [[ -n "$SEARCH_TERM" ]]; then
        echo -e "${Y}Search results for: '${W}$SEARCH_TERM${Y}'${RESET}"
    else
        echo -e "${C}Browse Catalogue (Sorted A-Z)${RESET}"
    fi
    echo -e "${M}------------------------------------------------------------${RESET}"
    printf "${BOLD}%-4s %-20s %-10s %-30s${RESET}\n" "ID" "Name" "Type" "Description"
    echo -e "${B}------------------------------------------------------------${RESET}"
}

draw_list() {
    local total_items=${#FILTERED_INDICES[@]}
    local start_index=$(( (CURRENT_PAGE - 1) * APPS_PER_PAGE ))
    local end_index=$(( start_index + APPS_PER_PAGE - 1 ))
    
    if [[ $start_index -ge $total_items ]]; then
        CURRENT_PAGE=1
        start_index=0
        end_index=$(( APPS_PER_PAGE - 1 ))
    fi

    local count=0
    for i in "${FILTERED_INDICES[@]}"; do
        if [[ $count -ge $start_index && $count -le $end_index ]]; then
            local entry="${APP_DB[$i]}"
            local name=$(echo "$entry" | cut -d'|' -f1)
            local desc=$(echo "$entry" | cut -d'|' -f2)
            local type=$(echo "$entry" | cut -d'|' -f3)
            
            # Truncate description for display
            if [[ ${#desc} -gt 30 ]]; then desc="${desc:0:27}..."; fi
            
            # Color code types
            local type_color=$W
            case $type in
                "snap") type_color=$G ;;
                "flatpak") type_color=$B ;;
                "deb-repo"|"direct-deb") type_color=$R ;;
                *) type_color=$Y ;;
            esac

            printf "${C}%-4s${RESET} ${BOLD}%-20s${RESET} ${type_color}%-10s${RESET} %-30s\n" "$((i+1))" "$name" "$type" "$desc"
        fi
        ((count++))
    done
    
    echo -e "${B}------------------------------------------------------------${RESET}"
    local total_pages=$(( (total_items + APPS_PER_PAGE - 1) / APPS_PER_PAGE ))
    [ $total_pages -eq 0 ] && total_pages=1
    echo -e "Page: ${W}$CURRENT_PAGE / $total_pages${RESET} | Total Apps: ${W}$total_items${RESET}"
}

draw_footer() {
    echo -e "${M}------------------------------------------------------------${RESET}"
    echo -e "${Y}[N]${RESET} Next  ${Y}[P]${RESET} Prev  ${Y}[S]${RESET} Search  ${Y}[Q]${RESET} Quit"
    echo -e "${G}Install:${RESET} Enter ID(s) separated by commas (e.g. 10, 1, 25)"
    echo -n -e "${BOLD}Action > ${RESET}"
}

process_queue() {
    # Takes an array of IDs as input
    local ids_to_process=("$@")
    
    # Lists to hold package names for batch installation
    local BATCH_APT=()
    local BATCH_SNAP=()
    local BATCH_FLATPAK=()
    local DIRECT_DEBS=() # Stores indices for direct debs to process individually
    
    local update_apt_needed=false

    echo -e "\n${M}Preparing queue...${RESET}"

    for id in "${ids_to_process[@]}"; do
        # Trim whitespace
        id=$(echo "$id" | xargs)
        
        # Validate ID
        local index=$((id - 1))
        if [[ $index -lt 0 || $index -ge ${#APP_DB[@]} ]]; then
            echo -e "${R}Skipping invalid ID: $id${RESET}"
            continue
        fi

        local entry="${APP_DB[$index]}"
        local name=$(echo "$entry" | cut -d'|' -f1)
        local type=$(echo "$entry" | cut -d'|' -f3)
        local pkg=$(echo "$entry" | cut -d'|' -f4)
        local extra=$(echo "$entry" | cut -d'|' -f5)
        
        echo -e "Processing: ${W}$name${RESET}..."

        case $type in
            "snap")
                BATCH_SNAP+=("$pkg $extra")
                ;;
            "flatpak")
                BATCH_FLATPAK+=("$pkg")
                ;;
            "apt")
                BATCH_APT+=("$pkg")
                ;;
            "apt-universe")
                echo -e "  -> Enabling Universe repo..."
                sudo add-apt-repository universe -y >/dev/null 2>&1
                update_apt_needed=true
                BATCH_APT+=("$pkg")
                ;;
            "apt-ppa")
                echo -e "  -> Adding PPA: $extra..."
                sudo add-apt-repository -y "$extra" >/dev/null 2>&1
                update_apt_needed=true
                BATCH_APT+=("$pkg")
                ;;
            "apt-key")
                echo -e "  -> Setting up keys..."
                eval "$extra"
                update_apt_needed=true
                BATCH_APT+=("$pkg")
                ;;
            "deb-repo")
                echo -e "  -> Configuring repo deb..."
                local tmp_deb="/tmp/wow_store_repo_setup_$id.deb"
                wget -q -O "$tmp_deb" "$extra"
                if [[ -f "$tmp_deb" ]]; then
                    sudo dpkg -i "$tmp_deb" >/dev/null 2>&1
                    rm -f "$tmp_deb"
                    update_apt_needed=true
                    BATCH_APT+=("$pkg")
                else
                    echo -e "${R}Failed to download config for $name${RESET}"
                fi
                ;;
            "direct-deb")
                # Store full info to process later
                DIRECT_DEBS+=("$name|$extra")
                ;;
        esac
    done

    # --- EXECUTE BATCH INSTALLS ---

    # 1. Update APT if Repos changed
    if [ "$update_apt_needed" = true ]; then
        echo -e "\n${C}Updating APT Repositories...${RESET}"
        sudo apt update
    fi

    # 2. APT Batch
    if [ ${#BATCH_APT[@]} -gt 0 ]; then
        echo -e "\n${C}Installing APT packages: ${W}${BATCH_APT[*]}${RESET}"
        sudo apt install -y "${BATCH_APT[@]}"
    fi

    # 3. Direct Debs (Like Minecraft) - Process AFTER apt update/install
    if [ ${#DIRECT_DEBS[@]} -gt 0 ]; then
        for ddeb in "${DIRECT_DEBS[@]}"; do
            local d_name=$(echo "$ddeb" | cut -d'|' -f1)
            local d_url=$(echo "$ddeb" | cut -d'|' -f2)
            local d_file="/tmp/$(basename "$d_url")"

            echo -e "\n${C}Installing Standalone .deb: ${W}$d_name${RESET}"
            echo -e "  -> Downloading..."
            wget -q --show-progress -O "$d_file" "$d_url"
            
            if [[ -f "$d_file" ]]; then
                echo -e "  -> Installing (dpkg)..."
                sudo dpkg -i "$d_file"
                echo -e "  -> Resolving dependencies (apt -f install)..."
                sudo apt-get install -f -y
                rm -f "$d_file"
                echo -e "${G}  -> $d_name Installed.${RESET}"
            else
                echo -e "${R}  -> Download failed.${RESET}"
            fi
        done
    fi

    # 4. Snap Batch
    if [ ${#BATCH_SNAP[@]} -gt 0 ]; then
        echo -e "\n${C}Installing Snap packages...${RESET}"
        for snap_cmd in "${BATCH_SNAP[@]}"; do
            echo -e "Installing Snap: $snap_cmd"
            sudo snap install $snap_cmd
        done
    fi

    # 5. Flatpak Batch
    if [ ${#BATCH_FLATPAK[@]} -gt 0 ]; then
        echo -e "\n${C}Installing Flatpak packages: ${W}${BATCH_FLATPAK[*]}${RESET}"
        # Ensure plugin exists once
        sudo apt install -y gnome-software-plugin-flatpak >/dev/null 2>&1
        flatpak install -y flathub "${BATCH_FLATPAK[@]}"
    fi

    echo -e "\n${G}Batch processing complete!${RESET}"
}

# --- MAIN LOOP ---

# Start with checks
check_dependencies
self_update
install_to_path
init_filter

while true; do
    draw_header
    draw_list
    draw_footer
    read -r input

    case $input in
        [nN]*)
            local total_items=${#FILTERED_INDICES[@]}
            local max_page=$(( (total_items + APPS_PER_PAGE - 1) / APPS_PER_PAGE ))
            if [[ $CURRENT_PAGE -lt $max_page ]]; then
                ((CURRENT_PAGE++))
            fi
            ;;
        [pP]*)
            if [[ $CURRENT_PAGE -gt 1 ]]; then
                ((CURRENT_PAGE--))
            fi
            ;;
        [sS]*)
            echo -e "\n${C}Enter search term (leave empty to reset):${RESET}"
            read -r term
            SEARCH_TERM="$term"
            CURRENT_PAGE=1
            init_filter
            ;;
        [qQ]*)
            echo -e "${C}Goodbye!${RESET}"
            exit 0
            ;;
        *)
            # Handle list of numbers
            if [[ "$input" =~ ^[0-9, ]+$ ]]; then
                IFS=',' read -ra ADDR <<< "$input"
                process_queue "${ADDR[@]}"
                echo -e "\n${G}Press Enter to continue.${RESET}"
                read -r
            else
                if [[ -n "$input" ]]; then
                    echo -e "\n${R}Invalid input.${RESET} Press Enter."
                    read -r
                fi
            fi
            ;;
    esac
done
