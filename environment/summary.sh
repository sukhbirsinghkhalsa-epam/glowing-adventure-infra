#!/bin/bash

FILE="./terraform_plan_summary.json"

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed."
    exit 1
fi

# Check if JSON file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found."
    exit 1
fi

# Check if JSON is valid
if ! jq empty "$FILE" >/dev/null 2>&1; then
    echo "Error: Invalid JSON in '$FILE'."
    exit 1
fi

# ---------------------------------------------------------
# Function:
# Check whether a JSON value is meaningful
#
# Invalid / ignored values:
# null
# ""
# {}
# []
# ---------------------------------------------------------
is_meaningful() {
    local value="$1"

    if [[ -z "$value" ]]; then
        return 1
    fi

    case "$value" in
        null)
            return 1
            ;;
        '""')
            return 1
            ;;
        '{}')
            return 1
            ;;
        '[]')
            return 1
            ;;
    esac

    return 0
}

# ---------------------------------------------------------
# Process every Terraform resource change
# ---------------------------------------------------------
jq -c '.resource_changes[]?' "$FILE" | while read -r resource; do

    address=$(jq -r '.address // "Unknown"' <<< "$resource")

    actions=$(jq -r '
        (.change.actions // []) | join(", ")
    ' <<< "$resource")

    echo
    echo "Resource: $address"
    echo "Action: $actions"

    # -----------------------------------------------------
    # Get before / after objects
    #
    # Missing objects become null
    # -----------------------------------------------------
    before=$(jq -c '.change.before // null' <<< "$resource")
    after=$(jq -c '.change.after // null' <<< "$resource")

    # -----------------------------------------------------
    # Get all unique keys from before + after
    # -----------------------------------------------------
    keys=$(
        jq -r '
            [
                (.change.before // {} | keys[]?),
                (.change.after // {} | keys[]?)
            ]
            | unique[]
        ' <<< "$resource"
    )

    # -----------------------------------------------------
    # Compare every key
    # -----------------------------------------------------
    while IFS= read -r key; do

        # Skip empty key
        [[ -z "$key" ]] && continue

        # -------------------------------------------------
        # Safely get old value
        #
        # If before is missing OR key is missing:
        # return null
        # -------------------------------------------------
        old=$(
            jq -c \
                --arg key "$key" \
                '.change.before[$key] // null' \
                <<< "$resource"
        )

        # -------------------------------------------------
        # Safely get new value
        #
        # If after is missing OR key is missing:
        # return null
        # -------------------------------------------------
        new=$(
            jq -c \
                --arg key "$key" \
                '.change.after[$key] // null' \
                <<< "$resource"
        )

        # -------------------------------------------------
        # Validation 1:
        # Old must be meaningful
        # -------------------------------------------------
        if ! is_meaningful "$old"; then
            continue
        fi

        # -------------------------------------------------
        # Validation 2:
        # New must be meaningful
        # -------------------------------------------------
        if ! is_meaningful "$new"; then
            continue
        fi

        # -------------------------------------------------
        # Validation 3:
        # Old must not equal New
        # -------------------------------------------------
        if [[ "$old" == "$new" ]]; then
            continue
        fi

        # -------------------------------------------------
        # Convert JSON values into readable output
        # -------------------------------------------------
        old_display=$(jq -r -c '.' <<< "$old")
        new_display=$(jq -r -c '.' <<< "$new")

        # -------------------------------------------------
        # Display actual change
        # -------------------------------------------------
        echo " $key : $old_display -> $new_display"

    done <<< "$keys"

done
