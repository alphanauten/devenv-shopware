{ pkgs, config, inputs, lib, ... }:
let
  cfg = config.kellerkinder;

  listEntries = path:
    map (name: path + "/${name}") (builtins.attrNames (builtins.readDir path));
in {
  imports = [
    (lib.mkRenamedOptionModule [ "kellerkinder" "additionalServerAlias" ] [ "kellerkinder" "domains" ])
    (lib.mkRenamedOptionModule [ "kellerkinder" "fallbackRedirectMediaUrl" ] [ "kellerkinder" "fallbackMediaUrl" ])
  ] ++ (listEntries ./modules);

  options.kellerkinder = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Enables the Kellerkinder devenv environment";
      default = true;
    };

    phpVersion = lib.mkOption {
      type = lib.types.str;
      description = "PHP Version";
      default = "php81";
    };

    systemConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "shopware system config settings";
      default = { };
      example = {
        "foo.bar.testString" = "false";
      };
    };

    additionalPhpConfig = lib.mkOption {
      type = lib.types.str;
      description = "Additional php.ini configuration";
      default = "";
      example = ''
        memory_limit = 0
      '';
    };

    additionalPhpExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Additional PHP extensions";
      default = [ ];
      example = [ "mailparse" ];
    };

    additionalVhostConfig = lib.mkOption {
      type = lib.types.str;
      description = "Additional vhost configuration";
      default = "";
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Domains to be used for the vhost";
      default = [ ];
      example = [ "example.com" ];
    };

    enableElasticsearch = lib.mkOption {
      type = lib.types.bool;
      description = "Enables Elasticsearch";
      default = false;
    };

    enableRabbitMq = lib.mkOption {
      type = lib.types.bool;
      description = "Enables RabbitMQ";
      default = false;
    };

    importDatabaseDumps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of links to be imported with command importdb";
      default = [ ];
      example = [
        "http://localhost/dump.sql.gz"
        "http://localhost/dump.sql"
      ];
    };

    documentRoot = lib.mkOption {
      type = lib.types.str;
      description = "Sets the docroot of caddy";
      default = "public";
    };

    staticFilePaths = lib.mkOption {
      type = lib.types.str;
      description = ''Sets the matcher paths to be "ignored" by caddy'';
      default = "/theme/* /media/* /thumbnail/* /bundles/* /css/* /fonts/* /js/* /recovery/* /sitemap/*";
    };

    fallbackMediaUrl = lib.mkOption {
      type = lib.types.str;
      description = "Fallback redirect URL for media not found on local storage. Best for CDN purposes without downloading them.";
      default = "";
    };

    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Additional packages to be installed";
      default = [ ];
      example = [ pkgs.jpegoptim pkgs.optipng pkgs.gifsicle ];
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.jq
      pkgs.gnupatch
    ] ++ cfg.additionalPackages;

    languages.javascript = {
      enable = lib.mkDefault true;
      package = lib.mkDefault pkgs.nodejs-16_x;
    };

    services.adminer.enable = lib.mkDefault true;
    services.adminer.listen = lib.mkDefault "127.0.0.1:8010";

    services.elasticsearch.enable = cfg.enableElasticsearch;

    services.mailhog.enable = true;

    services.rabbitmq.enable = cfg.enableRabbitMq;
    services.rabbitmq.managementPlugin.enable = cfg.enableRabbitMq;

    services.redis.enable = lib.mkDefault true;

    # Environment variables
    env = lib.mkMerge [
      (lib.mkIf cfg.enable {
        DATABASE_URL = lib.mkDefault "mysql://shopware:shopware@127.0.0.1:3306/shopware";
        MAILER_URL = lib.mkDefault "smtp://127.0.0.1:1025?encryption=&auth_mode=";
        MAILER_DSN = lib.mkDefault "smtp://127.0.0.1:1025?encryption=&auth_mode=";

        APP_URL = lib.mkDefault "https://127.0.0.1:8000";
        CYPRESS_baseUrl = lib.mkDefault "https://127.0.0.1:8000";

        APP_SECRET = lib.mkDefault "devsecret";

        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD = true;
        DISABLE_ADMIN_COMPILATION_TYPECHECK = true;

        SHOPWARE_CACHE_ID = "dev";

        NODE_OPTIONS = "--openssl-legacy-provider --max-old-space-size=2000";
      })
      (lib.mkIf config.services.elasticsearch.enable {
        SHOPWARE_ES_ENABLED = "1";
        SHOPWARE_ES_INDEXING_ENABLED = "1";
        SHOPWARE_ES_HOSTS = "127.0.0.1";
        SHOPWARE_ES_THROW_EXCEPTION = "1";
      })
      (lib.mkIf config.services.rabbitmq.enable {
        RABBITMQ_NODENAME = "rabbit@localhost"; # 127.0.0.1 can't be used as rabbitmq can't set short node name
        MESSENGER_TRANSPORT_DSN = "amqp://guest:guest@localhost:5672/%2f";
      })
      (lib.mkIf config.services.redis.enable {
        REDIS_DSN = "redis://127.0.0.1:6379";
      })
    ];
  };
}
