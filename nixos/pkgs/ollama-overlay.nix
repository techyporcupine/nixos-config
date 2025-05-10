self: super: {
  ollama = super.ollama.overrideAttrs (old: {
    cmakeFlags =
      (old.cmakeFlags or [])
      ++ [
        "-DCMAKE_CUDA_ARCHITECTURES=50;52"
        "-DLLAMA_CUDA_FORCE_MMQ=on"
      ];
  });
}
