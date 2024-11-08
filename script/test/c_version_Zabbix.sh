# === Version Validation Passed ===
echo "✅ Ubuntu version is supported ($OS_VERSION). Continuing with script..."

# === Zabbix Version Selection and Validation ===
read -rp "Enter Zabbix version (6.0, 6.4, or 7.0): " ZABBIX_VERSION

if ! [[ "$ZABBIX_VERSION" =~ ^(6.0|6|6.4|7.0|7)$ ]]; then
    log_and_exit "Invalid version. Please retype."
fi

# Get Link Download version
case "$ZABBIX_VERSION" in
    6.0) VERSION="${ZABBIX_VERSION}-6" ;;
    6) VERSION="${ZABBIX_VERSION}.0-6" ZABBIX_VERSION="${ZABBIX_VERSION}.0";;
    6.4) VERSION="${ZABBIX_VERSION}-1" ;;
    7.0) VERSION="${ZABBIX_VERSION}-2" ;;
    7) VERSION="${ZABBIX_VERSION}.0-2" ZABBIX_VERSION="${ZABBIX_VERSION}.0";;
    *) log_and_exit "Unsupported Zabbix version: $ZABBIX_VERSION" ;;
esac

echo "✅ Selected Zabbix version: $ZABBIX_VERSION"