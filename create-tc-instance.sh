#!/bin/bash
# A definitive script to fully prepare a new Tomcat instance on SLES for use with Log4j2.
# It validates prerequisites, creates the directory structure, installs Log4j2 and the
# examples webapp, sets up all configurations, and makes the instance ready to test.

# --- Validation ---
if [ -z "$1" ]; then
  echo "Error: You must provide an instance name."
  echo "Usage: $0 <instance-name>"
  exit 1
fi

# --- Configuration ---
INSTANCE_NAME="$1"
INSTANCE_BASE_DIR="/var/lib/tomcats/${INSTANCE_NAME}"
INSTANCE_LIB_DIR="${INSTANCE_BASE_DIR}/lib"
CUSTOM_SCRIPT_PATH="/usr/lib/tomcat/server-${INSTANCE_NAME}"
SYSTEMD_ENV_FILE="/etc/sysconfig/tomcat@${INSTANCE_NAME}"
DROP_IN_DIR="/etc/systemd/system/tomcat@${INSTANCE_NAME}.service.d"
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
# --- End Configuration ---

echo "🚀 Setting up definitive Tomcat instance: ${INSTANCE_NAME}"

### 1. Check Prerequisites (Tomcat Installation)
echo "--> Step 1: Checking for Tomcat installation..."
if ! rpm -q tomcat > /dev/null; then
  echo "    Tomcat not found. Attempting to install..."
  sudo zypper in -y tomcat
  if [ $? -ne 0 ]; then
    echo "⛔ ERROR: Failed to install Tomcat. Please ensure the 'Web and Scripting Module' is enabled."
    exit 1
  fi
fi
echo "    Tomcat is installed."

### 2. Create Instance Directory Structure
echo "--> Step 2: Creating directory structure..."
sudo mkdir -p "${INSTANCE_BASE_DIR}"/{conf,logs,lib,temp,webapps,work}

### 3. Copy Base Configuration
echo "--> Step 3: Copying base configuration files..."
sudo cp /etc/tomcat/*.{xml,properties,policy} "${INSTANCE_BASE_DIR}/conf/"

### 4. Install Log4j2 & Webapps Packages
echo "--> Step 4: Checking for log4j & tomcat-webapps packages..."
for pkg in log4j tomcat-webapps; do
  if ! rpm -q ${pkg} > /dev/null; then
    echo "    ${pkg} not found. Installing..."
    sudo zypper in -y ${pkg}
  fi
done
echo "    Required packages are installed."

### 5. Link Libraries and Test App
echo "--> Step 5: Linking Log4j2 JARs and test application..."
sudo ln -sfn /usr/share/java/log4j/log4j-api.jar    "${INSTANCE_LIB_DIR}/"
sudo ln -sfn /usr/share/java/log4j/log4j-core.jar   "${INSTANCE_LIB_DIR}/"
sudo ln -sfn /usr/share/java/log4j/log4j-jul.jar    "${INSTANCE_LIB_DIR}/"
# Link the exploded examples directory into our instance's webapps
sudo ln -sfn /usr/share/tomcat/webapps/examples    "${INSTANCE_BASE_DIR}/webapps/"
echo "    Libraries and test app are linked."

### 6. Create Custom Startup Script
echo "--> Step 6: Creating custom, upgrade-safe startup script..."
sudo cp /usr/lib/tomcat/server "${CUSTOM_SCRIPT_PATH}"
sudo chmod +x "${CUSTOM_SCRIPT_PATH}"
# This sed command finds the line with the conflicting JULI manager and comments it out.
CONFLICT_STRING="Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager"
sudo sed -i "s|.*${CONFLICT_STRING}.*|# &|" "${CUSTOM_SCRIPT_PATH}"

### 7. Create Instance Environment File
echo "--> Step 7: Creating instance-specific environment file..."
sudo tee "${SYSTEMD_ENV_FILE}" > /dev/null <<'EOF'
CATALINA_BASE="INSTANCE_BASE_PLACEHOLDER"
CLASSPATH="/usr/share/java/log4j/log4j-api.jar:/usr/share/java/log4j/log4j-core.jar:/usr/share/java/log4j/log4j-jul.jar"
CATALINA_OPTS="-Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager -Dlog4j.configurationFile=file:${CATALINA_BASE}/lib/log4j2.xml --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.rmi/sun.rmi.transport=ALL-UNNAMED"
EOF
sudo sed -i "s|INSTANCE_BASE_PLACEHOLDER|${INSTANCE_BASE_DIR}|g" "${SYSTEMD_ENV_FILE}"

### 8. Create Systemd Drop-in File
echo "--> Step 8: Creating systemd drop-in to use the custom script..."
sudo mkdir -p "${DROP_IN_DIR}"
sudo tee "${DROP_IN_DIR}/override.conf" > /dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=CUSTOM_SCRIPT_PLACEHOLDER start
EOF
sudo sed -i "s|CUSTOM_SCRIPT_PLACEHOLDER|${CUSTOM_SCRIPT_PATH}|g" "${DROP_IN_DIR}/override.conf"

### 9. Create Default log4j2.xml
echo "--> Step 9: Creating default log4j2.xml..."
sudo tee "${INSTANCE_LIB_DIR}/log4j2.xml" > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Properties>
        <Property name="LOG_PATH">${sys:catalina.base}/logs</Property>
        <Property name="LOG_PATTERN">%d{yyyy-MM-dd HH:mm:ss.SSS} [%t] %-5level %logger{36} - %msg%n</Property>
    </Properties>
    <Appenders>
        <Console name="Console" target="SYSTEM_OUT"><PatternLayout pattern="${LOG_PATTERN}"/></Console>
        <RollingFile name="File" fileName="${LOG_PATH}/tomcat.log" filePattern="${LOG_PATH}/tomcat-%d{yyyy-MM-dd}-%i.log.gz">
            <PatternLayout><Pattern>${LOG_PATTERN}</Pattern></PatternLayout>
            <Policies>
                <TimeBasedTriggeringPolicy interval="1" /><SizeBasedTriggeringPolicy size="10 MB"/>
            </Policies>
            <DefaultRolloverStrategy max="10"/>
        </RollingFile>
    </Appenders>
    <Loggers>
        <Logger name="org.apache" level="warn" /><Root level="info"><AppenderRef ref="Console"/><AppenderRef ref="File"/></Root>
    </Loggers>
</Configuration>
EOF

### 10. Set Final Permissions
echo "--> Step 10: Setting final permissions..."
sudo chown -R ${TOMCAT_USER}:${TOMCAT_GROUP} "${INSTANCE_BASE_DIR}"

# --- Final Output ---
echo ""
echo "✅ Definitive setup for instance '${INSTANCE_NAME}' is complete!"
echo "Run 'sudo systemctl daemon-reload' if this is the first time you run this script."
echo ""
echo "To use it, run: sudo systemctl start tomcat@${INSTANCE_NAME}.service"
echo ""
echo "Once started, you can access the test page at one of the following URLs:"

# Get all non-local IP addresses
IP_ADDRESSES=$(hostname -I)

echo "   - http://localhost:8080/examples/"
for IP in ${IP_ADDRESSES}; do
  echo "   - http://${IP}:8080/examples/"
done
echo ""
