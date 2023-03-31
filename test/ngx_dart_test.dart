import 'package:ngx_dart/models/vhost.dart';
import 'package:ngx_dart/nginx.dart';
import 'package:test/test.dart';
import '../bin/ngx_dart.dart' ;


void main() {
  final nginx = Nginx();
  final hostname = "test.io";
  Vhost ensureHost() {
    final host = nginx.getVhost(hostname);
    expect(host, isNotNull);
    return host!;
  }
  test("Create vhost", () {
    ngx(["create", "test.io"], nginx);
    ensureHost();
  });

  test("Enable vhost", () {
    ngx(["enable", hostname], nginx);
    expect(ensureHost().enabled(), isTrue);
  });

  test("List vhosts", () {
    ngx(["list"], nginx);
  });

  test("Disable vhost", () {
    ngx(["disable", hostname], nginx);
    expect(ensureHost().enabled(), isFalse);
  });

  test("Root path", () {
    ngx(["root", hostname], nginx);
  });

  test("Delete vhost", () {
    ngx(["delete", hostname], nginx);
    expect(nginx.getVhost(hostname), isNull);
  });
}
