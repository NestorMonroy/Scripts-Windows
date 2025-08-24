# Instalador VirtualBox v7.1.8

Script de PowerShell para instalar y configurar VirtualBox 7.1.8 con Extension Pack y requisitos completos en sistemas Windows.

## Descripción

Este script automatiza la instalación completa de VirtualBox incluyendo Microsoft Visual C++ 2015-2022 Redistributable, VirtualBox 7.1.8, Extension Pack y la configuración de variables de entorno del sistema para VBoxManage en herramientas de desarrollo como PowerShell, CMD y Git Bash.

## Requisitos del Sistema

- Windows 10/11
- PowerShell 3.0 o superior (recomendado 5.1+)
- Privilegios de administrador
- Conexión a internet para descargas
- Política de ejecución de PowerShell configurada (RemoteSigned o superior)
- Mínimo 4GB de RAM y 2GB de espacio libre en disco

## Características Técnicas

### Arquitectura
- Programación funcional con separación clara de responsabilidades
- Funciones puras para validaciones y transformaciones de datos
- Efectos secundarios aislados en funciones específicas
- Sistema de logging estructurado con rotación automática de archivos
- Configuración centralizada e inmutable

### Validaciones de Seguridad
- Verificación de privilegios de administrador
- Validación de políticas de ejecución de PowerShell
- Comprobación de compatibilidad de versiones
- Detección automática de componentes existentes

### Sistema de Componentes
- **Microsoft Visual C++ 2015-2022**: Requisito fundamental para VirtualBox
- **VirtualBox 7.1.8**: Versión estable recomendada (abril 2025)
- **Extension Pack**: Soporte USB 2.0/3.0, RDP, cifrado de disco
- **PATH Configuration**: Acceso global a VBoxManage

## Instalación y Uso

### Preparación
```powershell
# 1. Abrir PowerShell como Administrador
# Win + X -> Windows PowerShell (Administrador)

# 2. Si es necesario, configurar política de ejecución
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. Navegar al directorio del script
cd C:\ruta\donde\esta\el\script
```

### Ejecución Automática
```powershell
# Proceso completo automatizado
.\install-vbox.ps1 -All

# Solo instalación de componentes
.\install-vbox.ps1 -Install

# Solo configuración de PATH
.\install-vbox.ps1 -Configure

# Solo verificación del sistema
.\install-vbox.ps1 -Verify
```

### Ejecución Interactiva
```powershell
# Inicia menús interactivos
.\install-vbox.ps1
```

## Opciones del Menú

### Menú Principal
1. **Instalar componentes** - Acceso al submenú de instalación granular
2. **Configurar sistema** - Configuración de PATH y variables de entorno
3. **Verificar instalación** - Diagnóstico completo del sistema
4. **Proceso completo** - Instalación y configuración automatizada completa
5. **Salir** - Termina el script

### Submenú de Instalación de Componentes
1. **Instalar Microsoft Visual C++ 2015-2022** - Solo el redistributable
2. **Instalar VirtualBox 7.1.8** - Solo VirtualBox principal
3. **Instalar VirtualBox Extension Pack** - Solo el paquete de extensiones
4. **Instalar todos los componentes** - Instalación completa secuencial
5. **Volver al menú principal** - Navegación hacia atrás

### Submenú de Configuración del Sistema
1. **Configurar PATH para VBoxManage** - Agregue VirtualBox al PATH del sistema
2. **Verificar y reparar PATH existente** - Diagnóstico y corrección automática
3. **Actualizar variables de entorno de sesión** - Refresco de variables actuales
4. **Volver al menú principal** - Navegación hacia atrás

### Submenú de Verificación de Instalación
1. **Reporte completo del sistema** - Estado detallado de todos los componentes
2. **Verificar solo Visual C++** - Diagnóstico específico del redistributable
3. **Verificar solo VirtualBox** - Verificación de instalación y versión
4. **Verificar solo Extension Pack** - Estado del paquete de extensiones
5. **Probar funcionamiento de VBoxManage** - Test funcional con comandos reales
6. **Volver al menú principal** - Navegación hacia atrás

## Componentes Instalados

### Microsoft Visual C++ 2015-2022 Redistributable (x64)
- **Propósito**: Bibliotecas de tiempo de ejecución requeridas por VirtualBox
- **Fuente**: Descarga directa desde Microsoft (aka.ms)
- **Instalación**: Silenciosa sin reinicio requerido
- **Detección**: Verificación via WMI Win32_Product

### VirtualBox 7.1.8
- **Versión**: 7.1.8-164202 (Abril 2025)
- **Fuente**: Sitio oficial de Oracle VirtualBox
- **Instalación**: Modo silencioso con parámetros --silent
- **Ubicación**: `C:\Program Files\Oracle\VirtualBox`
- **Verificación**: Test funcional de VBoxManage --version

