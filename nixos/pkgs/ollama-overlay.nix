# Save this as ollama-overlay.nix
final: prev: {
  ollama = prev.ollama.overrideAttrs (oldAttrs: {
    buildPhase = ''
      # Set custom CUDA flags
      export OLLAMA_CUSTOM_CUDA_DEFS="-DLLAMA_CUDA_FORCE_MMQ=on"

      # Use the original build phase
      ${oldAttrs.buildPhase}
    '';

    # Add any other necessary environment variables
    preBuild = ''
      export LLAMA_CUDA_FORCE_MMQ=on
    '';
  });
}
