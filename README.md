# Tomcat Instance Automation for SLES

A comprehensive shell script to automate the creation of isolated, production-ready Apache Tomcat instances on SUSE Linux Enterprise Server (SLES). This script replaces the default Tomcat JULI logger with the more powerful and flexible Log4j2 logging framework.

## Overview

The default Tomcat package on SLES is tightly integrated with the system and uses the `java.util.logging` (JULI) framework, which can be difficult to override. This script solves that problem by leveraging systemd templates and a custom, upgrade-safe configuration to create completely independent Tomcat instances, each configured to use Log4j2.

The entire process, from checking prerequisites to deploying a test application, is handled by a single command.

## Features ✨

* **Isolated Instances**: Creates a self-contained Tomcat instance in `/var/lib/tomcats/`, keeping it separate from the base installation.
* **Log4j2 Integration**: Automatically configures the instance to use Log4j2 for all logging, including capturing Tomcat's internal logs.
* **Dependency Management**: Checks for and installs necessary packages (`tomcat`, `log4j`, `tomcat-webapps`) using `zypper`.
* **Upgrade-Safe**: Does not modify any original system files. It uses a custom startup script and a systemd drop-in file, which are safe from being overwritten by package updates.
* **Fully Automated**:
    * Generates a default, production-ready `log4j2.xml` with rolling file appenders.
    * Creates the required systemd environment (`sysconfig`) and drop-in files.
    * Sets all necessary file permissions.
* **Includes a Test App**: Automatically installs and deploys the official Tomcat "Examples" web application for immediate verification.
* **User-Friendly**: Provides clear output, including the final URLs to access the test application.

## Prerequisites

* A running system with **SUSE Linux Enterprise Server 15**.
* **Root or `sudo` privileges**.
* The **"Web and Scripting Module"** for SLES must be enabled to provide the `tomcat` packages. (The script will check for this and provide an error if Tomcat cannot be installed).

## Usage

1.  **Save the script** to your server (e.g., as `create-tc-instance.sh`).
2.  **Make it executable**:
    ```bash
    chmod +x create-tc-instance.sh
    ```
3.  **Run the script** with a name for your new instance:
    ```bash
    sudo ./create-tc-instance.sh my-new-app
    ```
    Replace `my-new-app` with your desired project name.

After the script finishes, it will provide instructions to start the service and the URLs to access the test application.

## How to Remove an Instance

To completely remove an instance created by this script:

1.  **Stop and disable the service**:
    ```bash
    sudo systemctl stop tomcat@my-new-app.service
    sudo systemctl disable tomcat@my-new-app.service
    ```
2.  **Remove the instance files**:
    ```bash
    sudo rm -rf /var/lib/tomcats/my-new-app
    ```
3.  **Remove the configuration files**:
    ```bash
    sudo rm -f /usr/lib/tomcat/server-my-new-app
    sudo rm -f /etc/sysconfig/tomcat@my-new-app
    sudo rm -rf /etc/systemd/system/tomcat@my-new-app.service.d
    ```
4.  **Reload systemd**:
    ```bash
    sudo systemctl daemon-reload
    ```