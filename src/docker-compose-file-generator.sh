#!/bin/bash
set -e

source ./commons.sh
source ./../variables.env

build_dependencies() {
  local values_file=$1

  local deps_list
  deps_list=$("$YQ" '.container.compose.dependencies // [] | .[]' "$values_file" 2>/dev/null || true)

  if [ -z "$deps_list" ]; then
    return
  fi

  local result="depends_on:\n"

  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    result+="      - $dep\n"
  done <<< "$deps_list"

  echo -e "$result"
}

build_variables() {
  local values_file=$1
  local result=""

  configMaps=$("$YQ" '.container.variables.config-map // {}' "$values_file")
  secrets=$("$YQ" '.container.variables.secrets // {}' "$values_file")

  for key in $(echo "$configMaps" | "$YQ" 'keys | .[]'); do
    value=$(echo "$configMaps" | "$YQ" ".\"$key\"")
    result+="      - $(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')=$value\n"
  done

  for key in $(echo "$secrets" | "$YQ" 'keys | .[]'); do
    value=$(echo "$secrets" | "$YQ" ".\"$key\"")
    result+="      - $(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')=$value\n"
  done

  echo -e "$result"
}

build_volumes() {
  local values_file=$1

  local volumes_list
  volumes_list=$("$YQ" '.container.compose.volumes // [] | .[]' "$values_file" 2>/dev/null || true)

  if [ -z "$volumes_list" ]; then
    return
  fi

  local result="volumes:\n"

  while IFS= read -r vol; do
    [ -z "$vol" ] && continue
    result+="      - $vol\n"
  done <<< "$volumes_list"

  echo -e "$result"
}

process_csv_record() {
  local template_accumulator=$1
  local project_name=$2
  local absolute_path=$3

  project_path="$absolute_path/$project_name"
  values_file="$project_path/$DEFAULT_VALUES_FILE"

  if [[ ! -f "$values_file" ]]; then
    print_log "$RED $values_file not found. $NC"
    exit 1
  fi

  repository=$("$YQ" '.container.image.repository' "$values_file")
  tag_version=$("$YQ" '.container.image.tag' "$values_file")
  container_port=$("$YQ" '.container.port' "$values_file")

  docker_image="$repository:$tag_version"

  host_port=$("$YQ" '.container.compose.host-port' "$values_file")

  formatted_service=$(<"$SERVICE_TEMPLATE")
  formatted_service="${formatted_service//@project_path/$project_path}"
  formatted_service="${formatted_service//@app_name/$project_name}"
  formatted_service="${formatted_service//@docker_image/$docker_image}"
  formatted_service="${formatted_service//@host_port/$host_port}"
  formatted_service="${formatted_service//@container_port/$container_port}"

  # dependencies como array
  dependencies_section=$(build_dependencies "$values_file")
  if [ -n "$dependencies_section" ]; then
    formatted_service="${formatted_service//@dependencies/$dependencies_section}"
  else
    formatted_service="${formatted_service//@dependencies/""}"
  fi

  variables=$(build_variables "$values_file")
  if [ -n "$variables" ]; then
    formatted_service="${formatted_service//@variables/"environment:\n$variables"}"
  else
    formatted_service="${formatted_service//@variables/""}"
  fi

  volumes_section=$(build_volumes "$values_file")
  if [ -n "$volumes_section" ]; then
    formatted_service="${formatted_service//@volumes/$volumes_section}"
  else
    formatted_service="${formatted_service//@volumes/""}"
  fi

  template_accumulator+="$formatted_service\n\n"

  print_log "$project_name"
  echo "$template_accumulator"
}

iterate_csv_records() {
  local template_accumulator=""

  firstline=true
  while IFS=',' read -r project_name absolute_path || [ -n "$project_name" ]; do
    # Ignore headers
    if $firstline; then
        firstline=false
        continue
    fi

    # Ignore comments and parents
    if [[ $project_name != "#"* ]]; then
      template_accumulator=$(process_csv_record "$template_accumulator" "$project_name" "$absolute_path")
    fi

  done < <(sed 's/\r//g' "$PROJECTS_CSV")
  echo "$template_accumulator"
}

build_top_level_volumes() {
  local all_sources=""
  local firstline=true

  while IFS=',' read -r project_name absolute_path || [ -n "$project_name" ]; do
    # Ignore headers
    if $firstline; then
      firstline=false
      continue
    fi

    # Ignore comments and parents
    if [[ $project_name == "#"* ]]; then
      continue
    fi

    local project_path="$absolute_path/$project_name"
    local values_file="$project_path/$DEFAULT_VALUES_FILE"

    if [[ ! -f "$values_file" ]]; then
      continue
    fi

    local volumes_list
    volumes_list=$("$YQ" '.container.compose.volumes // [] | .[]' "$values_file" 2>/dev/null || true)

    [ -z "$volumes_list" ] && continue

    while IFS= read -r vol; do
      [ -z "$vol" ] && continue

      local source="${vol%%:*}"

      # Binds mounts
      if [[ "$source" == /* || "$source" == .* || "$source" == ../* ]]; then
        continue
      fi

      # no duplicates
      if ! grep -q "^$source$" <<< "$all_sources"; then
        all_sources+="$source\n"
      fi
    done <<< "$volumes_list"

  done < <(sed 's/\r//g' "$PROJECTS_CSV")

  if [ -z "$all_sources" ]; then
    return
  fi

  local result="volumes:\n"
  while IFS= read -r src; do
    [ -z "$src" ] && continue
    result+="  $src:\n"
  done <<< "$(echo -e "$all_sources")"

  echo -e "$result"
}

build_compose_file() {
  compose_template=$(<"$COMPOSE_TEMPLATE")
  services=$(iterate_csv_records)
  compose_template="${compose_template//@services/$services}"

  top_level_volumes=$(build_top_level_volumes)
  if [ -n "$top_level_volumes" ]; then
    compose_template="${compose_template//@top_level_volumes/$top_level_volumes}"
  else
    compose_template="${compose_template//@top_level_volumes/""}"
  fi

  compose_template=$(echo "$compose_template" | sed '/^[[:space:]]*$/d') # delete empty lines

  echo -e "$compose_template" > "$COMPOSE_FILE"
  echo -e "${CHECK_SYMBOL} created: $COMPOSE_FILE"
}

build_compose_file
