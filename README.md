# Royal Egoist
*Royal Egoist* es una novela visual de romance ambientada en la Edad Media, con varios reinos en los que podrás ayudar y enamorar a tus egoístas favoritos. 
Cuenta con reinos inspirados en las civilizaciones medievales de Japón, Inglaterra, Francia y Alemania.
- [Pagina Oficial](https://studio-newtopia.web.app)

## Licencia
- **Código Fuente:** Licenciado bajo [GNU General Public License v3.0](LICENSE).
- **Arte, Música, Guión y Sonido:** Licenciado bajo [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International (CC BY-NC-ND 4.0)](https://creativecommons.org/licenses/by-nc-nd/4.0/).

## Equipo
- **Programadores:**
  - **BryLang**
- **Diseñadores:**
  - **BryLang**
- **Artistas:**
  - **Damzelette**
  - **Hyuna**
  - **LenVainilla**
  - **Yam**
  - **Yuko**
- **Guionistas:**
  - **Axel**
  - **BryLang**
  - **Hyuna**
  - **LenVainilla**
  - **Ness**
  - **Skull**
  - **Yam**
  - **Yuko**
- **Doblaje:**
  - **Jhoan**
  - **Blexx**
  - **Fan**
  - **Daichi**
  - **Grokz**
  - **Loki**
  - **Marialin**
  - **MiseriSixSeven**
  - **Sinyo**
- **Testers:**
  - **Mirko**

## Build de Android con Ren'Py (Docker)

Este Dockerfile compila el proyecto de Ren'Py a un APK de Android de forma
reproducible, usando Docker.

### Preparación (una sola vez)

Los archivos grandes del SDK/Gradle/cmdline-tools **no están en este repo**
(son binarios de terceros, ~500MB en total). Descárgalos así antes de
compilar:

```bash
mkdir -p archivos && cd archivos

wget -c "https://www.renpy.org/dl/8.5.3/renpy-8.5.3-sdk.tar.bz2"
wget -c "https://www.renpy.org/dl/8.5.3/renpy-8.5.3-rapt.zip"
wget -c "https://services.gradle.org/distributions/gradle-9.1.0-bin.zip"
wget -c "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -O cmdline-tools.zip

cd ..
```

(`-c` permite reanudar si se corta la descarga a medio camino.)

### Build

```bash
docker build -t renpy-android-builder .
```

### Run

```bash
docker run --rm -v $(pwd)/dist:/dist renpy-android-builder
```

El APK generado queda en `./dist/`.

### Notas

- Si necesitas otra versión de Ren'Py, Gradle o cmdline-tools, actualiza
  los `ARG` correspondientes en el `Dockerfile` y vuelve a descargar los
  archivos con los nombres/versiones nuevos en `assets/`.
- La keystore de firma se genera automáticamente (de prueba) si no existe.
  Para publicar de verdad, genera tu propia keystore segura y móntala en
  vez de dejar que el script cree una nueva — ver comentarios en
  `build-android.sh`.
