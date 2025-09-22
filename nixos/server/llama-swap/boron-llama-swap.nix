{
  macros = {
    "llama-server" = ''
      /run/current-system/sw/bin/llama-server
      --port ''${PORT}
      --no-webui
    '';
  };

  models = {
    "qwen-embedding" = {
      cmd = ''
        ''${llama-server}
        -hf Mungert/Qwen3-Embedding-0.6B-GGUF:Q6_K_M
        -ngl 999
        --pooling last
        --embedding
        -c 512
      '';
      ttl = 300;
    };

    "embeddinggemma" = {
      cmd = ''
        ''${llama-server}
        -hf unsloth/embeddinggemma-300m-GGUF:Q8_0
        -ngl 999
        --embedding
        -c 512
      '';
      ttl = 300;
    };

    "gemma-3n-e4b" = {
      cmd = ''
        ''${llama-server}
        -hf unsloth/gemma-3n-E4B-it-GGUF:Q4_K_M
        -ngl 999
        -c 4096
        --temp 1.0
        --top-k 64
        --min-p 0
        --top-p 0.95
      '';
      ttl = 180;
    };

    "qwen3-4b" = {
      cmd = ''
        ''${llama-server}
        -hf unsloth/Qwen3-4B-Instruct-2507-GGUF:Q4_K_M
        -c 3072
        -ngl 999
        -fa on
        --temp 0.7
        --top-k 20
        --min-p 0
        --top-p 0.80
        --presence-penalty 0.5
      '';
      ttl = 180;
    };

    "gemma-3n-e2b" = {
      cmd = ''
        ''${llama-server}
        -hf unsloth/gemma-3n-E2B-it-GGUF:Q4_K_M
        -c 8192
        --temp 1.0
        --top-k 64
        --min-p 0
        --top-p 0.95
      '';
      ttl = 180;
    };

    "qwen3-1.7b" = {
      cmd = ''
        ''${llama-server}
        -hf unsloth/Qwen3-1.7B-GGUF:Q5_K_XL
        -c 16384
        --temp 0.7
        --top-k 20
        --min-p 0
        --top-p 0.80
        --presence-penalty 0.5
      '';
      ttl = 300;
    };

    "qwen3-0.6b" = {
      cmd = ''
        ''${llama-server}
        -hf unsloth/Qwen3-0.6B-GGUF:Q5_K_XL
        -c 16384
        --temp 0.7
        --top-k 20
        --min-p 0
        --top-p 0.80
        --presence-penalty 0.5
      '';
      ttl = 300;
    };
  };

  groups = {
    "embedding" = {
      swap = true;
      exclusive = false;
      persistent = true;
      members = [
        "qwen-embedding"
        "embeddinggemma"
      ];
    };
  };
}
