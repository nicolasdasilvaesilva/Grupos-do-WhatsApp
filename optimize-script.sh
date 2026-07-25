#!/bin/bash
# Chatwoot WhatsApp Groups - Performance Optimization Script
# This script detects your server hardware and recommends/applies
# optimal SIDEKIQ_CONCURRENCY and Postgres max_connections values.

set -e

DEBUG="${DEBUG:-false}"

debug() {
  if [[ "$DEBUG" == "true" ]]; then
    echo -e "\033[0;90m[DEBUG] $*\033[0m" >&2
  fi
}

# Run psql against coolify-db, keeping stderr out of stdout.
# When DEBUG=true, stderr is captured and logged via debug().
psql_coolify() {
  local psql_args=("$@")
  local result stderr_tmp
  if [[ "$DEBUG" == "true" ]]; then
    stderr_tmp=$(mktemp)
    result=$(docker exec coolify-db psql -U coolify "${psql_args[@]}" 2>"$stderr_tmp") || true
    local err
    err=$(<"$stderr_tmp")
    rm -f "$stderr_tmp"
    [[ -n "$err" ]] && debug "psql_coolify stderr: $err"
  else
    result=$(docker exec coolify-db psql -U coolify "${psql_args[@]}" 2>/dev/null) || true
  fi
  echo "$result"
}

LOCALE="pt-BR"

# ============================================================
# Translations
# ============================================================

declare -A T

if [[ "$LOCALE" == "pt-BR" || "$LOCALE" == "pt" ]]; then
  T["header_title"]="Chatwoot WhatsApp Groups - Otimização de Performance"
  T["docker_not_installed"]="Docker não está instalado. Por favor, instale o Docker primeiro."
  T["detecting_hardware"]="Detectando hardware do servidor..."
  T["vcpus"]="vCPUs detectados"
  T["ram_mb"]="RAM total (MB)"
  T["recommended_values"]="Valores recomendados"
  T["sidekiq_concurrency"]="SIDEKIQ_CONCURRENCY"
  T["max_connections"]="Postgres max_connections"
  T["current_max_connections"]="max_connections atual"
  T["detecting_platform"]="Detectando plataforma de gerenciamento..."
  T["platform_detected"]="Plataforma detectada"
  T["no_platform_detected"]="Nenhuma plataforma de gerenciamento detectada."
  T["platform_not_supported"]="não é suportado para configuração automática. Aplique as configurações manualmente."
  T["manual_instructions"]="Aplique estas configurações manualmente:"
  T["manual_sidekiq"]="Adicione ao seu arquivo .env ou variáveis de ambiente do Chatwoot:"
  T["manual_postgres"]="Para o Postgres max_connections, execute no container Postgres:"
  T["manual_restart"]="Depois reinicie seus serviços Chatwoot."
  T["looking_for_chatwoot"]="Procurando serviços Chatwoot..."
  T["no_chatwoot_found"]="Nenhum serviço Chatwoot encontrado."
  T["found_chatwoot"]="Serviços Chatwoot encontrados:"
  T["select_service"]="Selecione o serviço para otimizar"
  T["cancel_return"]="Cancelar e sair"
  T["invalid_selection"]="Seleção inválida"
  T["applying_settings"]="Aplicando configurações..."
  T["env_updated"]="Variável de ambiente atualizada"
  T["env_already_set"]="Variável já configurada"
  T["restart_required"]="Reinicie o serviço para aplicar as alterações."
  T["restart_now"]="Reiniciar o serviço agora?"
  T["restarting"]="Reiniciando serviço..."
  T["restart_success"]="Serviço reiniciado com sucesso!"
  T["restart_failed"]="Falha ao reiniciar o serviço."
  T["done"]="Otimização concluída!"
  T["cancelled"]="Cancelado."
  T["whatsapp_groups_enabled"]="BAILEYS_WHATSAPP_GROUPS_ENABLED será configurado como true"
  T["confirm_apply"]="Aplicar estas configurações?"
  T["postgres_note"]="Nota: max_connections do Postgres requer reinicialização do container Postgres para aplicar."
  T["postgres_applying"]="Aplicando max_connections no Postgres..."
  T["postgres_applied"]="max_connections atualizado para"
  T["postgres_apply_failed"]="Falha ao aplicar max_connections. Aplique manualmente."
  T["postgres_restart_required"]="Reinicie o container Postgres para aplicar a alteração."
  T["postgres_default_warning"]="max_connections está no valor padrão (100). Recomendamos aumentar."
  T["postgres_ok"]="max_connections já está acima do padrão"
  T["checking_postgres"]="Verificando Postgres max_connections..."
  T["postgres_not_found"]="Container Postgres não encontrado. Ajuste max_connections manualmente."
  T["summary_title"]="Resumo das alterações"
  T["compose_injected"]="Variável adicionada ao docker-compose para"
  T["compose_already_set"]="Variável já existe no docker-compose para"
  T["compose_section_not_found"]="Seção environment não encontrada no docker-compose para"
  T["coolify_link"]="Painel Coolify"
  T["sidekiq_concurrency_target"]="SIDEKIQ_CONCURRENCY será configurado no sidekiq"
