# Firebase Studio / Project IDX Nix configuration
{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.jdk17
    pkgs.unzip
  ];

  env = {
    JAVA_HOME = "${pkgs.jdk17}";
  };

  idx = {
    extensions = [
      "Dart-Code.dart-code"
      "Dart-Code.flutter"
    ];

    workspace = {
      onCreate = {
        build = ''
          cd "$WS_DIR"
          flutter pub get
        '';
      };
    };

    # ONLY Android preview - tflite_flutter does NOT support web (uses dart:ffi)
    previews = {
      enable = true;
      previews = {
        android = {
          command = [
            "flutter"
            "run"
            "--machine"
            "-d"
            "android"
            "-d"
            "localhost:5555"
          ];
          manager = "flutter";
        };
      };
    };
  };
}
