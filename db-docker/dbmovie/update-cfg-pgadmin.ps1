$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir ".env"
$pgpassFile = Join-Path $scriptDir "pgadmin\pgpass"
$serversFile = Join-Path $scriptDir "pgadmin\servers.json"

$dbName = "dbmovie"
$dbUser = "umovie"
$dbPassword = "password"

if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        if ($trimmed -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim().Trim('"').Trim("'")
            switch ($key) {
                "DB_NAME"     { $dbName = $value }
                "DB_USER"     { $dbUser = $value }
                "DB_PASSWORD" { $dbPassword = $value }
            }
        }
    }
}

# Port reste 5432 : port interne au reseau docker (pgadmin -> db),
# pas DB_PORT qui sert uniquement au mapping vers l'hote.
Set-Content -Path $pgpassFile -Value "db:5432:*:${dbUser}:${dbPassword}"

# PassFile: ".pgpass" fait reference au fichier copie par pgAdmin dans son
# repertoire de stockage via la variable PGPASS_FILE (sans cette cle,
# pgAdmin ignore le pgpass et redemande toujours le mot de passe).
$serversJson = @"
{
  "Servers": {
    "1": {
      "Name": "$dbName",
      "Group": "Servers",
      "Host": "db",
      "Port": 5432,
      "MaintenanceDB": "$dbName",
      "Username": "$dbUser",
      "PassFile": ".pgpass",
      "SSLMode": "prefer"
    }
  }
}
"@
Set-Content -Path $serversFile -Value $serversJson

$envFound = if (Test-Path $envFile) { "oui" } else { "non" }
Write-Host "pgpass + servers.json mis a jour (.env trouve: $envFound) -> db=$dbName user=$dbUser"