else
  T["header_title"]="Chatwoot WhatsApp Groups - Performance Optimization"
  T["docker_not_installed"]="Docker is not installed. Please install Docker first."
  T["detecting_hardware"]="Detecting server hardware..."
  T["vcpus"]="Detected vCPUs"
  T["ram_mb"]="Total RAM (MB)"
  T["recommended_values"]="Recommended values"
  T["sidekiq_concurrency"]="SIDEKIQ_CONCURRENCY"
  T["max_connections"]="Postgres max_connections"
  T["current_max_connections"]="Current max_connections"
  T["detecting_platform"]="Detecting management platform..."
  T["platform_detected"]="Platform detected"
  T["no_platform_detected"]="No management platform detected."
  T["platform_not_supported"]="is not supported for automatic configuration. Apply settings manually."
  T["manual_instructions"]="Apply these settings manually:"
  T["manual_sidekiq"]="Add to your Chatwoot .env file or environment variables:"
  T["manual_postgres"]="For Postgres max_connections, run inside the Postgres container:"
  T["manual_restart"]="Then restart your Chatwoot services."
  T["looking_for_chatwoot"]="Looking for Chatwoot services..."
  T["no_chatwoot_found"]="No Chatwoot services found."
  T["found_chatwoot"]="Found Chatwoot services:"
  T["select_service"]="Select service to optimize"
  T["cancel_return"]="Cancel and exit"
  T["invalid_selection"]="Invalid selection"
  T["applying_settings"]="Applying settings..."
  T["env_updated"]="Environment variable updated"
  T["env_already_set"]="Variable already set"
  T["restart_required"]="Restart the service to apply changes."
  T["restart_now"]="Restart service now?"
  T["restarting"]="Restarting service..."
  T["restart_success"]="Service restarted successfully!"
  T["restart_failed"]="Failed to restart service."
  T["done"]="Optimization complete!"
  T["cancelled"]="Cancelled."
  T["whatsapp_groups_enabled"]="BAILEYS_WHATSAPP_GROUPS_ENABLED will be set to true"
  T["confirm_apply"]="Apply these settings?"
  T["postgres_note"]="Note: Postgres max_connections requires a Postgres container restart to take effect."
  T["postgres_applying"]="Applying max_connections to Postgres..."
  T["postgres_applied"]="max_connections updated to"
  T["postgres_apply_failed"]="Failed to apply max_connections. Apply manually."
  T["postgres_restart_required"]="Restart the Postgres container to apply the change."
  T["postgres_default_warning"]="max_connections is at default value (100). We recommend increasing it."
  T["postgres_ok"]="max_connections is already above default"
  T["checking_postgres"]="Checking Postgres max_connections..."
  T["postgres_not_found"]="Postgres container not found. Adjust max_connections manually."
  T["summary_title"]="Changes summary"
  T["compose_injected"]="Variable added to docker-compose for"
  T["compose_already_set"]="Variable already in docker-compose for"
  T["compose_section_not_found"]="Environment section not found in docker-compose for"
  T["coolify_link"]="Coolify dashboard"
  T["sidekiq_concurrency_target"]="SIDEKIQ_CONCURRENCY will be set on sidekiq"
fi

# ============================================================
# Colors and UI
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

print_header() {
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC}   ${BOLD}${T[header_title]}${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_success() {
  echo -e "${GREEN}✔${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}!${NC} $1"
}

print_info() {
  echo -e "${CYAN}→${NC} $1"
}

print_detail() {
  echo -e "  ${YELLOW}│${NC} $1"
}

# ============================================================
# Hardware Detection
# ============================================================

detect_hardware() {
  VCPUS=$(nproc 2>/dev/null || echo 1)
  RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo 1024)
}

