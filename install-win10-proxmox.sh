#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Proxmox Windows Installer Contributors
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Description: Windows 10 LTSC VM Installation Script for Proxmox VE

source /dev/stdin <<<$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/api.func)

function header_info {
  clear
  cat <<"EOF"
    __ __(_)_______/ /_____  _    _____ 
   / / / / / ___/ __ \/ __ \/ |  / / _ \
  / /_/ / (__  ) / / / /_/ /| | / /  __/
  \__,_/_/____/_/ /_/\____/ |_|/_/\___/ 
   __    ___________  __  ______   __________
  / /   / ____/ ___/ / / / /__  / / ____/ __ \
 / /   / /    \__ \ / / / /  / / / /   / / / /
/ /___/ /___ ___/ / /_/ /  / / / /___/ /_/ / 
/_____/\____//____/\____/  /_/  \____/\____/  

EOF
}

# ============================================================================
# CONFIGURACIÓN INICIAL
# ============================================================================

header_info
echo -e "\n Loading..."

# Configuración de colores
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BOLD=$(echo "\033[1m")
BFR="\\r\\033[K"
HOLD=" "
TAB="  "

# Iconos
CM="${TAB}✔️${TAB}${CL}"
CROSS="${TAB}✖️${TAB}${CL}"
INFO="${TAB}💡${TAB}${CL}"
DISKSIZE="${TAB}💾${TAB}${CL}"
CPUCORE="${TAB}🧠${TAB}${CL}"
RAMSIZE="${TAB}🛠️${TAB}${CL}"
CONTAINERID="${TAB}🆔${TAB}${CL}"
HOSTNAME="${TAB}🏠${TAB}${CL}"
BRIDGE="${TAB}🌉${TAB}${CL}"
CREATING="${TAB}🚀${TAB}${CL}"
ADVANCED="${TAB}🧩${TAB}${CL}"
DEFAULT="${TAB}⚙️${TAB}${CL}"

# ============================================================================
# MANEJO DE ERRORES Y SEÑALES
# ============================================================================

set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
trap 'post_update_to_api "failed" "INTERRUPTED"' SIGINT
trap 'post_update_to_api "failed" "TERMINATED"' SIGTERM

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  post_update_to_api "failed" "$command"
  local error_message="${RD}[ERROR]${CL} en línea ${RD}$line_number${CL}: código de salida ${RD}$exit_code${CL}: ejecutando ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

function msg_info() {
  local msg="$1"
  echo -ne "${TAB}${YW}${HOLD}${msg}${HOLD}"
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR}${CM}${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR}${CROSS}${RD}${msg}${CL}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Por favor, ejecuta este script como root."
    echo -e "\nSaliendo..."
    sleep 2
    exit
  fi
}

function pve_check() {
  local PVE_VER
  PVE_VER="$(pveversion | awk -F'/' '{print $2}' | awk -F'-' '{print $1}')"

  if [[ "$PVE_VER" =~ ^8\.([0-9]+) ]]; then
    local MINOR="${BASH_REMATCH[1]}"
    if ((MINOR < 0 || MINOR > 9)); then
      msg_error "Esta versión de Proxmox VE no es compatible."
      msg_error "Soportadas: Proxmox VE versión 8.0 – 8.9"
      exit 1
    fi
    return 0
  fi

  if [[ "$PVE_VER" =~ ^9\.([0-9]+) ]]; then
    local MINOR="${BASH_REMATCH[1]}"
    if ((MINOR > 2)); then
      msg_error "Esta versión de Proxmox VE aún no es compatible."
      msg_error "Soportadas: Proxmox VE versión 9.0 – 9.2"
      exit 1
    fi
    return 0
  fi

  msg_error "Esta versión de Proxmox VE no es compatible."
  msg_error "Versiones soportadas: Proxmox VE 8.0 – 8.9 o 9.0 – 9.2"
  exit 1
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${INFO}${YW}Este script no funcionará con PiMox! \n"
    echo -e "\n ${YW}Visita https://github.com/asylumexp/Proxmox para soporte ARM64. \n"
    echo -e "Saliendo..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "SSH DETECTADO" --yesno "Se recomienda usar la shell de Proxmox en lugar de SSH. ¿Deseas continuar?" 10 62; then
        echo "Continuando..."
      else
        clear
        exit
      fi
    fi
  fi
}

function get_valid_nextid() {
  local try_id
  try_id=$(pvesh get /cluster/nextid)
  while true; do
    if [ -f "/etc/pve/qemu-server/${try_id}.conf" ] || [ -f "/etc/pve/lxc/${try_id}.conf" ]; then
      try_id=$((try_id + 1))
      continue
    fi
    if lvs --noheadings -o lv_name 2>/dev/null | grep -qE "(^|[-_])${try_id}($|[-_])"; then
      try_id=$((try_id + 1))
      continue
    fi
    break
  done
  echo "$try_id"
}

