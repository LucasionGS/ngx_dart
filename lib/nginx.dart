import "dart:io";
import 'package:ngx_dart/models/vhost.dart';
import "package:yaml/yaml.dart";

final homeDirectory = Platform.environment["HOME"] ?? "~";

class Nginx {
  late final Directory toolConfigDir;
  late final File toolConfig;
  String nginxDir="/etc/nginx";
  String vhosts="/var/www/vhosts";
  String logs="/var/www/log";
  String nginxSitesAvailable() => "$nginxDir/sites-available";
  String nginxSitesEnabled() => "$nginxDir/sites-enabled";

  Nginx() {
    toolConfigDir = Directory.fromUri(Uri(path: "$homeDirectory/.ngx"));
    toolConfig = File.fromUri(Uri(path: "${toolConfigDir.path}/config.yml"));

    if (toolConfig.existsSync()) {
      var config = loadYaml(toolConfig.readAsStringSync());
      if (config["nginxDir"] != null) nginxDir = config["nginxDir"];
      if (config["vhosts"] != null) vhosts = config["vhosts"];
      if (config["logs"] != null) logs = config["logs"];
    }
    else {
      toolConfig.createSync(recursive: true);
    }
    
    if (!Directory.fromUri(Uri.file(nginxDir)).existsSync()) {
      throw Exception("Nginx directory does not exist");
    }
  }

  Map<String, String> get templates {
    final templateFilesPath = Directory.fromUri(
      Uri.file("$nginxDir/_templates"),
    );
    var templates = <String, String>{};
    if (templateFilesPath.existsSync()) {
      templateFilesPath.listSync().forEach((file) {
        if (file is File) {
          templates[file.uri.pathSegments.last] = file.readAsStringSync();
        }
      });
    }
    return templates..addAll(premadeTemplates);
  }

  String replaceVariables(String template, Map<String, String> variables) {
    variables.forEach((key, value) {
      template = template.replaceAll("{{$key}}", value);
    });
    return template;
  }

  void createVhost(String name, { String template = "base" }) {
    var vhostDir = Directory.fromUri(Uri.file("$vhosts/$name"));
    if (!vhostDir.existsSync()) {
      vhostDir.createSync(recursive: true);
    }
    var vhostLogDir = Directory.fromUri(Uri.file("$logs/$name"));
    if (!vhostLogDir.existsSync()) {
      vhostLogDir.createSync(recursive: true);
    }
    var vhostLog = File.fromUri(Uri.file("$logs/$name/access.log"));
    if (!vhostLog.existsSync()) {
      vhostLog.createSync(recursive: true);
    }
    var vhostErrorLog = File.fromUri(Uri.file("$logs/$name/error.log"));
    if (!vhostErrorLog.existsSync()) {
      vhostErrorLog.createSync(recursive: true);
    }
    var vhostConfig = File.fromUri(Uri.file("${nginxSitesAvailable()}/$name.conf"));
    if (!vhostConfig.existsSync()) {
      vhostConfig.createSync(recursive: true);

      var vhostConfigTemplate = templates[template] ?? templates["base"]!;
      
      vhostConfig.writeAsStringSync(
        replaceVariables(
          vhostConfigTemplate,
          {
            "server_name": name,
            "vhosts_path": vhosts,
            "log_path": logs,
          }
        )
      );
    }
  }

  void deleteVhost(Vhost host) {
    var vhostDir = Directory.fromUri(Uri.file("$vhosts/${host.name}"));
    if (vhostDir.existsSync()) {
      vhostDir.deleteSync(recursive: true);
    }
    var vhostLogDir = Directory.fromUri(Uri.file("$logs/${host.name}"));
    if (vhostLogDir.existsSync()) {
      vhostLogDir.deleteSync(recursive: true);
    }
    host.disable();
    var vhostConfig = host.config;
    if (vhostConfig.existsSync()) {
      vhostConfig.deleteSync();
    }
  }

  List<Vhost> listVhosts() {
    var vhosts = <Vhost>[];
    Directory.fromUri(Uri.directory(nginxSitesAvailable())).listSync().forEach((file) {
      if (file is File) {
        vhosts.add(Vhost(this, file));
      }
    });
    return vhosts;
  }

  Vhost? getVhost(String name) {
    try {
      return listVhosts().firstWhere((vhost) => vhost.name == name);
    } catch (e) {
      return null;
    }
  }

  void enableVhost(Vhost host) {
    var vhostConfig = File.fromUri(Uri.file("${nginxSitesAvailable()}/${host.name}.conf"));
    var vhostConfigEnabled = Link.fromUri(Uri.file("${nginxSitesEnabled()}/${host.name}.conf"));
    if (!vhostConfigEnabled.existsSync()) {
      vhostConfigEnabled.createSync(vhostConfig.path, recursive: true);
    }
  }

  void disableVhost(Vhost host) {
    var vhostConfigEnabled = Link.fromUri(Uri.file("${nginxSitesEnabled()}/${host.name}.conf"));
    if (vhostConfigEnabled.existsSync()) {
      vhostConfigEnabled.deleteSync();
    }
  }

  void reload() {
    ensureRoot();
    Process.runSync("systemctl", ["reload", "nginx"]);
  }

  void restart() {
    ensureRoot();
    Process.runSync("systemctl", ["restart", "nginx"]);
  }

  String getRoot(Vhost host) {
    var config = host.config.readAsStringSync();
    var root = RegExp(r"root\s+(.+);").firstMatch(config)?.group(1);
    if (root == null) {
      throw Exception("Could not find root for vhost ${host.name}");
    }
    return root;
  }
}

void ensureRoot() {
  if (Platform.isWindows) return;
  if (Process.runSync("id", ["-u"]).stdout.toString().trim() != "0") {
    throw Exception("You must be root to run this command");
  }
}

const premadeTemplates = {
  "base": """
server {
  listen 80;

  server_name {{server_name}};

  root {{vhosts_path}}/{{server_name}};

  index index.html index.htm index.php;

  charset utf-8;

  location = /favicon.ico { access_log off; log_not_found off; }
  location = /robots.txt  { access_log off; log_not_found off; }

  error_log {{log_path}}/{{server_name}}/error_log error;
  access_log {{log_path}}/{{server_name}}/access_log;

  sendfile off;

  fastcgi_intercept_errors on;

  #auth_basic           "IonServer Restricted";
  #auth_basic_user_file {{vhosts_path}}/{{server_name}}/.htpasswd;

  #location / {
  #  proxy_set_header X-Forwarded-For \$remote_addr;
  #  proxy_set_header Host \$http_host;
  #  proxy_pass       http://localhost:<PORT>;
  #}

  #location ~ \\.php {
  #  fastcgi_pass unix:/run/php/php8.0-fpm.sock;
  #  fastcgi_split_path_info ^((?U).+\\.php)(/?.+)\$;
  #  fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
  #  fastcgi_param PATH_INFO \$fastcgi_path_info;
  #  fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_path_info;
  #  fastcgi_read_timeout 600s;
  #  fastcgi_send_timeout 600s;
  #  fastcgi_index index.php;
  #  include /etc/nginx/fastcgi_params;
  #}
  
  location ~ /\\.ht {
    deny all;
  }
}
"""
};