calculate_sidekiq_concurrency() {
  local ram_mb=$1

  # Baseline: 25 for 8 GB (8192 MB), scale linearly, round up to nearest 5
  local result=$(( ram_mb * 25 / 8192 ))
  result=$(( ((result + 4) / 5) * 5 ))

  # Minimum 5 (respect low-capacity hosts), maximum 200
  if [[ $result -lt 5 ]]; then
    result=5
  elif [[ $result -gt 200 ]]; then
    result=200
  fi

  echo "$result"
}

calculate_max_connections() {
  local sidekiq_val=$1

  # 1.5x the SIDEKIQ_CONCURRENCY value, rounded up to nearest 5
  local result=$(( sidekiq_val * 3 / 2 ))
  result=$(( ((result + 4) / 5) * 5 ))

  # Minimum 100, maximum 500
  if [[ $result -lt 100 ]]; then
    result=100
  elif [[ $result -gt 500 ]]; then
    result=500
  fi

  echo "$result"
}

# ============================================================
# Platform Detection
# ============================================================

PLATFORM=""
PLATFORM_NAME=""

detect_platform() {
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^coolify$"; then
    PLATFORM="coolify"
    PLATFORM_NAME="Coolify"
    return 0
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "easypanel"; then
    PLATFORM="easypanel"
    PLATFORM_NAME="Easypanel"
    return 0
  fi

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "portainer"; then
    PLATFORM="portainer"
    PLATFORM_NAME="Portainer"
    return 0
  fi

  return 1
}


# ============================================================
# Postgres Detection
# ============================================================

find_postgres_container() {
  # If a container name is passed, use it directly
  if [[ -n "${1:-}" ]]; then
    echo "$1"
    return
  fi
  # Otherwise, search for any postgres container
  docker ps --format '{{.Names}}' 2>/dev/null | grep -iE "postgres|pg|pgsql" | head -1
}

pg_exec_sql() {
  local pg_container="$1"
  local sql="$2"

  debug "pg_exec_sql: container=$pg_container sql='$sql'"

  # Detect the actual postgres user from the container env
  local pg_user pg_db
  pg_user=$(docker exec "$pg_container" printenv POSTGRES_USER 2>/dev/null || true)
  pg_db=$(docker exec "$pg_container" printenv POSTGRES_DB 2>/dev/null || true)
  # Fallback chain: POSTGRES_USER → postgres → chatwoot
  local users_to_try=()
  [[ -n "$pg_user" ]] && users_to_try+=("$pg_user")
  users_to_try+=("postgres" "chatwoot")
  [[ -z "$pg_db" ]] && pg_db="postgres"

  debug "pg_exec_sql: detected pg_user='$pg_user' pg_db='$pg_db'"

  local result=""
  for user in "${users_to_try[@]}"; do
    if [[ "$DEBUG" == "true" ]]; then
      local stderr_tmp
      stderr_tmp=$(mktemp)
      result=$(docker exec "$pg_container" psql -U "$user" -d "$pg_db" -t -A -c "$sql" 2>"$stderr_tmp") || true
      local err
      err=$(<"$stderr_tmp")
      rm -f "$stderr_tmp"
      [[ -n "$err" ]] && debug "pg_exec_sql ($user) stderr: $err"
    else
      result=$(docker exec "$pg_container" psql -U "$user" -d "$pg_db" -t -A -c "$sql" 2>/dev/null) || true
    fi
    debug "pg_exec_sql: user=$user result='$result'"
    [[ -n "$result" ]] && break
  done
  echo "$result"
}

check_postgres_max_connections() {
  local pg_container
  pg_container=$(find_postgres_container "${1:-}")

  debug "check_postgres_max_connections: container='$pg_container'"
  if [[ -z "$pg_container" ]]; then
    echo "not_found"
    return
  fi

  local current
  current=$(pg_exec_sql "$pg_container" "SHOW max_connections;")

  debug "check_postgres_max_connections: current='$current'"
  if [[ -z "$current" ]]; then
    echo "not_found"
  else
    echo "$current"
  fi
}

