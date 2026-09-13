# Contains code from https://github.com/NixOS/nixpkgs/pull/132275, proposed by emilytrau 🏳️‍⚧️
{
  python3,
  lib,
  stdenv,
  autoPatchelfHook,
  fetchpatch,
  zip,
  unzip,
  fetchPypi,
}: let
  pname = "mediapipe";
  version = "0.10.33";
  format = "wheel";
in
  python3.pkgs.buildPythonPackage {
    inherit pname version format;

    src = fetchPypi ({
        inherit pname version format;
        python = "py3";
        dist = "py3";
        abi = "none";
      }
      // {
        "x86_64-linux" = {
          platform = "manylinux_2_28_x86_64";
          sha256 = "sha256-QQ55YhXZ6yzx/dauy/QWq6tudKXupVcvS22pRljHZNk=";
        };
      }.${
        stdenv.system
      });

    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [unzip zip autoPatchelfHook];
    propagatedBuildInputs = with python3.pkgs; [
      absl-py
      attrs
      jax
      jaxlib
      numpy
      sounddevice
      # Working around nixos/nixpkgs#418899
      (protobuf4.overrideAttrs (oldAttrs: {
        patches =
          oldAttrs.patches
          ++ [
            (fetchpatch {
              name = "4-tests-missing-proto.patch";
              url = "https://raw.githubusercontent.com/kirelagin/nixpkgs/eb83e76382da36cb698e8f27b75f61a489a008b8/pkgs/development/python-modules/protobuf/4-tests-missing-proto.patch";
              hash = "sha256-TBuhlWXNQjRI8XmW74gZWKJ9DDWj1DjUVCh7rki5vY8=";
            })
            (fetchpatch {
              name = "4-tests-numpy-index.patch";
              url = "https://raw.githubusercontent.com/kirelagin/nixpkgs/eb83e76382da36cb698e8f27b75f61a489a008b8/pkgs/development/python-modules/protobuf/4-tests-numpy-index.patch";
              hash = "sha256-F9JJWwzdalSclC4gdILslukJE6Fh2i0EOVXFitIdScE=";
            })
          ];
      }))
      flatbuffers
      matplotlib
      opencv-contrib-python
    ];

    postPatch = ''
      # Patch out requirement for static opencv and numpy so we can substitute it with the nix version
      METADATA=mediapipe-${version}.dist-info/METADATA
      unzip $src $METADATA
      substituteInPlace $METADATA \
        --replace "Requires-Dist: opencv-contrib-python" ""
      substituteInPlace $METADATA \
        --replace "Requires-Dist: numpy<2" ""
      chmod +w dist/*.whl
      zip -r dist/*.whl $METADATA
    '';

    pythonImportsCheck = [
      "mediapipe"
    ];

    meta = with lib; {
      description = "Cross-platform, customizable ML solutions for live and streaming media";
      homepage = "https://ai.google.dev/edge/mediapipe";
      license = licenses.asl20;
      platforms = [ "x86_64-linux" ];
    };
  }
