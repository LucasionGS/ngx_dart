import 'dart:io';

import 'package:ngx_dart/nginx.dart';

class Vhost {
  File config;
  Nginx nginx;

  String? _name;
  String get name => _name ??= config.uri.pathSegments.last.replaceFirst(RegExp(r"\.conf$"), "");
  bool enabled() => File.fromUri(Uri.file("${nginx.nginxSitesEnabled()}/$name.conf")).existsSync();
  Vhost(this.nginx, this.config);

  void enable() {
    if (!enabled()) {
      nginx.enableVhost(this);
    }
  }

  void disable() {
    if (enabled()) {
      nginx.disableVhost(this);
    }
  }

  String get root => nginx.getRoot(this);
}