apply_postgres_max_connections() {
  local pg_container="$1"
  local max_conn_val="$2"

  debug "apply_postgres_max_connections: container=$pg_container value=$max_conn_val"
  local result
  result=$(pg_exec_sql "$pg_container" "ALTER SYSTEM SET max_connections TO '$max_conn_val';")
  debug "apply_postgres_max_connections: result='$result'"

  if [[ "$result" == *"ALTER SYSTEM"* ]]; then
    return 0
  else
    return 1
  fi
}

# ============================================================
# Coolify Functions
# ============================================================

coolify_list_chatwoot_services() {
  debug "coolify_list_chatwoot_services: querying coolify-db"
  local result
  result=$(psql_coolify -t -A -F '|' -c "
    SELECT
      s.uuid,
      COALESCE(p.name, '') || '/' || s.name,
      COALESCE(p.uuid, ''),
      COALESCE(e.uuid, '')
    FROM services s
    LEFT JOIN environments e ON e.id = s.environment_id
    LEFT JOIN projects p ON p.id = e.project_id
    WHERE s.docker_compose_raw ILIKE '%chatwoot%';
  ")
  debug "coolify_list_chatwoot_services: result='$result'"
  echo "$result"
}

coolify_get_service_env() {
  local service_uuid="$1"
  local var_name="$2"

  debug "coolify_get_service_env: uuid=$service_uuid var=$var_name"
  local result
  result=$(docker exec coolify php artisan tinker --execute="
    \$service = App\Models\Service::where('uuid', '$service_uuid')->first();
    if (\$service) {
      \$env = \$service->environment_variables()->where('key', '$var_name')->first();
      echo \$env ? \$env->value : '';
    }
  " 2>/dev/null | tail -1) || true
  debug "coolify_get_service_env: result='$result'"
  echo "$result"
}

coolify_set_service_env() {
  local service_uuid="$1"
  local var_name="$2"
  local var_value="$3"

  debug "coolify_set_service_env: uuid=$service_uuid var=$var_name value=$var_value"
  local result
  result=$(docker exec coolify php artisan tinker --execute="
    \$service = App\Models\Service::where('uuid', '$service_uuid')->first();
    if (!\$service) { echo 'NOT_FOUND'; return; }
    \$env = \$service->environment_variables()->where('key', '$var_name')->first();
    if (\$env) {
      \$env->update(['value' => '$var_value']);
      echo 'UPDATED';
    } else {
      \$service->environment_variables()->create([
        'key' => '$var_name',
        'value' => '$var_value',
        'is_preview' => false,
        'is_literal' => true,
      ]);
      echo 'CREATED';
    }
  " 2>/dev/null | tail -1) || true
  debug "coolify_set_service_env: result='$result'"
  echo "$result"
}

coolify_restart_service() {
  local service_uuid="$1"

  debug "coolify_restart_service: uuid=$service_uuid"
  local result
  if [[ "$DEBUG" == "true" ]]; then
    local stderr_tmp
    stderr_tmp=$(mktemp)
    result=$(docker exec coolify php artisan tinker --execute="
      \$service = App\Models\Service::where('uuid', '$service_uuid')->first();
      if (\$service) {
        \$service->parse();
        (new App\Actions\Service\StartService)->handle(\$service);
        echo 'OK';
      } else {
        echo 'NOT_FOUND';
      }
    " 2>"$stderr_tmp") || true
    local err
    err=$(<"$stderr_tmp")
    rm -f "$stderr_tmp"
    [[ -n "$err" ]] && debug "coolify_restart_service stderr: $err"
  else
    result=$(docker exec coolify php artisan tinker --execute="
      \$service = App\Models\Service::where('uuid', '$service_uuid')->first();
      if (\$service) {
        \$service->parse();
        (new App\Actions\Service\StartService)->handle(\$service);
        echo 'OK';
      } else {
        echo 'NOT_FOUND';
      }
    " 2>/dev/null) || true
  fi
  debug "coolify_restart_service: full output='$result'"
  echo "$result" | tail -1
}

coolify_find_postgres_container() {
  local service_uuid="$1"

  debug "coolify_find_postgres_container: looking for pg container in service $service_uuid"

  # List all containers matching this service UUID
  local all_containers
  all_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i "$service_uuid" || true)
  debug "coolify_find_postgres_container: containers matching uuid: $(echo "$all_containers" | tr '\n' ', ')"

  # Find postgres container by name pattern
  local pg_container
  pg_container=$(echo "$all_containers" | grep -iE "postgres|pg|pgsql" | head -1 || true)

  if [[ -n "$pg_container" ]]; then
    debug "coolify_find_postgres_container: found by name pattern: $pg_container"
    echo "$pg_container"
    return 0
  fi

  # Fallback: parse docker_compose_raw to find the postgres service name
  debug "coolify_find_postgres_container: no match by pattern, trying docker_compose_raw fallback"
  local compose_raw
  compose_raw=$(docker exec coolify-db psql -U coolify -t -A -c "
    SELECT docker_compose_raw FROM services WHERE uuid = '$service_uuid';
  " 2>/dev/null || true)
  debug "coolify_find_postgres_container: docker_compose_raw length=$(echo "$compose_raw" | wc -c)"

  local pg_service_name
  pg_service_name=$(echo "$compose_raw" | grep -iE '^\s*(postgres|pg|pgsql)' | head -1 | sed 's/:.*//' | xargs || true)
  debug "coolify_find_postgres_container: parsed pg service name='$pg_service_name'"

  if [[ -n "$pg_service_name" ]]; then
    pg_container=$(echo "$all_containers" | grep -i "$pg_service_name" | head -1 || true)
    debug "coolify_find_postgres_container: match by service name: '$pg_container'"

    if [[ -n "$pg_container" ]]; then
      echo "$pg_container"
      return 0
    fi
  fi

  debug "coolify_find_postgres_container: not found"
  return 1
}

coolify_get_fqdn() {
  local result
  result=$(psql_coolify -t -A -c "SELECT fqdn FROM instance_settings LIMIT 1;")
  debug "coolify_get_fqdn: result='$result'"
  echo "$result"
}

coolify_inject_compose_env() {
  local service_uuid="$1"
  local sub_service="$2"
  local var_name="$3"

  debug "coolify_inject_compose_env: uuid=$service_uuid sub=$sub_service var=$var_name"
  local result
  result=$(docker exec coolify php artisan tinker --execute="
    \$service = App\Models\Service::where('uuid', '$service_uuid')->first();
    if (!\$service) { echo 'NOT_FOUND'; return; }
    \$yaml = \$service->docker_compose_raw;
    \$varLine = \"      - '${var_name}=\\\${${var_name}}'\";
    \$lines = explode(\"\\n\", \$yaml);
    \$inTarget = false;
    \$inEnv = false;
    \$insertAt = -1;
    foreach (\$lines as \$i => \$line) {
      if (preg_match('/^  (\\w[\\w-]*):/', \$line, \$m)) {
        if (\$inTarget && \$insertAt >= 0) break;
        \$inTarget = (\$m[1] === '$sub_service');
        \$inEnv = false;
      }
      if (\$inTarget && preg_match('/^    \\w/', \$line)) {
        if (trim(\$line) === 'environment:') {
          \$inEnv = true;
        } else {
          if (\$inEnv && \$insertAt >= 0) break;
          \$inEnv = false;
        }
      }
      if (\$inTarget && \$inEnv && strpos(ltrim(\$line), \"- \") === 0) {
        if (str_contains(\$line, \"${var_name}\")) {
          echo 'ALREADY_EXISTS';
          return;
        }
        \$insertAt = \$i;
      }
    }
    if (\$insertAt >= 0) {
      array_splice(\$lines, \$insertAt + 1, 0, [\$varLine]);
      \$service->docker_compose_raw = implode(\"\\n\", \$lines);
      \$service->save();
      echo 'INJECTED';
    } else {
      echo 'SECTION_NOT_FOUND';
    }
  " 2>/dev/null | tail -1) || true
  debug "coolify_inject_compose_env: result='$result'"
  echo "$result"
}

# ============================================================
# Manual Instructions (no platform detected)
# ============================================================

show_manual_instructions() {
  local sidekiq_val=$1
  local max_conn_val=$2

  echo -e "${BOLD}${T[manual_instructions]}${NC}"
  echo ""

  echo -e "${T[manual_sidekiq]}"
  echo ""
  echo -e "  ${CYAN}BAILEYS_WHATSAPP_GROUPS_ENABLED=true${NC}"
  echo -e "  ${CYAN}SIDEKIQ_CONCURRENCY=${sidekiq_val}${NC}"
  echo ""

  echo -e "${T[manual_postgres]}"
  echo ""
  echo -e "  ${CYAN}ALTER SYSTEM SET max_connections TO '${max_conn_val}';${NC}"
  echo ""

  echo -e "${T[postgres_restart_required]}"
  echo ""

  echo -e "${T[manual_restart]}"
  echo ""
}

# ============================================================
# Coolify Apply
# ============================================================

apply_coolify() {
  local sidekiq_val=$1
  local max_conn_val=$2

  print_info "${T[looking_for_chatwoot]}"
  echo ""

  local coolify_fqdn
  coolify_fqdn=$(coolify_get_fqdn)
  debug "apply_coolify: fqdn='$coolify_fqdn'"

  local services
  services=$(coolify_list_chatwoot_services)

  if [[ -z "$services" ]]; then
    print_warning "${T[no_chatwoot_found]}"
    return
  fi

  echo -e "${BOLD}${T[found_chatwoot]}${NC}"
  echo ""

  local i=1
  local service_list=()
  while IFS='|' read -r uuid name project_uuid env_uuid; do
    [[ -z "$uuid" ]] && continue
    service_list+=("$uuid|$name")
    echo -e "  ${CYAN}$i)${NC} $name"
    if [[ -n "$coolify_fqdn" && -n "$project_uuid" && -n "$env_uuid" ]]; then
      echo -e "     ${GRAY}${coolify_fqdn}/project/${project_uuid}/environment/${env_uuid}/service/${uuid}${NC}"
    fi
    ((i++))
  done <<< "$services"

  echo ""
  echo -e "  ${CYAN}q)${NC} ${T[cancel_return]}"
  echo ""

  read -rp "${T[select_service]} (1-$((i - 1)) or q): " choice < /dev/tty

  if [[ "$choice" == "q" ]]; then
    print_info "${T[cancelled]}"
    return
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice >= i)); then
    print_error "${T[invalid_selection]}"
    return
  fi

  local selected="${service_list[$((choice - 1))]}"
  local uuid name
  uuid=$(echo "$selected" | cut -d'|' -f1)
  name=$(echo "$selected" | cut -d'|' -f2)

  # Find Postgres container in the same Coolify service stack
  local pg_container=""
  pg_container=$(coolify_find_postgres_container "$uuid" 2>/dev/null || echo "")

  echo ""
  echo -e "${BOLD}${T[summary_title]}:${NC}"
  print_detail "${T[whatsapp_groups_enabled]} (chatwoot + sidekiq)"
  print_detail "${T[sidekiq_concurrency_target]}: $sidekiq_val"
  if [[ -n "$pg_container" ]]; then
    print_detail "${T[max_connections]}: $max_conn_val (ALTER SYSTEM SET)"
  else
    print_detail "${T[postgres_note]}"
  fi
  echo ""

  read -rp "${T[confirm_apply]} (y/N): " confirm < /dev/tty
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    print_info "${T[cancelled]}"
    return
  fi

  echo ""
  print_info "${T[applying_settings]}"

  # Set env vars via Coolify tinker (handles encryption)
  debug "apply_coolify: setting BAILEYS_WHATSAPP_GROUPS_ENABLED for uuid=$uuid"
  coolify_set_service_env "$uuid" "BAILEYS_WHATSAPP_GROUPS_ENABLED" "true"
  print_success "${T[env_updated]}: BAILEYS_WHATSAPP_GROUPS_ENABLED=true"

  debug "apply_coolify: setting SIDEKIQ_CONCURRENCY=$sidekiq_val for uuid=$uuid"
  coolify_set_service_env "$uuid" "SIDEKIQ_CONCURRENCY" "$sidekiq_val"
  print_success "${T[env_updated]}: SIDEKIQ_CONCURRENCY=$sidekiq_val"

  # Inject BAILEYS_WHATSAPP_GROUPS_ENABLED into chatwoot + sidekiq in docker_compose_raw
  echo ""
  for sub in chatwoot rails sidekiq; do
    debug "apply_coolify: injecting BAILEYS_WHATSAPP_GROUPS_ENABLED into $sub compose"
    local inject_result
    inject_result=$(coolify_inject_compose_env "$uuid" "$sub" "BAILEYS_WHATSAPP_GROUPS_ENABLED")
    case "$inject_result" in
      INJECTED) print_success "${T[compose_injected]} $sub: BAILEYS_WHATSAPP_GROUPS_ENABLED" ;;
      ALREADY_EXISTS) print_success "${T[compose_already_set]} $sub: BAILEYS_WHATSAPP_GROUPS_ENABLED" ;;
      *) print_warning "${T[compose_section_not_found]} $sub" ;;
    esac
  done

  # Inject SIDEKIQ_CONCURRENCY only into sidekiq in docker_compose_raw
  debug "apply_coolify: injecting SIDEKIQ_CONCURRENCY into sidekiq compose"
  local inject_sidekiq
  inject_sidekiq=$(coolify_inject_compose_env "$uuid" "sidekiq" "SIDEKIQ_CONCURRENCY")
  case "$inject_sidekiq" in
    INJECTED) print_success "${T[compose_injected]} sidekiq: SIDEKIQ_CONCURRENCY" ;;
    ALREADY_EXISTS) print_success "${T[compose_already_set]} sidekiq: SIDEKIQ_CONCURRENCY" ;;
    *) print_warning "${T[compose_section_not_found]} sidekiq" ;;
  esac

  # Apply max_connections via ALTER SYSTEM SET
  debug "apply_coolify: pg_container='$pg_container'"
  echo ""
  if [[ -n "$pg_container" ]]; then
    print_info "${T[postgres_applying]}"
    if apply_postgres_max_connections "$pg_container" "$max_conn_val"; then
      print_success "${T[postgres_applied]} $max_conn_val"
      print_warning "${T[postgres_restart_required]}"
    else
      print_error "${T[postgres_apply_failed]}"
      echo -e "  ${CYAN}ALTER SYSTEM SET max_connections TO '${max_conn_val}';${NC}"
    fi
  else
    print_warning "${T[postgres_not_found]}"
    echo -e "  ${CYAN}ALTER SYSTEM SET max_connections TO '${max_conn_val}';${NC}"
  fi
  echo ""

  read -rp "${T[restart_now]} (y/N): " restart_confirm < /dev/tty
  if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
    print_info "${T[restarting]}"
    local result
    result=$(coolify_restart_service "$uuid")
    if [[ "$result" == "OK" ]]; then
      print_success "${T[restart_success]}"
    else
      print_error "${T[restart_failed]}"
    fi
  else
    print_warning "${T[restart_required]}"
  fi

  echo ""
  print_success "${T[done]}"
}

# ============================================================
# Main
# ============================================================

main() {
  print_header

  if ! command -v docker &>/dev/null; then
    print_error "${T[docker_not_installed]}"
    exit 1
  fi

  # Detect hardware
  print_info "${T[detecting_hardware]}"
  detect_hardware
  echo ""
  print_detail "${T[vcpus]}: ${BOLD}$VCPUS${NC}"
  print_detail "${T[ram_mb]}: ${BOLD}$RAM_MB${NC}"
  echo ""

  # Calculate recommendations
  local sidekiq_val
  sidekiq_val=$(calculate_sidekiq_concurrency "$RAM_MB")
  local max_conn_val
  max_conn_val=$(calculate_max_connections "$sidekiq_val")

  echo -e "${BOLD}${T[recommended_values]}:${NC}"
  print_detail "${T[sidekiq_concurrency]}: ${GREEN}$sidekiq_val${NC}"
  print_detail "${T[max_connections]}: ${GREEN}$max_conn_val${NC}"
  echo ""

  # Check current Postgres max_connections
  print_info "${T[checking_postgres]}"
  local current_max_conn
  current_max_conn=$(check_postgres_max_connections)

  if [[ "$current_max_conn" == "not_found" ]]; then
    print_warning "${T[postgres_not_found]}"
  elif [[ "$current_max_conn" -lt "$max_conn_val" ]]; then
    print_warning "${T[postgres_default_warning]}"
    print_detail "${T[current_max_connections]}: ${YELLOW}$current_max_conn${NC}"
  else
    print_success "${T[postgres_ok]}: $current_max_conn"
  fi
  echo ""

  # Detect platform
  print_info "${T[detecting_platform]}"

  if detect_platform; then
    print_success "${T[platform_detected]}: ${BOLD}$PLATFORM_NAME${NC}"
    echo ""

    case "$PLATFORM" in
      coolify)
        apply_coolify "$sidekiq_val" "$max_conn_val"
        ;;
      *)
        print_warning "${PLATFORM_NAME}: ${T[platform_not_supported]}"
        echo ""
        show_manual_instructions "$sidekiq_val" "$max_conn_val"
        ;;
    esac
  else
    print_warning "${T[no_platform_detected]}"
    echo ""
    show_manual_instructions "$sidekiq_val" "$max_conn_val"
  fi
}

main
