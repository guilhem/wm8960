{ lib, alsa-lib, buildPackages, kernelPackages, src }:
let
  kernel = kernelPackages.kernel;
in
kernel.stdenv.mkDerivation {
  pname = "tagtagtag-sound";
  version = "unstable";
  inherit src;

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    buildPackages.dtc buildPackages.kmod
  ];
  buildInputs = [ alsa-lib ];
  hardeningDisable = [ "pic" "format" ];
  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      ${lib.concatStringsSep " " kernelPackages.kernelModuleMakeFlags} \
      M="$PWD" -j"$NIX_BUILD_CORES" modules
    dtc -@ -I dts -O dtb -o tagtagtag-sound.dtbo tagtagtag-sound-overlay.dts
    $CC -Wall -Werror tagtagtag-mixerd.c -lasound -lpthread -o tagtagtag-mixerd
    runHook postBuild
  '';

  doCheck = kernel.stdenv.buildPlatform.canExecute kernel.stdenv.hostPlatform;
  checkPhase = ''
    runHook preCheck
    $CC -Wall -Werror -DTEST tagtagtag-mixerd.c -lasound -lpthread -o tagtagtag-mixerd-test
    ./tagtagtag-mixerd-test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    for module in snd-soc-wm8960 snd-soc-max9759; do
      # A successful compile alone is insufficient if a different kernel was used.
      test "$(modinfo -F vermagic "$module.ko" | cut -d ' ' -f1)" = ${lib.escapeShellArg kernel.modDirVersion}
      install -Dm644 "$module.ko" "$out/lib/modules/${kernel.modDirVersion}/extra/$module.ko"
    done
    install -Dm644 tagtagtag-sound.dtbo "$out/overlays/tagtagtag-sound.dtbo"
    install -m644 tagtagtag-sound-overlay.dts "$out/overlays/tagtagtag-sound-overlay.dts"
    install -Dm755 tagtagtag-mixerd "$out/bin/tagtagtag-mixerd"
    install -Dm644 mixer.conf.default "$out/share/tagtagtag-sound/mixer.conf.default"
    install -Dm644 60-tagtagtag-volume.rules "$out/lib/udev/rules.d/60-tagtagtag-volume.rules"
    runHook postInstall
  '';

  passthru = { inherit kernel; kernelVersion = kernel.modDirVersion; };
  meta.platforms = lib.platforms.linux;
}
