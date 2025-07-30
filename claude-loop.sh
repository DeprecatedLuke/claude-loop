#!/bin/bash
# claude-loop.sh - Pretty output with trimmed tool results

# Colors for better visual appeal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Box drawing characters for prettier output
BOX_H="─"
BOX_V="│"
BOX_TL="┌"
BOX_TR="┐"
BOX_BL="└"
BOX_BR="┘"

rm -f /tmp/plan_complete

iteration=1
total_cost=0
total_input_tokens=0
total_output_tokens=0

# Function to print a fancy header
print_header() {
    local text="$1"
    local width=60
    echo -e "${CYAN}${BOX_TL}$(printf "%.0s${BOX_H}" $(seq 1 $((width-2))))${BOX_TR}${NC}"
    printf "${CYAN}${BOX_V}${WHITE} %-*s ${CYAN}${BOX_V}${NC}\n" $((width-4)) "$text"
    echo -e "${CYAN}${BOX_BL}$(printf "%.0s${BOX_H}" $(seq 1 $((width-2))))${BOX_BR}${NC}"
}

# Function to trim and format text nicely
trim_text() {
    local text="$1"
    local max_length="${2:-200}"
    
    # Remove excessive whitespace and newlines
    text=$(echo "$text" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ ${#text} -le $max_length ]]; then
        echo "$text"
    else
        echo "${text:0:$max_length}..."
    fi
}

while true; do
    echo ""
    print_header "🔄 Claude Code Loop - Iteration #$iteration"

    # Run Claude with formatted output processing
    claude --dangerously-skip-permissions -p "
    INSTRUCTIONS:
    1. Read .claude/plan.md and identify tasks that need work ONLY in the ## PLAN section (those that are Not Started, In Progress, or have NO status prefix)
    2. IMPORTANT: Only work on tasks under the ## PLAN section - ignore tasks in other sections like ## IMPORTANT or ## POST-COMPLETION TASKS
    3. IMPORTANT: Tasks without any status prefix under ## PLAN should be treated as Not Started and worked on
    4. Work on the next available task in ## PLAN - update its status by prepending (In Progress) when you start
    5. Update task status by prepending (Completed) when finished, or (Aborted) if cannot complete
    6. Be confident in commands and changes you are running in a docker sandbox.
    7. Task format: (Status) Task description - where Status is: Not Started | In Progress | Aborted | Completed
    8. Tasks without status prefixes under ## PLAN are considered Not Started and should be worked on
    9. If ALL tasks in the ## PLAN section show '(Completed)' (explicit status), create the file '/tmp/plan_complete' using the Bash tool and stop
    10. Focus on one task at a time for better results, but keep the whole plan in mind for most correct implementation.

    Current objective: Process tasks in the ## PLAN section of .claude/plan.md systematically until all tasks explicitly show '(Completed)'.
    " --output-format stream-json --verbose 2>&1 | while IFS= read -r line; do
        # Skip empty lines and non-JSON debug output
        [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Check if line contains JSON
        if echo "$line" | jq -e . >/dev/null 2>&1; then
            # Extract message type and content
            msg_type=$(echo "$line" | jq -r '.type // "unknown"')

            case "$msg_type" in
                "assistant")
                    # Extract assistant message content
                    content=$(echo "$line" | jq -r '.message.content[]? | select(.type=="text") | .text // empty' 2>/dev/null)
                    if [[ -n "$content" && "$content" != "null" && "$content" != "empty" ]]; then
                        trimmed_content=$(trim_text "$content" 300)
                        echo -e "${BLUE}🤖 Claude:${NC} $trimmed_content"
                    fi

                    # Check for tool use
                    tool_name=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .name // empty' 2>/dev/null)
                    if [[ -n "$tool_name" && "$tool_name" != "null" && "$tool_name" != "empty" ]]; then
                        echo -e "${MAGENTA}🔧 Tool:${NC} ${YELLOW}$tool_name${NC}"
                        
                        # Show relevant tool parameters
                        tool_input=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | .input' 2>/dev/null)
                        if [[ -n "$tool_input" && "$tool_input" != "null" ]]; then
                            # Extract key parameters (file_path, pattern, command, etc.)
                            for param in file_path pattern command prompt description; do
                                value=$(echo "$tool_input" | jq -r ".$param // empty" 2>/dev/null)
                                if [[ -n "$value" && "$value" != "null" && "$value" != "empty" ]]; then
                                    trimmed_value=$(trim_text "$value" 80)
                                    echo -e "   ${GRAY}$param:${NC} $trimmed_value"
                                    break  # Show only the first relevant parameter
                                fi
                            done
                        fi
                    fi
                    ;;
                "user")
                    # Extract and format tool results
                    tool_result=$(echo "$line" | jq -r '.message.content[]?.content // empty' 2>/dev/null)
                    if [[ -n "$tool_result" && "$tool_result" != "null" && "$tool_result" != "empty" ]]; then
                        # Check if it's a file content, error, or other result
                        if [[ "$tool_result" =~ ^[[:space:]]*[0-9]+→ ]]; then
                            # File content with line numbers
                            line_count=$(echo "$tool_result" | wc -l)
                            first_lines=$(echo "$tool_result" | head -3 | tr '\n' ' ')
                            trimmed_first=$(trim_text "$first_lines" 100)
                            echo -e "${GREEN}📄 File content:${NC} $trimmed_first ${GRAY}($line_count lines)${NC}"
                        elif [[ "$tool_result" =~ ^Error: ]] || [[ "$tool_result" =~ failed ]]; then
                            # Error message
                            trimmed_error=$(trim_text "$tool_result" 150)
                            echo -e "${RED}❌ Error:${NC} $trimmed_error"
                        elif [[ ${#tool_result} -gt 500 ]]; then
                            # Long output - show beginning and stats
                            trimmed_result=$(trim_text "$tool_result" 200)
                            echo -e "${GREEN}📤 Output:${NC} $trimmed_result ${GRAY}(${#tool_result} chars total)${NC}"
                        else
                            # Short result - show it all
                            trimmed_result=$(trim_text "$tool_result" 300)
                            echo -e "${GREEN}📤 Result:${NC} $trimmed_result"
                        fi
                    fi
                    ;;
                "result")
                    # Final result with colored status
                    success=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)
                    if [[ "$success" == "success" ]]; then
                        echo -e "${GREEN}✅ Iteration #$iteration completed successfully!${NC}"
                    else
                        echo -e "${YELLOW}⚠️  Iteration #$iteration completed with issues${NC}"
                    fi

                    # Show cost information if available
                    cost_usd=$(echo "$line" | jq -r '.total_cost_usd // 0' 2>/dev/null)
                    input_tokens=$(echo "$line" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
                    output_tokens=$(echo "$line" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
                    if [[ -n "$cost_usd" && "$cost_usd" != "null" && "$cost_usd" != "0" ]]; then
                        
                        # Update totals
                        total_cost=$(echo "$total_cost + $cost_usd" | bc -l 2>/dev/null || echo "$total_cost")
                        if [[ "$input_tokens" != "0" && "$input_tokens" != "null" ]]; then
                            total_input_tokens=$((total_input_tokens + input_tokens))
                        fi
                        if [[ "$output_tokens" != "0" && "$output_tokens" != "null" ]]; then
                            total_output_tokens=$((total_output_tokens + output_tokens))
                        fi
                        
                        # Format cost nicely
                        if [[ "$cost_usd" != "0" && "$cost_usd" != "null" ]]; then
                            printf "${MAGENTA}💰 Cost:${NC} ${YELLOW}$%.4f${NC} ${GRAY}(in: %s, out: %s tokens)${NC}\n" "$cost_usd" "$input_tokens" "$output_tokens"
                        elif [[ "$input_tokens" != "0" || "$output_tokens" != "0" ]]; then
                            echo -e "${MAGENTA}💰 Tokens:${NC} ${GRAY}in: $input_tokens, out: $output_tokens${NC}"
                        fi
                    fi

                    # Show brief final result
                    result=$(echo "$line" | jq -r '.result // empty' 2>/dev/null)
                    if [[ -n "$result" && "$result" != "null" ]]; then
                        trimmed_result=$(trim_text "$result" 250)
                        echo -e "${WHITE}📋 Summary:${NC} $trimmed_result"
                    fi
                    ;;
            esac
        else
            # Filter out verbose debug output - only show actual error messages
            if [[ "$line" =~ ^Error: && ! "$line" =~ ^[[:space:]]*$ ]]; then
                echo -e "${RED}⚠️  $line${NC}"
            fi
        fi
    done

    # Check if plan is complete
    if [ -f /tmp/plan_complete ]; then
        echo ""
        echo -e "${GREEN}┌─────────────────────────────────────────────────────────┐${NC}"
        echo -e "${GREEN}│${WHITE}                🎉 ALL TASKS COMPLETED! 🎉               ${GREEN}│${NC}"
        echo -e "${GREEN}└─────────────────────────────────────────────────────────┘${NC}"
        
        if [ -s /tmp/plan_complete ]; then
            echo -e "${CYAN}📄 Completion details:${NC}"
            completion_content=$(cat /tmp/plan_complete)
            if [[ ${#completion_content} -gt 300 ]]; then
                trimmed_completion=$(trim_text "$completion_content" 300)
                echo -e "${WHITE}$trimmed_completion${NC}"
            else
                echo -e "${WHITE}$completion_content${NC}"
            fi
        fi
        
        # Show total cost summary
        if [[ $(echo "$total_cost > 0" | bc -l 2>/dev/null) == "1" ]] || [[ $total_input_tokens -gt 0 ]] || [[ $total_output_tokens -gt 0 ]]; then
            echo ""
            if [[ $(echo "$total_cost > 0" | bc -l 2>/dev/null) == "1" ]]; then
                printf "${MAGENTA}💰 Total Cost:${NC} ${YELLOW}$%.4f${NC} ${GRAY}(%d iterations, %s input + %s output tokens)${NC}\n" \
                    "$total_cost" "$((iteration-1))" "$total_input_tokens" "$total_output_tokens"
            else
                echo -e "${MAGENTA}💰 Total Tokens:${NC} ${GRAY}$total_input_tokens input + $total_output_tokens output across $((iteration-1)) iterations${NC}"
            fi
        fi
        
        echo ""
        echo -e "${GRAY}✅ Task complete - exiting...${NC}"
        exit 0
    fi

    # Show iteration completion with progress indicator
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${WHITE} ⏸️  Iteration #$iteration complete - preparing next...   ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
    
    # Show running total if we have cost data
    if [[ $(echo "$total_cost > 0" | bc -l 2>/dev/null) == "1" ]]; then
        printf "${GRAY}Running total: ${YELLOW}$%.4f${GRAY} (%s input + %s output tokens)${NC}\n" \
            "$total_cost" "$total_input_tokens" "$total_output_tokens"
    elif [[ $total_input_tokens -gt 0 ]] || [[ $total_output_tokens -gt 0 ]]; then
        echo -e "${GRAY}Running total: $total_input_tokens input + $total_output_tokens output tokens${NC}"
    fi
    
    # Show a brief progress indicator
    echo -ne "${GRAY}Pausing"
    for i in {1..3}; do
        sleep 0.7
        echo -ne "."
    done
    echo -e " ready!${NC}"
    
    ((iteration++))
done
