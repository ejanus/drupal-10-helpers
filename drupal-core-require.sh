#!/bin/bash

# This script provides a function called `drupal-require-core` for managing 
# and updating Drupal core dependencies in a project. It identifies 
# `drupal/core-*` dependencies from composer.json and updates them to the 
# specified version.

# Usage:
#   drupal-require-core <drupal-core-version> [<project-directory>]
#     <drupal-core-version>    The version of Drupal core to update to (e.g., 10.4).
#     <project-directory>      (Optional) Path to the project directory. If not 
#                              provided, the current directory is assumed.

drupal-require-core() {
  if [ -z "$1" ]; then
    echo "Usage: drupal-require-core <drupal-core-version> [<project-directory>]"
    echo "If <project-directory> is not provided, the current directory is assumed."
    return 1
  fi

  local version=$1
  local project_dir=${2:-$(pwd)} # Use current directory if no directory is provided

  if [ ! -d "$project_dir" ]; then
    echo "Error: Directory $project_dir does not exist."
    return 1
  fi

  cd "$project_dir" || return 1

  # Ensure composer.json exists
  if [ ! -f composer.json ]; then
    echo "Error: composer.json not found in $project_dir."
    return 1
  fi

  # Parse dependencies from composer.json
  local dependencies=$(jq -r --arg version "$version" '.require | to_entries[] | select(.key | startswith("drupal/core-")) | .key + ":" + "^" + $version' composer.json)
  local dev_dependencies=$(jq -r --arg version "$version" '.["require-dev"] | to_entries[] | select(.key | startswith("drupal/core-")) | .key + ":" + "^" + $version' composer.json)

  if [ -z "$dependencies" ] && [ -z "$dev_dependencies" ]; then
    echo "No drupal/core-* dependencies found in composer.json"
    return 1
  fi

  echo "The following dependencies will be updated to ^$version:"
  echo
  echo "Normal dependencies:"
  echo "$dependencies" | tr ' ' '\n'
  echo
  echo "Dev dependencies:"
  echo "$dev_dependencies" | tr ' ' '\n'
  echo

  # Prepare inline commands
  local commands=(
    "composer clear-cache && composer install"
    "composer require $(echo "$dependencies" | xargs) --update-with-all-dependencies"
    "composer require --dev $(echo "$dev_dependencies" | xargs) --update-with-all-dependencies"
    "drush updb && drush cr && drush cex -y"
  )

  echo "The following inline commands will be executed:"
  echo
  for cmd in "${commands[@]}"; do
    echo "$cmd"
  done
  echo

  # Ask for confirmation
  printf "Do you want to run these commands now? (y/N): "
  read confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "You can copy and run the commands manually if needed."
    return 0
  fi

  # Execute commands
  for cmd in "${commands[@]}"; do
    echo "Running: $cmd"
    eval "$cmd"
    if [ $? -ne 0 ]; then
      echo "Command failed: $cmd"
      return 1
    fi
  done
}
