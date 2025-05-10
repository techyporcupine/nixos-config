self: super: {
  ollama = super.ollama.overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or []) ++ ["-DCMAKE_CUDA_ARCHITECTURES=50"];
  });
}
