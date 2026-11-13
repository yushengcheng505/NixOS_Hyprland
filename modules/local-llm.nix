{ config, lib, pkgs, ... }:

let
  bonsaiDir = "${config.users.users.klenko.home}/Bonsai-demo";
  llamaServer = "${bonsaiDir}/bin/vulkan/llama-server";
  model = "${bonsaiDir}/models/bonsai2-gguf/9B/Ternary-Bonsai-2-9B-PQ2_0-MTP-Q8_0.gguf";

  args = [
    "-m" model
    "--host" "127.0.0.1"
    "--port" "8080"
    "-ngl" "99"
    "-fa" "on"
    "-c" "32768"
    "-np" "1"
    "--jinja"
    "--spec-type" "draft-mtp"
    "--spec-draft-n-max" "2"
    "--spec-draft-n-min" "0"
    "--spec-draft-p-min" "0"
    "--temp" "0.7"
    "--top-p" "0.8"
    "--top-k" "20"
    "--min-p" "0"
    "--presence-penalty" "1.5"
    "--repeat-penalty" "1"
    "--repeat-last-n" "64"
    "--samplers" "top_k;penalties;top_p;min_p;temperature"
    "--chat-template-kwargs" ''{"enable_thinking":false}''
  ];
in
{
  environment.systemPackages = [ pkgs.vulkan-tools ];

  systemd.user.services.bonsai-llm = {
    unitConfig = {
      Description = "Ternary-Bonsai-2-9B via PrismML llama-server (Vulkan)";
      ConditionUser = "klenko";
      ConditionPathExists = [ llamaServer model ];
    };
    serviceConfig = {
      WorkingDirectory = bonsaiDir;
      ExecStart = pkgs.writeShellScript "bonsai-llm" ''
        exec ${llamaServer} ${lib.escapeShellArgs args}
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
