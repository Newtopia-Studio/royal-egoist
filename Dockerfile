# syntax=docker/dockerfile:1
#
# Dockerfile reproducible para compilar juegos de Ren'Py a Android (RAPT).
#
# Esta versión usa archivos YA DESCARGADOS en el build context (carpeta
# ./assets/) en vez de descargarlos con wget durante el build. Esto evita
# que un build se cuelgue o se corte a medio camino por una descarga lenta
# (nos pasó con cmdline-tools.zip).
#
# Estructura esperada del build context:
#
#   .
#   ├── Dockerfile
#   ├── build-android.sh
#   └── assets/
#       ├── renpy-8.5.3-sdk.tar.bz2
#       ├── renpy-8.5.3-rapt.zip
#       ├── gradle-9.1.0-bin.zip
#       └── cmdline-tools.zip
#
# Para descargar esos 4 archivos a ./assets/ (con reintento vía -c si se
# corta a medio camino):
#
#   mkdir -p assets && cd assets
#   wget -c "https://www.renpy.org/dl/8.5.3/renpy-8.5.3-sdk.tar.bz2"
#   wget -c "https://www.renpy.org/dl/8.5.3/renpy-8.5.3-rapt.zip"
#   wget -c "https://services.gradle.org/distributions/gradle-9.1.0-bin.zip"
#   wget -c "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip
#
# Si cambias RENPY_VERSION, GRADLE_VERSION o CMDLINE_TOOLS_VERSION más
# abajo, tienes que volver a descargar los archivos correspondientes con
# los nombres/versiones nuevos.

FROM eclipse-temurin:21-jdk

ARG RENPY_VERSION=8.5.3
ARG GRADLE_VERSION=9.1.0
ARG CMDLINE_TOOLS_VERSION=11076708
ARG BUILD_TOOLS_VERSION=35.0.0
ARG PLATFORM_VERSION=android-36
ARG PROJECT_REF=main

ENV DEBIAN_FRONTEND=noninteractive
ENV SDK_ROOT=/renpy-${RENPY_VERSION}-sdk
ENV ANDROID_SDK_ROOT=${SDK_ROOT}/rapt/Sdk
ENV RENPY_VERSION=${RENPY_VERSION}

# --- Dependencias del sistema -------------------------------------------
# El JDK 21 ya viene preinstalado en la imagen base eclipse-temurin:21-jdk.
# bzip2: para descomprimir el SDK de Ren'Py (.tar.bz2)
# unzip: para descomprimir los .zip
# git: para clonar el proyecto
# nano: editor mínimo, útil para depurar dentro del contenedor
# (ya no necesitamos wget aquí porque los assets grandes vienen locales,
# pero lo dejamos por si algún paso futuro lo necesita)
RUN apt-get update && apt-get install -y --no-install-recommends \
        bzip2 \
        unzip \
        wget \
        git \
        ca-certificates \
        nano \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /

# --- SDK de Ren'Py (copiado local, no descargado) ------------------------
COPY archivos/renpy-${RENPY_VERSION}-sdk.tar.bz2 /tmp/renpy-sdk.tar.bz2
RUN tar -xjf /tmp/renpy-sdk.tar.bz2 -C / \
    && rm /tmp/renpy-sdk.tar.bz2

# --- RAPT (Ren'Py Android Packaging Tool) --------------------------------
# Se descomprime DENTRO del directorio del SDK, quedando como
# ${SDK_ROOT}/rapt/. Sin este paso, rapt/prototype no existe y falla el
# sed del wrapper de Gradle más abajo.
COPY archivos/renpy-${RENPY_VERSION}-rapt.zip /tmp/renpy-rapt.zip
RUN unzip -q /tmp/renpy-rapt.zip -d ${SDK_ROOT} \
    && rm /tmp/renpy-rapt.zip

# --- Gradle (copiado local) ----------------------------------------------
# El gradle-wrapper.properties de RAPT espera un archivo file:// (no una
# carpeta) para "instalarse" desde ahí.
COPY archivos/gradle-${GRADLE_VERSION}-bin.zip /opt/gradle-${GRADLE_VERSION}-bin.zip

# Parchamos el wrapper para que use el zip local en vez de descargar de
# services.gradle.org. Solo se parchea prototype/: es la plantilla maestra
# que RAPT usa para regenerar project/ en cada build, así que editar
# project/ directamente se perdería en la siguiente corrida de
# android_build.
RUN sed -i "s#distributionUrl=.*#distributionUrl=file\\\\:///opt/gradle-${GRADLE_VERSION}-bin.zip#" \
        ${SDK_ROOT}/rapt/prototype/gradle/wrapper/gradle-wrapper.properties \
    && sed -i "s#networkTimeout=.*#networkTimeout=60000#" \
        ${SDK_ROOT}/rapt/prototype/gradle/wrapper/gradle-wrapper.properties

# --- Android SDK Command-line Tools (copiado local) -----------------------
COPY archivos/cmdline-tools.zip /tmp/cmdline-tools.zip
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && cd ${ANDROID_SDK_ROOT}/cmdline-tools \
    && unzip -q /tmp/cmdline-tools.zip \
    && mv cmdline-tools latest \
    && rm /tmp/cmdline-tools.zip

# --- Aceptar licencias e instalar build-tools/platform -------------------
# Esto SÍ necesita red durante el `docker build` (paquetes de ~50-60MB,
# vía sdkmanager, no wget). Si tu conexión es inestable, considera:
#   - Correr el build con --network=host
#   - O reintentar el build (las capas anteriores ya quedan cacheadas)
# Con reintentos: la descarga de build-tools/platforms vía sdkmanager se
# ha cortado varias veces con "Connection reset" a media descarga. El
# loop reintenta hasta 5 veces antes de rendirse.
RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
        --licenses --sdk_root=${ANDROID_SDK_ROOT} > /dev/null \
    && for i in 1 2 3 4 5; do \
        ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
            --sdk_root=${ANDROID_SDK_ROOT} \
            "build-tools;${BUILD_TOOLS_VERSION}" \
            "platforms;${PLATFORM_VERSION}" \
            "platform-tools" && break; \
        echo ">> sdkmanager falló (intento $i/5), reintentando en 5s..."; \
        sleep 5; \
        if [ "$i" = "5" ]; then exit 1; fi; \
    done

# --- Script de entrada ---------------------------------------------------
COPY build-android.sh /usr/local/bin/build-android.sh
RUN chmod +x /usr/local/bin/build-android.sh

# --- Proyecto: se clona directamente de GitHub, no se monta por volumen -
# Esto hace la imagen totalmente autocontenida y reproducible: cualquiera
# que corra `docker build` obtiene exactamente el mismo código fuente
# (pineado por PROJECT_REF), sin depender de qué haya o no en el host.
#
# Para reconstruir con la última versión del repo, vuelve a correr
# `docker build` (sin cache si quieres forzar el pull más reciente):
#   docker build --no-cache -t renpy-android-builder .
#
# Para fijar una versión exacta (recomendado para releases reproducibles
# de verdad), usa un tag o commit en vez de una rama:
#   docker build --build-arg PROJECT_REF=v0.3.0 -t renpy-android-builder .
COPY . /project

WORKDIR /project

ENTRYPOINT ["/usr/local/bin/build-android.sh"]
