#!/usr/bin/env bash

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VALUES_FILE="charts/neuron-helm-chart/values.yaml"
README_FILE="charts/neuron-helm-chart/README.md"

# Repository to YAML path mapping
declare -A REPOSITORIES=(
    ["public.ecr.aws/neuron/neuron-device-plugin"]="devicePlugin.image.tag"
    ["public.ecr.aws/neuron/neuron-scheduler"]="scheduler.image.tag"
    ["public.ecr.aws/neuron/neuron-node-recovery"]="npd.nodeRecovery.image.tag"
    ["public.ecr.aws/neuron/neuron-dra-driver"]="draDriver.image.tag"
    ["public.ecr.aws/neuron/neuron-ultraserver-operator"]="ultraserverOperator.image.tag"
    ["registry.k8s.io/node-problem-detector/node-problem-detector"]="npd.nodeProblemDetector.image.tag"
)

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

get_latest_tag() {
    local repo=$1
    local image_path tags_url tag_pattern auth_header=""

    if [[ "$repo" == public.ecr.aws/* ]]; then
        local repository_name="${repo##*/}"
        image_path="neuron/${repository_name}"
        tags_url="https://public.ecr.aws/v2/${image_path}/tags/list"
        tag_pattern='^[0-9]+\.[0-9]+\.[0-9]+'

        # ECR requires a bearer token
        local token
        token=$(curl -s --max-time 10 "https://public.ecr.aws/token/?scope=repository:${image_path}:pull&service=public.ecr.aws" | jq -r '.token' 2>/dev/null)
        if [[ -z "$token" || "$token" == "null" ]]; then
            return 1
        fi
        auth_header="Authorization: Bearer $token"
    elif [[ "$repo" == registry.k8s.io/* ]]; then
        image_path="${repo#registry.k8s.io/}"
        tags_url="https://registry.k8s.io/v2/${image_path}/tags/list"
        tag_pattern='^v[0-9]+\.[0-9]+\.[0-9]+$'
        # registry.k8s.io supports anonymous access, no token needed
    else
        print_status "$RED" "  Unknown registry for $repo"
        return 1
    fi

    # Get tags and sort by semantic version
    local curl_args=(-sL --max-time 15)
    if [[ -n "$auth_header" ]]; then
        curl_args+=(-H "$auth_header")
    fi

    local tag
    tag=$(curl "${curl_args[@]}" "$tags_url" \
        | jq -r '.tags[]' 2>/dev/null \
        | grep -E "$tag_pattern" \
        | sort -t. -k1,1V -k2,2n -k3,3n -k4,4n \
        | tail -1)

    if [[ -n "$tag" ]]; then
        echo "$tag"
        return 0
    fi

    return 1
}

update_yaml_value() {
    local yaml_path=$1
    local new_value=$2
    
    # Get current value
    local current_value
    current_value=$(yq eval ".${yaml_path}" "$VALUES_FILE")
    
    # Skip update if value is already the same
    if [[ "$current_value" == "$new_value" ]]; then
        return 2  # Return special code to indicate no change needed
    fi
    
    # Update yaml value
    yq eval ".${yaml_path} = \"${new_value}\"" -i "$VALUES_FILE"
    return $?
}

update_readme_value() {
    local yaml_path=$1
    local new_value=$2
    
    # Find the line with this key
    local line_with_key
    line_with_key=$(grep -F "\`${yaml_path}\`" "$README_FILE" || true)
    
    if [[ -z "$line_with_key" ]]; then
        # Key not found in README
        return 1
    fi
    
    # Extract current value (last backtick-enclosed value on the line)
    local current_readme_value
    current_readme_value=$(echo "$line_with_key" | grep -oE '\`[^\`]+\`' | tail -1 | tr -d '`')
    
    # Skip update if value is already the same
    if [[ "$current_readme_value" == "$new_value" ]]; then
        return 2  # Return special code to indicate no change needed
    fi
    
    # Extract the description (text between second and third pipe)
    local description
    description=$(echo "$line_with_key" | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Create the replacement line
    local replacement="| \`${yaml_path}\` | ${description} | \`${new_value}\` |"
    
    # Use awk to replace the line
    awk -v search="\`${yaml_path}\`" -v repl="$replacement" \
        'index($0, search) { print repl; next } { print }' \
        "$README_FILE" > "${README_FILE}.tmp" && mv "${README_FILE}.tmp" "$README_FILE"
    
    return $?
}

check_dependencies() {
    local missing_required=()
    
    # Check required tools
    if ! command -v curl &>/dev/null; then
        missing_required+=("curl")
    fi
    
    if ! command -v jq &>/dev/null; then
        missing_required+=("jq")
    fi
    
    if ! command -v yq &>/dev/null; then
        missing_required+=("yq")
    fi
    
    # Fail if required tools are missing
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        print_status "$RED" "ERROR: Required tools not found: ${missing_required[*]}"
        if [[ " ${missing_required[*]} " =~ " curl " ]]; then
            print_status "$YELLOW" "  curl is typically pre-installed on most systems"
        fi
        if [[ " ${missing_required[*]} " =~ " jq " ]]; then
            print_status "$YELLOW" "  Install jq: https://jqlang.github.io/jq/download/"
        fi
        if [[ " ${missing_required[*]} " =~ " yq " ]]; then
            print_status "$YELLOW" "  Install yq: https://github.com/mikefarah/yq#install"
        fi
        exit 1
    fi
}

main() {
    print_status "$YELLOW" "=== Neuron Helm Chart Image Tag Updater ==="
    echo
    
    # Check if values file exists
    if [[ ! -f "$VALUES_FILE" ]]; then
        print_status "$RED" "ERROR: Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    # Check if README file exists
    if [[ ! -f "$README_FILE" ]]; then
        print_status "$RED" "ERROR: README file not found: $README_FILE"
        exit 1
    fi
    
    print_status "$GREEN" "Processing files:"
    print_status "$GREEN" "  - $VALUES_FILE"
    print_status "$GREEN" "  - $README_FILE"
    echo
    
    # Check dependencies
    check_dependencies
    
    # Track success/failure
    local success_count=0
    local total_count=${#REPOSITORIES[@]}
    local failed_repos=()
    
    # Process each repository
    for repo in "${!REPOSITORIES[@]}"; do
        local yaml_path="${REPOSITORIES[$repo]}"
        
        print_status "$YELLOW" "Processing repository: $repo"
        print_status "$YELLOW" "  Fetching latest tag..."
        
        # Get latest tag
        set +e
        latest_tag=$(get_latest_tag "$repo")
        local get_tag_result=$?
        set -e
        
        if [[ $get_tag_result -eq 0 && -n "$latest_tag" ]]; then
            print_status "$GREEN" "✓ SUCCESS: Retrieved tag '$latest_tag' for $repo"
            
            # Update the values.yaml file
            set +e
            update_yaml_value "$yaml_path" "$latest_tag"
            local update_result=$?
            set -e
            
            if [[ $update_result -eq 0 ]]; then
                print_status "$GREEN" "  Updated $yaml_path to '$latest_tag' in values.yaml"
            elif [[ $update_result -eq 2 ]]; then
                print_status "$YELLOW" "  No change needed - $yaml_path already set to '$latest_tag' in values.yaml"
            else
                print_status "$RED" "  Failed to update $yaml_path in values.yaml"
                failed_repos+=("$repo")
                echo
                continue
            fi
            
            # Update the README file (disable exit on error)
            set +e
            update_readme_value "$yaml_path" "$latest_tag"
            local readme_result=$?
            set -e
            
            if [[ $readme_result -eq 0 ]]; then
                print_status "$GREEN" "  Updated $yaml_path to '$latest_tag' in README.md"
                success_count=$((success_count + 1))
            elif [[ $readme_result -eq 2 ]]; then
                print_status "$YELLOW" "  No change needed - $yaml_path already set to '$latest_tag' in README.md"
                success_count=$((success_count + 1))
            else
                print_status "$RED" "  Failed to update $yaml_path in README.md"
                failed_repos+=("$repo")
            fi
        else
            print_status "$RED" "✗ FAILURE: Could not retrieve tag for $repo"
            failed_repos+=("$repo")
        fi
        
        echo
    done
    
    # Summary
    print_status "$YELLOW" "=== SUMMARY ==="
    print_status "$GREEN" "Successfully updated: $success_count/$total_count repositories"
    
    if [[ ${#failed_repos[@]} -gt 0 ]]; then
        print_status "$RED" "Failed repositories:"
        for repo in "${failed_repos[@]}"; do
            print_status "$RED" "  - $repo"
        done
    fi
    
    echo
    if [[ $success_count -eq $total_count ]]; then
        print_status "$GREEN" "🎉 All repositories updated successfully!"
    else
        print_status "$YELLOW" "⚠️  Some repositories failed to update. Check the errors above."
    fi
    print_status "$YELLOW" "Updated files:"
    print_status "$YELLOW" "  - $VALUES_FILE"
    print_status "$YELLOW" "  - $README_FILE"
}

main "$@"