function exit-script() {
  clear
  echo -e "\n${CROSS}${RD}Usuario canceló el script${CL}\n"
  exit
}

# ============================================================================
# CONFIGURACIÓN POR DEFECTO
# ============================================================================

function default_settings() {
  VMID=$(get_valid_nextid)
  VM_NAME="Windows10-LTSC"
  MEMORY=4096
  CORES=2
  DISK_SIZE="60G"
  BRIDGE="vmbr0"
  START_VM="yes"
  METHOD="default"
  
  echo -e "${CONTAINERID}${BOLD}${DGN}ID de Máquina Virtual: ${BGN}${VMID}${CL}"
  echo -e "${HOSTNAME}${BOLD}${DGN}Nombre de la VM: ${BGN}${VM_NAME}${CL}"
  echo -e "${RAMSIZE}${BOLD}${DGN}Memoria RAM: ${BGN}${MEMORY}${CL}"
  echo -e "${CPUCORE}${BOLD}${DGN}Núcleos CPU: ${BGN}${CORES}${CL}"
  echo -e "${DISKSIZE}${BOLD}${DGN}Tamaño de Disco: ${BGN}${DISK_SIZE}${CL}"
  echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}${BRIDGE}${CL}"
  echo -e "${DEFAULT}${BOLD}${DGN}Iniciar VM al completar: ${BGN}sí${CL}"
  echo -e "${CREATING}${BOLD}${DGN}Creando Windows 10 LTSC VM con configuración por defecto${CL}"
}

function advanced_settings() {
  METHOD="advanced"
  [ -z "${VMID:-}" ] && VMID=$(get_valid_nextid)
  
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "ID de Máquina Virtual" 8 58 $VMID --title "ID DE MÁQUINA VIRTUAL" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID=$(get_valid_nextid)
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID ya está en uso${CL}"
        sleep 2
        continue
      fi
      echo -e "${CONTAINERID}${BOLD}${DGN}ID de Máquina Virtual: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Nombre de la Máquina Virtual" 8 58 "Windows10-LTSC" --title "NOMBRE DE LA VM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      VM_NAME="Windows10-LTSC"
    fi
    echo -e "${HOSTNAME}${BOLD}${DGN}Nombre de la VM: ${BGN}$VM_NAME${CL}"
  else
    exit-script
  fi

  if MEMORY=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Asignar Memoria en MiB" 8 58 4096 --title "MEMORIA RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MEMORY ]; then
      MEMORY="4096"
    fi
    echo -e "${RAMSIZE}${BOLD}${DGN}Memoria RAM: ${BGN}$MEMORY${CL}"
  else
    exit-script
  fi

  if CORES=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Asignar Núcleos CPU" 8 58 2 --title "NÚCLEOS CPU" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORES ]; then
      CORES="2"
    fi
    echo -e "${CPUCORE}${BOLD}${DGN}Núcleos CPU: ${BGN}$CORES${CL}"
  else
    exit-script
  fi

  if DISK_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Tamaño de Disco en GiB (ej: 60)" 8 58 "60" --title "TAMAÑO DE DISCO" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    DISK_SIZE=$(echo "$DISK_SIZE" | tr -d ' ')
    if [[ "$DISK_SIZE" =~ ^[0-9]+$ ]]; then
      DISK_SIZE="${DISK_SIZE}G"
    fi
    echo -e "${DISKSIZE}${BOLD}${DGN}Tamaño de Disco: ${BGN}$DISK_SIZE${CL}"
  else
    exit-script
  fi

  if BRIDGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Establecer Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRIDGE ]; then
      BRIDGE="vmbr0"
    fi
    echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRIDGE${CL}"
  else
    exit-script
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "INICIAR MÁQUINA VIRTUAL" --yesno "¿Iniciar VM al completar?" 10 58); then
    START_VM="yes"
    echo -e "${DEFAULT}${BOLD}${DGN}Iniciar VM al completar: ${BGN}sí${CL}"
  else
    START_VM="no"
    echo -e "${DEFAULT}${BOLD}${DGN}Iniciar VM al completar: ${BGN}no${CL}"
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "CONFIGURACIÓN AVANZADA COMPLETA" --yesno "¿Listo para crear Windows 10 LTSC VM?" --no-button Do-Over 10 58); then
    echo -e "${CREATING}${BOLD}${DGN}Creando Windows 10 LTSC VM con configuración avanzada${CL}"
  else
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Usando Configuración Avanzada${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "CONFIGURACIÓN" --yesno "¿Usar Configuración por Defecto?" --no-button Advanced 10 58); then
    header_info
    echo -e "${DEFAULT}${BOLD}${BL}Usando Configuración por Defecto${CL}"
    default_settings
  else
    header_info
    echo -e "${ADVANCED}${BOLD}${RD}Usando Configuración Avanzada${CL}"
    advanced_settings
  fi
}

