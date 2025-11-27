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
        # Replace ExternalProject_Add with our pre-built llguidance
        substituteInPlace common/CMakeLists.txt \
          --replace-fail 'if (LLAMA_LLGUIDANCE)' \
                         'if (LLAMA_LLGUIDANCE)
    # Use pre-built llguidance from Nix
    set(LLGUIDANCE_PATH ${llguidance}/lib)
    add_library(llguidance STATIC IMPORTED)
    set_target_properties(llguidance PROPERTIES IMPORTED_LOCATION ''${LLGUIDANCE_PATH}/libllguidance.a)
    target_include_directories(''${TARGET} PRIVATE ${llguidance}/include)
    set(LLAMA_COMMON_EXTRA_LIBS ''${LLAMA_COMMON_EXTRA_LIBS} llguidance)
    target_compile_definitions(''${TARGET} PUBLIC LLAMA_USE_LLGUIDANCE)
if (FALSE) # Disable the ExternalProject_Add'
        
        # Close the if(FALSE) block
        substituteInPlace common/CMakeLists.txt \
          --replace-fail 'endif ()' \
                         'endif() # FALSE
endif () # LLAMA_LLGUIDANCE'
      '';
    });
in {
  # --- Base Packages (Portable builds) ---

  # 1. Base CPU-only package from the upstream flake's overlay.
  llama-cpp-cpu = (inputs.llama-cpp.overlays.default final prev).llamaPackages.llama-cpp;

  # 2. Base Vulkan-accelerated package.
  llama-cpp-vulkan = final.llama-cpp-cpu.override {useVulkan = true;};

  # 3. Base CUDA-accelerated package.
  # This one is special, as it comes from the flake's CUDA-specific pkgs set.
  llama-cpp-cuda = inputs.llama-cpp.legacyPackages.${system}.llamaPackagesCuda.llama-cpp;

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
