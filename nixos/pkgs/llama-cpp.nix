# File: ./nixos/overlays/llama-cpp.nix
#
# This overlay provides a comprehensive set of `llama-cpp` packages using the
# official `llama-cpp` flake. It provides standard builds and versions that are
# additionally optimized for the host CPU's native instruction set (AVX, FMA, etc.).
{
  inputs,
  lib,
  ...
}: final: prev: let
  system = prev.stdenv.hostPlatform.system;
  llamaOverlay = inputs.llama-cpp.overlays.default final prev;
  llamaPackages = llamaOverlay.llamaPackages;

  # Helper function to apply native CPU optimizations to any llama.cpp package.
  # This avoids repeating the same overrideAttrs logic for each variant.
  withNativeCpu = pkg:
    pkg.overrideAttrs (old: {
      # Append a suffix for clarity in the Nix store path
      pname = old.pname + "-native";

      # Remove the generic flag and add the native optimization flag.
      cmakeFlags =
        (lib.lists.filter (flag: flag != "-DGGML_NATIVE=false") old.cmakeFlags)
        ++ [
          "-DGGML_NATIVE=ON"
        ];
      NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -O3 -march=native -mtune=native";
      NIX_CXXSTDLIB_COMPILE = (old.NIX_CXXSTDLIB_COMPILE or "") + " -O3 -march=native -mtune=native";
    });

  # Helper function to enable HTTPS support for HF downloads and embed the WebUI
  # Note: LLAMA_CURL is deprecated in recent llama.cpp versions in favor of
  # LLAMA_OPENSSL which enables HTTPS support in the internal httplib.
  withHttps = pkg:
    let
      uiAssets = {
        "index.html" = prev.fetchurl {
          url = "https://huggingface.co/buckets/ggml-org/llama-ui/resolve/latest/index.html?download=true";
          sha256 = "3ea56dac69456ecc2f31ad84d9e912155ae37f247a248d7f28107a22d6bc4af3";
        };
        "bundle.js" = prev.fetchurl {
          url = "https://huggingface.co/buckets/ggml-org/llama-ui/resolve/latest/bundle.js?download=true";
          sha256 = "c3f935c41f489d95e64c1ec4229f5bafffc000bf4e2aac8d3ea98be683d9f9e1";
        };
        "bundle.css" = prev.fetchurl {
          url = "https://huggingface.co/buckets/ggml-org/llama-ui/resolve/latest/bundle.css?download=true";
          sha256 = "02bfcb5fe93f75c39ccd7da36cc24fa21eecfdd1cfeee0ebe64d98ff26b27e93";
        };
        "loading.html" = prev.fetchurl {
          url = "https://huggingface.co/buckets/ggml-org/llama-ui/resolve/latest/loading.html?download=true";
          sha256 = "2500057e39ab81518d16b28f5d019f6107b58abb47b2a30d33862d9e7b703cdc";
        };
      };
    in
      pkg.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
        buildInputs = (old.buildInputs or [ ]) ++ [ prev.openssl ];
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DLLAMA_OPENSSL=ON"
          "-DLLAMA_HTTPLIB=ON"
          "-DLLAMA_BUILD_UI=ON"
        ];
        preConfigure = (old.preConfigure or "") + ''
          mkdir -p build/tools/ui/dist
          cp ${uiAssets."index.html"} build/tools/ui/dist/index.html
          cp ${uiAssets."bundle.js"} build/tools/ui/dist/bundle.js
          cp ${uiAssets."bundle.css"} build/tools/ui/dist/bundle.css
          cp ${uiAssets."loading.html"} build/tools/ui/dist/loading.html
        '';
      });

  # Build llguidance as a proper Rust package
  # NOTE: When llama.cpp updates, you may need to update the rev and hashes below
  # Run: misc/update-llguidance.sh to automatically update this
  llguidance = prev.rustPlatform.buildRustPackage rec {
    pname = "llguidance";
    version = "1.0.1";

    src = prev.fetchFromGitHub {
      owner = "guidance-ai";
      repo = "llguidance";
      rev = "d795912fedc7d393de740177ea9ea761e7905774"; # v1.0.1
      hash = "sha256-LiardZnaXD5kc+p9c+UYBbtBb7+2ycWqEGCp3aaqHBs=";
    };

    cargoHash = "sha256-VyLTa+1iEY/Z3/4DUIAcjHH0MxLMGtlpcsy2zvmg3b8=";

    nativeBuildInputs = [prev.pkg-config];
    buildInputs = [prev.oniguruma prev.openssl];

    env = {
      RUSTONIG_SYSTEM_LIBONIG = true;
    };

    buildAndTestSubdir = ".";
    cargoBuildFlags = ["--package" "llguidance"];

    postInstall = ''
      mkdir -p $out/include
      cp parser/llguidance.h $out/include/
    '';

    doCheck = false;
  };

  # Helper function to enable llguidance support
  withLlguidance = pkg:
    pkg.overrideAttrs (old: {
      pname = old.pname + "-llguidance";

      buildInputs = (old.buildInputs or []) ++ [llguidance];

      cmakeFlags = (old.cmakeFlags or []) ++ ["-DLLAMA_LLGUIDANCE=ON"];

      postPatch = (old.postPatch or "") + ''
        # Replace the entire LLAMA_LLGUIDANCE block with one using pre-built llguidance from Nix
        sed -i '/^if (LLAMA_LLGUIDANCE)/,/^endif()/{
          /^if (LLAMA_LLGUIDANCE)/c\
if (LLAMA_LLGUIDANCE)\
    # Use pre-built llguidance from Nix\
    add_library(llguidance STATIC IMPORTED)\
    set_target_properties(llguidance PROPERTIES IMPORTED_LOCATION ${llguidance}/lib/libllguidance.a)\
    target_include_directories(''${TARGET} PRIVATE ${llguidance}/include)\
    target_link_libraries(''${TARGET} PRIVATE llguidance)\
    target_compile_definitions(''${TARGET} PUBLIC LLAMA_USE_LLGUIDANCE)\
    if (WIN32)\
        target_link_libraries(''${TARGET} PRIVATE ws2_32 userenv ntdll bcrypt)\
    endif()
          /^if (LLAMA_LLGUIDANCE)/!{/^endif()/!d}
        }' common/CMakeLists.txt
      '';
    });
