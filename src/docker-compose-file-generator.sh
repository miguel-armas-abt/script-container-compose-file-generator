#!/bin/bash
set -e

source ./commons.sh
source ./../variables.env

build_dependencies() {
  local dependencies=$1

  if [ "$dependencies" != "none" ]; then
    formatted_dependencies=$(echo "$dependencies" | awk -F';' '{for(i=1;i<=NF;i++) printf "      - %s\n", $i}')
    echo -e "depends_on:\n$formatted_dependencies"
  fi
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
  local volumes=$1

  if [ "$volumes" != "none" ]; then
    formatted_volumes=$(echo "$volumes" | awk -F';' '{for(i=1;i<=NF;i++) printf "      - %s\n", $i}')
    echo -e "volumes:\n$formatted_volumes"
  fi
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
  dependencies=$("$YQ" '.container.compose.dependencies // "none"' "$values_file")
  volumes=$("$YQ" '.container.compose.volumes // "none"' "$values_file")

  formatted_service=$(<"$SERVICE_TEMPLATE")
  formatted_service="${formatted_service//@project_path/$project_path}"
  formatted_service="${formatted_service//@app_name/$project_name}"
  formatted_service="${formatted_service//@docker_image/$docker_image}"
  formatted_service="${formatted_service//@host_port/$host_port}"
  formatted_service="${formatted_service//@container_port/$container_port}"

  dependencies=$(build_dependencies "$dependencies")
  formatted_service="${formatted_service//@dependencies/$dependencies}"

  variables=$(build_variables "$values_file")
  if [ -n "$variables" ]; then
    formatted_service="${formatted_service//@variables/"environment:\n$variables"}"
  else
    formatted_service="${formatted_service//@variables/""}"
  fi

  volumes=$(build_volumes "$volumes")
  formatted_service="${formatted_service//@volumes/$volumes}"

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

build_compose_file() {
  compose_template=$(<"$COMPOSE_TEMPLATE")
  services=$(iterate_csv_records)
  compose_template="${compose_template//@services/$services}"
  compose_template=$(echo "$compose_template" | sed '/^[[:space:]]*$/d') #delete empty lines

  echo -e "$compose_template" > "$COMPOSE_FILE"
  echo -e "${CHECK_SYMBOL} created: $COMPOSE_FILE"
}

build_compose_file