### Oracle VirtualBox Extension Pack 7.1.8
- **Características**: USB 2.0/3.0, RDP, cifrado de disco, PXE boot
- **Fuente**: Descarga oficial de Oracle
- **Instalación**: Via VBoxManage extpack install --replace
- **Licencia**: Oracle Personal Use and Evaluation License (PUEL)
- **Verificación**: VBoxManage list extpacks

## Sistema de Logging

### Ubicación de Logs
```
Install-VirtualBox/
├── install-vbox.ps1
└── logs/
    ├── install-vbox-20250823-143022.log
    ├── install-vbox-20250823-141530.log
    └── ...
```

### Características del Logging
- **Formato de archivo**: `install-vbox-YYYYMMDD-HHMMSS.log`
- **Rotación automática**: Mantiene máximo 10 archivos de log
- **Encoding**: UTF8 para compatibilidad internacional
- **Timestamps**: Fecha y hora completa para cada entrada

### Niveles de Log
- **INFO** - Información general del proceso
- **SUCCESS** - Operaciones completadas exitosamente
- **WARN** - Advertencias que no detienen la ejecución
- **ERROR** - Errores que requieren atención inmediata

### Formato de Log
```
[YYYY-MM-DD HH:mm:ss] [LEVEL] Mensaje detallado
```

### Tipos de Registro
- **Step Begin/End** - Inicio y fin de procesos principales
- **Progress** - Acciones específicas dentro de procesos
- **System Info** - Información del entorno y usuario
- **Download Info** - URLs, destinos y tamaños de archivos
- **Error Details** - Detalles completos de excepciones y códigos de salida

## Configuración del Sistema

### Variables de Entorno
El script modifica la variable `PATH` del sistema (Machine scope) agregando:
```
C:\Program Files\Oracle\VirtualBox
```

### Actualización Automática de Sesión
- Refresca variables de entorno en la sesión actual
- Combina PATH de Machine y User scopes
- Verifica funcionamiento inmediato de VBoxManage
- Proporciona instrucciones de fallback para nuevas sesiones

### Detección de Instalaciones Existentes
- Verifica componentes antes de descargar
- Evita reinstalaciones innecesarias
- Valida funcionalidad de instalaciones existentes
- Proporciona opciones de reparación cuando es necesario

## Manejo de Errores

### Validaciones Previas
- Privilegios de administrador obligatorios
- Política de ejecución compatible
- Versión de PowerShell soportada
- Conexión a internet disponible

### Errores Comunes y Soluciones

#### Error de Privilegios
```
ERROR: Este script necesita ejecutarse como Administrador
```
**Solución**:
1. Cerrar PowerShell actual
2. Win + X → Windows PowerShell (Administrador)
3. Navegar al directorio del script
4. Ejecutar nuevamente

#### Error de Política de Ejecución
```
PROBLEMA: Política de Ejecución Restrictiva Detectada
```
**Solución**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Error de Descarga
- Verificación automática de conectividad
- Reintentos con manejo de timeouts
- URLs de respaldo cuando están disponibles
- Limpieza automática de archivos parciales

#### VBoxManage no encontrado después de instalación
- Verificación de instalación de VirtualBox
- Configuración automática de PATH
- Actualización de variables de entorno de sesión
- Instrucciones para reinicio de terminal si es necesario

## Verificación Post-Instalación

### Comandos de Prueba
```powershell
# Verificar VBoxManage
VBoxManage --version

# Listar VMs registradas
VBoxManage list vms

# Verificar Extension Pack
VBoxManage list extpacks
```

### Salida Esperada - VBoxManage
```
7.1.8r164202
```

### Salida Esperada - Extension Pack
```
Extension Packs: 1
Pack no. 0:   Oracle VirtualBox Extension Pack
Version:      7.1.8
Revision:     164202
Edition:      
Description:  Oracle VirtualBox Extension Pack
VRDE Module:  VBoxVRDP
Usable:       true 
Why unusable: 
```

### Solución de Problemas Post-Instalación
1. **VBoxManage no reconocido**:
    - Reiniciar terminal/PowerShell
    - Verificar PATH del sistema
    - Ejecutar script con -Configure

2. **Extension Pack no instalado**:
    - Verificar instalación de VirtualBox primero
    - Ejecutar instalación de Extension Pack individual
    - Comprobar conectividad para descarga

3. **Errores de permisos de VirtualBox**:
    - Ejecutar VirtualBox como administrador una vez
    - Configurar permisos de usuario en Windows
    - Verificar antivirus no bloquee VirtualBox

## Estructura del Código

