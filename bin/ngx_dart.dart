import 'dart:io';

import 'package:ngx_dart/nginx.dart' show Nginx;
import 'package:colorize/colorize.dart';

bool isNullOrEmpty(String? str) => str == null || str.isEmpty;
const debug = true;

Future<void> wait(int milliseconds) async {
  await Future.delayed(Duration(milliseconds: milliseconds));
}
void main(List<String> arguments) async {
  if (Platform.isWindows) {
    print("This script is not supported on Windows");
    return;
  }
  ngx(arguments);
}

void ngx(List<String> arguments, [Nginx? nginx]) {	
  nginx ??= Nginx();
  final command = arguments[0];
  final args = arguments.sublist(1);
  
  switch (command) {
    case "list":
      final vhosts = nginx.listVhosts();
      print("Vhosts:");
      for (final vhost in vhosts) {
        final enabled = vhost.enabled();
        if (enabled) {
          print("\t${Colorize("Enabled").green()} | ${vhost.name}");
        }
        else {
          print("\t${Colorize("Disabled").red()} | ${vhost.name}");
        }
      }

      break;
    case "create":
      if (args.isEmpty) {
        print("Missing argument: server_name");
        return;
      }
      final name = args[0],
            template = args.length > 1 ? args[1] : "base";
      
      nginx.createVhost(name, template: template);

      print("Created vhost $name");
      break;

    case "delete":
      if (args.isEmpty) {
        print("Missing argument: server_name");
        return;
      }
      final name = args[0];
      final vhost = nginx.getVhost(name);
      if (vhost == null) {
        print("Vhost $name does not exist");
        return;
      }

      nginx.deleteVhost(vhost);

      print("Deleted vhost $name");
      break;

    case "enable":
      if (args.isEmpty) {
        print("Missing argument: server_name");
        return;
      }
      final name = args[0];
      final vhost = nginx.getVhost(name);
      if (vhost == null) {
        print("Vhost $name does not exist");
        return;
      }
      vhost.enable();

      print("Enabled vhost $name");
      break;

    case "disable":
      if (args.isEmpty) {
        print("Missing argument: server_name");
        return;
      }
      final name = args[0];
      final vhost = nginx.getVhost(name);
      if (vhost == null) {
        print("Vhost $name does not exist");
        return;
      }
      vhost.disable();

      print("Disabled vhost $name");
      break;

    case "root":
      if (args.isEmpty) {
        print("Missing argument: server_name");
        return;
      }
      final name = args[0];
      final vhost = nginx.getVhost(name);
      if (vhost == null) {
        print("Vhost $name does not exist");
        return;
      }
      print(vhost.root);
      break;

    default:
      print("Unknown command");
      break;
  }
}
