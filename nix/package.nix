# Parts of https://github.com/puzzler995/katpkgs is referenced for this file.
# katpkgs is licensed under GPL v3.
{
  autoPatchelfHook,
  writableTmpDirAsHomeHook,
  stdenv,
  version,
  godotPackages_4_6,
  fetchpatch,
  lib,
  callPackage,
  python3,
  libGL,
  vulkan-loader,
  libX11,
  libXcursor,
  libXext,
  libXi,
  libXrandr,
  makeWrapper,
  zip,
  unzip,
  fetchPypi,
  makeDesktopItem,
  copyDesktopItems,
  wayland,
}:
stdenv.mkDerivation (finalAttrs: let
  hostPlatform = stdenv.hostPlatform;
  platform = "${hostPlatform.uname.system}-${hostPlatform.linuxArch}";
  mediapipe = callPackage ./mediapipe.nix {
    inherit
      python3
      lib
      stdenv
      autoPatchelfHook
      fetchpatch
      zip
      unzip
      fetchPypi
      ;
  };
  trackerPython =
    python3.withPackages
    (ps: [mediapipe ps.psutil ps.cv2-enumerate-cameras ps.numpy]);
in {
  pname = "snekstudio";
  inherit version;

  src = ./..;

  nativeBuildInputs = [
    autoPatchelfHook
    writableTmpDirAsHomeHook
    copyDesktopItems
    makeWrapper
    godotPackages_4_6.godot
  ];

  runtimeDependencies = [
    trackerPython
    wayland
    libGL
    vulkan-loader
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
  ];

  patches = [
    ./deref-pycache.diff
    ./embed-pck.diff
    ./config-home-dir.diff

    # As mediapipe moved away from python _framework bindings for the facial landmark tracking
    # since 0.10.32, frames_queued_mutex is no longer needed.
    ./mediapipe-queue-mutex-delete.diff
  ];

  buildPhase = ''
    runHook preBuild

    VERSION=${version}

    ln -s ${godotPackages_4_6.export-templates-bin} $HOME/.local

    echo ${trackerPython}

    mkdir -p $out/bin
    sed -i "s#_build_wrangler.get_runtime_python_executable_system_path()#\"${trackerPython}/bin/python3\"#g" addons/KiriPythonRPCWrapper/KiriPythonWrapperInstance.gd

    godot --headless --import

    godot --headless --export-release "${platform}" Build/Builds/snekstudio

    runHook postBuild
  '';

  desktopItems = [
    (
      makeDesktopItem {
        name = "snekstudio";
        desktopName = "SnekStudio";
        genericName = "VTuber Software";
        comment = "Open-source VTuber software";
        exec = "snekstudio";
        icon = "com.snekstudio.Snekstudio";
        terminal = false;
        categories = ["Video" "AudioVideo"];
        startupNotify = true;
        startupWMClass = "SnekStudio";
      }
    )
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/snekstudio
    cd ./Build/Builds

    find Mods -type f -exec install -Dm 644 {} $out/lib/snekstudio/{} \;
    find SampleModels -type f -exec install -Dm 644 {} $out/lib/snekstudio/{} \;

    install -D -m 755 snekstudio $out/bin/snekstudio

    wrapProgram $out/bin/snekstudio \
      --set SNEKSTUDIO_SAMPLE_PATH $out/lib/snekstudio/SampleModels \
      --set SNEKSTUDIO_MODS_PATHS $out/lib/snekstudio/Mods

    runHook postInstall
  '';

  meta = with lib; {
    description = " Open-source VTuber software using Godot Engine!";
    homepage = "https://snekstudio.com/";
    license = licenses.gpl3;
    platforms = ["x86_64-linux"];
  };
})
