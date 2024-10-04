#!/bin/sh
export MAVEN_HOME=/opt/maven/3.8.8
export GRADLE_HOME=/opt/gradle/7.5.1
export TOOL_VERSION=7.5.1
export PROJECT_VERSION=1.1
export JAVA_HOME=/lib/jvm/java-1.8.0
export ENFORCE_VERSION=

set -- "$@" assemble publishToMavenLocal -DdisableTests 

#!/usr/bin/env bash
set -o verbose
set -eu
set -o pipefail
FILE="$JAVA_HOME/lib/security/cacerts"
if [ ! -f "$FILE" ]; then
    FILE="$JAVA_HOME/jre/lib/security/cacerts"
fi

if [ -f /var/workdir/software/tls/service-ca.crt/service-ca.crt ]; then
    keytool -import -alias jbs-cache-certificate -keystore "$FILE" -file /var/workdir/software/tls/service-ca.crt/service-ca.crt -storepass changeit -noprompt
fi



#!/usr/bin/env bash
set -o verbose
set -eu
set -o pipefail

cd /var/workdir/workspace/source

if [ -n "" ]
then
    cd 
fi

if [ ! -z ${JAVA_HOME+x} ]; then
    echo "JAVA_HOME:$JAVA_HOME"
    PATH="${JAVA_HOME}/bin:$PATH"
fi

if [ ! -z ${MAVEN_HOME+x} ]; then
    echo "MAVEN_HOME:$MAVEN_HOME"
    PATH="${MAVEN_HOME}/bin:$PATH"
fi

if [ ! -z ${GRADLE_HOME+x} ]; then
    echo "GRADLE_HOME:$GRADLE_HOME"
    PATH="${GRADLE_HOME}/bin:$PATH"
fi

if [ ! -z ${ANT_HOME+x} ]; then
    echo "ANT_HOME:$ANT_HOME"
    PATH="${ANT_HOME}/bin:$PATH"
fi

if [ ! -z ${SBT_DIST+x} ]; then
    echo "SBT_DIST:$SBT_DIST"
    PATH="${SBT_DIST}/bin:$PATH"
fi
echo "PATH:$PATH"

#fix this when we no longer need to run as root
export HOME=/root

mkdir -p /var/workdir/workspace/logs /var/workdir/workspace/packages



#This is replaced when the task is created by the golang code


#!/usr/bin/env bash

if [ ! -z ${JBS_DISABLE_CACHE+x} ]; then
    cat >"/var/workdir/software/settings"/settings.xml <<EOF
    <settings>
EOF
else
    cat >"/var/workdir/software/settings"/settings.xml <<EOF
    <settings>
      <mirrors>
        <mirror>
          <id>mirror.default</id>
          <url>${CACHE_URL}</url>
          <mirrorOf>*</mirrorOf>
        </mirror>
      </mirrors>
EOF
fi

cat >>"/var/workdir/software/settings"/settings.xml <<EOF
  <!-- Off by default, but allows a secondary Maven build to use results of prior (e.g. Gradle) deployment -->
  <profiles>
    <profile>
      <id>gradle</id>
      <activation>
        <property>
          <name>useJBSDeployed</name>
        </property>
      </activation>
      <repositories>
        <repository>
          <id>artifacts</id>
          <url>file:///var/workdir/workspace/artifacts</url>
          <releases>
            <enabled>true</enabled>
            <checksumPolicy>ignore</checksumPolicy>
          </releases>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>artifacts</id>
          <url>file:///var/workdir/workspace/artifacts</url>
          <releases>
            <enabled>true</enabled>
            <checksumPolicy>ignore</checksumPolicy>
          </releases>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
</settings>
EOF

#!/usr/bin/env bash
export GRADLE_USER_HOME="/var/workdir/software/settings/.gradle"
mkdir -p "${GRADLE_USER_HOME}"
mkdir -p "${HOME}/.m2/repository"

cat > "${GRADLE_USER_HOME}"/gradle.properties << EOF
org.gradle.console=plain

# For https://github.com/Kotlin/kotlinx.team.infra
versionSuffix=

# Increase timeouts
systemProp.org.gradle.internal.http.connectionTimeout=600000
systemProp.org.gradle.internal.http.socketTimeout=600000
systemProp.http.socketTimeout=600000
systemProp.http.connectionTimeout=600000

# Settings for <https://github.com/vanniktech/gradle-maven-publish-plugin>
RELEASE_REPOSITORY_URL=file:/var/workdir/workspace/artifacts
RELEASE_SIGNING_ENABLED=false
mavenCentralUsername=
mavenCentralPassword=

# Default values for common enforced properties
sonatypeUsername=jbs
sonatypePassword=jbs
EOF

if [ -d .hacbs-init ]; then
    rm -rf "${GRADLE_USER_HOME}"/init.d
    cp -r .hacbs-init "${GRADLE_USER_HOME}"/init.d
fi

#if we run out of memory we want the JVM to die with error code 134
export JAVA_OPTS="-XX:+CrashOnOutOfMemoryError"

export PATH="${JAVA_HOME}/bin:${PATH}"

#some gradle builds get the version from the tag
#the git init task does not fetch tags
#so just create one to fool the plugin
git config user.email "HACBS@redhat.com"
git config user.name "HACBS"
if [ -n "" ]; then
  echo "Creating tag 1.1 to match enforced version"
  git tag -m 1.1 -a 1.1 || true
fi

if [ ! -d "${GRADLE_HOME}" ]; then
    echo "Gradle home directory not found at ${GRADLE_HOME}" >&2
    exit 1
fi

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

#our dependency tracing breaks verification-metadata.xml
#TODO: should we disable tracing for these builds? It means we can't track dependencies directly, so we can't detect contaminants
rm -f gradle/verification-metadata.xml

echo "Running Gradle command with arguments: $@"

gradle -Dmaven.repo.local=/var/workdir/workspace/artifacts --info --stacktrace "$@" | tee /var/workdir/workspace/logs/gradle.log




