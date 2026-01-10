#!/bin/bash

LOG_DIR="$HOME/Library/Application Support/Luzia/Evals"

echo "📊 Watching Luzia logs..."
echo "   Location: $LOG_DIR"
echo "   Press Ctrl+C to stop"
echo ""

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Create log files if they don't exist
touch "$LOG_DIR/evals_log.tsv"
touch "$LOG_DIR/evals_errors.tsv"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Success Log (evals_log.tsv):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show last 5 successful corrections
if [ -s "$LOG_DIR/evals_log.tsv" ]; then
    tail -n 5 "$LOG_DIR/evals_log.tsv" | column -t -s $'\t'
else
    echo "(empty - no successful corrections yet)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Error Log (evals_errors.tsv):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show last 5 errors
if [ -s "$LOG_DIR/evals_errors.tsv" ]; then
    tail -n 5 "$LOG_DIR/evals_errors.tsv" | column -t -s $'\t'
else
    echo "(empty - no errors logged yet)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Watching for new entries... (Ctrl+C to exit)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Tail both files simultaneously with labels
tail -f "$LOG_DIR/evals_log.tsv" "$LOG_DIR/evals_errors.tsv" 2>/dev/null | while read line; do
    if [[ "$line" == "==>"* ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$line"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo "$line"
    fi
done
