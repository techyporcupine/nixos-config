self: super: {
  ollama = super.ollama.overrideAttrs (old: {
    buildInputs = (old.buildInputs or []) ++ [super.cudatoolkit];

    cmakeFlags =
      (old.cmakeFlags or [])
      ++ [
        "-DLLAMA_CUBLAS=on"
        "-DLLAMA_ACCELERATE=on"
        "-DLLAMA_K_QUANTS=on"
        "-DCMAKE_CUDA_ARCHITECTURES=50;52"
        "-DLLAMA_CUDA_FORCE_MMQ=on"
      ];

    postBuild = ''
      # Create build directories
      mkdir -p gglm/build/cuda ggu/build/cuda

      # Generate build system for gglm
      cmake -S gglm -B gglm/build/cuda -DLLAMA_CUBLAS=on -DLLAMA_ACCELERATE=on -DLLAMA_K_QUANTS=on
      cmake --build gglm/build/cuda --target server --config Release
      mv gglm/build/cuda/bin/server gglm/build/cuda/bin/ollama-runner

      # Generate build system for ggu
      cmake -S ggu -B ggu/build/cuda -DLLAMA_CUBLAS=on -DLLAMA_ACCELERATE=on -DLLAMA_K_QUANTS=on
      cmake --build ggu/build/cuda --target server --config Release
      mv ggu/build/cuda/bin/server ggu/build/cuda/bin/ollama-runner

      # Final build step
      cd ../..
      go generate ./...
      go build .
    '';
  });
}