### Regiones del Script
- `Core Data Types` - Configuración centralizada y constantes
- `Logging Functions` - Sistema de registro con rotación de archivos
- `Validation Functions` - Validaciones puras sin efectos secundarios
- `Download Functions` - Gestión de descargas con manejo de errores
- `Installation Functions` - Lógica de instalación de cada componente
- `Configuration Functions` - Configuración de PATH y variables
- `Verification Functions` - Pruebas funcionales y diagnósticos
- `Menu Systems` - Interfaz de usuario interactiva completa
- `Business Logic` - Orquestación de procesos complejos
- `Main Application` - Punto de entrada y flujo principal

### Principios de Diseño
- **Funciones puras** separadas de efectos secundarios
- **Configuración inmutable** centralizada en hashtables
- **Manejo consistente** de errores con logging estructurado
- **Separación clara** entre UI, lógica y IO
- **Componentes reutilizables** con responsabilidades específicas

## URLs de Descarga

### Microsoft Visual C++ Redistributable
```
https://aka.ms/vs/17/release/vc_redist.x64.exe
```

### VirtualBox 7.1.8
```
https://download.virtualbox.org/virtualbox/7.1.8/VirtualBox-7.1.8-164202-Win.exe
```

### VirtualBox Extension Pack 7.1.8
```
https://download.virtualbox.org/virtualbox/7.1.8/Oracle_VirtualBox_Extension_Pack-7.1.8.vbox-extpack
```

## Compatibilidad

### Sistemas Operativos
- Windows 10 (todas las versiones, build 1809+)
- Windows 11 (todas las versiones)
- Windows Server 2016/2019/2022

### PowerShell
- Windows PowerShell 3.0+ (mínimo funcional)
- Windows PowerShell 5.1 (recomendado para estabilidad)
- PowerShell 7.x (completamente compatible)

### Herramientas de Desarrollo
- Git Bash (acceso completo a VBoxManage)
- Visual Studio Code (integración con terminales)
- Command Prompt (CMD)
- Windows Terminal
- JetBrains IDEs
- Docker Desktop (compatibilidad con VirtualBox)

### Arquitecturas de Hardware
- Intel x64 (Core, Xeon)
- AMD x64 (Ryzen, EPYC)
- Virtualización habilitada en BIOS/UEFI requerida
- Mínimo 4GB RAM (recomendado 8GB+)

## Limitaciones

- Requiere conexión a internet para descargas (aproximadamente 200MB total)
- Necesita privilegios de administrador para todas las operaciones
- No incluye desinstalación automática de componentes
- Extension Pack requiere aceptación de licencia Oracle PUEL
- VirtualBox puede requerir reinicio en algunos sistemas
- No compatible con Hyper-V habilitado simultáneamente

## Información Técnica Adicional

### Dependencias Externas
- Microsoft Visual C++ 2015-2022 Runtime
- Oracle VirtualBox 7.1.8
- Oracle VirtualBox Extension Pack
- Windows Installer service
- .NET Framework 4.5+ (presente en Windows 10/11)

### Modificaciones del Sistema
- Variable de entorno PATH (Machine scope)
- Instalación de archivos en Program Files
- Registro de Windows para VirtualBox
- Servicios de Windows para VirtualBox
- Drivers de red y dispositivos virtuales

### Puertos de Red Utilizados
- **VirtualBox SOAP API**: 18083 (configurable)
- **VirtualBox Web Service**: 18084 (configurable)
- **RDP Server**: 3389+ (rango configurable)
- **Host-Only Networks**: 192.168.56.x/24 (configurable)

### Logs de Seguridad
El script registra información del usuario y sistema para trazabilidad:
- Usuario ejecutor y dominio
- Versión de PowerShell y SO
- Timestamps de todas las operaciones
- Códigos de salida de instaladores
- URLs de descarga y tamaños de archivos
- **No almacena datos sensibles** o credenciales

### Consideraciones de Seguridad
- Descargas desde fuentes oficiales verificadas
- Validación de integridad de archivos descargados
- Ejecución con privilegios mínimos necesarios
- Limpieza automática de archivos temporales
- Logging para auditoría de cambios del sistema

## Soporte y Mantenimiento

### Actualizaciones de Versión
Para actualizar a nuevas versiones de VirtualBox:
1. Modificar `$Script:Config.VirtualBox.Version`
2. Actualizar URLs de descarga correspondientes
3. Probar compatibilidad con Extension Pack
4. Validar funcionamiento en entornos objetivo

### Resolución de Problemas
1. **Revisar logs** en directorio `logs/`
2. **Ejecutar verificación** con `-Verify`
3. **Probar componentes** individualmente desde menús
4. **Verificar prerequisites** del sistema
5. **Consultar documentación** oficial de VirtualBox

### Contacto y Contribuciones
- Documentar issues encontrados con logs completos
- Probar en múltiples versiones de Windows
- Validar compatibilidad con actualizaciones de VirtualBox
- Mantener principios de diseño funcional establecidos