# ============================================================================
# VERIFICACIONES PRELIMINARES
# ============================================================================

check_root
arch_check
pve_check
ssh_check
start_script

# ============================================================================
# DESCARGAS DE ISOs
# ============================================================================

WIN10_URL="https://go.microsoft.com/fwlink/p/?LinkID=2208844&clcid=0x40a&culture=es-es&country=ES"
WIN10_ISO="/var/lib/vz/template/iso/Windows10.iso"

VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso"
VIRTIO_ISO="/var/lib/vz/template/iso/virtio-win.iso"

msg_info "Creando directorio de ISOs"
mkdir -p /var/lib/vz/template/iso
msg_ok "Directorio creado"

msg_info "Verificando ISOs necesarios"
if [ ! -f "$WIN10_ISO" ]; then
    msg_info "Descargando Windows 10 LTSC..."
    wget --progress=bar:force:noscroll -O "$WIN10_ISO" "$WIN10_URL" 2>&1 | grep -oP '\d+(?=%)' | tail -1 | xargs -I {} sh -c 'echo -ne "\r${BFR}Progreso: {}%"'
    echo -en "\e[1A\e[0K"
    msg_ok "Windows 10 LTSC descargado"
else
    msg_ok "Windows 10 LTSC ya está disponible"
fi

if [ ! -f "$VIRTIO_ISO" ]; then
    msg_info "Descargando VirtIO Drivers..."
    wget --progress=bar:force:noscroll -O "$VIRTIO_ISO" "$VIRTIO_URL" 2>&1 | grep -oP '\d+(?=%)' | tail -1 | xargs -I {} sh -c 'echo -ne "\r${BFR}Progreso: {}%"'
    echo -en "\e[1A\e[0K"
    msg_ok "VirtIO Drivers descargados"
else
    msg_ok "VirtIO ISO ya está disponible"
fi

# ============================================================================
# CREACIÓN DE LA MÁQUINA VIRTUAL
# ============================================================================

msg_info "Creando Máquina Virtual \"$VM_NAME\""
qm create $VMID \
  --name $VM_NAME \
  --memory $MEMORY \
  --cores $CORES \
  --cpu host \
  --machine q35 \
  --bios ovmf \
  --ostype win10 \
  --scsihw virtio-scsi-pci \
  --boot "order=ide2;ide3;scsi0" \
  --agent enabled=1 \
  --net0 virtio,bridge=$BRIDGE \
  --tablet 1 \
  --onboot 0 \
  --localdisk 0 >/dev/null
msg_ok "Máquina Virtual creada"

msg_info "Configurando disco virtual de ${DISK_SIZE}"
qm set $VMID --scsi0 local-lvm:${DISK_SIZE} >/dev/null
msg_ok "Disco configurado"

msg_info "Ajustando configuración de hardware"
qm set $VMID --vga qxl >/dev/null
qm set $VMID --serial0 socket >/dev/null
qm set $VMID --efidisk0 local-lvm:0,efitype=4m,pre-enrolled-keys=1 >/dev/null
msg_ok "Hardware configurado"

msg_info "Montando ISOs (Windows 10 + VirtIO)"
qm set $VMID --ide2 local:iso/$(basename $WIN10_ISO),media=cdrom >/dev/null
qm set $VMID --ide3 local:iso/$(basename $VIRTIO_ISO),media=cdrom >/dev/null
msg_ok "ISOs montadas"

# Agregar descripción
DESCRIPTION=$(
  cat <<EOF
<div align='center'>
  <h2>Windows 10 LTSC VM</h2>
  <p>Máquina Virtual Windows 10 LTSC creada con script de Proxmox Helper</p>
</div>
EOF
)
qm set "$VMID" -description "$DESCRIPTION" >/dev/null

# ============================================================================
# INICIALIZACIÓN DE LA MÁQUINA VIRTUAL
# ============================================================================

if [ "$START_VM" == "yes" ]; then
  msg_info "Iniciando Máquina Virtual"
  qm start $VMID
  msg_ok "Máquina Virtual iniciada"
fi

post_update_to_api "done" "none"

msg_ok "¡Completado Exitosamente!\n"
echo -e "${INFO}Abre la consola de la VM \"${BL}$VM_NAME${CL}\" en la interfaz web de Proxmox para comenzar la instalación de Windows 10 LTSC.\n"
echo -e "${INFO}Los drivers de VirtIO están disponibles en el segundo disco para la instalación.\n"
echo -e "✨ Gracias por usar este instalador ✨\n"
