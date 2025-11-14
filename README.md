# Windows 10 LTSC Proxmox Installer

Script automatizado para instalar Windows 10 LTSC en Proxmox VE.

## 📋 Requisitos

- **Proxmox VE** versión 8.0 - 8.9 o 9.0 - 9.2
- Arquitectura **amd64** (x86_64)
- Acceso **root** o **sudo**
- Conexión a Internet
- Almacenamiento disponible (mínimo 100GB recomendado)
- **whiptail** instalado (generalmente viene por defecto)

## 🚀 Instalación Rápida

### Con curl

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/0xLoratadina/pve-windows-installer/main/install-win10-proxmox.sh)"
```

### Con wget

```bash
bash -c "$(wget -q https://raw.githubusercontent.com/0xLoratadina/pve-windows-installer/main/install-win10-proxmox.sh -O -)"
```

## ⚙️ Configuración

### Modo por Defecto (Recomendado para Principiantes)

El script preguntará si deseas usar la configuración por defecto:

- **ID de VM**: Automático (siguiente disponible)
- **Nombre**: Windows10-LTSC
- **RAM**: 4096 MiB (4 GB)
- **CPU Cores**: 2
- **Disco**: 60 GB
- **Bridge**: vmbr0
- **Iniciar VM**: Sí

### Modo Avanzado (Personalización)

Si seleccionas "Advanced", podrás personalizar:

- ID de la máquina virtual
- Nombre de la VM
- Cantidad de RAM
- Cantidad de CPU cores
- Tamaño del disco
- Bridge de red
- Iniciar VM automáticamente o no

## 📝 Pasos de Instalación

1. **Descargas**: El script descargará automáticamente:
   - Windows 10 LTSC ISO (español)
   - VirtIO Drivers ISO

2. **Creación de VM**: Se crea la máquina virtual con la configuración seleccionada

3. **Configuración de Hardware**:
   - Disco SCSI
   - Controlador QXL
   - UEFI/OVMF
   - Agente de Proxmox

4. **Montaje de ISOs**: Se montan los discos de instalación

5. **Inicio de VM**: Se inicia automáticamente (si está habilitado)

## 🎯 Primeros Pasos Después de la Instalación

1. Abre la consola de la VM en la interfaz web de Proxmox
2. Inicia el instalador de Windows 10
3. Durante la instalación, cuando te pida drivers de almacenamiento:
   - Carga el segundo DVD (VirtIO Drivers)
   - Selecciona los drivers SCSI de Red Hat VirtIO

## ✅ Características

- 🛡️ Manejo robusto de errores
- 🔍 Validaciones previas (versión PVE, arquitectura, permisos)
- 🧹 Limpieza automática en caso de fallos
- 📍 Obtención automática de ID disponible
- 🌍 Interfaz completamente en español
- 🔧 Modos de configuración flexible (defecto/avanzado)
- ⚡ Descargas automáticas de ISOs

## 🐛 Solución de Problemas

### Error: "Por favor, ejecuta este script como root"
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/0xLoratadina/pve-windows-installer/main/install-win10-proxmox.sh)"
```

### Error: "Esta versión de Proxmox VE no es compatible"
Verifica tu versión de Proxmox VE:
```bash
pveversion
```
Este script es compatible con Proxmox VE 8.0-8.9 y 9.0-9.2

### Error: "whiptail no encontrado"
Instala whiptail:
```bash
apt-get update && apt-get install -y whiptail
```

### La descarga de ISOs es muy lenta
El script descargará una sola vez y las ISOs se guardarán en `/var/lib/vz/template/iso/`

### Windows no reconoce el disco
Durante la instalación, cuando Windows pida drivers:
1. Carga el DVD con VirtIO Drivers
2. Busca la carpeta `Balloon\w10\amd64` o `vioscsi\w10\amd64`

## 📊 Especificaciones de la VM

| Componente | Configuración |
|-----------|---------------|
| BIOS | OVMF (UEFI) |
| Máquina | Q35 |
| CPU | Host |
| GPU | QXL |
| Network | VirtIO |
| Almacenamiento | VirtIO SCSI |
| Agent | Habilitado |

## 📜 Licencia

MIT License - Copyright (c) 2021-2025 community-scripts ORG

Basado en los estándares de [Proxmox Helper Scripts](https://github.com/community-scripts/ProxmoxVE)

## 🔗 Enlaces Importantes

- **Repositorio**: https://github.com/0xLoratadina/pve-windows-installer
- **Script**: https://github.com/0xLoratadina/pve-windows-installer/blob/main/install-win10-proxmox.sh
- **Issues**: https://github.com/0xLoratadina/pve-windows-installer/issues

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📞 Soporte

- 📧 [Issues en GitHub](https://github.com/0xLoratadina/pve-windows-installer/issues)
- 💬 [Discusiones](https://github.com/0xLoratadina/pve-windows-installer/discussions)
- 🐛 Reporta bugs de forma detallada
- 📍 [Ver código fuente](https://github.com/0xLoratadina/pve-windows-installer/blob/main/install-win10-proxmox.sh)

## 🙏 Agradecimientos

- Comunidad de Proxmox
- Contribuidores

---

**¿Te resultó útil? ⭐ Dale una estrella al repositorio**
