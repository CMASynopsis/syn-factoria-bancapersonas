#!/bin/bash
# scripts/jmeter/install.sh

# Load common utilities
source scripts/commons/get.sh
source scripts/commons/log.sh

# Initialize module name for logging
MODULE_NAME="jmeter-install"
LOG_MODULE_NAME="$MODULE_NAME"

load_env_vars "dev" "$(get_script_dir)/jmeter"

# Resolve JMETER_HOME using set_with_fallback (ENV_JMETER_HOME -> inline default)
JMETER_HOME="$(set_with_fallback "JMETER_HOME" "/usr/local/jmeter")"

# Ensure target directory exists
if [[ ! -d "$JMETER_HOME/lib/ext" ]]; then
  log "INFO" "Directory $JMETER_HOME/lib/ext does not exist. Creating..."
  mkdir -p "$JMETER_HOME/lib/ext"
fi

# Copy plugins to JMeter extensions directory
log "INFO" "Copying JMeter plugins..."
cp -r "$(get_script_dir)/jmeter/plugins/"* "$JMETER_HOME/lib/ext/"

log "SUCCESS" "Installation completed. Plugins copied to $JMETER_HOME/lib/ext"
