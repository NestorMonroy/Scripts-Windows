# Instalador GnuWin32 Make

Script de PowerShell para instalar y configurar GnuWin32 Make en sistemas Windows.

## Descripción

Este script automatiza la instalación de GnuWin32 Make utilizando winget y configura las variables de entorno del sistema para su uso en herramientas de desarrollo como Git Bash, PowerShell y CMD.

## Requisitos del Sistema

- Windows 10/11
- PowerShell 3.0 o superior (recomendado 5.1+)
- Privilegios de administrador
- winget (Windows Package Manager)
- Política de ejecución de PowerShell configurada (RemoteSigned o superior)

## Características Técnicas

### Arquitectura
- Programación funcional con separación clara de responsabilidades
- Funciones puras para validaciones y transformaciones de datos
- Efectos secundarios aislados en funciones específicas
- Sistema de logging estructurado con niveles

### Validaciones de Seguridad
- Verificación de privilegios de administrador
- Validación de políticas de ejecución de PowerShell
- Comprobación de compatibilidad de versiones

### Funcionalidades de Búsqueda
- Búsqueda en ubicaciones comunes predefinidas
- Búsqueda exhaustiva en todo el sistema (opcional)
- Configuración manual de rutas
- Detección automática de instalaciones existentes

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

### Ejecución
```powershell
.\InstalarMake.ps1
```

## Opciones del Menú

### Menú Principal
1. **Instalar GnuWin32 Make** - Solo ejecuta la instalación via winget
2. **Configurar PATH del sistema** - Configura variables de entorno con submenu
3. **Verificar instalación actual** - Muestra estado completo del sistema
4. **Proceso completo** - Instalación y configuración automática
5. **Salir** - Termina el script

### Submenú de Configuración de PATH
1. **Búsqueda común** - Verifica ubicaciones estándar de instalación
2. **Búsqueda completa** - Búsqueda común + exploración de todo el sistema
3. **Ruta manual** - Permite especificar ruta personalizada
4. **Volver** - Regresa al menú principal

## Ubicaciones de Búsqueda

### Rutas Comunes Verificadas
- `C:\Program Files (x86)\GnuWin32\bin`
- `C:\Program Files\GnuWin32\bin`
- `C:\GnuWin32\bin`

### Búsqueda de Sistema
- Exploración recursiva en unidad C:
- Filtrado por archivos make.exe relacionados con GnuWin32
- Validación de ejecutabilidad antes de configurar PATH

## Sistema de Logging

### Niveles de Log
- **INFO** - Información general del proceso
- **SUCCESS** - Operaciones completadas exitosamente
- **WARN** - Advertencias que no detienen la ejecución
- **ERROR** - Errores que requieren atención

### Formato de Log
```
[HH:mm:ss] [LEVEL] Mensaje
```

### Tipos de Registro
- **Step Begin/End** - Inicio y fin de procesos principales
- **Progress** - Acciones específicas dentro de procesos
- **System Info** - Información del entorno y usuario
- **Error Details** - Detalles completos de excepciones

## Configuración del Sistema

### Variables de Entorno
El script modifica la variable `PATH` del sistema (Machine scope) agregando la ruta de instalación de GnuWin32 Make.

### Actualización Automática
- Refresca variables de entorno en la sesión actual
- Verifica funcionamiento inmediato del comando make
- Proporciona instrucciones de fallback si es necesario

## Manejo de Errores

### Validaciones Previas
- Privilegios de administrador requeridos
- Política de ejecución compatible
- Versión de PowerShell soportada

### Errores Comunes y Soluciones

#### Error de Privilegios
```
ERROR: Este script necesita ejecutarse como Administrador
```
**Solución**: Ejecutar PowerShell como administrador

#### Error de Política de Ejecución
```
PROBLEMA: Política de Ejecución Restrictiva Detectada
```
**Solución**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Make no encontrado después de instalación
- El script buscará en ubicaciones alternativas
- Opción de búsqueda manual disponible
- Instrucciones para configuración manual

## Verificación Post-Instalación

### Comando de Prueba
```bash
# En Git Bash o PowerShell
make --version
```

### Salida Esperada
```
GNU Make 3.81
Copyright (C) 2006  Free Software Foundation, Inc.
```

### Solución de Problemas
Si make no funciona después de la instalación:
1. Cerrar todas las ventanas de terminal
2. Abrir Git Bash nuevamente
3. Verificar con `make --version`

## Estructura del Código

### Regiones del Script
- `Core Data Types` - Configuración y constantes
- `Logging Functions` - Sistema de registro
- `Validation Functions` - Validaciones puras
- `Search Operations` - Funciones de búsqueda
- `Business Logic` - Lógica de negocio con IO
- `Menu Systems` - Interfaz de usuario
- `Main Application` - Punto de entrada

### Principios de Diseño
- Funciones puras separadas de efectos secundarios
- Configuración centralizada e inmutable
- Manejo consistente de errores
- Logging estratégico sin ruido

## Compatibilidad

### Sistemas Operativos
- Windows 10 (todas las versiones)
- Windows 11 (todas las versiones)
- Windows Server 2016+

### PowerShell
- Windows PowerShell 3.0+ (mínimo)
- Windows PowerShell 5.1 (recomendado)
- PowerShell 7.x (compatible)

### Herramientas de Desarrollo
- Git Bash
- Visual Studio Code
- Command Prompt
- Windows Terminal

## Limitaciones

- Requiere conexión a internet para descargas via winget
- Necesita privilegios de administrador para modificar PATH del sistema
- La búsqueda de sistema puede ser lenta en discos grandes
- No incluye desinstalación automática

## Información Técnica Adicional

### Dependencias Externas
- winget (Windows Package Manager)
- GnuWin32 Make package en repositorios de winget

### Modificaciones del Sistema
- Variable de entorno PATH (Machine scope)
- Instalación de archivos en Program Files

### Logs de Seguridad
El script registra información del usuario y sistema para trazabilidad sin almacenar datos sensibles.