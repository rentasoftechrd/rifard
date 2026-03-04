# Despliega el backend NestJS al VPS de Hostinger por SSH.
# Uso: .\deploy-backend-vps.ps1 -VpsIp "IP" -SshUser "root" [-SshKey "ruta\a\clave"]
# Si no pasas -SshKey, usará contraseña (te la pedirá).
# Si da "permission denied" en /opt, usa: -AppDir "~/rifard-backend"

param(
    [Parameter(Mandatory=$true)][string]$VpsIp,
    [Parameter(Mandatory=$false)][string]$SshUser = "root",
    [Parameter(Mandatory=$false)][string]$SshKey = "",
    [Parameter(Mandatory=$false)][string]$AppDir = "~/rifard-backend"
)

$ErrorActionPreference = "Stop"
$BackendPath = Join-Path $PSScriptRoot "..\apps\backend"

Write-Host "Building backend..." -ForegroundColor Cyan
Push-Location $BackendPath
try {
    npm ci
    npx prisma generate
    npm run build
} finally {
    Pop-Location
}

$distPath = Join-Path $BackendPath "dist"
$prismaPath = Join-Path $BackendPath "prisma"
$pkgJson = Join-Path $BackendPath "package.json"
$pkgLock = Join-Path $BackendPath "package-lock.json"

if (-not (Test-Path $distPath)) {
    Write-Error "dist/ no encontrado. Ejecuta npm run build en apps/backend."
}

$scpArgs = @()
if ($SshKey) { $scpArgs += "-i", $SshKey }
$scpTarget = "${SshUser}@${VpsIp}:${AppDir}"

$sshArgs = @()
if ($SshKey) { $sshArgs += "-i", $SshKey }
$sshTarget = "${SshUser}@${VpsIp}"

# Probar conexión SSH primero (evita errores poco claros más adelante)
Write-Host "Testing SSH connection to $sshTarget ..." -ForegroundColor Cyan
& ssh @sshArgs -o BatchMode=no -o ConnectTimeout=10 $sshTarget "echo OK"
if ($LASTEXITCODE -ne 0) {
    Write-Host "SSH failed. If 'Permission denied': use correct password, or -SshKey with your private key." -ForegroundColor Yellow
    exit 1
}

Write-Host "Creating remote dir and uploading..." -ForegroundColor Cyan
# Crear directorio remoto (en home del usuario para evitar problemas con /opt)
& ssh @sshArgs $sshTarget "mkdir -p $AppDir"

# Subir archivos (requiere scp/rsync)
& scp @scpArgs -r $distPath "${scpTarget}/"
& scp @scpArgs -r $prismaPath "${scpTarget}/"
& scp @scpArgs $pkgJson $pkgLock "${scpTarget}/"

Write-Host "Installing deps and starting on VPS..." -ForegroundColor Cyan
$remoteCmd = "cd $AppDir && npm ci --production && npx prisma generate && (pm2 delete rifard-backend 2>/dev/null; true) && pm2 start dist/main.js --name rifard-backend && pm2 save"
& ssh @sshArgs $sshTarget $remoteCmd

Write-Host "Done. Backend should be running. Check: ssh $sshTarget 'pm2 status'" -ForegroundColor Green