in {
  # --- Base Packages (Portable builds) ---

  # 1. Base CPU-only package from the upstream flake's overlay.
  llama-cpp-cpu = withHttps llamaPackages.llama-cpp;

  # 2. Base Vulkan-accelerated package.
  llama-cpp-vulkan = withHttps (llamaPackages.llama-cpp.override {useVulkan = true; useRocm = false; });

  # 3. Base CUDA-accelerated package.
  # Build directly from the CPU package to ensure we reuse the main nixpkgs
  # configuration, including allowUnfree, instead of the upstream CUDA instance.
  llama-cpp-cuda = withHttps (llamaPackages.llama-cpp.override {useCuda = true; useRocm = false; useVulkan = false; });

  # --- Native-Optimized Packages ---

  # 1n. Native-optimized CPU-only package.
  llama-cpp-cpu-native = withNativeCpu final.llama-cpp-cpu;

  # 2n. Native-optimized Vulkan package (for Intel/AMD GPUs).
  llama-cpp-vulkan-native = withNativeCpu final.llama-cpp-vulkan;

  # 3n. Native-optimized CUDA package (for NVIDIA GPUs).
  llama-cpp-cuda-native = withNativeCpu final.llama-cpp-cuda;

  # --- LLGuidance-Enabled Packages ---

  # 1g. CPU-only with llguidance support.
  llama-cpp-cpu-llguidance = withLlguidance final.llama-cpp-cpu;

  # 2g. Vulkan with llguidance support.
  llama-cpp-vulkan-llguidance = withLlguidance final.llama-cpp-vulkan;

  # 3g. CUDA with llguidance support.
  llama-cpp-cuda-llguidance = withLlguidance final.llama-cpp-cuda;

  # --- Combined: Native + LLGuidance ---

  # 1ng. Native-optimized CPU-only with llguidance.
  llama-cpp-cpu-native-llguidance = withLlguidance final.llama-cpp-cpu-native;

  # 2ng. Native-optimized Vulkan with llguidance.
  llama-cpp-vulkan-native-llguidance = withLlguidance final.llama-cpp-vulkan-native;

  # 3ng. Native-optimized CUDA with llguidance.
  llama-cpp-cuda-native-llguidance = withLlguidance final.llama-cpp-cuda-native;

  # --- A Sensible Default ---

  # For convenience, `pkgs.llama-cpp` will point to the most common optimized build.
  # Anyone building from source on their own machine likely wants this.
  llama-cpp = final.llama-cpp-cpu-native;
}
