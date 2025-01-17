{
  inputs,
  lib,
  build,
  pkgs,
  pkgsCross,
  pkgsi686Linux,
  callPackage,
  fetchFromGitHub,
  fetchurl,
  moltenvk,
  supportFlags,
  stdenv_32bit,
}: let
  fetchurl = args @ {
    url,
    sha256,
    ...
  }:
    pkgs.fetchurl {inherit url sha256;} // args;

  gecko32 = fetchurl rec {
    version = "2.47.3";
    url = "https://dl.winehq.org/wine/wine-gecko/${version}/wine-gecko-${version}-x86.msi";
    sha256 = "00cfyjkqglfwbacb2kj6326hq7kywd2f0wifimm68mg37inv1fg5";
  };
  gecko64 = fetchurl rec {
    version = "2.47.3";
    url = "https://dl.winehq.org/wine/wine-gecko/${version}/wine-gecko-${version}-x86_64.msi";
    sha256 = "0xcn2g74b59l8fsah0wbvk4gnym9wbjgcic5sviiyv9b75afjgm5";
  };
  mono = fetchurl rec {
    version = "7.3.0";
    url = "https://dl.winehq.org/wine/wine-mono/${version}/wine-mono-${version}-x86.msi";
    sha256 = "1zr29qkfla8yb1z4sp1qmsvk66m149k441g3qw7hs3bjd5b2z7lk";
  };

  defaults = with pkgs; {
    inherit supportFlags moltenvk;
    patches = [];
    buildScript = "${inputs.nixpkgs}/pkgs/applications/emulators/wine/builder-wow.sh";
    configureFlags = ["--disable-tests"];
    geckos = [gecko32 gecko64];
    mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc mingwW64.buildPackages.gcc];
    monos = [mono];
    pkgArches = [pkgs pkgsi686Linux];
    platforms = ["x86_64-linux"];
    stdenv = stdenv_32bit;
    vkd3dArches = lib.optionals supportFlags.vkd3dSupport [vkd3d vkd3d_i686];
  };

  pnameGen = n: n + lib.optionalString (build == "full") "-full";

  vkd3d = pkgs.callPackage "${inputs.nixpkgs}/pkgs/applications/emulators/wine/vkd3d.nix" {inherit moltenvk;};
  vkd3d_i686 = pkgsi686Linux.callPackage "${inputs.nixpkgs}/pkgs/applications/emulators/wine/vkd3d.nix" {inherit moltenvk;};
in {
  wine-ge = let
    pname = pnameGen "wine-ge";
  in
    callPackage "${inputs.nixpkgs}/pkgs/applications/emulators/wine/base.nix" (defaults
      // {
        inherit pname;
        version = "7.0";
        src = fetchFromGitHub {
          owner = "GloriousEggroll";
          repo = "proton-wine";
          rev = "Proton7-29";
          hash = "sha256-IEsJ11TUlOx1ySVSk+P8j8LheWA7UZ2+HBsGLlAJWfQ=";
        };
      });

  wine-tkg = let
    pname = pnameGen "wine-tkg";
  in
    callPackage "${inputs.nixpkgs}/pkgs/applications/emulators/wine/base.nix" (defaults
      // {
        inherit pname;
        version = "7.13";
        src = fetchFromGitHub {
          owner = "Tk-Glitch";
          repo = "wine-tkg";
          rev = "e70427c7a3380068860279937d13501f59ff72ad";
          hash = "sha256-LqWSJNXYqbCYYo9tHfUkJmc3Nj+x8xWdiIJ6n9wKpKg=";
        };
      });

  wine-osu = let
    pname = pnameGen "wine-osu";
    version = "7.0";
    staging = fetchFromGitHub {
      owner = "wine-staging";
      repo = "wine-staging";
      rev = "v${version}";
      sha256 = "sha256-2gBfsutKG0ok2ISnnAUhJit7H2TLPDpuP5gvfMVE44o=";
    };
  in
    (callPackage "${inputs.nixpkgs}/pkgs/applications/emulators/wine/base.nix" (defaults
      // rec {
        inherit version pname;
        src = fetchFromGitHub {
          owner = "wine-mirror";
          repo = "wine";
          rev = "wine-${version}";
          sha256 = "sha256-uDdjgibNGe8m1EEL7LGIkuFd1UUAFM21OgJpbfiVPJs=";
        };
        patches = ["${inputs.nixpkgs}/pkgs/applications/emulators/wine/cert-path.patch"] ++ inputs.self.lib.mkPatches ./patches;
      }))
    .overrideDerivation (_: {
      prePatch = ''
        patchShebangs tools
        cp -r ${staging}/patches .
        chmod +w patches
        cd patches
        patchShebangs gitapply.sh
        ./patchinstall.sh DESTDIR="$PWD/.." --all ${lib.concatMapStringsSep " " (ps: "-W ${ps}") []}
        cd ..
      '';
    });
}
